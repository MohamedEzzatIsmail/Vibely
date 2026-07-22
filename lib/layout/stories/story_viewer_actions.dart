part of 'story_viewer.dart';

// ──────────────────────────────────────────────────────────────────────────────
//  Action methods extracted from _StoryViewerState.
//  Kept as an extension (not a separate class) so every method below keeps
//  full access to _StoryViewerState's fields and setState, exactly as if this
//  code still lived inline in story_viewer.dart. Nothing about behavior
//  changes — only the file these methods live in.
// ──────────────────────────────────────────────────────────────────────────────
extension StoryViewerActions on _StoryViewerState {
  Future<void> _initSlide(int idx) async {
    if (!mounted) return;
    _advancing = false;
    _progress.stop();

    // Dispose old player immediately
    final oldPlayer = _player;
    _player = null;
    _videoCtrl = null;
    _mediaReady = false;
    _videoError = false;

    if (mounted) setState(() { _idx = idx; _paused = false; });
    oldPlayer?.dispose();

    final story = widget.stories[idx];
    StoriesCubit.get(context).markSeen(story.storyId);

    if (story.isVideo) {
      _initVideoNoAwait(story);
    } else {
      _progress.duration = const Duration(seconds: 5);
    }
  }

  /// Fire-and-forget video init — no await on open() so there is ZERO black screen.
  void _initVideoNoAwait(StoryModel story) {
    final player = Player();
    final ctrl = VideoController(player);

    // Assign controller & show Video widget IMMEDIATELY — before buffering starts.
    // media_kit renders a black frame initially which is fine; the real frame
    // appears within ~1 frame of play().  This eliminates the multi-second black gap.
    _player = player;
    _videoCtrl = ctrl;
    if (mounted) setState(() { _mediaReady = true; });

    final trimStart = story.trimStartMs != null
        ? Duration(milliseconds: story.trimStartMs!)
        : Duration.zero;

    // Open media asynchronously — do NOT await
    player.open(Media(story.mediaUrl), play: false).then((_) async {
      if (!mounted) { player.dispose(); return; }
      // Seek to trim start then play
      await player.seek(trimStart);
      if (!mounted) { player.dispose(); return; }
      player.play();

      // Start progress bar — duration stream will refine it
      _progress.duration = const Duration(seconds: 15); // fallback
      _progress.forward(from: 0);
    }).catchError((_) {
      player.dispose();
      if (mounted) {
        setState(() { _videoError = true; _player = null; _videoCtrl = null; });
        _progress.duration = const Duration(seconds: 5);
        _progress.forward(from: 0);
      }
    });

    // Refine duration once stream delivers it
    player.stream.duration.listen((dur) {
      if (!mounted || dur.inMilliseconds < 200) return;
      final end = story.trimEndMs != null
          ? Duration(milliseconds: story.trimEndMs!)
          : dur;
      final window = end - trimStart;
      if (window.inMilliseconds > 200) {
        final pos = player.state.position - trimStart;
        final frac =
            (pos.inMilliseconds / window.inMilliseconds).clamp(0.0, 1.0);
        _progress.duration = window;
        if (!_paused) _progress.forward(from: frac);
      }
    });

    // Trim-end guard
    player.stream.position.listen((pos) {
      if (!mounted) return;
      final endMs = story.trimEndMs;
      if (endMs != null && pos.inMilliseconds >= endMs) _next();
    });
  }

  void _onImageLoaded() {
    if (!mounted || _paused || _mediaReady) return;
    _mediaReady = true;
    _progress.forward(from: 0);
  }

  void _next() {
    if (_advancing || !mounted) return;
    _advancing = true;
    if (_idx < widget.stories.length - 1) {
      _initSlide(_idx + 1);
    } else {
      if (widget.onFinished != null) {
        widget.onFinished!();
      } else {
        Navigator.pop(context);
      }
    }
  }

  void _prev() {
    if (!mounted) return;
    if (_idx > 0) _initSlide(_idx - 1);
  }

  void _pause() {
    if (_paused) return;
    _progress.stop();
    _player?.pause();
    _paused = true;
    if (mounted) setState(() {});
  }

  void _resume() {
    if (!_paused) return;
    _paused = false;
    if (_mediaReady) {
      _progress.forward();
      _player?.play();
    }
    if (mounted) setState(() {});
  }

  Future<void> _reactToStory(String emoji) async {
    final story = widget.stories[_idx];
    await StoriesCubit.get(context).toggleStoryReaction(story.storyId, emoji);
    if (!mounted) return;
    // Floating emoji animation feedback
    _showEmojiFloat(emoji);
  }

  void _showEmojiFloat(String emoji) {
    final overlay = Overlay.of(context);
    final entry = OverlayEntry(builder: (_) => _EmojiFloatAnim(emoji: emoji));
    overlay.insert(entry);
    Future.delayed(const Duration(milliseconds: 1200), entry.remove);
  }

  void _showReactionPicker(StoryModel liveStory) {
    _pause();
    final myUid = StoriesCubit.get(context).currentUser?.uid ?? '';
    // Find which emoji (if any) this user already used
    String? myReaction;
    for (final e in liveStory.reactions.entries) {
      if (e.value.contains(myUid)) { myReaction = e.key; break; }
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C2128),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 36, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                  color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: ['❤️', '😂', '😮', '😢', '😡', '👍', '🔥', '😍']
                .map((e) => GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        _reactToStory(e);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: myReaction == e
                              ? const Color(0xFFe5c687).withValues(alpha: 0.2)
                              : Colors.transparent,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: myReaction == e
                                ? const Color(0xFFe5c687)
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Text(e,
                            style: TextStyle(
                                fontSize: myReaction == e ? 32 : 28)),
                      ),
                    ))
                .toList(),
          ),
        ]),
      ),
    ).then((_) => _resume());
  }

  void _showComments(StoryModel liveStory) {
    _pause();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.of(context).surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _StoryCommentsSheet(
        story: liveStory,
        cubit: StoriesCubit.get(context),
        commentCtrl: _commentCtrl,
      ),
    ).then((_) {
      _commentCtrl.clear();
      _resume();
    });
  }

  void _shareStory() async {
    final story = widget.stories[_idx];
    final url = story.mediaUrl;
    if (url.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(AppStrings.of(context).storyLinkCopied),
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.black87,
    ));
  }

  Future<void> _sendReply(String text) async {
    if (text.trim().isEmpty) return;
    _replyCtrl.clear();
    try {
      final story = widget.stories[_idx];
      await ChatCubit.get(context).sendReply(
        receiverId: story.uid,
        text: text.trim(),
        replyToId: story.storyId,
        replyToSenderName: story.userName,
        replyToText: story.caption ?? '📷 Story',
        replyToMediaUrl: story.isVideo ? null : story.mediaUrl,
        replyToIsStory: true,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(AppStrings.of(context).replySent),
          backgroundColor: const Color(0xFF2e7d32),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (_) {}
    _resume();
  }

  Future<void> _deleteStory() async {
    final story = widget.stories[_idx];
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF21262d),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(AppStrings.of(context).deleteStoryTitle2, style: TextStyle(color: AppColors.of(context).text)),
        content: Text(AppStrings.of(context).deleteStoryBody,
            style: const TextStyle(color: Colors.grey)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(AppStrings.of(context).cancel, style: TextStyle(color: Colors.grey))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(AppStrings.of(context).deleteStory,
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await StoriesCubit.get(context).deleteStory(story.storyId);
    if (mounted) Navigator.pop(context);
  }

  void _showViewers(StoryModel story) {
    _pause();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.of(context).surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ViewersSheet(seenByUids: story.seenBy),
    ).whenComplete(_resume);
  }

  String _ago(String iso) {
    final dt = DateTime.tryParse(iso) ?? DateTime.now();
    final diff = DateTime.now().difference(dt);
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }
}
