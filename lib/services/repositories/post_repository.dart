// lib/services/repositories/post_repository.dart
//
// Wraps every Firestore + Supabase call that post_cubit.dart used to make
// directly. PostsCubit should hold no FirebaseFirestore/Supabase references
// of its own after this — it only calls PostRepository methods.
//
// Follows the same static-class convention as NotificationService:
// no instances, a private constructor, static clients, static methods.

import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../../models/post_model.dart';

class PostRepository {
  PostRepository._();

  static final _firestore = FirebaseFirestore.instance;
  static final _supabase = Supabase.instance.client;

  static CollectionReference<Map<String, dynamic>> get _posts =>
      _firestore.collection('Posts');

  // ── Presence ─────────────────────────────────────────────────────────────
  static Future<void> setOnline(String uid, bool online) async {
    await _firestore.collection('Users').doc(uid).update({
      'isOnline': online,
      'lastSeen': DateTime.now().toIso8601String(),
    });
  }

  // ── Feed — first page with real-time listener ───────────────────────────
  // Returns the subscription so the cubit can cancel it on logout/refresh,
  // exactly as it did when it owned the Firestore call directly.
  static StreamSubscription<QuerySnapshot<Map<String, dynamic>>> watchFeed({
    required int pageSize,
    required void Function(QuerySnapshot<Map<String, dynamic>> snapshot) onData,
    required void Function(Object error) onError,
  }) {
    return _posts
        .orderBy('dateTime', descending: true)
        .limit(pageSize)
        .snapshots()
        .listen(onData, onError: onError);
  }

  // ── Load more posts (cursor-based, one-time fetch) ──────────────────────
  static Future<QuerySnapshot<Map<String, dynamic>>> fetchMorePosts({
    required DocumentSnapshot lastDoc,
    required int pageSize,
  }) {
    return _posts
        .orderBy('dateTime', descending: true)
        .startAfterDocument(lastDoc)
        .limit(pageSize)
        .get();
  }

  // ── Create post ───────────────────────────────────────────────────────────
  static Future<String> uploadPostImage(File image, int index) async {
    final fn = 'posts/post_img_${DateTime.now().millisecondsSinceEpoch}_$index.jpg';
    await _supabase.storage
        .from('user-images')
        .upload(fn, image, fileOptions: const FileOptions(upsert: true));
    return _supabase.storage.from('user-images').getPublicUrl(fn);
  }

  static Future<String> uploadPostVideo(File video) async {
    if (!await video.exists() || await video.length() == 0) {
      throw Exception('Video file is empty or missing. Please pick it again.');
    }
    final fn = 'posts/post_vid_${DateTime.now().millisecondsSinceEpoch}.mp4';
    await _supabase.storage.from('user-images').upload(
          fn,
          video,
          fileOptions: const FileOptions(upsert: true, contentType: 'video/mp4'),
        );
    return _supabase.storage.from('user-images').getPublicUrl(fn);
  }

  static Future<String?> generateAndUploadThumbnail(File videoFile) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final thumbPath = await VideoThumbnail.thumbnailFile(
        video: videoFile.path,
        thumbnailPath: tempDir.path,
        imageFormat: ImageFormat.JPEG,
        maxHeight: 480,
        quality: 75,
      );
      if (thumbPath == null) return null;
      final thumbFile = File(thumbPath);
      if (!await thumbFile.exists()) return null;
      final fn = 'posts/post_thumb_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await _supabase.storage.from('user-images').upload(
            fn,
            thumbFile,
            fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'),
          );
      return _supabase.storage.from('user-images').getPublicUrl(fn);
    } catch (_) {
      return null;
    }
  }

  static Future<void> createPost(PostModel post) async {
    final ref = post.postId != null ? _posts.doc(post.postId) : _posts.doc();
    await ref.set(post.toMap());
  }

  static DocumentReference<Map<String, dynamic>> newPostRef() => _posts.doc();

  // ── Edit post ─────────────────────────────────────────────────────────────
  static Future<void> editPost({
    required String postId,
    required String newText,
    required String privacy,
    required List<String> hashtags,
  }) async {
    await _posts.doc(postId).update({
      'text': newText,
      'privacy': privacy,
      'hashtags': hashtags,
      'editedAt': DateTime.now().toIso8601String(),
    });
  }

  // ── Delete post ───────────────────────────────────────────────────────────
  static Future<void> deletePost(String postId) async {
    await _posts.doc(postId).delete();
  }

  static Future<void> deleteNotificationsForPost({
    required String uid,
    required String postId,
  }) async {
    final snap = await _firestore
        .collection('Users')
        .doc(uid)
        .collection('notifications')
        .where('postId', isEqualTo: postId)
        .get();
    if (snap.docs.isEmpty) return;
    final batch = _firestore.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  // ── Bookmark ──────────────────────────────────────────────────────────────
  static Future<void> setBookmarked({
    required String uid,
    required String postId,
    required bool bookmarked,
  }) async {
    final userRef = _firestore.collection('Users').doc(uid);
    final postRef = _posts.doc(postId);
    if (bookmarked) {
      await userRef.update({
        'bookmarkedPostIds': FieldValue.arrayUnion([postId]),
      });
      await postRef.update({'bookmarkCount': FieldValue.increment(1)});
    } else {
      await userRef.update({
        'bookmarkedPostIds': FieldValue.arrayRemove([postId]),
      });
      await postRef.update({'bookmarkCount': FieldValue.increment(-1)});
    }
  }

  // ── Reactions ─────────────────────────────────────────────────────────────
  static Future<void> applyReactionUpdate({
    required String postId,
    required Map<String, dynamic> update,
  }) async {
    await _posts.doc(postId).update(update);
  }

  // ── Comments ──────────────────────────────────────────────────────────────
  static DocumentReference<Map<String, dynamic>> newCommentRef(String postId) =>
      _posts.doc(postId).collection('comments').doc();

  static Future<void> addComment({
    required String postId,
    required DocumentReference<Map<String, dynamic>> ref,
    required Map<String, dynamic> data,
  }) async {
    await ref.set(data);
    await _posts.doc(postId).update({'commentsCount': FieldValue.increment(1)});
  }

  static Future<DocumentSnapshot<Map<String, dynamic>>> getPost(String postId) {
    return _posts.doc(postId).get();
  }

  static Future<void> deleteComment({
    required String postId,
    required String commentId,
  }) async {
    await _posts.doc(postId).collection('comments').doc(commentId).delete();
    await _posts.doc(postId).update({'commentsCount': FieldValue.increment(-1)});
  }

  static Future<void> deleteNotificationsForComment({
    required String uid,
    required String commentId,
  }) async {
    final snap = await _firestore
        .collection('Users')
        .doc(uid)
        .collection('notifications')
        .where('commentId', isEqualTo: commentId)
        .get();
    if (snap.docs.isEmpty) return;
    final batch = _firestore.batch();
    for (final d in snap.docs) {
      batch.delete(d.reference);
    }
    await batch.commit();
  }

  static Future<DocumentSnapshot<Map<String, dynamic>>> getComment({
    required String postId,
    required String commentId,
  }) {
    return _posts.doc(postId).collection('comments').doc(commentId).get();
  }

  static Future<void> updateCommentReactions({
    required String postId,
    required String commentId,
    required int likes,
    required int dislikes,
    required Map<String, dynamic> reactions,
  }) async {
    await _posts.doc(postId).collection('comments').doc(commentId).update({
      'likes': likes,
      'dislikes': dislikes,
      'reactions': reactions,
    });
  }

  // ── Replies ───────────────────────────────────────────────────────────────
  static DocumentReference<Map<String, dynamic>> newReplyRef({
    required String postId,
    required String commentId,
  }) =>
      _posts.doc(postId).collection('comments').doc(commentId).collection('replies').doc();

  static Future<void> addReply({
    required String postId,
    required String commentId,
    required DocumentReference<Map<String, dynamic>> ref,
    required Map<String, dynamic> data,
  }) async {
    await ref.set(data);
    await _posts
        .doc(postId)
        .collection('comments')
        .doc(commentId)
        .update({'repliesCount': FieldValue.increment(1)});
  }

  static Future<DocumentSnapshot<Map<String, dynamic>>> getReply({
    required String postId,
    required String commentId,
    required String replyId,
  }) {
    return _posts
        .doc(postId)
        .collection('comments')
        .doc(commentId)
        .collection('replies')
        .doc(replyId)
        .get();
  }

  static Future<void> updateReplyReactions({
    required String postId,
    required String commentId,
    required String replyId,
    required int likes,
    required int dislikes,
    required Map<String, dynamic> reactions,
  }) async {
    await _posts
        .doc(postId)
        .collection('comments')
        .doc(commentId)
        .collection('replies')
        .doc(replyId)
        .update({
      'likes': likes,
      'dislikes': dislikes,
      'reactions': reactions,
    });
  }
}
