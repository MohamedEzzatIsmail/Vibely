import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../share/style/app_colors.dart';
import '../../share/local/app_strings.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../models/story_model.dart';
import '../../models/user_model.dart';
import '../cubit/chat/chat_cubit.dart';
import 'stories_cubit.dart';

part 'story_viewer_actions.dart';
part 'story_bottom_bar.dart';
part 'story_sheets.dart';

class StoryViewer extends StatefulWidget {
  final List<StoryModel> stories;
  final String ownerUid;
  final VoidCallback? onFinished;
  const StoryViewer(
      {super.key,
      required this.stories,
      required this.ownerUid,
      this.onFinished});
  @override
  State<StoryViewer> createState() => _StoryViewerState();
}

class _StoryViewerState extends State<StoryViewer>
    with SingleTickerProviderStateMixin {
  int _idx = 0;
  bool _paused = false;
  bool _advancing = false;
  bool _mediaReady = false;
  bool _videoError = false;

  late AnimationController _progress;
  Player? _player;
  VideoController? _videoCtrl;
  final _replyCtrl = TextEditingController();
  final _commentCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _progress =
        AnimationController(vsync: this, duration: const Duration(seconds: 5));
    _progress.addStatusListener((s) {
      if (s == AnimationStatus.completed && !_paused) _next();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _initSlide(0);
    });
  }

  @override
  void dispose() {
    _progress.dispose();
    _player?.dispose();
    _replyCtrl.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    final cubit = StoriesCubit.get(context);
    final isOwner = cubit.isMyStory(widget.stories[_idx]);
    final myUid = cubit.currentUser?.uid ?? '';

    // ── Live stream for the current story doc (reactions + commentCount)
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('Stories')
          .doc(widget.stories[_idx].storyId)
          .snapshots(),
      builder: (context, snap) {
        // Use live data if available, fall back to snapshot
        StoryModel liveStory = widget.stories[_idx];
        if (snap.hasData && snap.data!.exists) {
          try {
            liveStory =
                StoryModel.fromJson(snap.data!.data() as Map<String, dynamic>);
          } catch (_) {}
        }

        final viewers = liveStory.seenBy.length;
        final allReactions = liveStory.reactions;
        final reactionEntries = allReactions.entries
            .where((e) => e.value.isNotEmpty)
            .toList()
          ..sort((a, b) => b.value.length.compareTo(a.value.length));
        final totalReactions =
            allReactions.values.fold(0, (s, l) => s + l.length);

        return Scaffold(
          resizeToAvoidBottomInset: true,
          backgroundColor: Colors.black,
          body: GestureDetector(
            onLongPressStart: (_) => _pause(),
            onLongPressEnd: (_) => _resume(),
            onTapUp: (d) {
              if (_replyCtrl.text.isNotEmpty) return;
              final w = MediaQuery.of(context).size.width;
              if (d.globalPosition.dx < w / 3) {
                _prev();
              } else if (d.globalPosition.dx > w * 2 / 3) {
                _next();
              }
            },
            child: Stack(fit: StackFit.expand, children: [

              // ── Media layer ───────────────────────────────────────────
              if (_videoCtrl != null && !_videoError)
                Video(
                  controller: _videoCtrl!,
                  controls: NoVideoControls,
                  fit: BoxFit.cover,
                )
              else if (_videoError)
                Container(
                  color: Colors.black,
                  child: Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.videocam_off_rounded,
                          color: AppColors.of(context).textHint, size: 48),
                      const SizedBox(height: 10),
                      Text(AppStrings.of(context).videoUnavailable,
                          style: TextStyle(color: AppColors.of(context).textSub, fontSize: 14)),
                    ]),
                  ),
                )
              else if (liveStory.isVideo)
              // Video is opening — show thumbnail immediately (no black screen)
                Stack(children: [
                  if ((liveStory.thumbnailUrl ?? '').isNotEmpty)
                    Positioned.fill(
                      child: CachedNetworkImage(
                        imageUrl: liveStory.thumbnailUrl!,
                        fit: BoxFit.cover,
                      ),
                    )
                  else
                    Container(color: Colors.black87),
                  const Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFFe5c687), strokeWidth: 2)),
                ])
              else
                CachedNetworkImage(
                  imageUrl: liveStory.mediaUrl,
                  fit: BoxFit.cover,
                  imageBuilder: (_, provider) {
                    WidgetsBinding.instance
                        .addPostFrameCallback((_) => _onImageLoaded());
                    return DecoratedBox(
                        decoration: BoxDecoration(
                            image: DecorationImage(
                                image: provider, fit: BoxFit.cover)));
                  },
                  placeholder: (_, _) => const Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFFe5c687), strokeWidth: 2)),
                  errorWidget: (_, _, ___) {
                    WidgetsBinding.instance
                        .addPostFrameCallback((_) => _onImageLoaded());
                    return const ColoredBox(color: Colors.black);
                  },
                ),

              // ── Vignette gradient ─────────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.6),
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.8),
                    ],
                    stops: const [0, 0.18, 0.6, 1],
                  ),
                ),
              ),

              // ── Progress bars ─────────────────────────────────────────
              Positioned(
                top: MediaQuery.of(context).padding.top + 6,
                left: 8,
                right: 8,
                child: Row(
                  children: List.generate(widget.stories.length, (i) {
                    return Expanded(
                      child: Container(
                        height: 2.5,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(2)),
                        child: i < _idx
                            ? Container(
                                decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(2)))
                            : i == _idx
                                ? AnimatedBuilder(
                                    animation: _progress,
                                    builder: (_, _) => FractionallySizedBox(
                                      alignment: Alignment.centerLeft,
                                      widthFactor: _progress.value,
                                      child: Container(
                                          decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(2))),
                                    ),
                                  )
                                : const SizedBox.shrink(),
                      ),
                    );
                  }),
                ),
              ),

              // ── Header ────────────────────────────────────────────────
              Positioned(
                top: MediaQuery.of(context).padding.top + 18,
                left: 12,
                right: 8,
                child: Row(children: [
                  CircleAvatar(
                    radius: 19,
                    backgroundImage: liveStory.userImage.isNotEmpty
                        ? NetworkImage(liveStory.userImage)
                        : null,
                    backgroundColor: const Color(0xFF21262d),
                    child: liveStory.userImage.isEmpty
                        ? Text(
                            liveStory.userName.isNotEmpty
                                ? liveStory.userName[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                                color: AppColors.of(context).text,
                                fontWeight: FontWeight.bold))
                        : null,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(liveStory.userName,
                            style: TextStyle(
                                color: AppColors.of(context).text,
                                fontWeight: FontWeight.bold,
                                fontSize: 13)),
                        Text(_ago(liveStory.dateTime),
                            style: const TextStyle(
                                color: Colors.white60, fontSize: 11)),
                      ],
                    ),
                  ),
                  if (_paused)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(6)),
                      child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.pause_rounded,
                                color: AppColors.of(context).textSub, size: 12),
                            const SizedBox(width: 3),
                            Text(AppStrings.of(context).holdLabel,
                                style: TextStyle(
                                    color: AppColors.of(context).textSub, fontSize: 10)),
                          ]),
                    ),
                  if (isOwner)
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert,
                          color: AppColors.of(context).text, size: 20),
                      color: const Color(0xFF21262d),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      onSelected: (v) {
                        if (v == 'delete') _deleteStory();
                        if (v == 'viewers') _showViewers(liveStory);
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(
                            value: 'viewers',
                            child: Row(children: [
                              const Icon(Icons.visibility_outlined,
                                  color: Colors.grey, size: 18),
                              const SizedBox(width: 10),
                              Text(
                                  '$viewers viewer${viewers == 1 ? '' : 's'}',
                                  style: TextStyle(
                                      color: AppColors.of(context).text, fontSize: 14)),
                            ])),
                        PopupMenuItem(
                            value: 'delete',
                            child: Row(children: [
                              const Icon(Icons.delete_outline_rounded,
                                  color: Colors.red, size: 18),
                              const SizedBox(width: 10),
                              Text(AppStrings.of(context).deleteStory,
                                  style: const TextStyle(
                                      color: Colors.red, fontSize: 14)),
                            ])),
                      ],
                    )
                  else
                    IconButton(
                      icon: Icon(Icons.close,
                          color: AppColors.of(context).text, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                ]),
              ),

              // ── Caption ───────────────────────────────────────────────
              if ((liveStory.caption ?? '').isNotEmpty)
                Positioned(
                  bottom: isOwner ? 72 : 160,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(12)),
                    child: Text(liveStory.caption!,
                        style: TextStyle(
                            color: AppColors.of(context).text, fontSize: 15, height: 1.4)),
                  ),
                ),

              // ── Facebook-style bottom bar (non-owner) ──────────────────
              if (!isOwner)
                Positioned(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                  left: 0,
                  right: 0,
                  child: _StoryBottomBar(
                    liveStory: liveStory,
                    myUid: myUid,
                    replyCtrl: _replyCtrl,
                    reactionEntries: reactionEntries,
                    totalReactions: totalReactions,
                    onPause: _pause,
                    onReact: () => _showReactionPicker(liveStory),
                    onComment: () => _showComments(liveStory),
                    onShare: _shareStory,
                    onSendReply: _sendReply,
                  ),
                ),

              // ── Owner bottom: viewers bar ──────────────────────────────
              if (isOwner)
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: GestureDetector(
                    onTap: () => _showViewers(liveStory),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white24)),
                      child: Row(children: [
                        Icon(Icons.visibility_outlined,
                            color: AppColors.of(context).textSub, size: 18),
                        const SizedBox(width: 8),
                        Text(
                            '$viewers viewer${viewers == 1 ? '' : 's'}',
                            style: TextStyle(
                                color: AppColors.of(context).textSub, fontSize: 13)),
                        const Spacer(),
                        Icon(Icons.keyboard_arrow_up_rounded,
                            color: AppColors.of(context).textSub, size: 18),
                      ]),
                    ),
                  ),
                ),
            ]),
          ),
        );
      },
    );
  }
}

