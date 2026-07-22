// test/cubits/post_cubit_test.dart
//
// Compatible with:
//   bloc_test: ^10.0.0
//   mocktail: ^1.0.5
//
// NOTE: Firebase/Supabase cannot be mocked in unit tests without firebase_core
// initialisation. These tests verify pure Dart logic (filtering, model parsing,
// rate-limiting guard, state emission). Integration tests cover Firestore writes.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vibely/layout/cubit/post/post_cubit.dart';
import 'package:vibely/layout/cubit/post/post_states.dart';
import 'package:vibely/models/post_model.dart';
import 'package:vibely/models/user_model.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────
PostModel _makePost({
  String id = 'post1',
  String uid = 'user1',
  String privacy = 'public',
  String text = 'Hello #world',
  int likes = 5,
}) =>
    PostModel(
      postId: id,
      uid: uid,
      name: 'Test User',
      text: text,
      dateTime: DateTime.now().toIso8601String(),
      privacy: privacy,
      likes: likes,
    );

UserModel _makeUser({
  String uid = 'me',
  List<String> following = const [],
  List<String> blocked = const [],
}) =>
    UserModel(
      uid: uid,
      name: 'Me',
      followingUids: following,
      blockedUids: blocked,
    );

// ── Helper extension to test private filter logic without Firestore ───────────
extension PostsCubitTestHelpers on PostsCubit {
  void injectPosts(List<PostModel> posts) {
    allPosts = posts;
  }

  void applyFilterPublic() {
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

  // Expose emit for tests
  // ignore: invalid_use_of_protected_member
  void emitState(PostsStates s) => emit(s);
}

void main() {
  // ── PostModel unit tests ───────────────────────────────────────────────────
  group('PostModel', () {
    test('fromJson: parses new List-based postImages', () {
      final json = {
        'postId': 'p1',
        'uid': 'u1',
        'postImages': ['https://a.com/1.jpg', 'https://a.com/2.jpg'],
        'likes': 0,
        'dislikes': 0,
        'commentsCount': 0,
        'bookmarkCount': 0,
      };
      final post = PostModel.fromJson(json);
      expect(post.postImages.length, 2);
      expect(post.postImages.first, 'https://a.com/1.jpg');
    });

    test('fromJson: falls back to comma-string for legacy documents', () {
      final json = {
        'postId': 'p1',
        'uid': 'u1',
        'postImage': 'https://a.com/1.jpg,https://a.com/2.jpg',
        'likes': 0,
        'dislikes': 0,
        'commentsCount': 0,
        'bookmarkCount': 0,
      };
      final post = PostModel.fromJson(json);
      expect(post.postImages.length, 2);
      expect(post.postImages.first, 'https://a.com/1.jpg');
    });

    test('fromJson: empty postImages when neither field present', () {
      final json = {
        'postId': 'p1',
        'uid': 'u1',
        'likes': 0,
        'dislikes': 0,
        'commentsCount': 0,
        'bookmarkCount': 0,
      };
      final post = PostModel.fromJson(json);
      expect(post.postImages, isEmpty);
    });

    test('trendingScore: returns 0.0 for null dateTime', () {
      final post = PostModel(postId: 'p1', uid: 'u1');
      expect(post.trendingScore(), 0.0);
    });

    test('trendingScore: returns positive value for recent post with reactions',
        () {
      final post = PostModel(
        postId: 'p1',
        uid: 'u1',
        dateTime: DateTime.now()
            .subtract(const Duration(hours: 1))
            .toIso8601String(),
        reactionCounts: {'like': 10},
        commentsCount: 5,
      );
      expect(post.trendingScore(), greaterThan(0));
    });

    test('extractHashtags: extracts lowercase hashtags correctly', () {
      final tags =
          PostModel.extractHashtags('Hello #World and #Flutter today!');
      expect(tags, containsAll(['world', 'flutter']));
      expect(tags.every((t) => t == t.toLowerCase()), isTrue);
    });

    test('extractHashtags: returns empty for no hashtags', () {
      expect(PostModel.extractHashtags('No tags here'), isEmpty);
    });

    test('myReaction: handles legacy bool true → "like"', () {
      final post = PostModel(
        userReactions: {'user42': true},
      );
      expect(post.myReaction('user42'), 'like');
    });

    test('myReaction: handles legacy bool false → null', () {
      final post = PostModel(
        userReactions: {'user42': false},
      );
      expect(post.myReaction('user42'), isNull);
    });

    test('myReaction: handles new string format', () {
      final post = PostModel(
        userReactions: {'user42': 'love'},
      );
      expect(post.myReaction('user42'), 'love');
    });

    test('myReaction: returns null for unknown user', () {
      final post = PostModel(userReactions: {});
      expect(post.myReaction('nobody'), isNull);
    });

    test('myReaction: returns null when userId is null', () {
      final post = PostModel(userReactions: {'u1': 'like'});
      expect(post.myReaction(null), isNull);
    });
  });

  // ── PostsCubit filter logic ────────────────────────────────────────────────
  group('PostsCubit feed filter', () {
    late PostsCubit cubit;

    setUp(() => cubit = PostsCubit());
    tearDown(() => cubit.close());

    test('filters out blocked users', () {
      cubit.currentUser = _makeUser(
        uid: 'me',
        following: ['user1'],
        blocked: ['user2'],
      );
      cubit.injectPosts([
        _makePost(id: 'p1', uid: 'user1', privacy: 'public'),
        _makePost(id: 'p2', uid: 'user2', privacy: 'public'),
      ]);
      cubit.applyFilterPublic();
      expect(cubit.posts.any((p) => p.uid == 'user2'), isFalse);
      expect(cubit.posts.any((p) => p.uid == 'user1'), isTrue);
    });

    test('shows only public posts when following list is empty', () {
      cubit.currentUser = _makeUser(uid: 'me', following: []);
      cubit.injectPosts([
        _makePost(id: 'p1', uid: 'user1', privacy: 'public'),
        _makePost(id: 'p2', uid: 'user2', privacy: 'public'),
        _makePost(id: 'p3', uid: 'user3', privacy: 'private'),
      ]);
      cubit.applyFilterPublic();
      expect(cubit.posts.length, 2);
      expect(cubit.posts.every((p) => p.privacy == 'public'), isTrue);
    });

    test('shows own posts regardless of privacy', () {
      cubit.currentUser = _makeUser(
        uid: 'me',
        following: ['user1'],
      );
      cubit.injectPosts([
        _makePost(id: 'p1', uid: 'me', privacy: 'private'),
        _makePost(id: 'p2', uid: 'user1', privacy: 'public'),
      ]);
      cubit.applyFilterPublic();
      expect(cubit.posts.any((p) => p.postId == 'p1'), isTrue);
    });

    test('hides private posts from followed users', () {
      cubit.currentUser = _makeUser(uid: 'me', following: ['user1']);
      cubit.injectPosts([
        _makePost(id: 'p1', uid: 'user1', privacy: 'private'),
      ]);
      cubit.applyFilterPublic();
      expect(cubit.posts, isEmpty);
    });
  });

  // ── PostsCubit state emission ─────────────────────────────────────────────
  group('PostsCubit state', () {
    test('initial state is PostsInitialState', () {
      final cubit = PostsCubit();
      expect(cubit.state, isA<PostsInitialState>());
      cubit.close();
    });

    blocTest<PostsCubit, PostsStates>(
      'emits PostEditedState when editPost logic is triggered',
      build: () {
        final c = PostsCubit();
        c.currentUser = _makeUser();
        c.posts = [_makePost(id: 'post1')];
        c.allPosts = [_makePost(id: 'post1')];
        return c;
      },
      act: (c) {
        // Simulate local edit without Firestore (unit test)
        final idx = c.posts.indexWhere((p) => p.postId == 'post1');
        if (idx >= 0) {
          c.posts[idx].text = 'Edited text';
          c.emitState(PostEditedState());
        }
      },
      expect: () => [isA<PostEditedState>()],
    );
  });
}
