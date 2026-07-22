// lib/layout/chats/message_bubble.dart
//
// Upgraded:
//  • Supports image, video, audio (voice) media types
//  • Forwarded indicator
//  • deletedByOther hint ("You deleted this message")
//  • Reaction bubble tappable → detail sheet callback
//  • Selection highlight (isSelected param)
//  • Long-press → selection mode (no conflict with action sheet)
//  • Action sheet triggered ONLY via onActionsTap callback (never on long-press)

import 'package:cached_network_image/cached_network_image.dart';
import '../../share/local/constants.dart';
import '../../share/local/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/message_model.dart';
import '../../share/style/app_colors.dart';
import '../feeds/post_video_player.dart';

class MessageBubble extends StatelessWidget {
  final MapEntry<String, MessageModel> entry;
  final bool isMe;

  /// Called when the user long-presses the bubble (enters selection mode).
  final VoidCallback? onLongPress;

  /// Called when the user taps the bubble in selection mode (toggles selection).
  final VoidCallback? onTap;

  /// Called when the user taps the "•••" more-options affordance on the bubble.
  /// This opens the action sheet. Kept separate from long-press intentionally.
  final VoidCallback? onActionsTap;

  /// Called when a reaction bubble is tapped (opens detail sheet).
  final VoidCallback? onReactionTap;

  /// Called when a reaction emoji is chosen from the quick-react row.
  final void Function(String messageId, String emoji)? onReact;

  /// Called when the reply quote is tapped (scrolls to original).
  final VoidCallback? onReplyTap;

  /// Whether this bubble is currently selected (multi-select mode).
  final bool isSelected;

  /// Whether multi-select mode is active (affects tap behaviour).
  final bool isSelecting;

  const MessageBubble({
    super.key,
    required this.entry,
    required this.isMe,
    this.onLongPress,
    this.onTap,
    this.onActionsTap,
    this.onReactionTap,
    this.onReact,
    this.onReplyTap,
    this.isSelected = false,
    this.isSelecting = false,
  });

  @override
  Widget build(BuildContext context) {
    final msg   = entry.value;
    final msgId = entry.key;

    return GestureDetector(
      // Long-press → selection mode (never opens action sheet)
      onLongPress: () {
        if (!msg.isDeleted) {
          HapticFeedback.mediumImpact();
          onLongPress?.call();
        }
      },
      // Tap: in selection mode → toggle; otherwise no-op
      onTap: isSelecting ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        color: isSelected
            ? kGold.withValues(alpha: 0.08)
            : Colors.transparent,
        padding: EdgeInsets.only(
          left:   isMe ? 60 : 10,
          right:  isMe ? 10 : 60,
          top:    3,
          bottom: msg.reactions.isNotEmpty ? 22 : 3,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                // ── Reply preview ──────────────────────────────────────────
                if (msg.hasReply)
                  _ReplyPreview(msg: msg, onTap: onReplyTap),

                // ── Bubble ─────────────────────────────────────────────────
                _BubbleContainer(
                  msg:          msg,
                  isMe:         isMe,
                  onActionsTap: isSelecting ? null : onActionsTap,
                ),
              ],
            ),

            // ── Reaction bubble (tappable → detail sheet) ─────────────────
            if (msg.reactions.isNotEmpty)
              Positioned(
                bottom: -14,
                left:   isMe ? null : 6,
                right:  isMe ? 6    : null,
                child: GestureDetector(
                  onTap: onReactionTap,
                  child: _ReactionBubble(reactions: msg.reactions, isMe: isMe),
                ),
              ),

            // ── Selection checkmark ────────────────────────────────────────
            if (isSelecting)
              Positioned(
                top:  0,
                left: isMe ? null : -24,
                right: isMe ? -24 : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 18, height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color:  isSelected ? kGold : Colors.transparent,
                    border: Border.all(
                      color: isSelected ? kGold : Colors.white38,
                      width: 1.5,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check_rounded,
                          color: Colors.black87, size: 12)
                      : null,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Bubble container ──────────────────────────────────────────────────────────
class _BubbleContainer extends StatelessWidget {
  final MessageModel msg;
  final bool isMe;
  final VoidCallback? onActionsTap;

  const _BubbleContainer({
    required this.msg,
    required this.isMe,
    this.onActionsTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDeleted      = msg.isDeleted;
    final deletedByOther = msg.deletedByOther == true && !isMe;

    return Container(
      constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72),
      decoration: BoxDecoration(
        gradient: (isDeleted || deletedByOther)
            ? null
            : isMe
                ? LinearGradient(
                    colors: [
                      kGold.withValues(alpha: 0.85),
                      const Color(0xFFB8964A),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : LinearGradient(
                    // Dark mode: dark grey. Light mode: visible silver-grey (not white).
                    colors: AppColors.of(context).isDark
                        ? const [Color(0xFF2C313A), Color(0xFF21262D)]
                        : const [Color(0xFFD8D8DC), Color(0xFFCCCCD0)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
        color: (isDeleted || deletedByOther) ? Colors.transparent : null,
        border: (isDeleted || deletedByOther)
            ? Border.all(color: Colors.white12, width: 0.5)
            : isMe
                ? Border.all(color: kGold.withValues(alpha: 0.35), width: 0.5)
                : Border.all(
                    color: AppColors.of(context).isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : const Color(0xFFBBBBBF),
                    width: 0.5),
        borderRadius: BorderRadius.only(
          topLeft:     const Radius.circular(18),
          topRight:    const Radius.circular(18),
          bottomLeft:  Radius.circular(isMe ? 18 : 4),
          bottomRight: Radius.circular(isMe ? 4 : 18),
        ),
        boxShadow: (isDeleted || deletedByOther)
            ? null
            : [
                BoxShadow(
                  color: isMe
                      ? kGold.withValues(alpha: 0.12)
                      : Colors.black.withValues(alpha: 0.2),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 36, 8),
            child: _BubbleBody(msg: msg, isMe: isMe),
          ),
          // ── More-options button (separate from long-press/selection) ──────
          if (onActionsTap != null && !isDeleted && !deletedByOther)
            Positioned(
              top: 0, right: 0,
              child: GestureDetector(
                onTap: onActionsTap,
                behavior: HitTestBehavior.translucent,
                child: Container(
                  width: 30, height: 30,
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: isMe
                        ? Colors.black38
                        : Colors.white24,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Bubble body ───────────────────────────────────────────────────────────────
class _BubbleBody extends StatelessWidget {
  final MessageModel msg;
  final bool isMe;
  const _BubbleBody({required this.msg, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final isDark      = AppColors.of(context).isDark;
    final textColor   = isMe ? Colors.black87 : (isDark ? Colors.white : const Color(0xFF1A1A1A));
    final metaColor   = isMe ? Colors.black38 : (isDark ? Colors.white38 : const Color(0xFF666666));

    // ── Deleted for everyone ─────────────────────────────────────────────────
    if (msg.isDeleted) {
      return Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.block_rounded, size: 13, color: metaColor),
        const SizedBox(width: 5),
        Text(AppStrings.of(context).thisMessageDeleted,
            style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic,
                color: metaColor)),
      ]);
    }

    // ── "You deleted this message" hint shown to the OTHER party ─────────────
    if (msg.deletedByOther == true && !isMe) {
      return Text(AppStrings.of(context).youDeletedThisMessage,
          style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic,
              color: Colors.white38));
    }

    return Column(
      crossAxisAlignment:
          isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [

        // ── Forwarded label ─────────────────────────────────────────────────
        if (msg.isForwarded == true) ...[
          Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.forward_rounded, size: 12, color: metaColor),
            const SizedBox(width: 3),
            Text(AppStrings.of(context).forwardedLabel, style: TextStyle(fontSize: 11,
                fontStyle: FontStyle.italic, color: metaColor)),
          ]),
          const SizedBox(height: 4),
        ],

        // ── Image ───────────────────────────────────────────────────────────
        if (msg.hasImage) ...[
          _InlineImage(imageUrl: msg.imageUrl!),
          const SizedBox(height: 6),
        ],

        // ── Video ───────────────────────────────────────────────────────────
        if (msg.hasVideo) ...[
          _InlineVideoThumb(videoUrl: msg.videoUrl!),
          const SizedBox(height: 6),
        ],

        // ── Voice message ───────────────────────────────────────────────────
        if (msg.hasAudio) ...[
          _VoiceRow(durationSec: msg.audioDuration ?? 0, isMe: isMe),
          const SizedBox(height: 4),
        ],

        // ── Text ────────────────────────────────────────────────────────────
        if (msg.text != null && msg.text!.isNotEmpty)
          Text(msg.text!, style: TextStyle(fontSize: 14.5, height: 1.4,
              color: textColor)),

        // ── Meta row ────────────────────────────────────────────────────────
        const SizedBox(height: 4),
        Row(mainAxisSize: MainAxisSize.min, children: [
          if (msg.edited == true) ...[
            Text('edited', style: TextStyle(fontSize: 10,
                fontStyle: FontStyle.italic, color: metaColor)),
            const SizedBox(width: 5),
          ],
          Text(_fmt(msg.dateTime),
              style: TextStyle(fontSize: 10, color: metaColor)),
          if (isMe) ...[
            const SizedBox(width: 4),
            Icon(
              msg.seen == true ? Icons.done_all_rounded : Icons.done_rounded,
              size: 13,
              color: msg.seen == true ? const Color(0xFF1565C0) : metaColor,
            ),
          ],
        ]),
      ],
    );
  }

  String _fmt(String? dt) {
    if (dt == null) return '';
    try {
      final d = DateTime.parse(dt).toLocal();
      String p(int n) => n.toString().padLeft(2, '0');
      return '${p(d.hour)}:${p(d.minute)}';
    } catch (_) { return ''; }
  }
}

// ── Inline image ──────────────────────────────────────────────────────────────
class _InlineImage extends StatelessWidget {
  final String imageUrl;
  const _InlineImage({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showDialog(
        context: context,
        builder: (_) => Dialog(backgroundColor: Colors.transparent,
            child: InteractiveViewer(
                child: CachedNetworkImage(imageUrl: imageUrl))),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          width:    220,
          fit:      BoxFit.cover,
          placeholder: (_, _) => Container(
              width: 220, height: 140,
              color: Colors.black26,
              child: const Center(child: CircularProgressIndicator(
                  color: kGold, strokeWidth: 2))),
          errorWidget: (_, _, ___) => Container(
              width: 220, height: 80, color: Colors.black26,
              child: const Center(child: Icon(Icons.broken_image_rounded,
                  color: Colors.white24))),
        ),
      ),
    );
  }
}

// ── Inline video player in chat bubble ───────────────────────────────────────
// Uses the same PostVideoPlayer as feeds: full-screen button, seek bar,
// aspect-ratio-aware landscape rotation — everything feeds has.
class _InlineVideoThumb extends StatelessWidget {
  final String videoUrl;
  const _InlineVideoThumb({required this.videoUrl});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 240,
        child: PostVideoPlayer(
          videoUrl: videoUrl,
          maxHeight: 150,
        ),
      ),
    );
  }
}

// ── Voice message row ─────────────────────────────────────────────────────────
class _VoiceRow extends StatelessWidget {
  final int  durationSec;
  final bool isMe;
  const _VoiceRow({required this.durationSec, required this.isMe});

  String _fmt(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final trackColor = isMe ? Colors.black26 : Colors.white12;
    final iconColor  = isMe ? Colors.black54 : Colors.white54;
    final metaColor  = isMe ? Colors.black38 : Colors.white38;

    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.mic_rounded, color: iconColor, size: 18),
      const SizedBox(width: 8),
      Container(
        width: 100, height: 3,
        decoration: BoxDecoration(
          color: trackColor, borderRadius: BorderRadius.circular(2)),
      ),
      const SizedBox(width: 8),
      Text(_fmt(durationSec), style: TextStyle(fontSize: 11, color: metaColor)),
    ]);
  }
}

// ── Reply preview ─────────────────────────────────────────────────────────────
class _ReplyPreview extends StatelessWidget {
  final MessageModel msg;
  final VoidCallback? onTap;
  const _ReplyPreview({required this.msg, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: const Border(left: BorderSide(color: kGold, width: 3)),
        ),
        child: Row(children: [
          if (msg.replyToMediaUrl != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: CachedNetworkImage(
                  imageUrl: msg.replyToMediaUrl!,
                  width: 32, height: 32, fit: BoxFit.cover),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(msg.replyToSenderName ?? '',
                  style: const TextStyle(color: kGold, fontSize: 12,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(
                msg.replyToIsStory == true ? '📸 Story reply'
                    : (msg.replyToText ?? ''),
                style: const TextStyle(color: Colors.white54, fontSize: 12),
                maxLines: 2, overflow: TextOverflow.ellipsis,
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ── Reaction bubble ───────────────────────────────────────────────────────────
class _ReactionBubble extends StatelessWidget {
  final Map<String, List<String>> reactions;
  final bool isMe;
  const _ReactionBubble({required this.reactions, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final entries = reactions.entries
        .where((e) => e.value.isNotEmpty)
        .toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));
    if (entries.isEmpty) return const SizedBox.shrink();
    final total = reactions.values.fold(0, (s, l) => s + l.length);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF21262D),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 0.5),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        ...entries.take(3).map((e) =>
            Text(e.key, style: const TextStyle(fontSize: 13))),
        if (total > 1) ...[
          const SizedBox(width: 3),
          Text('$total',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                  color: Colors.white60)),
        ],
      ]),
    );
  }
}
