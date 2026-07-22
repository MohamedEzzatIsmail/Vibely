part of 'chat.dart';

class _MediaPickerButton extends StatelessWidget {
  final String    receiverId;
  final ChatCubit cubit;
  const _MediaPickerButton({required this.receiverId, required this.cubit});

  void _show(BuildContext context) {
    showModalBottomSheet(
      context: context, backgroundColor: AppColors.of(context).surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        _sheetHandle(),
        _tile(context, Icons.image_rounded,      'Send Image',    () async {
          final ok = await MediaPermissionService.requestMediaPermission(context);
          if (!ok) return;
          final p = await ImagePicker().pickImage(
              source: ImageSource.gallery, imageQuality: 80);
          if (p != null) cubit.sendImage(receiverId: receiverId, imageFile: File(p.path));
        }),
        _tile(context, Icons.camera_alt_rounded, 'Take Photo',    () async {
          final ok = await MediaPermissionService.requestMediaPermission(context);
          if (!ok) return;
          final p = await ImagePicker().pickImage(
              source: ImageSource.camera, imageQuality: 85);
          if (p != null) cubit.sendImage(receiverId: receiverId, imageFile: File(p.path));
        }),
        _tile(context, Icons.videocam_rounded,   'Send Video',    () async {
          final ok = await MediaPermissionService.requestMediaPermission(context);
          if (!ok) return;
          final p = await ImagePicker().pickVideo(source: ImageSource.gallery);
          if (p != null) cubit.sendVideo(receiverId: receiverId, videoFile: File(p.path));
        }),
        _tile(context, Icons.video_call_rounded, AppStrings.of(context).recordVideo,  () async {
          final ok = await MediaPermissionService.requestMediaPermission(context);
          if (!ok) return;
          final p = await ImagePicker().pickVideo(source: ImageSource.camera);
          if (p != null) cubit.sendVideo(receiverId: receiverId, videoFile: File(p.path));
        }),
        const SizedBox(height: 8),
      ])),
    );
  }

  Widget _tile(BuildContext ctx, IconData icon, String label, VoidCallback onTap) =>
      ListTile(
        leading: Icon(icon, color: _kGold),
        title: Text(label, style: TextStyle(color: AppColors.of(ctx).textSub)),
        onTap: () { Navigator.pop(ctx); onTap(); },
      );

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => _show(context),
    child: Container(width: 44, height: 44,
        decoration: BoxDecoration(shape: BoxShape.circle, color: _kSurface2,
            border: Border.all(color: const Color(0x30FFFFFF))),
        child: const Icon(Icons.attach_file_rounded, color: Colors.white60, size: 20)),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
//  HELPERS
// ══════════════════════════════════════════════════════════════════════════════
Widget _sheetHandle() => Container(
  margin: const EdgeInsets.symmetric(vertical: 8),
  width: 36, height: 4,
  decoration: BoxDecoration(
      color: Colors.white24, borderRadius: BorderRadius.circular(2)),
);

class _UploadProgressBubble extends StatelessWidget {
  final double? progress;
  const _UploadProgressBubble({required this.progress});
  @override Widget build(BuildContext context) => Container(
    width: 60, height: 60,
    decoration: const BoxDecoration(shape: BoxShape.circle,
        gradient: LinearGradient(colors: [Color(0xFFE5C687), Color(0xFFB8964A)])),
    child: Stack(alignment: Alignment.center, children: [
      SizedBox.expand(child: CircularProgressIndicator(
          value: progress, color: Colors.black26, strokeWidth: 3)),
      const Icon(Icons.upload_rounded, color: Colors.black54, size: 22),
      if (progress != null) Positioned(bottom: 10,
          child: Text('${(progress! * 100).round()}%',
              style: const TextStyle(color: Colors.black54, fontSize: 8,
                  fontWeight: FontWeight.bold))),
    ]),
  );
}

class _DateSeparator extends StatelessWidget {
  final DateTime date;
  const _DateSeparator({required this.date});
  String _label(BuildContext context) {
    final isAr  = Localizations.localeOf(context).languageCode == 'ar';
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d     = DateTime(date.year, date.month, date.day);
    final diff  = today.difference(d).inDays;
    if (diff == 0) return isAr ? 'اليوم' : 'Today';
    if (diff == 1) return isAr ? 'أمس' : 'Yesterday';
    if (diff < 7) {
      const en = ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'];
      const ar = ['الاثنين','الثلاثاء','الأربعاء','الخميس','الجمعة','السبت','الأحد'];
      return isAr ? ar[d.weekday - 1] : en[d.weekday - 1];
    }
    const mEn = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    const mAr = ['يناير','فبراير','مارس','أبريل','مايو','يونيو','يوليو','أغسطس','سبتمبر','أكتوبر','نوفمبر','ديسمبر'];
    final month = isAr ? mAr[d.month - 1] : mEn[d.month - 1];
    return isAr ? '${d.day} $month ${d.year}' : '${d.day} $month ${d.year}';
  }
  @override Widget build(BuildContext context) => Center(child: Container(
    margin: const EdgeInsets.symmetric(vertical: 8),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
    decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12)),
    child: Builder(builder: (ctx) => Text(_label(ctx),
        style: TextStyle(fontSize: 11, color: AppColors.of(context).textSub))),
  ));
}

class _ProfileActionBtn extends StatelessWidget {
  final IconData icon; final String label; final VoidCallback onTap;
  const _ProfileActionBtn({required this.icon, required this.label, required this.onTap});
  @override Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Column(children: [
      Container(width: 52, height: 52,
          decoration: BoxDecoration(shape: BoxShape.circle, color: _kSurface2,
              border: Border.all(color: Colors.white12)),
          child: Icon(icon, color: AppColors.of(context).textSub, size: 22)),
      const SizedBox(height: 4),
      Text(label, style: TextStyle(color: AppColors.of(context).textHint, fontSize: 11)),
    ]),
  );
}

class _CircleButton extends StatelessWidget {
  final IconData icon; final VoidCallback onTap; final bool filled;
  const _CircleButton({super.key, required this.icon, required this.onTap,
    this.filled = false});
  @override Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(width: 44, height: 44,
        decoration: BoxDecoration(shape: BoxShape.circle,
            gradient: filled ? const LinearGradient(
                colors: [Color(0xFFE5C687), Color(0xFFB8964A)],
                begin: Alignment.topLeft, end: Alignment.bottomRight) : null,
            color: filled ? null : AppColors.of(context).elevated,
            border: filled ? null : Border.all(color: AppColors.of(context).border)),
        child: Icon(icon, color: filled ? Colors.black87 : AppColors.of(context).textSub, size: 20)),
  );
}

class _EmojiButton extends StatefulWidget {
  final String emoji; final VoidCallback onTap;
  const _EmojiButton({required this.emoji, required this.onTap});
  @override State<_EmojiButton> createState() => _EmojiButtonState();
}
class _EmojiButtonState extends State<_EmojiButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  @override void initState() { super.initState();
  _ctrl = AnimationController(vsync: this,
      duration: const Duration(milliseconds: 120));
  _scale = Tween(begin: 1.0, end: 1.3)
      .chain(CurveTween(curve: Curves.easeOut)).animate(_ctrl);
  }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => GestureDetector(
      onTap: () async { await _ctrl.forward(); _ctrl.reverse(); widget.onTap(); },
      child: ScaleTransition(scale: _scale,
          child: Padding(padding: const EdgeInsets.all(6),
              child: Text(widget.emoji,
                  style: const TextStyle(fontSize: 26)))));
}

class _ActionTile extends StatelessWidget {
  final IconData icon; final String label; final Color? color;
  final VoidCallback onTap;
  const _ActionTile({required this.icon, required this.label,
    required this.onTap, this.color});
  @override Widget build(BuildContext context) {
    final c = color ?? Colors.white70;
    return ListTile(dense: true,
        leading: Icon(icon, color: c, size: 22),
        title: Text(label, style: TextStyle(color: c, fontSize: 14)),
        onTap: onTap);
  }
}

class _ReactionBubble extends StatelessWidget {
  final Map<String, List<String>> reactions;
  final String? myUid; final bool isMe;
  const _ReactionBubble({required this.reactions, required this.myUid,
    required this.isMe});
  @override Widget build(BuildContext context) {
    final entries = reactions.entries.where((e) => e.value.isNotEmpty).toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));
    if (entries.isEmpty) return const SizedBox.shrink();
    final total    = reactions.values.fold(0, (s, l) => s + l.length);
    final iReacted = myUid != null &&
        reactions.values.any((l) => l.contains(myUid));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: iReacted ? _kGold.withValues(alpha: 0.18) : _kSurface2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: iReacted ? _kGold.withValues(alpha: 0.6) : const Color(0x30FFFFFF),
            width: 1),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        ...entries.take(3).map((e) =>
            Text(e.key, style: const TextStyle(fontSize: 12))),
        if (total > 1) ...[
          const SizedBox(width: 3),
          Text('$total', style: TextStyle(fontSize: 11,
              fontWeight: FontWeight.w600,
              color: iReacted ? _kGold : Colors.white54)),
        ],
      ]),
    );
  }
}

class _ReplyQuote extends StatelessWidget {
  final MessageModel msg; final bool isMe;
  const _ReplyQuote({required this.msg, required this.isMe});
  @override Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 6),
    padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
    decoration: BoxDecoration(
        color: isMe ? Colors.black.withValues(alpha: 0.12)
            : Colors.black.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: const Border(left: BorderSide(color: _kGold, width: 3))),
    child: Row(children: [
      if (msg.replyToMediaUrl != null) ...[
        ClipRRect(borderRadius: BorderRadius.circular(5),
            child: CachedNetworkImage(imageUrl: msg.replyToMediaUrl!,
                width: 36, height: 36, fit: BoxFit.cover)),
        const SizedBox(width: 8),
      ],
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(msg.replyToSenderName ?? '',
            style: const TextStyle(color: _kGold, fontSize: 11,
                fontWeight: FontWeight.w700)),
        Text(msg.replyToIsStory == true ? '📸 Story reply' : (msg.replyToText ?? ''),
            style: const TextStyle(color: Colors.black54, fontSize: 11),
            maxLines: 2, overflow: TextOverflow.ellipsis),
      ])),
    ]),
  );
}

// ── Full-screen image viewer (Prompt 13) ─────────────────────────────────────
class _InlineImage extends StatelessWidget {
  final String imageUrl; final String? caption;
  const _InlineImage({required this.imageUrl, this.caption});
  @override Widget build(BuildContext context) => GestureDetector(
    onTap: () => Navigator.push(context, PageRouteBuilder(
        opaque: false, barrierColor: Colors.black87,
        pageBuilder: (_, _, ___) =>
            _FullScreenImageViewer(imageUrl: imageUrl, caption: caption))),
    child: ClipRRect(borderRadius: BorderRadius.circular(10),
        child: CachedNetworkImage(imageUrl: imageUrl, width: 220, fit: BoxFit.cover,
            placeholder: (_, _) => Container(width: 220, height: 150,
                color: Colors.black26,
                child: const Center(child: CircularProgressIndicator(
                    color: _kGold, strokeWidth: 2))))),
  );
}

class _FullScreenImageViewer extends StatefulWidget {
  final String imageUrl; final String? caption;
  const _FullScreenImageViewer({required this.imageUrl, this.caption});
  @override State<_FullScreenImageViewer> createState() =>
      _FullScreenImageViewerState();
}
class _FullScreenImageViewerState extends State<_FullScreenImageViewer> {
  double _dy = 0;
  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black.withValues(alpha: 1 - (_dy / 300).clamp(0.0, 0.8)),
    body: Stack(children: [
      GestureDetector(
        onVerticalDragUpdate: (d) => setState(() => _dy += d.delta.dy),
        onVerticalDragEnd: (_) {
          if (_dy > 100) Navigator.pop(context);
          else setState(() => _dy = 0);
        },
        child: Center(child: Transform.translate(
          offset: Offset(0, _dy),
          child: InteractiveViewer(minScale: 0.8, maxScale: 5.0,
              child: CachedNetworkImage(
                  imageUrl: widget.imageUrl, fit: BoxFit.contain)),
        )),
      ),
      Positioned(top: 40, right: 12,
          child: IconButton(
              icon: Icon(Icons.close_rounded, color: AppColors.of(context).text),
              onPressed: () => Navigator.pop(context))),
      if (widget.caption?.isNotEmpty == true)
        Positioned(bottom: 0, left: 0, right: 0,
            child: Container(padding: const EdgeInsets.all(16),
                color: Colors.black54,
                child: Text(widget.caption!,
                    style: TextStyle(color: AppColors.of(context).text, fontSize: 14)))),
    ]),
  );
}

// ── Inline video player ───────────────────────────────────────────────────────
class _InlineVideoPlayer extends StatefulWidget {
  final String videoUrl;
  const _InlineVideoPlayer({required this.videoUrl});
  @override State<_InlineVideoPlayer> createState() => _InlineVideoPlayerState();
}
class _InlineVideoPlayerState extends State<_InlineVideoPlayer> {
  Player? _player; VideoController? _ctrl;
  bool _ready = false; bool _playing = false; bool _loading = false;
  @override void dispose() { _player?.dispose(); super.dispose(); }
  Future<void> _toggle() async {
    if (_player != null) {
      setState(() => _playing = !_playing);
      _playing ? _player!.play() : _player!.pause();
      return;
    }
    setState(() => _loading = true);
    try {
      final p = Player(); final c = VideoController(p);
      await p.open(Media(widget.videoUrl), play: false);
      try { await p.stream.videoParams.first.timeout(const Duration(seconds: 10)); }
      catch (_) {}
      if (!mounted) { p.dispose(); return; }
      setState(() { _player = p; _ctrl = c; _ready = true; _loading = false; _playing = true; });
      p.play();
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }
  @override Widget build(BuildContext context) => GestureDetector(
      onTap: _toggle,
      child: ClipRRect(borderRadius: BorderRadius.circular(10),
          child: Stack(alignment: Alignment.center, children: [
            _ready && _ctrl != null
                ? AspectRatio(aspectRatio: 9/16,
                child: Video(controller: _ctrl!, controls: NoVideoControls))
                : Container(height: 150, color: Colors.black26,
                child: Center(child: Icon(Icons.videocam_rounded,
                    color: AppColors.of(context).textHint, size: 36))),
            if (_loading) const CircularProgressIndicator(color: _kGold, strokeWidth: 2),
            if (!_loading && !_playing) Container(padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                child: Icon(Icons.play_arrow_rounded, color: AppColors.of(context).text, size: 30)),
          ])));
}

class _SharedPostCard extends StatelessWidget {
  final MessageModel msg; final bool isMe;
  const _SharedPostCard({required this.msg, required this.isMe});
  @override Widget build(BuildContext context) {
    if (msg.sharedPostDeleted == true) {
      return Container(margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white24)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.info_outline_rounded, color: AppColors.of(context).textHint, size: 15),
            const SizedBox(width: 6),
            Text(AppStrings.of(context).thisPostDeleted, style: const TextStyle(
                fontSize: 12, fontStyle: FontStyle.italic, color: Colors.black45)),
          ]));
    }
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PostDetailsScreen(
            postId: msg.sharedPostId!,
          ),
        ),
      ),
      child: Container(margin: const EdgeInsets.only(bottom: 6),
          decoration: BoxDecoration(
              color: isMe ? Colors.black.withValues(alpha: 0.1)
                  : Colors.white.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black.withValues(alpha: 0.08))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (msg.sharedPostImage?.isNotEmpty == true)
              ClipRRect(borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12)),
                  child: CachedNetworkImage(imageUrl: msg.sharedPostImage!,
                      height: 110, width: double.infinity, fit: BoxFit.cover)),
            Padding(padding: const EdgeInsets.all(8), child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                if (msg.sharedPostOwnerImage?.isNotEmpty == true)
                  CircleAvatar(radius: 9,
                      backgroundImage: NetworkImage(msg.sharedPostOwnerImage!)),
                const SizedBox(width: 5),
                Text(msg.sharedPostOwnerName ?? '', style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 12,
                    color: Colors.black87)),
              ]),
              if (msg.sharedPostText?.isNotEmpty == true) ...[
                const SizedBox(height: 3),
                Text(msg.sharedPostText!, maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Colors.black54)),
              ],
              const SizedBox(height: 4),
              Text(AppStrings.of(context).tapToView, style: const TextStyle(
                  fontSize: 11, color: _kGoldDim, fontWeight: FontWeight.w600)),
            ])),
          ])),
    );
  }
}
