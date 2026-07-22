import 'package:flutter_test/flutter_test.dart';
import 'package:vibely/models/user_model.dart';

void main() {
  group('UserModel', () {
    late UserModel original;

    setUp(() {
      original = UserModel(
        uid: 'user1',
        name: 'Alice',
        bio: 'My bio',
        email: 'alice@example.com',
        phone: '+201234567890',
        followersUids: ['f1', 'f2'],
        followingUids: ['g1'],
        blockedUids: ['b1'],
        bookmarkedPostIds: ['post1'],
        closeFriendsUids: ['cf1'],
        notifyOnMention: true,
        notificationsEnabled: true,
        notifyOnPostLike: true,
        notifyOnComment: true,
        notifyOnCommentLike: true,
        notifyOnReply: true,
        notifyOnMessage: true,
        notifyOnFollow: true,
      );
    });

    // ── copyWith ──────────────────────────────────────────────────────────────
    test('copyWith: does not mutate the original', () {
      final copy = original.copyWith(name: 'Bob', bio: 'New bio');
      expect(original.name, 'Alice');
      expect(original.bio, 'My bio');
      expect(copy.name, 'Bob');
      expect(copy.bio, 'New bio');
    });

    test('copyWith: preserves uid and email (not copyWith params)', () {
      final copy = original.copyWith(name: 'Charlie');
      expect(copy.uid, 'user1');
      expect(copy.email, 'alice@example.com');
    });

    test('copyWith: preserves all list fields not explicitly overridden', () {
      final copy = original.copyWith(name: 'Dave');
      expect(copy.followersUids, ['f1', 'f2']);
      expect(copy.followingUids, ['g1']);
      expect(copy.blockedUids, ['b1']);
      expect(copy.bookmarkedPostIds, ['post1']);
      expect(copy.closeFriendsUids, ['cf1']);
    });

    test('copyWith: overrides closeFriendsUids when provided', () {
      final copy = original.copyWith(closeFriendsUids: ['cf1', 'cf2']);
      expect(copy.closeFriendsUids.length, 2);
      expect(copy.closeFriendsUids, contains('cf2'));
      // Original unchanged
      expect(original.closeFriendsUids.length, 1);
    });

    test('copyWith: overrides notifyOnMention when provided', () {
      final copy = original.copyWith(notifyOnMention: false);
      expect(copy.notifyOnMention, isFalse);
      expect(original.notifyOnMention, isTrue); // unchanged
    });

    // ── hasBlocked ────────────────────────────────────────────────────────────
    test('hasBlocked: returns true for blocked uid', () {
      expect(original.hasBlocked('b1'), isTrue);
    });

    test('hasBlocked: returns false for non-blocked uid', () {
      expect(original.hasBlocked('not_blocked'), isFalse);
    });

    // ── isFollowedBy / isFollowing ─────────────────────────────────────────────
    test('isFollowedBy: true when uid is in followersUids', () {
      expect(original.isFollowedBy('f1'), isTrue);
    });

    test('isFollowedBy: false when uid is not a follower', () {
      expect(original.isFollowedBy('nobody'), isFalse);
    });

    test('isFollowing: true when uid is in followingUids', () {
      expect(original.isFollowing('g1'), isTrue);
    });

    test('isFollowing: false when not following', () {
      expect(original.isFollowing('nobody'), isFalse);
    });

    // ── isCloseFriend ──────────────────────────────────────────────────────────
    test('isCloseFriend: true for uid in closeFriendsUids', () {
      expect(original.isCloseFriend('cf1'), isTrue);
    });

    test('isCloseFriend: false for uid not in closeFriendsUids', () {
      expect(original.isCloseFriend('other'), isFalse);
    });

    // ── Counts ────────────────────────────────────────────────────────────────
    test('followersCount: correct length', () {
      expect(original.followersCount, 2);
    });

    test('followingCount: correct length', () {
      expect(original.followingCount, 1);
    });

    // ── notifyOnMention ────────────────────────────────────────────────────────
    test('notifyOnMention: defaults to true in constructor', () {
      final user = UserModel(uid: 'u1', name: 'Test');
      expect(user.notifyOnMention, isTrue);
    });

    test('notifyOnMention: can be set to false', () {
      final user = UserModel(uid: 'u1', notifyOnMention: false);
      expect(user.notifyOnMention, isFalse);
    });

    // ── closeFriendsUids ──────────────────────────────────────────────────────
    test('closeFriendsUids: defaults to empty list', () {
      final user = UserModel(uid: 'u1');
      expect(user.closeFriendsUids, isEmpty);
    });

    // ── fromJson / toMap round-trip ────────────────────────────────────────────
    test('fromJson/toMap: round-trip preserves notifyOnMention', () {
      final map = original.toMap();
      final decoded = UserModel.fromJson(map);
      expect(decoded.notifyOnMention, isTrue);
    });

    test('fromJson/toMap: round-trip preserves closeFriendsUids', () {
      final map = original.toMap();
      final decoded = UserModel.fromJson(map);
      expect(decoded.closeFriendsUids, ['cf1']);
    });

    test('fromJson: defaults notifyOnMention to true if field missing', () {
      final json = {'uid': 'u1', 'name': 'Bob'};
      final user = UserModel.fromJson(json);
      expect(user.notifyOnMention, isTrue);
    });

    test('fromJson: defaults closeFriendsUids to [] if field missing', () {
      final json = {'uid': 'u1', 'name': 'Bob'};
      final user = UserModel.fromJson(json);
      expect(user.closeFriendsUids, isEmpty);
    });

    test('fromJson: reads closeFriendsUids list', () {
      final json = {
        'uid': 'u1',
        'name': 'Bob',
        'closeFriendsUids': ['cf1', 'cf2'],
      };
      final user = UserModel.fromJson(json);
      expect(user.closeFriendsUids.length, 2);
      expect(user.closeFriendsUids, contains('cf1'));
    });

    test('fromJson: reads notifyOnMention = false', () {
      final json = {
        'uid': 'u1',
        'name': 'Bob',
        'notifyOnMention': false,
      };
      final user = UserModel.fromJson(json);
      expect(user.notifyOnMention, isFalse);
    });

    // ── hasBookmarked ─────────────────────────────────────────────────────────
    test('hasBookmarked: true when postId in bookmarkedPostIds', () {
      expect(original.hasBookmarked('post1'), isTrue);
    });

    test('hasBookmarked: false when not bookmarked', () {
      expect(original.hasBookmarked('post999'), isFalse);
    });
  });
}
