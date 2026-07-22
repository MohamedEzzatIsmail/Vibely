part of 'chats_screen.dart';

class _GroupsTab extends StatelessWidget {
  final VoidCallback onCreateGroup;
  const _GroupsTab({required this.onCreateGroup});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChatCubit, ChatStates>(builder: (context, state) {
      final cubit = ChatCubit.get(context);
      return Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.group_add, color: kGold),
                label: Text(AppStrings.of(context).createGroup, style: TextStyle(color: kGold)),
                style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: kGold, width: 1),
                    padding: const EdgeInsets.symmetric(vertical: 12)),
                onPressed: onCreateGroup,
              )),
        ),
        Expanded(child: cubit.groups.isEmpty
            ? Center(child: Text(AppStrings.of(context).noGroupsYet, style: TextStyle(color: AppColors.of(context).textHint)))
            : ListView.separated(
          itemCount: cubit.groups.length,
          separatorBuilder: (_, _) => const Divider(height: 1, color: Colors.white12, indent: 58),
          itemBuilder: (_, i) {
            final g = cubit.groups[i];
            return ListTile(
              leading: CircleAvatar(
                radius: 22, backgroundColor: Colors.white12,
                backgroundImage: g.imageUrl != null ? CachedNetworkImageProvider(g.imageUrl!) : null,
                child: g.imageUrl == null ? Icon(Icons.group, color: AppColors.of(context).textHint) : null,
              ),
              title: Text(g.name, style: TextStyle(color: AppColors.of(context).text, fontSize: 15)),
              subtitle: Text(
                  g.onlyAdminsCanSend ? '🔒 Only admins can send' : '${g.memberUids.length} members',
                  style: TextStyle(color: AppColors.of(context).textHint, fontSize: 12)),
              onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => GroupChatScreen(group: g))),
              trailing: IconButton(
                icon: Icon(Icons.info_outline_rounded, color: AppColors.of(context).textHint, size: 18),
                onPressed: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => GroupInfoScreen(group: g))),
              ),
            );
          },
        )),
      ]);
    });
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  CHAT TILE with Prompt 15 archive + existing mute/pin/delete
// ══════════════════════════════════════════════════════════════════════════════
class _ChatTile extends StatelessWidget {
  final UserModel user;
  final ChatCubit cubit;
  const _ChatTile({required this.user, required this.cubit});

  void _showOptions(BuildContext context) {
    final isPinned   = cubit.isPinned(user.uid!);
    final isMuted    = cubit.isMuted(user.uid!);
    final isArchived = cubit.isArchived(user.uid!);

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.of(context).surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(margin: const EdgeInsets.only(top: 8, bottom: 4), width: 36, height: 4,
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
        ListTile(
          leading: Icon(isPinned ? Icons.push_pin : Icons.push_pin_outlined, color: AppColors.of(context).textSub),
          title: Text(isPinned ? 'Unpin chat' : 'Pin chat', style: TextStyle(color: AppColors.of(context).textSub)),
          onTap: () { Navigator.pop(context); cubit.pinConversation(user.uid!, pin: !isPinned); },
        ),
        ListTile(
          leading: Icon(isMuted ? Icons.volume_up : Icons.volume_off, color: AppColors.of(context).textSub),
          title: Text(isMuted ? 'Unmute' : 'Mute', style: TextStyle(color: AppColors.of(context).textSub)),
          onTap: () { Navigator.pop(context); cubit.muteConversation(user.uid!, mute: !isMuted); },
        ),
        ListTile(
          leading: Icon(isArchived ? Icons.unarchive_rounded : Icons.archive_outlined, color: AppColors.of(context).textSub),
          title: Text(isArchived ? 'Unarchive' : 'Archive', style: TextStyle(color: AppColors.of(context).textSub)),
          onTap: () { Navigator.pop(context); cubit.archiveConversation(user.uid!, archive: !isArchived); },
        ),
        ListTile(
          leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
          title: Text(AppStrings.of(context).deleteConversationLabel, style: const TextStyle(color: Colors.redAccent)),
          onTap: () { Navigator.pop(context); _confirmDelete(context); },
        ),
        const SizedBox(height: 8),
      ])),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: AppColors.of(context).surface,
      title: Text(AppStrings.of(context).deleteConversationTitle, style: TextStyle(color: AppColors.of(context).text)),
      content: Text(AppStrings.of(context).deleteConversationBody,
          style: TextStyle(color: AppColors.of(context).textSub)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context),
            child: Text(AppStrings.of(context).cancel, style: TextStyle(color: AppColors.of(context).textHint))),
        TextButton(onPressed: () { Navigator.pop(context); cubit.deleteConversation(user.uid!); },
            child: Text(AppStrings.of(context).delete, style: const TextStyle(color: Colors.redAccent))),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
      final c = AppColors.of(context);
    final lastMsg  = cubit.getLastMessage(user.uid!);
    final lastTime = cubit.getLastMessageTime(user.uid!);
    final unread   = cubit.getUnreadCount(user.uid!);
    final isMe     = cubit.isMeLastSender(user.uid!);
    final isPinned = cubit.isPinned(user.uid!);
    final isMuted  = cubit.isMuted(user.uid!);
    final live     = cubit.getLiveUser(user.uid!) ?? user;
    final online   = live.isOnline;
    final lastSeen = live.lastSeen;

    return GestureDetector(
      onLongPress: () => _showOptions(context),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => ChatScreen(user: user))),
        leading: Stack(children: [
          CircleAvatar(
            radius: 24, backgroundColor: Colors.white12,
            backgroundImage: user.image?.isNotEmpty == true
                ? CachedNetworkImageProvider(user.image!) : null,
            child: user.image?.isEmpty != false
                ? Icon(Icons.person, color: AppColors.of(context).textHint) : null,
          ),
          if (online) Positioned(bottom: 0, right: 0,
              child: Container(width: 11, height: 11,
                  decoration: BoxDecoration(color: Colors.green, shape: BoxShape.circle,
                      border: Border.all(color: c.bg, width: 2)))),
        ]),
        title: Row(children: [
          if (isPinned) const Padding(padding: EdgeInsets.only(right: 4),
              child: Icon(Icons.push_pin, color: kGold, size: 12)),
          Expanded(child: Text(user.name ?? '',
              style: TextStyle(color: AppColors.of(context).text,
                  fontWeight: unread > 0 ? FontWeight.w700 : FontWeight.w500, fontSize: 15),
              overflow: TextOverflow.ellipsis)),
          if (user.isVerified == true) ...[
            const SizedBox(width: 3), const Icon(Icons.verified, color: kGold, size: 13),
          ],
          if (isMuted) ...[
            const SizedBox(width: 4), const Icon(Icons.volume_off, color: Colors.white24, size: 12),
          ],
        ]),
        subtitle: Row(children: [
          if (isMe) Icon(Icons.done, color: AppColors.of(context).textHint, size: 13),
          Expanded(child: Text(
              lastMsg.isEmpty ? (online ? 'Online'
                  : lastSeen != null ? cubit.formatLastSeen(lastSeen) : 'Start chatting')
                  : lastMsg,
              style: TextStyle(color: unread > 0 ? Colors.white70 : Colors.white38, fontSize: 13,
                  fontWeight: unread > 0 ? FontWeight.w500 : FontWeight.normal),
              overflow: TextOverflow.ellipsis, maxLines: 1)),
        ]),
        trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(lastTime, style: TextStyle(color: unread > 0 ? kGold : Colors.white38, fontSize: 11)),
          const SizedBox(height: 4),
          if (unread > 0) Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                  color: isMuted ? Colors.grey : Colors.red, borderRadius: BorderRadius.circular(10)),
              child: Text(unread > 99 ? '99+' : '$unread',
                  style: TextStyle(color: AppColors.of(context).text, fontSize: 11, fontWeight: FontWeight.bold))),
        ]),
      ),
    );
  }
}

