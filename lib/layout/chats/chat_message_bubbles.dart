part of 'chat.dart';

class _MyBubble extends StatelessWidget {
  final MessageModel msg;
  final String       docId;
  final ChatCubit    cubit;
  final VoidCallback? onActionsTap;
  final VoidCallback? onReactionTap;
  const _MyBubble({required this.msg, required this.docId, required this.cubit,
    this.onActionsTap, this.onReactionTap});

  @override
  Widget build(BuildContext context) {
    final hasReactions = msg.reactions.isNotEmpty;
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: EdgeInsets.only(
            left: 56, right: 12, top: 3, bottom: hasReactions ? 22 : 3),
        child: Stack(clipBehavior: Clip.none, children: [
          GestureDetector(
            onTap: onActionsTap,
            child: Container(
              constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.72),
              // FIX: deleted messages show a proper muted bubble, not transparent
              decoration: BoxDecoration(
                gradient: msg.isDeleted ? null : const LinearGradient(
                    colors: [Color(0xFFE5C687), Color(0xFFB8964A)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight),
                color: msg.isDeleted ? const Color(0xFF1C2128) : null,
                borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(18), topRight: Radius.circular(18),
                    bottomLeft: Radius.circular(18), bottomRight: Radius.circular(4)),
                border: msg.isDeleted
                    ? Border.all(color: Colors.white12, width: 0.8)
                    : Border.all(color: const Color(0xFFB8964A).withValues(alpha: 0.35), width: 0.5),
                boxShadow: msg.isDeleted ? null : [BoxShadow(
                    color: const Color(0xFFB8964A).withValues(alpha: 0.25),
                    blurRadius: 8, offset: const Offset(0, 3))],
              ),
              child: _MsgContent(msg: msg, isMe: true, cubit: cubit),
            ),
          ),
          if (hasReactions) Positioned(bottom: -14, right: 6,
              child: GestureDetector(
                  onTap: onReactionTap,
                  child: _ReactionBubble(
                      reactions: msg.reactions,
                      myUid: cubit.currentUser?.uid,
                      isMe: true))),
        ]),
      ),
    );
  }
}

class _OtherBubble extends StatelessWidget {
  final MessageModel msg;
  final String       docId;
  final ChatCubit    cubit;
  final VoidCallback? onActionsTap;
  final VoidCallback? onReactionTap;
  const _OtherBubble({required this.msg, required this.docId, required this.cubit,
    this.onActionsTap, this.onReactionTap});

  @override
  Widget build(BuildContext context) {
    final hasReactions = msg.reactions.isNotEmpty;
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.only(
            left: 12, right: 56, top: 3, bottom: hasReactions ? 22 : 3),
        child: Stack(clipBehavior: Clip.none, children: [
          GestureDetector(
            onTap: onActionsTap,
            child: Container(
              constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.72),
              // FIX: deleted messages show a proper muted bubble, not transparent
              decoration: BoxDecoration(
                gradient: msg.isDeleted ? null : const LinearGradient(
                    colors: [Color(0xFFFFFFFF), Color(0xFFE8E8E8)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight),
                color: msg.isDeleted ? const Color(0xFF1C2128) : null,
                borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4), topRight: Radius.circular(18),
                    bottomLeft: Radius.circular(18), bottomRight: Radius.circular(18)),
                border: msg.isDeleted
                    ? Border.all(color: Colors.white12, width: 0.8)
                    : null,
              ),
              child: _MsgContent(msg: msg, isMe: false, cubit: cubit),
            ),
          ),
          if (hasReactions) Positioned(bottom: -14, left: 6,
              child: GestureDetector(
                  onTap: onReactionTap,
                  child: _ReactionBubble(
                      reactions: msg.reactions,
                      myUid: cubit.currentUser?.uid,
                      isMe: false))),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  MESSAGE CONTENT
// ══════════════════════════════════════════════════════════════════════════════
class _MsgContent extends StatelessWidget {
  final MessageModel msg;
  final bool         isMe;
  final ChatCubit    cubit;
  const _MsgContent({required this.msg, required this.isMe, required this.cubit});

  @override
  Widget build(BuildContext context) {
    if (msg.isDeleted) {
      // FIX: bubble bg is now dark (0xFF1C2128) so use white-toned text
      return Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.block_rounded, size: 13, color: AppColors.of(context).textHint),
            const SizedBox(width: 6),
            Text(AppStrings.of(context).thisMessageDeleted,
                style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic,
                    color: AppColors.of(context).textHint)),
          ]));
    }
    if (msg.deletedByOther == true && !isMe) {
      return Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Text(AppStrings.of(context).youDeletedMessage,
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic,
                  color: AppColors.of(context).textHint)));
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // Group sender name (Prompt 5)
          if (msg.isGroupMsg == true && !isMe) ...[
            Text(
              cubit.users.firstWhereOrNull((u) => u.uid == msg.senderId)?.name ?? 'Unknown',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                  color: _senderColor(msg.senderId)),
            ),
            const SizedBox(height: 3),
          ],
          if (msg.isForwarded == true) ...[
            Padding(padding: const EdgeInsets.only(bottom: 4),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.forward_rounded, size: 12,
                      color: isMe ? Colors.black38 : Colors.white38),
                  const SizedBox(width: 3),
                  Text(AppStrings.of(context).forwardedLabel, style: TextStyle(fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: isMe ? Colors.black38 : Colors.white38)),
                ])),
          ],
          if (msg.hasReply) _ReplyQuote(msg: msg, isMe: isMe),
          if (msg.isSharedPost) _SharedPostCard(msg: msg, isMe: isMe),
          // Image (Prompt 13 — full-screen viewer)
          if (msg.hasImage) _InlineImage(imageUrl: msg.imageUrl!, caption: msg.text),
          if (msg.hasVideo) _InlineVideoPlayer(videoUrl: msg.videoUrl!),
          // Voice player (Prompt 2 — now using isolated widget)
          if (msg.hasAudio)
            VoiceMessagePlayer(
              audioUrl:     msg.audioUrl!,
              durationSec:  msg.audioDuration ?? 0,
              isMe:         isMe,
              waveformData: msg.waveformData,
            ),
          if (msg.text != null && msg.text!.isNotEmpty && !msg.hasImage)
            Padding(padding: const EdgeInsets.only(top: 2),
                child: Text(msg.text!,
                    style: const TextStyle(fontSize: 15, height: 1.4,
                        color: Colors.black87))),
          const SizedBox(height: 4),
          Row(mainAxisSize: MainAxisSize.min, children: [
            if (msg.edited == true) ...[
              Text('edited', style: TextStyle(fontSize: 10,
                  fontStyle: FontStyle.italic,
                  color: isMe ? Colors.black38 : Colors.black38)),
              const SizedBox(width: 5),
            ],
            Text(cubit.formatTime(msg.dateTime),
                style: TextStyle(fontSize: 10,
                    color: isMe ? Colors.black45 : Colors.black45)),
            if (isMe) ...[
              const SizedBox(width: 4),
              Icon(msg.seen == true
                  ? Icons.done_all_rounded : Icons.done_rounded,
                  size: 14,
                  color: msg.seen == true
                      ? const Color(0xFF1565C0) : Colors.black38),
            ],
          ]),
        ],
      ),
    );
  }
}
