import 'dart:math' as math;
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../share/style/app_colors.dart';
import '../../share/local/app_strings.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../layout/cubit/chat/chat_cubit.dart';
import '../../layout/cubit/chat/chat_states.dart';
import '../../layout/cubit/cubit.dart';
import '../../layout/cubit/notifications/notifications_cubit.dart';
import '../../layout/cubit/notifications/notifications_states.dart';
import '../../layout/cubit/post/post_cubit.dart';
import '../../layout/cubit/post/post_states.dart';
import '../../layout/feeds/hashtag_screen.dart';
import '../../layout/feeds/post_detail_header.dart';
import '../../layout/feeds/post_detail_media.dart';
import '../../layout/feeds/post_reaction_bar.dart';
import '../../layout/notifications/notifications_screen.dart';
import '../../layout/stories/stories_bar.dart';
import '../../layout/feeds/create_post_screen.dart';
import '../../models/post_model.dart';
import '../../models/user_model.dart';
import '../../share/local/skeleton_widgets.dart';

// ── Split into multiple files sharing one library via part/part of ──────────
// All classes below remain private (_Foo) and mutually visible exactly as
// they were when this was a single file. Nothing outside this library can
// see them, matching the original behavior.
part 'feed_palette.dart';
part 'feed_header.dart';
part 'feed_post_card.dart';
part 'feed_modules.dart';
part 'feed_states.dart';
part 'feed_small_widgets.dart';

class FeedsScreen extends StatefulWidget {
  const FeedsScreen({super.key});

  @override
  State<FeedsScreen> createState() => _FeedsScreenState();
}

class _FeedsScreenState extends State<FeedsScreen> {
  final _scrollController = ScrollController();
  static const _paginationThreshold = 240.0;
  bool _isScrolled = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final pos = _scrollController.position;
    final shouldCollapse = pos.pixels > 18;
    if (shouldCollapse != _isScrolled && mounted) {
      setState(() => _isScrolled = shouldCollapse);
    }

    if (pos.maxScrollExtent - pos.pixels <= _paginationThreshold) {
      PostsCubit.get(context).loadMorePosts();
    }
  }

  Future<void> _onRefresh() async {
    PostsCubit.get(context).getPosts();
    await Future.delayed(const Duration(milliseconds: 420));
  }

  void _openSearch() => MainCubit.get(context).changeBottomNav(1);

  void _openMessages() => MainCubit.get(context).changeBottomNav(2);

  void _openNotifications() {
    final nc = NotificationsCubit.get(context);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    );
    nc.markAllAsSeen();
  }

  void _openCreatePost() => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => BlocProvider.value(
        value: PostsCubit.get(context),
        child: const CreatePostScreen(),
      ),
      fullscreenDialog: true,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final palette = _FeedPalette.of(context);
    final topInset = MediaQuery.paddingOf(context).top;

    return Scaffold(
      extendBody: true,
      backgroundColor: palette.background,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: _FloatingCreateCluster(
        palette: palette,
        onCreate: _openCreatePost,
      ),
      body: BlocBuilder<PostsCubit, PostsStates>(
        builder: (context, state) {
          final cubit = PostsCubit.get(context);
          final tags = _collectTrendingTags(cubit.posts);

          return Stack(
            children: [
              _PremiumBackdrop(palette: palette),
              RefreshIndicator.adaptive(
                onRefresh: _onRefresh,
                edgeOffset: topInset + 78,
                displacement: 72,
                color: palette.gold,
                backgroundColor: palette.elevated,
                child: CustomScrollView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  slivers: [
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _FeedTopBarDelegate(
                        palette: palette,
                        topInset: topInset,
                        isScrolled: _isScrolled,
                        user: cubit.currentUser,
                        postCount: cubit.posts.length,
                        onSearch: _openSearch,
                        onNotifications: _openNotifications,
                        onMessages: _openMessages,
                        onCreate: _openCreatePost,
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: _StorySpotlight(
                        palette: palette,
                        onCreate: _openCreatePost,
                      ),
                    ),

                    if (state is PostsLoadingState && cubit.posts.isEmpty)
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                              (_, i) => _SkeletonEnvelope(
                            palette: palette,
                            child: const PostCardSkeleton(),
                          ),
                          childCount: 4,
                        ),
                      )
                    else if (cubit.posts.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _PremiumEmptyState(
                          palette: palette,
                          onCreate: _openCreatePost,
                        ),
                      )
                    else
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                              (ctx, rawIndex) => _buildFeedItem(
                            context: ctx,
                            rawIndex: rawIndex,
                            cubit: cubit,
                            state: state,
                            palette: palette,
                            tags: tags,
                          ),
                          childCount: _feedChildCount(cubit.posts.length),
                        ),
                      ),
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: 108 + MediaQuery.paddingOf(context).bottom,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  int _feedChildCount(int postCount) {
    var count = postCount + 1;
    if (postCount >= 5) count += 1;
    return count;
  }

  Widget _buildFeedItem({
    required BuildContext context,
    required int rawIndex,
    required PostsCubit cubit,
    required PostsStates state,
    required _FeedPalette palette,
    required List<String> tags,
  }) {
    final hasTopicModule = cubit.posts.length >= 5;

    if (hasTopicModule && rawIndex == 5) {
      return _TopicClusterModule(
        palette: palette,
        tags: tags,
        onOpenTag: (tag) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => HashtagScreen(hashtag: tag),
            ),
          );
        },
      );
    }

    var postIndex = rawIndex;
    if (hasTopicModule && rawIndex > 5) postIndex -= 1;

    if (postIndex < cubit.posts.length) {
      final post = cubit.posts[postIndex];
      return _PremiumPostCard(
        key: ValueKey(post.postId ?? 'post-$postIndex'),
        index: postIndex,
        post: post,
        currentUser: cubit.currentUser,
        palette: palette,
      );
    }

    return _FeedFooter(
      palette: palette,
      state: state,
      hasMorePosts: cubit.hasMorePosts,
    );
  }

  List<String> _collectTrendingTags(List<PostModel> posts) {
    final counts = <String, int>{};
    for (final post in posts) {
      for (final tag in post.hashtags) {
        final normalized = tag.replaceAll('#', '').trim().toLowerCase();
        if (normalized.isEmpty) continue;
        counts[normalized] = (counts[normalized] ?? 0) + 1;
      }
    }

    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final tags = sorted.map((e) => e.key).take(8).toList();
    if (tags.isNotEmpty) return tags;
    return const ['design', 'music', 'travel', 'daily'];
  }
}