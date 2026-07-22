part of 'users_screen.dart';

class _ProfileHero extends StatelessWidget {
  final dynamic model;
  final File? profileImage;
  final File? coverImage;
  final VoidCallback onAvatarTap;
  final VoidCallback onCoverTap;

  const _ProfileHero({
    required this.model,
    required this.profileImage,
    required this.coverImage,
    required this.onAvatarTap,
    required this.onCoverTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 250,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // ── Cover photo ─────────────────────────────────────────────────
          GestureDetector(
            onTap: onCoverTap,
            child: Stack(
              children: [
                Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.of(context).surface,
                    image: (coverImage != null || (model.cover ?? '').isNotEmpty)
                        ? DecorationImage(
                      image: coverImage != null
                          ? FileImage(coverImage!) as ImageProvider
                          : NetworkImage(model.cover ?? ''),
                      fit: BoxFit.cover,
                    )
                        : null,
                  ),
                  child: (coverImage == null && (model.cover ?? '').isEmpty)
                      ? const Center(
                    child: Icon(Icons.panorama_rounded,
                        color: Colors.white12, size: 48),
                  )
                      : null,
                ),
                // Gradient overlay for readability
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        AppColors.of(context).bg.withValues(alpha: 0.7),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Avatar ──────────────────────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 24,
            child: GestureDetector(
              onTap: onAvatarTap,
              child: Stack(
                children: [
                  // Outer ring
                  Container(
                    width: 100,
                    height: 100,
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          kGold,
                          Color(0xE60D1117),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: kGold.withValues(alpha: 0.58),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(3),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.of(context).bg,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(3),
                          child: CircleAvatar(
                            radius: 44,
                            backgroundColor: AppColors.of(context).elevated,
                            backgroundImage: profileImage != null
                                ? FileImage(profileImage!) as ImageProvider
                                : (model.image ?? '').isNotEmpty
                                ? NetworkImage(model.image ?? '')
                                : null,
                            child: (profileImage == null &&
                                (model.image ?? '').isEmpty)
                                ? Icon(Icons.person,
                                color: AppColors.of(context).textHint, size: 36)
                                : null,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Camera badge
                  Positioned(
                    bottom: 2,
                    right: 2,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: const BoxDecoration(
                        color: Color(0xFFe5c687),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.camera_alt_rounded,
                          color: Colors.black, size: 14),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  NAME / BIO / STATS row
// ══════════════════════════════════════════════════════════════════════════════
class _ProfileInfo extends StatelessWidget {
  final dynamic model;
  const _ProfileInfo({required this.model});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Name
          Row(
            children: [
              Text(
                model.name ?? 'No Name',
                style: TextStyle(
                  color: AppColors.of(context).text,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
              SizedBox(width: 8,),
              if (model.isVerified == true)
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFe5c687),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.verified_rounded,
                          color: Colors.black, size: 12),
                      const SizedBox(width: 3),
                      Text(AppStrings.of(context).verifiedLabel,
                          style: const TextStyle(
                              color: Colors.black,
                              fontSize: 10,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
            ],
          ),
          if ((model.bio ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              model.bio ?? '',
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 20),
          // Stats row — real-time from Firestore stream
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('Posts')
                .where('uid', isEqualTo: model.uid)
                .snapshots(),
            builder: (ctx, postsSnap) {
              final postCount = postsSnap.data?.docs.length ?? 0;
              return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('Users')
                    .doc(model.uid)
                    .snapshots(),
                builder: (ctx2, userSnap) {
                  int followers = model.followersCount;
                  int following = model.followingCount;
                  if (userSnap.hasData && userSnap.data!.exists) {
                    final d = userSnap.data!.data()!;
                    followers = (d['followersUids'] as List?)?.length ?? followers;
                    following = (d['followingUids'] as List?)?.length ?? following;
                  }
                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppColors.of(context).surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(children: [
                      _StatItem(label: AppStrings.of(context).posts,     value: '$postCount'),
                      _StatDivider(),
                      _StatItem(label: AppStrings.of(context).followers, value: _fmtCount(followers)),
                      _StatDivider(),
                      _StatItem(label: AppStrings.of(context).following, value: _fmtCount(following)),
                    ]),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

String _fmtCount(int n) {
  if (n >= 1000000) return "${(n / 1000000).toStringAsFixed(1)}M";
  if (n >= 1000)    return "${(n / 1000).toStringAsFixed(1)}K";
  return '$n';
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: const TextStyle(
                  color: Color(0xFFe5c687),
                  fontSize: 20,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 32, color: Colors.white10);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  ACTION BUTTONS
// ══════════════════════════════════════════════════════════════════════════════
class _ProfileActions extends StatelessWidget {
  final bool showConfirm;
  final VoidCallback onEdit;
  final VoidCallback onConfirm;

  const _ProfileActions({
    required this.showConfirm,
    required this.onEdit,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Column(
        children: [
          // Edit profile button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_rounded,
                  size: 18, color: Color(0xFFe5c687)),
              label: Text(
                AppStrings.of(context).editProfileTitle,
                style: const TextStyle(
                  color: Color(0xFFe5c687),
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFe5c687), width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),

          // Confirm image update (only visible when images are pending)
          if (showConfirm) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: onConfirm,
                icon: const Icon(Icons.check_circle_rounded,
                    size: 18, color: Colors.black),
                label: const Text(
                  'Save Photo Changes',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFe5c687),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

