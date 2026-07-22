part of 'feeds_screen.dart';

class _FeedPalette {
  final bool isDark;
  final Color background;
  final Color backgroundAlt;
  final Color surface;
  final Color elevated;
  final Color glass;
  final Color text;
  final Color muted;
  final Color faint;
  final Color border;
  final Color gold;
  final Color coral;
  final Color aqua;
  final Color green;
  final Color shadow;

  const _FeedPalette({
    required this.isDark,
    required this.background,
    required this.backgroundAlt,
    required this.surface,
    required this.elevated,
    required this.glass,
    required this.text,
    required this.muted,
    required this.faint,
    required this.border,
    required this.gold,
    required this.coral,
    required this.aqua,
    required this.green,
    required this.shadow,
  });

  factory _FeedPalette.of(BuildContext context) {
    final theme = Theme.of(context);
    final scaffoldLum = theme.scaffoldBackgroundColor.computeLuminance();
    final isDark = theme.brightness == Brightness.dark || scaffoldLum < 0.32;

    if (!isDark) {
      return const _FeedPalette(
        isDark: false,
        background: Color(0xFFF8F7F2),
        backgroundAlt: Color(0xFFEFF7F5),
        surface: Color(0xFFFFFFFF),
        elevated: Color(0xFFFFFFFF),
        glass: Color(0xEAFBFAF7),
        text: Color(0xFF121417),
        muted: Color(0xFF69717D),
        faint: Color(0xFF9CA3AF),
        border: Color(0x1F121417),
        gold: Color(0xFFe5c687),
        coral: Color(0xFFE86D5B),
        aqua: Color(0xFF2DAFBD),
        green: Color(0xFF37A56B),
        shadow: Color(0x1A101828),
      );
    }

    return const _FeedPalette(
      isDark: true,
      background: Color(0xFF080B10),
      backgroundAlt: Color(0xFF101820),
      surface: Color(0xFF121821),
      elevated: Color(0xFF171D27),
      glass: Color(0xE60D1117),
      text: Color(0xFFF6F2EA),
      muted: Color(0xFF9BA3AE),
      faint: Color(0xFF5F6874),
      border: Color(0x1FFFFFFF),
      gold: Color(0xFFe5c687),
      coral: Color(0xFFFF7A66),
      aqua: Color(0xFF63D5E6),
      green: Color(0xFF72DA99),
      shadow: Color(0x66000000),
    );
  }
}
