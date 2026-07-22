// lib/layout/feeds/post_card.dart
//
// Single post card widget. Uses post.postImages (List<String>) directly.

import 'package:flutter/material.dart';
import '../../share/style/app_colors.dart';
import '../../layout/feeds/post_detail_header.dart';
import '../../layout/feeds/post_detail_media.dart';
import '../../layout/feeds/post_reaction_bar.dart';
import '../../models/post_model.dart';
import '../../models/user_model.dart';

class PostCard extends StatelessWidget {
  final PostModel post;
  final UserModel? currentUser;

  const PostCard({
    super.key,
    required this.post,
    this.currentUser,
  });

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.of(context).surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: avatar, name, timestamp, privacy badge, menu
            PostDetailHeader(post: post, currentUser: currentUser),

            // Post text with hashtag / mention highlighting
            if (post.text != null && post.text!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: _PostText(post: post),
              ),

            // Media: image carousel or lazy video player
            if (post.postImages.isNotEmpty || post.postVideo != null)
              PostDetailMedia(post: post),

            // Reaction / comment / bookmark bar
            PostReactionBar(post: post, currentUser: currentUser),
          ],
        ),
      ),
    );
  }
}

// ── Rich text with gold hashtags and @mentions ────────────────────────────────
class _PostText extends StatelessWidget {
  final PostModel post;
  const _PostText({required this.post});

  @override
  Widget build(BuildContext context) {
    final text = post.text ?? '';
    final spans = <TextSpan>[];
    final regex = RegExp(r'(#\w+|@\w+)');
    int last = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > last) {
        spans.add(TextSpan(
          text: text.substring(last, match.start),
          style: TextStyle(color: AppColors.of(context).textSub, fontSize: 14.5),
        ));
      }
      spans.add(TextSpan(
        text: match.group(0),
        style: const TextStyle(
          color: Color(0xFFe5c687),
          fontSize: 14.5,
          fontWeight: FontWeight.w600,
        ),
      ));
      last = match.end;
    }
    if (last < text.length) {
      spans.add(TextSpan(
        text: text.substring(last),
        style: TextStyle(color: AppColors.of(context).textSub, fontSize: 14.5),
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(text: TextSpan(children: spans)),
        if (post.editedAt != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              'Edited',
              style: TextStyle(
                color: AppColors.of(context).textHint,
                fontSize: 11,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }
}
