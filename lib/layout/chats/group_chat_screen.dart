part of 'chats_screen.dart';

class GroupChatScreen extends StatefulWidget {
  final GroupModel group;
  const GroupChatScreen({super.key, required this.group});
  @override State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  late GroupModel _group;

  @override
  void initState() {
    super.initState();
    _group = widget.group;
    final cubit = ChatCubit.get(context);
    cubit.listenGroupMessages(_group.id);
  }

  @override
  Widget build(BuildContext context) {
      final c = AppColors.of(context);
    final cubit  = ChatCubit.get(context);
    final myUid  = cubit.currentUser?.uid ?? '';
    final isAdmin = myUid == _group.adminUid;
    final canSend = isAdmin || _group.onlyAdminsCanSend != true;

    return BlocListener<ChatCubit, ChatStates>(
      listener: (context, state) {
        if (state is ChatGroupUpdatedState) {
          final fresh = cubit.groups.firstWhere((g) => g.id == _group.id, orElse: () => _group);
          setState(() => _group = fresh);
        }
        // Send/upload failures were emitted as ChatErrorState but never shown
        // anywhere — group chat looked just as "dead" as 1-to-1 chat did.
        if (state is ChatErrorState) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.red.shade700,
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: c.bg,
        appBar: AppBar(
          backgroundColor: c.surface,
          // Tapping the header opens the group's info/settings screen
          title: GestureDetector(
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => GroupInfoScreen(group: _group))),
            child: Row(children: [
              CircleAvatar(radius: 18, backgroundColor: Colors.white12,
                  backgroundImage: _group.imageUrl != null
                      ? CachedNetworkImageProvider(_group.imageUrl!) : null,
                  child: _group.imageUrl == null
                      ? Icon(Icons.group, color: AppColors.of(context).textHint) : null),
              const SizedBox(width: 10),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_group.name,
                    style: TextStyle(color: AppColors.of(context).text, fontSize: 15, fontWeight: FontWeight.w600)),
                Text(
                    _group.onlyAdminsCanSend ? '🔒 Admins only' : '${_group.memberUids.length} members',
                    style: TextStyle(color: AppColors.of(context).textHint, fontSize: 11)),
              ]),
            ]),
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.info_outline_rounded, color: AppColors.of(context).textSub),
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => GroupInfoScreen(group: _group))),
            ),
          ],
        ),
        body: BlocBuilder<ChatCubit, ChatStates>(builder: (_, _) {
          final msgs = cubit.groupMessagesWithIdsMap[_group.id] ?? [];
          return Column(children: [
            Expanded(child: ListView.builder(
              reverse: true, itemCount: msgs.length,
              itemBuilder: (_, i) {
                final msg  = msgs[i].value;
                final isMe = cubit.isMe(msg.senderId);
                final senderName = msg.senderId == 'system'
                    ? null
                    : cubit.users.firstWhere((u) => u.uid == msg.senderId,
                    orElse: () => UserModel(name: msg.senderId)).name;

                if (msg.senderId == 'system') {
                  return Center(child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                      decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(12)),
                      child: Text(msg.text ?? '', style: TextStyle(color: AppColors.of(context).textSub, fontSize: 12)),
                    ),
                  ));
                }

                return Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: EdgeInsets.only(left: isMe ? 56 : 12, right: isMe ? 12 : 56, top: 2, bottom: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                    decoration: BoxDecoration(
                      color: isMe ? kGold.withValues(alpha: 0.15) : const Color(0xFF21262D),
                      border: Border.all(color: isMe ? kGold.withValues(alpha: 0.4) : Colors.white12, width: 0.5),
                      borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(16), topRight: const Radius.circular(16),
                          bottomLeft: Radius.circular(isMe ? 16 : 4),
                          bottomRight: Radius.circular(isMe ? 4 : 16)),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      if (!isMe && senderName != null)
                        Padding(padding: const EdgeInsets.only(bottom: 3),
                            child: Text(senderName,
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                                    color: _senderColor(msg.senderId)))),
                      if (msg.hasAudio)
                        VoiceMessagePlayer(
                          audioUrl:     msg.audioUrl!,
                          durationSec:  msg.audioDuration ?? 0,
                          isMe:         isMe,
                          waveformData: msg.waveformData,
                        ),
                      if (msg.text != null && msg.text!.isNotEmpty && !msg.hasAudio)
                        Text(msg.text ?? '', style: TextStyle(color: isMe ? Colors.black87 : Colors.white, fontSize: 14.5)),
                    ]),
                  ),
                );
              },
            )),
            // Shows the input bar, or a locked banner if the group is
            // admin-only-send and this user isn't an admin
            canSend
                ? _GroupInputBar(group: _group, cubit: cubit)
                : Container(
                padding: const EdgeInsets.all(14), color: c.surface,
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.lock_outline_rounded, color: AppColors.of(context).textHint, size: 16),
                  const SizedBox(width: 8),
                  Text(AppStrings.of(context).onlyAdminsCanSend, style: TextStyle(color: AppColors.of(context).textHint, fontSize: 13)),
                ])),
          ]);
        }),
      ),
    );
  }
}

Color _senderColor(String? uid) {
  const colors = [Color(0xFF4CAF50), Color(0xFF2196F3), Color(0xFFFF9800),
    Color(0xFFE91E63), Color(0xFF9C27B0), Color(0xFF00BCD4)];
  if (uid == null) return colors[0];
  return colors[uid.hashCode.abs() % colors.length];
}

class _GroupInputBar extends StatefulWidget {
  final GroupModel group; final ChatCubit cubit;
  const _GroupInputBar({required this.group, required this.cubit});
  @override State<_GroupInputBar> createState() => _GroupInputBarState();
}
class _GroupInputBarState extends State<_GroupInputBar> {
  final _ctrl = TextEditingController();
  bool _hasText = false;
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) {
    return Container(
      color: AppColors.of(context).surface,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: SafeArea(top: false, child: Row(children: [
        Expanded(child: TextField(controller: _ctrl, style: TextStyle(color: AppColors.of(context).text),
            onChanged: (t) => setState(() => _hasText = t.trim().isNotEmpty),
            decoration: InputDecoration(hintText: 'Message…',
                hintStyle: TextStyle(color: AppColors.of(context).textHint),
                filled: true, fillColor: const Color(0xFF1C2128),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)))),
        const SizedBox(width: 8),
        // Fixed-size box keeps layout stable while the send button
        // cross-fades in — an unconstrained AnimatedSwitcher here would
        // otherwise crash on layout.
        SizedBox(
          width: 44, height: 44,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
            child: _hasText
                ? GestureDetector(
              key: const ValueKey('grp_send'),
              onTap: () {
                final text = _ctrl.text.trim();
                if (text.isEmpty) return;
                widget.cubit.sendGroupMessage(groupId: widget.group.id, text: text);
                _ctrl.clear(); setState(() => _hasText = false);
              },
              child: Container(width: 44, height: 44,
                  decoration: const BoxDecoration(shape: BoxShape.circle,
                      gradient: LinearGradient(colors: [Color(0xFFE5C687), Color(0xFFB8964A)])),
                  child: const Icon(Icons.send_rounded, color: Colors.black87, size: 20)),
            )
                : MicButton(
              key: const ValueKey('grp_mic'),
              groupId: widget.group.id,
              cubit: widget.cubit,
            ),
          ),
        ),
      ])),
    );
  }
}

