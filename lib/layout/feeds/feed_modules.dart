part of 'feeds_screen.dart';

class _PostDigest extends StatelessWidget {
  final _FeedPalette palette;
  final String text;

  const _PostDigest({
    required this.palette,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.aqua.withValues(alpha: palette.isDark ? 0.10 : 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.aqua.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.auto_awesome_rounded, color: palette.aqua, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quick read',
                  style: TextStyle(
                    color: palette.text,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.muted,
                    fontSize: 12.5,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
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

class _SmartRecommendationModule extends StatelessWidget {
  final _FeedPalette palette;
  final VoidCallback onExplore;

  const _SmartRecommendationModule({
    required this.palette,
    required this.onExplore,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.elevated.withValues(alpha: palette.isDark ? 0.82 : 0.98),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _SoftIcon(
                icon: Icons.blur_on_rounded,
                palette: palette,
                accent: palette.aqua,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Made for your next scroll',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Fresh creators, live moments, and nearby conversations.',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.muted,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: onExplore,
                style: TextButton.styleFrom(
                  foregroundColor: palette.gold,
                  minimumSize: const Size(48, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                child: Text(AppStrings.of(context).exploreLabel),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _RecommendationTile(
                  icon: Icons.person_add_alt_1_rounded,
                  title: 'Creators',
                  subtitle: AppStrings.of(context).newVoices,
                  color: palette.gold,
                  palette: palette,
                  onTap: onExplore,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _RecommendationTile(
                  icon: Icons.sensors_rounded,
                  title: 'Live',
                  subtitle: 'Happening now',
                  color: palette.coral,
                  palette: palette,
                  onTap: onExplore,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _RecommendationTile(
                  icon: Icons.near_me_rounded,
                  title: 'Nearby',
                  subtitle: 'Local pulse',
                  color: palette.green,
                  palette: palette,
                  onTap: onExplore,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RecommendationTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final _FeedPalette palette;
  final VoidCallback onTap;

  const _RecommendationTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.palette,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          height: 104,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: palette.isDark ? 0.10 : 0.12),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withValues(alpha: 0.22)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 22),
              const Spacer(),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.text,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.muted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopicClusterModule extends StatelessWidget {
  final _FeedPalette palette;
  final List<String> tags;
  final ValueChanged<String> onOpenTag;

  const _TopicClusterModule({
    required this.palette,
    required this.tags,
    required this.onOpenTag,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            palette.gold.withValues(alpha: palette.isDark ? 0.12 : 0.18),
            palette.aqua.withValues(alpha: palette.isDark ? 0.08 : 0.12),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tag_rounded, color: palette.gold, size: 20),
              const SizedBox(width: 8),
              Text(
                'Topic clusters',
                style: TextStyle(
                  color: palette.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              Text(
                AppStrings.of(context).trending,
                style: TextStyle(
                  color: palette.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 9,
            runSpacing: 9,
            children: tags.map((tag) {
              return GestureDetector(
                onTap: () => onOpenTag(tag),
                child: _TextTag(label: '#$tag', palette: palette, large: true),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _FeedFooter extends StatelessWidget {
  final _FeedPalette palette;
  final PostsStates state;
  final bool hasMorePosts;

  const _FeedFooter({
    required this.palette,
    required this.state,
    required this.hasMorePosts,
  });

  @override
  Widget build(BuildContext context) {
    if (state is PostsLoadingMoreState) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 22),
        child: Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              color: palette.gold,
              strokeWidth: 2.4,
            ),
          ),
        ),
      );
    }

    if (hasMorePosts) {
      return const SizedBox(height: 18);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 18, 28, 28),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: palette.border,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            "You're all caught up",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: palette.text,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            AppStrings.of(context).noPostsMessage,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: palette.muted,
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
