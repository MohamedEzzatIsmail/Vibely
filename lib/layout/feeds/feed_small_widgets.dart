part of 'feeds_screen.dart';

class _InlinePill extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final _FeedPalette palette;

  const _InlinePill({
    required this.label,
    required this.icon,
    required this.color,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: palette.isDark ? 0.12 : 0.14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 5),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: palette.text,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final _FeedPalette palette;
  final Color color;

  const _MetricPill({
    required this.label,
    required this.icon,
    required this.palette,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: palette.isDark ? 0.10 : 0.12),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: palette.text,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _TextTag extends StatelessWidget {
  final String label;
  final _FeedPalette palette;
  final bool large;

  const _TextTag({
    required this.label,
    required this.palette,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: large ? 12 : 10,
        vertical: large ? 8 : 6,
      ),
      decoration: BoxDecoration(
        color: palette.gold.withValues(alpha: palette.isDark ? 0.10 : 0.14),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: palette.gold.withValues(alpha: 0.24)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: palette.gold,
          fontSize: large ? 13 : 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _IconMicroButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final _FeedPalette palette;
  final VoidCallback onTap;

  const _IconMicroButton({
    required this.tooltip,
    required this.icon,
    required this.palette,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, color: palette.text, size: 22),
        ),
      ),
    );
  }
}

class _SoftIcon extends StatelessWidget {
  final IconData icon;
  final _FeedPalette palette;
  final Color accent;
  final double size;

  const _SoftIcon({
    required this.icon,
    required this.palette,
    required this.accent,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: accent.withValues(alpha: palette.isDark ? 0.12 : 0.15),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Icon(icon, color: accent, size: size * 0.48),
    );
  }
}

class _CountBadge extends StatelessWidget {
  final int count;
  final _FeedPalette palette;

  const _CountBadge({
    required this.count,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    final text = count > 99 ? '99+' : '$count';

    return Container(
      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: palette.coral,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: palette.background, width: 2),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: TextStyle(
          color: AppColors.of(context).text,
          fontSize: 9,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
