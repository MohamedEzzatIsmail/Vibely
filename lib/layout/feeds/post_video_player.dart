// lib/layout/feeds/post_video_player.dart
//
// Full-featured video player with:
//  • Full-screen button (bottom-left expand icon)
//  • Aspect-ratio-aware full screen:
//    - Portrait video → fills screen vertically, no rotation
//    - Landscape video → forces device to landscape
//  • Playback controls (play/pause, seek bar, time display)
//  • Auto-pause when scrolled off screen

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:visibility_detector/visibility_detector.dart';

class PostVideoPlayer extends StatefulWidget {
  final String  videoUrl;
  final String? thumbnailUrl;
  final double  maxHeight;

  const PostVideoPlayer({
    super.key,
    required this.videoUrl,
    this.thumbnailUrl,
    this.maxHeight = 280,
  });

  @override
  State<PostVideoPlayer> createState() => _PostVideoPlayerState();
}

class _PostVideoPlayerState extends State<PostVideoPlayer> {
  Player?          _player;
  VideoController? _controller;
  bool  _initialized = false;
  bool  _loading     = false;
  bool  _playing     = false;
  bool  _showControls = true;
  Duration _pos      = Duration.zero;
  Duration _total    = Duration.zero;

  @override
  void dispose() {
    _disposePlayer();
    super.dispose();
  }

  Future<void> _initPlayer() async {
    if (_initialized || _loading) return;
    if (!mounted) return;
    setState(() => _loading = true);

    final player = Player();
    final ctrl   = VideoController(player);
    await player.open(Media(widget.videoUrl), play: true);

    player.stream.position.listen((p) {
      if (mounted) setState(() => _pos = p);
    });
    player.stream.duration.listen((d) {
      if (mounted) setState(() => _total = d);
    });
    player.stream.playing.listen((v) {
      if (mounted) setState(() => _playing = v);
    });

    _player     = player;
    _controller = ctrl;
    if (mounted) setState(() { _initialized = true; _loading = false; });
  }

  void _disposePlayer() {
    _player?.dispose();
    _player     = null;
    _controller = null;
  }

  void _onVisibilityChanged(VisibilityInfo info) {
    if (!mounted) return;
    if (info.visibleFraction == 0.0 && _initialized) {
      _player?.pause();
      _disposePlayer();
      setState(() { _initialized = false; _playing = false; });
    }
  }

  Future<void> _togglePlay() async {
    if (_player == null) return;
    _playing ? await _player!.pause() : await _player!.play();
  }

  Future<void> _enterFullScreen() async {
    if (_player == null || _controller == null) return;

    // Detect aspect ratio from the player's video stream
    final w = _player!.state.videoParams.w ?? 0;
    final h = _player!.state.videoParams.h ?? 0;
    final isLandscape = w > 0 && h > 0 && w > h;

    if (isLandscape) {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }

    if (!mounted) return;
    await Navigator.of(context).push(
      PageRouteBuilder(
        opaque: true,
        pageBuilder: (_, __, ___) => _FullScreenPlayer(
          player:     _player!,
          controller: _controller!,
          isLandscape: isLandscape,
        ),
        transitionDuration: const Duration(milliseconds: 200),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );

    // Restore portrait after returning
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  String _fmt(Duration d) =>
      '${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  double get _progress {
    if (_total.inMilliseconds == 0) return 0;
    return (_pos.inMilliseconds / _total.inMilliseconds).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: Key('video_${widget.videoUrl.hashCode}'),
      onVisibilityChanged: _onVisibilityChanged,
      child: GestureDetector(
        onTap: () {
          if (!_initialized) {
            _initPlayer();
          } else {
            setState(() => _showControls = !_showControls);
          }
        },
        child: SizedBox(
          height: widget.maxHeight,
          width: double.infinity,
          child: Stack(
            children: [
              // ── Video or thumbnail ──────────────────────────────────
              if (_initialized && _controller != null)
                ClipRRect(
                  child: Video(
                    controller: _controller!,
                    height: widget.maxHeight,
                    fit: BoxFit.cover,
                  ),
                )
              else
                _ThumbnailOverlay(
                  thumbnailUrl: widget.thumbnailUrl,
                  loading: _loading,
                  maxHeight: widget.maxHeight,
                  onTap: _initPlayer,
                ),

              // ── Controls overlay (only when initialized) ────────────
              if (_initialized && _showControls) ...[
                // Dark gradient at bottom
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: Container(
                    height: 72,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [Colors.black87, Colors.transparent],
                      ),
                    ),
                  ),
                ),

                // Play / pause centre button
                Center(
                  child: GestureDetector(
                    onTap: _togglePlay,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 150),
                      child: Container(
                        key: ValueKey(_playing),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.4),
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(10),
                        child: Icon(
                          _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ),
                  ),
                ),

                // Bottom bar: time + seek + fullscreen
                Positioned(
                  bottom: 8, left: 8, right: 8,
                  child: Row(children: [
                    // Full-screen button (bottom-left)
                    GestureDetector(
                      onTap: _enterFullScreen,
                      child: const Icon(
                        Icons.fullscreen_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Elapsed time
                    Text(
                      _fmt(_pos),
                      style: const TextStyle(
                          color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(width: 6),
                    // Seek bar
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 2,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                          overlayShape: SliderComponentShape.noOverlay,
                          activeTrackColor: const Color(0xFFE5C687),
                          inactiveTrackColor: Colors.white24,
                          thumbColor: const Color(0xFFE5C687),
                        ),
                        child: Slider(
                          value: _progress,
                          onChanged: (v) {
                            final ms = (_total.inMilliseconds * v).round();
                            _player?.seek(Duration(milliseconds: ms));
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Total time
                    Text(
                      _fmt(_total),
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 11),
                    ),
                  ]),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Full-screen player ────────────────────────────────────────────────────────
class _FullScreenPlayer extends StatefulWidget {
  final Player          player;
  final VideoController controller;
  final bool            isLandscape;

  const _FullScreenPlayer({
    required this.player,
    required this.controller,
    required this.isLandscape,
  });

  @override
  State<_FullScreenPlayer> createState() => _FullScreenPlayerState();
}

class _FullScreenPlayerState extends State<_FullScreenPlayer> {
  bool     _showControls = true;
  bool     _playing      = true;
  Duration _pos          = Duration.zero;
  Duration _total        = Duration.zero;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
    widget.player.stream.position.listen((p) {
      if (mounted) setState(() => _pos = p);
    });
    widget.player.stream.duration.listen((d) {
      if (mounted) setState(() => _total = d);
    });
    widget.player.stream.playing.listen((v) {
      if (mounted) setState(() => _playing = v);
    });
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _togglePlay() async =>
      _playing ? await widget.player.pause() : await widget.player.play();

  String _fmt(Duration d) =>
      '${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  double get _progress {
    if (_total.inMilliseconds == 0) return 0;
    return (_pos.inMilliseconds / _total.inMilliseconds).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => setState(() => _showControls = !_showControls),
        child: Stack(
          children: [
            // Video fills screen
            Center(
              child: Video(
                controller: widget.controller,
                fit: widget.isLandscape ? BoxFit.contain : BoxFit.contain,
              ),
            ),

            if (_showControls) ...[
              // Top bar — close button
              Positioned(
                top: 0, left: 0, right: 0,
                child: Container(
                  height: 80,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.black87, Colors.transparent],
                    ),
                  ),
                  alignment: Alignment.topLeft,
                  padding: const EdgeInsets.fromLTRB(8, 40, 0, 0),
                  child: SafeArea(
                    child: IconButton(
                      icon: const Icon(Icons.fullscreen_exit_rounded,
                          color: Colors.white, size: 28),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),
              ),

              // Centre play/pause
              Center(
                child: GestureDetector(
                  onTap: _togglePlay,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(14),
                    child: Icon(
                      _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                ),
              ),

              // Bottom controls
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 40, 16, 24),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Colors.black87, Colors.transparent],
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Row(children: [
                      Text(
                        _fmt(_pos),
                        style: const TextStyle(
                            color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 3,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                            overlayShape: SliderComponentShape.noOverlay,
                            activeTrackColor: const Color(0xFFE5C687),
                            inactiveTrackColor: Colors.white24,
                            thumbColor: const Color(0xFFE5C687),
                          ),
                          child: Slider(
                            value: _progress,
                            onChanged: (v) {
                              final ms = (_total.inMilliseconds * v).round();
                              widget.player.seek(Duration(milliseconds: ms));
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _fmt(_total),
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ]),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Thumbnail overlay (unchanged from original) ───────────────────────────────
class _ThumbnailOverlay extends StatelessWidget {
  final String?      thumbnailUrl;
  final bool         loading;
  final double       maxHeight;
  final VoidCallback onTap;

  const _ThumbnailOverlay({
    required this.thumbnailUrl,
    required this.loading,
    required this.maxHeight,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Stack(alignment: Alignment.center, children: [
        if (thumbnailUrl != null && thumbnailUrl!.isNotEmpty)
          CachedNetworkImage(
            imageUrl: thumbnailUrl!,
            width: double.infinity,
            height: maxHeight,
            fit: BoxFit.cover,
            placeholder: (_, _) => Container(
              height: maxHeight, color: Colors.white.withValues(alpha: 0.05)),
            errorWidget: (_, _, ___) => Container(
              height: maxHeight, color: Colors.black87),
          )
        else
          Container(width: double.infinity, height: maxHeight, color: Colors.black87),

        Container(
          width: double.infinity, height: maxHeight,
          color: Colors.black.withValues(alpha: 0.28)),

        if (loading)
          const CircularProgressIndicator(color: Color(0xFFE5C687), strokeWidth: 3)
        else
          Container(
            width: 62, height: 62,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.55), width: 2),
            ),
            child: const Icon(Icons.play_arrow, color: Colors.white, size: 36),
          ),
      ]),
    );
  }
}
