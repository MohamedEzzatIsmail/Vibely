// lib/layout/chats/chat.dart
// record and just_audio imports removed from this file.
// Voice recording → VoiceRecorderButton (voice_recorder_button.dart)
// Voice playback  → VoiceMessagePlayer  (voice_message_player.dart)
// This removes the "Target of URI doesn't exist" errors entirely from chat.dart.

import 'dart:io';
import 'package:path_provider/path_provider.dart';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import '../../share/local/app_strings.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../layout/cubit/chat/chat_cubit.dart';
import '../../layout/cubit/chat/chat_states.dart';
import '../../models/message_model.dart';
import '../../models/user_model.dart';
import '../../share/local/media_permission_service.dart';
import '../feeds/post_details_screen.dart';
import 'chat_screen_hooks.dart';
import 'voice_recorder_button.dart';    // ← record 6.x isolated here
import 'voice_message_player.dart';
import '../../share/style/app_colors.dart';
import '../../share/local/constants.dart';     // ← just_audio 0.10.x isolated here

part 'chat_message_bubbles.dart';
part 'chat_media_widgets.dart';
part 'chat_actions.dart';

// ─── Design tokens ─────────────────────────────────────────────────────────────
const _kSurface2 = Color(0xFF21262D);
const _kGold     = Color(0xFFE5C687);
const _kGoldDim  = Color(0xFFB8964A);
const _kInputBg  = Color(0xFF1C2128);

const _kReactionEmojis = ['❤️', '😂', '😮', '😢', '😡', '👍'];

const _kGroupNameColors = [
  Color(0xFF4CAF50), Color(0xFF2196F3), Color(0xFFFF9800),
  Color(0xFFE91E63), Color(0xFF9C27B0), Color(0xFF00BCD4),
];

Color _senderColor(String? uid) {
  if (uid == null) return _kGroupNameColors[0];
  return _kGroupNameColors[uid.hashCode.abs() % _kGroupNameColors.length];
}

class ChatScreen extends StatefulWidget {
  final UserModel user;
  const ChatScreen({super.key, required this.user});
  @override State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with SingleTickerProviderStateMixin, ChatScreenHooks {

  late ChatCubit cubit;
  final _controller       = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode        = FocusNode();
  final _searchController = TextEditingController();

  bool   _inputHasText = false;
  bool   _searchMode   = false;
  String _searchQuery  = '';

  // ── Multi-select ────────────────────────────────────────────────────────────
  final Set<String> _selected = {};
  bool get _selecting => _selected.isNotEmpty;

  // ── Reply / edit ────────────────────────────────────────────────────────────
  MessageModel? _replyingTo;
  String?       _replyingToDocId;
  MessageModel? _editingMsg;
  String?       _editingDocId;

  // ── Scroll-to-reply ─────────────────────────────────────────────────────────
  final Map<String, GlobalKey> _messageKeys = {};
  String? _highlightedDocId;

  // ── Scroll FAB ──────────────────────────────────────────────────────────────
  bool _showScrollFab = false;

  // ── Undo-delete ──────────────────────────────────────────────────────────────
  // Holds the last deleted message so the user can recover it within 5 seconds.
  // _undoCancelled = true means user tapped Undo before the timer fired.
  MessageModel? _undoMsg;
  String?       _undoDocId;
  bool          _undoForEveryone = false;
  bool          _undoCancelled   = false;

  @override
  void initState() {
    super.initState();
    cubit = context.read<ChatCubit>();
    cubit.initChat(widget.user.uid!);
    cubit.setContext(context);
    hookFCM(_chatId);

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 100) {
        cubit.loadMoreMessages(widget.user.uid!);
      }
      final showFab = _scrollController.offset > 200;
      if (showFab != _showScrollFab) setState(() => _showScrollFab = showFab);
    });

    _controller.addListener(() {
      final has = _controller.text.trim().isNotEmpty;
      if (has != _inputHasText) setState(() => _inputHasText = has);
    });

    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim());
    });
  }

  @override
  void dispose() {
    unhookFCM();
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _searchController.dispose();
    cubit.disposeChat(widget.user.uid!);
    super.dispose();
  }

  String get _chatId {
    final ids = [cubit.currentUser?.uid ?? '', widget.user.uid!]..sort();
    return ids.join('_');
  }

  // ── Send helpers ─────────────────────────────────────────────────────────────
  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    if (_editingMsg != null && _editingDocId != null) {
      cubit.editMessage(
          receiverId: widget.user.uid!, messageId: _editingDocId!, newText: text);
      setState(() { _editingMsg = null; _editingDocId = null; });
    } else if (_replyingTo != null && _replyingToDocId != null) {
      cubit.sendReply(
        receiverId:        widget.user.uid!,
        text:              text,
        replyToId:         _replyingToDocId!,
        replyToSenderName: cubit.isMe(_replyingTo!.senderId)
            ? 'You' : (widget.user.name ?? ''),
        replyToText:       _replyingTo!.text ?? '',
        replyToMediaUrl:   _replyingTo!.replyToMediaUrl,
        replyToIsStory:    _replyingTo!.replyToIsStory ?? false,
      );
      setState(() { _replyingTo = null; _replyingToDocId = null; });
    } else {
      cubit.sendMessage(receiverId: widget.user.uid!, text: text);
    }
    _controller.clear();
    HapticFeedback.lightImpact();
  }

  Future<void> _pickAndSendImage({ImageSource source = ImageSource.gallery}) async {
    final ok = await MediaPermissionService.requestMediaPermission(context);
    if (!ok || !mounted) return;
    final picked = await ImagePicker().pickImage(source: source, imageQuality: 80);
    if (picked == null || !mounted) return;
    cubit.sendImage(receiverId: widget.user.uid!, imageFile: File(picked.path));
  }

  Future<void> _pickAndSendVideo({ImageSource source = ImageSource.gallery}) async {
    final ok = await MediaPermissionService.requestMediaPermission(context);
    if (!ok || !mounted) return;
    final picked = await ImagePicker().pickVideo(source: source);
    if (picked == null || !mounted) return;
    File videoFile;
    if (picked.path.startsWith('content://')) {
      final tmp = await getTemporaryDirectory();
      final dst = File('${tmp.path}/chat_vid_${DateTime.now().millisecondsSinceEpoch}.mp4');
      await File(picked.path).copy(dst.path);
      videoFile = dst;
    } else {
      videoFile = File(picked.path);
    }
    if (!mounted) return;
    cubit.sendVideo(receiverId: widget.user.uid!, videoFile: videoFile);
  }

  // ── Selection ────────────────────────────────────────────────────────────────
  void _onBubbleLongPress(String docId, MessageModel msg) {
    // FIX: deleted messages ARE selectable — user needs to be able to
    // long-press them so they can select + delete the local placeholder too.
    HapticFeedback.mediumImpact();
    setState(() => _selected.add(docId));
  }

  void _onBubbleTap(String docId) {
    if (!_selecting) return;
    setState(() {
      if (_selected.contains(docId)) _selected.remove(docId);
      else _selected.add(docId);
    });
  }

  void _exitSelection() => setState(() => _selected.clear());

  // ── BUILD ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ChatCubit, ChatStates>(
      listener: (context, state) {
        // Every send/upload/action failure in ChatCubit emits ChatErrorState,
        // but until now nothing displayed it — failures looked identical to
        // "nothing happened." Surface it so the user knows something went
        // wrong instead of silently retyping into a dead send button.
        if (state is ChatErrorState) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.red.shade700,
            ),
          );
        }
      },
      builder: (context, state) {
      final disappearDays = cubit.getDisappearDays(widget.user.uid!);
      return Scaffold(
        backgroundColor: AppColors.of(context).bg,
        appBar: _selecting
            ? _selectionBar()
            : (_searchMode ? _searchBar() : _appBar()),
        body: Column(children: [
          // Disappearing messages banner
          if (disappearDays != null)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 5),
              color: _kGold.withValues(alpha: 0.08),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.timer_outlined, color: _kGold, size: 14),
                const SizedBox(width: 6),
                Text(
                    'Messages disappear after $disappearDays day${disappearDays == 1 ? "" : "s"}',
                    style: const TextStyle(color: _kGold, fontSize: 12)),
              ]),
            ),
          Expanded(child: Stack(children: [
            _buildList(),
            // Per-bubble upload progress (Prompt 14)
            if (state is ChatSendingMediaState)
              Positioned(right: 12, bottom: 12,
                  child: _UploadProgressBubble(progress: state.progress)),
          ])),
          if (_replyingTo != null) _replyBanner(),
          if (_editingMsg  != null) _editBanner(),
          _inputBar(),
        ]),
        floatingActionButton: _showScrollFab
            ? Padding(
            padding: const EdgeInsets.only(bottom: 70),
            child: GestureDetector(
              onTap: () => _scrollController.animateTo(0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut),
              child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle, color: AppColors.of(context).surface,
                      border: Border.all(color: AppColors.of(context).border)),
                  child: Icon(Icons.keyboard_arrow_down_rounded,
                      color: AppColors.of(context).textSub, size: 22)),
            ))
            : null,
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      );
    });
  }

  // ── App bar ───────────────────────────────────────────────────────────────────
  PreferredSizeWidget _appBar() {
    final live     = cubit.getLiveUser(widget.user.uid!) ?? widget.user;
    final online   = live.isOnline;
    final lastSeen = live.lastSeen;

    return PreferredSize(
      preferredSize: const Size.fromHeight(64),
      child: Container(
        decoration: BoxDecoration(color: AppColors.of(context).surface,
            border: Border(bottom: BorderSide(color: Color(0x18FFFFFF)))),
        child: SafeArea(bottom: false, child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(children: [
            IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded,
                  color: AppColors.of(context).textSub, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            // Tap to open contact profile (Prompt 17)
            GestureDetector(
              onTap: _showContactProfile,
              child: Row(children: [
                Stack(children: [
                  CircleAvatar(radius: 20, backgroundColor: AppColors.of(context).elevated,
                      backgroundImage: widget.user.image?.isNotEmpty == true
                          ? NetworkImage(widget.user.image!) : null,
                      child: widget.user.image?.isEmpty != false
                          ? Icon(Icons.person, color: AppColors.of(context).textHint) : null),
                  if (online) Positioned(right: 0, bottom: 0,
                      child: Container(width: 10, height: 10,
                          decoration: BoxDecoration(
                              color: const Color(0xFF2EA043),
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.of(context).surface, width: 2)))),
                ]),
                const SizedBox(width: 10),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(widget.user.name ?? '',
                      style: TextStyle(color: AppColors.of(context).text, fontSize: 15,
                          fontWeight: FontWeight.w600)),
                  BlocBuilder<ChatCubit, ChatStates>(builder: (_, _) {
                    if (cubit.isUserTyping(widget.user.uid!))
                      return const Text('typing…',
                          style: TextStyle(color: _kGold, fontSize: 12));
                    if (online) return Text(AppStrings.of(context).onlineStatus,
                        style: TextStyle(color: Color(0xFF2EA043), fontSize: 12));
                    if (lastSeen != null)
                      return Text(cubit.formatLastSeen(lastSeen),
                          style: TextStyle(color: AppColors.of(context).textHint, fontSize: 11));
                    return Text(AppStrings.of(context).offlineStatus,
                        style: TextStyle(color: AppColors.of(context).textHint, fontSize: 12));
                  }),
                ]),
              ]),
            ),
            const Spacer(),
            IconButton(
              icon: Icon(Icons.search, color: AppColors.of(context).textSub, size: 20),
              onPressed: () => setState(() {
                _searchMode = true;
                _searchController.clear();
              }),
            ),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: AppColors.of(context).textSub),
              color: _kSurface2,
              onSelected: (v) {
                if (v == 'disappear') _showDisappearSheet();
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'disappear',
                    child: Text(AppStrings.of(context).disappearingMessages,
                        style: TextStyle(color: AppColors.of(context).textSub))),
              ],
            ),
          ]),
        )),
      ),
    );
  }

  PreferredSizeWidget _searchBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(64),
      child: Container(
        decoration: BoxDecoration(color: AppColors.of(context).surface,
            border: Border(bottom: BorderSide(color: Color(0x18FFFFFF)))),
        child: SafeArea(bottom: false, child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(children: [
            IconButton(
              icon: Icon(Icons.close, color: AppColors.of(context).textSub),
              onPressed: () => setState(() {
                _searchMode = false;
                _searchQuery = '';
                _searchController.clear();
              }),
            ),
            Expanded(child: TextField(
              controller: _searchController, autofocus: true,
              style: TextStyle(color: AppColors.of(context).text),
              decoration: InputDecoration(
                hintText: 'Search messages…',
                hintStyle: TextStyle(color: AppColors.of(context).textHint),
                border: InputBorder.none,
              ),
            )),
          ]),
        )),
      ),
    );
  }

  PreferredSizeWidget _selectionBar() {
    return AppBar(
      backgroundColor: AppColors.of(context).elevated,
      leading: IconButton(
        icon: Icon(Icons.close_rounded, color: AppColors.of(context).text),
        onPressed: _exitSelection,
      ),
      title: Text('${_selected.length} selected',
          style: TextStyle(color: AppColors.of(context).text, fontSize: 15)),
      actions: [
        // Forward selected (Prompt 25)
        IconButton(
          icon: Icon(Icons.forward_rounded, color: AppColors.of(context).textSub),
          onPressed: () {
            final msgs = _selected
                .map((id) => cubit.getMessagesWithIds(widget.user.uid!)
                .firstWhereOrNull((e) => e.key == id)?.value)
                .whereType<MessageModel>()
                .toList();
            if (msgs.isEmpty) return;
            _exitSelection();
            _showForwardSheet(msgs);
          },
        ),
        IconButton(
          icon: const Icon(Icons.delete_rounded, color: Colors.redAccent),
          onPressed: _showBulkDeleteDialog,
        ),
      ],
    );
  }

  Widget _replyBanner() {
    final isMe = cubit.isMe(_replyingTo!.senderId);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      decoration: BoxDecoration(color: AppColors.of(context).surface,
          border: Border(top: BorderSide(color: Color(0x18FFFFFF)))),
      child: Row(children: [
        Container(width: 3, height: 36,
            decoration: BoxDecoration(
                color: _kGold, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(isMe ? 'You' : (widget.user.name ?? ''),
              style: const TextStyle(color: _kGold, fontSize: 12,
                  fontWeight: FontWeight.w600)),
          Text(
              _replyingTo!.text ?? (_replyingTo!.hasImage ? '🖼️ Image'
                  : _replyingTo!.hasVideo ? '📹 Video' : ''),
              style: TextStyle(color: AppColors.of(context).textSub, fontSize: 12),
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ])),
        GestureDetector(
          onTap: () => setState(() { _replyingTo = null; _replyingToDocId = null; }),
          child: Padding(padding: const EdgeInsets.all(8),
              child: Icon(Icons.close_rounded, color: AppColors.of(context).textHint, size: 18)),
        ),
      ]),
    );
  }

  Widget _editBanner() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      decoration: BoxDecoration(color: AppColors.of(context).surface,
          border: Border(top: BorderSide(color: Color(0x18FFFFFF)))),
      child: Row(children: [
        const Icon(Icons.edit_rounded, color: _kGold, size: 16),
        const SizedBox(width: 10),
        Expanded(child: Text(AppStrings.of(context).editingMessage,
            style: TextStyle(color: _kGold, fontSize: 12))),
        GestureDetector(
          onTap: () => setState(() {
            _editingMsg = null; _editingDocId = null; _controller.clear();
          }),
          child: Padding(padding: const EdgeInsets.all(8),
              child: Icon(Icons.close_rounded, color: AppColors.of(context).textHint, size: 18)),
        ),
      ]),
    );
  }

  // ── Messages list ─────────────────────────────────────────────────────────────
  Widget _buildList() {
    final entries = _searchMode && _searchQuery.isNotEmpty
        ? cubit.searchMessages(widget.user.uid!, _searchQuery)
        : cubit.getMessagesWithIds(widget.user.uid!);

    if (entries.isEmpty && !_searchMode) {
      final imageUrl = widget.user.image;
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        ClipOval(
          child: Container(
            width: 72, height: 72,
            color: AppColors.of(context).elevated,
            alignment: Alignment.center,
            child: (imageUrl != null && imageUrl.isNotEmpty)
                ? CachedNetworkImage(
              imageUrl: imageUrl,
              width: 72, height: 72,
              fit: BoxFit.cover,
              placeholder: (_, _) => Icon(Icons.person, size: 32,
                  color: AppColors.of(context).textHint),
              errorWidget: (_, _, ___) => Icon(Icons.person, size: 32,
                  color: AppColors.of(context).textHint),
            )
                : Icon(Icons.person, size: 32, color: AppColors.of(context).textHint),
          ),
        ),
        const SizedBox(height: 16),
        Text(widget.user.name ?? '',
            style: TextStyle(color: AppColors.of(context).text, fontSize: 16,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text('${AppStrings.of(context).noMessagesYet} — ${AppStrings.of(context).sayHello}',
            style: TextStyle(color: AppColors.of(context).textHint, fontSize: 13)),
      ]));
    }

    if (entries.isEmpty && _searchMode) {
      return Center(
          child: Text(AppStrings.of(context).noResults, style: TextStyle(color: AppColors.of(context).textHint)));
    }

    // FIX: pre-compute which calendar days have at least one visible message.
    // A "visible" message here means it exists in entries (deletedForMe are
    // already stripped by the cubit). We only show a date separator for days
    // that actually have messages — so if every message on a day is removed,
    // the separator for that day disappears too.
    String _dayKey(String? dt) {
      final d = DateTime.tryParse(dt ?? '');
      if (d == null) return '';
      return '${d.year}-${d.month}-${d.day}';
    }

    final daysWithMessages = <String>{
      for (final e in entries) _dayKey(e.value.dateTime),
    };

    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: entries.length,
      itemBuilder: (_, i) {
        final entry = entries[i];
        final docId = entry.key;
        final msg   = entry.value;
        final isMe  = cubit.isMe(msg.senderId);
        final key   = _messageKeys.putIfAbsent(docId, () => GlobalKey());

        Widget bubble = _msgRow(msg, docId, isMe, key);

        // The list is REVERSED (newest at bottom, index 0 = newest).
        // A date separator belongs ABOVE the first message of each day
        // (i.e. the oldest message of that day, in visual terms) — this
        // matches the usual chat convention (WhatsApp/Telegram/Messenger).
        //
        // Logic:
        //   - Show a separator ABOVE the current bubble (as the first child
        //     in this item's Column — this item sits visually above the
        //     NEXT entry, which is older) when the CURRENT message is on a
        //     different day from the NEXT message (older, higher index).
        //   - The separator label shows the date of the CURRENT message,
        //     because it introduces the group that starts here.
        //   - For the oldest message in the list (last index), always show
        //     its own day separator above it.
        //   - Never show a separator for a day that has no visible messages.

        final currDt  = DateTime.tryParse(msg.dateTime ?? '');
        final currKey = _dayKey(msg.dateTime);

        if (!daysWithMessages.contains(currKey)) return bubble;

        if (i < entries.length - 1) {
          final nextDt = DateTime.tryParse(entries[i + 1].value.dateTime ?? '');
          // Show separator when crossing a day boundary
          if (currDt != null && nextDt != null && !_sameDay(currDt, nextDt)) {
            return Column(mainAxisSize: MainAxisSize.min, children: [
              // Separator date = current message's date (the group below starts here)
              _DateSeparator(date: currDt),
              bubble,
            ]);
          }
        } else {
          // Oldest message in list — always gets its own separator
          if (currDt != null) {
            return Column(mainAxisSize: MainAxisSize.min, children: [
              _DateSeparator(date: currDt),
              bubble,
            ]);
          }
        }
        return bubble;
      },
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Widget _msgRow(MessageModel msg, String docId, bool isMe, GlobalKey key) {
    final isSelected    = _selected.contains(docId);
    final isHighlighted = _highlightedDocId == docId;

    Widget bubble = isMe
        ? _MyBubble(msg: msg, docId: docId, cubit: cubit,
        onActionsTap: () => _showMessageActions(msg, docId),
        onReactionTap: () => _showReactionDetail(msg))
        : _OtherBubble(msg: msg, docId: docId, cubit: cubit,
        onActionsTap: () => _showMessageActions(msg, docId),
        onReactionTap: () => _showReactionDetail(msg));

    // Swipe to reply (disabled in selection mode)
    if (!_selecting) {
      bubble = Dismissible(
        key: ValueKey('swipe_$docId'),
        direction: isMe ? DismissDirection.endToStart : DismissDirection.startToEnd,
        confirmDismiss: (_) async {
          if (!msg.isDeleted) {
            setState(() { _replyingTo = msg; _replyingToDocId = docId; });
            _focusNode.requestFocus();
          }
          return false;
        },
        background: Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Padding(padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: _kGold.withValues(alpha: 0.15), shape: BoxShape.circle),
                  child: const Icon(Icons.reply_rounded, color: _kGold, size: 22))),
        ),
        child: bubble,
      );
    }

    return KeyedSubtree(
      key: key,
      child: GestureDetector(
        onLongPress: () => _onBubbleLongPress(docId, msg),
        onTap: () => _onBubbleTap(docId),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          color: isHighlighted
              ? _kGold.withValues(alpha: 0.15)
              : isSelected
              ? _kGold.withValues(alpha: 0.08)
              : Colors.transparent,
          child: bubble,
        ),
      ),
    );
  }

  // ── Input bar ─────────────────────────────────────────────────────────────────
  Widget _inputBar() {
    final blocked = widget.user.uid != null && cubit.isBlockedPair(widget.user.uid!);
    if (blocked) {
      return Container(
        decoration: BoxDecoration(color: AppColors.of(context).surface,
            border: Border(top: BorderSide(color: Color(0x18FFFFFF)))),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: SafeArea(top: false, child: Row(children: [
          Icon(Icons.block_rounded, color: AppColors.of(context).textHint, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(
            "You can't message this user.",
            style: TextStyle(color: AppColors.of(context).textHint, fontSize: 13.5),
          )),
        ])),
      );
    }
    return Container(
      decoration: BoxDecoration(color: AppColors.of(context).surface,
          border: Border(top: BorderSide(color: Color(0x18FFFFFF)))),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: SafeArea(top: false, child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Media picker (Prompt 12 — camera inside)
          _MediaPickerButton(receiverId: widget.user.uid!, cubit: cubit),
          const SizedBox(width: 8),
          Expanded(child: Container(
            constraints: const BoxConstraints(maxHeight: 120),
            decoration: BoxDecoration(
                color: AppColors.of(context).surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.of(context).border)),
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              style: TextStyle(color: AppColors.of(context).text, fontSize: 15),
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (t) => cubit.onTypingChanged(widget.user.uid!, t),
              decoration: InputDecoration(
                hintText: 'Message…',
                hintStyle: TextStyle(color: AppColors.of(context).textHint, fontSize: 15),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              ),
            ),
          )),
          const SizedBox(width: 8),
          // FIX: ScaleTransition inside AnimatedSwitcher with an unconstrained
          // parent causes RenderStack layout crash. Use SizedBox + Opacity
          // switch to keep sizing stable while still animating.
          SizedBox(
            width: 44, height: 44,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              transitionBuilder: (child, anim) =>
                  FadeTransition(opacity: anim, child: child),
              child: _inputHasText
                  ? _CircleButton(
                  key: const ValueKey('send'),
                  icon: Icons.send_rounded,
                  filled: true,
                  onTap: _sendMessage)
              // MicButton: hold-to-record, overlay recording UI
                  : MicButton(
                  key: const ValueKey('mic'),
                  receiverId: widget.user.uid!,
                  cubit: cubit),
            ),
          ),
        ],
      )),
    );
  }
}