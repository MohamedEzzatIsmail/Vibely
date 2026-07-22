import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../share/style/app_colors.dart';
import '../../share/local/app_strings.dart';

import '../../models/post_model.dart';
import '../cubit/cubit.dart';
import '../feeds/post_details_screen.dart';
import '../../share/network/notification_router.dart';

class BookmarksScreen extends StatefulWidget {
  const BookmarksScreen({super.key});
  @override
  State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen> {
  List<PostModel> _posts = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final model = MainCubit.get(context).model;
    if (model == null || model.bookmarkedPostIds.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    final ids = model.bookmarkedPostIds;
    // Firestore whereIn max 30
    final chunks = <List<String>>[];
    for (var i = 0; i < ids.length; i += 30) {
      chunks.add(ids.sublist(i, i + 30 > ids.length ? ids.length : i + 30));
    }
    final results = <PostModel>[];
    for (final chunk in chunks) {
      final snap = await FirebaseFirestore.instance
          .collection('Posts').where('postId', whereIn: chunk).get();
      results.addAll(snap.docs.map((d) => PostModel.fromJson(d.data())));
    }
    // preserve bookmark order
    results.sort((a, b) => ids.indexOf(a.postId ?? '').compareTo(ids.indexOf(b.postId ?? '')));
    setState(() { _posts = results; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.of(context).surface,
      appBar: AppBar(
        backgroundColor: AppColors.of(context).surface,
        title: Text(AppStrings.of(context).bookmarks, style: TextStyle(color: AppColors.of(context).text, fontSize: 18, fontWeight: FontWeight.bold)),
        iconTheme: IconThemeData(color: AppColors.of(context).isDark ? Colors.white : const Color(0xFFe5c687)),
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: const CircularProgressIndicator(color: Color(0xFFe5c687)))
          : _posts.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.bookmark_border_rounded, color: Colors.grey, size: 52),
                  const SizedBox(height: 12),
                  Text(AppStrings.of(context).noBookmarks, style: const TextStyle(color: Colors.grey, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text(AppStrings.of(context).tapBookmarkHint, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ]))
              : GridView.builder(
                  padding: const EdgeInsets.all(2),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3, crossAxisSpacing: 2, mainAxisSpacing: 2),
                  itemCount: _posts.length,
                  itemBuilder: (_, i) {
                    final p = _posts[i];
                    final imgs = (p.postImage ?? '').split(',').where((s) => s.isNotEmpty).toList();
                    return GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => PostDetailsScreen(
                          postId: p.postId!,
                          navigationTarget: const PostNavigationTarget.none()))),
                      child: imgs.isNotEmpty
                          ? CachedNetworkImage(imageUrl: imgs.first, fit: BoxFit.cover,
                              placeholder: (_, _) => const ColoredBox(color: Color(0xFF2a3140)),
                              errorWidget: (_, _, ___) => const ColoredBox(color: Color(0xFF2a3140)))
                          : Container(
                              color: const Color(0xFF2a3140),
                              alignment: Alignment.center,
                              padding: const EdgeInsets.all(6),
                              child: Text(p.text ?? '', style: TextStyle(color: AppColors.of(context).textSub, fontSize: 10),
                                maxLines: 4, overflow: TextOverflow.ellipsis)),
                    );
                  },
                ),
    );
  }
}
