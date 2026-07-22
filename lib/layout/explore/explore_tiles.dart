part of 'explore_screen.dart';

class _TrendingGrid extends StatelessWidget {
  const _TrendingGrid();

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final c = AppColors.of(context);
    return BlocBuilder<PostsCubit, PostsStates>(
      builder: (ctx, _) {
        final cubit  = PostsCubit.get(ctx);
        final sorted = [...cubit.posts]
          ..sort((a, b) => (b.likes + b.commentsCount * 2)
              .compareTo(a.likes + a.commentsCount * 2));
        final top = sorted.take(30).toList();

        if (top.isEmpty) {
          return const ExploreGridSkeleton();
        }

        // Build a masonry-style mixed layout:
        // Every 7 posts: 1 hero (full-width), then 2 medium side by side,
        // then a 3-column strip of 4 small tiles.
        return CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _sectionLabel('Trending Now', Icons.local_fire_department_rounded)),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                      (_, blockIdx) {
                    final base = blockIdx * 7;
                    if (base >= top.length) return null;

                    final hero   = top[base];
                    final medium = [
                      if (base + 1 < top.length) top[base + 1],
                      if (base + 2 < top.length) top[base + 2],
                    ];
                    final small = [
                      for (int k = 3; k < 7 && base + k < top.length; k++)
                        top[base + k],
                    ];

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Column(children: [
                        // Hero
                        _HeroTile(post: hero),
                        const SizedBox(height: 3),
                        // 2-medium row
                        if (medium.isNotEmpty)
                          IntrinsicHeight(
                            child: Row(
                              children: medium.asMap().entries.map((e) => Expanded(
                                child: Padding(
                                  padding: EdgeInsets.only(left: e.key > 0 ? 3 : 0),
                                  child: _MediumTile(post: e.value),
                                ),
                              )).toList(),
                            ),
                          ),
                        if (medium.isNotEmpty) const SizedBox(height: 3),
                        // 4-small strip
                        if (small.isNotEmpty)
                          Row(
                            children: small.asMap().entries.map((e) => Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(left: e.key > 0 ? 3 : 0),
                                child: _SmallTile(post: e.value),
                              ),
                            )).toList(),
                          ),
                        const SizedBox(height: 3),
                      ]),
                    );
                  },
                  childCount: (top.length / 7).ceil(),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        );
      },
    );
  }

  Widget _sectionLabel(String label, IconData icon) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(children: [
        Icon(icon, color: _gold, size: 16),
        const SizedBox(width: 7),
        Text(label, style: const TextStyle(
          color: _gold,
          fontSize: 14,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        )),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Tile base
// ─────────────────────────────────────────────────────────────────────────────
class _TileBase extends StatelessWidget {
  final PostModel post;
  final double aspectRatio;
  final double avatarRadius;
  final double iconSize;
  final double fontSize;
  final bool showText;

  const _TileBase({
    required this.post,
    required this.aspectRatio,
    this.avatarRadius = 10,
    this.iconSize     = 11,
    this.fontSize     = 10,
    this.showText     = false,
  });

  @override
  Widget build(BuildContext context) {
    final images   = (post.postImage ?? '').split(',').where((s) => s.isNotEmpty).toList();
    final hasImage = images.isNotEmpty;
    final hasVideo = post.postVideo?.isNotEmpty == true;
    final thumbUrl = post.videoThumbnail;

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => PostDetailsScreen(
          postId: post.postId!,
          navigationTarget: const PostNavigationTarget.none(),
        ),
      )),
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            color: AppColors.of(context).elevated,
            child: Stack(fit: StackFit.expand, children: [
              // Media
              if (hasVideo && (thumbUrl?.isNotEmpty == true))
                CachedNetworkImage(imageUrl: thumbUrl!, fit: BoxFit.cover,
                    placeholder: (_, _) => const ColoredBox(color: _surfaceHi),
                    errorWidget: (_, _, ___) => const ColoredBox(color: _surfaceHi))
              else if (hasImage)
                CachedNetworkImage(imageUrl: images.first, fit: BoxFit.cover,
                    placeholder: (_, _) => const ColoredBox(color: _surfaceHi),
                    errorWidget: (_, _, ___) => const ColoredBox(color: _surfaceHi))
              else if (hasVideo)
                  Container(color: AppColors.of(context).elevated, alignment: Alignment.center,
                      child: Icon(Icons.play_circle_fill_rounded, color: AppColors.of(context).textHint, size: iconSize * 3))
                else
                  Container(
                    color: AppColors.of(context).surface,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.all(10),
                    child: showText
                        ? Text(post.text ?? '',
                        style: TextStyle(color: AppColors.of(context).text, fontSize: fontSize),
                        maxLines: 4, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center)
                        : Icon(Icons.article_rounded, color: AppColors.of(context).textHint, size: iconSize * 2),
                  ),

              // Gradient overlay
              Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withValues(alpha: 0.65)],
                  stops: const [0.5, 1.0],
                ),
              ))),

              // Video play badge
              if (hasVideo)
                Positioned(top: 7, right: 7,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black54,
                      ),
                      child: Icon(Icons.play_arrow_rounded, color: AppColors.of(context).text, size: iconSize),
                    )),

              // Multi-image badge
              if (!hasVideo && images.length > 1)
                Positioned(top: 7, right: 7,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: Colors.black54,
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.photo_library_rounded, color: AppColors.of(context).text, size: iconSize - 1),
                        const SizedBox(width: 2),
                        Text('${images.length}', style: TextStyle(color: AppColors.of(context).text, fontSize: iconSize - 1, fontWeight: FontWeight.w600)),
                      ]),
                    )),

              // Bottom row: avatar + likes
              Positioned(bottom: 7, left: 7, right: 7,
                child: Row(children: [
                  // Avatar
                  CircleAvatar(
                    radius: avatarRadius,
                    backgroundColor: _border,
                    backgroundImage: (post.image ?? '').isNotEmpty
                        ? CachedNetworkImageProvider(post.image!) : null,
                    child: (post.image ?? '').isEmpty
                        ? Text((post.name ?? '?')[0].toUpperCase(),
                        style: TextStyle(color: AppColors.of(context).text, fontSize: avatarRadius * 0.8, fontWeight: FontWeight.bold))
                        : null,
                  ),
                  const Spacer(),
                  // Live like count
                  StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance.collection('Posts').doc(post.postId).snapshots(),
                    builder: (_, snap) {
                      int likes = post.likes;
                      if (snap.hasData && snap.data!.exists) {
                        final d  = snap.data!.data()!;
                        final rc = d['reactionCounts'] as Map<String, dynamic>? ?? {};
                        final sum = rc.values.map((v) => (v as num).toInt()).where((v) => v > 0).fold(0, (a, b) => a + b);
                        likes = sum > 0 ? sum : (d['likes'] as int? ?? 0);
                      }
                      return Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.favorite_rounded, color: _gold, size: iconSize),
                        const SizedBox(width: 3),
                        Text(_formatCount(likes), style: TextStyle(
                            color: AppColors.of(context).text, fontSize: iconSize - 1, fontWeight: FontWeight.w700)),
                      ]);
                    },
                  ),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  String _formatCount(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Tile variants
// ─────────────────────────────────────────────────────────────────────────────
class _HeroTile extends StatelessWidget {
  final PostModel post;
  const _HeroTile({required this.post});

  @override
  Widget build(BuildContext context) {
    final images   = (post.postImage ?? '').split(',').where((s) => s.isNotEmpty).toList();
    final hasImage = images.isNotEmpty;
    final hasVideo = post.postVideo?.isNotEmpty == true;
    final thumbUrl = post.videoThumbnail;

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => PostDetailsScreen(
          postId: post.postId!,
          navigationTarget: const PostNavigationTarget.none(),
        ),
      )),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(fit: StackFit.expand, children: [
            // Media
            if (hasVideo && (thumbUrl?.isNotEmpty == true))
              CachedNetworkImage(imageUrl: thumbUrl!, fit: BoxFit.cover,
                  placeholder: (_, _) => const ColoredBox(color: _surfaceHi),
                  errorWidget: (_, _, ___) => const ColoredBox(color: _surfaceHi))
            else if (hasImage)
              CachedNetworkImage(imageUrl: images.first, fit: BoxFit.cover,
                  placeholder: (_, _) => const ColoredBox(color: _surfaceHi),
                  errorWidget: (_, _, ___) => const ColoredBox(color: _surfaceHi))
            else
              Container(color: AppColors.of(context).surface, alignment: Alignment.center,
                  padding: const EdgeInsets.all(20),
                  child: Text(post.text ?? '',
                      style: TextStyle(color: AppColors.of(context).text, fontSize: 16),
                      maxLines: 5, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center)),

            // Rich gradient
            Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withValues(alpha: 0.75)],
                stops: const [0.35, 1.0],
              ),
            ))),

            // Top badge
            if (hasVideo)
              Positioned(top: 10, right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.play_arrow_rounded, color: AppColors.of(context).text, size: 14),
                      const SizedBox(width: 3),
                      Text('Video', style: TextStyle(color: AppColors.of(context).text, fontSize: 11, fontWeight: FontWeight.w600)),
                    ]),
                  )),

            // "Top Post" badge
            Positioned(top: 10, left: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _gold.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _gold.withValues(alpha: 0.5), width: 1),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: const [
                    Icon(Icons.local_fire_department_rounded, color: _gold, size: 11),
                    SizedBox(width: 4),
                    Text('#1 Trending', style: TextStyle(color: _gold, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.2)),
                  ]),
                )),

            // Bottom info
            Positioned(bottom: 12, left: 12, right: 12,
              child: Row(children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: _border,
                  backgroundImage: (post.image ?? '').isNotEmpty
                      ? CachedNetworkImageProvider(post.image!) : null,
                  child: (post.image ?? '').isEmpty
                      ? Text((post.name ?? '?')[0].toUpperCase(),
                      style: TextStyle(color: AppColors.of(context).text, fontSize: 10, fontWeight: FontWeight.bold))
                      : null,
                ),
                const SizedBox(width: 8),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(post.name ?? '', style: TextStyle(color: AppColors.of(context).text, fontSize: 13, fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis),
                  if ((post.text ?? '').isNotEmpty)
                    Text(post.text!, style: TextStyle(color: AppColors.of(context).text.withValues(alpha: 0.65), fontSize: 11),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                ])),
                const SizedBox(width: 8),
                StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance.collection('Posts').doc(post.postId).snapshots(),
                  builder: (_, snap) {
                    int likes = post.likes;
                    if (snap.hasData && snap.data!.exists) {
                      final d  = snap.data!.data()!;
                      final rc = d['reactionCounts'] as Map<String, dynamic>? ?? {};
                      final sum = rc.values.map((v) => (v as num).toInt()).where((v) => v > 0).fold(0, (a, b) => a + b);
                      likes = sum > 0 ? sum : (d['likes'] as int? ?? 0);
                    }
                    return _StatChip(count: likes, icon: Icons.favorite_rounded);
                  },
                ),
                const SizedBox(width: 6),
                _StatChip(count: post.commentsCount, icon: Icons.chat_bubble_rounded),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final int    count;
  final IconData icon;
  const _StatChip({required this.count, required this.icon});

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: _gold, size: 11),
        const SizedBox(width: 4),
        Text(_fmt(count), style: TextStyle(color: AppColors.of(context).text, fontSize: 11, fontWeight: FontWeight.w700)),
      ]),
    );
  }

  String _fmt(int n) => n >= 1000 ? '${(n / 1000).toStringAsFixed(1)}k' : '$n';
}

class _MediumTile extends StatelessWidget {
  final PostModel post;
  const _MediumTile({required this.post});
  @override
  Widget build(BuildContext context) => _TileBase(
    post: post, aspectRatio: 1.0,
    avatarRadius: 10, iconSize: 12, fontSize: 11, showText: true,
  );
}

class _SmallTile extends StatelessWidget {
  final PostModel post;
  const _SmallTile({required this.post});
  @override
  Widget build(BuildContext context) => _TileBase(
    post: post, aspectRatio: 1.0,
    avatarRadius: 8, iconSize: 10, fontSize: 9,
  );
}

