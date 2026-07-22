// lib/layout/notifications/notifications_screen.dart
//
// Fix: RefreshIndicator now calls the correct pattern to reload notifications.
// NotificationsCubit has NO getNotifications() method — notifications are loaded
// via a real-time stream started in setUser(). Refreshing re-calls setUser()
// which cancels and restarts the stream subscription, effectively refreshing.
// Empty state uses the illustrated EmptyNotificationsState widget.

import 'package:vibely/layout/cubit/notifications/notifications_cubit.dart';
import 'package:vibely/models/notification_model.dart';
import 'package:vibely/share/local/empty_state_widget.dart';
import 'package:vibely/share/local/skeleton_widgets.dart';
import 'package:flutter/material.dart';
import '../../share/local/app_strings.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import '../../share/network/notification_router.dart';
import '../../share/style/app_colors.dart';
import '../cubit/notifications/notifications_states.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NotificationsCubit, NotificationsState>(
      builder: (context, state) {
        final cubit = NotificationsCubit.get(context);

        final today = <AppNotification>[];
        final earlier = <AppNotification>[];

        for (final n in cubit.notifications) {
          try {
            final dt = DateTime.parse(n.dateTime).toLocal();
            final now = DateTime.now();
            final isToday = dt.year == now.year &&
                dt.month == now.month &&
                dt.day == now.day;
            if (isToday) {
              today.add(n);
            } else {
              earlier.add(n);
            }
          } catch (_) {
            earlier.add(n);
          }
        }

        // Determine loading state (first load before any stream data arrives)
        final isLoading = state is NotificationsLoading;

        return Scaffold(
          backgroundColor: AppColors.of(context).bg,
          appBar: AppBar(
            backgroundColor: AppColors.of(context).bg,
            elevation: 0,
            title: Text(
              AppStrings.of(context).notificationsTitle,
              style: TextStyle(
                  color: AppColors.of(context).text,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
            actions: [
              if (cubit.unreadCount > 0)
                TextButton(
                  onPressed: () => cubit.markAllAsSeen(),
                  child: Text(
                    AppStrings.of(context).markAllRead,
                    style: const TextStyle(
                        color: Color(0xFFe5c687), fontSize: 13),
                  ),
                ),
            ],
          ),
          body: RefreshIndicator(
            color: const Color(0xFFe5c687),
            backgroundColor: AppColors.of(context).surface,
            onRefresh: () async {
              // Re-trigger the stream by calling setUser again.
              // This cancels the existing subscription and starts fresh.
              if (cubit.currentUserId != null) {
                cubit.setUser(cubit.currentUserId!);
              }
              // Give the stream a moment to emit
              await Future.delayed(const Duration(milliseconds: 500));
            },
            child: isLoading
                ? ListView.builder(
                    itemCount: 6,
                    itemBuilder: (_, _) => const NotificationTileSkeleton(),
                  )
                : cubit.notifications.isEmpty
                    ? ListView(
                        // ListView so RefreshIndicator works on empty state
                        children: const [
                          SizedBox(height: 120),
                          EmptyNotificationsState(),
                        ],
                      )
                    : ListView(
                        padding:
                            const EdgeInsets.symmetric(vertical: 10),
                        children: [
                          if (today.isNotEmpty)
                            _buildSection('Today', today, context),
                          if (earlier.isNotEmpty)
                            _buildSection('Earlier', earlier, context),
                        ],
                      ),
          ),
        );
      },
    );
  }

  Widget _buildSection(
      String title, List<AppNotification> list, BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            title,
            style: TextStyle(
              color: AppColors.of(context).textHint,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
        ...list.map((n) => _dismissibleItem(n, context)),
      ],
    );
  }

  Widget _dismissibleItem(AppNotification n, BuildContext context) {
    return Dismissible(
      key: ValueKey(n.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) {
        final cubit = NotificationsCubit.get(context);
        cubit.deleteNotification(n.id!);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.of(context).notificationDeleted),
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'UNDO',
              onPressed: () => cubit.restoreNotification(n),
            ),
          ),
        );
      },
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        padding: const EdgeInsets.only(right: 20),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: Colors.red.shade700,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      child: _NotificationItem(notification: n),
    );
  }
}

// ── Notification tile ─────────────────────────────────────────────────────────
class _NotificationItem extends StatelessWidget {
  final AppNotification notification;

  const _NotificationItem({required this.notification});

  @override
  Widget build(BuildContext context) {
    final n = notification;

    return InkWell(
      onTap: () {
        if (n.id != null) {
          NotificationsCubit.get(context).markAsRead(n.id!);
        }
        NotificationRouter.open(context, n);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: n.isRead
              ? AppColors.of(context).surface
              : AppColors.of(context).unread,
          borderRadius: BorderRadius.circular(14),
          border: n.isRead
              ? Border.all(color: Colors.white.withValues(alpha: 0.05))
              : Border.all(
                  color: const Color(0xFFe5c687).withValues(alpha: 0.2)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar + unread dot
            Stack(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: Colors.white12,
                  backgroundImage: n.fromUserImage.isNotEmpty
                      ? NetworkImage(n.fromUserImage)
                      : null,
                  child: n.fromUserImage.isEmpty
                      ? const Icon(Icons.person,
                          color: Colors.white38, size: 22)
                      : null,
                ),
                if (!n.isRead)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: const Color(0xFFe5c687),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: AppColors.of(context).unread, width: 2),
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(width: 12),

            // Text content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: n.fromUserName,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.of(context).text,
                            fontSize: 14,
                          ),
                        ),
                        TextSpan(
                          text: ' ${_actionText(n.type)}',
                          style: TextStyle(
                              color: AppColors.of(context).textSub, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  if (n.text != null && n.text!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      n.text!,
                      style: TextStyle(
                          color: AppColors.of(context).textHint, fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(n.dateTime),
                    style: TextStyle(
                        color: AppColors.of(context).textHint, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _actionText(NotificationType t) {
    switch (t) {
      case NotificationType.postLike:
        return 'reacted to your post';
      case NotificationType.postComment:
        return 'commented on your post';
      case NotificationType.commentLike:
        return 'liked your comment';
      case NotificationType.commentReply:
        return 'replied to your comment';
      case NotificationType.message:
        return 'sent you a message';
      case NotificationType.follow:
        return 'started following you';
      case NotificationType.mention:
        return 'mentioned you';
      case NotificationType.blocked:
        return 'blocked you';
    }
  }

  String _formatTime(String dateTime) {
    try {
      final dt = DateTime.parse(dateTime).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return '';
    }
  }
}
