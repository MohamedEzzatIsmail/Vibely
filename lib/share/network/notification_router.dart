import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../layout/feeds/post_details_screen.dart';
import '../../layout/chats/chat.dart';
import '../../layout/chats/chats_screen.dart';
import '../../layout/cubit/chat/chat_cubit.dart';
import '../../models/notification_model.dart';
import '../../models/user_model.dart';

class NotificationRouter {
  NotificationRouter._();

  static Future<void> open(BuildContext context, AppNotification n) async {
    // follow / blocked notifications have nothing to open — dismiss only
    if (n.type == NotificationType.follow || n.type == NotificationType.blocked) {
      return;
    }

    // message notifications point at a chat, not a post — handle separately
    if (n.type == NotificationType.message) {
      await _openChat(context, n);
      return;
    }

    if (n.type == NotificationType.mention && n.postId == null) {
      return;
    }

    if (n.postId == null) return;

    final postDoc = await FirebaseFirestore.instance
        .collection('Posts')
        .doc(n.postId)
        .get();

    if (!postDoc.exists) {
      _showDeletedMessage(context, 'Post was deleted');
      return;
    }

    switch (n.type) {
      case NotificationType.postLike:
        _push(context, n.postId!, const PostNavigationTarget.none());
        return;

      case NotificationType.postComment:
      case NotificationType.commentLike:
        _push(
          context,
          n.postId!,
          PostNavigationTarget.comment(commentId: n.commentId),
        );
        return;

      case NotificationType.commentReply:
        _push(
          context,
          n.postId!,
          PostNavigationTarget.reply(
            commentId: n.commentId,
            replyId: n.replyId,
          ),
        );
        return;

      case NotificationType.message:
        return;

      // follow: no post to open — just dismiss (notification already shown in bell)
      case NotificationType.follow:
        return;

      // mention: open the post that mentioned the user
      case NotificationType.mention:
        if (n.postId != null) {
          _push(context, n.postId!, const PostNavigationTarget.none());
        }
        return;

      // blocked: never actually reached (returns early above, before the
      // postId fetch) — case included only to satisfy exhaustiveness.
      case NotificationType.blocked:
        return;
    }
  }

  /// Opens the chat a `message` notification points at — a direct
  /// conversation with [AppNotification.fromUserId], or the group
  /// identified by [AppNotification.chatId] when [AppNotification.isGroup].
  static Future<void> _openChat(BuildContext context, AppNotification n) async {
    final chatId = n.chatId;
    if (chatId == null || chatId.isEmpty) return;

    if (n.isGroup) {
      final groupDoc = await FirebaseFirestore.instance
          .collection('Groups')
          .doc(chatId)
          .get();
      if (!context.mounted) return;
      final data = groupDoc.data();
      if (!groupDoc.exists || data == null) {
        _showDeletedMessage(context, 'This group no longer exists');
        return;
      }
      final group = GroupModel.fromJson(groupDoc.id, data);
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => GroupChatScreen(group: group)),
      );
      return;
    }

    if (n.fromUserId.isEmpty) return;
    final userDoc = await FirebaseFirestore.instance
        .collection('Users')
        .doc(n.fromUserId)
        .get();
    if (!context.mounted) return;
    final data = userDoc.data();
    if (!userDoc.exists || data == null) {
      _showDeletedMessage(context, 'This user no longer exists');
      return;
    }
    final user = UserModel.fromJson(data);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ChatScreen(user: user)),
    );
  }

  static void _push(
      BuildContext context,
      String postId,
      PostNavigationTarget target,
      ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PostDetailsScreen(
          postId: postId,
          navigationTarget: target,
        ),
      ),
    );
  }

  static void _showDeletedMessage(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }
}

enum _TargetKind { none, comment, reply }

class PostNavigationTarget {
  final _TargetKind _kind;
  final String? commentId;
  final String? replyId;

  const PostNavigationTarget._({
    required _TargetKind kind,
    this.commentId,
    this.replyId,
  }) : _kind = kind;

  const factory PostNavigationTarget.none() = _NoneTarget;

  factory PostNavigationTarget.comment({String? commentId}) =>
      PostNavigationTarget._(
        kind: _TargetKind.comment,
        commentId: commentId,
      );

  factory PostNavigationTarget.reply({
    String? commentId,
    String? replyId,
  }) =>
      PostNavigationTarget._(
        kind: _TargetKind.reply,
        commentId: commentId,
        replyId: replyId,
      );

  bool get isNone => _kind == _TargetKind.none;
  bool get isComment => _kind == _TargetKind.comment;
  bool get isReply => _kind == _TargetKind.reply;
}

class _NoneTarget extends PostNavigationTarget {
  const _NoneTarget() : super._(kind: _TargetKind.none);
}