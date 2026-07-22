part of 'feeds_screen.dart';

class _PremiumBackdrop extends StatelessWidget {
  final _FeedPalette palette;

  const _PremiumBackdrop({required this.palette});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            palette.backgroundAlt,
            palette.background,
            palette.background,
          ],
          stops: const [0, 0.34, 1],
        ),
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _FeedTopBarDelegate extends SliverPersistentHeaderDelegate {
  final _FeedPalette palette;
  final double topInset;
  final bool isScrolled;
  final UserModel? user;
  final int postCount;
  final VoidCallback onSearch;
  final VoidCallback onNotifications;
  final VoidCallback onMessages;
  final VoidCallback onCreate;

  const _FeedTopBarDelegate({
    required this.palette,
    required this.topInset,
    required this.isScrolled,
    required this.user,
    required this.postCount,
    required this.onSearch,
    required this.onNotifications,
    required this.onMessages,
    required this.onCreate,
  });

  @override
  double get maxExtent => topInset + 132;

  @override
  double get minExtent => topInset + 82;

  @override
  Widget build(
      BuildContext context,
      double shrinkOffset,
      bool overlapsContent,
      ) {
    final collapseT =
    (shrinkOffset / math.max(1, maxExtent - minExtent)).clamp(0.0, 1.0);
    final searchOpacity = (1 - collapseT).clamp(0.0, 1.0);
    final showShadow = overlapsContent || isScrolled || collapseT > 0.15;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: showShadow ? 22 : 12,
          sigmaY: showShadow ? 22 : 12,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Color.lerp(
              palette.background.withValues(alpha: 0.44),
              palette.glass,
              collapseT,
            ),
            border: Border(
              bottom: BorderSide(
                color: showShadow ? palette.border : Colors.transparent,
              ),
            ),
            boxShadow: showShadow
                ? [
              BoxShadow(
                color: palette.shadow,
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ]
                : const [],
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, topInset + 8, 16, 10),
            child: Column(
              children: [
                SizedBox(
                  height: 48,
                  child: Row(
                    children: [
                      _ProfileSignal(user: user, palette: palette),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _BrandLockup(
                          palette: palette,
                          user: user,
                          postCount: postCount,
                          collapsed: collapseT > 0.55,
                        ),
                      ),
                      BlocBuilder<NotificationsCubit, NotificationsState>(
                        builder: (context, _) {
                          final unread =
                              NotificationsCubit.get(context).unreadCount;
                          return _HeaderActionButton(
                            tooltip: 'Notifications',
                            icon: Icons.notifications_none_rounded,
                            palette: palette,
                            badgeCount: unread,
                            onTap: onNotifications,
                          );
                        },
                      ),
                    ],
                  ),
                ),
                ClipRect(
                  child: Align(
                    heightFactor: searchOpacity,
                    child: Opacity(
                      opacity: searchOpacity,
                      child: Transform.translate(
                        offset: Offset(0, -8 * collapseT),
                        child: Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: _SmartSearchBar(
                            palette: palette,
                            onTap: onSearch,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _FeedTopBarDelegate oldDelegate) {
    return palette != oldDelegate.palette ||
        topInset != oldDelegate.topInset ||
        isScrolled != oldDelegate.isScrolled ||
        user != oldDelegate.user ||
        postCount != oldDelegate.postCount;
  }
}

class _ProfileSignal extends StatelessWidget {
  final UserModel? user;
  final _FeedPalette palette;

  const _ProfileSignal({required this.user, required this.palette});

  @override
  Widget build(BuildContext context) {
    final image = user?.image;

    return Semantics(
      label: 'Current profile',
      image: true,
      child: Container(
        width: 46,
        height: 46,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            //colors: [palette.gold, palette.coral, palette.aqua],
            colors: [palette.gold, palette.glass],
          ),
          boxShadow: [
            BoxShadow(
              color: palette.gold.withValues(alpha: 0.16),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: CircleAvatar(
          backgroundColor: palette.surface,
          backgroundImage: image != null && image.isNotEmpty
              ? CachedNetworkImageProvider(image)
              : null,
          child: image == null || image.isEmpty
              ? Icon(Icons.person_rounded, color: palette.faint, size: 22)
              : null,
        ),
      ),
    );
  }
}

class _BrandLockup extends StatelessWidget {
  final _FeedPalette palette;
  final UserModel? user;
  final int postCount;
  final bool collapsed;

  const _BrandLockup({
    required this.palette,
    required this.user,
    required this.postCount,
    required this.collapsed,
  });

  @override
  Widget build(BuildContext context) {
    final firstName = (user?.name ?? '').trim().split(' ').first;
    final greeting = _greeting();
    final subtitle = firstName.isEmpty
        ? '$greeting. $postCount fresh posts'
        : '$greeting, $firstName';

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: collapsed
          ? Text(
        'Vibely',
        key: const ValueKey('brand-collapsed'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: palette.text,
          fontSize: 24,
          fontWeight: FontWeight.w900,
          letterSpacing: 0,
        ),
      )
          : Column(
        key: const ValueKey('brand-expanded'),
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Vibely',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: palette.text,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: palette.muted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }
}

class _HeaderActionButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final _FeedPalette palette;
  final VoidCallback onTap;
  final int badgeCount;
  final Color? accent;
  final bool filled;

  const _HeaderActionButton({
    required this.tooltip,
    required this.icon,
    required this.palette,
    required this.onTap,
    this.badgeCount = 0,
    this.accent,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = accent ?? palette.text;
    final bg = filled
        ? color
        : palette.surface.withValues(alpha: palette.isDark ? 0.72 : 0.86);

    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: bg,
                    border: Border.all(
                      color: filled ? Colors.transparent : palette.border,
                    ),
                  ),
                  child: Icon(
                    icon,
                    color: filled ? Colors.black : color,
                    size: 21,
                  ),
                ),
                if (badgeCount > 0)
                  Positioned(
                    top: -3,
                    right: -3,
                    child: _CountBadge(
                      count: badgeCount,
                      palette: palette,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SmartSearchBar extends StatelessWidget {
  final _FeedPalette palette;
  final VoidCallback onTap;

  const _SmartSearchBar({
    required this.palette,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: AppStrings.of(context).searchVibely,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: palette.surface.withValues(alpha: palette.isDark ? 0.78 : 0.94),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: palette.border),
          ),
          child: Row(
            children: [
              Icon(Icons.search_rounded, color: palette.muted, size: 21),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  AppStrings.of(context).searchPeoplePosts,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.muted,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _InlinePill(
                label: 'Live',
                icon: Icons.sensors_rounded,
                color: palette.green,
                palette: palette,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StorySpotlight extends StatelessWidget {
  final _FeedPalette palette;
  final VoidCallback onCreate;

  const _StorySpotlight({
    required this.palette,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    return const StoriesBar();
  }
}



class _ComposerTool extends StatelessWidget {
  final IconData icon;
  final _FeedPalette palette;

  const _ComposerTool({
    required this.icon,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: palette.elevated,
        border: Border.all(color: palette.border),
      ),
      child: Icon(icon, color: palette.gold, size: 19),
    );
  }
}
