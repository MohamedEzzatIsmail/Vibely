// lib/layout/chats/voice_message_player.dart
// Latest version — dynamic range normalization, 60-bar waveform, speed control.

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

const _kGoldPlayed   = Color(0xFFE5C687);
const _kGoldUnplayed = Color(0x50E5C687);
const _kBluePlayed   = Color(0xFF1976D2);
const _kBlueUnplayed = Color(0x331976D2);

const _kWaveHeight = 44.0;
const _kTargetBars = 60;

List<double> _normalizeDb(List<double> rawDb) {
  if (rawDb.isEmpty) return [];
  final valid = rawDb.where((v) => v > -150).toList();
  if (valid.isEmpty) return List.filled(rawDb.length, 0.04);
  double minDb = valid[0], maxDb = valid[0];
  for (final v in valid) {
    if (v < minDb) minDb = v;
    if (v > maxDb) maxDb = v;
  }
  final range = maxDb - minDb;
  if (range < 3.0) return _localContrastNormalize(rawDb);
  return rawDb.map((db) {
    if (db <= -150) return 0.04;
    final linear = ((db - minDb) / range).clamp(0.0, 1.0);
    final contrast = 3 * linear * linear - 2 * linear * linear * linear;
    return contrast.clamp(0.04, 1.0);
  }).toList();
}

List<double> _localContrastNormalize(List<double> rawDb) {
  final n = rawDb.length;
  final result = List<double>.filled(n, 0.0);
  const window = 5;
  for (var i = 0; i < n; i++) {
    final start = math.max(0, i - window);
    final end   = math.min(n - 1, i + window);
    double lo = rawDb[i], hi = rawDb[i];
    for (var j = start; j <= end; j++) {
      if (rawDb[j] < lo) lo = rawDb[j];
      if (rawDb[j] > hi) hi = rawDb[j];
    }
    final rng = hi - lo;
    if (rng < 0.5) {
      result[i] = 0.3 + (i % 3) * 0.1;
    } else {
      result[i] = ((rawDb[i] - lo) / rng).clamp(0.04, 1.0);
    }
  }
  return result;
}

List<double> _resampleTo(List<double> values, int targetN) {
  final n = values.length;
  if (n == 0) return List.filled(targetN, 0.04);
  if (n == targetN) return List<double>.from(values);
  final result = List<double>.filled(targetN, 0.0);
  if (n > targetN) {
    final ratio = n / targetN;
    for (var i = 0; i < targetN; i++) {
      final start = (i * ratio).floor();
      final end   = ((i + 1) * ratio).ceil().clamp(0, n);
      double peak = 0.0;
      for (var j = start; j < end; j++) {
        if (values[j] > peak) peak = values[j];
      }
      result[i] = peak;
    }
  } else {
    for (var i = 0; i < targetN; i++) {
      final t  = i / (targetN - 1) * (n - 1);
      final lo = t.floor().clamp(0, n - 1);
      final hi = (lo + 1).clamp(0, n - 1);
      result[i] = values[lo] + (values[hi] - values[lo]) * (t - lo);
    }
  }
  return result;
}

List<double> _buildEnvelope(List<double> rawDb) {
  if (rawDb.isEmpty) return _placeholderEnvelope('');
  final normalized = _normalizeDb(rawDb);
  return _resampleTo(normalized, _kTargetBars);
}

List<double> _placeholderEnvelope(String seed) {
  final rng = math.Random(seed.hashCode.abs() + 1);
  final out  = List<double>.filled(_kTargetBars, 0.0);
  for (var i = 0; i < _kTargetBars; i++) {
    final t      = i / (_kTargetBars - 1);
    final burst1 = math.sin(t * math.pi * 4.0).abs();
    final burst2 = math.sin(t * math.pi * 9.0).abs() * 0.5;
    final env    = (burst1 + burst2).clamp(0.0, 1.5) / 1.5;
    final noise  = 0.7 + rng.nextDouble() * 0.3;
    out[i] = (env * noise).clamp(0.05, 1.0);
  }
  final peak = out.fold(0.0, math.max);
  if (peak > 0) for (var i = 0; i < _kTargetBars; i++) out[i] /= peak;
  return out;
}

class VoiceMessagePlayer extends StatefulWidget {
  final String       audioUrl;
  final int          durationSec;
  final bool         isMe;
  final List<double> waveformData;

  const VoiceMessagePlayer({
    super.key,
    required this.audioUrl,
    required this.durationSec,
    required this.isMe,
    this.waveformData = const [],
  });

  @override
  State<VoiceMessagePlayer> createState() => _VoiceMessagePlayerState();
}

class _VoiceMessagePlayerState extends State<VoiceMessagePlayer> {
  AudioPlayer? _player;
  bool     _playing = false;
  bool     _loading = false;
  bool     _inited  = false;
  Duration _pos     = Duration.zero;
  Duration _total   = Duration.zero;
  double   _speed   = 1.0;

  StreamSubscription? _posSub;
  StreamSubscription? _stateSub;

  late final List<double> _envelope;

  @override
  void initState() {
    super.initState();
    _envelope = widget.waveformData.isNotEmpty
        ? _buildEnvelope(widget.waveformData)
        : _placeholderEnvelope(widget.audioUrl);
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _stateSub?.cancel();
    _player?.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    if (_inited) return;
    setState(() => _loading = true);
    try {
      final player   = AudioPlayer();
      final duration = await player.setUrl(widget.audioUrl);
      _total = duration ?? Duration(seconds: widget.durationSec);
      _posSub = player.positionStream.listen((p) {
        if (mounted) setState(() => _pos = p);
      });
      _stateSub = player.playerStateStream.listen((s) {
        if (!mounted) return;
        if (s.processingState == ProcessingState.completed) {
          setState(() { _playing = false; _pos = Duration.zero; });
          player.seek(Duration.zero);
        } else {
          setState(() => _playing = s.playing);
        }
      });
      _player = player;
      setState(() { _inited = true; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggle() async {
    await _init();
    if (_player == null) return;
    _playing ? await _player!.pause() : await _player!.play();
  }

  Future<void> _seekToFraction(double f) async {
    if (_player == null) await _init();
    if (_player == null) return;
    final ms = (_total.inMilliseconds * f.clamp(0.0, 1.0)).round();
    await _player!.seek(Duration(milliseconds: ms));
    if (!_playing) await _player!.play();
  }

  Future<void> _cycleSpeed() async {
    const speeds = [1.0, 1.5, 2.0];
    final next = speeds[(speeds.indexOf(_speed) + 1) % speeds.length];
    setState(() => _speed = next);
    await _player?.setSpeed(next);
  }

  String _fmt(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  double get _progress {
    final total = _total.inMilliseconds > 0
        ? _total.inMilliseconds : widget.durationSec * 1000;
    if (total == 0) return 0;
    return (_pos.inMilliseconds / total).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final totalShow = _total.inSeconds > 0
        ? _total : Duration(seconds: widget.durationSec);
    final metaColor = widget.isMe ? Colors.black45 : Colors.white54;
    final dimColor  = widget.isMe ? Colors.black12 : Colors.white12;
    final iconColor = widget.isMe ? Colors.black87 : Colors.white70;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        if (_loading)
          SizedBox(width: 38, height: 38,
              child: CircularProgressIndicator(strokeWidth: 2, color: metaColor))
        else
          GestureDetector(
            onTap: _toggle,
            child: Container(
              width: 38, height: 38,
              decoration: BoxDecoration(shape: BoxShape.circle, color: dimColor),
              child: Icon(
                  _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: iconColor, size: 24),
            ),
          ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LayoutBuilder(builder: (_, bc) {
                return GestureDetector(
                  onTapDown: (d) =>
                      _seekToFraction(d.localPosition.dx / bc.maxWidth),
                  onHorizontalDragUpdate: (d) =>
                      _seekToFraction(
                          (d.localPosition.dx / bc.maxWidth).clamp(0.0, 1.0)),
                  child: SizedBox(
                    width: bc.maxWidth, height: _kWaveHeight,
                    child: CustomPaint(
                      painter: _WaveformPainter(
                        envelope: _envelope,
                        progress: _progress,
                        isMe:     widget.isMe,
                      ),
                    ),
                  ),
                );
              }),
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                  Text(_fmt(_pos),
                      style: TextStyle(fontSize: 10, color: metaColor)),
                  Text(_fmt(totalShow),
                      style: TextStyle(fontSize: 10, color: metaColor)),
                ]),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _cycleSpeed,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
            decoration: BoxDecoration(
                color: dimColor, borderRadius: BorderRadius.circular(6)),
            child: Text(
              _speed % 1 == 0 ? '${_speed.toInt()}x' : '${_speed}x',
              style: TextStyle(fontSize: 13, color: metaColor,
                  fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ]),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final List<double> envelope;
  final double       progress;
  final bool         isMe;

  const _WaveformPainter({
    required this.envelope,
    required this.progress,
    required this.isMe,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (envelope.isEmpty) return;
    final n     = envelope.length;
    final cx    = size.height / 2;
    final headX = size.width * progress;
    final slotW = size.width / n;
    final barW  = (slotW * 0.60).clamp(1.5, 5.0);
    final pad   = (slotW - barW) / 2;

    final playedPaint = Paint()..style = PaintingStyle.fill
      ..color = isMe ? _kGoldPlayed : _kBluePlayed;
    final dimPaint    = Paint()..style = PaintingStyle.fill
      ..color = isMe ? _kGoldUnplayed : _kBlueUnplayed;

    for (var i = 0; i < n; i++) {
      final amp   = envelope[i].clamp(0.04, 1.0);
      final halfH = math.max(2.5, amp * cx * 0.90);
      final x     = i * slotW + pad;
      final mid   = x + barW / 2;
      canvas.drawRRect(
        RRect.fromLTRBR(
          x, cx - halfH, x + barW, cx + halfH,
          Radius.circular(barW / 2),
        ),
        mid <= headX ? playedPaint : dimPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) =>
      old.progress != progress || old.isMe != isMe || old.envelope != envelope;
}

class WaveformBars extends StatelessWidget {
  final List<double> rawDb;
  final bool         isMe;

  const WaveformBars({super.key, required this.rawDb, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: CustomPaint(
        size: const Size(double.infinity, 32),
        painter: _LiveWavePainter(rawDb: rawDb, isMe: isMe),
      ),
    );
  }
}

class _LiveWavePainter extends CustomPainter {
  final List<double> rawDb;
  final bool         isMe;

  const _LiveWavePainter({required this.rawDb, required this.isMe});

  @override
  void paint(Canvas canvas, Size size) {
    const barW  = 3.0;
    const slotW = 5.0;
    final cx    = size.height / 2;
    final maxN  = (size.width / slotW).floor();
    final basePaint = Paint()..style = PaintingStyle.fill;

    if (rawDb.isEmpty) {
      basePaint.color = isMe ? _kGoldUnplayed : _kBlueUnplayed;
      for (var i = 0; i < maxN; i++) {
        canvas.drawRRect(
          RRect.fromLTRBR(
              i * slotW, cx - 2.0, i * slotW + barW, cx + 2.0,
              const Radius.circular(1.5)),
          basePaint,
        );
      }
      return;
    }

    final normalized = _normalizeDb(rawDb);
    final vis    = normalized.length > maxN
        ? normalized.sublist(normalized.length - maxN) : normalized;
    final count  = vis.length;
    final startI = maxN - count;
    basePaint.color = isMe ? _kGoldPlayed : _kBluePlayed;

    for (var i = 0; i < count; i++) {
      final amp   = vis[i].clamp(0.04, 1.0);
      final halfH = math.max(2.0, amp * cx * 0.82);
      final x     = (startI + i) * slotW;
      canvas.drawRRect(
        RRect.fromLTRBR(x, cx - halfH, x + barW, cx + halfH,
            const Radius.circular(1.5)),
        basePaint,
      );
    }
  }

  @override
  bool shouldRepaint(_LiveWavePainter old) => old.rawDb != rawDb;
}
