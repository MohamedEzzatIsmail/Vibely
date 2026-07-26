// lib/layout/chats/chats_screen.dart
// Prompt 15 — archive, Prompt 16 — unread filter, Prompt 24 — real-time groups

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../share/local/app_strings.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../layout/chats/chat.dart';
import '../../layout/chats/group_info_screen.dart';
import '../../layout/cubit/chat/chat_cubit.dart';
import '../../layout/cubit/chat/chat_states.dart';
import '../../models/user_model.dart';
import '../../share/local/constants.dart';
import '../../share/style/app_colors.dart';
import 'voice_recorder_button.dart';
import 'voice_message_player.dart';

part 'groups_tab_widgets.dart';
part 'group_chat_screen.dart';
part 'chat_sheets_widgets.dart';

class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key});
  @override State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  // FIX: _showOnlyUnread lives HERE (parent State), not inside _ChatsTab.
  // When it was in _ChatsTabState, every cubit emit rebuilt BlocBuilder which
  // recreated _ChatsTabState and reset the bool to false — trapping the user.
  bool _showOnlyUnread = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    Future.microtask(() => _init(context));
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  Future<void> _init(BuildContext ctx) async {
    final fbUser = FirebaseAuth.instance.currentUser;
    if (fbUser == null) return;
    final doc = await FirebaseFirestore.instance.collection('Users').doc(fbUser.uid).get();
    if (!doc.exists || !ctx.mounted) return;
    final cubit = ChatCubit.get(ctx);
    cubit.setCurrentUser(UserModel.fromJson(doc.data()!));
    cubit.setContext(ctx);
    // Prompt 24 — real-time group listener
    await cubit.loadUsers();
    cubit.listenGroups();
  }

  Future<void> _onRefresh() => ChatCubit.get(context).loadUsers(forceRefresh: true);

  void _openNewChat() => showModalBottomSheet(
    context: context, isScrollControlled: true,
    backgroundColor: AppColors.of(context).surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => _NewChatSheet(cubit: ChatCubit.get(context)),
  );

  void _openCreateGroup() => showModalBottomSheet(
    context: context, isScrollControlled: true,
    backgroundColor: AppColors.of(context).surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => _CreateGroupSheet(cubit: ChatCubit.get(context)),
  );

  @override
  Widget build(BuildContext context) {
      final c = AppColors.of(context);
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg, elevation: 0,
        title: Text(AppStrings.of(context).messagesTitle,
            style: TextStyle(color: AppColors.of(context).text, fontSize: 18, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: Icon(Icons.search, color: AppColors.of(context).textSub),
            onPressed: () => Navigator.pushNamed(context, '/search'),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: kGold, labelColor: kGold, unselectedLabelColor: AppColors.of(context).textHint,
          tabs: [Tab(text: AppStrings.of(context).chats), Tab(text: AppStrings.of(context).createGroup.replaceFirst('Create ', ''))],
        ),
      ),
      body: TabBarView(controller: _tabs, children: [
        _ChatsTab(
          onRefresh: _onRefresh,
          showOnlyUnread: _showOnlyUnread,
          onFilterChanged: (v) => setState(() => _showOnlyUnread = v),
        ),
        _GroupsTab(onCreateGroup: _openCreateGroup),
      ]),
      // Moved from an AppBar icon to a floating action button, matching the
      // gold circular "create post" FAB on the feed screen.
      floatingActionButton: AnimatedBuilder(
        animation: _tabs,
        builder: (context, _) {
          if (_tabs.index != 0) return const SizedBox.shrink();
          return Tooltip(
            message: 'New conversation',
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: kGold.withValues(alpha: 0.15),
                    blurRadius: 22,
                    spreadRadius: 2,
                    offset: const Offset(0, 6),
                  ),
                  BoxShadow(
                    color: kGold.withValues(alpha: 0.15),
                    blurRadius: 35,
                    spreadRadius: 6,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: FloatingActionButton(
                heroTag: 'chats-new-conversation-fab',
                elevation: 0,
                backgroundColor: kGold,
                foregroundColor: Colors.black,
                shape: const CircleBorder(),
                onPressed: _openNewChat,
                child: const Icon(Icons.edit_square, size: 26),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  CHATS TAB — Prompt 15 (archive) + Prompt 16 (unread filter)
// ══════════════════════════════════════════════════════════════════════════════
class _ChatsTab extends StatelessWidget {
  final Future<void> Function() onRefresh;
  final bool showOnlyUnread;
  final ValueChanged<bool> onFilterChanged;
  const _ChatsTab({
    required this.onRefresh,
    required this.showOnlyUnread,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
      final c = AppColors.of(context);
    return BlocBuilder<ChatCubit, ChatStates>(
      buildWhen: (_, s) =>
      s is ChatUsersLoadedState || s is ChatUnreadUpdatedState ||
          s is ChatMessagesUpdatedState || s is ChatInitialState ||
          s is ChatArchivedState || s is ChatConversationPinnedState ||
          s is ChatConversationDeletedState,
      builder: (context, state) {
        final cubit = ChatCubit.get(context);

        if (state is ChatInitialState) {
          return ListView.builder(
              itemCount: 6,
              itemBuilder: (_, _) => const _ChatTileSkeleton());
        }

        final activeUsers   = cubit.users.where((u) => !cubit.isArchived(u.uid!)).toList();
        final archivedUsers = cubit.users.where((u) =>  cubit.isArchived(u.uid!)).toList();
        final unreadCount   = activeUsers
            .where((u) => cubit.getUnreadCount(u.uid!) > 0).length;

        final displayUsers = showOnlyUnread
            ? activeUsers.where((u) => cubit.getUnreadCount(u.uid!) > 0).toList()
            : activeUsers;

        return RefreshIndicator(
          onRefresh: onRefresh,
          color: kGold,
          backgroundColor: c.surface,
          // FIX: chips are ALWAYS rendered — they no longer live inside
          // the displayUsers.isEmpty branch that caused them to vanish
          // when the "Unread" filter returned 0 results.
          child: ListView(children: [
            // ── Filter chips — always shown once chats exist ──────────
            if (activeUsers.isNotEmpty || archivedUsers.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
                child: Wrap(spacing: 8, children: [
                  _FilterChip(
                    label: 'All',
                    selected: !showOnlyUnread,
                    onTap: () => onFilterChanged(false),
                  ),
                  _FilterChip(
                    label: 'Unread ($unreadCount)',
                    selected: showOnlyUnread,
                    onTap: () => onFilterChanged(true),
                  ),
                ]),
              ),

            // ── Empty state: no chats at all ──────────────────────────
            if (activeUsers.isEmpty && archivedUsers.isEmpty) ...[
              const SizedBox(height: 120),
              const _EmptyChatsWidget(),
            ],

            // ── Empty state: unread filter but no unread chats ────────
            if ((activeUsers.isNotEmpty || archivedUsers.isNotEmpty) &&
                showOnlyUnread && displayUsers.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 60),
                child: Center(
                  child: Text(AppStrings.of(context).noUnreadMessages,
                      style: TextStyle(
                          color: AppColors.of(context).textHint, fontSize: 14)),
                ),
              ),

            // ── Active chats ──────────────────────────────────────────
            ...displayUsers.asMap().entries.map((e) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ChatTile(user: e.value, cubit: cubit),
                if (e.key < displayUsers.length - 1)
                  const Divider(
                      height: 1,
                      color: Colors.white12,
                      indent: 74),
              ],
            )),
            // ── Archived section ──────────────────────────────────────
            if (archivedUsers.isNotEmpty) ...[
              const SizedBox(height: 8),
              ExpansionTile(
                backgroundColor: c.surface,
                collapsedBackgroundColor: c.surface,
                iconColor: Colors.white38,
                collapsedIconColor: Colors.white38,
                leading: Icon(Icons.archive_outlined,
                    color: AppColors.of(context).textHint, size: 20),
                title: Text(
                    'Archived (${archivedUsers.length})',
                    style: TextStyle(
                        color: AppColors.of(context).textSub, fontSize: 14)),
                children: archivedUsers
                    .map((u) => _ChatTile(user: u, cubit: cubit))
                    .toList(),
              ),
            ],
            const SizedBox(height: 20),
          ]),
        );
      },
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String   label;
  final bool     selected;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          // Selected: solid gold fill; Unselected: surface color (theme-aware)
          color: selected ? kGold : c.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? kGold : c.border,
            width: 1.5,
          ),
        ),
        child: Text(label, style: TextStyle(
            color: selected ? Colors.black87 : c.textSub,
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.normal)),
      ),
    );
  }
}
