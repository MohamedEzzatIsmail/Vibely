part of 'post_details_screen.dart';

class _RepliesList extends StatelessWidget {
  final String postId, commentId;
  final PostsCubit cubit;
  final String? highlightReplyId, replyingToReplyId, replyingToUserName;
  final Map<String, GlobalKey> replyKeys;
  final void Function({
  required String commentId, required String replyId,
  required String userName, required String replyOwnerId,
  }) onReplyToReply;
  final VoidCallback onSubmitReply, onCancelReply;
  final TextEditingController replyController;
  final FocusNode replyFocus;

  const _RepliesList({
    required this.postId, required this.commentId, required this.cubit,
    required this.replyKeys, required this.onReplyToReply,
    required this.onSubmitReply, required this.onCancelReply,
    required this.replyController, required this.replyFocus,
    this.highlightReplyId, this.replyingToReplyId, this.replyingToUserName,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('Posts').doc(postId)
          .collection('comments').doc(commentId)
          .collection('replies').orderBy('dateTime').snapshots(),
      builder: (_, snap) {
        if (!snap.hasData) {
          return const Padding(
            padding: EdgeInsets.all(8),
            child: SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Color(0xFFe5c687))),
          );
        }
        return Column(
          children: snap.data!.docs.map((doc) {
            final data    = doc.data() as Map<String, dynamic>;
            final replyId = data['replyId'] as String? ?? doc.id;
            replyKeys.putIfAbsent(replyId, () => GlobalKey());

            return _ReplyTile(
              key:        replyKeys[replyId],
              data:       data,
              postId:     postId,
              commentId:  commentId,
              cubit:      cubit,
              isHighlighted:     replyId == highlightReplyId,
              isReplyingToThis:  replyingToReplyId == replyId,
              replyController:   replyController,
              replyFocus:        replyFocus,
              replyingToUserName: replyingToUserName,
              onReplyToReply: () => onReplyToReply(
                commentId:    commentId,
                replyId:      replyId,
                userName:     data['userName'] ?? '',
                replyOwnerId: data['userId']   ?? '',
              ),
              onSubmitReply: onSubmitReply,
              onCancelReply: onCancelReply,
            );
          }).toList(),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  REPLY TILE
// ══════════════════════════════════════════════════════════════════════════════
class _ReplyTile extends StatefulWidget {
  final Map<String, dynamic> data;
  final String postId, commentId;
  final PostsCubit cubit;
  final bool isHighlighted, isReplyingToThis;
  final String? replyingToUserName;
  final VoidCallback onReplyToReply, onSubmitReply, onCancelReply;
  final TextEditingController replyController;
  final FocusNode replyFocus;

  const _ReplyTile({
    super.key,
    required this.data, required this.postId, required this.commentId,
    required this.cubit, required this.isHighlighted,
    required this.isReplyingToThis, required this.onReplyToReply,
    required this.onSubmitReply, required this.onCancelReply,
    required this.replyController, required this.replyFocus,
    this.replyingToUserName,
  });

  @override
  State<_ReplyTile> createState() => _ReplyTileState();
}

class _ReplyTileState extends State<_ReplyTile> {
  static const _def = Color(0x20FFFFFF);
  late Color _bg;
  bool _fired = false;

  @override
  void initState() {
    super.initState();
    _bg = widget.isHighlighted ? Colors.blue.withValues(alpha: 0.3) : _def;
    if (widget.isHighlighted) _flash();
  }

  void _flash() {
    _fired = true;
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _bg = _def);
    });
  }

  @override
  Widget build(BuildContext context) {
    final replyId    = widget.data['replyId'] as String? ?? '';
    final userId     = widget.cubit.currentUser?.uid;
    final reactions  = Map<String, dynamic>.from(widget.data['reactions'] ?? {});
    final isLiked    = reactions[userId] == true;
    final isDisliked = reactions[userId] == false;
    final likes      = widget.data['likes']    ?? 0;
    final dislikes   = widget.data['dislikes'] ?? 0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      margin: const EdgeInsets.only(left: 28, top: 6, bottom: 2),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 2, height: 16,
                margin: const EdgeInsets.only(right: 8),
                color: const Color(0xFFe5c687).withValues(alpha: 0.3),
              ),
              CircleAvatar(
                  radius: 13,
                  backgroundImage: NetworkImage(widget.data['userImage'] ?? '')),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.data['userName'] ?? '',
                        style: TextStyle(
                            color: AppColors.of(context).text, fontSize: 12,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(widget.data['text'] ?? '',
                        style: TextStyle(
                            color: AppColors.of(context).textSub, fontSize: 13, height: 1.4)),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          // Reaction row for reply
          Row(children: [
            const SizedBox(width: 28),
            _ReactionBtn(
              icon:  isLiked ? Icons.favorite : Icons.favorite_border,
              color: isLiked ? Colors.red : Colors.grey, count: likes,
              onTap: () => widget.cubit.reactToReply(
                  postId:    widget.postId, commentId: widget.commentId,
                  replyId:   replyId, isLike: true),
            ),
            const SizedBox(width: 10),
            _ReactionBtn(
              icon:  isDisliked ? Icons.heart_broken : Icons.heart_broken_outlined,
              color: isDisliked ? Colors.white : Colors.grey, count: dislikes,
              onTap: () => widget.cubit.reactToReply(
                  postId:    widget.postId, commentId: widget.commentId,
                  replyId:   replyId, isLike: false),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: widget.onReplyToReply,
              child: Row(children: [
                Icon(Icons.reply_rounded,
                    color: widget.isReplyingToThis
                        ? const Color(0xFFe5c687) : Colors.grey,
                    size: 16),
                const SizedBox(width: 3),
                Text(AppStrings.of(context).replyLabel2,
                    style: TextStyle(
                        color: widget.isReplyingToThis
                            ? const Color(0xFFe5c687) : Colors.grey,
                        fontSize: 11)),
              ]),
            ),
          ]),

          // Inline reply-on-reply input
          if (widget.isReplyingToThis)
            Padding(
              padding: const EdgeInsets.only(left: 28, top: 6),
              child: _InlineReplyInput(
                controller:  widget.replyController,
                focusNode:   widget.replyFocus,
                replyingTo:  widget.replyingToUserName,
                onSubmit:    widget.onSubmitReply,
                onCancel:    widget.onCancelReply,
              ),
            ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  INLINE REPLY INPUT
// ══════════════════════════════════════════════════════════════════════════════
class _InlineReplyInput extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String? replyingTo;
  final VoidCallback onSubmit, onCancel;

  const _InlineReplyInput({
    required this.controller, required this.focusNode,
    required this.onSubmit, required this.onCancel, this.replyingTo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1a1d24),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (replyingTo != null)
            Row(children: [
              Text('Replying to @$replyingTo',
                  style: const TextStyle(
                      color: Color(0xFFe5c687), fontSize: 11)),
              const Spacer(),
              GestureDetector(
                  onTap: onCancel,
                  child: const Icon(Icons.close, color: Colors.grey, size: 15)),
            ]),
          Row(children: [
            Expanded(
              child: TextField(
                controller: controller,
                focusNode:  focusNode,
                style: TextStyle(color: AppColors.of(context).text, fontSize: 13),
                maxLines: null,
                decoration: const InputDecoration(
                  hintText:  'Write a reply…',
                  hintStyle: TextStyle(color: Colors.grey, fontSize: 13),
                  border:    InputBorder.none,
                  isDense:   true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            GestureDetector(
              onTap: onSubmit,
              child: const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(Icons.send_rounded,
                    color: Color(0xFFe5c687), size: 22),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  COMMENT INPUT BAR
// ══════════════════════════════════════════════════════════════════════════════
class _CommentInputBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSubmit, onCancelReply;
  final String? replyingTo;

  const _CommentInputBar({
    required this.controller, required this.focusNode,
    required this.onSubmit, required this.onCancelReply, this.replyingTo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1a1d24),
        border: Border(top: BorderSide(
            color: Colors.white.withValues(alpha: 0.08), width: 1)),
      ),
      padding: EdgeInsets.only(
        left: 14, right: 10, top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 100),
              decoration: BoxDecoration(
                color: const Color(0xFF262c34),
                borderRadius: BorderRadius.circular(24),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: TextField(
                controller: controller,
                focusNode:  focusNode,
                style: TextStyle(color: AppColors.of(context).text, fontSize: 14),
                maxLines: null,
                decoration: const InputDecoration(
                  hintText:  'Add a comment…',
                  hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                  border:    InputBorder.none,
                  isDense:   true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onSubmit,
            child: Container(
              width: 42, height: 42,
              decoration: const BoxDecoration(
                  color: Color(0xFFe5c687), shape: BoxShape.circle),
              child: const Icon(Icons.send_rounded,
                  color: Colors.black87, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  SMALL REACTION BUTTON HELPER
// ══════════════════════════════════════════════════════════════════════════════
class _ReactionBtn extends StatelessWidget {
  final IconData icon;
  final Color    color;
  final int      count;
  final VoidCallback onTap;

  const _ReactionBtn({
    required this.icon, required this.color,
    required this.count, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(children: [
        Icon(icon, color: color, size: 18),
        if (count > 0) ...[
          const SizedBox(width: 3),
          Text('$count', style: TextStyle(color: color, fontSize: 12)),
        ],
      ]),
    );
  }
}
