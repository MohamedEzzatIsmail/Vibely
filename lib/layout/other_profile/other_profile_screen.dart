import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../share/local/app_strings.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../models/notification_model.dart';
import '../../models/post_model.dart';
import '../../models/user_model.dart';
import '../cubit/cubit.dart';
import '../cubit/post/post_cubit.dart';
import '../feeds/post_details_screen.dart';
import '../report/report_sheet.dart';
import '../../share/style/app_colors.dart';
import '../chats/chat.dart';
import '../cubit/chat/chat_cubit.dart';
import '../../share/network/notification_router.dart';

class OtherProfileScreen extends StatefulWidget {
  final UserModel user;
  const OtherProfileScreen({super.key, required this.user});
  @override
  State<OtherProfileScreen> createState() => _OtherProfileScreenState();
}

class _OtherProfileScreenState extends State<OtherProfileScreen>
    with SingleTickerProviderStateMixin {
  late UserModel _user;
  List<PostModel> _posts = [];
  bool _loadingProfile   = true;
  bool _loadingPosts     = true;
  bool _followLoading    = false;
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _user = widget.user;
    _tabs = TabController(length: 1, vsync: this);
    // Real-time stream for this user's document
    FirebaseFirestore.instance
        .collection('Users')
        .doc(_user.uid)
        .snapshots()
        .listen((snap) {
      if (!snap.exists || snap.data() == null) {
        if (mounted) setState(() => _loadingProfile = false);
        return;
      }
      if (mounted) setState(() {
        _user           = UserModel.fromJson(snap.data()!);
        _loadingProfile = false;
      });
    }, onError: (_) {
      if (mounted) setState(() => _loadingProfile = false);
    });
    _loadPosts();
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  Future<void> _loadPosts() async {
    try {
      final myUid       = MainCubit.get(context).model?.uid ?? '';
      final isFollowing = _user.isFollowedBy(myUid);
      final filter      = (isFollowing || myUid == _user.uid)
          ? ['public', 'followers'] : ['public'];

      final snap = await FirebaseFirestore.instance
          .collection('Posts')
          .where('uid', isEqualTo: _user.uid)
          .where('privacy', whereIn: filter)
          .orderBy('dateTime', descending: true)
          .get();

      if (mounted) setState(() {
        _posts       = snap.docs.map((d) => PostModel.fromJson(d.data())).toList();
        _loadingPosts = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingPosts = false);
    }
  }

  Future<void> _toggleFollow() async {
    final me = MainCubit.get(context).model;
    if (me?.uid == null || _user.uid == null || _followLoading) return;
    setState(() => _followLoading = true);
    HapticFeedback.lightImpact();

    final myUid = me!.uid!;
    final theirUid = _user.uid!;
    final wasFollowing = _user.isFollowedBy(myUid);

    try {
      final batch    = FirebaseFirestore.instance.batch();
      final myRef    = FirebaseFirestore.instance.collection('Users').doc(myUid);
      final theirRef = FirebaseFirestore.instance.collection('Users').doc(theirUid);

      if (wasFollowing) {
        batch.update(myRef,    {'followingUids': FieldValue.arrayRemove([theirUid])});
        batch.update(theirRef, {'followersUids': FieldValue.arrayRemove([myUid])});
        me.followingUids.remove(theirUid);
      } else {
        batch.update(myRef,    {'followingUids': FieldValue.arrayUnion([theirUid])});
        batch.update(theirRef, {'followersUids': FieldValue.arrayUnion([myUid])});
        me.followingUids.add(theirUid);
        try {
          await PostsCubit.get(context).sendNotification(
              toUserId: theirUid, type: NotificationType.follow);
        } catch (_) {}
      }
      await batch.commit();
      _loadPosts(); // reload posts with new privacy level
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _followLoading = false);
    }
  }

  Future<void> _blockUser() async {
    final me = MainCubit.get(context).model;
    if (me == null || _user.uid == null) return;
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      backgroundColor: const Color(0xFF21262d),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(AppStrings.of(context).blockUserQuestion, style: TextStyle(color: AppColors.of(context).text)),
      content: Text(AppStrings.of(context).blockUserBody,
          style: const TextStyle(color: Colors.grey, height: 1.5)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false),
            child: Text(AppStrings.of(context).cancel, style: TextStyle(color: Colors.grey))),
        TextButton(onPressed: () => Navigator.pop(context, true),
            child: Text(AppStrings.of(context).blockUser, style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
      ],
    ));
    if (ok != true || !mounted) return;
    await ChatCubit.get(context).blockUser(_user.uid!);
    me.blockedUids.add(_user.uid!);
    if (mounted) { Navigator.pop(context); }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingProfile) {
      return Scaffold(
        backgroundColor: AppColors.of(context).bg,
        body: Center(child: const CircularProgressIndicator(color: Color(0xFFe5c687))),
      );
    }
    final myUid       = MainCubit.get(context).model?.uid ?? '';
    final isFollowing = _user.isFollowedBy(myUid);
    final isPrivate   = _user.isPrivateAccount && !isFollowing && _user.uid != myUid;

    return Scaffold(
      backgroundColor: AppColors.of(context).bg,
      body: NestedScrollView(
        headerSliverBuilder: (_, _) => [
          SliverAppBar(
            backgroundColor: AppColors.of(context).bg,
            foregroundColor: AppColors.of(context).isDark ? Colors.white : const Color(0xFFe5c687),
            pinned: true,
            title: Row(children: [
              Flexible(child: Text(_user.name ?? '',
                  style: TextStyle(color: AppColors.of(context).text, fontSize: 16, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis)),
              if (_user.isVerified == true) ...[
                const SizedBox(width: 4),
                const Icon(Icons.verified_rounded, color: Color(0xFFe5c687), size: 15),
              ],
              if (_user.isOnline) ...[
                const SizedBox(width: 8),
                Container(width: 8, height: 8,
                    decoration: const BoxDecoration(color: Color(0xFF3fb950), shape: BoxShape.circle)),
              ],
            ]),
            actions: [
              PopupMenuButton<String>(
                icon: Icon(Icons.more_horiz_rounded, color: AppColors.of(context).text),
                color: const Color(0xFF21262d),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onSelected: (v) {
                  if (v == 'report') ReportSheet.show(context, targetUid: _user.uid!, targetType: 'user');
                  if (v == 'block')  _blockUser();
                  if (v == 'copy') {
                    Clipboard.setData(ClipboardData(text: 'https://vibely.app/user/${_user.uid}'));
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(AppStrings.of(context).profileLinkCopied)));
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'copy', child: Row(children: [
                    const Icon(Icons.link_rounded, color: Colors.grey, size: 18), const SizedBox(width: 10),
                    Text(AppStrings.of(context).copyLink, style: TextStyle(color: AppColors.of(context).text, fontSize: 14))])),
                  PopupMenuItem(value: 'report', child: Row(children: [
                    const Icon(Icons.flag_outlined, color: Colors.orange, size: 18), const SizedBox(width: 10),
                    Text(AppStrings.of(context).reportTitle, style: TextStyle(color: AppColors.of(context).text, fontSize: 14))])),
                  PopupMenuItem(value: 'block', child: Row(children: [
                    const Icon(Icons.block_rounded, color: Colors.red, size: 18), const SizedBox(width: 10),
                    Text(AppStrings.of(context).blockUser, style: const TextStyle(color: Colors.red, fontSize: 14))])),
                ],
              ),
            ],
          ),
          SliverToBoxAdapter(child: Directionality(
            textDirection: TextDirection.ltr,
            child: _Header(
              user: _user, posts: _posts,
              isFollowing: isFollowing, followLoading: _followLoading,
              onFollowTap: _toggleFollow, myUid: myUid,
            ),
          )),
        ],
        body: isPrivate
            ? _PrivateLock(name: _user.name ?? '')
            : _loadingPosts
            ? const Center(child: CircularProgressIndicator(color: Color(0xFFe5c687), strokeWidth: 2))
            : _posts.isEmpty
            ? _EmptyPosts(name: _user.name ?? '')
            : _PostsGrid(posts: _posts),
      ),
    );
  }
}

// ─── Header ───────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final UserModel user; final List<PostModel> posts;
  final bool isFollowing; final bool followLoading;
  final VoidCallback onFollowTap; final String myUid;
  const _Header({required this.user,required this.posts,required this.isFollowing,
    required this.followLoading,required this.onFollowTap,required this.myUid});

  String _fmt(int n) {
    if (n >= 1000000) return '${(n/1000000).toStringAsFixed(1)}M';
    if (n >= 1000)    return '${(n/1000).toStringAsFixed(1)}K';
    return '$n';
  }

  @override
  Widget build(BuildContext context) => Container(
    color: AppColors.of(context).bg,
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        // Avatar
        Container(
          decoration: BoxDecoration(shape: BoxShape.circle,
              gradient: const LinearGradient(colors: [Color(0xFFe5c687), Color(0xFF9b692a)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight)),
          padding: const EdgeInsets.all(2.5),
          child: Container(decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.of(context).bg), padding: EdgeInsets.all(2),
              child: CircleAvatar(radius: 40, backgroundColor: const Color(0xFF21262d),
                backgroundImage: (user.image ?? '').isNotEmpty ? CachedNetworkImageProvider(user.image!) : null,
                child: (user.image ?? '').isEmpty ? Text((user.name ?? '?')[0].toUpperCase(),
                    style: TextStyle(color: AppColors.of(context).text, fontSize: 28, fontWeight: FontWeight.bold)) : null,
              )),
        ),
        const SizedBox(width: 20),
        Expanded(child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          _Stat(label: AppStrings.of(context).posts, value: '${posts.length}'),
          GestureDetector(
              onTap: () => _showList(context, isFollowers: true),
              child: _Stat(label: AppStrings.of(context).followers, value: _fmt(user.followersCount))),
          GestureDetector(
              onTap: () => _showList(context, isFollowers: false),
              child: _Stat(label: AppStrings.of(context).following, value: _fmt(user.followingCount))),
        ])),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        Text(user.name ?? '', style: TextStyle(color: AppColors.of(context).text, fontSize: 15, fontWeight: FontWeight.w700)),
        if (user.isVerified == true) ...[const SizedBox(width: 4), const Icon(Icons.verified_rounded, color: Color(0xFFe5c687), size: 15)],
      ]),
      if ((user.bio ?? '').isNotEmpty) ...[
        const SizedBox(height: 4),
        Text(user.bio!, style: const TextStyle(color: Color(0xFFE6EDF3), fontSize: 14, height: 1.4)),
      ],
      const SizedBox(height: 14),
      if (user.uid != myUid)
        Row(children: [
          Expanded(child: _FollowBtn(isFollowing: isFollowing, loading: followLoading, onTap: onFollowTap)),
          const SizedBox(width: 8),
          Expanded(child: OutlinedButton(
            style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF30363d)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 10)),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(user: user))),
            child: Text(AppStrings.of(context).messageLabel, style: TextStyle(color: AppColors.of(context).text, fontWeight: FontWeight.w600, fontSize: 14)),
          )),
        ]),
      const SizedBox(height: 14),
      const Divider(color: Color(0xFF21262d), height: 1, thickness: 0.5),
      TabBar(
        controller: TabController(length: 1, vsync: _FakeVsync()),
        labelColor: Colors.white, unselectedLabelColor: Colors.grey,
        indicatorColor: const Color(0xFFe5c687), indicatorSize: TabBarIndicatorSize.label,
        tabs: const [Tab(icon: Icon(Icons.grid_on_rounded, size: 22))],
      ),
    ]),
  );

  void _showList(BuildContext ctx, {required bool isFollowers}) =>
      showModalBottomSheet(context: ctx, backgroundColor: AppColors.of(ctx).surface,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          builder: (_) => _FollowListSheet(user: user, isFollowers: isFollowers));
}

class _FakeVsync implements TickerProvider {
  @override Ticker createTicker(TickerCallback onTick) => Ticker(onTick);
}

class _Stat extends StatelessWidget {
  final String label, value;
  const _Stat({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
    Text(value, style: TextStyle(color: AppColors.of(context).text, fontSize: 18, fontWeight: FontWeight.bold)),
    const SizedBox(height: 2),
    Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
  ]);
}

class _FollowBtn extends StatelessWidget {
  final bool isFollowing, loading; final VoidCallback onTap;
  const _FollowBtn({required this.isFollowing, required this.loading, required this.onTap});
  @override
  Widget build(BuildContext context) => SizedBox(height: 38,
    child: ElevatedButton(
      style: ElevatedButton.styleFrom(
          backgroundColor: isFollowing ? const Color(0xFF21262d) : const Color(0xFFe5c687),
          foregroundColor: isFollowing ? Colors.white : Colors.black, elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10),
              side: isFollowing ? const BorderSide(color: Color(0xFF30363d)) : BorderSide.none)),
      onPressed: loading ? null : onTap,
      child: loading
          ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(
          color: isFollowing ? Colors.white : Colors.black, strokeWidth: 2))
          : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(isFollowing ? Icons.how_to_reg_rounded : Icons.person_add_rounded,
            size: 16, color: isFollowing ? Colors.white : Colors.black),
        const SizedBox(width: 6),
        Text(isFollowing ? AppStrings.of(context).following : AppStrings.of(context).follow,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14,
                color: isFollowing ? Colors.white : Colors.black)),
      ]),
    ),
  );
}

// ── Instagram-style media grid ───────────────────────────────────────────────
class _PostsGrid extends StatelessWidget {
  final List<PostModel> posts;
  const _PostsGrid({required this.posts});

  @override
  Widget build(BuildContext context) {
    // Only show posts that have media (images or video)
    final mediaPosts = posts.where((p) =>
    (p.postImage?.isNotEmpty == true) ||
        (p.postVideo?.isNotEmpty  == true) ||
        (p.videoThumbnail?.isNotEmpty == true)).toList();

    if (mediaPosts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.grid_off_rounded, color: Colors.white24, size: 48),
            const SizedBox(height: 12),
            Text(AppStrings.of(context).noPostsYetFull, style: TextStyle(color: AppColors.of(context).textHint)),
          ]),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(1),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: mediaPosts.length,
      itemBuilder: (_, i) => _GridCell(post: mediaPosts[i]),
    );
  }
}

class _GridCell extends StatelessWidget {
  final PostModel post;
  const _GridCell({required this.post});

  @override
  Widget build(BuildContext context) {
    final imgs = (post.postImage ?? '')
        .split(',')
        .where((s) => s.trim().isNotEmpty)
        .toList();
    final isVideo       = post.postVideo?.isNotEmpty == true;
    final hasMulti      = imgs.length > 1;
    // Prefer thumbnail for video, else first image
    final thumbUrl = isVideo
        ? (post.videoThumbnail?.isNotEmpty == true ? post.videoThumbnail! : null)
        : (imgs.isNotEmpty ? imgs.first : null);

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PostDetailsScreen(
            postId: post.postId!,
            navigationTarget: const PostNavigationTarget.none(),
          ),
        ),
      ),
      child: Stack(fit: StackFit.expand, children: [
        // ── Thumbnail ──────────────────────────────────────────────────
        thumbUrl != null
            ? CachedNetworkImage(
          imageUrl: thumbUrl,
          fit: BoxFit.cover,
          placeholder: (_, _) => const ColoredBox(color: Color(0xFF21262d)),
          errorWidget:  (_, _, ___) => _VideoPlaceholder(isVideo: isVideo),
        )
            : _VideoPlaceholder(isVideo: isVideo),

        // ── Video play icon ────────────────────────────────────────────
        if (isVideo)
          Positioned(
            top: 6, right: 6,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                  color: Colors.black45, borderRadius: BorderRadius.circular(6)),
              child: Icon(Icons.play_arrow_rounded,
                  color: AppColors.of(context).text, size: 14),
            ),
          ),

        // ── Multiple images badge ──────────────────────────────────────
        if (hasMulti && !isVideo)
          Positioned(
            top: 6, right: 6,
            child: Icon(Icons.collections_rounded, color: AppColors.of(context).text, size: 16),
          ),

        // ── Likes overlay ──────────────────────────────────────────────
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Colors.black.withValues(alpha: 0.6), Colors.transparent],
              ),
            ),
            child: Row(children: [
              Icon(Icons.favorite_rounded, color: AppColors.of(context).text, size: 11),
              const SizedBox(width: 3),
              Text('${post.likes}',
                  style: TextStyle(color: AppColors.of(context).text, fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _VideoPlaceholder extends StatelessWidget {
  final bool isVideo;
  const _VideoPlaceholder({required this.isVideo});
  @override
  Widget build(BuildContext context) => Container(
    color: const Color(0xFF21262d),
    alignment: Alignment.center,
    child: Icon(
      isVideo ? Icons.play_circle_outline : Icons.image_not_supported_outlined,
      color: Colors.white24, size: 28,
    ),
  );
}

class _FollowListSheet extends StatefulWidget {
  final UserModel user; final bool isFollowers;
  const _FollowListSheet({required this.user, required this.isFollowers});
  @override State<_FollowListSheet> createState() => _FollowListSheetState();
}

class _FollowListSheetState extends State<_FollowListSheet> {
  List<UserModel> _people = []; bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final uids = widget.isFollowers ? widget.user.followersUids : widget.user.followingUids;
    if (uids.isEmpty) { if (mounted) setState(() => _loading = false); return; }
    final results = <UserModel>[];
    for (var i = 0; i < uids.length; i += 30) {
      final chunk = uids.sublist(i, (i+30).clamp(0, uids.length));
      final snap  = await FirebaseFirestore.instance.collection('Users').where('uid', whereIn: chunk).get();
      results.addAll(snap.docs.map((d) => UserModel.fromJson(d.data())));
    }
    if (mounted) setState(() { _people = results; _loading = false; });
  }

  Future<void> _toggle(UserModel target) async {
    final me = MainCubit.get(context).model;
    if (me?.uid == null || target.uid == null) return;
    final wasFollowing = me!.followingUids.contains(target.uid);
    final batch = FirebaseFirestore.instance.batch();
    final myRef = FirebaseFirestore.instance.collection('Users').doc(me.uid);
    final theirRef = FirebaseFirestore.instance.collection('Users').doc(target.uid);
    if (wasFollowing) {
      batch.update(myRef,    {'followingUids': FieldValue.arrayRemove([target.uid])});
      batch.update(theirRef, {'followersUids': FieldValue.arrayRemove([me.uid])});
      me.followingUids.remove(target.uid);
    } else {
      batch.update(myRef,    {'followingUids': FieldValue.arrayUnion([target.uid])});
      batch.update(theirRef, {'followersUids': FieldValue.arrayUnion([me.uid])});
      me.followingUids.add(target.uid!);
    }
    await batch.commit();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final me = MainCubit.get(context).model;
    return DraggableScrollableSheet(expand: false, initialChildSize: 0.6, maxChildSize: 0.92,
      builder: (_, scroll) => Column(children: [
        Container(margin: const EdgeInsets.symmetric(vertical: 10), width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
        Text(widget.isFollowers ? AppStrings.of(context).followers : AppStrings.of(context).following,
            style: TextStyle(color: AppColors.of(context).text, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Divider(color: Colors.white10, height: 1),
        Expanded(child: _loading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFFe5c687), strokeWidth: 2))
            : _people.isEmpty
            ? Center(child: Text(widget.isFollowers ? 'No followers yet' : 'Not following anyone',
            style: const TextStyle(color: Colors.grey)))
            : ListView.builder(controller: scroll, itemCount: _people.length,
            itemBuilder: (_, i) {
              final u = _people[i];
              final isMeFollowing = me?.followingUids.contains(u.uid) ?? false;
              return ListTile(
                leading: CircleAvatar(radius: 22, backgroundColor: const Color(0xFF21262d),
                    backgroundImage: (u.image ?? '').isNotEmpty ? CachedNetworkImageProvider(u.image!) : null,
                    child: (u.image ?? '').isEmpty ? Text((u.name ?? '?')[0].toUpperCase(),
                        style: TextStyle(color: AppColors.of(context).text, fontWeight: FontWeight.bold)) : null),
                title: Row(children: [
                  Flexible(child: Text(u.name ?? '', style: TextStyle(color: AppColors.of(context).text, fontSize: 14, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
                  if (u.isVerified == true) ...[const SizedBox(width: 4), const Icon(Icons.verified_rounded, color: Color(0xFFe5c687), size: 13)],
                ]),
                subtitle: Text('${u.followersCount} followers', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                trailing: u.uid == me?.uid ? null : GestureDetector(
                    onTap: () => _toggle(u),
                    child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                            color: isMeFollowing ? const Color(0xFF21262d) : const Color(0xFFe5c687),
                            borderRadius: BorderRadius.circular(8),
                            border: isMeFollowing ? Border.all(color: const Color(0xFF30363d)) : null),
                        child: Text(isMeFollowing ? AppStrings.of(context).following : AppStrings.of(context).follow,
                            style: TextStyle(color: isMeFollowing ? Colors.white : Colors.black,
                                fontSize: 13, fontWeight: FontWeight.bold)))),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => OtherProfileScreen(user: u)));
                },
              );
            })),
      ]),
    );
  }
}

class _PrivateLock extends StatelessWidget {
  final String name; const _PrivateLock({required this.name});
  @override
  Widget build(BuildContext context) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    Container(padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: const Color(0xFF21262d), shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF30363d))),
        child: const Icon(Icons.lock_rounded, color: Colors.grey, size: 40)),
    const SizedBox(height: 16),
    Text(AppStrings.of(context).privateAccountTitle, style: TextStyle(color: AppColors.of(context).text, fontSize: 17, fontWeight: FontWeight.bold)),
    const SizedBox(height: 6),
    Text(AppStrings.of(context).privateAccountFollow, style: const TextStyle(color: Colors.grey, fontSize: 14)),
  ]));
}

class _EmptyPosts extends StatelessWidget {
  final String name; const _EmptyPosts({required this.name});
  @override
  Widget build(BuildContext context) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    const Icon(Icons.photo_camera_outlined, color: Colors.grey, size: 52),
    const SizedBox(height: 12),
    Text(AppStrings.of(context).noPostsYetOther, style: TextStyle(color: AppColors.of(context).text, fontSize: 16, fontWeight: FontWeight.bold)),
    const SizedBox(height: 4),
    Text(AppStrings.of(context).whenSharesPhotos,
        style: const TextStyle(color: Colors.grey, fontSize: 13), textAlign: TextAlign.center),
  ]));
}