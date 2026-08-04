import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../models/notification_model.dart';
import '../../../services/repositories/notification_repository.dart';
import '../../../services/push_dispatcher.dart';
import 'notifications_states.dart';

class NotificationsCubit extends Cubit<NotificationsState> {
  NotificationsCubit() : super(NotificationsInitial());

  static NotificationsCubit get(context) => BlocProvider.of(context);

  String? currentUserId;
  List<AppNotification> notifications = [];
  int unreadCount = 0;
  StreamSubscription? _sub;

  void setUser(String userId) {
    if (currentUserId == userId) return; // already listening
    currentUserId = userId;
    _sub?.cancel();
    _deleteOldNotifications();
    _listenToNotifications();
  }

  void _listenToNotifications() {
    if (currentUserId == null) return;

    _sub = NotificationRepository.watchNotifications(
      uid: currentUserId!,
      onData: (snapshot) {
        // Rebuild from authoritative Firestore snapshot — no local mutation
        notifications = snapshot.docs
            .map((e) => AppNotification.fromJson(e.data()))
            .toList();

        unreadCount = notifications.where((n) => !n.isSeen).length;

        emit(NotificationsUpdated());
      },
      onError: (e) {
        emit(NotificationsError(e.toString()));
      },
    );
  }

  Future<void> sendNotification({
    required String toUserId,
    required AppNotification notification,
  }) async {
    // 🚨 safety check
    if (toUserId.isEmpty) return;

    // 🚨 prevent self-notifications (optional but recommended)
    if (notification.fromUserId == toUserId) return;

    final docRef = NotificationRepository.newNotificationRef(toUserId);

    final finalNotification = AppNotification(
      id: docRef.id,
      type: notification.type,
      fromUserId: notification.fromUserId,
      fromUserName: notification.fromUserName,
      fromUserImage: notification.fromUserImage,
      postId: notification.postId,
      commentId: notification.commentId,
      replyId: notification.replyId,
      chatId: notification.chatId,
      messageId: notification.messageId,
      text: notification.text,
      dateTime: notification.dateTime,
      isSeen: false,
      isRead: false,
      isGroup: notification.isGroup,
    );

    await NotificationRepository.sendNotification(
      toUserId: toUserId,
      ref: docRef,
      data: finalNotification.toMap(),
    );
    unawaited(PushDispatcher.notify(
      notification: finalNotification,
      toUserId: toUserId,
    ));
  }

  Future<void> markAllAsSeen() async {
    if (currentUserId == null) return;

    final snapshot = await NotificationRepository.fetchUnseen(currentUserId!);

    if (snapshot.docs.isEmpty) return;

    await NotificationRepository.markAllSeen(
      uid: currentUserId!,
      docs: snapshot.docs,
    );
  }

  Future<void> markAsRead(String notificationId) async {
    if (currentUserId == null) return;

    await NotificationRepository.markAsRead(
      uid: currentUserId!,
      notificationId: notificationId,
    );
  }

  Future<void> deleteNotification(String id) async {
    if (currentUserId == null) return;
    // Stream listener will update local list automatically
    await NotificationRepository.deleteNotification(
      uid: currentUserId!,
      id: id,
    );
  }

  /// Called when a post is deleted — removes all notifications that reference it
  Future<void> deleteNotificationsForPost(String postId) async {
    if (currentUserId == null) return;
    final snap = await NotificationRepository.fetchByPostId(
      uid: currentUserId!,
      postId: postId,
    );
    if (snap.docs.isNotEmpty) {
      await NotificationRepository.deleteBatch(docs: snap.docs);
    }
  }

  /// Called when a comment is deleted — removes all notifications that reference it
  Future<void> deleteNotificationsForComment(String commentId) async {
    if (currentUserId == null) return;
    final snap = await NotificationRepository.fetchByCommentId(
      uid: currentUserId!,
      commentId: commentId,
    );
    if (snap.docs.isNotEmpty) {
      await NotificationRepository.deleteBatch(docs: snap.docs);
    }
  }

  Future<void> restoreNotification(AppNotification n) async {
    if (currentUserId == null) return;

    await NotificationRepository.restoreNotification(
      uid: currentUserId!,
      notificationId: n.id,
      data: n.toMap(),
    );
  }

  Future<void> _deleteOldNotifications() async {
    final cutoff = DateTime.now().subtract(const Duration(days: 30));

    final snapshot = await NotificationRepository.fetchAll(currentUserId!);

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final dt = DateTime.parse(data['dateTime']);

      if (dt.isBefore(cutoff)) {
        await NotificationRepository.deleteDoc(doc.reference);
      }
    }
  }
}
