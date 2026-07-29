/// All Firestore access for user notifications — reads, writes, and the
/// real-time notifications stream. Kept as a static-only class so
/// NotificationsCubit never touches Firestore directly.

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationRepository {
  NotificationRepository._();

  static final _firestore = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> _notifs(String uid) =>
      _firestore.collection('Users').doc(uid).collection('notifications');

  /// Live stream of this user's notifications, newest first.
  static StreamSubscription<QuerySnapshot<Map<String, dynamic>>> watchNotifications({
    required String uid,
    required void Function(QuerySnapshot<Map<String, dynamic>> snapshot) onData,
    required void Function(Object error) onError,
  }) {
    return _notifs(uid)
        .orderBy('dateTime', descending: true)
        .snapshots()
        .listen(onData, onError: onError);
  }

  // ── Send ──────────────────────────────────────────────────────────────────
  static DocumentReference<Map<String, dynamic>> newNotificationRef(String toUserId) =>
      _notifs(toUserId).doc();

  /// Writes a notification document at [ref]. The recipient is implied by
  /// which user's sub-collection [ref] belongs to.
  static Future<void> sendNotification({
    required String toUserId,
    required DocumentReference<Map<String, dynamic>> ref,
    required Map<String, dynamic> data,
  }) async {
    await ref.set(data);
  }

  // ── Mark seen / read ──────────────────────────────────────────────────────
  static Future<QuerySnapshot<Map<String, dynamic>>> fetchUnseen(String uid) {
    return _notifs(uid).where('isSeen', isEqualTo: false).get();
  }

  /// Marks every notification in [docs] as seen in a single batched write.
  static Future<void> markAllSeen({
    required String uid,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  }) async {
    if (docs.isEmpty) return;
    final batch = _firestore.batch();
    for (final doc in docs) {
      batch.update(doc.reference, {'isSeen': true});
    }
    await batch.commit();
  }

  static Future<void> markAsRead({
    required String uid,
    required String notificationId,
  }) async {
    await _notifs(uid).doc(notificationId).update({'isRead': true});
  }

  // ── Delete ────────────────────────────────────────────────────────────────
  static Future<void> deleteNotification({
    required String uid,
    required String id,
  }) async {
    await _notifs(uid).doc(id).delete();
  }

  static Future<QuerySnapshot<Map<String, dynamic>>> fetchByPostId({
    required String uid,
    required String postId,
  }) {
    return _notifs(uid).where('postId', isEqualTo: postId).get();
  }

  static Future<QuerySnapshot<Map<String, dynamic>>> fetchByCommentId({
    required String uid,
    required String commentId,
  }) {
    return _notifs(uid).where('commentId', isEqualTo: commentId).get();
  }

  static Future<void> deleteBatch({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  }) async {
    if (docs.isEmpty) return;
    final batch = _firestore.batch();
    for (final doc in docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  // ── Restore ───────────────────────────────────────────────────────────────
  static Future<void> restoreNotification({
    required String uid,
    required String? notificationId,
    required Map<String, dynamic> data,
  }) async {
    await _notifs(uid).doc(notificationId).set(data);
  }

  // ── Cleanup ───────────────────────────────────────────────────────────────
  static Future<QuerySnapshot<Map<String, dynamic>>> fetchAll(String uid) {
    return _notifs(uid).get();
  }

  static Future<void> deleteDoc(
      DocumentReference<Map<String, dynamic>> ref) async {
    await ref.delete();
  }
}
