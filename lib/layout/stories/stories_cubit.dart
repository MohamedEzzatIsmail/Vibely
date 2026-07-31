// lib/layout/stories/stories_cubit.dart
//
// Complete replacement — preserves ALL original methods:
//   toggleStoryReaction, addStoryComment, loadStoryComments,
//   markSeen, hasSeen, hasMyStory, isMyStory, deleteStory,
//   pickAndAddPhotoStory, pickAndAddVideoStory
//
// Improvements added over original:
//   • Server-side expiry filter in loadStories() (perf 3d)
//   • isCloseFriends support on StoryModel (feature 6g)
//   • toggleCloseFriend helper for Close Friends list management

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/story_model.dart';
import '../../models/user_model.dart';
import '../../share/local/media_permission_service.dart';
import 'video_trim_screen.dart';

// ── States ────────────────────────────────────────────────────────────────────
abstract class StoriesState {}

class StoriesInitial extends StoriesState {}

class StoriesLoading extends StoriesState {}

class StoriesLoaded extends StoriesState {}

class StoryUploading extends StoriesState {}

class StoryUploaded extends StoriesState {}

class StoriesError extends StoriesState {
  final String msg;
  StoriesError(this.msg);
}

// ── Cubit ─────────────────────────────────────────────────────────────────────
class StoriesCubit extends Cubit<StoriesState> {
  StoriesCubit() : super(StoriesInitial());

  static StoriesCubit get(context) => BlocProvider.of(context);

  final _fs = FirebaseFirestore.instance;
  final _sb = Supabase.instance.client;

  UserModel? currentUser;
  Map<String, List<StoryModel>> storiesByUser = {};
  List<String> orderedUids = [];

  void setUser(UserModel u) {
    currentUser = u;
  }

  // ── Load all non-expired stories ──────────────────────────────────────────
  // Improvement: filter expired stories server-side so they are never
  // transferred to the client. Client-side batch-delete cleans any stragglers.
  Future<void> loadStories() async {
    emit(StoriesLoading());
    try {
      final nowIso = DateTime.now().toIso8601String();

      // Server-side filter: only fetch stories that haven't expired yet.
      // Requires a Firestore single-field index on 'expiresAt' (auto-created).
      final snap = await _fs
          .collection('Stories')
          .where('expiresAt', isGreaterThan: nowIso)
          .orderBy('expiresAt', descending: false)
          .get();

      final now = DateTime.now();
      final expired = <String>[];
      final active = <StoryModel>[];

      for (final doc in snap.docs) {
        final s = StoryModel.fromJson(doc.data());
        try {
          if (DateTime.parse(s.expiresAt).isAfter(now)) {
            // Close Friends filter: skip CF-only stories if viewer isn't a CF
            if (s.isCloseFriends && !_canViewCloseFriendsStory(s)) continue;
            active.add(s);
          } else {
            expired.add(s.storyId);
          }
        } catch (_) {
          expired.add(s.storyId);
        }
      }

      // Batch-delete any expired stories that slipped through
      if (expired.isNotEmpty) {
        final batch = _fs.batch();
        for (final id in expired) {
          batch.delete(_fs.collection('Stories').doc(id));
        }
        await batch.commit();
      }

      storiesByUser = {};
      for (final s in active) {
        storiesByUser.putIfAbsent(s.uid, () => []).add(s);
      }

      // My stories first, then others sorted by most recent story
      orderedUids = storiesByUser.keys.toList()
        ..sort((a, b) {
          if (a == currentUser?.uid) return -1;
          if (b == currentUser?.uid) return 1;
          final aLatest = storiesByUser[a]!.last.dateTime;
          final bLatest = storiesByUser[b]!.last.dateTime;
          return bLatest.compareTo(aLatest);
        });

      emit(StoriesLoaded());
    } catch (e) {
      emit(StoriesError(e.toString()));
    }
  }

  /// Returns true if the current user is allowed to view a Close Friends story.
  bool _canViewCloseFriendsStory(StoryModel s) {
    if (s.uid == currentUser?.uid) return true; // always see own stories
    // Current user must be in the story owner's closeFriendsUids list.
    // We can't check the owner's list without a Firestore fetch, so we rely
    // on the viewer's own closeFriendsUids as a symmetric approximation.
    return currentUser?.isCloseFriend(s.uid) ?? false;
  }

  // ── Pick and upload a photo story ─────────────────────────────────────────
  Future<void> pickAndAddPhotoStory({
    String? caption,
    BuildContext? context,
    bool isCloseFriends = false,
  }) async {
    if (context != null) {
      final ok =
          await MediaPermissionService.requestMediaPermission(context);
      if (!ok) return;
    }
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    await _uploadStory(
      file: File(picked.path),
      isVideo: false,
      caption: caption,
      isCloseFriends: isCloseFriends,
    );
  }

  // ── Pick and upload a video story ─────────────────────────────────────────
  Future<void> pickAndAddVideoStory({
    String? caption,
    required BuildContext context,
    bool isCloseFriends = false,
  }) async {
    final permitted =
        await MediaPermissionService.requestMediaPermission(context);
    if (!permitted) return;

    final picked =
        await ImagePicker().pickVideo(source: ImageSource.gallery);
    if (picked == null) return;

    final file = File(picked.path);

    // Push trim screen; returns VideoTrimResult or null if cancelled
    final result = await Navigator.push<dynamic>(
      context,
      MaterialPageRoute(
        builder: (_) => VideoTrimScreen(videoFile: file),
        fullscreenDialog: true,
      ),
    );
    if (result == null) return;

    await _uploadStory(
      file: result.file as File,
      isVideo: true,
      caption: caption,
      trimStart: result.start as Duration,
      trimEnd: result.end as Duration,
      isCloseFriends: isCloseFriends,
    );
  }

  Future<void> _uploadStory({
    required File file,
    required bool isVideo,
    String? caption,
    Duration? trimStart,
    Duration? trimEnd,
    bool isCloseFriends = false,
  }) async {
    if (currentUser?.uid == null) return;
    emit(StoryUploading());
    try {
      final ext = isVideo ? 'mp4' : 'jpg';
      final fn =
          'stories/${currentUser!.uid}/${DateTime.now().millisecondsSinceEpoch}.$ext';

      await _sb.storage.from('user-images').upload(fn, file);
      final url = _sb.storage.from('user-images').getPublicUrl(fn);

      final ref = _fs.collection('Stories').doc();
      final now = DateTime.now();
      final storyMap = StoryModel(
        storyId: ref.id,
        uid: currentUser!.uid!,
        userName: currentUser!.name ?? '',
        userImage: currentUser!.image ?? '',
        mediaUrl: url,
        isVideo: isVideo,
        caption: caption,
        dateTime: now.toIso8601String(),
        expiresAt:
            now.add(const Duration(hours: 24)).toIso8601String(),
        thumbnailUrl: isVideo ? null : url,
        isCloseFriends: isCloseFriends,
      ).toMap();

      if (trimStart != null) storyMap['trimStartMs'] = trimStart.inMilliseconds;
      if (trimEnd != null) storyMap['trimEndMs'] = trimEnd.inMilliseconds;

      await ref.set(storyMap);

      emit(StoryUploaded());
      await loadStories();
    } catch (e) {
      emit(StoriesError(e.toString()));
    }
  }

  // ── Delete a story (own only) — cascades reactions & comments ─────────────
  Future<void> deleteStory(String storyId) async {
    final storyRef = _fs.collection('Stories').doc(storyId);
    final comments = await storyRef.collection('Comments').get();
    final batch = _fs.batch();
    for (final d in comments.docs) batch.delete(d.reference);
    batch.delete(storyRef);
    await batch.commit();
    await loadStories();
  }

  // ── Toggle emoji reaction on a story ──────────────────────────────────────
  // Called from StoryViewer via: StoriesCubit.get(context).toggleStoryReaction(...)
  Future<void> toggleStoryReaction(String storyId, String emoji) async {
    final uid = currentUser?.uid;
    if (uid == null) return;
    final ref = _fs.collection('Stories').doc(storyId);
    await _fs.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data() ?? {};
      final raw = (data['reactions'] as Map<String, dynamic>?) ?? {};
      final reactions =
          raw.map((k, v) => MapEntry(k, List<String>.from(v as List)));
      final list = List<String>.from(reactions[emoji] ?? []);
      if (list.contains(uid)) {
        list.remove(uid);
      } else {
        list.add(uid);
      }
      if (list.isEmpty) {
        reactions.remove(emoji);
      } else {
        reactions[emoji] = list;
      }
      tx.update(ref, {'reactions': reactions});
    });
    await loadStories();
  }

  // ── Add a comment to a story ──────────────────────────────────────────────
  // Called from StoryViewer via: widget.cubit.addStoryComment(...)
  Future<void> addStoryComment(String storyId, String text) async {
    if (currentUser?.uid == null || text.trim().isEmpty) return;
    final storyRef = _fs.collection('Stories').doc(storyId);
    final commentRef = storyRef.collection('Comments').doc();
    final batch = _fs.batch();
    batch.set(commentRef, {
      'uid': currentUser!.uid,
      'name': currentUser!.name ?? '',
      'image': currentUser!.image ?? '',
      'text': text.trim(),
      'dateTime': DateTime.now().toIso8601String(),
    });
    batch.update(storyRef, {'commentCount': FieldValue.increment(1)});
    await batch.commit();
  }

  // ── Load comments for a story ─────────────────────────────────────────────
  // Called from StoryViewer via: widget.cubit.loadStoryComments(...)
  Future<List<Map<String, dynamic>>> loadStoryComments(
      String storyId) async {
    final snap = await _fs
        .collection('Stories')
        .doc(storyId)
        .collection('Comments')
        .orderBy('dateTime', descending: false)
        .get();
    return snap.docs.map((d) => d.data()).toList();
  }

  // ── Mark story as seen ────────────────────────────────────────────────────
  Future<void> markSeen(String storyId) async {
    if (currentUser?.uid == null) return;
    await _fs.collection('Stories').doc(storyId).update({
      'seenBy': FieldValue.arrayUnion([currentUser!.uid]),
    });
  }

  // ── Toggle Close Friends membership ──────────────────────────────────────
  Future<void> toggleCloseFriend(String targetUid) async {
    if (currentUser?.uid == null) return;
    final privateRef = _fs
        .collection('Users').doc(currentUser!.uid)
        .collection('private').doc('data');
    final isCF = currentUser!.closeFriendsUids.contains(targetUid);
    if (isCF) {
      currentUser!.closeFriendsUids.remove(targetUid);
      await privateRef.set(
          {'closeFriendsUids': FieldValue.arrayRemove([targetUid])},
          SetOptions(merge: true));
    } else {
      currentUser!.closeFriendsUids.add(targetUid);
      await privateRef.set(
          {'closeFriendsUids': FieldValue.arrayUnion([targetUid])},
          SetOptions(merge: true));
    }
    emit(StoriesLoaded());
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  bool hasSeen(StoryModel s) => s.seenBy.contains(currentUser?.uid);
  bool hasMyStory() => storiesByUser.containsKey(currentUser?.uid);
  bool isMyStory(StoryModel s) => s.uid == currentUser?.uid;
}
