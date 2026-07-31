// lib/layout/close_friends/close_friends_screen.dart
//
// New screen — previously the Settings tile navigated to /close-friends
// but no route existed, causing a Navigator crash.
//
// Lets users toggle which of their followers / following are "Close Friends".
// Changes are written atomically to Firestore (ArrayUnion / ArrayRemove).
// Styling follows the app's existing dark theme (0xFF0D1117 / 0xFF161B22, kGold).

import 'package:cached_network_image/cached_network_image.dart';
import '../../share/style/app_colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../share/local/app_strings.dart';


import '../../layout/cubit/cubit.dart';
import '../../models/user_model.dart';
import '../../share/local/constants.dart';
import '../../share/local/skeleton_widgets.dart';

class CloseFriendsScreen extends StatefulWidget {
  const CloseFriendsScreen({super.key});

  @override
  State<CloseFriendsScreen> createState() => _CloseFriendsScreenState();
}

class _CloseFriendsScreenState extends State<CloseFriendsScreen> {
  List<UserModel> _allUsers   = [];
  Set<String>     _cfUids     = {};
  bool            _loading    = true;
  bool            _saving     = false;
  String          _query      = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final me = MainCubit.get(context).model;
    if (me == null) return;

    setState(() {
      _cfUids  = Set<String>.from(me.closeFriendsUids);
      _loading = true;
    });

    // Fetch all followers + following, deduplicated
    final combined = <String>{
      ...me.followersUids,
      ...me.followingUids,
    }..remove(me.uid ?? '');

    if (combined.isEmpty) {
      setState(() => _loading = false);
      return;
    }

    // Firestore `whereIn` supports max 30 items at a time
    final chunks = <List<String>>[];
    final list   = combined.toList();
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
        _allUsers = users;
        _loading  = false;
      });
    }
  }

  Future<void> _toggle(String uid) async {
    if (_saving) return;
    setState(() => _saving = true);

    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) { setState(() => _saving = false); return; }

    final isNow = _cfUids.contains(uid);
    final update = isNow
        ? FieldValue.arrayRemove([uid])
        : FieldValue.arrayUnion([uid]);

    try {
      await FirebaseFirestore.instance
          .collection('Users')
          .doc(myUid)
          .collection('private')
          .doc('data')
          .set({'closeFriendsUids': update}, SetOptions(merge: true));

      setState(() {
        if (isNow) {
          _cfUids.remove(uid);
        } else {
          _cfUids.add(uid);
        }
      });

      // Keep in-memory MainCubit model in sync
      if (mounted) {
        final me = MainCubit.get(context).model;
        if (me != null) {
          List<String> newList;
          if (isNow) {
            newList = [...me.closeFriendsUids];
            newList.remove(uid);
          } else {
            newList = [...me.closeFriendsUids, uid];
          }
          MainCubit.get(context).model =
              me.copyWith(closeFriendsUids: newList);
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Failed to update. Please try again.'),
          backgroundColor: Colors.redAccent,
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  List<UserModel> get _filtered {
    if (_query.trim().isEmpty) return _allUsers;
    final q = _query.trim().toLowerCase();
    return _allUsers
        .where((u) =>
            (u.name ?? '').toLowerCase().contains(q) ||
            (u.email ?? '').toLowerCase().contains(q))
        .toList();
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
        title: Text(
          AppStrings.of(context).closeFriendsTitle,
          style: TextStyle(
              color: AppColors.of(context).text, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          if (_cfUids.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: kGold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: kGold.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    '${_cfUids.length} selected',
                    style: const TextStyle(
                        color: kGold,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Info banner ───────────────────────────────────────────────
          Container(
            margin: const EdgeInsets.fromLTRB(14, 4, 14, 0),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.of(context).surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Row(
              children: [
                const Icon(Icons.star_rounded, color: kGold, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    AppStrings.of(context).closeFriendsInfo,
                    style: TextStyle(color: AppColors.of(context).textSub, fontSize: 12, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // ── Search bar ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: TextField(
              style: TextStyle(color: AppColors.of(context).text),
              decoration: InputDecoration(
                hintText: AppStrings.of(context).searchPeopleHint,
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon: const Icon(Icons.search, color: Colors.white38),
                filled: true,
                fillColor: AppColors.of(context).surface,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          const SizedBox(height: 8),

          // ── List ──────────────────────────────────────────────────────
          Expanded(
            child: RefreshIndicator(
              color: kGold,
              backgroundColor: AppColors.of(context).surface,
              onRefresh: _load,
              child: _loading
                ? ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    itemCount: 8,
                    itemBuilder: (_, _) => const _SkeletonTile(),
                  )
                : _allUsers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.people_outline,
                                color: Colors.white24, size: 56),
                            const SizedBox(height: 12),
                            Text(
                              'No followers or following yet.\nFollow people to add them here.',
                              textAlign: TextAlign.center,
                              style:
                                  TextStyle(color: AppColors.of(context).textHint, fontSize: 14),
                            ),
                          ],
                        ),
                      )
                    : _filtered.isEmpty
                        ? Center(
                            child: Text(AppStrings.of(context).noResults,
                                style: TextStyle(color: AppColors.of(context).textHint)),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(14, 4, 14, 20),
                            itemCount: _filtered.length,
                            itemBuilder: (context, i) {
                              final user     = _filtered[i];
                              final isCF     = _cfUids.contains(user.uid ?? '');
                              return _UserTile(
                                user:       user,
                                isCF:       isCF,
                                onTap:      () => _toggle(user.uid ?? ''),
                              );
                            },
                          ),
            ), // RefreshIndicator
          ),
        ],
      ),
    );
  }
}

// ── Tile ──────────────────────────────────────────────────────────────────────
class _UserTile extends StatelessWidget {
  final UserModel user;
  final bool      isCF;
  final VoidCallback onTap;

  const _UserTile({
    required this.user,
    required this.isCF,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isCF
              ? kGold.withValues(alpha: 0.07)
              : AppColors.of(context).surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isCF
                ? kGold.withValues(alpha: 0.35)
                : Colors.white.withValues(alpha: 0.05),
          ),
        ),
        child: Row(
          children: [
            // Avatar
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
            // Name + email
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
            // Check indicator
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCF ? kGold : Colors.white.withValues(alpha: 0.06),
                border: Border.all(
                  color: isCF ? kGold : Colors.white24,
                  width: 1.5,
                ),
              ),
              child: isCF
                  ? const Icon(Icons.star_rounded,
                      color: Colors.black, size: 16)
                  : const Icon(Icons.star_border_rounded,
                      color: Colors.white38, size: 16),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Skeleton tile while loading ───────────────────────────────────────────────
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
        children: [
          const SkeletonBox(width: 44, height: 44, radius: 22),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              SkeletonBox(width: 120, height: 13, radius: 6),
              SizedBox(height: 6),
              SkeletonBox(width: 80, height: 11, radius: 5),
            ],
          ),
        ],
      ),
    );
  }
}
