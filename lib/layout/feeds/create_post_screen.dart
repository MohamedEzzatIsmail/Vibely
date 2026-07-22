// lib/layout/feeds/create_post_screen.dart
//
// Full create-post screen with privacy selector and media picking.

import 'dart:io';
import '../../share/local/constants.dart';
import '../../share/style/app_colors.dart';
import 'package:flutter/material.dart';
import '../../share/local/app_strings.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubit/post/post_cubit.dart';
import '../cubit/post/post_states.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _textCtrl = TextEditingController();
  String _privacy = 'public';
  bool _isPosting = false;

  static const _privacyOptions = [
    _PrivacyOption(
      value: 'public',
      label: 'Public',
      icon: Icons.public_rounded,
      description: 'Anyone on Vibely can see this post',
    ),
    _PrivacyOption(
      value: 'followers',
      label: 'Followers',
      icon: Icons.people_alt_rounded,
      description: 'Only people who follow you can see this',
    ),
    _PrivacyOption(
      value: 'close_circle',
      label: 'Close Circle',
      icon: Icons.favorite_rounded,
      description: 'Only mutual follows — people you follow back',
    ),
  ];

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _textCtrl.text.trim();
    final cubit = PostsCubit.get(context);

    if (text.isEmpty && cubit.postImages.isEmpty && cubit.postVideo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.of(context).writeSomethingFirst)),
      );
      return;
    }

    setState(() => _isPosting = true);
    HapticFeedback.lightImpact();

    // Navigation is handled exclusively by BlocListener (PostCreatedState /
    // PostErrorState / PostRateLimitedState). Do NOT await + pop here —
    // that caused a double-pop which dismissed the screen below this one,
    // leaving a black screen.
    cubit.createPostWithMedia(
      text: text,
      images: List.from(cubit.postImages),
      video: cubit.postVideo,
      privacy: _privacy,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<PostsCubit, PostsStates>(
      listener: (context, state) {
        if (state is PostCreatedState) {
          setState(() => _isPosting = false);
          // Clear cubit media now that the post succeeded
          PostsCubit.get(context).postImages.clear();
          PostsCubit.get(context).postVideo = null;
          Navigator.pop(context);
        } else if (state is PostErrorState) {
          setState(() => _isPosting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.error),
              backgroundColor: Colors.redAccent,
            ),
          );
        } else if (state is PostRateLimitedState) {
          setState(() => _isPosting = false);
          final secs = state.remaining.inSeconds;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${AppStrings.of(context).waitSeconds} (${secs}s)'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.of(context).bg,
        appBar: AppBar(
          backgroundColor: AppColors.of(context).bg,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.close_rounded, color: AppColors.of(context).textSub),
            onPressed: () {
              PostsCubit.get(context).postImages.clear();
              PostsCubit.get(context).postVideo = null;
              Navigator.pop(context);
            },
          ),
          title: Text(
            AppStrings.of(context).createPostTitle,
            style: TextStyle(
              color: AppColors.of(context).text,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          centerTitle: true,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: _isPosting
                  ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: kGold,
                  strokeWidth: 2.5,
                ),
              )
                  : FilledButton(
                onPressed: _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: kGold,
                  foregroundColor: Colors.black,
                  minimumSize: const Size(72, 36),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                ),
                child: Text(
                  AppStrings.of(context).postButton,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
        body: BlocBuilder<PostsCubit, PostsStates>(
          builder: (context, state) {
            final cubit = PostsCubit.get(context);
            return SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 8,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── User row ─────────────────────────────────────────────
                  _UserRow(user: cubit.currentUser),
                  const SizedBox(height: 14),

                  // ── Privacy selector ─────────────────────────────────────
                  _PrivacySelector(
                    selected: _privacy,
                    options: _privacyOptions,
                    onChanged: (v) => setState(() => _privacy = v),
                  ),
                  const SizedBox(height: 16),

                  // ── Text field ───────────────────────────────────────────
                  TextField(
                    controller: _textCtrl,
                    autofocus: true,
                    maxLines: null,
                    minLines: 4,
                    maxLength: 2000,
                    style: TextStyle(
                      color: AppColors.of(context).text,
                      fontSize: 16,
                      height: 1.5,
                    ),
                    decoration: InputDecoration(
                      hintText: AppStrings.of(context).whatsOnYourMind,
                      hintStyle: TextStyle(
                        color: AppColors.of(context).text.withValues(alpha: 0.3),
                        fontSize: 16,
                      ),
                      border: InputBorder.none,
                      counterStyle: TextStyle(
                        color: AppColors.of(context).textHint,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // ── Picked media preview ─────────────────────────────────
                  if (cubit.postImages.isNotEmpty || cubit.postVideo != null)
                    _MediaPreview(
                      images: cubit.postImages,
                      video: cubit.postVideo,
                      onRemoveImage: (i) {
                        cubit.postImages.removeAt(i);
                        cubit.emit(PostImagesPickedState());
                      },
                      onRemoveVideo: () {
                        cubit.postVideo = null;
                        cubit.emit(PostImagesPickedState());
                      },
                    ),

                  const SizedBox(height: 16),

                  // ── Media actions ─────────────────────────────────────────
                  _MediaActions(cubit: cubit),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ── Privacy option data class ─────────────────────────────────────────────────
class _PrivacyOption {
  final String value;
  final String label;
  final IconData icon;
  final String description;
  const _PrivacyOption({
    required this.value,
    required this.label,
    required this.icon,
    required this.description,
  });
}

// ── Privacy dropdown selector ─────────────────────────────────────────────────
class _PrivacySelector extends StatelessWidget {
  final String selected;
  final List<_PrivacyOption> options;
  final ValueChanged<String> onChanged;

  const _PrivacySelector({
    required this.selected,
    required this.options,
    required this.onChanged,
  });

  _PrivacyOption get _current =>
      options.firstWhere((o) => o.value == selected, orElse: () => options.first);

  @override
  Widget build(BuildContext context) {
    final cur = _current;
    return PopupMenuButton<String>(
      onSelected: onChanged,
      color: const Color(0xFF1A2030),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      itemBuilder: (_) => options
          .map(
            (o) => PopupMenuItem<String>(
          value: o.value,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(o.icon, color: kGold, size: 18),
                  const SizedBox(width: 10),
                  Text(
                    o.label,
                    style: TextStyle(
                      color: AppColors.of(context).text,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  if (o.value == selected) ...[
                    const Spacer(),
                    const Icon(Icons.check_rounded, color: kGold, size: 16),
                  ],
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(left: 28, top: 3),
                child: Text(
                  o.description,
                  style: TextStyle(
                    color: AppColors.of(context).textHint,
                    fontSize: 11.5,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      )
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: kGold.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: kGold.withValues(alpha: 0.30)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(cur.icon, color: kGold, size: 15),
            const SizedBox(width: 6),
            Text(
              cur.label,
              style: const TextStyle(
                color: kGold,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down_rounded, color: kGold, size: 16),
          ],
        ),
      ),
    );
  }
}

// ── User avatar + name row ────────────────────────────────────────────────────
class _UserRow extends StatelessWidget {
  final dynamic user;
  const _UserRow({required this.user});

  @override
  Widget build(BuildContext context) {
    final image = user?.image as String?;
    final name = user?.name as String? ?? '';
    return Row(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: Colors.white12,
          backgroundImage:
          image != null && image.isNotEmpty ? NetworkImage(image) : null,
          child: image == null || image.isEmpty
              ? Icon(Icons.person_rounded, color: AppColors.of(context).textHint, size: 22)
              : null,
        ),
        const SizedBox(width: 10),
        Text(
          name,
          style: TextStyle(
            color: AppColors.of(context).text,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

// ── Media preview grid ────────────────────────────────────────────────────────
class _MediaPreview extends StatelessWidget {
  final List<File> images;
  final File? video;
  final ValueChanged<int> onRemoveImage;
  final VoidCallback onRemoveVideo;

  const _MediaPreview({
    required this.images,
    required this.video,
    required this.onRemoveImage,
    required this.onRemoveVideo,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (video != null)
          Stack(
            children: [
              Container(
                height: 180,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Icon(Icons.videocam_rounded,
                      color: AppColors.of(context).textHint, size: 48),
                ),
              ),
              Positioned(
                top: 8, right: 8,
                child: _RemoveBtn(onTap: onRemoveVideo),
              ),
            ],
          ),
        if (images.isNotEmpty) ...[
          if (video != null) const SizedBox(height: 8),
          SizedBox(
            height: 100,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: images.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) => Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      images[i],
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 4, right: 4,
                    child: _RemoveBtn(onTap: () => onRemoveImage(i)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _RemoveBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _RemoveBtn({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 24,
        height: 24,
        decoration: const BoxDecoration(
          color: Colors.black87,
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.close_rounded, color: AppColors.of(context).text, size: 14),
      ),
    );
  }
}

// ── Media pick actions ────────────────────────────────────────────────────────
class _MediaActions extends StatelessWidget {
  final PostsCubit cubit;
  const _MediaActions({required this.cubit});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Row(
        children: [
          Text(
            'Add to post',
            style: TextStyle(
              color: AppColors.of(context).textSub,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          _ToolBtn(
            icon: Icons.image_rounded,
            color: const Color(0xFF63D5E6),
            tooltip: 'Photos',
            onTap: () => cubit.pickPostImages(ctx: context),
          ),
          const SizedBox(width: 10),
          _ToolBtn(
            icon: Icons.videocam_rounded,
            color: const Color(0xFFFF7A66),
            tooltip: 'Video',
            onTap: cubit.postImages.isEmpty
                ? () => cubit.pickPostVideo(ctx: context)
                : null,
          ),
        ],
      ),
    );
  }
}

class _ToolBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback? onTap;

  const _ToolBtn({
    required this.icon,
    required this.color,
    required this.tooltip,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: enabled
                ? color.withValues(alpha: 0.12)
                : Colors.white.withValues(alpha: 0.04),
            border: Border.all(
              color: enabled ? color.withValues(alpha: 0.28) : Colors.white12,
            ),
          ),
          child: Icon(
            icon,
            color: enabled ? color : Colors.white24,
            size: 20,
          ),
        ),
      ),
    );
  }
}