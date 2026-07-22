// lib/share/local/skeleton_widgets.dart
//
// Shimmer skeleton screens for all loading states.
// Requires: shimmer package

import 'package:flutter/material.dart';
import '../../share/local/app_strings.dart';
import 'package:shimmer/shimmer.dart';

import '../style/app_colors.dart';

// ── Shared shimmer box helper ─────────────────────────────────────────────────
Widget _shim({double? w, double? h, double radius = 8}) => Shimmer.fromColors(
      baseColor: const Color(0xFF21262D),
      highlightColor: const Color(0xFF30363D),
      child: Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: const Color(0xFF21262D),
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );

Widget _shimCircle(double size) => Shimmer.fromColors(
      baseColor: const Color(0xFF21262D),
      highlightColor: const Color(0xFF30363D),
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: const Color(0xFF21262D),
          shape: BoxShape.circle,
        ),
      ),
    );

// ── Post card skeleton ────────────────────────────────────────────────────────
class PostCardSkeleton extends StatelessWidget {
  const PostCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.of(context).surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Author row
          Row(
            children: [
              _shimCircle(40),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _shim(w: 120, h: 13),
                  const SizedBox(height: 5),
                  _shim(w: 70, h: 10),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Text lines
          _shim(w: double.infinity, h: 13),
          const SizedBox(height: 6),
          _shim(w: 220, h: 13),
          const SizedBox(height: 12),
          // Media area
          _shim(w: double.infinity, h: 180, radius: 12),
          const SizedBox(height: 12),
          // Reaction bar
          Row(
            children: [
              _shim(w: 60, h: 28, radius: 14),
              const SizedBox(width: 10),
              _shim(w: 80, h: 28, radius: 14),
              const Spacer(),
              _shim(w: 28, h: 28, radius: 14),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Chat tile skeleton ────────────────────────────────────────────────────────
class ChatTileSkeleton extends StatelessWidget {
  const ChatTileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          _shimCircle(48),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _shim(w: 130, h: 13),
                    _shim(w: 40, h: 10),
                  ],
                ),
                const SizedBox(height: 6),
                _shim(w: 200, h: 11),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Notification tile skeleton ────────────────────────────────────────────────
class NotificationTileSkeleton extends StatelessWidget {
  const NotificationTileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          _shimCircle(44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _shim(w: double.infinity, h: 13),
                const SizedBox(height: 5),
                _shim(w: 100, h: 10),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _shim(w: 44, h: 44, radius: 8),
        ],
      ),
    );
  }
}

// ── Story bar skeleton ────────────────────────────────────────────────────────
class StoryBarSkeleton extends StatelessWidget {
  const StoryBarSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 88,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        itemCount: 6,
        itemBuilder: (_, i) => Padding(
          padding: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
          child: Column(
            children: [
              _shimCircle(56),
              const SizedBox(height: 4),
              _shim(w: 50, h: 9),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Explore grid skeleton ─────────────────────────────────────────────────────
class ExploreGridSkeleton extends StatelessWidget {
  const ExploreGridSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(4),
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 3,
        mainAxisSpacing: 3,
      ),
      itemCount: 12,
      itemBuilder: (_, _) => _shim(radius: 0),
    );
  }
}

// ── Generic SkeletonBox widget used by CloseFriendsScreen & BlockedUsersScreen
// A simple shimmer-animated placeholder rectangle.
class SkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  final double radius;

  const SkeletonBox({
    super.key,
    required this.width,
    required this.height,
    this.radius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor:      const Color(0xFF21262D),
      highlightColor: const Color(0xFF30363D),
      child: Container(
        width:  width,
        height: height,
        decoration: BoxDecoration(
          color:        const Color(0xFF21262D),
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}
