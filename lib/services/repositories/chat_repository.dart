import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatRepository {
  ChatRepository._();

  static final _firestore = FirebaseFirestore.instance;
  static final _supabase = Supabase.instance.client;

  static CollectionReference<Map<String, dynamic>> get _chats =>
      _firestore.collection('Chats');
  static CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('Users');
  static CollectionReference<Map<String, dynamic>> get _groups =>
      _firestore.collection('Groups');

  /// `Users/{uid}/private/data` — block lists and pinned chats live here,
  /// not on the public Users doc. See UserRepository for the full rationale.
  static DocumentReference<Map<String, dynamic>> _privateUserDoc(String uid) =>
      _users.doc(uid).collection('private').doc('data');

  // ── Presence ─────────────────────────────────────────────────────────────
  static StreamSubscription<DocumentSnapshot<Map<String, dynamic>>> watchUser(
    String uid,
    void Function(DocumentSnapshot<Map<String, dynamic>> doc) onData, {
    void Function(Object error)? onError,
  }) {
    return _users.doc(uid).snapshots().listen(onData, onError: onError);
  }

  static Future<void> setOnline({
    required String uid,
    required bool isOnline,
  }) async {
    await _users.doc(uid).update({
      'isOnline': isOnline,
      if (!isOnline) 'lastSeen': DateTime.now().toIso8601String(),
    });
  }

  // ── Chat metadata ────────────────────────────────────────────────────────
  static Future<DocumentSnapshot<Map<String, dynamic>>> getChatMeta(String chatId) {
    return _chats.doc(chatId).get();
  }

  /// Creates the Chat document if it doesn't exist yet (merge write, so it's
  /// safe to call even if it already does). `participants` is the array the
  /// security rules check to authorize access to this chat and its messages.
  static Future<void> ensureChatDoc({
    required String chatId,
    required List<String> participants,
  }) async {
    await _chats.doc(chatId).set({
      'chatId': chatId,
      'participants': participants,
    }, SetOptions(merge: true));
  }

  // ── Messages stream (1-to-1) ─────────────────────────────────────────────
  static StreamSubscription<QuerySnapshot<Map<String, dynamic>>> watchMessages({
    required String chatId,
    required int limit,
    required void Function(QuerySnapshot<Map<String, dynamic>> snapshot) onData,
    void Function(Object error)? onError,
  }) {
    return _chats
        .doc(chatId)
        .collection('Messages')
        .orderBy('dateTime', descending: true)
        .limit(limit)
        .snapshots()
        .listen(onData, onError: onError);
  }

  /// Sends one message and updates the parent chat's preview metadata
  /// (last message, sender, timestamp) in a single batched write. Used for
  /// text, image, video, voice, forwarded, shared-post, and reply messages
  /// alike, since they all need the same two writes.
  static Future<String> sendMessage({
    required String chatId,
    required Map<String, dynamic> messageData,
    required List<String?> participants,
    required String preview,
    required String? lastSenderId,
  }) async {
    final chatRef = _chats.doc(chatId);

    // Must happen as its OWN write, before the batch below — not merged
    // into it. The Messages rule's isChatParticipant() does a get() on this
    // Chat doc, and within a single batch a get() can't see another write
    // from that same batch before it commits. If the chat doc didn't exist
    // yet, the message-create batch would see "no chat doc" and deny the
    // whole batch — which also meant the chat doc itself never got created,
    // breaking the conversation for both people from that point on. Doing
    // this first (and it's a no-op merge if the doc already exists) means
    // the batch below always sees an existing parent doc.
    await ensureChatDoc(
      chatId: chatId,
      participants: participants.whereType<String>().toList(),
    );

    final msgRef = chatRef.collection('Messages').doc();
    final batch = _firestore.batch();
    batch.set(msgRef, messageData);
    batch.set(chatRef, {
      'chatId': chatId,
      'participants': participants,
      'lastMessage': preview,
      'lastMessageTime': messageData['dateTime'],
      'lastSenderId': lastSenderId,
      'seenBy': [lastSenderId],
    }, SetOptions(merge: true));
    await batch.commit();
    return msgRef.id;
  }

  /// Marks a message as delivered — called by the recipient's device the
  /// moment the push notification for it arrives (foreground or
  /// background/terminated), so the sender sees the double-grey-tick
  /// "delivered" state in real time without the recipient needing to open
  /// the app. Distinct from `seen`, which only flips once they actually
  /// open the conversation.
  static Future<void> markDelivered({
    required String chatId,
    required String messageId,
  }) async {
    await _chats.doc(chatId).collection('Messages').doc(messageId).update({
      'delivered': true,
      'deliveredAt': DateTime.now().toIso8601String(),
    });
  }

  // ── Media uploads ────────────────────────────────────────────────────────
  static Future<String> uploadChatImage(File file) async {
    final fn = 'chat/chat_img_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await _supabase.storage
        .from('user-images')
        .upload(fn, file, fileOptions: const FileOptions(upsert: true));
    return _supabase.storage.from('user-images').getPublicUrl(fn);
  }

  static Future<String> uploadChatVideo(File file) async {
    final fn = 'chat/chat_vid_${DateTime.now().millisecondsSinceEpoch}.mp4';
    await _supabase.storage
        .from('user-images')
        .upload(fn, file, fileOptions: const FileOptions(upsert: true));
    return _supabase.storage.from('user-images').getPublicUrl(fn);
  }

  static Future<String> uploadChatVoice(File file) async {
    final fn = 'chat/chat_audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _supabase.storage
        .from('user-images')
        .upload(fn, file, fileOptions: const FileOptions(upsert: true));
    return _supabase.storage.from('user-images').getPublicUrl(fn);
  }

  static Future<String> uploadGroupVoice(File file) async {
    final fn = 'chat/grp_audio_${DateTime.now().millisecondsSinceEpoch}.aac';
    await _supabase.storage
        .from('user-images')
        .upload(fn, file, fileOptions: const FileOptions(upsert: true));
    return _supabase.storage.from('user-images').getPublicUrl(fn);
  }

  static Future<String> uploadGroupImage(File file, {String? groupId}) async {
    final fn = groupId != null
        ? 'groups/group_${groupId}_${DateTime.now().millisecondsSinceEpoch}.jpg'
        : 'groups/group_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await _supabase.storage
        .from('user-images')
        .upload(fn, file, fileOptions: const FileOptions(upsert: true));
    return _supabase.storage.from('user-images').getPublicUrl(fn);
  }

  // ── Delete / edit (1-to-1) ───────────────────────────────────────────────
  static Future<void> deleteForMe({
    required String chatId,
    required String messageId,
    required String myUid,
  }) async {
    await _chats.doc(chatId).collection('Messages').doc(messageId).update({
      'deletedForMe': FieldValue.arrayUnion([myUid]),
    });
  }

  static Future<void> deleteForEveryone({
    required String chatId,
    required String messageId,
  }) async {
    await _chats.doc(chatId).collection('Messages').doc(messageId).update({
      'deleted': true,
      'text': null,
    });
  }

  static Future<void> deleteOtherMessageForMe({
    required String chatId,
    required String messageId,
    required String myUid,
  }) async {
    await _chats.doc(chatId).collection('Messages').doc(messageId).update({
      'deletedForMe': FieldValue.arrayUnion([myUid]),
      'deletedByOther': true,
    });
  }

  static Future<void> bulkDeleteForMe({
    required String chatId,
    required Set<String> messageIds,
    required String myUid,
  }) async {
    final batch = _firestore.batch();
    for (final id in messageIds) {
      batch.update(_chats.doc(chatId).collection('Messages').doc(id), {
        'deletedForMe': FieldValue.arrayUnion([myUid]),
      });
    }
    await batch.commit();
  }

  static Future<void> bulkDeleteForEveryone({
    required String chatId,
    required Set<String> messageIds,
  }) async {
    final batch = _firestore.batch();
    for (final id in messageIds) {
      batch.update(_chats.doc(chatId).collection('Messages').doc(id), {
        'deleted': true,
        'text': null,
      });
    }
    await batch.commit();
  }

  static Future<void> deleteConversationMessages({
    required String chatId,
    required String myUid,
  }) async {
    final msgs = await _chats.doc(chatId).collection('Messages').get();
    final batch = _firestore.batch();
    for (final doc in msgs.docs) {
      batch.update(doc.reference, {
        'deletedForMe': FieldValue.arrayUnion([myUid]),
      });
    }
    await batch.commit();
  }

  static Future<void> editMessage({
    required String chatId,
    required String messageId,
    required String newText,
  }) async {
    await _chats.doc(chatId).collection('Messages').doc(messageId).update({
      'text': newText,
      'edited': true,
    });
  }

  // ── Reactions (1-to-1) ───────────────────────────────────────────────────
  /// Toggles [myUid]'s reaction to [emoji] on a message. Each user can only
  /// have one active reaction per message, so any of their other reactions
  /// are removed first. Runs as a transaction since it reads-then-writes the
  /// existing reactions map and concurrent reactions from other users must
  /// not clobber each other.
  static Future<void> toggleReaction({
    required String chatId,
    required String messageId,
    required String emoji,
    required String myUid,
  }) async {
    final ref = _chats.doc(chatId).collection('Messages').doc(messageId);
    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final raw = (snap.data()!['reactions'] as Map<String, dynamic>?) ?? {};
      final reactions = raw.map((k, v) => MapEntry(k, List<String>.from(v)));
      for (final key in reactions.keys.toList()) {
        if (key != emoji) reactions[key]?.remove(myUid);
      }
      final list = List<String>.from(reactions[emoji] ?? []);
      if (list.contains(myUid)) {
        list.remove(myUid);
      } else {
        list.add(myUid);
      }
      if (list.isEmpty) {
        reactions.remove(emoji);
      } else {
        reactions[emoji] = list;
      }
      reactions.removeWhere((_, v) => v.isEmpty);
      tx.update(ref, {'reactions': reactions});
    });
  }

  // ── Mute / pin / archive ─────────────────────────────────────────────────
  static Future<void> setMuted({
    required String chatId,
    required String myUid,
    required bool mute,
  }) async {
    await _chats.doc(chatId).set({
      'mutedBy': mute
          ? FieldValue.arrayUnion([myUid])
          : FieldValue.arrayRemove([myUid]),
    }, SetOptions(merge: true));
  }

  static Future<void> setPinned({
    required String myUid,
    required String otherUid,
    required bool pin,
  }) async {
    await _privateUserDoc(myUid).set({
      'pinnedChats': pin
          ? FieldValue.arrayUnion([otherUid])
          : FieldValue.arrayRemove([otherUid]),
    }, SetOptions(merge: true));
  }

  static Future<void> setArchived({
    required String chatId,
    required String myUid,
    required bool archive,
  }) async {
    await _chats.doc(chatId).set({
      'archivedBy': archive
          ? FieldValue.arrayUnion([myUid])
          : FieldValue.arrayRemove([myUid]),
    }, SetOptions(merge: true));
  }

  // ── Disappearing messages ────────────────────────────────────────────────
  static Future<void> setDisappearingMessages({
    required String chatId,
    required int? days,
  }) async {
    await _chats.doc(chatId).update({'disappearAfterDays': days});
  }

  // ── Seen status ───────────────────────────────────────────────────────────
  static Future<void> markAsSeen({
    required String chatId,
    required String myUid,
  }) async {
    final snap = await _chats
        .doc(chatId)
        .collection('Messages')
        .where('receiverId', isEqualTo: myUid)
        .where('seen', isEqualTo: false)
        .get();
    if (snap.docs.isEmpty) return;
    final batch = _firestore.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'seen': true});
    }
    await batch.commit();
  }

  // ── Block / report ────────────────────────────────────────────────────────
  static Future<void> blockUser({
    required String myUid,
    required String targetUid,
  }) async {
    final batch = _firestore.batch();
    batch.set(
      _privateUserDoc(myUid),
      {'blockedUids': FieldValue.arrayUnion([targetUid])},
      SetOptions(merge: true),
    );
    // Denormalized reverse index so the blocked user can cheaply know they
    // were blocked (from their own doc) without reading the blocker's doc.
    // Allowed cross-user by a narrow rule exception — see firestore.rules.
    batch.set(
      _privateUserDoc(targetUid),
      {'blockedByUids': FieldValue.arrayUnion([myUid])},
      SetOptions(merge: true),
    );
    await batch.commit();
  }

  static Future<void> unblockUser({
    required String myUid,
    required String targetUid,
  }) async {
    final batch = _firestore.batch();
    batch.set(
      _privateUserDoc(myUid),
      {'blockedUids': FieldValue.arrayRemove([targetUid])},
      SetOptions(merge: true),
    );
    batch.set(
      _privateUserDoc(targetUid),
      {'blockedByUids': FieldValue.arrayRemove([myUid])},
      SetOptions(merge: true),
    );
    await batch.commit();
  }

  static Future<void> reportUser({
    required String reportedBy,
    required String reportedUser,
    required String reason,
    required List<String> recentMessages,
  }) async {
    await _firestore.collection('Reports').add({
      'reportedBy': reportedBy,
      'reportedUser': reportedUser,
      'reason': reason,
      'recentMessages': recentMessages,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  // ── Groups ────────────────────────────────────────────────────────────────
  static Future<DocumentReference<Map<String, dynamic>>> createGroup(
      Map<String, dynamic> groupData) {
    return _groups.add(groupData);
  }

  static StreamSubscription<QuerySnapshot<Map<String, dynamic>>> watchGroups({
    required String myUid,
    required void Function(QuerySnapshot<Map<String, dynamic>> snapshot) onData,
    void Function(Object error)? onError,
  }) {
    return _groups
        .where('members', arrayContains: myUid)
        .snapshots()
        .listen(onData, onError: onError);
  }

  static Future<QuerySnapshot<Map<String, dynamic>>> fetchGroups(String myUid) {
    return _groups.where('members', arrayContains: myUid).get();
  }

  static StreamSubscription<QuerySnapshot<Map<String, dynamic>>> watchGroupMessages({
    required String groupId,
    required int limit,
    required void Function(QuerySnapshot<Map<String, dynamic>> snapshot) onData,
    void Function(Object error)? onError,
  }) {
    return _groups
        .doc(groupId)
        .collection('Messages')
        .orderBy('dateTime', descending: true)
        .limit(limit)
        .snapshots()
        .listen(onData, onError: onError);
  }

  static Future<void> sendGroupMessage({
    required String groupId,
    required Map<String, dynamic> messageData,
    required String preview,
  }) async {
    final groupRef = _groups.doc(groupId);
    final batch = _firestore.batch();
    batch.set(groupRef.collection('Messages').doc(), messageData);
    batch.set(groupRef, {
      'lastMessage': preview,
      'lastMessageTime': messageData['dateTime'],
    }, SetOptions(merge: true));
    await batch.commit();
  }

  static Future<void> deleteGroupMessage({
    required String groupId,
    required String messageId,
  }) async {
    await _groups.doc(groupId).collection('Messages').doc(messageId).update({
      'deleted': true,
      'text': '',
    });
  }

  static Future<void> addGroupSystemMessage({
    required String groupId,
    required Map<String, dynamic> messageData,
  }) async {
    await _groups.doc(groupId).collection('Messages').add(messageData);
  }

  static Future<void> addGroupMember({
    required String groupId,
    required String newMemberUid,
  }) async {
    await _groups.doc(groupId).update({
      'members': FieldValue.arrayUnion([newMemberUid]),
    });
  }

  static Future<void> removeGroupMember({
    required String groupId,
    required String memberUid,
  }) async {
    await _groups.doc(groupId).update({
      'members': FieldValue.arrayRemove([memberUid]),
    });
  }

  static Future<void> makeGroupAdmin({
    required String groupId,
    required String newAdminUid,
  }) async {
    await _groups.doc(groupId).update({'adminUid': newAdminUid});
  }

  static Future<void> leaveGroup({
    required String groupId,
    required String myUid,
  }) async {
    await _groups.doc(groupId).update({
      'members': FieldValue.arrayRemove([myUid]),
    });
  }

  static Future<void> deleteGroup(String groupId) async {
    final groupRef = _groups.doc(groupId);
    final messages = await groupRef.collection('Messages').get();
    final batch = _firestore.batch();
    for (final doc in messages.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(groupRef);
    await batch.commit();
  }

  static Future<void> updateGroupName({
    required String groupId,
    required String newName,
  }) async {
    await _groups.doc(groupId).update({'name': newName});
  }

  static Future<void> updateGroupPhoto({
    required String groupId,
    required String imageUrl,
  }) async {
    await _groups.doc(groupId).update({'imageUrl': imageUrl});
  }

  static Future<void> setGroupOnlyAdmins({
    required String groupId,
    required bool onlyAdmins,
  }) async {
    await _groups.doc(groupId).update({'onlyAdminsCanSend': onlyAdmins});
  }

  // ── Users / conversations list ───────────────────────────────────────────
  static Future<QuerySnapshot<Map<String, dynamic>>> fetchMyChats(String myUid) {
    return _chats.where('participants', arrayContains: myUid).get();
  }

  static Future<DocumentSnapshot<Map<String, dynamic>>> getUser(String uid) {
    return _users.doc(uid).get();
  }

  static Future<List<DocumentSnapshot<Map<String, dynamic>>>> getUsers(
      Iterable<String> uids) {
    return Future.wait(uids.map((uid) => _users.doc(uid).get()));
  }

  static StreamSubscription<QuerySnapshot<Map<String, dynamic>>> watchLastMessage({
    required String chatId,
    required void Function(QuerySnapshot<Map<String, dynamic>> snapshot) onData,
    void Function(Object error)? onError,
  }) {
    return _chats
        .doc(chatId)
        .collection('Messages')
        .orderBy('dateTime', descending: true)
        .limit(20)
        .snapshots()
        .listen(onData, onError: onError);
  }

  /// Streams every message addressed to [myUid] in this chat; the cubit
  /// filters by `seen == false` client-side to get the unread count, since a
  /// direct `where('seen', isEqualTo: false)` listener would need its own
  /// composite index and this collection is small per-chat anyway.
  static StreamSubscription<QuerySnapshot<Map<String, dynamic>>> watchUnread({
    required String chatId,
    required String myUid,
    required void Function(QuerySnapshot<Map<String, dynamic>> snapshot) onData,
    void Function(Object error)? onError,
  }) {
    return _chats
        .doc(chatId)
        .collection('Messages')
        .where('receiverId', isEqualTo: myUid)
        .snapshots()
        .listen(onData, onError: onError);
  }

  // ── Typing ────────────────────────────────────────────────────────────────
  /// Watches the Chat document itself, not a sub-collection — typing state
  /// (`typingUserId`) lives directly on the chat doc rather than its own
  /// collection, since it's transient, single-value, per-chat state.
  static StreamSubscription<DocumentSnapshot<Map<String, dynamic>>> watchTyping({
    required String chatId,
    required void Function(DocumentSnapshot<Map<String, dynamic>> doc) onData,
    void Function(Object error)? onError,
  }) {
    return _chats.doc(chatId).snapshots().listen(onData, onError: onError);
  }

  static Future<void> setTypingUser({
    required String chatId,
    required String? typingUserId,
  }) async {
    await _chats.doc(chatId).set({
      'typingUserId': typingUserId,
    }, SetOptions(merge: true));
  }
}
