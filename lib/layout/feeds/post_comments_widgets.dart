part of 'post_details_screen.dart';

class _CommentsSection extends StatelessWidget {
  final String postId;
  final PostsCubit cubit;
  final PostNavigationTarget target;
  final Map<String, GlobalKey> commentKeys, replyKeys;
  final String? expandedCommentId, replyingToCommentId, replyingToReplyId;
  final void Function(String) onToggleComment;
  final void Function(String commentId, String userName) onReply;
  final void Function({
  required String commentId, required String replyId,
  required String userName, required String replyOwnerId,
  }) onReplyToReply;
  final VoidCallback onSubmitReply, onCancelReply;
  final TextEditingController replyController;
  final FocusNode replyFocus;
  final String? replyingToUserName;

  const _CommentsSection({
    required this.postId, required this.cubit, required this.target,
    required this.commentKeys, required this.replyKeys,
    required this.expandedCommentId, required this.replyingToCommentId,
    required this.replyingToReplyId, required this.onToggleComment,
    required this.onReply, required this.onReplyToReply,
    required this.onSubmitReply, required this.onCancelReply,
    required this.replyController, required this.replyFocus,
    required this.replyingToUserName,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('Posts').doc(postId).collection('comments')
          .orderBy('dateTime', descending: true).snapshots(),
      builder: (_, snap) {
        if (!snap.hasData) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator(
                color: Color(0xFFe5c687))),
          );
        }
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Column(children: [
                Icon(Icons.chat_bubble_outline,
                    color: Colors.grey.withValues(alpha: 0.4), size: 48),
                const SizedBox(height: 10),
                Text(AppStrings.of(context).noCommentsYet,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey)),
              ]),
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            final cid  = data['commentId'] as String? ?? '';
            commentKeys.putIfAbsent(cid, () => GlobalKey());

            return _CommentTile(
              key:                  commentKeys[cid],
              data:                 data,
              postId:               postId,
              cubit:                cubit,
              isHighlighted:        (target.isComment || target.isReply) &&
                  target.commentId == cid,
              isExpanded:           expandedCommentId == cid,
              isReplyingToThis:     replyingToCommentId == cid &&
                  replyingToReplyId == null,
              replyController:      replyController,
              replyFocus:           replyFocus,
              replyingToUserName:   replyingToUserName,
              replyKeys:            replyKeys,
              highlightReplyId:     target.isReply ? target.replyId : null,
              replyingToReplyId:    replyingToReplyId,
              onToggle:             () => onToggleComment(cid),
              onReply:              () => onReply(cid, data['userName'] ?? ''),
              onReplyToReply:       onReplyToReply,
              onSubmitReply:        onSubmitReply,
              onCancelReply:        onCancelReply,
            );
          },
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  COMMENT TILE
// ══════════════════════════════════════════════════════════════════════════════
class _CommentTile extends StatefulWidget {
  final Map<String, dynamic> data;
  final String postId;
  final PostsCubit cubit;
  final bool isHighlighted, isExpanded, isReplyingToThis;
  final String? highlightReplyId, replyingToReplyId, replyingToUserName;
  final Map<String, GlobalKey> replyKeys;
  final VoidCallback onToggle, onReply, onSubmitReply, onCancelReply;
  final void Function({
  required String commentId, required String replyId,
  required String userName, required String replyOwnerId,
  }) onReplyToReply;
  final TextEditingController replyController;
  final FocusNode replyFocus;

  const _CommentTile({
    super.key,
    required this.data, required this.postId, required this.cubit,
    required this.isHighlighted, required this.isExpanded,
    required this.isReplyingToThis, required this.replyController,
    required this.replyFocus, required this.replyingToUserName,
    required this.replyKeys, required this.onToggle, required this.onReply,
    required this.onReplyToReply, required this.onSubmitReply,
    required this.onCancelReply,
    this.highlightReplyId, this.replyingToReplyId,
  });

  @override
  State<_CommentTile> createState() => _CommentTileState();
}

class _CommentTileState extends State<_CommentTile> {
  static const _def  = Color(0xFF262c34);
  static const _high = Color(0x40e5c687);
  late Color _bg;
  bool _fired = false;

  @override
  void initState() {
    super.initState();
    _bg = widget.isHighlighted ? _high : _def;
    if (widget.isHighlighted) _flash();
  }

  @override
  void didUpdateWidget(covariant _CommentTile old) {
    super.didUpdateWidget(old);
    if (widget.isHighlighted && !_fired) _flash();
  }

  void _flash() {
    _fired = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _bg = _high);
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) setState(() => _bg = _def);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final cid        = widget.data['commentId'] as String? ?? '';
    final userId     = widget.cubit.currentUser?.uid;
    final reactions  = Map<String, dynamic>.from(widget.data['reactions'] ?? {});
    final isLiked    = reactions[userId] == true;
    final isDisliked = reactions[userId] == false;
    final likes      = widget.data['likes']    ?? 0;
    final dislikes   = widget.data['dislikes'] ?? 0;
    final replies    = widget.data['repliesCount'] ?? 0;
    final isCommentOwner = userId == widget.data['userId'];
    final isPostOwner    = widget.cubit.posts
        .any((p) => p.postId == widget.postId && p.uid == userId);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
          color: _bg, borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                    radius: 18,
                    backgroundImage: NetworkImage(widget.data['userImage'] ?? '')),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.data['userName'] ?? '',
                          style: TextStyle(
                              color: AppColors.of(context).text, fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 3),
                      Text(widget.data['text'] ?? '',
                          style: TextStyle(color: AppColors.of(context).textSub, fontSize: 14, height: 1.4)),
                    ],
                  ),
                ),
                if (isCommentOwner || isPostOwner)
                  GestureDetector(
                    onTap: () => widget.cubit.deleteComment(
                        postId: widget.postId, comment: widget.data),
                    child: const Padding(
                      padding: EdgeInsets.only(left: 8, top: 2),
                      child: Icon(Icons.delete_outline, color: Colors.red, size: 18),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 8),

            // Reactions row
            Row(children: [
              _ReactionBtn(
                icon:    isLiked ? Icons.favorite : Icons.favorite_border,
                color:   isLiked ? Colors.red : Colors.grey,
                count:   likes,
                onTap: () => widget.cubit.reactToComment(
                    postId: widget.postId, commentId: cid, isLike: true),
              ),
              const SizedBox(width: 12),
              _ReactionBtn(
                icon:  isDisliked ? Icons.heart_broken : Icons.heart_broken_outlined,
                color: isDisliked ? Colors.white : Colors.grey,
                count: dislikes,
                onTap: () => widget.cubit.reactToComment(
                    postId: widget.postId, commentId: cid, isLike: false),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: widget.onReply,
                child: Row(children: [
                  Icon(Icons.reply_rounded,
                      color: widget.isReplyingToThis
                          ? const Color(0xFFe5c687) : Colors.grey,
                      size: 18),
                  const SizedBox(width: 3),
                  Text(AppStrings.of(context).replyLabel2,
                      style: TextStyle(
                          color: widget.isReplyingToThis
                              ? const Color(0xFFe5c687) : Colors.grey,
                          fontSize: 12)),
                ]),
              ),
              const Spacer(),
              if (replies > 0)
                GestureDetector(
                  onTap: widget.onToggle,
                  child: Row(children: [
                    Icon(
                        widget.isExpanded
                            ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                        color: const Color(0xFFe5c687), size: 18),
                    const SizedBox(width: 3),
                    Text(
                        widget.isExpanded ? 'Hide' : '$replies ${replies == 1 ? 'reply' : 'replies'}',
                        style: const TextStyle(color: Color(0xFFe5c687), fontSize: 12)),
                  ]),
                ),
            ]),

            // Inline reply input (comment-level)
            if (widget.isReplyingToThis)
              _InlineReplyInput(
                controller:    widget.replyController,
                focusNode:     widget.replyFocus,
                replyingTo:    widget.replyingToUserName,
                onSubmit:      widget.onSubmitReply,
                onCancel:      widget.onCancelReply,
              ),

            // Replies list
            if (widget.isExpanded)
              _RepliesList(
                postId:          widget.postId,
                commentId:       cid,
                cubit:           widget.cubit,
                highlightReplyId: widget.highlightReplyId,
                replyKeys:       widget.replyKeys,
                replyingToReplyId: widget.replyingToReplyId,
                replyController:  widget.replyController,
                replyFocus:       widget.replyFocus,
                replyingToUserName: widget.replyingToUserName,
                onReplyToReply:   widget.onReplyToReply,
                onSubmitReply:    widget.onSubmitReply,
                onCancelReply:    widget.onCancelReply,
              ),
          ],
        ),
      ),
    );
  }
}

