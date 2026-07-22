part of 'post_details_screen.dart';

class _PostCard extends StatelessWidget {
  final PostModel   post;
  final PostsCubit  cubit;

  const _PostCard({required this.post, required this.cubit});

  String _fmt(String? dt) {
    if (dt == null) return '';
    try {
      final d = DateTime.parse(dt).toLocal();
      final diff = DateTime.now().difference(d);
      if (diff.inSeconds < 60) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24)   return '${diff.inHours}h ago';
      if (diff.inDays < 7)     return '${diff.inDays}d ago';
      return '${d.day}/${d.month}/${d.year}';
    } catch (_) { return ''; }
  }

  TextDirection _dir(String t) =>
      RegExp(r'[\u0600-\u06FF]').hasMatch(t) ? TextDirection.rtl : TextDirection.ltr;

  @override
  Widget build(BuildContext context) {
    final userId     = cubit.currentUser?.uid;
    final myReaction = post.myReaction(userId);

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
      margin: const EdgeInsets.fromLTRB(10, 8, 10, 0),
      decoration: BoxDecoration(
        color: AppColors.of(context).surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF21262d), width: 0.8),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFF21262d),
                  backgroundImage: (post.image ?? '').isNotEmpty
                      ? NetworkImage(post.image!) : null,
                  child: (post.image ?? '').isEmpty
                      ? Text((post.name ?? '?')[0].toUpperCase(),
                      style: TextStyle(color: AppColors.of(context).text, fontWeight: FontWeight.bold))
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(post.name ?? '',
                          style: TextStyle(color: AppColors.of(context).text,
                              fontWeight: FontWeight.w600, fontSize: 14)),
                      Text(_fmt(post.dateTime),
                          style: const TextStyle(color: Colors.grey, fontSize: 11)),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_horiz_rounded, color: Colors.grey, size: 20),
                  color: const Color(0xFF21262d),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onSelected: (v) {
                    if (v == 'delete') { cubit.deletePost(post.postId!); Navigator.pop(context); }
                    if (v == 'bookmark') cubit.toggleBookmark(post.postId!);
                    if (v == 'report') {}
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'bookmark', child: Row(children: [
                      Icon(cubit.currentUser?.hasBookmarked(post.postId ?? '') == true
                          ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
                          color: const Color(0xFFe5c687), size: 18),
                      const SizedBox(width: 10),
                      Text(cubit.currentUser?.hasBookmarked(post.postId ?? '') == true
                          ? 'Unsave' : 'Save',
                          style: TextStyle(color: AppColors.of(context).text, fontSize: 14)),
                    ])),
                    if (cubit.currentUser?.uid == post.uid)
                      PopupMenuItem(value: 'delete', child: Row(children: [
                        const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                        const SizedBox(width: 10),
                        Text(AppStrings.of(context).deletePost, style: const TextStyle(color: Colors.redAccent, fontSize: 14)),
                      ])),
                  ],
                ),
              ],
            ),
          ),

          // Text
          if (post.text != null && post.text!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Directionality(
                textDirection: _dir(post.text!),
                child: Text(post.text!,
                    style: const TextStyle(
                        color: Color(0xFFE6EDF3), fontSize: 15, height: 1.45)),
              ),
            ),

          // Images
          if (post.postImage != null && post.postImage!.isNotEmpty)
            _PostImages(imageUrls: post.postImage!.split(',')
                .where((s) => s.trim().isNotEmpty).toList()),

          // Video
          if (post.postVideo != null && post.postVideo!.isNotEmpty)
            _PostVideoPlayer(videoUrl: post.postVideo!, thumbnailUrl: post.videoThumbnail),

          // Reaction summary
          if (post.reactionCounts.values.any((v) => v > 0))
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
              child: _ReactionSummary(counts: post.reactionCounts),
            ),

          const Divider(color: Color(0xFF21262d), height: 1, thickness: 0.5),

          // Action bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                // Emoji reaction
                Expanded(
                  child: _EmojiReactionButton(
                    post:        post,
                    myReaction:  myReaction,
                    onReact: (key) => cubit.reactToPost(
                        postId: post.postId!, reactionKey: key),
                  ),
                ),
                // Comment count
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.comment_outlined,
                            color: Colors.grey, size: 20),
                        if (post.commentsCount > 0) ...[
                          const SizedBox(width: 5),
                          Text('${post.commentsCount}',
                              style: const TextStyle(color: Colors.grey)),
                        ],
                      ],
                    ),
                  ),
                ),
                // Share
                Expanded(
                  child: GestureDetector(
                    onTap: () => SharePostSheet.show(context, post),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Icon(Icons.reply_rounded, color: Colors.grey, size: 20),
                        const SizedBox(width: 5),
                        Text(AppStrings.of(context).share, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                      ]),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  EMOJI REACTION BUTTON
// ══════════════════════════════════════════════════════════════════════════════
class _EmojiReactionButton extends StatefulWidget {
  final PostModel  post;
  final String?    myReaction;
  final void Function(String) onReact;

  const _EmojiReactionButton({
    required this.post, required this.myReaction, required this.onReact,
  });

  @override
  State<_EmojiReactionButton> createState() => _EmojiReactionButtonState();
}

class _EmojiReactionButtonState extends State<_EmojiReactionButton>
    with SingleTickerProviderStateMixin {
  OverlayEntry? _overlay;
  late AnimationController _animCtrl;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 180));
  }

  @override
  void dispose() { _removeOverlay(); _animCtrl.dispose(); super.dispose(); }

  void _showPicker() {
    if (_overlay != null) return;
    final box = context.findRenderObject() as RenderBox;
    final pos = box.localToGlobal(Offset.zero);

    _overlay = OverlayEntry(builder: (_) => GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: _removeOverlay,
      child: Stack(children: [
        Positioned(
          left: pos.dx - 8,
          top:  pos.dy - 76,
          child: ScaleTransition(
            scale: CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutBack),
            alignment: Alignment.bottomLeft,
            child: _ReactionPickerWidget(onSelect: (key) {
              _removeOverlay();
              widget.onReact(key);
            }),
          ),
        ),
      ]),
    ));

    Overlay.of(context).insert(_overlay!);
    _animCtrl.forward(from: 0);
  }

  void _removeOverlay() {
    _overlay?.remove();
    _overlay = null;
  }

  @override
  Widget build(BuildContext context) {
    final r = _reactionByKey(widget.myReaction);
    final reacted = widget.myReaction != null;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onReact(reacted ? widget.myReaction! : 'like');
      },
      onLongPress: () {
        HapticFeedback.mediumImpact();
        _showPicker();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: reacted ? (r?.bgColor ?? const Color(0xFF1C2A3A)) : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: Icon(
              r?.icon ?? Icons.thumb_up_outlined,
              color: reacted ? (r?.color ?? const Color(0xFF4A90D9)) : Colors.grey,
              size: 20,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            r?.label ?? (widget.post.totalReactions() > 0
                ? '${widget.post.totalReactions()}' : 'Like'),
            style: TextStyle(
              color: reacted ? (r?.color ?? const Color(0xFF4A90D9)) : Colors.grey,
              fontWeight: reacted ? FontWeight.bold : FontWeight.normal,
              fontSize: 13,
            ),
          ),
        ]),
      ),
    );
  }
}

class _ReactionPickerWidget extends StatefulWidget {
  final void Function(String) onSelect;
  const _ReactionPickerWidget({required this.onSelect});
  @override
  State<_ReactionPickerWidget> createState() => _ReactionPickerWidgetState();
}

class _ReactionPickerWidgetState extends State<_ReactionPickerWidget> {
  String? _hovered;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF21262d),
          borderRadius: BorderRadius.circular(40),
          border: Border.all(color: const Color(0xFF30363d)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 6))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: _reactions.map((r) {
            final hov = _hovered == r.key;
            return GestureDetector(
              onTap: () => widget.onSelect(r.key),
              child: MouseRegion(
                onEnter: (_) => setState(() => _hovered = r.key),
                onExit:  (_) => setState(() => _hovered = null),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOut,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  transform: hov
                      ? (Matrix4.identity()..translate(0.0, -8.0)..scale(1.25))
                      : Matrix4.identity(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 42, height: 42,
                        decoration: BoxDecoration(
                          color: hov ? r.bgColor : r.bgColor.withValues(alpha: 0.6),
                          shape: BoxShape.circle,
                          boxShadow: hov ? [BoxShadow(color: r.color.withValues(alpha: 0.4), blurRadius: 8)] : [],
                        ),
                        child: Icon(r.icon, color: r.color, size: 22),
                      ),
                      if (hov) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                              color: const Color(0xFF30363d), borderRadius: BorderRadius.circular(6)),
                          child: Text(r.label,
                              style: TextStyle(color: AppColors.of(context).text, fontSize: 10, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _ReactionSummary extends StatelessWidget {
  final Map<String, int> counts;
  const _ReactionSummary({required this.counts});

  @override
  Widget build(BuildContext context) {
    final active = counts.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = active.fold(0, (s, e) => s + e.value);
    if (total == 0) return const SizedBox.shrink();

    return Row(children: [
      SizedBox(
        height: 22,
        width: active.length <= 3 ? active.length * 18.0 + 4 : 58,
        child: Stack(
          children: active.take(3).toList().asMap().entries.map((entry) {
            final r = _reactionByKey(entry.value.key);
            return Positioned(
              left: entry.key * 16.0,
              child: Container(
                width: 22, height: 22,
                decoration: BoxDecoration(
                  color: r?.bgColor ?? const Color(0xFF21262d),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.of(context).surface, width: 1.5),
                ),
                child: Icon(r?.icon ?? Icons.thumb_up_rounded, size: 12, color: r?.color ?? Colors.grey),
              ),
            );
          }).toList(),
        ),
      ),
      const SizedBox(width: 6),
      Text('$total', style: const TextStyle(color: Colors.grey, fontSize: 13)),
    ]);
  }
}

