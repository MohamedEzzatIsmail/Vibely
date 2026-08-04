import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart' show FieldValue, DocumentSnapshot, QuerySnapshot;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../models/message_model.dart';
import '../../../models/notification_model.dart';
import '../../../models/user_model.dart';
import '../../../services/repositories/chat_repository.dart';
import '../notifications/notifications_cubit.dart';
import 'chat_states.dart';

// ─── GroupModel ───────────────────────────────────────────────────────────────
/// A group chat's metadata document — membership, admin, and the last
/// message preview shown in the groups list. Message documents themselves
/// live in a `Messages` sub-collection, not on this model.
class GroupModel {
  final String  id;
  final String  name;
  final String? imageUrl;
  final String? description;
  final List<String> memberUids;
  final String  adminUid;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final bool onlyAdminsCanSend;

  GroupModel({
    required this.id,
    required this.name,
    this.imageUrl,
    this.description,
    required this.memberUids,
    required this.adminUid,
    this.lastMessage,
    this.lastMessageTime,
    this.onlyAdminsCanSend = false,
  });

  factory GroupModel.fromJson(String id, Map<String, dynamic> j) => GroupModel(
    id:                id,
    name:              j['name'] ?? '',
    imageUrl:          j['imageUrl'],
    description:       j['description'],
    memberUids:        List<String>.from(j['members'] ?? []),
    adminUid:          j['adminUid'] ?? '',
    lastMessage:       j['lastMessage'],
    lastMessageTime:   j['lastMessageTime'] != null
        ? DateTime.tryParse(j['lastMessageTime']) : null,
    onlyAdminsCanSend: j['onlyAdminsCanSend'] ?? false,
  );

  Map<String, dynamic> toMap() => {
    'name':              name,
    if (imageUrl    != null) 'imageUrl':    imageUrl,
    if (description != null) 'description': description,
    'members':           memberUids,
    'adminUid':          adminUid,
    if (lastMessage != null) 'lastMessage': lastMessage,
    if (lastMessageTime != null)
      'lastMessageTime': lastMessageTime!.toIso8601String(),
    'onlyAdminsCanSend': onlyAdminsCanSend,
  };
}

class ChatCubit extends Cubit<ChatStates> {
  ChatCubit() : super(ChatInitialState());

  static ChatCubit get(context) => BlocProvider.of(context);

  UserModel?    currentUser;
  BuildContext? context;

  // ── 1-to-1 data ────────────────────────────────────────────────────────────
  Map<String, List<MessageModel>>                  messagesMap        = {};
  Map<String, List<MapEntry<String, MessageModel>>> messagesWithIdsMap = {};
  Map<String, bool>    typingMap      = {};
  Map<String, int>     unreadMap      = {};
  Map<String, String>  lastMessages   = {};
  Map<String, DateTime?> lastTimes    = {};
  Map<String, String?> lastSender     = {};
  Map<String, DocumentSnapshot?> lastDocs = {};
  Map<String, bool>    hasMoreMap     = {};
  Map<String, bool>    loadingMoreMap = {};
  Map<String, String?> typingUsers    = {};
  Map<String, bool>    mutedMap       = {};
  Map<String, bool>    pinnedMap      = {};
  Map<String, bool>    archivedMap    = {};
  Map<String, double>  uploadProgressMap = {};

  // ── Real-time presence ─────────────────────────────────────────────────────
  final Map<String, UserModel>              livePresence  = {};
  final Map<String, StreamSubscription>     _presenceSubs = {};

  // ── Group data ─────────────────────────────────────────────────────────────
  List<GroupModel>                                  groups              = [];
  Map<String, List<MessageModel>>                   groupMessagesMap    = {};
  Map<String, List<MapEntry<String, MessageModel>>> groupMessagesWithIdsMap = {};
  StreamSubscription?                               _groupsListener;
  final Map<String, StreamSubscription>             _groupMsgSubs = {};

  // ── Disappearing messages per chatId ──────────────────────────────────────
  final Map<String, int?> _disappearDaysMap = {};

  String? typingUserId;
  Timer?  typingTimer;
  bool    _isTyping = false;

  List<UserModel> users = [];

  DateTime? _usersCachedAt;
  static const _usersCacheDuration = Duration(minutes: 5);

  DateTime? _lastSendTime;
  static const _sendDebounce = Duration(seconds: 1);

  final Map<String, StreamSubscription> _messageSubs  = {};
  final Map<String, StreamSubscription> _typingSubs   = {};
  final Map<String, StreamSubscription> _lastMsgSubs  = {};
  final Map<String, StreamSubscription> _unreadSubs   = {};
  final Map<String, int>                _streamLimitMap = {};

  // ── Listener resilience ────────────────────────────────────────────────────
  /// Tracks a pending reconnect for each named real-time listener. A
  /// `.snapshots()` stream does not auto-reconnect after an error, so every
  /// listener below schedules a retry through here rather than staying dead.
  final Map<String, Timer> _retryTimers = {};
  static const _retryDelay = Duration(seconds: 3);

  /// Cancels any pending retry for [key] and schedules [resubscribe] to run
  /// after [_retryDelay].
  void _scheduleRetry(String key, void Function() resubscribe) {
    _retryTimers[key]?.cancel();
    _retryTimers[key] = Timer(_retryDelay, resubscribe);
  }

  /// Cancels a pending retry — call this once fresh data arrives, since the
  /// listener has clearly recovered on its own.
  void _clearRetry(String key) => _retryTimers[key]?.cancel();

  void _cancelAllRetries() {
    for (final t in _retryTimers.values) {
      t.cancel();
    }
    _retryTimers.clear();
  }

  // ── Init ───────────────────────────────────────────────────────────────────
  void setCurrentUser(UserModel user) {
    currentUser = user;
    // Restore pinned chats from user model
    for (final uid in (user.pinnedChats ?? [])) {
      pinnedMap[uid] = true;
    }
  }

  void setContext(BuildContext ctx) => context = ctx;

  void initChat(String receiverId) {
    loadInitialMessages(receiverId);
    _listenTyping(receiverId);
    markAsSeen(receiverId);
    listenPresence(receiverId);
    _loadChatMeta(receiverId);
  }

  Future<void> _loadChatMeta(String receiverId) async {
    final chatId = _getChatId(receiverId);
    final doc    = await ChatRepository.getChatMeta(chatId);
    if (!doc.exists) return;
    final data = doc.data()!;
    // Disappearing messages
    _disappearDaysMap[chatId] = data['disappearAfterDays'] as int?;
    // Muted/archived
    final myUid = currentUser?.uid ?? '';
    final mutedBy    = List<String>.from(data['mutedBy']    ?? []);
    final archivedBy = List<String>.from(data['archivedBy'] ?? []);
    mutedMap[receiverId]    = mutedBy.contains(myUid);
    archivedMap[receiverId] = archivedBy.contains(myUid);
    emit(ChatUsersLoadedState());
  }

  void disposeChat(String receiverId) {
    _messageSubs[receiverId]?.cancel();
    _typingSubs[receiverId]?.cancel();
    _clearRetry('messages_$receiverId');
    _clearRetry('typing_$receiverId');
  }

  void disposeAllChats() {
    for (final s in [
      ..._messageSubs.values, ..._typingSubs.values,
      ..._lastMsgSubs.values, ..._unreadSubs.values,
      ..._presenceSubs.values, ..._groupMsgSubs.values,
    ]) { s.cancel(); }
    _groupsListener?.cancel();
    _cancelAllRetries();
  }

  @override
  Future<void> close() {
    disposeAllChats();
    typingTimer?.cancel();
    return super.close();
  }

  // ── Real-time presence ─────────────────────────────────────────────────────
  void listenPresence(String uid) {
    _presenceSubs[uid]?.cancel();
    final key = 'presence_$uid';
    _presenceSubs[uid] = ChatRepository.watchUser(uid, (s) {
      _clearRetry(key);
      if (!s.exists) return;
      livePresence[uid] = UserModel.fromJson(s.data()!);
      emit(ChatOnlineUpdatedState());
    }, onError: (e) {
      debugPrint('Presence listener error for $uid: $e');
      _scheduleRetry(key, () => listenPresence(uid));
    });
  }

  Future<void> setOnline(bool isOnline) async {
    if (currentUser?.uid == null) return;
    await ChatRepository.setOnline(uid: currentUser!.uid!, isOnline: isOnline);
  }

  UserModel? getLiveUser(String uid) => livePresence[uid];
  int? getDisappearDays(String receiverId) => _disappearDaysMap[_getChatId(receiverId)];

  // ── Messages stream ────────────────────────────────────────────────────────
  void loadInitialMessages(String receiverId) => _startRealtimeStream(receiverId, limit: 20);

  void _startRealtimeStream(String receiverId, {required int limit}) {
    _messageSubs[receiverId]?.cancel();
    final chatId = _getChatId(receiverId);
    _streamLimitMap[receiverId] = limit;
    final key = 'messages_$receiverId';

    _messageSubs[receiverId] = ChatRepository.watchMessages(
      chatId: chatId,
      limit: limit,
      onData: (snapshot) {
        _clearRetry(key);
        final myUid        = currentUser?.uid ?? '';
        final disappearDays = _disappearDaysMap[chatId];
        final cutoff = disappearDays != null
            ? DateTime.now().subtract(Duration(days: disappearDays))
            : null;

        var entries = snapshot.docs
            .map((d) => MapEntry(d.id, MessageModel.fromJson(d.data())))
            .toList();

        // Filter hidden + expired
        entries = entries.where((e) {
          if (e.value.deletedForMe.contains(myUid)) return false;
          if (cutoff != null) {
            final dt = DateTime.tryParse(e.value.dateTime ?? '');
            if (dt != null && dt.isBefore(cutoff)) return false;
          }
          return true;
        }).toList();

        messagesMap[receiverId]        = entries.map((e) => e.value).toList();
        messagesWithIdsMap[receiverId] = entries;
        if (snapshot.docs.isNotEmpty) lastDocs[receiverId] = snapshot.docs.last;
        hasMoreMap[receiverId] = snapshot.docs.length >= limit;
        emit(ChatMessagesUpdatedState());
      },
      onError: (e) {
        debugPrint('Message listener error for $receiverId: $e');
        _scheduleRetry(key, () =>
            _startRealtimeStream(receiverId, limit: _streamLimitMap[receiverId] ?? limit));
      },
    );
  }

  // ── Send text ──────────────────────────────────────────────────────────────
  Future<void> sendMessage({required String receiverId, required String text}) async {
    if (isBlockedPair(receiverId)) {
      emit(ChatErrorState("You can't message this user."));
      return;
    }
    final now = DateTime.now();
    if (_lastSendTime != null && now.difference(_lastSendTime!) < _sendDebounce) return;
    _lastSendTime = now;
    try {
      stopTypingOnSend(receiverId);
      final chatId = _getChatId(receiverId);
      final nowStr = now.toIso8601String();
      final msg    = MessageModel(senderId: currentUser!.uid, receiverId: receiverId,
          text: text, dateTime: nowStr, seen: false);
      final messageId = await ChatRepository.sendMessage(
        chatId: chatId,
        messageData: msg.toMap(),
        participants: _participants(receiverId),
        preview: text,
        lastSenderId: currentUser!.uid,
      );
      await _sendChatNotification(receiverId: receiverId, chatId: chatId, messageId: messageId, preview: text, mediaType: 'text');
      emit(ChatSendMessageSuccessState());
    } catch (e) { emit(ChatErrorState(e.toString())); }
  }

  // ── Send image ─────────────────────────────────────────────────────────────
  Future<void> sendImage({required String receiverId, required File imageFile, String caption = ''}) async {
    if (isBlockedPair(receiverId)) {
      emit(ChatErrorState("You can't message this user."));
      return;
    }
    try {
      emit(ChatSendingMediaState(progress: 0));
      final url = await ChatRepository.uploadChatImage(imageFile);
      final chatId = _getChatId(receiverId);
      final nowStr = DateTime.now().toIso8601String();
      final preview = caption.isNotEmpty ? caption : '🖼️ Image';
      final msg = MessageModel(senderId: currentUser!.uid, receiverId: receiverId,
          text: caption.isNotEmpty ? caption : null, imageUrl: url,
          dateTime: nowStr, seen: false);
      final messageId = await ChatRepository.sendMessage(
        chatId: chatId,
        messageData: msg.toMap(),
        participants: _participants(receiverId),
        preview: preview,
        lastSenderId: currentUser!.uid,
      );
      uploadProgressMap.remove('pending');
      await _sendChatNotification(receiverId: receiverId, chatId: chatId, messageId: messageId, preview: preview, mediaType: 'image');
      emit(ChatSendMessageSuccessState());
    } catch (e) { uploadProgressMap.remove('pending'); emit(ChatErrorState(e.toString())); }
  }

  // ── Send video (NO notification) ───────────────────────────────────────────
  Future<void> sendVideo({required String receiverId, required File videoFile, String caption = ''}) async {
    if (isBlockedPair(receiverId)) {
      emit(ChatErrorState("You can't message this user."));
      return;
    }
    try {
      emit(ChatSendingMediaState(progress: 0));
      final url = await ChatRepository.uploadChatVideo(videoFile);
      final chatId = _getChatId(receiverId);
      final nowStr = DateTime.now().toIso8601String();
      final preview = caption.isNotEmpty ? caption : '📹 Video';
      final msg = MessageModel(senderId: currentUser!.uid, receiverId: receiverId,
          text: caption.isNotEmpty ? caption : null, videoUrl: url,
          dateTime: nowStr, seen: false);
      await ChatRepository.sendMessage(
        chatId: chatId,
        messageData: msg.toMap(),
        participants: _participants(receiverId),
        preview: preview,
        lastSenderId: currentUser!.uid,
      );
      uploadProgressMap.remove('pending');
      // ⚠️ No notification for video
      emit(ChatSendMessageSuccessState());
    } catch (e) { uploadProgressMap.remove('pending'); emit(ChatErrorState(e.toString())); }
  }

  // ── Send voice ─────────────────────────────────────────────────────────────
  Future<void> sendVoice({required String receiverId, required File audioFile, required int durationSeconds, List<double> waveformData = const []}) async {
    if (isBlockedPair(receiverId)) {
      emit(ChatErrorState("You can't message this user."));
      return;
    }
    try {
      emit(ChatSendingMediaState(progress: 0));
      final url = await ChatRepository.uploadChatVoice(audioFile);
      final chatId = _getChatId(receiverId);
      final nowStr = DateTime.now().toIso8601String();
      const preview = '🎤 Voice message';
      final msg = MessageModel(senderId: currentUser!.uid, receiverId: receiverId,
          audioUrl: url, audioDuration: durationSeconds, waveformData: waveformData, dateTime: nowStr, seen: false);
      final messageId = await ChatRepository.sendMessage(
        chatId: chatId,
        messageData: msg.toMap(),
        participants: _participants(receiverId),
        preview: preview,
        lastSenderId: currentUser!.uid,
      );
      uploadProgressMap.remove('pending');
      await _sendChatNotification(receiverId: receiverId, chatId: chatId, messageId: messageId, preview: preview, mediaType: 'audio');
      emit(ChatSendMessageSuccessState());
    } catch (e) { uploadProgressMap.remove('pending'); emit(ChatErrorState(e.toString())); }
  }

  // ── Forward ────────────────────────────────────────────────────────────────
  Future<void> forwardMessage({required String targetReceiverId, required MessageModel originalMsg}) async {
    if (isBlockedPair(targetReceiverId)) {
      emit(ChatErrorState("You can't message this user."));
      return;
    }
    try {
      final chatId = _getChatId(targetReceiverId);
      final nowStr = DateTime.now().toIso8601String();
      final fwd = MessageModel(
        senderId: currentUser!.uid, receiverId: targetReceiverId,
        text: originalMsg.text, videoUrl: originalMsg.videoUrl,
        imageUrl: originalMsg.imageUrl, audioUrl: originalMsg.audioUrl,
        audioDuration: originalMsg.audioDuration,
        sharedPostId: originalMsg.sharedPostId, sharedPostOwnerName: originalMsg.sharedPostOwnerName,
        sharedPostOwnerImage: originalMsg.sharedPostOwnerImage, sharedPostText: originalMsg.sharedPostText,
        sharedPostImage: originalMsg.sharedPostImage, sharedPostVideo: originalMsg.sharedPostVideo,
        isForwarded: true, dateTime: nowStr, seen: false,
      );
      final preview    = _previewText(fwd);
      final messageId = await ChatRepository.sendMessage(
        chatId: chatId,
        messageData: fwd.toMap(),
        participants: _participants(targetReceiverId),
        preview: preview,
        lastSenderId: currentUser!.uid,
      );
      if (!fwd.hasVideo) await _sendChatNotification(
          receiverId: targetReceiverId, chatId: chatId, messageId: messageId,
          preview: preview, mediaType: fwd.hasImage ? 'image' : 'text');
      emit(ChatSendMessageSuccessState());
    } catch (e) { emit(ChatErrorState(e.toString())); }
  }

  // ── Send shared post ───────────────────────────────────────────────────────
  Future<void> sendSharedPost({
    required String receiverId, required String caption,
    required String sharedPostId, required String sharedPostOwnerName,
    required String sharedPostOwnerImage, required String sharedPostText,
    String? sharedPostImage, String? sharedPostVideo,
  }) async {
    if (currentUser?.uid == null) return;
    if (isBlockedPair(receiverId)) {
      emit(ChatErrorState("You can't message this user."));
      return;
    }
    try {
      final chatId = _getChatId(receiverId);
      final nowStr = DateTime.now().toIso8601String();
      final preview = caption.isNotEmpty ? caption : '📎 Shared a post';
      final msg = MessageModel(
        senderId: currentUser!.uid, receiverId: receiverId, text: caption,
        sharedPostId: sharedPostId, sharedPostOwnerName: sharedPostOwnerName,
        sharedPostOwnerImage: sharedPostOwnerImage, sharedPostText: sharedPostText,
        sharedPostImage: sharedPostImage, sharedPostVideo: sharedPostVideo,
        dateTime: nowStr, seen: false,
      );
      final messageId = await ChatRepository.sendMessage(
        chatId: chatId,
        messageData: msg.toMap(),
        participants: _participants(receiverId),
        preview: preview,
        lastSenderId: currentUser!.uid,
      );
      await _sendChatNotification(receiverId: receiverId, chatId: chatId, messageId: messageId, preview: preview, mediaType: 'text');
      emit(ChatSendMessageSuccessState());
    } catch (e) { emit(ChatErrorState(e.toString())); }
  }

  // ── Reply ──────────────────────────────────────────────────────────────────
  Future<void> sendReply({
    required String receiverId, required String text,
    required String replyToId, required String replyToSenderName,
    required String replyToText, String? replyToMediaUrl, bool replyToIsStory = false,
  }) async {
    try {
      stopTypingOnSend(receiverId);
      final chatId = _getChatId(receiverId);
      final nowStr = DateTime.now().toIso8601String();
      final msg = MessageModel(
        senderId: currentUser!.uid, receiverId: receiverId, text: text,
        dateTime: nowStr, seen: false, replyToId: replyToId,
        replyToSenderName: replyToSenderName, replyToText: replyToText,
        replyToMediaUrl: replyToMediaUrl, replyToIsStory: replyToIsStory,
      );
      final messageId = await ChatRepository.sendMessage(
        chatId: chatId,
        messageData: msg.toMap(),
        participants: _participants(receiverId),
        preview: text,
        lastSenderId: currentUser!.uid,
      );
      await _sendChatNotification(receiverId: receiverId, chatId: chatId, messageId: messageId, preview: text, mediaType: 'text');
      emit(ChatSendMessageSuccessState());
    } catch (e) { emit(ChatErrorState(e.toString())); }
  }

  // ── Delete for me ──────────────────────────────────────────────────────────
  Future<void> deleteForMe({required String receiverId, required String messageId}) async {
    try {
      await ChatRepository.deleteForMe(
        chatId: _getChatId(receiverId),
        messageId: messageId,
        myUid: currentUser!.uid!,
      );
      emit(ChatMessageDeletedState());
    } catch (e) { emit(ChatErrorState(e.toString())); }
  }

  Future<void> deleteForEveryone({required String receiverId, required String messageId}) async {
    try {
      await ChatRepository.deleteForEveryone(
        chatId: _getChatId(receiverId),
        messageId: messageId,
      );
      emit(ChatMessageDeletedState());
    } catch (e) { emit(ChatErrorState(e.toString())); }
  }

  Future<void> deleteOtherMessageForMe({required String receiverId, required String messageId}) async {
    try {
      await ChatRepository.deleteOtherMessageForMe(
        chatId: _getChatId(receiverId),
        messageId: messageId,
        myUid: currentUser!.uid!,
      );
      emit(ChatMessageDeletedState());
    } catch (e) { emit(ChatErrorState(e.toString())); }
  }

  Future<void> bulkDeleteForMe({required String receiverId, required Set<String> messageIds}) async {
    await ChatRepository.bulkDeleteForMe(
      chatId: _getChatId(receiverId),
      messageIds: messageIds,
      myUid: currentUser!.uid!,
    );
    emit(ChatMessageDeletedState());
  }

  Future<void> bulkDeleteForEveryone({required String receiverId, required Set<String> messageIds}) async {
    await ChatRepository.bulkDeleteForEveryone(
      chatId: _getChatId(receiverId),
      messageIds: messageIds,
    );
    emit(ChatMessageDeletedState());
  }

  // ── Delete conversation ────────────────────────────────────────────────────
  Future<void> deleteConversation(String otherUid) async {
    try {
      final myUid  = currentUser!.uid!;
      final chatId = _getChatId(otherUid);
      await ChatRepository.deleteConversationMessages(chatId: chatId, myUid: myUid);
      users.removeWhere((u) => u.uid == otherUid);
      emit(ChatConversationDeletedState());
    } catch (e) { emit(ChatErrorState(e.toString())); }
  }

  // ── Mute ───────────────────────────────────────────────────────────────────
  Future<void> muteConversation(String otherUid, {required bool mute}) async {
    mutedMap[otherUid] = mute;
    await ChatRepository.setMuted(
      chatId: _getChatId(otherUid),
      myUid: currentUser!.uid!,
      mute: mute,
    );
    emit(ChatConversationMutedState());
  }

  bool isMuted(String otherUid) => mutedMap[otherUid] == true;

  // ── Pin — persisted per-user on their own Users doc, not the chat itself ───
  /// Pins/unpins a conversation to the top of the chats list.
  Future<void> pinConversation(String otherUid, {required bool pin}) async {
    pinnedMap[otherUid] = pin;
    await ChatRepository.setPinned(
      myUid: currentUser!.uid!,
      otherUid: otherUid,
      pin: pin,
    );
    emit(ChatConversationPinnedState());
  }

  bool isPinned(String otherUid) => pinnedMap[otherUid] == true;

  // ── Archive ──────────────────────────────────────────────────────────────
  /// Archives/unarchives a conversation (hides it from the main chats list).
  Future<void> archiveConversation(String otherUid, {required bool archive}) async {
    archivedMap[otherUid] = archive;
    await ChatRepository.setArchived(
      chatId: _getChatId(otherUid),
      myUid: currentUser!.uid!,
      archive: archive,
    );
    emit(ChatArchivedState());
  }

  bool isArchived(String otherUid) => archivedMap[otherUid] == true;

  // ── Edit ───────────────────────────────────────────────────────────────────
  Future<void> editMessage({required String receiverId, required String messageId, required String newText}) async {
    try {
      await ChatRepository.editMessage(
        chatId: _getChatId(receiverId),
        messageId: messageId,
        newText: newText,
      );
      emit(ChatMessageEditedState());
    } catch (e) { emit(ChatErrorState(e.toString())); }
  }

  // ── Reaction ───────────────────────────────────────────────────────────────
  Future<void> toggleReaction({required String receiverId, required String messageId, required String emoji}) async {
    try {
      await ChatRepository.toggleReaction(
        chatId: _getChatId(receiverId),
        messageId: messageId,
        emoji: emoji,
        myUid: currentUser!.uid!,
      );
      emit(ChatReactionToggledState());
    } catch (e) { emit(ChatErrorState(e.toString())); }
  }

  Map<String, List<String>> getReactionDetail(MessageModel msg) => msg.reactions;

  // ── Search ─────────────────────────────────────────────────────────────────
  List<MapEntry<String, MessageModel>> searchMessages(String receiverId, String query) {
    if (query.isEmpty) return [];
    final q = query.toLowerCase();
    return (messagesWithIdsMap[receiverId] ?? [])
        .where((e) => !e.value.isDeleted && (e.value.text?.toLowerCase().contains(q) == true))
        .toList();
  }

  // ── Disappearing messages ────────────────────────────────────────────────
  /// Sets (or clears, if [days] is null) an auto-expiry window for this
  /// chat. Expiry is enforced client-side by the message stream filter, not
  /// server-side — old messages still exist in Firestore, they're just
  /// filtered out of what's shown once they're past the cutoff.
  Future<void> setDisappearingMessages({required String receiverId, int? days}) async {
    final chatId = _getChatId(receiverId);
    _disappearDaysMap[chatId] = days;
    await ChatRepository.setDisappearingMessages(chatId: chatId, days: days);
    // Re-subscribe so the stream immediately re-applies the new cutoff.
    _startRealtimeStream(receiverId, limit: _streamLimitMap[receiverId] ?? 20);
    emit(ChatDisappearingMsgState());
  }

  // ── Pagination ─────────────────────────────────────────────────────────────
  Future<void> loadMoreMessages(String receiverId) async {
    if (loadingMoreMap[receiverId] == true) return;
    if (hasMoreMap[receiverId] == false) return;
    loadingMoreMap[receiverId] = true;
    final cur = _streamLimitMap[receiverId] ?? 20;
    _startRealtimeStream(receiverId, limit: cur + 20);
    loadingMoreMap[receiverId] = false;
  }

  Future<void> markAsSeen(String receiverId) async {
    await ChatRepository.markAsSeen(
      chatId: _getChatId(receiverId),
      myUid: currentUser!.uid!,
    );
  }

  // ── Start new chat ─────────────────────────────────────────────────────────
  Future<String> ensureChat(String otherUid) async {
    final chatId = _getChatId(otherUid);
    await ChatRepository.ensureChatDoc(
      chatId: chatId,
      participants: _participants(otherUid),
    );
    if (!users.any((u) => u.uid == otherUid)) {
      final doc = await ChatRepository.getUser(otherUid);
      if (doc.exists) {
        final u = UserModel.fromJson(doc.data()!);
        users.insert(0, u);
        _listenLastMessage(otherUid);
        _listenUnread(otherUid);
        listenPresence(otherUid);
        emit(ChatUsersLoadedState());
      }
    }
    return chatId;
  }

  // ── Block & report ───────────────────────────────────────────────────────
  /// Blocks a user: removes them from the conversations list, records the
  /// block on both sides (so blocked-by can be checked from either user's
  /// doc), and sends them a notification so being blocked isn't silent.
  Future<void> blockUser(String targetUid) async {
    final myUid = currentUser!.uid!;
    await ChatRepository.blockUser(myUid: myUid, targetUid: targetUid);
    users.removeWhere((u) => u.uid == targetUid);
    currentUser?.blockedUids.add(targetUid);
    emit(ChatUserBlockedState());

    // Let the blocked user know — matches how every other notification in
    // this app works, so it's consistent rather than a silent action.
    if (context != null && currentUser != null) {
      final notification = AppNotification(
        id: null, type: NotificationType.blocked,
        fromUserId: myUid, fromUserName: currentUser!.name ?? '',
        fromUserImage: currentUser!.image ?? '',
        dateTime: DateTime.now().toIso8601String(),
      );
      await NotificationsCubit.get(context!)
          .sendNotification(toUserId: targetUid, notification: notification);
    }
  }

  Future<void> unblockUser(String targetUid) async {
    final myUid = currentUser!.uid!;
    await ChatRepository.unblockUser(myUid: myUid, targetUid: targetUid);
    currentUser?.blockedUids.remove(targetUid);
    emit(ChatUserBlockedState());
  }

  /// True if either the current user has blocked [otherUid], or [otherUid]
  /// has blocked the current user. Used to gate messaging both directions
  /// and to hide messages from a blocked relationship in group chats.
  bool isBlockedPair(String otherUid) {
    final me = currentUser;
    if (me == null) return false;
    return me.blockedUids.contains(otherUid) ||
        me.blockedByUids.contains(otherUid);
  }

  Future<void> reportUser({required String targetUid, required String reason, required String receiverId}) async {
    final myUid     = currentUser!.uid!;
    final recentMsgs = (messagesWithIdsMap[receiverId] ?? []).take(5)
        .map((e) => e.value.text ?? '[media]').toList();
    await ChatRepository.reportUser(
      reportedBy: myUid,
      reportedUser: targetUid,
      reason: reason,
      recentMessages: recentMsgs,
    );
    emit(ChatUserReportedState());
  }

  bool isBlockedByMe(String uid) => currentUser?.blockedUids.contains(uid) == true;

  // ── Group management ───────────────────────────────────────────────────────
  Future<String> createGroup({required String name, required List<String> memberUids, File? imageFile}) async {
    try {
      String? imageUrl;
      if (imageFile != null) {
        imageUrl = await ChatRepository.uploadGroupImage(imageFile);
      }
      final allMembers = [...{currentUser!.uid!, ...memberUids}];
      final group = GroupModel(id: '', name: name, imageUrl: imageUrl,
          memberUids: allMembers, adminUid: currentUser!.uid!);
      final ref = await ChatRepository.createGroup(group.toMap());
      emit(ChatGroupCreatedState());
      return ref.id;
    } catch (e) { emit(ChatErrorState(e.toString())); return ''; }
  }

  /// Live listener for the groups this user belongs to.
  void listenGroups() {
    if (currentUser?.uid == null) return;
    _groupsListener?.cancel();
    const key = 'groups';
    _groupsListener = ChatRepository.watchGroups(
      myUid: currentUser!.uid!,
      onData: (snap) {
        _clearRetry(key);
        groups = snap.docs.map((d) => GroupModel.fromJson(d.id, d.data())).toList();
        emit(ChatGroupLoadedState());
      },
      onError: (e) {
        debugPrint('Groups listener error: $e');
        _scheduleRetry(key, listenGroups);
      },
    );
  }

  /// One-shot fetch of groups, used where a live listener isn't needed.
  Future<void> loadGroups() async {
    if (currentUser?.uid == null) return;
    final snap = await ChatRepository.fetchGroups(currentUser!.uid!);
    groups = snap.docs.map((d) => GroupModel.fromJson(d.id, d.data())).toList();
    emit(ChatGroupLoadedState());
  }

  void listenGroupMessages(String groupId) {
    _groupMsgSubs[groupId]?.cancel();
    final key = 'groupMsgs_$groupId';
    _groupMsgSubs[groupId] = ChatRepository.watchGroupMessages(
      groupId: groupId,
      limit: 30,
      onData: (snap) {
        _clearRetry(key);
        final myUid  = currentUser?.uid ?? '';
        final entries = snap.docs.map((d) => MapEntry(d.id, MessageModel.fromJson(d.data())))
            .where((e) => !e.value.deletedForMe.contains(myUid))
            .where((e) => e.value.senderId == null ||
                !isBlockedPair(e.value.senderId!))
            .toList();
        groupMessagesMap[groupId]        = entries.map((e) => e.value).toList();
        groupMessagesWithIdsMap[groupId] = entries;
        emit(ChatMessagesUpdatedState());
      },
      onError: (e) {
        debugPrint('Group message listener error for $groupId: $e');
        _scheduleRetry(key, () => listenGroupMessages(groupId));
      },
    );
  }

  /// Returns null if sending is allowed, or a user-facing error message if
  /// this group currently restricts sending to admins and the current user
  /// isn't one. Enforced here (not just in the UI) so a stale/late-refreshing
  /// group object in the composer can never let a restricted member send.
  String? _blockedByAdminOnlySend(String groupId) {
    GroupModel? group;
    for (final g in groups) {
      if (g.id == groupId) { group = g; break; }
    }
    // If we don't have the group cached locally, don't block on a guess —
    // that's a data-availability gap, not a permission decision.
    if (group == null) return null;
    final isAdmin = group.adminUid == currentUser?.uid;
    if (group.onlyAdminsCanSend && !isAdmin) {
      return 'Only the group admin can send messages in this group.';
    }
    return null;
  }

  Future<void> sendGroupMessage({
    required String groupId,
    required String text,
    String? replyToId,
    String? replyToSenderName,
    String? replyToText,
  }) async {
    final blocked = _blockedByAdminOnlySend(groupId);
    if (blocked != null) {
      emit(ChatErrorState(blocked));
      return;
    }
    try {
      final nowStr = DateTime.now().toIso8601String();
      final msg = MessageModel(
        senderId: currentUser!.uid,
        text: text,
        dateTime: nowStr,
        isGroupMsg: true,
        seen: false,
        replyToId: replyToId,
        replyToSenderName: replyToSenderName,
        replyToText: replyToText,
      );
      await ChatRepository.sendGroupMessage(
        groupId: groupId,
        messageData: msg.toMap(),
        preview: text,
      );
      emit(ChatSendMessageSuccessState());
      unawaited(_sendGroupChatNotifications(
        groupId: groupId,
        preview: text,
      ));
    } catch (e) { emit(ChatErrorState(e.toString())); }
  }

  Future<void> sendGroupVoice({
    required String groupId,
    required File audioFile,
    required int durationSeconds,
    List<double> waveformData = const [],
    String? replyToId,
    String? replyToSenderName,
    String? replyToText,
  }) async {
    final blocked = _blockedByAdminOnlySend(groupId);
    if (blocked != null) {
      emit(ChatErrorState(blocked));
      return;
    }
    try {
      emit(ChatSendingMediaState(progress: 0));
      final url = await ChatRepository.uploadGroupVoice(audioFile);
      final nowStr  = DateTime.now().toIso8601String();
      const preview = '🎤 Voice message';
      final msg = MessageModel(
        senderId: currentUser!.uid,
        audioUrl: url,
        audioDuration: durationSeconds,
        waveformData: waveformData,
        dateTime: nowStr,
        isGroupMsg: true,
        seen: false,
        replyToId: replyToId,
        replyToSenderName: replyToSenderName,
        replyToText: replyToText,
      );
      await ChatRepository.sendGroupMessage(
        groupId: groupId,
        messageData: msg.toMap(),
        preview: preview,
      );
      emit(ChatSendMessageSuccessState());
      unawaited(_sendGroupChatNotifications(
        groupId: groupId,
        preview: preview,
      ));
    } catch (e) { emit(ChatErrorState(e.toString())); }
  }

  Future<void> deleteGroupMessage({
    required String groupId,
    required String messageId,
  }) async {
    try {
      await ChatRepository.deleteGroupMessage(groupId: groupId, messageId: messageId);
      emit(ChatMessageDeletedState());
    } catch (e) { emit(ChatErrorState(e.toString())); }
  }

  // ── Group membership & admin ─────────────────────────────────────────────
  Future<void> addGroupMember({required String groupId, required String newMemberUid}) async {
    await ChatRepository.addGroupMember(groupId: groupId, newMemberUid: newMemberUid);
    emit(ChatGroupMemberAddedState());
  }

  Future<void> removeGroupMember({required String groupId, required String memberUid}) async {
    await ChatRepository.removeGroupMember(groupId: groupId, memberUid: memberUid);
    emit(ChatGroupMemberRemovedState());
  }

  Future<void> makeGroupAdmin({required String groupId, required String newAdminUid}) async {
    await ChatRepository.makeGroupAdmin(groupId: groupId, newAdminUid: newAdminUid);
    emit(ChatGroupUpdatedState());
  }

  /// Removes the current user from the group and posts a system message
  /// announcing it. The system message failing is treated as non-critical —
  /// the user has already left either way, so a notification hiccup
  /// shouldn't block the rest of the leave flow.
  Future<void> leaveGroup(String groupId) async {
    final myUid = currentUser!.uid!;
    await ChatRepository.leaveGroup(groupId: groupId, myUid: myUid);
    final nowStr = DateTime.now().toIso8601String();
    try {
      await ChatRepository.addGroupSystemMessage(
        groupId: groupId,
        messageData: {
          'senderId': 'system', 'text': '${currentUser!.name ?? "Someone"} left the group',
          'dateTime': nowStr, 'isGroupMsg': true, 'seen': true,
        },
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[ChatCubit] leaveGroup system message failed: $e');
    }
    groups.removeWhere((g) => g.id == groupId);
    emit(ChatGroupLeftState());
  }

  /// Deletes a group and all its messages. Admin-only — enforced by the
  /// Firestore rules, not checked here.
  Future<void> deleteGroup(String groupId) async {
    await ChatRepository.deleteGroup(groupId);
    groups.removeWhere((g) => g.id == groupId);
    emit(ChatGroupDeletedState());
  }

  // ── Group name / photo ───────────────────────────────────────────────────
  Future<void> updateGroupName({required String groupId, required String newName}) async {
    await ChatRepository.updateGroupName(groupId: groupId, newName: newName);
    final idx = groups.indexWhere((g) => g.id == groupId);
    if (idx != -1) {
      groups[idx] = GroupModel(id: groupId, name: newName,
          imageUrl: groups[idx].imageUrl, memberUids: groups[idx].memberUids, adminUid: groups[idx].adminUid);
    }
    emit(ChatGroupUpdatedState());
  }

  Future<void> updateGroupPhoto({required String groupId, required File imageFile}) async {
    emit(ChatSendingMediaState());
    final url = await ChatRepository.uploadGroupImage(imageFile, groupId: groupId);
    await ChatRepository.updateGroupPhoto(groupId: groupId, imageUrl: url);
    emit(ChatGroupUpdatedState());
  }

  /// Restricts sending in this group to admins only (or lifts the
  /// restriction). Enforced by the Firestore rules; this just sets the flag.
  Future<void> setGroupOnlyAdmins({required String groupId, required bool onlyAdmins}) async {
    await ChatRepository.setGroupOnlyAdmins(groupId: groupId, onlyAdmins: onlyAdmins);
    emit(ChatGroupUpdatedState());
  }

  // ── Users ──────────────────────────────────────────────────────────────────
  Future<void> loadUsers({bool forceRefresh = false}) async {
    if (currentUser == null) return;
    if (!forceRefresh && _usersCachedAt != null &&
        DateTime.now().difference(_usersCachedAt!) < _usersCacheDuration && users.isNotEmpty) {
      emit(ChatUsersLoadedState()); return;
    }
    final chatsSnap = await ChatRepository.fetchMyChats(currentUser!.uid!);
    final Set<String> otherUids = {};
    for (final doc in chatsSnap.docs) {
      final parts = List<String>.from(doc.data()['participants'] ?? []);
      for (final uid in parts) { if (uid != currentUser!.uid) otherUids.add(uid); }
    }
    if (otherUids.isEmpty) { users = []; _usersCachedAt = DateTime.now(); emit(ChatUsersLoadedState()); return; }
    final userSnaps = await ChatRepository.getUsers(otherUids);
    users = userSnaps.where((d) => d.exists).map((d) => UserModel.fromJson(d.data()!))
        .where((u) => !isBlockedByMe(u.uid!)).toList();
    users.sort((a, b) {
      final aPinned = isPinned(a.uid!) ? 1 : 0; final bPinned = isPinned(b.uid!) ? 1 : 0;
      if (aPinned != bPinned) return bPinned - aPinned;
      final aTime = lastTimes[a.uid!]; final bTime = lastTimes[b.uid!];
      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1; if (bTime == null) return -1;
      return bTime.compareTo(aTime);
    });
    _usersCachedAt = DateTime.now();
    for (final u in users) { _listenLastMessage(u.uid!); _listenUnread(u.uid!); listenPresence(u.uid!); }
    emit(ChatUsersLoadedState());
  }

  /// Watches for the chat preview shown in the conversations list. Fetches
  /// the most recent 20 messages (not just 1) so it can skip over any that
  /// are deleted or hidden-for-me and fall back to the newest one actually
  /// visible to this user.
  void _listenLastMessage(String userId) {
    final chatId  = _getChatId(userId);
    final myUid   = currentUser?.uid ?? '';
    _lastMsgSubs[userId]?.cancel();
    final key = 'lastMsg_$userId';
    _lastMsgSubs[userId] = ChatRepository.watchLastMessage(
      chatId: chatId,
      onData: (snap) {
        _clearRetry(key);
        for (final doc in snap.docs) {
          final d = doc.data();

          // Skip hard-deleted messages ("deleted for everyone")
          if (d['deleted'] == true) continue;

          // Skip messages the current user hid for themselves
          final deletedForMe = List<String>.from(d['deletedForMe'] ?? []);
          if (deletedForMe.contains(myUid)) continue;

          // Skip messages the other party deleted but marked as stub
          // (deletedByOther = true means the other side has already hidden their
          //  copy; the stub "You deleted this message" is their local view only)

          // This is the first visible message — use it as the preview
          lastMessages[userId] = d['text'] ??
              (d['imageUrl'] != null
                  ? '🖼️ Image'
                  : d['videoUrl'] != null
                  ? '📹 Video'
                  : d['audioUrl'] != null
                  ? '🎤 Voice message'
                  : '📎 Post');
          lastTimes[userId]  = DateTime.tryParse(d['dateTime'] ?? '');
          lastSender[userId] = d['senderId'];
          emit(ChatMessagesUpdatedState());
          return;
        }

        // Every recent message was deleted/hidden — show nothing
        lastMessages[userId] = '';
        lastTimes[userId]    = null;
        lastSender[userId]   = null;
        emit(ChatMessagesUpdatedState());
      },
      onError: (e) {
        debugPrint('Last-message listener error for $userId: $e');
        _scheduleRetry(key, () => _listenLastMessage(userId));
      },
    );
  }

  void _listenUnread(String userId) {
    final chatId = _getChatId(userId);
    _unreadSubs[userId]?.cancel();
    final key = 'unread_$userId';
    _unreadSubs[userId] = ChatRepository.watchUnread(
      chatId: chatId,
      myUid: currentUser!.uid!,
      onData: (s) {
        _clearRetry(key);
        unreadMap[userId] = s.docs.where((e) => e['seen'] == false).length;
        emit(ChatUnreadUpdatedState());
      },
      onError: (e) {
        debugPrint('Unread listener error for $userId: $e');
        _scheduleRetry(key, () => _listenUnread(userId));
      },
    );
  }

  int get totalUnreadCount => unreadMap.values.fold(0, (a, b) => a + b);

  void _listenTyping(String userId) {
    final chatId = _getChatId(userId);
    _typingSubs[userId]?.cancel();
    final key = 'typing_$userId';
    _typingSubs[userId] = ChatRepository.watchTyping(
      chatId: chatId,
      onData: (doc) {
        _clearRetry(key);
        typingUserId = doc.data()?['typingUserId'];
        emit(ChatTypingUpdatedState());
      },
      onError: (e) {
        debugPrint('Typing listener error for $userId: $e');
        _scheduleRetry(key, () => _listenTyping(userId));
      },
    );
  }

  void onTypingChanged(String receiverId, String text) {
    final myId = currentUser?.uid;
    if (myId == null) return;
    final chatId = _getChatId(receiverId);
    if (!_isTyping && text.isNotEmpty) {
      _isTyping = true;
      ChatRepository.setTypingUser(chatId: chatId, typingUserId: myId);
    }
    typingTimer?.cancel();
    typingTimer = Timer(const Duration(milliseconds: 1200), () => _stopTyping(receiverId));
    if (text.isEmpty) _stopTyping(receiverId);
  }

  void _stopTyping(String receiverId) {
    if (currentUser?.uid == null) return;
    _isTyping = false;
    ChatRepository.setTypingUser(chatId: _getChatId(receiverId), typingUserId: null);
  }

  void stopTypingOnSend(String receiverId) { typingTimer?.cancel(); _stopTyping(receiverId); }

  // ── Helpers ────────────────────────────────────────────────────────────────
  List<MessageModel>                   getMessages(String receiverId)        => messagesMap[receiverId] ?? [];
  List<MapEntry<String, MessageModel>> getMessagesWithIds(String receiverId) => messagesWithIdsMap[receiverId] ?? [];
  bool isMe(String? senderId)          => senderId == currentUser?.uid;
  bool isUserTyping(String otherId)    => typingUserId != null && typingUserId != currentUser?.uid;
  bool isMeLastSender(String userId)   => lastSender[userId] == currentUser?.uid;
  String getLastMessage(String userId) => lastMessages[userId] ?? '';
  String getLastMessageTime(String userId) => formatTime(lastTimes[userId]?.toIso8601String());
  int    getUnreadCount(String userId) => unreadMap[userId] ?? 0;

  String _getChatId(String otherId) {
    final ids = [currentUser!.uid!, otherId]..sort();
    return ids.join('_');
  }

  /// Canonical, order-independent `participants` array for a 1-to-1 chat —
  /// sorted the same way `_getChatId` sorts its two UIDs. The Chat doc's
  /// `participants` field must never depend on who happens to be sending,
  /// because Firestore rules require `participants` to stay byte-for-byte
  /// identical between the stored doc and every subsequent update. If it
  /// were built "me first" (as it used to be), whoever didn't send the
  /// chat's first message would produce a reversed array on every reply and
  /// get PERMISSION_DENIED forever after — this is what fixed that.
  List<String> _participants(String otherId) =>
      [currentUser!.uid!, otherId]..sort();

  String _previewText(MessageModel msg) {
    if (msg.text?.isNotEmpty == true) return msg.text!;
    if (msg.hasImage) return '🖼️ Image';
    if (msg.hasVideo) return '📹 Video';
    if (msg.hasAudio) return '🎤 Voice message';
    if (msg.isSharedPost) return '📎 Shared a post';
    return '';
  }

  String formatTime(String? dt) {
    if (dt == null) return '';
    final d = DateTime.tryParse(dt)?.toLocal();
    if (d == null) return '';
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1)  return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 12)   return '${diff.inHours}h';
    String p(int n) => n.toString().padLeft(2, '0');
    return '${d.day}/${d.month} ${p(d.hour)}:${p(d.minute)}';
  }

  String formatLastSeen(String? dt) {
    if (dt == null) return '';
    final d = DateTime.tryParse(dt)?.toLocal();
    if (d == null) return '';
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1)  return 'just now';
    if (diff.inMinutes < 60) return 'last seen ${diff.inMinutes}m ago';
    if (diff.inHours < 24)   return 'last seen ${diff.inHours}h ago';
    String p(int n) => n.toString().padLeft(2, '0');
    return 'last seen ${d.day}/${d.month} ${p(d.hour)}:${p(d.minute)}';
  }

  Future<void> _sendChatNotification({
    required String receiverId, required String chatId,
    required String messageId,
    required String preview, required String mediaType,
  }) async {
    if (context == null) return;
    final notification = AppNotification(
      id: null, type: NotificationType.message,
      fromUserId: currentUser!.uid!, fromUserName: currentUser!.name ?? '',
      fromUserImage: currentUser!.image ?? '', chatId: chatId,
      messageId: messageId,
      text: preview, dateTime: DateTime.now().toIso8601String(),
    );
    await NotificationsCubit.get(context!).sendNotification(
        toUserId: receiverId, notification: notification);
  }

  /// Group-chat counterpart of [_sendChatNotification] — notifies every
  /// other member of the group a message was just sent, so group chats get
  /// the same notification behaviour as direct chats. Members who are in a
  /// blocked relationship with the sender (either direction) are skipped,
  /// same as they're skipped when rendering the message list.
  Future<void> _sendGroupChatNotifications({
    required String groupId,
    required String preview,
  }) async {
    if (context == null) return;
    final me = currentUser;
    if (me?.uid == null) return;

    GroupModel? group;
    for (final g in groups) {
      if (g.id == groupId) { group = g; break; }
    }
    if (group == null) return;

    final notificationsCubit = NotificationsCubit.get(context!);
    for (final memberUid in group.memberUids) {
      if (memberUid == me!.uid) continue;
      if (isBlockedPair(memberUid)) continue;
      final notification = AppNotification(
        id: null, type: NotificationType.message,
        fromUserId: me.uid!, fromUserName: me.name ?? '',
        fromUserImage: me.image ?? '', chatId: groupId,
        text: preview, dateTime: DateTime.now().toIso8601String(),
        isGroup: true,
      );
      await notificationsCubit.sendNotification(
          toUserId: memberUid, notification: notification);
    }
  }
}
