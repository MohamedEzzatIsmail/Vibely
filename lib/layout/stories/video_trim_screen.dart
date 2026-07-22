import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../../share/local/app_strings.dart';

/// Shown when the user picks a video for a story.
///
/// • If the video is ≤ 30 s the user can post as-is OR drag a trim window.
/// • If the video is > 30 s the user MUST trim a 30-second clip before posting.
///
/// Returns a [VideoTrimResult] on pop, or null if cancelled.
class VideoTrimScreen extends StatefulWidget {
  final File videoFile;
  const VideoTrimScreen({super.key, required this.videoFile});

  @override
  State<VideoTrimScreen> createState() => _VideoTrimScreenState();
}

class VideoTrimResult {
  final File   file;       // same file (no re-encode on device)
  final Duration start;
  final Duration end;
  const VideoTrimResult({required this.file, required this.start, required this.end});
}

class _VideoTrimScreenState extends State<VideoTrimScreen> {
  Player?          _player;
  VideoController? _videoCtrl;
  bool    _initialized = false;
  bool    _playing     = false;
  String? _initError;

  File? _playFile;

  Duration _total     = Duration.zero;
  Duration _trimStart = Duration.zero;
  Duration _trimEnd   = const Duration(seconds: 30);

  static const _kMaxStory = Duration(seconds: 30);
  String? _dragging;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    final old = _player;
    _player    = null;
    _videoCtrl = null;
    await old?.dispose();

    if (mounted) setState(() { _initError = null; _initialized = false; });

    try {
      final filePath = widget.videoFile.path;

      // Copy content:// URI to real temp file — media_kit needs a file:// path
      File playFile = widget.videoFile;
      if (filePath.startsWith('content://') || !filePath.startsWith('/')) {
        if (mounted) setState(() {});
        final tempDir  = await getTemporaryDirectory();
        final tempPath = '${tempDir.path}/trim_preview_${DateTime.now().millisecondsSinceEpoch}.mp4';
        final tempFile = File(tempPath);
        await XFile(filePath).saveTo(tempPath);
        if (!await tempFile.exists() || await tempFile.length() == 0) {
          throw Exception('Could not copy video to temp storage.');
        }
        playFile = tempFile;
      }
      _playFile = playFile;

      final player = Player();
      final ctrl   = VideoController(player);

      await player.open(Media('file://${playFile.path}'), play: false);
      // Wait for duration to become available
      await player.stream.duration.firstWhere((d) => d.inMilliseconds > 0)
          .timeout(const Duration(seconds: 10));

      if (!mounted) { player.dispose(); return; }

      _total   = player.state.duration;
      _trimEnd = _total <= _kMaxStory ? _total : _kMaxStory;

      // Listen for position to loop within trim window
      player.stream.position.listen((pos) {
        if (_player != player) return;
        if (pos >= _trimEnd) {
          player.seek(_trimStart);
        }
      });
      // Listen for playing state
      player.stream.playing.listen((playing) {
        if (mounted && _player == player) setState(() => _playing = playing);
      });

      setState(() {
        _player      = player;
        _videoCtrl   = ctrl;
        _initialized = true;
        _playing     = false;
      });

      await player.seek(_trimStart);
      await player.play();
    } catch (e) {
      if (mounted) {
        final errStr = e.toString();
        setState(() => _initError = errStr.contains('NO_MEMORY') || errStr.contains('0xfffffff4')
            ? 'Video decoder unavailable. Reinstall the app after adding EnableImpeller=false to AndroidManifest.xml.'
            : 'Failed to load video. Make sure the video is not corrupted.\n\n(${errStr.split(')').last.trim()})');
      }
    }
  }

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  void _togglePlay() {
    if (_player == null) return;
    if (_playing) {
      _player!.pause();
    } else {
      _player!.seek(_trimStart);
      _player!.play();
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────
  double _toFraction(Duration d) =>
      _total.inMilliseconds == 0 ? 0 : d.inMilliseconds / _total.inMilliseconds;

  Duration _fromFraction(double f) =>
      Duration(milliseconds: (f.clamp(0.0, 1.0) * _total.inMilliseconds).round());

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  /// Duration doesn't have .clamp() — use this helper instead.
  Duration _clampD(Duration v, Duration lo, Duration hi) =>
      v < lo ? lo : (v > hi ? hi : v);

  void _onTrimDrag(DragUpdateDetails det, double barWidth) {
    if (_dragging == null || _total == Duration.zero) return;
    final delta = Duration(
        milliseconds: (det.delta.dx / barWidth * _total.inMilliseconds).round());

    setState(() {
      if (_dragging == 'start') {
        Duration newStart = _trimStart + delta;
        // Can't go below zero or past (trimEnd - 1s)
        newStart = _clampD(newStart, Duration.zero, _trimEnd - const Duration(seconds: 1));
        // For long videos enforce the max 30s window
        if (_total > _kMaxStory) {
          newStart = _clampD(newStart, Duration.zero, _trimEnd - _kMaxStory);
        }
        _trimStart = newStart;
      } else {
        Duration newEnd = _trimEnd + delta;
        // Can't go below (trimStart + 1s) or past total
        newEnd = _clampD(newEnd, _trimStart + const Duration(seconds: 1), _total);
        // For long videos enforce the max 30s window from trimStart
        if (_total > _kMaxStory) {
          newEnd = _clampD(newEnd, Duration.zero, _trimStart + _kMaxStory);
        }
        _trimEnd = newEnd;
      }
      // Final guard: keep window within 30s
      if ((_trimEnd - _trimStart) > _kMaxStory) {
        if (_dragging == 'start') {
          _trimEnd = _trimStart + _kMaxStory;
        } else {
          _trimStart = _trimEnd - _kMaxStory;
        }
      }
    });
    _player?.seek(_trimStart);
  }

  void _confirm() {
    Navigator.pop(context, VideoTrimResult(
      // Return the actual temp file (real filesystem path), not the original
      // content:// URI. Supabase upload needs a real path to read bytes from.
      file:  _playFile ?? widget.videoFile,
      start: _trimStart,
      end:   _trimEnd,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final mustTrim = _total > _kMaxStory;
    final window   = _trimEnd - _trimStart;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Column(children: [
            // ── Top bar ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(children: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                const Spacer(),
                Text(
                  mustTrim
                      ? 'Trim to 30 seconds'
                      : 'Use or trim video',
                  style: const TextStyle(color: Colors.white,
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _initialized ? _confirm : null,
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFFe5c687),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  child: Text(AppStrings.of(context).next,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ]),
            ),

            // ── Video preview ─────────────────────────────────────────
            Expanded(
              child: _initialized && _videoCtrl != null
                  ? GestureDetector(
                onTap: _togglePlay,
                child: Stack(alignment: Alignment.center, children: [
                  Video(
                    controller: _videoCtrl!,
                    controls: NoVideoControls,
                    fit: BoxFit.contain,
                  ),
                  if (!_playing)
                    Container(
                      width: 56, height: 56,
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white38, width: 1.5),
                      ),
                      child: const Icon(Icons.play_arrow_rounded,
                          color: Colors.white, size: 32),
                    ),
                ]),
              )
                  : _initError != null
                  ? Center(child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                  const SizedBox(height: 12),
                  Text(_initError!,
                      style: const TextStyle(color: Colors.white60, fontSize: 13),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF21262d),
                          foregroundColor: Colors.white),
                      onPressed: () => Navigator.pop(context),
                      child: Text(AppStrings.of(context).goBack),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFe5c687),
                          foregroundColor: Colors.black),
                      onPressed: _initVideo,
                      child: Text(AppStrings.of(context).retry),
                    ),
                  ]),
                ]),
              ))
                  : Center(child: Builder(builder: (context) => Column(mainAxisSize: MainAxisSize.min, children: [
                const CircularProgressIndicator(color: Color(0xFFe5c687), strokeWidth: 2),
                const SizedBox(height: 12),
                Text(AppStrings.of(context).loadingVideo,
                    style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ]))),
            ),

            // ── Duration info ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_fmt(_trimStart),
                      style: const TextStyle(color: Colors.white60, fontSize: 12)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: window <= _kMaxStory
                          ? const Color(0xFF2e7d32)
                          : const Color(0xFFc0392b),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_fmt(window)} / 0:30',
                      style: const TextStyle(color: Colors.white,
                          fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(_fmt(_trimEnd),
                      style: const TextStyle(color: Colors.white60, fontSize: 12)),
                ],
              ),
            ),

            // ── Trim bar ──────────────────────────────────────────────
            if (_initialized)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: LayoutBuilder(builder: (ctx, constraints) {
                  final barW = constraints.maxWidth;
                  return SizedBox(
                    height: 48,
                    child: Stack(alignment: Alignment.center, children: [
                      // Full track
                      Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: Colors.white12,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      // Selected window highlight
                      Positioned(
                        left:  _toFraction(_trimStart) * barW,
                        right: (1 - _toFraction(_trimEnd)) * barW,
                        child: Container(
                          height: 6,
                          decoration: BoxDecoration(
                            color: const Color(0xFFe5c687),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                      // Video playhead
                      if (_player != null)
                        StreamBuilder<Duration>(
                          stream: _player!.stream.position,
                          builder: (_, snap) {
                            final pos  = snap.data ?? Duration.zero;
                            final frac = _total.inMilliseconds > 0
                                ? pos.inMilliseconds / _total.inMilliseconds
                                : 0.0;
                            return Positioned(
                              left: (frac * barW).clamp(0, barW - 2) - 1,
                              child: Container(
                                width: 2, height: 24,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(1),
                                ),
                              ),
                            );
                          },
                        ),
                      // Start handle
                      Positioned(
                        left: (_toFraction(_trimStart) * barW - 10).clamp(0, barW - 20),
                        child: GestureDetector(
                          onHorizontalDragStart: (_) => setState(() => _dragging = 'start'),
                          onHorizontalDragUpdate: (d) => _onTrimDrag(d, barW),
                          onHorizontalDragEnd:   (_) => setState(() => _dragging = null),
                          child: _Handle(color: const Color(0xFFe5c687)),
                        ),
                      ),
                      // End handle
                      Positioned(
                        left: (_toFraction(_trimEnd) * barW - 10).clamp(0, barW - 20),
                        child: GestureDetector(
                          onHorizontalDragStart: (_) => setState(() => _dragging = 'end'),
                          onHorizontalDragUpdate: (d) => _onTrimDrag(d, barW),
                          onHorizontalDragEnd:   (_) => setState(() => _dragging = null),
                          child: _Handle(color: const Color(0xFFe5c687)),
                        ),
                      ),
                    ]),
                  );
                }),
              ),

            // ── Hint ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                mustTrim
                    ? 'Drag the handles to select a 30-second clip'
                    : 'Drag handles to trim  •  tap video to play/pause',
                style: const TextStyle(color: Colors.white38, fontSize: 11),
                textAlign: TextAlign.center,
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Handle extends StatelessWidget {
  final Color color;
  const _Handle({required this.color});
  @override
  Widget build(BuildContext context) => Container(
    width: 20, height: 36,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(4),
      boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 4)],
    ),
    child: const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _Bar(), SizedBox(height: 3), _Bar(), SizedBox(height: 3), _Bar(),
      ],
    ),
  );
}

class _Bar extends StatelessWidget {
  const _Bar();
  @override
  Widget build(BuildContext context) => Container(
    width: 10, height: 2,
    decoration: BoxDecoration(
      color: Colors.black54,
      borderRadius: BorderRadius.circular(1),
    ),
  );
}