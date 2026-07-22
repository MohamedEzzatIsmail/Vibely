// lib/layout/feeds/post_detail_header.dart
//
// Author row: avatar, name (with verified badge), timestamp,
// privacy badge pill, and owner kebab menu with Edit option.

import 'package:cached_network_image/cached_network_image.dart';
import '../../share/local/constants.dart';
import '../../share/style/app_colors.dart';
import 'package:flutter/material.dart';
import '../../share/local/app_strings.dart';

import '../../models/post_model.dart';
import '../../models/user_model.dart';
import '../cubit/post/post_cubit.dart';

class PostDetailHeader extends StatelessWidget {
  final PostModel post;
  final UserModel? currentUser;
  final bool showFullDate;

  const PostDetailHeader({
    super.key,
    required this.post,
    this.currentUser,
    this.showFullDate = false,
  });

  @override
  Widget build(BuildContext context) {
    final isOwner = currentUser?.uid != null &&
        currentUser!.uid == post.uid;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 4, 8),
      child: Row(
        children: [
          // ── Avatar ──────────────────────────────────────────────────────
          Container(
            width: 44,
            height: 44,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  kGold,
                  Color(0xE60D1117),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: kGold.withValues(alpha: 0.48),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.of(context).surface,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.06),
                  width: 1,
                ),
              ),
              child: CircleAvatar(
                radius: 20,
                backgroundColor: Colors.white12,
                backgroundImage:
                (post.image != null && post.image!.isNotEmpty)
                    ? CachedNetworkImageProvider(post.image!)
                    : null,
                child: (post.image == null || post.image!.isEmpty)
                    ? Icon(
                  Icons.person,
                  color: AppColors.of(context).textHint,
                  size: 20,
                )
                    : null,
              ),
            ),
          ),
          const SizedBox(width: 10),

          // ── Name + verified + timestamp + privacy ────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name row with optional verified badge
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        post.name ?? 'Unknown',
                        style: TextStyle(
                          color: AppColors.of(context).text,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Verified badge — set isVerified on UserModel to show
                    // Here we can't know without fetching post author's UserModel,
                    // so this is wired from outside if author model is provided.
                  ],
                ),

                const SizedBox(height: 2),

                // Timestamp + privacy badge
                Row(
                  children: [
                    Text(
                      _formatTime(post.dateTime),
                      style: TextStyle(
                          color: AppColors.of(context).textHint, fontSize: 11),
                    ),
                    const SizedBox(width: 6),
                    _PrivacyBadge(privacy: post.privacy ?? 'public'),
                  ],
                ),
              ],
            ),
          ),

          // ── Owner kebab menu ─────────────────────────────────────────────
          if (isOwner)
            _OwnerMenu(post: post)
          else
            _NonOwnerMenu(post: post, currentUser: currentUser),
        ],
      ),
    );
  }

  String _formatTime(String? dt) {
    if (dt == null) return '';
    try {
      final d = DateTime.parse(dt).toLocal();
      final diff = DateTime.now().difference(d);
      if (diff.inMinutes < 1) return 'just now';
      if (diff.inHours < 1) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${d.day}/${d.month}/${d.year}';
    } catch (_) {
      return '';
    }
  }
}

// ── Privacy badge pill ────────────────────────────────────────────────────────
class _PrivacyBadge extends StatelessWidget {
  final String privacy;
  const _PrivacyBadge({required this.privacy});

  @override
  Widget build(BuildContext context) {
    String label;
    Color color;
    switch (privacy) {
      case 'followers':
        label = '👥 Followers';
        color = Colors.blue.shade400;
        break;
      case 'private':
        label = '🔒 Only me';
        color = Colors.amber.shade600;
        break;
      default:
        label = '🌍 Public';
        color = Colors.white38;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 10),
      ),
    );
  }
}

// ── Non-owner kebab menu (bookmark only) ─────────────────────────────────────
class _NonOwnerMenu extends StatelessWidget {
  final PostModel post;
  final UserModel? currentUser;
  const _NonOwnerMenu({required this.post, required this.currentUser});

  @override
  Widget build(BuildContext context) {
    final isBookmarked =
        currentUser?.hasBookmarked(post.postId ?? '') == true;
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, color: AppColors.of(context).textHint, size: 20),
      color: const Color(0xFF21262D),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (value) {
        if (value == 'bookmark' && post.postId != null) {
          PostsCubit.get(context).toggleBookmark(post.postId!);
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'bookmark',
          child: Row(children: [
            Icon(
              isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
              color: isBookmarked ? kGold : Colors.white70,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              isBookmarked ? AppStrings.of(context).bookmarked : AppStrings.of(context).bookmarkPost,
              style: TextStyle(
                  color: isBookmarked ? kGold : Colors.white70),
            ),
          ]),
        ),
      ],
    );
  }
}

// ── Owner kebab menu ──────────────────────────────────────────────────────────
class _OwnerMenu extends StatelessWidget {
  final PostModel post;
  const _OwnerMenu({required this.post});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, color: AppColors.of(context).textHint, size: 20),
      color: const Color(0xFF21262D),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (value) => _handleMenuAction(context, value),
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'edit',
          child: Row(children: [
            Icon(Icons.edit_outlined, color: AppColors.of(context).textSub, size: 18),
            const SizedBox(width: 8),
            Text(AppStrings.of(context).editPostLabel, style: TextStyle(color: AppColors.of(context).textSub)),
          ]),
        ),
        PopupMenuItem(
          value: 'bookmark',
          child: Row(children: [
            Icon(Icons.bookmark_border_rounded, color: AppColors.of(context).textSub, size: 18),
            const SizedBox(width: 8),
            Text(AppStrings.of(context).bookmarkLabel, style: TextStyle(color: AppColors.of(context).textSub)),
          ]),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Row(children: [
            const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
            const SizedBox(width: 8),
            Text(AppStrings.of(context).deletePost, style: const TextStyle(color: Colors.redAccent)),
          ]),
        ),
      ],
    );
  }

  void _handleMenuAction(BuildContext context, String action) {
    if (action == 'edit') {
      _showEditSheet(context);
    } else if (action == 'delete') {
      _confirmDelete(context);
    } else if (action == 'bookmark') {
      if (post.postId != null) {
        PostsCubit.get(context).toggleBookmark(post.postId!);
      }
    }
  }

  void _showEditSheet(BuildContext context) {
    final controller = TextEditingController(text: post.text ?? '');
    String privacy = post.privacy ?? 'public';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.of(context).surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(AppStrings.of(context).editPost,
                  style: TextStyle(
                      color: AppColors.of(context).text,
                      fontSize: 17,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                maxLines: 6,
                maxLength: 2000,
                style: TextStyle(color: AppColors.of(context).text),
                decoration: InputDecoration(
                  hintText: 'What\'s on your mind?',
                  hintStyle: TextStyle(color: AppColors.of(context).textHint),
                  filled: true,
                  fillColor: AppColors.of(context).bg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                    BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Privacy selector
              DropdownButton<String>(
                value: privacy,
                dropdownColor: const Color(0xFF21262D),
                style: TextStyle(color: AppColors.of(context).textSub),
                items: [
                  DropdownMenuItem(value: 'public', child: Text(AppStrings.of(context).publicLabel)),
                  DropdownMenuItem(
                      value: 'followers', child: Text(AppStrings.of(context).followersLabel)),
                  DropdownMenuItem(
                      value: 'private', child: Text(AppStrings.of(context).onlyMeLabel)),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => privacy = v);
                },
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kGold,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () {
                    if (post.postId != null) {
                      PostsCubit.get(ctx).editPost(
                        postId: post.postId!,
                        newText: controller.text.trim(),
                        privacy: privacy,
                      );
                      Navigator.pop(ctx);
                    }
                  },
                  child: Text(AppStrings.of(context).saveChanges,
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.of(context).surface,
        title: Text(AppStrings.of(context).deletePostQuestion,
            style: TextStyle(color: AppColors.of(context).text)),
        content: Text(AppStrings.of(context).cannotUndone,
            style: TextStyle(color: AppColors.of(context).textSub)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppStrings.of(context).cancel,
                style: TextStyle(color: AppColors.of(context).textSub)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (post.postId != null) {
                PostsCubit.get(context).deletePost(post.postId!);
              }
            },
            child: Text(AppStrings.of(context).deletePost,
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}

// ── Verified name badge ───────────────────────────────────────────────────────
/// Use this wherever a user's name is displayed to show the gold verified tick.
class VerifiedNameRow extends StatelessWidget {
  final String name;
  final bool isVerified;
  final TextStyle? style;

  const VerifiedNameRow({
    super.key,
    required this.name,
    this.isVerified = false,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            name,
            style: style ??
                TextStyle(
                    color: AppColors.of(context).text,
                    fontWeight: FontWeight.w600,
                    fontSize: 14),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (isVerified) ...[
          const SizedBox(width: 3),
          const Icon(Icons.verified, color: kGold, size: 14),
        ]
      ],
    );
  }
}