// lib/layout/feeds/hashtag_screen.dart
//
// Tapping any #hashtag navigates here and shows all matching public posts
// ordered by dateTime descending, paginated with limit(20).

import 'package:vibely/layout/feeds/post_card.dart';
import '../../share/style/app_colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../share/local/app_strings.dart';

import '../../models/post_model.dart';
import '../../share/local/skeleton_widgets.dart';


class HashtagScreen extends StatefulWidget {
  final String hashtag;

  const HashtagScreen({super.key, required this.hashtag});

  @override
  State<HashtagScreen> createState() => _HashtagScreenState();
}

class _HashtagScreenState extends State<HashtagScreen> {
  static const _pageSize = 20;

  final _fs = FirebaseFirestore.instance;
  final _posts = <PostModel>[];
  DocumentSnapshot? _lastDoc;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  bool _hasError = false;
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadFirst();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadFirst() async {
    setState(() { _loading = true; _hasError = false; });
    try {
      final snap = await _fs
          .collection(AppStrings.of(context).posts)
          .where('privacy', isEqualTo: 'public')
          .where('hashtags', arrayContains: widget.hashtag.toLowerCase())
          .orderBy('dateTime', descending: true)
          .limit(_pageSize)
          .get();

      _posts.clear();
      _posts.addAll(
          snap.docs.map((d) => PostModel.fromJson(d.data())).toList());
      if (snap.docs.isNotEmpty) _lastDoc = snap.docs.last;
      _hasMore = snap.docs.length >= _pageSize;
    } catch (e) {
      if (kDebugMode) debugPrint('[HashtagScreen] _loadFirst failed: $e');
      _hasError = true;
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _lastDoc == null) return;
    setState(() => _loadingMore = true);
    try {
      final snap = await _fs
          .collection(AppStrings.of(context).posts)
          .where('privacy', isEqualTo: 'public')
          .where('hashtags', arrayContains: widget.hashtag.toLowerCase())
          .orderBy('dateTime', descending: true)
          .startAfterDocument(_lastDoc!)
          .limit(_pageSize)
          .get();

      _posts.addAll(
          snap.docs.map((d) => PostModel.fromJson(d.data())).toList());
      if (snap.docs.isNotEmpty) _lastDoc = snap.docs.last;
      _hasMore = snap.docs.length >= _pageSize;
    } catch (e) {
      if (kDebugMode) debugPrint('[HashtagScreen] _loadMore failed: $e');
      // Stop further pagination attempts rather than retrying (and failing)
      // on every subsequent scroll tick.
      _hasMore = false;
    }
    if (mounted) setState(() => _loadingMore = false);
  }

  void _onScroll() {
    if (_scrollCtrl.position.maxScrollExtent -
            _scrollCtrl.position.pixels <=
        200) {
      _loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.of(context).bg,
      appBar: AppBar(
        backgroundColor: AppColors.of(context).bg,
        elevation: 0,
        title: Text(
          '#${widget.hashtag}',
          style: const TextStyle(
              color: Color(0xFFe5c687),
              fontWeight: FontWeight.bold,
              fontSize: 18),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.of(context).textSub),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? ListView.builder(
              itemCount: 4,
              itemBuilder: (_, _) => const PostCardSkeleton(),
            )
          : _hasError && _posts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline,
                          color: AppColors.of(context).textSub, size: 40),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          AppStrings.of(context).failedToLoadPosts,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.of(context).textSub),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: _loadFirst,
                        child: Text(AppStrings.of(context).retry),
                      ),
                    ],
                  ),
                )
              : _posts.isEmpty
              ? Center(
                  child: Text(
                    AppStrings.of(context).noPostsForQuery,
                    style: TextStyle(color: AppColors.of(context).textSub),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadFirst,
                  color: const Color(0xFFe5c687),
                  child: ListView.builder(
                    controller: _scrollCtrl,
                    itemCount: _posts.length + 1,
                    itemBuilder: (_, i) {
                      if (i < _posts.length) {
                        return PostCard(post: _posts[i]);
                      }
                      return _loadingMore
                          ? const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: Color(0xFFe5c687),
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : const SizedBox(height: 20);
                    },
                  ),
                ),
    );
  }
}
