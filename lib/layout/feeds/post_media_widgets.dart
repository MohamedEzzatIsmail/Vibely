part of 'post_details_screen.dart';

class _PostImages extends StatefulWidget {
  final List<String> imageUrls;
  const _PostImages({required this.imageUrls});

  @override
  State<_PostImages> createState() => _PostImagesState();
}

class _PostImagesState extends State<_PostImages> {
  final PageController _pc = PageController();

  @override
  void dispose() { _pc.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    if (widget.imageUrls.length == 1) {
      return ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 220, maxHeight: 400),
        child: CachedNetworkImage(
          imageUrl: widget.imageUrls.first,
          fit: BoxFit.cover, width: double.infinity,
          placeholder: (_, _) => const SizedBox(height: 250,
              child: Center(child: CircularProgressIndicator(color: Color(0xFFe5c687), strokeWidth: 2))),
          errorWidget: (_, _, ___) => const SizedBox(height: 250,
              child: Center(child: Icon(Icons.broken_image_outlined, color: Colors.grey))),
        ),
      );
    }
    return Column(children: [
      SizedBox(
        height: 260,
        child: PageView.builder(
          controller:  _pc,
          itemCount:   widget.imageUrls.length,
          itemBuilder: (_, i) => SizedBox.expand(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: widget.imageUrls[i], fit: BoxFit.cover,
                placeholder: (_, _) => const SizedBox.expand(
                    child: ColoredBox(color: Color(0xFF21262d))),
                errorWidget: (_, _, ___) => const SizedBox.expand(
                    child: ColoredBox(color: Color(0xFF21262d))),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 8),
      SmoothPageIndicator(
        controller: _pc, count: widget.imageUrls.length,
        effect: const ExpandingDotsEffect(
          dotHeight: 8, dotWidth: 8, activeDotColor: Color(0xFFe5c687),
        ),
      ),
      const SizedBox(height: 8),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  POST VIDEO PLAYER
// ══════════════════════════════════════════════════════════════════════════════
class _PostVideoPlayer extends StatefulWidget {
  final String  videoUrl;
  final String? thumbnailUrl;
  const _PostVideoPlayer({required this.videoUrl, this.thumbnailUrl});

  @override
  State<_PostVideoPlayer> createState() => _PostVideoPlayerState();
}

class _PostVideoPlayerState extends State<_PostVideoPlayer> {
  Player?          _player;
  VideoController? _videoCtrl;
  bool _ready   = false;
  bool _playing = false;
  bool _loading = false;

  Widget _buildPlaceholder() {
    if (widget.thumbnailUrl?.isNotEmpty == true) {
      return SizedBox(height: 220,
          child: Stack(fit: StackFit.expand, children: [
            CachedNetworkImage(imageUrl: widget.thumbnailUrl!, fit: BoxFit.cover,
                placeholder: (_, _) => const ColoredBox(color: Colors.black),
                errorWidget:  (_, _, ___) => const ColoredBox(color: Colors.black)),
            Container(color: Colors.black38),
          ]));
    }
    return Container(height: 220, color: Colors.black,
        child: const Center(child: Icon(Icons.videocam_rounded, color: Colors.white24, size: 48)));
  }

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  Future<void> _initAndPlay() async {
    if (_player != null) {
      setState(() => _playing = !_playing);
      _playing ? _player!.play() : _player!.pause();
      return;
    }
    setState(() => _loading = true);
    try {
      final player = Player();
      final ctrl   = VideoController(player);
      await player.open(Media(widget.videoUrl), play: false);
      try {
        await player.stream.videoParams.first.timeout(const Duration(seconds: 10));
      } catch (_) { /* timeout or no params — continue anyway */ }
      if (!mounted) { player.dispose(); return; }
      setState(() {
        _player    = player;
        _videoCtrl = ctrl;
        _ready     = true;
        _loading   = false;
        _playing   = true;
      });
      player.play();
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _initAndPlay,
      child: Stack(alignment: Alignment.center, children: [
        _ready && _videoCtrl != null
            ? AspectRatio(
          aspectRatio: 9 / 16,
          child: Video(controller: _videoCtrl!, controls: NoVideoControls),
        )
            : _buildPlaceholder(),
        if (_loading)
          const CircularProgressIndicator(color: Color(0xFFe5c687), strokeWidth: 2),
        if (!_loading && !_playing)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
            child: Icon(Icons.play_arrow, color: AppColors.of(context).text, size: 36),
          ),
      ]),
    );
  }
}

