part of 'story_viewer.dart';

class _StoryBottomBar extends StatelessWidget {
  final StoryModel liveStory;
  final String myUid;
  final TextEditingController replyCtrl;
  final List<MapEntry<String, List<String>>> reactionEntries;
  final int totalReactions;
  final VoidCallback onPause;
  final VoidCallback onReact;
  final VoidCallback onComment;
  final VoidCallback onShare;
  final void Function(String) onSendReply;

  const _StoryBottomBar({
    required this.liveStory,
    required this.myUid,
    required this.replyCtrl,
    required this.reactionEntries,
    required this.totalReactions,
    required this.onPause,
    required this.onReact,
    required this.onComment,
    required this.onShare,
    required this.onSendReply,
  });

  @override
  Widget build(BuildContext context) {
    // Did current user react?
    String? myEmoji;
    for (final e in liveStory.reactions.entries) {
      if (e.value.contains(myUid)) { myEmoji = e.key; break; }
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black.withValues(alpha: 0.85), Colors.transparent],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Reaction summary row (if any reactions)
        if (reactionEntries.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(children: [
              GestureDetector(
                onTap: onReact,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    ...reactionEntries.take(5).map((e) => Padding(
                          padding: const EdgeInsets.only(right: 2),
                          child: Text(e.key,
                              style: const TextStyle(fontSize: 17)),
                        )),
                    const SizedBox(width: 4),
                    Text('$totalReactions',
                        style: TextStyle(
                            color: AppColors.of(context).textSub,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            ]),
          ),

        // Action icons row
        Row(children: [
          // Like/React button — Facebook heart-style
          _FbActionBtn(
            icon: myEmoji != null
                ? Text(myEmoji, style: const TextStyle(fontSize: 22))
                : Icon(Icons.favorite_border_rounded,
                    color: AppColors.of(context).text, size: 24),
            label: 'React',
            highlighted: myEmoji != null,
            onTap: onReact,
          ),
          const SizedBox(width: 4),
          // Comment
          _FbActionBtn(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(Icons.chat_bubble_outline_rounded,
                    color: AppColors.of(context).text, size: 24),
                if (liveStory.commentCount > 0)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                          color: Color(0xFFe5c687), shape: BoxShape.circle),
                      child: Text('${liveStory.commentCount}',
                          style: const TextStyle(
                              fontSize: 9,
                              color: Colors.black,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
              ],
            ),
            label: 'Comment',
            highlighted: false,
            onTap: onComment,
          ),
          const SizedBox(width: 4),
          // Share
          _FbActionBtn(
            icon: Icon(Icons.reply_rounded,
                color: AppColors.of(context).text, size: 24),
            label: 'Share',
            highlighted: false,
            onTap: onShare,
          ),
          const Spacer(),
          // Reply text field
          Expanded(
            flex: 3,
            child: TextField(
              controller: replyCtrl,
              style:
                  TextStyle(color: AppColors.of(context).text, fontSize: 14),
              onTap: onPause,
              onSubmitted: onSendReply,
              decoration: InputDecoration(
                hintText: 'Reply to ${liveStory.userName}…',
                hintStyle: TextStyle(
                    color: AppColors.of(context).textSub, fontSize: 13),
                filled: true,
                fillColor: Colors.white10,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.send_rounded,
                      color: Color(0xFFe5c687), size: 18),
                  onPressed: () => onSendReply(replyCtrl.text),
                ),
              ),
            ),
          ),
        ]),
      ]),
    );
  }
}

// ── Facebook action button ────────────────────────────────────────────────────
class _FbActionBtn extends StatelessWidget {
  final Widget icon;
  final String label;
  final bool highlighted;
  final VoidCallback onTap;
  const _FbActionBtn(
      {required this.icon,
      required this.label,
      required this.highlighted,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          icon,
          const SizedBox(height: 3),
          Text(label,
              style: TextStyle(
                  color: highlighted
                      ? const Color(0xFFe5c687)
                      : Colors.white70,
                  fontSize: 11,
                  fontWeight: highlighted
                      ? FontWeight.bold
                      : FontWeight.normal)),
        ]),
      ),
    );
  }
}

// ── Emoji float animation overlay ─────────────────────────────────────────────
class _EmojiFloatAnim extends StatefulWidget {
  final String emoji;
  const _EmojiFloatAnim({required this.emoji});
  @override
  State<_EmojiFloatAnim> createState() => _EmojiFloatAnimState();
}

class _EmojiFloatAnimState extends State<_EmojiFloatAnim>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _y, _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1100));
    _y = Tween<double>(begin: 0, end: -120).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _opacity = Tween<double>(begin: 1, end: 0).animate(
        CurvedAnimation(parent: _ctrl, curve: const Interval(0.6, 1)));
    _ctrl.forward();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final sz = MediaQuery.of(context).size;
    return Positioned(
      left: sz.width / 2 - 24,
      bottom: sz.height * 0.25,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, _) => Transform.translate(
          offset: Offset(0, _y.value),
          child: Opacity(
            opacity: _opacity.value,
            child: Text(widget.emoji,
                style: const TextStyle(fontSize: 48)),
          ),
        ),
      ),
    );
  }
}

