import 'package:cloud_firestore/cloud_firestore.dart';
import '../../share/style/app_colors.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../share/local/app_strings.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../models/post_model.dart';
import '../../share/network/notification_router.dart';
import '../cubit/post/post_cubit.dart';
import '../cubit/post/post_states.dart';
import '../feeds/share_post_sheet.dart';
import '../notifications/post_navigation_controller.dart';

part 'post_card_widgets.dart';
part 'post_media_widgets.dart';
part 'post_comments_widgets.dart';
part 'post_replies_widgets.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Reaction icon definitions — mirrors feeds_screen.dart exactly
// ─────────────────────────────────────────────────────────────────────────────
class _ReactionDef {
  final String   key;
  final String   label;
  final IconData icon;
  final Color    color;
  final Color    bgColor;
  const _ReactionDef(this.key, this.label, this.icon, this.color, this.bgColor);
}

const _reactions = [
  _ReactionDef('like',  'Like',    Icons.thumb_up_rounded,                  Color(0xFF4A90D9), Color(0xFFE8F4FD)),
  _ReactionDef('love',  'Love',    Icons.favorite_rounded,                   Color(0xFFE05C6C), Color(0xFFFFECEE)),
  _ReactionDef('haha',  'Haha',    Icons.sentiment_very_satisfied_rounded,   Color(0xFFFFB300), Color(0xFFFFF8E1)),
  _ReactionDef('wow',   'Wow',     Icons.auto_awesome_rounded,               Color(0xFFFF7043), Color(0xFFFBE9E7)),
  _ReactionDef('sad',   'Sad',     Icons.sentiment_dissatisfied_rounded,     Color(0xFF78909C), Color(0xFFECEFF1)),
  _ReactionDef('angry', 'Dislike', Icons.heart_broken_rounded,               Color(0xFFE53935), Color(0xFFFFEBEE)),
];

_ReactionDef? _reactionByKey(String? key) {
  if (key == null) return null;
  try { return _reactions.firstWhere((r) => r.key == key); } catch (_) { return null; }
}

class PostDetailsScreen extends StatefulWidget {
  final String postId;
  final PostNavigationTarget navigationTarget;

  const PostDetailsScreen({
    super.key,
    required this.postId,
    PostNavigationTarget? navigationTarget,
  }) : navigationTarget = navigationTarget ?? const PostNavigationTarget.none();

  @override
  State<PostDetailsScreen> createState() => _PostDetailsScreenState();
}

class _PostDetailsScreenState extends State<PostDetailsScreen> {
  PostModel? _post;

  // comment / reply state
  String? _expandedCommentId;
  String? _replyingToCommentId;
  String? _replyingToUserName;
  String? _replyingToReplyId;       // non-null = reply-on-reply
  String? _replyingToReplyOwnerId;

  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _commentKeys = {};
  final Map<String, GlobalKey> _replyKeys   = {};
  final TextEditingController _commentController = TextEditingController();
  final TextEditingController _replyController   = TextEditingController();
  final FocusNode _commentFocus = FocusNode();
  final FocusNode _replyFocus   = FocusNode();

  late final PostNavigationController _navController;

  @override
  void initState() {
    super.initState();
    _navController = PostNavigationController(
      scrollController: _scrollController,
      commentKeys: _commentKeys,
      replyKeys:   _replyKeys,
      target: widget.navigationTarget,
      onExpandComment: (id) => setState(() => _expandedCommentId = id),
    );
    _loadPost();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _commentController.dispose();
    _replyController.dispose();
    _commentFocus.dispose();
    _replyFocus.dispose();
    super.dispose();
  }

  Future<void> _loadPost() async {
    final doc = await FirebaseFirestore.instance
        .collection('Posts').doc(widget.postId).get();
    if (!doc.exists || !mounted) return;
    setState(() => _post = PostModel.fromJson(doc.data()!));
    WidgetsBinding.instance.addPostFrameCallback((_) => _navController.execute());
  }

  void _startReply(String commentId, String userName) {
    setState(() {
      _replyingToCommentId  = commentId;
      _replyingToUserName   = userName;
      _replyingToReplyId    = null;
      _replyingToReplyOwnerId = null;
      _expandedCommentId    = commentId;
    });
    Future.delayed(const Duration(milliseconds: 100), () => _replyFocus.requestFocus());
  }

  void _startReplyOnReply({
    required String commentId,
    required String replyId,
    required String userName,
    required String replyOwnerId,
  }) {
    setState(() {
      _replyingToCommentId    = commentId;
      _replyingToUserName     = userName;
      _replyingToReplyId      = replyId;
      _replyingToReplyOwnerId = replyOwnerId;
      _expandedCommentId      = commentId;
    });
    Future.delayed(const Duration(milliseconds: 100), () => _replyFocus.requestFocus());
  }

  void _cancelReply() {
    setState(() {
      _replyingToCommentId    = null;
      _replyingToUserName     = null;
      _replyingToReplyId      = null;
      _replyingToReplyOwnerId = null;
    });
    _replyController.clear();
  }

  void _submitComment(PostsCubit cubit) {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    cubit.addComment(postId: widget.postId, commentText: text);
    _commentController.clear();
    _commentFocus.unfocus();
  }

  void _submitReply(PostsCubit cubit) {
    final text = _replyController.text.trim();
    if (text.isEmpty || _replyingToCommentId == null) return;

    if (_replyingToReplyId != null) {
      // Reply on reply
      cubit.addReplyToReply(
        postId:           widget.postId,
        commentId:        _replyingToCommentId!,
        parentReplyId:    _replyingToReplyId!,
        text:             text,
        replyOwnerUserId: _replyingToReplyOwnerId ?? '',
      );
    } else {
      cubit.addReply(
        postId:    widget.postId,
        commentId: _replyingToCommentId!,
        text:      text,
      );
    }

    _replyController.clear();
    _replyFocus.unfocus();
    _cancelReply();
  }

  @override
  Widget build(BuildContext context) {
    if (_post == null) {
      return Scaffold(
        backgroundColor: AppColors.of(context).bg,
        body: Center(child: const CircularProgressIndicator(color: Color(0xFFe5c687))),
      );
    }

    return BlocBuilder<PostsCubit, PostsStates>(
      builder: (context, state) {
        final cubit = PostsCubit.get(context);
        final livePost = cubit.posts.firstWhere(
                (p) => p.postId == widget.postId, orElse: () => _post!);

        return Scaffold(
          backgroundColor: AppColors.of(context).bg,
          appBar: AppBar(
            backgroundColor: AppColors.of(context).bg,
            elevation: 0,
            title: Text(AppStrings.of(context).post,
                style: const TextStyle(
                    color: Color(0xFFe5c687),
                    fontWeight: FontWeight.bold,
                    fontSize: 18)),
            iconTheme: const IconThemeData(color: Color(0xFFe5c687)),
            centerTitle: true,
          ),
          body: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      // ── POST CARD ──────────────────────────────────────────
                      _PostCard(post: livePost, cubit: cubit),

                      // ── COMMENTS HEADER ───────────────────────────────────
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: Row(
                          children: [
                            const Icon(Icons.comment_rounded,
                                color: Color(0xFFe5c687), size: 18),
                            const SizedBox(width: 6),
                            StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('Posts').doc(widget.postId)
                                  .collection('comments').snapshots(),
                              builder: (_, snap) {
                                final n = snap.data?.docs.length ?? 0;
                                return Text(
                                  'Comments${n > 0 ? ' ($n)' : ''}',
                                  style: const TextStyle(
                                      color: Color(0xFFe5c687),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const Divider(color: Color(0xFF2e3540), height: 1),
                      const SizedBox(height: 4),

                      // ── COMMENTS ──────────────────────────────────────────
                      _CommentsSection(
                        postId:              widget.postId,
                        cubit:               cubit,
                        target:              widget.navigationTarget,
                        commentKeys:         _commentKeys,
                        replyKeys:           _replyKeys,
                        expandedCommentId:   _expandedCommentId,
                        replyingToCommentId: _replyingToCommentId,
                        replyingToReplyId:   _replyingToReplyId,
                        replyController:     _replyController,
                        replyFocus:          _replyFocus,
                        replyingToUserName:  _replyingToUserName,
                        onToggleComment: (id) => setState(() {
                          _expandedCommentId =
                          _expandedCommentId == id ? null : id;
                        }),
                        onReply:        _startReply,
                        onReplyToReply: _startReplyOnReply,
                        onSubmitReply:  () => _submitReply(cubit),
                        onCancelReply:  _cancelReply,
                      ),

                      const SizedBox(height: 90),
                    ],
                  ),
                ),
              ),

              // ── COMMENT INPUT BAR ──────────────────────────────────────────
              _CommentInputBar(
                controller:    _commentController,
                focusNode:     _commentFocus,
                onSubmit:      () => _submitComment(cubit),
                replyingTo:    _replyingToCommentId != null ? _replyingToUserName : null,
                onCancelReply: _cancelReply,
              ),
            ],
          ),
        );
      },
    );
  }
}
