// lib/layout/blocked_users/blocked_users_screen.dart
//
// New screen — the Settings › Privacy section navigated to /blocked-users
// but no route existed. This screen shows a list of blocked users and lets
// the user unblock them with a swipe or button.
// Styling follows the app's dark theme (0xFF0D1117 / 0xFF161B22, kGold).

import 'package:cached_network_image/cached_network_image.dart';
import '../../share/style/app_colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../share/local/app_strings.dart';

import 'package:flutter/services.dart';

import '../../layout/cubit/chat/chat_cubit.dart';
import '../../layout/cubit/cubit.dart';
import '../../models/user_model.dart';
import '../../share/local/constants.dart';
import '../../share/local/skeleton_widgets.dart';

class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  List<UserModel> _blocked = [];
  bool            _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final me = MainCubit.get(context).model;
    if (me == null || me.blockedUids.isEmpty) {
      setState(() => _loading = false);
      return;
    }

    // Firestore whereIn max 30
    final chunks = <List<String>>[];
    final list   = me.blockedUids;
    for (var i = 0; i < list.length; i += 30) {
      chunks.add(list.sublist(i, i + 30 > list.length ? list.length : i + 30));
    }

    final users = <UserModel>[];
    for (final chunk in chunks) {
      final snap = await FirebaseFirestore.instance
          .collection('Users')
          .where('uid', whereIn: chunk)
          .get();
      users.addAll(snap.docs.map((d) => UserModel.fromJson(d.data())));
    }

    if (mounted) {
      setState(() {
        _blocked = users;
        _loading = false;
      });
    }
  }

  Future<void> _unblock(UserModel user) async {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) return;

    HapticFeedback.lightImpact();

    try {
      await ChatCubit.get(context).unblockUser(user.uid!);

      setState(() => _blocked.removeWhere((u) => u.uid == user.uid));

      // Keep MainCubit model in sync
      if (mounted) {
        final me = MainCubit.get(context).model;
        if (me != null) {
          final newList = [...me.blockedUids]..remove(user.uid);
          MainCubit.get(context).model = me.copyWith(blockedUids: newList);
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${user.name ?? ''} ${AppStrings.of(context).userUnblocked}'),
            backgroundColor: const Color(0xFF2e7d32),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.of(context).unblockFailed),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _confirmUnblock(UserModel user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.of(context).surface,
        title: Text(AppStrings.of(context).unblockConfirmTitle,
            style: TextStyle(color: AppColors.of(context).text)),
        content: Text(
          '${user.name ?? 'This user'} will be able to see your posts and follow you again.',
          style: TextStyle(color: AppColors.of(context).textSub),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppStrings.of(context).cancel, style: TextStyle(color: AppColors.of(context).textSub)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppStrings.of(context).unblock,
                style: TextStyle(color: kGold, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirmed == true) _unblock(user);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.of(context).bg,
      appBar: AppBar(
        backgroundColor: AppColors.of(context).bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios,
              color: AppColors.of(context).isDark ? Colors.white70 : const Color(0xFFe5c687)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(AppStrings.of(context).blockedAccountsTitle,
            style: TextStyle(
                color: AppColors.of(context).text,
                fontWeight: FontWeight.bold,
                fontSize: 18)),
        actions: [
          if (_blocked.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Text(
                  '${_blocked.length}',
                  style: TextStyle(
                      color: AppColors.of(context).textHint,
                      fontSize: 14),
                ),
              ),
            ),
        ],
      ),
      body: _loading
          ? ListView.builder(
              padding: const EdgeInsets.all(14),
              itemCount: 6,
              itemBuilder: (_, _) => const _SkeletonTile(),
            )
          : _blocked.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.block_rounded,
                          color: Colors.white12, size: 64),
                      const SizedBox(height: 16),
                      Text(
                        AppStrings.of(context).noBlockedAccounts,
                        style: TextStyle(
                            color: AppColors.of(context).textSub,
                            fontSize: 16,
                            fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'People you block won\'t be able to find\nyour profile or see your posts.',
                        textAlign: TextAlign.center,
                        style:
                            TextStyle(color: AppColors.of(context).textHint, fontSize: 13),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Info hint
                    Container(
                      margin: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.of(context).surface,
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: Colors.white.withValues(alpha: 0.06)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline,
                              color: Colors.white38, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              AppStrings.of(context).swipeToUnblock,
                              style: TextStyle(
                                  color: AppColors.of(context).textHint,
                                  fontSize: 12,
                                  height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 20),
                        itemCount: _blocked.length,
                        itemBuilder: (context, i) {
                          final user = _blocked[i];
                          return Dismissible(
                            key: Key(user.uid ?? i.toString()),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              margin:
                                  const EdgeInsets.symmetric(vertical: 5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2e7d32),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.lock_open,
                                      color: Colors.white, size: 22),
                                  const SizedBox(height: 2),
                                  Text(AppStrings.of(context).unblock,
                                      style: TextStyle(
                                          color: AppColors.of(context).text,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                            confirmDismiss: (_) async {
                              await _confirmUnblock(user);
                              return false; // we handle removal ourselves
                            },
                            child: _BlockedUserTile(
                              user:     user,
                              onUnblock: () => _confirmUnblock(user),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _BlockedUserTile extends StatelessWidget {
  final UserModel    user;
  final VoidCallback onUnblock;

  const _BlockedUserTile({required this.user, required this.onUnblock});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.of(context).surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: Colors.white10,
            backgroundImage: (user.image != null && user.image!.isNotEmpty)
                ? CachedNetworkImageProvider(user.image!)
                : null,
            child: (user.image == null || user.image!.isEmpty)
                ? const Icon(Icons.person, color: Colors.white38, size: 20)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name ?? '',
                  style: TextStyle(
                      color: AppColors.of(context).text,
                      fontWeight: FontWeight.w600,
                      fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
                if (user.email != null && user.email!.isNotEmpty)
                  Text(
                    user.email!,
                    style: TextStyle(
                        color: AppColors.of(context).textHint, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          TextButton(
            onPressed: onUnblock,
            style: TextButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.05),
              foregroundColor: Colors.white70,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(AppStrings.of(context).unblock,
                style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _SkeletonTile extends StatelessWidget {
  const _SkeletonTile();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.of(context).surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: const [
          SkeletonBox(width: 44, height: 44, radius: 22),
          SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SkeletonBox(width: 120, height: 13, radius: 6),
            SizedBox(height: 6),
            SkeletonBox(width: 80, height: 11, radius: 5),
          ]),
        ],
      ),
    );
  }
}
