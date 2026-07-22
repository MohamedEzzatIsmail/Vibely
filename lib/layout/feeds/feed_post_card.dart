part of 'feeds_screen.dart';

class _PremiumPostCard extends StatefulWidget {
  final int index;
  final PostModel post;
  final UserModel? currentUser;
  final _FeedPalette palette;

  const _PremiumPostCard({
    super.key,
    required this.index,
    required this.post,
    required this.currentUser,
    required this.palette,
  });

  @override
  State<_PremiumPostCard> createState() => _PremiumPostCardState();
}

class _PremiumPostCardState extends State<_PremiumPostCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _burstController;
  late final Animation<double> _burstScale;
  late final Animation<double> _burstOpacity;
  bool _expandedCaption = false;

  @override
  void initState() {
    super.initState();
    _burstController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 640),
    );
    _burstScale = Tween<double>(begin: 0.74, end: 1.38).animate(
      CurvedAnimation(parent: _burstController, curve: Curves.easeOutBack),
    );
    _burstOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: 1), weight: 18),
      TweenSequenceItem(tween: Tween(begin: 1, end: 1), weight: 32),
      TweenSequenceItem(tween: Tween(begin: 1, end: 0), weight: 50),
    ]).animate(
      CurvedAnimation(parent: _burstController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _burstController.dispose();
    super.dispose();
  }

  void _handleDoubleTap() {
    final id = widget.post.postId;
    if (id == null) return;
    HapticFeedback.lightImpact();
    PostsCubit.get(context).reactToPost(postId: id, reactionKey: 'love');
    _burstController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final palette = widget.palette;
    final hasMedia = post.postImages.isNotEmpty ||
        (post.postVideo != null && post.postVideo!.isNotEmpty);
    final isVideo = post.postVideo != null && post.postVideo!.isNotEmpty;
    final maxHeight = _mediaHeight(context, post);

    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 280 + (widget.index % 4) * 45),
      curve: Curves.easeOutCubic,
      tween: Tween(begin: 0, end: 1),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 18 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: GestureDetector(
        onDoubleTap: _handleDoubleTap,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              margin: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              decoration: BoxDecoration(
                color: palette.surface.withValues(alpha: palette.isDark ? 0.88 : 0.98),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: palette.border),
                boxShadow: [
                  BoxShadow(
                    color: palette.shadow.withValues(alpha: palette.isDark ? 0.42 : 1),
                    blurRadius: 24,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(26),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
                      child: _PostContextRow(
                        post: post,
                        palette: palette,
                        isVideo: isVideo,
                        hasMedia: hasMedia,
                      ),
                    ),
                    PostDetailHeader(
                      post: post,
                      currentUser: widget.currentUser,
                    ),
                    if (post.text != null && post.text!.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                        child: _PremiumPostText(
                          post: post,
                          palette: palette,
                          expanded: _expandedCaption,
                          onToggle: () {
                            setState(() {
                              _expandedCaption = !_expandedCaption;
                            });
                          },
                        ),
                      ),
                    if (_shouldShowDigest(post))
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: _PostDigest(
                          palette: palette,
                          text: _digestText(post.text!),
                        ),
                      ),
                    if (hasMedia)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(22),
                          child: PostDetailMedia(
                            post: post,
                            maxHeight: maxHeight,
                          ),
                        ),
                      ),
                    PostReactionBar(
                      post: post,
                      currentUser: widget.currentUser,
                    ),
                  ],
                ),
              ),
            ),
            IgnorePointer(
              child: AnimatedBuilder(
                animation: _burstController,
                builder: (_, _) {
                  if (_burstController.isDismissed) return const SizedBox.shrink();
                  return Opacity(
                    opacity: _burstOpacity.value,
                    child: Transform.scale(
                      scale: _burstScale.value,
                      child: Container(
                        width: 118,
                        height: 118,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withValues(alpha: 0.16),
                        ),
                        child: Icon(
                          Icons.favorite_rounded,
                          color: palette.coral,
                          size: 74,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  double _mediaHeight(BuildContext context, PostModel post) {
    final size = MediaQuery.sizeOf(context);
    if (post.postVideo != null && post.postVideo!.isNotEmpty) {
      return math.min(size.height * 0.62, 520);
    }
    if (post.postImages.length > 1) {
      return math.min(size.width * 0.92, 410);
    }
    return math.min(size.width * 0.98, 450);
  }

  bool _shouldShowDigest(PostModel post) {
    final text = post.text?.trim() ?? '';
    return text.length > 150;
  }

  String _digestText(String text) {
    final clean = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (clean.length <= 118) return clean;
    final sentenceEnd = clean.indexOf(RegExp(r'[.!?]'));
    if (sentenceEnd > 58 && sentenceEnd < 118) {
      return clean.substring(0, sentenceEnd + 1);
    }
    return '${clean.substring(0, 112)}...';
  }
}

class _PostContextRow extends StatelessWidget {
  final PostModel post;
  final _FeedPalette palette;
  final bool isVideo;
  final bool hasMedia;

  const _PostContextRow({
    required this.post,
    required this.palette,
    required this.isVideo,
    required this.hasMedia,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _InlinePill(
          label: post.privacy == 'public' ? AppStrings.of(context).forYou : AppStrings.of(context).closeCircle,
          icon: post.privacy == 'public'
              ? Icons.graphic_eq_rounded
              : Icons.lock_outline_rounded,
          color: post.privacy == 'public' ? palette.gold : palette.green,
          palette: palette,
        ),
        const SizedBox(width: 8),
        if (post.editedAt != null)
          _InlinePill(
            label: 'Updated',
            icon: Icons.history_rounded,
            color: palette.aqua,
            palette: palette,
          ),
        const Spacer(),
        if (hasMedia)
          _InlinePill(
            label: isVideo
                ? 'Video'
                : post.postImages.length > 1
                ? '${post.postImages.length} slides'
                : 'Photo',
            icon: isVideo ? Icons.play_arrow_rounded : Icons.collections_rounded,
            color: isVideo ? palette.coral : palette.aqua,
            palette: palette,
          ),
      ],
    );
  }
}

class _PremiumPostText extends StatelessWidget {
  final PostModel post;
  final _FeedPalette palette;
  final bool expanded;
  final VoidCallback onToggle;

  const _PremiumPostText({
    required this.post,
    required this.palette,
    required this.expanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final text = post.text ?? '';
    final isLong = text.length > 180;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: RichText(
            maxLines: expanded ? null : 4,
            overflow: expanded ? TextOverflow.visible : TextOverflow.ellipsis,
            text: TextSpan(children: _spans(text)),
          ),
        ),
        if (isLong)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: GestureDetector(
              onTap: onToggle,
              child: Text(
                expanded ? 'Show less' : 'Read more',
                style: TextStyle(
                  color: palette.gold,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        if (post.hashtags.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: post.hashtags.take(4).map((tag) {
                final clean = tag.startsWith('#') ? tag : '#$tag';
                return _TextTag(label: clean, palette: palette);
              }).toList(),
            ),
          ),
      ],
    );
  }

  List<TextSpan> _spans(String text) {
    final spans = <TextSpan>[];
    final regex = RegExp(r'(#\w+|@\w+)');
    var last = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > last) {
        spans.add(
          TextSpan(
            text: text.substring(last, match.start),
            style: TextStyle(
              color: palette.text.withValues(alpha: 0.9),
              fontSize: 15,
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      }
      spans.add(
        TextSpan(
          text: match.group(0),
          style: TextStyle(
            color: palette.gold,
            fontSize: 15,
            height: 1.45,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
      last = match.end;
    }

    if (last < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(last),
          style: TextStyle(
            color: palette.text.withValues(alpha: 0.9),
            fontSize: 15,
            height: 1.45,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    return spans;
  }
}
