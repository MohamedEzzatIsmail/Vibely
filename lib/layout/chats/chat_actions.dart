part of 'chat.dart';

// ──────────────────────────────────────────────────────────────────────────────
//  Action-sheet / dialog methods for the chat screen — delete, edit, forward,
//  block/report, etc. Kept as an extension (not a separate class) so every
//  method here has full access to _ChatScreenState's fields and setState.
// ──────────────────────────────────────────────────────────────────────────────
extension ChatScreenActions on _ChatScreenState {
  // ── 5-second undo snackbar ───────────────────────────────────────────────────
  /// Shows an undo snackbar right after a delete. The actual Firestore write
  /// is deferred 5 seconds so the user can tap Undo and abort it; if they do
  /// nothing, it commits automatically once the timer elapses.
  void _showUndoDeleteSnack({
    required MessageModel msg,
    required String       docId,
    required bool         forEveryone,
    String?               label,
  }) {
    _undoMsg          = msg;
    _undoDocId        = docId;
    _undoForEveryone  = forEveryone;
    _undoCancelled    = false;

    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();

    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 5),
        backgroundColor: AppColors.of(context).elevated,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(children: [
          Icon(Icons.delete_outline, color: AppColors.of(context).textSub, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label ?? (forEveryone ? 'Deleted for everyone' : 'Deleted for you'),
              style: TextStyle(color: AppColors.of(context).textSub, fontSize: 13),
            ),
          ),
        ]),
        action: SnackBarAction(
          label: 'UNDO',
          textColor: const Color(0xFFE5C687),
          onPressed: () {
            // User tapped Undo — cancel the pending write
            _undoCancelled = true;
            // The message is still in Firestore unmodified (we haven't written yet),
            // so nothing more is needed — the UI will still show it.
          },
        ),
        onVisible: () {
          // Commit the delete after 5 seconds UNLESS user cancelled
          Future.delayed(const Duration(seconds: 5), () {
            if (_undoCancelled) return;
            if (_undoDocId == null) return;
            final id = _undoDocId!;
            final ev = _undoForEveryone;
            _undoMsg    = null;
            _undoDocId  = null;
            if (ev) {
              cubit.deleteForEveryone(
                  receiverId: widget.user.uid!, messageId: id);
            } else {
              cubit.deleteForMe(
                  receiverId: widget.user.uid!, messageId: id);
            }
          });
        },
      ),
    );
  }

  // ── Scroll to quoted message ─────────────────────────────────────────────────
  void _scrollToMessage(String targetDocId) {
    final key = _messageKeys[targetDocId];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(key!.currentContext!,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
          alignment: 0.5);
      setState(() => _highlightedDocId = targetDocId);
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) setState(() => _highlightedDocId = null);
      });
    }
  }

  // ── Bulk delete ──────────────────────────────────────────────────────────────
  void _showBulkDeleteDialog() {
    final allMsgs = _selected
        .map((id) => cubit
        .getMessagesWithIds(widget.user.uid!)
        .firstWhereOrNull((e) => e.key == id)
        ?.value)
        .whereType<MessageModel>()
        .toList();

    // If every selected message is already a deleted placeholder, skip the
    // full dialog and only offer "Remove from my chat".
    final allDeleted = allMsgs.isNotEmpty &&
        allMsgs.every((m) => m.isDeleted || m.deletedByOther == true);
    if (allDeleted) {
      final ids   = Set<String>.from(_selected);
      final count = ids.length;
      _exitSelection();
      _undoCancelled = false;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(
          duration: const Duration(seconds: 5),
          backgroundColor: AppColors.of(context).elevated,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Row(children: [
            Icon(Icons.delete_sweep_rounded, color: AppColors.of(context).textSub, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text(
              'Removed $count placeholder(s) from your chat',
              style: TextStyle(color: AppColors.of(context).textSub, fontSize: 13),
            )),
          ]),
          action: SnackBarAction(
            label: 'UNDO',
            textColor: const Color(0xFFE5C687),
            onPressed: () => _undoCancelled = true,
          ),
          onVisible: () => Future.delayed(const Duration(seconds: 5), () {
            if (_undoCancelled) return;
            cubit.bulkDeleteForMe(receiverId: widget.user.uid!, messageIds: ids);
          }),
        ));
      return;
    }

    final myIds = _selected.where((id) {
      final e = cubit.getMessagesWithIds(widget.user.uid!)
          .firstWhereOrNull((e) => e.key == id);
      return cubit.isMe(e?.value.senderId);
    }).toSet();

    final count = _selected.length;

    showModalBottomSheet(
      isScrollControlled: true,
      context: context,
      backgroundColor: AppColors.of(context).surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        _sheetHandle(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text('${AppStrings.of(context).deleteMessages} ($count)',
              style: TextStyle(
                  color: AppColors.of(context).text, fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 16),
        ListTile(
          leading: Icon(Icons.delete_outline, color: AppColors.of(context).textSub),
          title: Text(AppStrings.of(context).deleteForMeLabel, style: TextStyle(color: AppColors.of(context).textSub)),
          onTap: () {
            Navigator.pop(context);
            final ids = Set<String>.from(_selected);
            _exitSelection();
            _undoCancelled = false;
            ScaffoldMessenger.of(context)
              ..clearSnackBars()
              ..showSnackBar(SnackBar(
                duration: const Duration(seconds: 5),
                backgroundColor: AppColors.of(context).elevated,
                behavior: SnackBarBehavior.floating,
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                content: Row(children: [
                  Icon(Icons.delete_outline, color: AppColors.of(context).textSub, size: 18),
                  const SizedBox(width: 10),
                  Expanded(child: Text('${AppStrings.of(context).deletedMessages} ($count)',
                      style: TextStyle(color: AppColors.of(context).textSub, fontSize: 13))),
                ]),
                action: SnackBarAction(
                  label: 'UNDO', textColor: const Color(0xFFE5C687),
                  onPressed: () => _undoCancelled = true,
                ),
                onVisible: () => Future.delayed(const Duration(seconds: 5), () {
                  if (_undoCancelled) return;
                  cubit.bulkDeleteForMe(receiverId: widget.user.uid!, messageIds: ids);
                }),
              ));
          },
        ),
        if (myIds.isNotEmpty)
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.redAccent),
            title: Text(AppStrings.of(context).deleteForEveryoneLabel,
                style: const TextStyle(color: Colors.redAccent)),
            subtitle: Text(AppStrings.of(context).deleteForEveryoneBody,
                style: TextStyle(color: AppColors.of(context).textHint, fontSize: 11)),
            onTap: () {
              Navigator.pop(context);
              final evIds    = Set<String>.from(myIds);
              final otherIds = _selected.difference(myIds);
              _exitSelection();
              _undoCancelled = false;
              ScaffoldMessenger.of(context)
                ..clearSnackBars()
                ..showSnackBar(SnackBar(
                  duration: const Duration(seconds: 5),
                  backgroundColor: AppColors.of(context).elevated,
                  behavior: SnackBarBehavior.floating,
                  margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  content: Row(children: [
                    const Icon(Icons.delete_forever, color: Colors.redAccent, size: 18),
                    const SizedBox(width: 10),
                    Expanded(child: Text('${AppStrings.of(context).deletedMessages} ($count)',
                        style: TextStyle(color: AppColors.of(context).textSub, fontSize: 13))),
                  ]),
                  action: SnackBarAction(
                    label: 'UNDO', textColor: const Color(0xFFE5C687),
                    onPressed: () => _undoCancelled = true,
                  ),
                  onVisible: () => Future.delayed(const Duration(seconds: 5), () {
                    if (_undoCancelled) return;
                    cubit.bulkDeleteForEveryone(receiverId: widget.user.uid!, messageIds: evIds);
                    if (otherIds.isNotEmpty) {
                      cubit.bulkDeleteForMe(receiverId: widget.user.uid!, messageIds: otherIds);
                    }
                  }),
                ));
            },
          ),
        const SizedBox(height: 8),
      ])),
    );
  }


  /// Shows the full action sheet for a message — or, for an already-deleted
  /// message, a minimal sheet with just "remove from my chat".
  void _showMessageActions(MessageModel msg, String docId) {
    if (_selecting) return;
    HapticFeedback.mediumImpact();
    if (msg.isDeleted || msg.deletedByOther == true) {
      _showDeletedMsgActions(msg, docId);
      return;
    }

    showModalBottomSheet(
      isScrollControlled: true,
      context: context,
      backgroundColor: AppColors.of(context).surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _sheetHandle(),
          const SizedBox(height: 12),
          // Emoji row
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            decoration: BoxDecoration(
                color: _kSurface2, borderRadius: BorderRadius.circular(16)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: _kReactionEmojis.map((e) => _EmojiButton(
                emoji: e,
                onTap: () {
                  Navigator.pop(context);
                  cubit.toggleReaction(
                      receiverId: widget.user.uid!, messageId: docId, emoji: e);
                },
              )).toList(),
            ),
          ),
          const SizedBox(height: 10),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 6),
          // Copy text (first item in the sheet)
          if (msg.text?.isNotEmpty == true)
            _ActionTile(
              icon: Icons.copy_rounded, label: 'Copy text',
              onTap: () {
                Navigator.pop(context);
                Clipboard.setData(ClipboardData(text: msg.text!));
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(AppStrings.of(context).copiedToClipboard,
                      style: TextStyle(color: AppColors.of(context).text)),
                  backgroundColor: AppColors.of(context).elevated,
                  duration: const Duration(seconds: 2),
                ));
              },
            ),
          _ActionTile(
            icon: Icons.reply_rounded, label: AppStrings.of(context).replyLabel,
            onTap: () {
              Navigator.pop(context);
              setState(() { _replyingTo = msg; _replyingToDocId = docId; });
              _focusNode.requestFocus();
            },
          ),
          _ActionTile(
            icon: Icons.forward_rounded, label: AppStrings.of(context).forwardLabel,
            onTap: () { Navigator.pop(context); _showForwardSheet([msg]); },
          ),
          if (cubit.isMe(msg.senderId)) ...[
            _ActionTile(
              icon: Icons.edit_rounded, label: 'Edit message',
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _editingMsg  = msg;
                  _editingDocId = docId;
                  _controller.text = msg.text ?? '';
                });
                _focusNode.requestFocus();
              },
            ),
            _ActionTile(
              icon: Icons.delete_outline, label: 'Delete for me',
              onTap: () {
                Navigator.pop(context);
                _showUndoDeleteSnack(
                  msg:          msg,
                  docId:        docId,
                  forEveryone:  false,
                  label:        'Deleted for you',
                );
              },
            ),
            _ActionTile(
              icon: Icons.delete_forever, label: 'Delete for everyone',
              color: Colors.redAccent,
              onTap: () {
                Navigator.pop(context);
                _showUndoDeleteSnack(
                  msg:          msg,
                  docId:        docId,
                  forEveryone:  true,
                  label:        'Deleted for everyone',
                );
              },
            ),
          ] else
            _ActionTile(
              icon: Icons.hide_source_rounded, label: 'Delete for me',
              onTap: () {
                Navigator.pop(context);
                _showUndoDeleteSnack(
                  msg:          msg,
                  docId:        docId,
                  forEveryone:  false,
                  label:        'Deleted for you',
                );
              },
            ),
        ]),
      )),
    );
  }

  // ── Deleted message action sheet ──────────────────────────────────────────────
  // When a user long-presses (or taps the deleted bubble in selection mode),
  // they should only be able to remove the placeholder from their own chat.
  void _showDeletedMsgActions(MessageModel msg, String docId) {
    showModalBottomSheet(
      isScrollControlled: true,
      context: context,
      backgroundColor: AppColors.of(context).surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _sheetHandle(),
            const SizedBox(height: 14),
            // Descriptive label so user knows what they're deleting
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.block_rounded, color: AppColors.of(context).textHint, size: 15),
              const SizedBox(width: 6),
              Text(
                msg.isDeleted
                    ? 'This message was deleted'
                    : 'You deleted this message',
                style: TextStyle(
                    color: AppColors.of(context).textHint,
                    fontSize: 13,
                    fontStyle: FontStyle.italic),
              ),
            ]),
            const SizedBox(height: 16),
            const Divider(color: Colors.white12, height: 1),
            const SizedBox(height: 6),
            // Only option: hide this placeholder from the user's own chat
            _ActionTile(
              icon: Icons.delete_sweep_rounded,
              label: 'Remove from my chat',
              onTap: () {
                Navigator.pop(context);
                _showUndoDeleteSnack(
                  msg:         msg,
                  docId:       docId,
                  forEveryone: false,
                  label:       'Removed from your chat',
                );
              },
            ),
          ]),
        ),
      ),
    );
  }

  // ── Forward sheet ─────────────────────────────────────────────────────────────
  void _showForwardSheet(List<MessageModel> msgs) {
    showModalBottomSheet(
      isScrollControlled: true,
      context: context,
      backgroundColor: AppColors.of(context).surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        _sheetHandle(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Align(alignment: Alignment.centerLeft,
              child: Text(AppStrings.of(context).forwardTo,
                  style: TextStyle(color: AppColors.of(context).text, fontSize: 16,
                      fontWeight: FontWeight.bold))),
        ),
        SizedBox(
          height: 300,
          child: ListView.builder(
            itemCount: cubit.users.length,
            itemBuilder: (_, i) {
              final u = cubit.users[i];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.white12,
                  backgroundImage: u.image?.isNotEmpty == true
                      ? CachedNetworkImageProvider(u.image!) : null,
                  child: u.image?.isEmpty != false
                      ? Icon(Icons.person, color: AppColors.of(context).textHint) : null,
                ),
                title: Text(u.name ?? '',
                    style: TextStyle(color: AppColors.of(context).text)),
                onTap: () {
                  Navigator.pop(context);
                  for (final msg in msgs) {
                    cubit.forwardMessage(
                        targetReceiverId: u.uid!, originalMsg: msg);
                  }
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('${AppStrings.of(context).forwardedLabel}: ${u.name}',
                        style: TextStyle(color: AppColors.of(context).text)),
                    backgroundColor: AppColors.of(context).elevated,
                    duration: const Duration(seconds: 2),
                  ));
                },
              );
            },
          ),
        ),
      ])),
    );
  }

  // ── Reaction detail sheet ─────────────────────────────────────────────────────
  void _showReactionDetail(MessageModel msg) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.of(context).surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false, initialChildSize: 0.5,
        builder: (_, sc) => Column(children: [
          _sheetHandle(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Align(alignment: Alignment.centerLeft,
                child: Text(AppStrings.of(context).reactions, style: TextStyle(
                    color: AppColors.of(context).text, fontSize: 16,
                    fontWeight: FontWeight.bold))),
          ),
          Expanded(child: ListView(controller: sc,
            children: msg.reactions.entries.expand((e) {
              final emoji = e.key;
              return e.value.map((uid) {
                final isMe   = uid == cubit.currentUser?.uid;
                final name   = isMe ? 'You'
                    : (cubit.users.firstWhereOrNull((u) => u.uid == uid)?.name ?? uid);
                final image  = cubit.users.firstWhereOrNull((u) => u.uid == uid)?.image;
                return ListTile(
                  leading: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(emoji, style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 10),
                    CircleAvatar(
                      radius: 16, backgroundColor: Colors.white12,
                      backgroundImage: image?.isNotEmpty == true
                          ? CachedNetworkImageProvider(image!) : null,
                      child: image?.isEmpty != false
                          ? Icon(Icons.person, color: AppColors.of(context).textHint, size: 16) : null,
                    ),
                  ]),
                  title: Text(name,
                      style: TextStyle(color: AppColors.of(context).textSub, fontSize: 14)),
                );
              });
            }).toList(),
          )),
        ]),
      ),
    );
  }

  // ── Contact profile sheet ─────────────────────────────────────────────────────
  void _showContactProfile() {
    final live   = cubit.getLiveUser(widget.user.uid!) ?? widget.user;
    final images = cubit.getMessagesWithIds(widget.user.uid!)
        .where((e) => e.value.hasImage).toList();

    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: AppColors.of(context).surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => DraggableScrollableSheet(
        expand: false, initialChildSize: 0.75,
        builder: (_, sc) => ListView(
          controller: sc, padding: const EdgeInsets.all(20),
          children: [
            Center(child: CircleAvatar(radius: 48, backgroundColor: AppColors.of(context).elevated,
                backgroundImage: widget.user.image?.isNotEmpty == true
                    ? NetworkImage(widget.user.image!) : null,
                child: widget.user.image?.isEmpty != false
                    ? Icon(Icons.person, color: AppColors.of(context).textHint, size: 40) : null)),
            const SizedBox(height: 12),
            Center(child: Text(widget.user.name ?? '',
                style: TextStyle(color: AppColors.of(context).text, fontSize: 18,
                    fontWeight: FontWeight.w600))),
            Center(child: Text(
              live.isOnline ? AppStrings.of(context).onlineStatus
                  : (live.lastSeen != null
                  ? cubit.formatLastSeen(live.lastSeen) : AppStrings.of(context).offlineStatus),
              style: TextStyle(
                  color: live.isOnline
                      ? const Color(0xFF2EA043) : Colors.white38,
                  fontSize: 13),
            )),
            const SizedBox(height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              _ProfileActionBtn(
                icon: Icons.search_rounded, label: AppStrings.of(context).search,
                onTap: () {
                  Navigator.pop(context);
                  setState(() { _searchMode = true; _searchController.clear(); });
                },
              ),
              _ProfileActionBtn(
                icon: cubit.isMuted(widget.user.uid!)
                    ? Icons.volume_up : Icons.volume_off,
                label: cubit.isMuted(widget.user.uid!) ? AppStrings.of(context).unmute : AppStrings.of(context).muteLabel,
                onTap: () {
                  Navigator.pop(context);
                  cubit.muteConversation(
                      widget.user.uid!,
                      mute: !cubit.isMuted(widget.user.uid!));
                },
              ),
            ]),
            if (images.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(AppStrings.of(context).sharedMedia,
                  style: TextStyle(color: AppColors.of(context).textSub, fontSize: 13,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              SizedBox(height: 72, child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: images.take(6).length,
                separatorBuilder: (_, _) => const SizedBox(width: 6),
                itemBuilder: (_, i) {
                  final url = images[i].value.imageUrl!;
                  return GestureDetector(
                    onTap: () => Navigator.push(context, PageRouteBuilder(
                      opaque: false, barrierColor: Colors.black87,
                      pageBuilder: (_, _, ___) =>
                          _FullScreenImageViewer(imageUrl: url),
                    )),
                    child: ClipRRect(borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                            imageUrl: url, width: 72, height: 72, fit: BoxFit.cover)),
                  );
                },
              )),
            ],
            const SizedBox(height: 20),
            const Divider(color: Colors.white12),
            ListTile(
              leading: const Icon(Icons.block_rounded, color: Colors.redAccent),
              title: Text('${AppStrings.of(context).blockUser}: ${widget.user.name ?? ""}',
                  style: const TextStyle(color: Colors.redAccent)),
              onTap: () {
                Navigator.pop(context);
                showDialog(context: context, builder: (_) => AlertDialog(
                  backgroundColor: AppColors.of(context).surface,
                  title: Text('${AppStrings.of(context).blockConfirmTitle} ${widget.user.name}?',
                      style: TextStyle(color: AppColors.of(context).text)),
                  content: Text(AppStrings.of(context).blockConfirmBody,
                      style: TextStyle(color: AppColors.of(context).textSub)),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context),
                        child: Text(AppStrings.of(context).cancel,
                            style: TextStyle(color: AppColors.of(context).textHint))),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        cubit.blockUser(widget.user.uid!);
                        Navigator.pop(this.context);
                      },
                      child: Text(AppStrings.of(context).blockUser,
                          style: TextStyle(color: Colors.redAccent)),
                    ),
                  ],
                ));
              },
            ),
            ListTile(
              leading: const Icon(Icons.flag_rounded, color: Colors.orange),
              title: Text('${AppStrings.of(context).reportTitle}: ${widget.user.name ?? ""}',
                  style: const TextStyle(color: Colors.orange)),
              onTap: () { Navigator.pop(context); _showReportDialog(); },
            ),
          ],
        ),
      ),
    );
  }

  void _showReportDialog() {
    String reason = 'Spam';
    showDialog(context: context, builder: (_) =>
        StatefulBuilder(builder: (ctx, setSt) => AlertDialog(
          backgroundColor: AppColors.of(context).surface,
          title: Text(AppStrings.of(context).reportUserTitle, style: TextStyle(color: AppColors.of(context).text)),
          content: Column(mainAxisSize: MainAxisSize.min,
            children: ['Spam', 'Harassment', 'Inappropriate content', 'Other']
                .map((r) => RadioListTile<String>(
              value: r, groupValue: reason, activeColor: _kGold,
              title: Text(r, style: TextStyle(color: AppColors.of(context).textSub)),
              onChanged: (v) => setSt(() => reason = v!),
            )).toList(),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context),
                child: Text(AppStrings.of(context).cancel, style: TextStyle(color: AppColors.of(context).textHint))),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                cubit.reportUser(
                    targetUid: widget.user.uid!, reason: reason,
                    receiverId: widget.user.uid!);
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(AppStrings.of(context).reportSubmitted)));
              },
              child: Text(AppStrings.of(context).submitReport, style: const TextStyle(color: Colors.orange)),
            ),
          ],
        )));
  }

  // ── Disappearing messages sheet ───────────────────────────────────────────────
  void _showDisappearSheet() {
    final current = cubit.getDisappearDays(widget.user.uid!);
    showModalBottomSheet(
      isScrollControlled: true,
      context: context, backgroundColor: AppColors.of(context).surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        _sheetHandle(),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(AppStrings.of(context).disappearingMessages,
              style: TextStyle(color: AppColors.of(context).text, fontSize: 16,
                  fontWeight: FontWeight.bold)),
        ),
        ...[null, 1, 7, 90].map((d) => ListTile(
          leading: Icon(d == null ? Icons.timer_off : Icons.timer,
              color: d == current ? _kGold : Colors.white38),
          title: Text(d == null ? AppStrings.of(context).off : '$d day${d == 1 ? "" : "s"}',
              style: TextStyle(
                  color: d == current ? _kGold : Colors.white70)),
          trailing: d == current
              ? const Icon(Icons.check, color: _kGold, size: 18) : null,
          onTap: () {
            Navigator.pop(context);
            cubit.setDisappearingMessages(
                receiverId: widget.user.uid!, days: d);
          },
        )),
        const SizedBox(height: 8),
      ])),
    );
  }
}
