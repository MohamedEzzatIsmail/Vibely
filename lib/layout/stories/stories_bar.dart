import 'package:cached_network_image/cached_network_image.dart';
import '../../share/style/app_colors.dart';
import 'package:flutter/material.dart';
import '../../share/local/app_strings.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'stories_cubit.dart';
import 'story_viewer.dart';

class StoriesBar extends StatelessWidget {
  const StoriesBar({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<StoriesCubit, StoriesState>(
      builder: (ctx, state) {
        final cubit = StoriesCubit.get(ctx);
        final myUid = cubit.currentUser?.uid;

        // Show uploading indicator
        if (state is StoryUploading) {
          return SizedBox(height: 90,
            child: Center(child: Builder(builder: (context) => Column(mainAxisSize: MainAxisSize.min, children: [
              const CircularProgressIndicator(color: Color(0xFFe5c687), strokeWidth: 2),
              const SizedBox(height: 4),
              Text(AppStrings.of(context).uploadingStoryBar, style: const TextStyle(color: Colors.grey, fontSize: 11)),
            ]))));
        }
        if (state is StoriesError) {
          return SizedBox(height: 90,
            child: Center(child: Text(
              '⚠ Story failed: ${state.msg}',
              style: const TextStyle(color: Colors.redAccent, fontSize: 11),
              textAlign: TextAlign.center)));
        }

        final uids = cubit.orderedUids;

        return SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            // Always at least 1 (the "Add Story" slot) so bar never collapses
            itemCount: uids.length + 1,
            itemBuilder: (_, i) {
              // ── "Add Story" / "Your Story" slot ─────────────────────────
              if (i == 0) {
                final hasMyStory = cubit.hasMyStory();
                final myStories  = myUid != null
                    ? (cubit.storiesByUser[myUid] ?? [])
                    : <dynamic>[];
                // Thumbnail = first story's mediaUrl if it's an image, else null
                // Use thumbnailUrl (set for image stories) for IG-style ring fill
                final myThumb = (hasMyStory && myStories.isNotEmpty)
                    ? (myStories.first.thumbnailUrl ?? (myStories.first.isVideo ? null : myStories.first.mediaUrl))
                    : null;
                return _StoryAvatar(
                  image:       cubit.currentUser?.image,
                  storyThumb:  myThumb,
                  name:        cubit.currentUser?.name ?? 'You',
                  label:       hasMyStory ? 'Your Story' : 'Add Story',
                  seen:        false,
                  isAddBtn:    !hasMyStory,
                  hasStory:    hasMyStory,
                  isVideo:     hasMyStory && myStories.isNotEmpty && myStories.first.isVideo,
                  onTap: () {
                    if (hasMyStory && myUid != null) {
                      _openViewer(ctx, cubit, myUid);
                    } else {
                      _showAddStorySheet(ctx, cubit);
                    }
                  },
                  onAddTap: () => _showAddStorySheet(ctx, cubit),
                );
              }

              // ── Other users' stories ──────────────────────────────
              final uid     = uids[i - 1];
              if (uid == myUid) return const SizedBox.shrink();
              final stories = cubit.storiesByUser[uid] ?? [];
              if (stories.isEmpty) return const SizedBox.shrink();
              final first   = stories.first;
              final allSeen = stories.every(cubit.hasSeen);
              final thumb   = first.thumbnailUrl ?? (first.isVideo ? null : first.mediaUrl);

              return _StoryAvatar(
                image:      first.userImage.isNotEmpty ? first.userImage : null,
                storyThumb: thumb,
                name:       first.userName,
                label:      first.userName,
                seen:       allSeen,
                isAddBtn:   false,
                isVideo:    first.isVideo,
                onTap:      () => _openViewer(ctx, cubit, uid),
              );
            },
          ),
        );
      },
    );
  }

  void _openViewer(BuildContext ctx, StoriesCubit cubit, String uid) {
    final allUids  = cubit.orderedUids;
    final startIdx = allUids.indexOf(uid);
    _openViewerAtIndex(ctx, cubit, startIdx < 0 ? 0 : startIdx);
  }

  void _openViewerAtIndex(BuildContext ctx, StoriesCubit cubit, int uidIdx) {
    final allUids = cubit.orderedUids;
    if (uidIdx >= allUids.length) return; // all done → just close

    final uid     = allUids[uidIdx];
    final stories = cubit.storiesByUser[uid];
    if (stories == null || stories.isEmpty) {
      // Skip empty slot, advance to next user
      _openViewerAtIndex(ctx, cubit, uidIdx + 1);
      return;
    }

    Navigator.push(ctx, PageRouteBuilder(
      pageBuilder: (_, _, ___) => BlocProvider.value(
        value: cubit,
        child: StoryViewer(
          stories:    stories,
          ownerUid:   uid,
          onFinished: () {
            // Pop current viewer, then open next user's stories
            Navigator.pop(ctx);
            _openViewerAtIndex(ctx, cubit, uidIdx + 1);
          },
        ),
      ),
      transitionDuration: const Duration(milliseconds: 250),
      transitionsBuilder: (_, anim, _, child) =>
          FadeTransition(opacity: anim, child: child),
    ));
  }

  void _showAddStorySheet(BuildContext ctx, StoriesCubit cubit) {
    final captionCtrl = TextEditingController();
    showModalBottomSheet(
      context: ctx,
      backgroundColor: AppColors.of(ctx).surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      isScrollControlled: true,
      builder: (bCtx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(bCtx).viewInsets.bottom + 20,
          left: 20, right: 20, top: 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          Text(AppStrings.of(ctx).addToStoryBar, style: TextStyle(
            color: AppColors.of(ctx).text, fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(
            controller: captionCtrl,
            style: TextStyle(color: AppColors.of(ctx).text),
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'Add a caption (optional)…',
              hintStyle: const TextStyle(color: Colors.grey),
              filled: true, fillColor: const Color(0xFF21262d),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFe5c687), width: 1.5)),
            ),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _MediaBtn(
              icon: Icons.image_rounded,
              label: 'Photo',
              color: const Color(0xFF4A90D9),
              onTap: () async {
                final caption = captionCtrl.text.trim().isEmpty ? null : captionCtrl.text.trim();
                final outerCtx = ctx;
                Navigator.pop(bCtx);
                await cubit.pickAndAddPhotoStory(caption: caption, context: outerCtx);
              },
            )),
            const SizedBox(width: 12),
            Expanded(child: _MediaBtn(
              icon: Icons.videocam_rounded,
              label: 'Video (30s)',
              color: const Color(0xFFE05C6C),
              onTap: () async {
                final caption = captionCtrl.text.trim().isEmpty ? null : captionCtrl.text.trim();
                // Capture the outer context before popping the bottom sheet
                final outerCtx = ctx;
                Navigator.pop(bCtx);
                await cubit.pickAndAddVideoStory(caption: caption, context: outerCtx);
              },
            )),
          ]),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}

class _MediaBtn extends StatelessWidget {
  final IconData icon; final String label; final Color color; final VoidCallback onTap;
  const _MediaBtn({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 6),
        Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600)),
      ]),
    ),
  );
}

class _StoryAvatar extends StatelessWidget {
  final String? image;        // user profile photo
  final String? storyThumb;   // first story image URL (IG-style ring fill)
  final String  name;
  final String  label;
  final bool    seen;
  final bool    isAddBtn;
  final bool    hasStory;
  final bool    isVideo;      // show play icon overlay on story thumb
  final VoidCallback  onTap;
  final VoidCallback? onAddTap;

  const _StoryAvatar({
    required this.image,
    required this.name,
    required this.label,
    required this.seen,
    required this.isAddBtn,
    required this.onTap,
    this.storyThumb,
    this.hasStory  = false,
    this.isVideo   = false,
    this.onAddTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 68,
      margin: const EdgeInsets.only(right: 10),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        GestureDetector(
          onTap: onTap,
          child: Stack(alignment: Alignment.center, children: [
            // ── Outer gradient ring (64px) ─────────────────────────
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: (!seen && !isAddBtn && hasStory)
                    ? const LinearGradient(
                        colors: [Color(0xFFe5c687), Color(0xFFb8934e)],
                        begin: Alignment.topLeft, end: Alignment.bottomRight)
                    : null,
                color: (!hasStory || isAddBtn)
                    ? const Color(0xFF30363d)
                    : (seen ? const Color(0xFF444444) : null),
              ),
            ),
            // ── Inner dark border gap (58px) ───────────────────────
            Container(
              width: 58, height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.of(context).bg,
              ),
            ),
            // ── IG-style: show story thumbnail or profile photo ────
            ClipOval(
              child: SizedBox(
                width: 54, height: 54,
                child: (storyThumb != null && storyThumb!.isNotEmpty)
                    // Story image fills the circle (IG style)
                    ? CachedNetworkImage(
                        imageUrl: storyThumb!,
                        fit: BoxFit.cover,
                        placeholder: (_, _) =>
                            Container(color: const Color(0xFF21262d)),
                        errorWidget: (_, _, ___) =>
                            Container(color: const Color(0xFF21262d)),
                      )
                    // No thumbnail: show profile photo
                    : (image != null
                        ? CachedNetworkImage(
                            imageUrl: image!,
                            fit: BoxFit.cover,
                            placeholder: (_, _) =>
                                Container(color: const Color(0xFF21262d)),
                            errorWidget: (_, _, ___) =>
                                Container(color: const Color(0xFF21262d)),
                          )
                        : Container(
                            color: const Color(0xFF21262d),
                            child: Center(
                              child: Text(
                                name.isNotEmpty ? name[0].toUpperCase() : '?',
                                style: TextStyle(
                                    color: AppColors.of(context).text,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20),
                              ),
                            ),
                          )),
              ),
            ),
            // ── Video play overlay (for video stories with no thumb) ─
            if (isVideo && hasStory && (storyThumb == null || storyThumb!.isEmpty))
              Icon(Icons.play_circle_fill_rounded,
                  color: AppColors.of(context).textSub, size: 26),
            // ── "+" badge ─────────────────────────────────────────
            if (isAddBtn || (hasStory && onAddTap != null))
              Positioned(
                bottom: 0, right: 0,
                child: GestureDetector(
                  onTap: (hasStory && onAddTap != null) ? onAddTap : onTap,
                  child: Container(
                    width: 20, height: 20,
                    decoration: const BoxDecoration(
                      color: Color(0xFFe5c687), shape: BoxShape.circle),
                    child: const Icon(Icons.add, color: Colors.black, size: 14)),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 5),
        GestureDetector(
          onTap: onTap,
          child: Text(label,
            style: TextStyle(color: AppColors.of(context).textSub, fontSize: 10),
            maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
        ),
      ]),
    );
  }
}
