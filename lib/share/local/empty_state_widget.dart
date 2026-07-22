// lib/share/local/empty_state_widget.dart
//
// Illustrated empty states — all drawn in Flutter custom paint (no assets needed).
// Used in: Feed, Chats, Notifications, Bookmarks.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../share/style/app_colors.dart';

// ── Feed empty state ──────────────────────────────────────────────────────────
class EmptyFeedState extends StatelessWidget {
  const EmptyFeedState({super.key});

  @override
  Widget build(BuildContext context) => _EmptyState(
        painter: _CameraWithPlusPainter(),
        title: 'Share your first moment',
        subtitle:
            'Tap the + button to create your first post and connect with friends.',
      );
}

// ── Chats empty state ─────────────────────────────────────────────────────────
class EmptyChatsState extends StatelessWidget {
  const EmptyChatsState({super.key});

  @override
  Widget build(BuildContext context) => _EmptyState(
        painter: _BubblesPainter(),
        title: 'No conversations yet',
        subtitle: 'Start a chat with someone you follow.',
      );
}

// ── Notifications empty state ─────────────────────────────────────────────────
class EmptyNotificationsState extends StatelessWidget {
  const EmptyNotificationsState({super.key});

  @override
  Widget build(BuildContext context) => _EmptyState(
        painter: _BellZzzPainter(),
        title: "You're all caught up",
        subtitle: 'New likes, comments, and follows will appear here.',
      );
}

// ── Bookmarks empty state ─────────────────────────────────────────────────────
class EmptyBookmarksState extends StatelessWidget {
  const EmptyBookmarksState({super.key});

  @override
  Widget build(BuildContext context) => _EmptyState(
        painter: _BookmarkPainter(),
        title: 'Nothing saved yet',
        subtitle: 'Tap the bookmark icon on any post to save it here.',
      );
}

// ── Shared scaffold ───────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final CustomPainter painter;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.painter,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 120,
              height: 120,
              child: CustomPaint(painter: painter),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.of(context).text,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Painters ──────────────────────────────────────────────────────────────────

/// Camera outline with plus sign
class _CameraWithPlusPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFe5c687).withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final cx = size.width / 2;
    final cy = size.height / 2;

    // Camera body
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy + 8), width: 70, height: 46),
      const Radius.circular(10),
    );
    canvas.drawRRect(bodyRect, paint);

    // Lens
    canvas.drawCircle(Offset(cx, cy + 8), 14, paint);

    // Viewfinder bump
    final Path bump = Path()
      ..moveTo(cx - 14, cy - 14)
      ..lineTo(cx - 10, cy - 22)
      ..lineTo(cx + 10, cy - 22)
      ..lineTo(cx + 14, cy - 14);
    canvas.drawPath(bump, paint);

    // Plus sign inside lens
    canvas.drawLine(
        Offset(cx - 7, cy + 8), Offset(cx + 7, cy + 8), paint);
    canvas.drawLine(
        Offset(cx, cy + 1), Offset(cx, cy + 15), paint);
  }

  @override
  bool shouldRepaint(_) => false;
}

/// Two overlapping speech bubbles
class _BubblesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFe5c687).withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final cx = size.width / 2;
    final cy = size.height / 2;

    // Bubble 1
    final b1 = RRect.fromRectAndRadius(
      Rect.fromCenter(
          center: Offset(cx - 10, cy - 6), width: 60, height: 42),
      const Radius.circular(14),
    );
    canvas.drawRRect(b1, paint);
    // Tail 1
    final t1 = Path()
      ..moveTo(cx - 24, cy + 14)
      ..lineTo(cx - 30, cy + 26)
      ..lineTo(cx - 14, cy + 14);
    canvas.drawPath(t1, paint);

    // Bubble 2
    final b2 = RRect.fromRectAndRadius(
      Rect.fromCenter(
          center: Offset(cx + 12, cy + 8), width: 56, height: 38),
      const Radius.circular(14),
    );
    canvas.drawRRect(b2, paint);
    // Tail 2
    final t2 = Path()
      ..moveTo(cx + 24, cy + 26)
      ..lineTo(cx + 32, cy + 36)
      ..lineTo(cx + 16, cy + 26);
    canvas.drawPath(t2, paint);
  }

  @override
  bool shouldRepaint(_) => false;
}

/// Bell with ZZZ
class _BellZzzPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFe5c687).withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final cx = size.width / 2;
    final cy = size.height / 2;

    // Bell arc (dome)
    final bellPath = Path()
      ..moveTo(cx - 22, cy + 10)
      ..cubicTo(cx - 22, cy - 30, cx + 22, cy - 30, cx + 22, cy + 10)
      ..lineTo(cx + 28, cy + 10)
      ..lineTo(cx - 28, cy + 10)
      ..close();
    canvas.drawPath(bellPath, paint);

    // Clapper
    canvas.drawLine(
        Offset(cx - 6, cy + 10), Offset(cx + 6, cy + 18), paint);
    canvas.drawArc(
      Rect.fromCenter(center: Offset(cx, cy + 18), width: 12, height: 8),
      0,
      math.pi,
      false,
      paint,
    );

    // Stem
    canvas.drawLine(Offset(cx, cy - 30), Offset(cx, cy - 38), paint);

    // ZZZ
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'zzz',
        style: TextStyle(
          color: const Color(0xFFe5c687).withValues(alpha: 0.7),
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, Offset(cx + 24, cy - 24));
  }

  @override
  bool shouldRepaint(_) => false;
}

/// Bookmark outline
class _BookmarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFe5c687).withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final cx = size.width / 2;
    final cy = size.height / 2;

    final path = Path()
      ..moveTo(cx - 22, cy - 40)
      ..lineTo(cx + 22, cy - 40)
      ..lineTo(cx + 22, cy + 30)
      ..lineTo(cx, cy + 14)
      ..lineTo(cx - 22, cy + 30)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_) => false;
}
