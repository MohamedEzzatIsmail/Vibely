import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/post_model.dart';
import '../../models/user_model.dart';
import '../cubit/cubit.dart';
import '../cubit/post/post_cubit.dart';
import '../cubit/post/post_states.dart';
import '../feeds/post_details_screen.dart';
import '../other_profile/other_profile_screen.dart';
import '../../share/network/notification_router.dart';
import '../../share/local/skeleton_widgets.dart';
import '../../share/style/app_colors.dart';
import '../../share/local/app_strings.dart';

part 'explore_tiles.dart';
part 'explore_results.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Design tokens
// ─────────────────────────────────────────────────────────────────────────────
const _bg        = Color(0xFF0A0C10);
const _surface   = Color(0xFF13161C);
const _surfaceHi = Color(0xFF1C2029);
const _border    = Color(0xFF252930);
const _gold      = Color(0xFFE5C687);

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});
  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen>
    with SingleTickerProviderStateMixin {
  final _ctrl       = TextEditingController();
  final _focusNode  = FocusNode();
  String _query     = '';
  List<UserModel>  _userResults     = [];
  List<PostModel>  _hashtagResults  = [];
  bool   _searching = false;
  bool   _focused   = false;
  late AnimationController _barAnim;
  late Animation<double>   _barWidth;

  @override
  void initState() {
    super.initState();
    _barAnim  = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _barWidth = CurvedAnimation(parent: _barAnim, curve: Curves.easeOutCubic);
    _focusNode.addListener(() {
      setState(() => _focused = _focusNode.hasFocus);
      _focusNode.hasFocus ? _barAnim.forward() : _barAnim.reverse();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focusNode.dispose();
    _barAnim.dispose();
    super.dispose();
  }

  bool _searchError = false;

  Future<void> _search(String q) async {
    q = q.trim();
    if (q.isEmpty) {
      setState(() { _userResults = []; _hashtagResults = []; _searching = false; _searchError = false; });
      return;
    }
    setState(() { _searching = true; _searchError = false; });

    try {
      if (q.startsWith('#')) {
        final tag  = q.substring(1).toLowerCase();
        final snap = await FirebaseFirestore.instance
            .collection('Posts')
            .where('hashtags', arrayContains: tag)
            .orderBy('dateTime', descending: true)
            .limit(30)
            .get();
        if (!mounted) return;
        setState(() {
          _hashtagResults = snap.docs.map((d) => PostModel.fromJson(d.data())).toList();
          _userResults    = [];
        });
      } else {
        final qLower = q.toLowerCase();
        final myUid  = MainCubit.get(context).model?.uid;
        final snap   = await FirebaseFirestore.instance
            .collection('Users').orderBy('name').limit(100).get();
        final all      = snap.docs.map((d) => UserModel.fromJson(d.data())).toList();
        final filtered = all
            .where((u) => u.uid != myUid)
            .where((u) => (u.name ?? '').toLowerCase().contains(qLower))
            .toList();
        if (!mounted) return;
        setState(() { _userResults = filtered; _hashtagResults = []; });
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[ExploreScreen] search failed: $e');
      if (mounted) {
        setState(() { _userResults = []; _hashtagResults = []; _searchError = true; });
      }
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isHashtag = _query.startsWith('#') && _query.length > 1;
    final showUsers = _query.isNotEmpty && !isHashtag;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.of(context).bg,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              _buildSearchBar(),
              if (_query.isNotEmpty) _buildSearchChip(isHashtag),
              const SizedBox(height: 4),
              Expanded(child: _buildBody(showUsers, isHashtag)),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Row(
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(AppStrings.of(context).exploreTitle, style: TextStyle(
              color: AppColors.of(context).text,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
            )),
            const SizedBox(height: 2),
            Text(AppStrings.of(context).discoverTrending, style: TextStyle(
              color: AppColors.of(context).textHint,
              fontSize: 13,
              fontWeight: FontWeight.w400,
            )),
          ]),
          const Spacer(),
          // Gold accent dot
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _gold.withValues(alpha: 0.12),
              border: Border.all(color: _gold.withValues(alpha: 0.3), width: 1),
            ),
            child: const Icon(Icons.local_fire_department_rounded, color: _gold, size: 18),
          ),
        ],
      ),
    );
  }

  // ── Search bar ──────────────────────────────────────────────────────────────
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: AnimatedBuilder(
        animation: _barWidth,
        builder: (_, _) => Container(
          decoration: BoxDecoration(
            color: AppColors.of(context).surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _focused
                  ? _gold.withValues(alpha: 0.5 * _barWidth.value + 0.15)
                  : _border,
              width: 1.2,
            ),
            boxShadow: _focused
                ? [BoxShadow(color: _gold.withValues(alpha: 0.08 * _barWidth.value), blurRadius: 20, offset: const Offset(0, 4))]
                : [],
          ),
          child: TextField(
            controller: _ctrl,
            focusNode: _focusNode,
            style: TextStyle(color: AppColors.of(context).text, fontSize: 15),
            onChanged: (v) { setState(() => _query = v); _search(v); },
            decoration: InputDecoration(
              hintText: 'Search people or #hashtag…',
              hintStyle: TextStyle(color: AppColors.of(context).textHint, fontSize: 14),
              prefixIcon: Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Icon(Icons.search_rounded,
                    color: _focused ? _gold : AppColors.of(context).textHint, size: 20),
              ),
              suffixIcon: _query.isNotEmpty
                  ? GestureDetector(
                onTap: () { _ctrl.clear(); _search(''); setState(() => _query = ''); },
                child: Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.of(context).elevated,
                  ),
                  child: Icon(Icons.close_rounded, color: AppColors.of(context).textHint, size: 16),
                ),
              )
                  : null,
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
      ),
    );
  }

  // ── Search type chip ────────────────────────────────────────────────────────
  Widget _buildSearchChip(bool isHashtag) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isHashtag ? _gold.withValues(alpha: 0.12) : _surfaceHi,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isHashtag ? _gold.withValues(alpha: 0.4) : _border),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(
              isHashtag ? Icons.tag_rounded : Icons.person_search_rounded,
              color: isHashtag ? _gold : AppColors.of(context).textHint,
              size: 13,
            ),
            const SizedBox(width: 5),
            Text(
              isHashtag ? 'Hashtag' : 'People',
              style: TextStyle(
                color: isHashtag ? _gold : AppColors.of(context).textHint,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  // ── Body router ─────────────────────────────────────────────────────────────
  Widget _buildBody(bool showUsers, bool isHashtag) {
    if (_searching) {
      return const Center(
        child: CircularProgressIndicator(color: _gold, strokeWidth: 2),
      );
    }
    if (_searchError) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.error_outline, color: AppColors.of(context).textHint, size: 44),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              AppStrings.of(context).failedToLoadPosts,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.of(context).textHint, fontSize: 14),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => _search(_query),
            child: Text(AppStrings.of(context).retry),
          ),
        ]),
      );
    }
    if (_query.isEmpty)    return const _TrendingGrid();
    if (showUsers)         return _UserResults(users: _userResults);
    return _HashtagResults(posts: _hashtagResults, query: _query);
  }
}
