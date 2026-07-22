part of 'feeds_screen.dart';

class _PremiumEmptyState extends StatelessWidget {
  final _FeedPalette palette;
  final VoidCallback onCreate;

  const _PremiumEmptyState({
    required this.palette,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(26),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 132,
            height: 132,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  palette.gold.withValues(alpha: 0.24),
                  palette.aqua.withValues(alpha: 0.16),
                ],
              ),
              border: Border.all(color: palette.border),
            ),
            child: Icon(
              Icons.add_photo_alternate_outlined,
              color: palette.gold,
              size: 46,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Your feed is ready',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: palette.text,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Post your first moment or follow more people to shape a feed that feels alive.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: palette.muted,
              fontSize: 14,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: onCreate,
            style: FilledButton.styleFrom(
              backgroundColor: palette.gold,
              foregroundColor: Colors.black,
              minimumSize: const Size(180, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            icon: const Icon(Icons.add_rounded),
            label: const Text(
              'Create post',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedErrorState extends StatelessWidget {
  final _FeedPalette palette;
  final String message;
  final VoidCallback onRetry;

  const _FeedErrorState({
    required this.palette,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(26),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _SoftIcon(
            icon: Icons.wifi_off_rounded,
            palette: palette,
            accent: palette.coral,
            size: 72,
          ),
          const SizedBox(height: 20),
          Text(
            'Feed could not refresh',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: palette.text,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: palette.muted,
              fontSize: 13.5,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: onRetry,
            style: OutlinedButton.styleFrom(
              foregroundColor: palette.gold,
              side: BorderSide(color: palette.gold.withValues(alpha: 0.6)),
              minimumSize: const Size(150, 46),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(23),
              ),
            ),
            icon: const Icon(Icons.refresh_rounded),
            label: Text(AppStrings.of(context).tryAgain),
          ),
        ],
      ),
    );
  }
}

class _SkeletonEnvelope extends StatelessWidget {
  final _FeedPalette palette;
  final Widget child;

  const _SkeletonEnvelope({
    required this.palette,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: palette.shadow.withValues(alpha: palette.isDark ? 0.2 : 0.75),
            blurRadius: 20,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _FloatingCreateCluster extends StatelessWidget {
  final _FeedPalette palette;
  final VoidCallback onCreate;

  const _FloatingCreateCluster({
    required this.palette,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(
          message: 'Create post',
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: palette.gold.withValues(alpha: 0.15),
                  blurRadius: 22,
                  spreadRadius: 2,
                  offset: const Offset(0, 6),
                ),
                BoxShadow(
                  color: palette.gold.withValues(alpha: 0.15),
                  blurRadius: 35,
                  spreadRadius: 6,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: FloatingActionButton(
              heroTag: 'feed-create-fab',
              elevation: 0,
              backgroundColor: palette.gold,
              foregroundColor: Colors.black,
              shape: const CircleBorder(),
              onPressed: onCreate,
              child: const Icon(Icons.add_rounded, size: 30),
            ),
          ),
        ),
      ],
    );
  }
}

class _AssistantPromptChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final _FeedPalette palette;

  const _AssistantPromptChip({
    required this.label,
    required this.icon,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 13),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: palette.gold, size: 18),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: palette.text,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
