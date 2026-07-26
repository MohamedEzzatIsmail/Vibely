import 'dart:async';
import 'dart:io';
import 'package:vibely/layout/cubit/post/post_states.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show FieldValue, QuerySnapshot, DocumentSnapshot;
import '../../../models/post_model.dart';
import '../../../models/user_model.dart';
import '../../../share/local/media_permission_service.dart';
import '../../../models/notification_model.dart';
import '../../../services/notification_service.dart';
import '../../../services/repositories/post_repository.dart';
import '../../../share/network/notification_router.dart';
import '../../feeds/comments_bottom_sheet.dart';
import '../../feeds/post_details_screen.dart';

class PostsCubit extends Cubit<PostsStates> {
  PostsCubit() : super(PostsInitialState());
  static PostsCubit get(context) => BlocProvider.of(context);

  UserModel? currentUser;

  List<PostModel> posts = [];
  List<PostModel> allPosts = [];
  List<File> postImages = [];
  File? postVideo;

  bool _isPicking = false;

  // ── Feed stream subscription (cancelled on logout) ────────────────────────
  StreamSubscription? _feedSub;
  // If the listener errors out (transient network/auth hiccup), this retries
  // the subscription automatically instead of leaving the feed stuck until
  // the user manually pulls to refresh.
  Timer? _feedRetryTimer;
  static const _feedRetryDelay = Duration(seconds: 3);

  // ── Pagination ─────────────────────────────────────────────────────────────
  DocumentSnapshot? _lastDoc;
  bool hasMorePosts = true;
  bool _loadingMore = false;
  static const _pageSize = 15;

  // ── Rate limiting (30s between posts) ─────────────────────────────────────
  DateTime? _lastPostTime;
  static const _postCooldown = Duration(seconds: 30);

  // ── Context ───────────────────────────────────────────────────────────────
  BuildContext? _context;
  void setContext(BuildContext ctx) {
    _context = ctx;
  }

  // ── Setup ─────────────────────────────────────────────────────────────────
  void setCurrentUser(UserModel user) {
    currentUser = user;
    posts.clear();
    postImages.clear();
    postVideo = null;
    emit(PostsInitialState());
    getPosts();
    _setOnline(true);
  }

  // ── Clear feed (called on logout) ─────────────────────────────────────────
  void clearFeed() {
    _feedSub?.cancel();
    _feedSub = null;
    _feedRetryTimer?.cancel();
    posts.clear();
    allPosts.clear();
    _lastDoc = null;
    hasMorePosts = true;
    emit(PostsInitialState());
  }

  @override
  Future<void> close() {
    _feedSub?.cancel();
    _feedRetryTimer?.cancel();
    return super.close();
  }

  // ── Online presence ───────────────────────────────────────────────────────
  Future<void> _setOnline(bool online) async {
    if (currentUser?.uid == null) return;
    await PostRepository.setOnline(currentUser!.uid!, online);
  }

  void goOffline() => _setOnline(false);

  // ── Feed — first page with real-time listener ─────────────────────────────
  void getPosts() {
    _feedSub?.cancel();
    _feedRetryTimer?.cancel();
    emit(PostsLoadingState());
    _subscribeFeed();
  }

  void _subscribeFeed() {
    _feedSub = PostRepository.watchFeed(
      pageSize: _pageSize,
      onData: (snapshot) {
        // A previous error's retry is no longer needed once data flows again.
        _feedRetryTimer?.cancel();

        if (snapshot.docs.isNotEmpty) {
          _lastDoc = snapshot.docs.last;
        }
        hasMorePosts = snapshot.docs.length >= _pageSize;

        allPosts =
            snapshot.docs.map((d) => PostModel.fromJson(d.data())).toList();

        _applyFeedFilter();
        emit(PostsSuccessState());
      },
      onError: (e) {
        emit(PostsErrorState(e.toString()));
        // The real-time listener dies permanently on error (this is how
        // Firestore snapshot listeners behave) — without this, the feed
        // would never update again until the user manually pulled to
        // refresh. Reconnect automatically after a short delay instead.
        _feedRetryTimer?.cancel();
        _feedRetryTimer = Timer(_feedRetryDelay, _subscribeFeed);
      },
    );
  }

  // ── Load more posts (cursor-based, one-time fetch) ────────────────────────
  Future<void> loadMorePosts() async {
    if (_loadingMore || !hasMorePosts || _lastDoc == null) return;
    _loadingMore = true;
    emit(PostsLoadingMoreState());

    try {
      final snapshot = await PostRepository.fetchMorePosts(
        lastDoc: _lastDoc!,
        pageSize: _pageSize,
      );

      if (snapshot.docs.isNotEmpty) {
        _lastDoc = snapshot.docs.last;
        final newPosts =
            snapshot.docs.map((d) => PostModel.fromJson(d.data())).toList();
        allPosts.addAll(newPosts);
        _applyFeedFilter();
      }

      hasMorePosts = snapshot.docs.length >= _pageSize;
      emit(PostsSuccessState());
    } catch (e) {
      emit(PostsErrorState(e.toString()));
    } finally {
      _loadingMore = false;
    }
  }

  void _applyFeedFilter() {
    final me = currentUser;
    if (me == null) {
      posts = allPosts.where((p) => p.privacy == 'public').toList();
      return;
    }

    final blocked = me.blockedUids;
    final following = me.followingUids;

    if (following.isEmpty) {
      posts = allPosts
          .where((p) =>
              p.privacy == 'public' && !blocked.contains(p.uid))
          .toList();
    } else {
      posts = allPosts.where((p) {
        if (blocked.contains(p.uid)) return false;
        if (p.uid == me.uid) return true;
        if (!following.contains(p.uid)) return false;
        if (p.privacy == 'private') return false;
        return true;
      }).toList();
    }
  }

  // ── Create post with rate limiting ─────────────────────────────────────────
  Future<void> createPostWithMedia({
    required String text,
    required List<File> images,
    File? video,
    String privacy = 'public',
  }) async {
    if (currentUser == null || currentUser!.uid == null) return;

    // Rate limiting guard
    if (_lastPostTime != null &&
        DateTime.now().difference(_lastPostTime!) < _postCooldown) {
      final remaining = _postCooldown - DateTime.now().difference(_lastPostTime!);
      emit(PostRateLimitedState(remaining));
      return;
    }

    emit(PostCreatingState());
    try {
      final imageUrls = <String>[];
      String? videoUrl;

      for (var i = 0; i < images.length; i++) {
        imageUrls.add(await PostRepository.uploadPostImage(images[i], i));
      }

      String? videoThumbnailUrl;
      if (video != null) {
        videoUrl = await PostRepository.uploadPostVideo(video);
        videoThumbnailUrl = await PostRepository.generateAndUploadThumbnail(video);
      }

      final hashtags = PostModel.extractHashtags(text);
      final ref = PostRepository.newPostRef();
      await PostRepository.createPost(PostModel(
        postId: ref.id,
        uid: currentUser!.uid!,
        name: currentUser!.name,
        image: currentUser!.image,
        text: text,
        postImages: imageUrls,
        postVideo: videoUrl,
        videoThumbnail: videoThumbnailUrl,
        dateTime: DateTime.now().toIso8601String(),
        privacy: privacy,
        hashtags: hashtags,
        likes: 0,
        dislikes: 0,
        commentsCount: 0,
        userReactions: {},
        reactionCounts: {},
      ));

      _lastPostTime = DateTime.now();
      emit(PostCreatedState());
    } catch (e) {
      emit(PostErrorState(e.toString()));
    }
  }

  // ── Edit post ─────────────────────────────────────────────────────────────
  Future<void> editPost({
    required String postId,
    required String newText,
    required String privacy,
  }) async {
    try {
      final hashtags = PostModel.extractHashtags(newText);
      await PostRepository.editPost(
        postId: postId,
        newText: newText,
        privacy: privacy,
        hashtags: hashtags,
      );
      for (final list in [posts, allPosts]) {
        final idx = list.indexWhere((p) => p.postId == postId);
        if (idx >= 0) {
          list[idx].text = newText;
          list[idx].privacy = privacy;
          list[idx].hashtags = hashtags;
        }
      }
      emit(PostEditedState());
    } catch (e) {
      emit(PostErrorState(e.toString()));
    }
  }

  // ── Delete post ───────────────────────────────────────────────────────────
  Future<void> deletePost(String postId) async {
    try {
      await PostRepository.deletePost(postId);
      if (currentUser?.uid != null) {
        await PostRepository.deleteNotificationsForPost(
          uid: currentUser!.uid!,
          postId: postId,
        );
      }
      emit(PostDeletedState());
    } catch (e) {
      emit(PostErrorState(e.toString()));
    }
  }

  // ── Bookmark toggle ───────────────────────────────────────────────────────
  Future<void> toggleBookmark(String postId) async {
    if (currentUser?.uid == null) return;
    final uid = currentUser!.uid!;
    final isBookmarked = currentUser!.hasBookmarked(postId);

    if (isBookmarked) {
      currentUser!.bookmarkedPostIds.remove(postId);
    } else {
      currentUser!.bookmarkedPostIds.add(postId);
    }
    await PostRepository.setBookmarked(
      uid: uid,
      postId: postId,
      bookmarked: !isBookmarked,
    );
    emit(PostsSuccessState());
  }

  // ── Reactions ─────────────────────────────────────────────────────────────
  Future<void> reactToPost({
    required String postId,
    required String reactionKey,
  }) async {
    if (currentUser?.uid == null) return;
    final idx = posts.indexWhere((p) => p.postId == postId);
    if (idx == -1) return;

    final post = posts[idx];
    final userId = currentUser!.uid!;
    final current = post.myReaction(userId);
    final update = <String, dynamic>{};

    if (current != null) {
      final newCount = (post.reactionCounts[current] ?? 1) - 1;
      if (newCount <= 0) {
        post.reactionCounts.remove(current);
        update['reactionCounts.$current'] = FieldValue.delete();
      } else {
        post.reactionCounts[current] = newCount;
        update['reactionCounts.$current'] = FieldValue.increment(-1);
      }
    }

    if (current == reactionKey) {
      post.userReactions.remove(userId);
      update['userReactions.$userId'] = FieldValue.delete();
    } else {
      post.userReactions[userId] = reactionKey;
      post.reactionCounts[reactionKey] =
          (post.reactionCounts[reactionKey] ?? 0) + 1;
      update['userReactions.$userId'] = reactionKey;
      update['reactionCounts.$reactionKey'] = FieldValue.increment(1);
      if (post.uid != null && post.uid != userId) {
        await _notify(
            toUserId: post.uid!,
            type: NotificationType.postLike,
            postId: postId);
      }
    }

    post.likes = post.reactionCounts.values
        .where((v) => v > 0)
        .fold(0, (a, b) => a + b);
    update['likes'] = post.likes;
    // Replace the post in the list so BlocBuilder detects the change
    posts[idx] = post;
    emit(PostsSuccessState());
    await PostRepository.applyReactionUpdate(postId: postId, update: update);
  }

  // ── Comments ──────────────────────────────────────────────────────────────
  Future<void> addComment(
      {required String postId, required String commentText}) async {
    if (currentUser?.uid == null) return;
    final ref = PostRepository.newCommentRef(postId);
    await PostRepository.addComment(
      postId: postId,
      ref: ref,
      data: {
        'commentId': ref.id,
        'userId': currentUser!.uid!,
        'userName': currentUser!.name,
        'userImage': currentUser!.image,
        'text': commentText,
        'dateTime': DateTime.now().toIso8601String(),
        'likes': 0,
        'dislikes': 0,
        'reactions': {},
        'repliesCount': 0,
      },
    );

    final postDoc = await PostRepository.getPost(postId);
    final postOwnerId = postDoc.data()?['uid'] as String?;
    if (postOwnerId != null && postOwnerId != currentUser!.uid) {
      await _notify(
          toUserId: postOwnerId,
          type: NotificationType.postComment,
          postId: postId,
          commentId: ref.id,
          text: commentText);
    }
  }

  Future<void> deleteComment(
      {required String postId,
      required Map<String, dynamic> comment}) async {
    if (currentUser?.uid == null) return;
    final postDoc = await PostRepository.getPost(postId);
    final postOwnerId = postDoc.data()?['uid'];
    if (currentUser!.uid != postOwnerId &&
        currentUser!.uid != comment['userId']) return;
    final commentId = comment['commentId'] as String?;
    await PostRepository.deleteComment(postId: postId, commentId: commentId!);
    if (commentId != null) {
      await PostRepository.deleteNotificationsForComment(
        uid: postOwnerId?.toString() ?? '',
        commentId: commentId,
      );
    }
    emit(CommentDeletedState(postId: postId));
  }

  Future<void> reactToComment(
      {required String postId,
      required String commentId,
      required bool isLike}) async {
    if (currentUser?.uid == null) return;
    final userId = currentUser!.uid!;
    final doc = await PostRepository.getComment(postId: postId, commentId: commentId);
    final data = doc.data()!;
    final reactions =
        Map<String, dynamic>.from(data['reactions'] ?? {});
    int likes = data['likes'] ?? 0, dislikes = data['dislikes'] ?? 0;
    final current = reactions[userId];
    if (current == isLike) {
      if (isLike) likes--;
      else dislikes--;
      reactions.remove(userId);
    } else {
      if (current != null) {
        if (current == true) likes--;
        else dislikes--;
      }
      if (isLike) likes++;
      else dislikes++;
      reactions[userId] = isLike;
    }
    await PostRepository.updateCommentReactions(
      postId: postId,
      commentId: commentId,
      likes: likes,
      dislikes: dislikes,
      reactions: reactions,
    );
    if (isLike && current != true) {
      final owner = data['userId'] as String?;
      if (owner != null && owner != userId) {
        await _notify(
            toUserId: owner,
            type: NotificationType.commentLike,
            postId: postId,
            commentId: commentId);
      }
    }
    emit(CommentReactionUpdatedState());
  }

  Future<void> addReply(
      {required String postId,
      required String commentId,
      required String text}) async {
    if (currentUser?.uid == null) return;
    final ref = PostRepository.newReplyRef(postId: postId, commentId: commentId);
    await PostRepository.addReply(
      postId: postId,
      commentId: commentId,
      ref: ref,
      data: {
        'replyId': ref.id,
        'userId': currentUser!.uid!,
        'userName': currentUser!.name,
        'userImage': currentUser!.image,
        'text': text,
        'dateTime': DateTime.now().toIso8601String(),
        'likes': 0,
        'dislikes': 0,
        'reactions': {},
      },
    );
    final commentDoc = await PostRepository.getComment(postId: postId, commentId: commentId);
    final owner = commentDoc.data()?['userId'] as String?;
    if (owner != null && owner != currentUser!.uid) {
      await _notify(
          toUserId: owner,
          type: NotificationType.commentReply,
          postId: postId,
          commentId: commentId,
          replyId: ref.id,
          text: text);
    }
  }

  Future<void> reactToReply(
      {required String postId,
      required String commentId,
      required String replyId,
      required bool isLike}) async {
    if (currentUser?.uid == null) return;
    final userId = currentUser!.uid!;
    final doc = await PostRepository.getReply(
        postId: postId, commentId: commentId, replyId: replyId);
    final data = doc.data()!;
    final reactions =
        Map<String, dynamic>.from(data['reactions'] ?? {});
    int likes = data['likes'] ?? 0, dislikes = data['dislikes'] ?? 0;
    final current = reactions[userId];
    if (current == isLike) {
      if (isLike) likes--;
      else dislikes--;
      reactions.remove(userId);
    } else {
      if (current != null) {
        if (current == true) likes--;
        else dislikes--;
      }
      if (isLike) likes++;
      else dislikes++;
      reactions[userId] = isLike;
    }
    await PostRepository.updateReplyReactions(
      postId: postId,
      commentId: commentId,
      replyId: replyId,
      likes: likes,
      dislikes: dislikes,
      reactions: reactions,
    );
    if (isLike && current != true) {
      final owner = data['userId'] as String?;
      if (owner != null && owner != userId) {
        await _notify(
            toUserId: owner,
            type: NotificationType.commentLike,
            postId: postId,
            commentId: commentId,
            replyId: replyId);
      }
    }
    emit(CommentReactionUpdatedState());
  }

  Future<void> addReplyToReply({
    required String postId,
    required String commentId,
    required String parentReplyId,
    required String text,
    required String replyOwnerUserId,
  }) async {
    if (currentUser?.uid == null) return;
    final ref = PostRepository.newReplyRef(postId: postId, commentId: commentId);
    await PostRepository.addReply(
      postId: postId,
      commentId: commentId,
      ref: ref,
      data: {
        'replyId': ref.id,
        'parentReplyId': parentReplyId,
        'userId': currentUser!.uid!,
        'userName': currentUser!.name,
        'userImage': currentUser!.image,
        'text': text,
        'dateTime': DateTime.now().toIso8601String(),
        'likes': 0,
        'dislikes': 0,
        'reactions': {},
      },
    );
    if (replyOwnerUserId.isNotEmpty &&
        replyOwnerUserId != currentUser!.uid) {
      await _notify(
          toUserId: replyOwnerUserId,
          type: NotificationType.commentReply,
          postId: postId,
          commentId: commentId,
          replyId: ref.id,
          text: text);
    }
  }

  // ── Pickers ───────────────────────────────────────────────────────────────
  Future<void> pickPostImages({BuildContext? ctx}) async {
    if (_isPicking) return;
    _isPicking = true;
    try {
      if (ctx != null) {
        final ok =
            await MediaPermissionService.requestMediaPermission(ctx);
        if (!ok) return;
      }
      final picked = await ImagePicker().pickMultiImage();
      if (picked.isNotEmpty) {
        postImages.addAll(picked.map((e) => File(e.path)));
        emit(PostImagesPickedState());
      }
    } finally {
      _isPicking = false;
    }
  }

  Future<void> pickPostVideo({BuildContext? ctx}) async {
    if (_isPicking) return;
    _isPicking = true;
    try {
      if (ctx != null) {
        final ok =
            await MediaPermissionService.requestMediaPermission(ctx);
        if (!ok) return;
      }
      final picked =
          await ImagePicker().pickVideo(source: ImageSource.gallery);
      if (picked == null) return;
      try {
        final tempDir = await getTemporaryDirectory();
        final tempFile = File(
            '${tempDir.path}/post_vid_${DateTime.now().millisecondsSinceEpoch}.mp4');
        await picked.saveTo(tempFile.path);
        if (!await tempFile.exists() ||
            await tempFile.length() == 0) {
          throw Exception('Saved video file is empty.');
        }
        postVideo = tempFile;
        emit(PostImagesPickedState());
      } catch (e) {
        emit(PostErrorState('Could not load video: $e'));
      }
    } finally {
      _isPicking = false;
    }
  }

  // ── Navigation ────────────────────────────────────────────────────────────
  void openCommentsBottomSheet(BuildContext context, PostModel post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF20262c),
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(40))),
      builder: (_) => CommentsBottomSheet(post: post),
    );
  }

  void openPost(BuildContext context, PostModel post) {
    if (post.postId == null) return;
    Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(
      builder: (_) => PostDetailsScreen(
          postId: post.postId!,
          navigationTarget: const PostNavigationTarget.none()),
    ));
  }

  // ── Notification helper ───────────────────────────────────────────────────
  Future<void> _notify({
    required String toUserId,
    required NotificationType type,
    String? postId,
    String? commentId,
    String? replyId,
    String? text,
  }) async {
    if (currentUser?.uid == null) return;
    if (toUserId.isEmpty) return;
    if (toUserId == currentUser!.uid) return;
    await NotificationService.send(
      currentUserId: currentUser!.uid!,
      currentUserName: currentUser!.name ?? '',
      currentUserImage: currentUser!.image ?? '',
      toUserId: toUserId,
      type: type,
      postId: postId,
      commentId: commentId,
      replyId: replyId,
      text: text,
    );
  }

  Future<void> sendNotification({
    required String toUserId,
    required NotificationType type,
    String? postId,
    String? commentId,
    String? replyId,
    String? text,
  }) =>
      _notify(
          toUserId: toUserId,
          type: type,
          postId: postId,
          commentId: commentId,
          replyId: replyId,
          text: text);
}
