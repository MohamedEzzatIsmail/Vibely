import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/notification_model.dart';
import '../models/user_model.dart';
import 'push_dispatcher.dart';

class NotificationService {
  NotificationService._();

  static final _fs = FirebaseFirestore.instance;

  /// Checks whether the recipient has enabled this notification type.
  static bool _isTypeEnabled(UserModel u, NotificationType type) {
    if (!u.notificationsEnabled) return false;
    switch (type) {
      case NotificationType.postLike:
        return u.notifyOnPostLike;
      case NotificationType.postComment:
        return u.notifyOnComment;
      case NotificationType.commentLike:
        return u.notifyOnCommentLike;
      case NotificationType.commentReply:
        return u.notifyOnReply;
      case NotificationType.message:
        return u.notifyOnMessage;
      case NotificationType.follow:
        return u.notifyOnFollow;
      case NotificationType.mention:
        // FIX: was incorrectly returning notifyOnPostLike
        return u.notifyOnMention;
      case NotificationType.blocked:
        // Block notices are account-safety related — always deliver,
        // no per-type toggle for them.
        return true;
    }
  }

  /// Sends a notification to [toUserId] if their preferences allow it.
  static Future<void> send({
    required String currentUserId,
    required String currentUserName,
    required String currentUserImage,
    required String toUserId,
    required NotificationType type,
    String? postId,
    String? commentId,
    String? replyId,
    String? text,
  }) async {
    if (toUserId.isEmpty || toUserId == currentUserId) return;

    try {
      // Fetch recipient to check preferences
      final doc =
          await _fs.collection('Users').doc(toUserId).get();
      if (!doc.exists || doc.data() == null) return;
      final recipient = UserModel.fromJson(doc.data()!);

      if (!_isTypeEnabled(recipient, type)) return;

      final ref =
          _fs.collection('Users').doc(toUserId).collection('notifications').doc();

      final notification = AppNotification(
        id: ref.id,
        type: type,
        fromUserId: currentUserId,
        fromUserName: currentUserName,
        fromUserImage: currentUserImage,
        postId: postId,
        commentId: commentId,
        replyId: replyId,
        text: text,
        chatId: null,
        dateTime: DateTime.now().toIso8601String(),
      );

      await ref.set(notification.toMap());
      unawaited(PushDispatcher.notify(
        notification: notification,
        toUserId: toUserId,
      ));
    } catch (_) {
      // Notification failure should not crash the app
    }
  }
}
