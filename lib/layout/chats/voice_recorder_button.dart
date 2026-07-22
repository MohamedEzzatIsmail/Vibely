// lib/layout/chats/voice_recorder_button.dart
// WhatsApp-style voice recorder — latest version.

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../layout/cubit/chat/chat_cubit.dart';
import '../../share/local/app_strings.dart';
import 'voice_message_player.dart' show WaveformBars;

const _kGold    = Color(0xFFE5C687);
const _kGoldDim = Color(0xFFB8964A);
const _kRed     = Color(0xFFFF4D4D);
const _kSurface = Color(0xFF21262D);
const _kInputBg = Color(0xFF161B22);

const _kMaxSamples    = 750;
const _kMinRecordSecs = 1;

class MicButton extends StatefulWidget {
  final String?   receiverId;
  final String?   groupId;
  final ChatCubit cubit;

  const MicButton({
    super.key,
    this.receiverId,
    this.groupId,
    required this.cubit,
  }) : assert(
    receiverId != null || groupId != null,
    'Pass either receiverId (DM) or groupId (Group)',
  );

  @override
  State<MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends State<MicButton> with TickerProviderStateMixin {
  final _recorder = FlutterSoundRecorder();
  bool    _ready     = false;
  bool    _recording = false;
  bool    _locked    = false;
  String? _filePath;
  int     _seconds   = 0;
  Timer?  _timer;

  final List<double> _rawDb = [];
  StreamSubscription<RecordingDisposition>? _ampSub;

  OverlayEntry? _overlayEntry;
  final _micKey = GlobalKey();

  double _totalDX   = 0;
  double _totalDY   = 0;
  bool   _didCancel = false;
  bool   _didLock   = false;

  static const double _cancelThresh = -90.0;
  static const double _lockThresh   = -70.0;

  late final AnimationController _micScaleCtrl;
  late final AnimationController _cancelCtrl;
  late final AnimationController _lockCtrl;
  late final AnimationController _bounceCtrl;

  late final Animation<double> _micScale;
  late final Animation<double> _cancelFade;
  late final Animation<double> _lockFade;
  late final Animation<double> _bounce;

  @override
  void initState() {
    super.initState();

    _micScaleCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 130));
    _micScale = Tween(begin: 1.0, end: 1.3)
        .chain(CurveTween(curve: Curves.easeOut))
        .animate(_micScaleCtrl);

    _cancelCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 200));
    _cancelFade = CurvedAnimation(parent: _cancelCtrl, curve: Curves.easeOut);

    _lockCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 200));
    _lockFade = CurvedAnimation(parent: _lockCtrl, curve: Curves.easeOut);

    _bounceCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 450))
      ..repeat(reverse: true);
    _bounce = Tween(begin: 0.0, end: -8.0)
        .chain(CurveTween(curve: Curves.easeInOut))
        .animate(_bounceCtrl);

    _initRecorder();
  }

  Future<void> _initRecorder() async {
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) return;
    await _recorder.openRecorder();
    await _recorder.setSubscriptionDuration(
        const Duration(milliseconds: 80));
    if (mounted) setState(() => _ready = true);
  }

  @override
  void dispose() {
    _removeOverlay();
    _micScaleCtrl.dispose();
    _cancelCtrl.dispose();
    _lockCtrl.dispose();
    _bounceCtrl.dispose();
    _timer?.cancel();
    _ampSub?.cancel();
    _recorder.closeRecorder();
    super.dispose();
  }

  void _showOverlay() {
    _removeOverlay();
    _overlayEntry = OverlayEntry(builder: (_) => _RecordingOverlay(state: this));
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _refreshOverlay() => _overlayEntry?.markNeedsBuild();

  Future<void> _start() async {
    if (!_ready || _recording) return;
    final dir = await getTemporaryDirectory();
    _filePath = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.aac';

    await _recorder.startRecorder(
      toFile: _filePath, codec: Codec.aacADTS,
      sampleRate: 44100, bitRate: 128000, numChannels: 1,
    );

    _ampSub = _recorder.onProgress!.listen((d) {
      final db = d.decibels ?? -160.0;
      if (mounted) {
        _rawDb.add(db);
        if (_rawDb.length > _kMaxSamples) _rawDb.removeAt(0);
        _refreshOverlay();
      }
    });

    setState(() {
      _recording = true; _locked = false; _didCancel = false;
      _didLock = false; _totalDX = 0; _totalDY = 0;
      _seconds = 0; _rawDb.clear();
    });

    HapticFeedback.mediumImpact();
    _micScaleCtrl.forward();
    _showOverlay();

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) { _seconds++; _refreshOverlay(); }
    });
  }

  Future<void> _send() async {
    if (!_recording) return;
    if (_seconds < _kMinRecordSecs) {
      await _cancelSilent();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(AppStrings.of(context).holdToRecord2),
          duration: const Duration(seconds: 2),
        ));
      }
      return;
    }
    _cleanUp();
    final path = await _recorder.stopRecorder();
    if (!mounted) return;
    setState(() { _recording = false; _locked = false; });
    _removeOverlay();
    if (path == null) return;

    final rawCopy = List<double>.from(_rawDb);
    if (widget.receiverId != null) {
      widget.cubit.sendVoice(
        receiverId: widget.receiverId!, audioFile: File(path),
        durationSeconds: _seconds, waveformData: rawCopy,
      );
    } else {
      widget.cubit.sendGroupVoice(
        groupId: widget.groupId!, audioFile: File(path),
        durationSeconds: _seconds, waveformData: rawCopy,
      );
    }
  }

  Future<void> _cancel() async {
    if (!_recording) return;
    _cleanUp();
    await _recorder.stopRecorder();
    if (!mounted) return;
    setState(() { _recording = false; _locked = false; _didCancel = false; });
    _removeOverlay();
    HapticFeedback.lightImpact();
  }

  Future<void> _cancelSilent() async {
    if (!_recording) return;
    _cleanUp();
    await _recorder.stopRecorder();
    if (!mounted) return;
    setState(() { _recording = false; _locked = false; _didCancel = false; });
    _removeOverlay();
  }

  void _cleanUp() {
    _timer?.cancel();
    _ampSub?.cancel();
    _micScaleCtrl.reverse();
    _cancelCtrl.reverse();
    _lockCtrl.reverse();
  }

  void _onPanUpdateFromLongPress(Offset offsetFromOrigin) {
    if (!_recording || _locked) return;
    _totalDX = offsetFromOrigin.dx;
    _totalDY = offsetFromOrigin.dy;
    _cancelCtrl.value = (_totalDX / _cancelThresh).clamp(0.0, 1.0);
    _lockCtrl.value   = (_totalDY / _lockThresh).clamp(0.0, 1.0);
    _refreshOverlay();

    if (_totalDX <= _cancelThresh && !_didCancel) {
      _didCancel = true;
      HapticFeedback.heavyImpact();
      _cancel();
      return;
    }
    if (_totalDY <= _lockThresh && !_didLock) {
      _didLock = true;
      HapticFeedback.lightImpact();
      setState(() => _locked = true);
      _cancelCtrl.reverse();
      _lockCtrl.animateTo(0, duration: const Duration(milliseconds: 300));
      _refreshOverlay();
    }
  }

  String _fmt(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:'
      '${(s % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: _micKey,
      onLongPressStart: (_) => _start(),
      onLongPressMoveUpdate: (d) => _onPanUpdateFromLongPress(d.offsetFromOrigin),
      onLongPressEnd: (_) { if (_recording && !_locked) _send(); },
      onLongPressCancel: () { if (_recording && !_locked) _cancel(); },
      child: _locked
          ? GestureDetector(
              onTap: _cancel,
              child: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle, color: _kRed,
                  boxShadow: [BoxShadow(
                      color: _kRed.withValues(alpha: 0.5), blurRadius: 12, spreadRadius: 2)],
                ),
                child: const Icon(Icons.lock_rounded, color: Colors.white, size: 20),
              ),
            )
          : _recording
              ? ScaleTransition(
                  scale: _micScale,
                  child: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const RadialGradient(
                          colors: [Color(0xFFE5C687), Color(0xFFB8964A)]),
                      boxShadow: [BoxShadow(
                          color: _kGold.withValues(alpha: 0.5), blurRadius: 14, spreadRadius: 2)],
                    ),
                    child: const Icon(Icons.mic_rounded, color: Colors.black87, size: 22),
                  ),
                )
              : Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle, color: _kSurface,
                    border: Border.all(color: const Color(0x30FFFFFF)),
                  ),
                  child: const Icon(Icons.mic_rounded, color: Colors.white60, size: 20),
                ),
    );
  }
}

class _RecordingOverlay extends StatelessWidget {
  final _MicButtonState state;
  const _RecordingOverlay({required this.state});

  @override
  Widget build(BuildContext context) {
    final s = state;
    if (!s._recording) return const SizedBox.shrink();
    final box    = s._micKey.currentContext?.findRenderObject() as RenderBox?;
    final micPos = box?.localToGlobal(Offset.zero);
    final screenH  = MediaQuery.of(context).size.height;
    final barBottom = micPos != null ? screenH - micPos.dy + 8 : 80.0;
    const barHeight = 56.0;

    return Stack(children: [
      Positioned(
        bottom: barBottom, left: 12, right: 12, height: barHeight,
        child: _RecordingBar(state: s),
      ),
      if (!s._locked)
        Positioned(
          bottom: barBottom + barHeight + 8, right: 16,
          child: AnimatedBuilder(
            animation: s._lockFade,
            builder: (_, _) => Opacity(
              opacity: s._lockFade.value,
              child: Transform.translate(
                offset: Offset(0, 10 * (1 - s._lockFade.value)),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.lock_open_rounded,
                      color: _kGold.withValues(alpha: s._lockFade.value), size: 22),
                  const SizedBox(height: 2),
                  Icon(Icons.arrow_upward_rounded,
                      color: _kGold.withValues(alpha: s._lockFade.value * 0.6), size: 14),
                ]),
              ),
            ),
          ),
        ),
      if (s._locked)
        Positioned(
          bottom: barBottom + barHeight + 4, right: 16,
          child: GestureDetector(
            onTap: s._send,
            child: AnimatedBuilder(
              animation: s._bounce,
              builder: (_, child) => Transform.translate(
                  offset: Offset(0, s._bounce.value), child: child),
              child: Container(
                width: 48, height: 48,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                      colors: [_kGold, _kGoldDim],
                      begin: Alignment.topLeft, end: Alignment.bottomRight),
                  boxShadow: [BoxShadow(
                      color: Color(0x66E5C687), blurRadius: 12, spreadRadius: 2)],
                ),
                child: const Icon(Icons.send_rounded, color: Colors.black87, size: 22),
              ),
            ),
          ),
        ),
    ]);
  }
}

class _RecordingBar extends StatelessWidget {
  final _MicButtonState state;
  const _RecordingBar({required this.state});

  @override
  Widget build(BuildContext context) {
    final s = state;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: _kInputBg,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0x22FFFFFF)),
        boxShadow: const [BoxShadow(
            color: Color(0x44000000), blurRadius: 8, offset: Offset(0, -2))],
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        _PulsingDot(),
        const SizedBox(width: 8),
        Text(s._fmt(s._seconds),
            style: const TextStyle(
              color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600,
              fontFeatures: [FontFeature.tabularFigures()],
            )),
        const SizedBox(width: 8),
        Expanded(child: WaveformBars(rawDb: s._rawDb, isMe: true)),
        const SizedBox(width: 6),
        AnimatedBuilder(
          animation: s._cancelFade,
          builder: (_, _) => Opacity(
            opacity: s._cancelFade.value,
            child: Transform.translate(
              offset: Offset(-10 * (1 - s._cancelFade.value), 0),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.arrow_back_ios_rounded,
                    color: _kRed.withValues(alpha: s._cancelFade.value), size: 13),
                const SizedBox(width: 2),
                Text(AppStrings.of(context).cancel, style: TextStyle(
                    color: _kRed.withValues(alpha: s._cancelFade.value), fontSize: 12)),
              ]),
            ),
          ),
        ),
        const SizedBox(width: 8),
        if (s._locked) const Icon(Icons.lock_rounded, color: _kGold, size: 16),
      ]),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  @override State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _a;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
    _a = Tween(begin: 0.5, end: 1.0)
        .chain(CurveTween(curve: Curves.easeInOut))
        .animate(_c);
  }

  @override void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _a,
    builder: (_, _) => Opacity(
      opacity: _a.value,
      child: Container(
          width: 9, height: 9,
          decoration: const BoxDecoration(color: _kRed, shape: BoxShape.circle)),
    ),
  );
}
