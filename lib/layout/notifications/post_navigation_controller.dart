import 'package:flutter/material.dart';
import '../../share/network/notification_router.dart';

class PostNavigationController {
  final ScrollController scrollController;
  final Map<String, GlobalKey> commentKeys;
  final Map<String, GlobalKey> replyKeys;
  final PostNavigationTarget target;
  final void Function(String commentId) onExpandComment;

  bool _hasExecuted = false;

  PostNavigationController({
    required this.scrollController,
    required this.commentKeys,
    required this.replyKeys,
    required this.target,
    required this.onExpandComment,
  });

  void execute() {
    if (_hasExecuted) return;
    _hasExecuted = true;

    if (target.isNone) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 400), () {
        _tryNavigate();
      });
    });
  }

  void _tryNavigate({int attempt = 0}) {
    if (attempt > 15) return;

    if (target.isReply && target.commentId != null) {
      final commentKey = commentKeys[target.commentId];

      if (commentKey?.currentContext == null) {
        _retry(attempt);
        return;
      }

      onExpandComment(target.commentId!);

      Future.delayed(const Duration(milliseconds: 500), () {
        final replyKey = replyKeys[target.replyId];

        if (replyKey?.currentContext == null) {
          _retry(attempt);
          return;
        }

        _scrollTo(replyKey!);
      });

      return;
    }

    if (target.isComment && target.commentId != null) {
      final key = commentKeys[target.commentId];

      if (key?.currentContext == null) {
        _retry(attempt);
        return;
      }

      _scrollTo(key!);
    }
  }

  void _scrollTo(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx == null) return;

    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeInOut,
      alignment: 0.2,
    );
  }

  void _retry(int attempt) {
    Future.delayed(const Duration(milliseconds: 300), () {
      _tryNavigate(attempt: attempt + 1);
    });
  }
}