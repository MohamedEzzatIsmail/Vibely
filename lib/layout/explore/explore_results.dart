part of 'explore_screen.dart';

class _UserResults extends StatelessWidget {
  final List<UserModel> users;
  const _UserResults({required this.users});

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final c = AppColors.of(context);
    if (users.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.person_search_rounded, color: AppColors.of(context).textHint, size: 48),
          const SizedBox(height: 12),
          Text(AppStrings.of(context).noUsersFound, style: TextStyle(color: AppColors.of(context).textHint, fontSize: 15)),
        ]),
      );
    }
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      itemCount: users.length,
      itemBuilder: (_, i) => _UserTile(user: users[i], index: i),
    );
  }
}

class _UserTile extends StatelessWidget {
  final UserModel user;
  final int       index;
  const _UserTile({required this.user, required this.index});

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => OtherProfileScreen(user: user))),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.of(context).surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.of(context).border, width: 1),
          ),
          child: Row(children: [
            // Rank number
            SizedBox(
              width: 24,
              child: Text('${index + 1}', style: TextStyle(
                color: index < 3 ? _gold : AppColors.of(context).textHint,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              )),
            ),
            const SizedBox(width: 4),
            // Avatar
            Stack(children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: AppColors.of(context).elevated,
                backgroundImage: (user.image ?? '').isNotEmpty
                    ? CachedNetworkImageProvider(user.image!) : null,
                child: (user.image ?? '').isEmpty
                    ? Icon(Icons.person, color: AppColors.of(context).textHint, size: 26) : null,
              ),
              if (user.isVerified == true)
                Positioned(right: 0, bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(shape: BoxShape.circle, color: _bg),
                      child: const Icon(Icons.verified_rounded, color: _gold, size: 14),
                    )),
            ]),
            const SizedBox(width: 12),
            // Info
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(user.name ?? '', style: TextStyle(
                  color: AppColors.of(context).text, fontSize: 15, fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text(
                '${_fmt(user.followersCount ?? 0)} followers',
                style: TextStyle(color: AppColors.of(context).textHint, fontSize: 12),
              ),
            ])),
            // Arrow
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.of(context).elevated,
              ),
              child: Icon(Icons.arrow_forward_ios_rounded, color: AppColors.of(context).textHint, size: 13),
            ),
          ]),
        ),
      ),
    );
  }

  String _fmt(int n) => n >= 1000 ? '${(n / 1000).toStringAsFixed(1)}k' : '$n';
}

// ─────────────────────────────────────────────────────────────────────────────
//  Hashtag results
// ─────────────────────────────────────────────────────────────────────────────
class _HashtagResults extends StatelessWidget {
  final List<PostModel> posts;
  final String          query;
  const _HashtagResults({required this.posts, required this.query});

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final c = AppColors.of(context);
    if (posts.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.tag_rounded, color: AppColors.of(context).textHint, size: 48),
          const SizedBox(height: 12),
          Text(AppStrings.of(context).noPostsForQuery, style: TextStyle(color: AppColors.of(context).textHint, fontSize: 15)),
        ]),
      );
    }
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _gold.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _gold.withValues(alpha: 0.3)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.tag_rounded, color: _gold, size: 14),
                  const SizedBox(width: 4),
                  Text(query.replaceFirst('#', ''), style: const TextStyle(
                      color: _gold, fontSize: 14, fontWeight: FontWeight.w700)),
                ]),
              ),
              const SizedBox(width: 10),
              Text('${posts.length} posts', style: TextStyle(color: AppColors.of(context).textHint, fontSize: 13)),
            ]),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3, crossAxisSpacing: 3, mainAxisSpacing: 3,
            ),
            delegate: SliverChildBuilderDelegate(
                  (_, i) => _TileBase(post: posts[i], aspectRatio: 1),
              childCount: posts.length,
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }
}
