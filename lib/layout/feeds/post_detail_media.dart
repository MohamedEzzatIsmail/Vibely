// lib/layout/feeds/post_detail_media.dart
//
// Uses post.postImages (List<String>) directly — no more .split(',')

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../layout/feeds/post_video_player.dart';
import '../../models/post_model.dart';

class PostDetailMedia extends StatefulWidget {
  final PostModel post;
  final double maxHeight;

  const PostDetailMedia({
    super.key,
    required this.post,
    this.maxHeight = 340,
  });

  @override
  State<PostDetailMedia> createState() => _PostDetailMediaState();
}

class _PostDetailMediaState extends State<PostDetailMedia> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final post = widget.post;

    // Video takes priority over images
    if (post.postVideo != null && post.postVideo!.isNotEmpty) {
      return PostVideoPlayer(
        videoUrl: post.postVideo!,
        thumbnailUrl: post.videoThumbnail,
        maxHeight: widget.maxHeight,
      );
    }

    // post.postImages is already a List<String> — use directly
    final images = post.postImages;
    if (images.isEmpty) return const SizedBox.shrink();

    if (images.length == 1) {
      return _SingleImage(url: images.first, maxHeight: widget.maxHeight);
    }

    // Multiple images → swipeable PageView with dot indicator
    return Column(
      children: [
        SizedBox(
          height: widget.maxHeight,
          child: PageView.builder(
            itemCount: images.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (_, i) =>
                _SingleImage(url: images[i], maxHeight: widget.maxHeight),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(images.length, (i) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: _page == i ? 16 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: _page == i
                      ? const Color(0xFFe5c687)
                      : Colors.white24,
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

class _SingleImage extends StatelessWidget {
  final String url;
  final double maxHeight;
  const _SingleImage({required this.url, required this.maxHeight});

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: url,
      width: double.infinity,
      height: maxHeight,
      fit: BoxFit.cover,
      placeholder: (_, _) => Container(
        height: maxHeight,
        color: Colors.white.withValues(alpha: 0.04),
        child: const Center(
          child: CircularProgressIndicator(
            color: Color(0xFFe5c687),
            strokeWidth: 2,
          ),
        ),
      ),
      errorWidget: (_, _, ___) => Container(
        height: maxHeight,
        color: Colors.white.withValues(alpha: 0.04),
        child: const Icon(Icons.broken_image, color: Colors.white24, size: 40),
      ),
    );
  }
}
