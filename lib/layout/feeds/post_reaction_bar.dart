// lib/layout/feeds/post_reaction_bar.dart
//
// Modern reaction bar: react / comment / share row with:
//  • Long-press opens animated reaction tray (ScaleTransition + stagger)
//  • Tap-selected reaction spawns floating emoji OverlayEntry that rises & fades
//  • Share button (replaces old bookmark — bookmark moved to 3-dots menu)

import 'package:flutter/material.dart';
import '../../share/style/app_colors.dart';
import '../../share/local/app_strings.dart';
import '../../share/local/constants.dart';
import 'package:flutter/services.dart';

import '../../models/post_model.dart';
import '../../models/user_model.dart';
import '../cubit/post/post_cubit.dart';
import 'share_post_sheet.dart';

class PostReactionBar extends StatefulWidget {
  final PostModel post;
  final UserModel? currentUser;

  const PostReactionBar({
    super.key,
    required this.post,
    this.currentUser,
  });

  @override
  State<PostReactionBar> createState() => _PostReactionBarState();
}

class _PostReactionBarState extends State<PostReactionBar>
    with SingleTickerProviderStateMixin {
  bool _showTray = false;
  late AnimationController _trayCtrl;
  late Animation<double> _trayScale;
  OverlayEntry? _floatEntry;

  @override
  void initState() {
    super.initState();
    _trayCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _trayScale = CurvedAnimation(
      parent: _trayCtrl,
      curve: Curves.elasticOut,
    );
  }

  @override
  void dispose() {
    _trayCtrl.dispose();
    _floatEntry?.remove();
    super.dispose();
  }

  void _openTray() {
    HapticFeedback.selectionClick();
    setState(() => _showTray = true);
    _trayCtrl.forward(from: 0);
  }

  void _closeTray() {
    _trayCtrl.reverse().then((_) {
      if (mounted) setState(() => _showTray = false);
    });
  }

  void _pickReaction(BuildContext ctx, String key, Offset position) async {
    _closeTray();
    _spawnFloatingEmoji(ctx, key, position);
    await PostsCubit.get(ctx)
        .reactToPost(postId: widget.post.postId!, reactionKey: key);
  }

  void _spawnFloatingEmoji(BuildContext ctx, String key, Offset globalPos) {
    final emoji = PostReaction.byKey(key)?.emoji ?? '👍';
    _floatEntry?.remove();
    final overlay = Overlay.of(ctx);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _FloatingEmoji(
        emoji: emoji,
        startPos: globalPos,
        onDone: () {
          entry.remove();
          _floatEntry = null;
        },
      ),
    );
    _floatEntry = entry;
    overlay.insert(entry);
  }

  void _handleShare() {
    final postId = widget.post.postId;
    if (postId == null) return;
    HapticFeedback.lightImpact();
    // Real share sheet: copy link, send to a Vibely user/chat, or share
    // externally via the OS share sheet — all fully wired and working.
    SharePostSheet.show(context, widget.post);
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final myReaction = post.myReaction(widget.currentUser?.uid);
    final reactionEmoji = PostReaction.byKey(myReaction)?.emoji ?? '👍';
    final hasReacted = myReaction != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Tray ─────────────────────────────────────────────────────────
          if (_showTray)
            _ReactionTray(
              scale: _trayScale,
              onPick: (key) {
                final rb = context.findRenderObject() as RenderBox?;
                final offset =
                    rb?.localToGlobal(Offset.zero) ?? Offset.zero;
                _pickReaction(context, key, offset);
              },
            ),

          // ── Modern action bar ─────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(
              children: [
                // ── React button ──────────────────────────────────────────
                Expanded(
                  child: _ActionButton(
                    onTap: () {
                      if (post.postId == null) return;
                      final rb = context.findRenderObject() as RenderBox?;
                      final offset =
                          rb?.localToGlobal(const Offset(40, -30)) ??
                              Offset.zero;
                      _pickReaction(
                          context, myReaction ?? 'like', offset);
                    },
                    onLongPress: _openTray,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 150),
                      child: Row(
                        key: ValueKey(myReaction),
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: hasReacted
                                  ? kGold.withValues(alpha: 0.15)
                                  : Colors.transparent,
                            ),
                            // When reacted: show their chosen emoji
                            // When not reacted: show outline (inactive) thumbs up
                            child: hasReacted
                                ? Text(reactionEmoji,
                                style: const TextStyle(fontSize: 17))
                                : Icon(
                              Icons.thumb_up_alt_outlined,
                              color: AppColors.of(context).textHint,
                              size: 17,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            post.likes > 0
                                ? '${post.likes}'
                                : AppStrings.of(context).like,
                            style: TextStyle(
                              color: hasReacted
                                  ? kGold
                                  : Colors.white54,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                _Divider(),

                // ── Comment button ────────────────────────────────────────
                Expanded(
                  child: _ActionButton(
                    onTap: () {
                      if (post.postId != null) {
                        PostsCubit.get(context)
                            .openCommentsBottomSheet(context, post);
                      }
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline_rounded,
                          color: AppColors.of(context).textSub,
                          size: 17,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          post.commentsCount > 0
                              ? '${post.commentsCount}'
                              : AppStrings.of(context).comment,
                          style: TextStyle(
                            color: AppColors.of(context).textSub,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                _Divider(),

                // ── Share button ──────────────────────────────────────────
                Expanded(
                  child: _ActionButton(
                    onTap: _handleShare,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.reply_rounded,
                          color: AppColors.of(context).textSub,
                          size: 18,
                          // Mirror the icon to look like "share forward"
                          // textDirection trick below
                        ),
                        const SizedBox(width: 5),
                        Text(
                          AppStrings.of(context).share,
                          style: TextStyle(
                            color: AppColors.of(context).textSub,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Thin vertical divider between action buttons ──────────────────────────────
class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 20,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      color: Colors.white.withValues(alpha: 0.08),
    );
  }
}

// ── Tappable action button with ink splash ────────────────────────────────────
class _ActionButton extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _ActionButton({
    required this.child,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: child,
        ),
      ),
    );
  }
}

// ── Reaction count row ────────────────────────────────────────────────────────
class _ReactionCountRow extends StatelessWidget {
  final PostModel post;
  const _ReactionCountRow({required this.post});

  @override
  Widget build(BuildContext context) {
    final top = (post.reactionCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value)))
        .take(3)
        .toList();

    return Row(
      children: [
        ...top.map((e) {
          final r = PostReaction.byKey(e.key);
          return Text(r?.emoji ?? '', style: const TextStyle(fontSize: 13));
        }),
        const SizedBox(width: 4),
        Text(
          '${post.totalReactions()}',
          style: TextStyle(color: AppColors.of(context).textHint, fontSize: 12),
        ),
      ],
    );
  }
}

// ── Reaction tray with stagger animation ──────────────────────────────────────
class _ReactionTray extends StatefulWidget {
  final Animation<double> scale;
  final void Function(String key) onPick;

  const _ReactionTray({required this.scale, required this.onPick});

  @override
  State<_ReactionTray> createState() => _ReactionTrayState();
}

class _ReactionTrayState extends State<_ReactionTray>
    with TickerProviderStateMixin {
  final List<AnimationController> _controllers = [];
  final List<Animation<double>> _animations = [];

  @override
  void initState() {
    super.initState();
    for (var i = 0; i < PostReaction.all.length; i++) {
      final ctrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 200),
      );
      _controllers.add(ctrl);
      _animations.add(CurvedAnimation(parent: ctrl, curve: Curves.easeOut));
      Future.delayed(Duration(milliseconds: i * 30), () {
        if (mounted) ctrl.forward();
      });
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: widget.scale,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.of(context).elevated,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 12,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(PostReaction.all.length, (i) {
            final r = PostReaction.all[i];
            return ScaleTransition(
              scale: _animations[i],
              child: GestureDetector(
                onTap: () => widget.onPick(r.key),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(r.emoji, style: const TextStyle(fontSize: 26)),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

// ── Floating emoji overlay ────────────────────────────────────────────────────
class _FloatingEmoji extends StatefulWidget {
  final String emoji;
  final Offset startPos;
  final VoidCallback onDone;

  const _FloatingEmoji({
    required this.emoji,
    required this.startPos,
    required this.onDone,
  });

  @override
  State<_FloatingEmoji> createState() => _FloatingEmojiState();
}

class _FloatingEmojiState extends State<_FloatingEmoji>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;
  late Animation<double> _translate;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _opacity = Tween(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.5, 1.0)),
    );
    _translate = Tween(begin: 0.0, end: -80.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
    _ctrl.forward().then((_) => widget.onDone());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, _) => Positioned(
        left: widget.startPos.dx - 12,
        top: widget.startPos.dy + _translate.value,
        child: Opacity(
          opacity: _opacity.value,
          child: Text(widget.emoji, style: const TextStyle(fontSize: 28)),
        ),
      ),
    );
  }
}