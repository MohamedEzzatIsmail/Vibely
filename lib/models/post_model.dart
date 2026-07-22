// lib/models/post_model.dart
//
// Drop-in replacement for the original PostModel.
// Key change: adds `List<String> postImages` alongside the legacy `String? postImage`.
// fromJson reads BOTH formats for backwards compatibility with existing Firestore docs.
// toMap() writes BOTH so old clients still work.

class PostModel {
  String? postId;
  String? uid;
  String? name;
  String? image;
  String? text;

  // ── Legacy field (comma-separated) — kept for backward compat ─────────────
  // UI code should prefer `postImages` (the List).
  String? postImage;

  // ── NEW: List of image URLs ───────────────────────────────────────────────
  // Populated from `postImages` array in Firestore (new docs) or by splitting
  // the legacy `postImage` comma-string (old docs).
  List<String> postImages;

  String? postVideo;
  String? videoThumbnail;
  String? dateTime;
  String? privacy;

  List<String> hashtags;
  List<String> mentionedUids;

  int likes;
  int dislikes;
  int commentsCount;

  Map<String, dynamic> userReactions;
  Map<String, int> reactionCounts;

  int bookmarkCount;
  String? editedAt;

  PostModel({
    this.postId,
    this.uid,
    this.name,
    this.image,
    this.text,
    this.postImage,
    List<String>? postImages,
    this.postVideo,
    this.videoThumbnail,
    this.dateTime,
    this.privacy = 'public',
    this.hashtags = const [],
    this.mentionedUids = const [],
    this.likes = 0,
    this.dislikes = 0,
    this.commentsCount = 0,
    Map<String, dynamic>? userReactions,
    Map<String, int>? reactionCounts,
    this.bookmarkCount = 0,
    this.editedAt,
  })  : postImages = postImages ??
            (postImage != null && postImage.isNotEmpty
                ? postImage
                    .split(',')
                    .map((s) => s.trim())
                    .where((s) => s.isNotEmpty)
                    .toList()
                : []),
        userReactions = userReactions ?? {},
        reactionCounts = reactionCounts ?? {};

  PostModel.fromJson(Map<String, dynamic> json)
      : likes = (json['likes'] as num?)?.toInt() ?? 0,
        dislikes = (json['dislikes'] as num?)?.toInt() ?? 0,
        commentsCount = (json['commentsCount'] as num?)?.toInt() ?? 0,
        bookmarkCount = (json['bookmarkCount'] as num?)?.toInt() ?? 0,
        hashtags = List<String>.from(json['hashtags'] ?? []),
        mentionedUids = List<String>.from(json['mentionedUids'] ?? []),
        userReactions =
            Map<String, dynamic>.from(json['userReactions'] ?? {}),
        reactionCounts = (() {
          final raw = json['reactionCounts'];
          if (raw == null) return <String, int>{};
          return (raw as Map<String, dynamic>).map(
            (k, v) => MapEntry(k, (v as num).toInt()),
          )..removeWhere((_, v) => v <= 0);
        })(),
        // ── postImages: prefer new List field, fall back to comma-string ────
        postImages = (() {
          // 1. New format: Firestore array field 'postImages'
          final newList = json['postImages'];
          if (newList is List && newList.isNotEmpty) {
            return List<String>.from(newList);
          }
          // 2. Legacy format: comma-separated string in 'postImage'
          final legacy = json['postImage'] as String?;
          if (legacy != null && legacy.isNotEmpty) {
            return legacy
                .split(',')
                .map((s) => s.trim())
                .where((s) => s.isNotEmpty)
                .toList();
          }
          return <String>[];
        })(),
        postImage = json['postImage'] as String? {
    postId = json['postId'] as String?;
    uid = json['uid'] as String?;
    name = json['name'] as String?;
    image = json['image'] as String?;
    text = json['text'] as String?;
    postVideo = json['postVideo'] as String?;
    videoThumbnail = json['videoThumbnail'] as String?;
    dateTime = json['dateTime'] as String?;
    privacy = (json['privacy'] as String?) ?? 'public';
    editedAt = json['editedAt'] as String?;
  }

  Map<String, dynamic> toMap() => {
        'postId': postId,
        'uid': uid,
        'name': name,
        'image': image,
        'text': text,
        // Write both formats so legacy clients still work
        'postImage': postImages.join(','),
        'postImages': postImages,
        'postVideo': postVideo,
        if (videoThumbnail != null) 'videoThumbnail': videoThumbnail,
        'dateTime': dateTime,
        'privacy': privacy ?? 'public',
        'hashtags': hashtags,
        'mentionedUids': mentionedUids,
        'likes': likes,
        'dislikes': dislikes,
        'commentsCount': commentsCount,
        'userReactions': userReactions,
        'reactionCounts': reactionCounts,
        'bookmarkCount': bookmarkCount,
        if (editedAt != null) 'editedAt': editedAt,
      };

  // ── Helpers ───────────────────────────────────────────────────────────────

  int totalReactions() =>
      reactionCounts.values.fold(0, (a, b) => a + b);

  double trendingScore() {
    if (dateTime == null) return 0;
    try {
      final ageHours =
          DateTime.now().difference(DateTime.parse(dateTime!)).inMinutes / 60.0;
      final engagement =
          totalReactions() + (commentsCount * 2) + (bookmarkCount * 1.5);
      return engagement / ((ageHours + 2).clamp(1, 9999) * 1.5);
    } catch (_) {
      return 0;
    }
  }

  /// Returns the current user's reaction key (e.g. 'like', 'love') or null.
  /// Handles both the legacy bool format and the new String format.
  String? myReaction(String? userId) {
    if (userId == null) return null;
    final r = userReactions[userId];
    if (r == null) return null;
    if (r is bool) return r ? 'like' : null;
    if (r is String) return r;
    return null;
  }

  static List<String> extractHashtags(String text) {
    final exp = RegExp(r'#(\w+)');
    return exp
        .allMatches(text)
        .map((m) => m.group(1)!.toLowerCase())
        .toList();
  }
}

// ── Reaction catalogue ────────────────────────────────────────────────────────
class PostReaction {
  final String key;
  final String emoji;
  final String label;
  final List<int> colors;

  const PostReaction({
    required this.key,
    required this.emoji,
    required this.label,
    required this.colors,
  });

  static const List<PostReaction> all = [
    PostReaction(
        key: 'like', emoji: '👍', label: 'Like', colors: [0xFF2196F3, 0xFF1565C0]),
    PostReaction(
        key: 'love', emoji: '❤️', label: 'Love', colors: [0xFFE91E63, 0xFFC2185B]),
    PostReaction(
        key: 'haha', emoji: '😂', label: 'Haha', colors: [0xFFFFB300, 0xFFFF8F00]),
    PostReaction(
        key: 'wow', emoji: '😮', label: 'Wow', colors: [0xFFFF9800, 0xFFE65100]),
    PostReaction(
        key: 'sad', emoji: '😢', label: 'Sad', colors: [0xFF78909C, 0xFF455A64]),
    PostReaction(
        key: 'angry', emoji: '😡', label: 'Angry', colors: [0xFFF44336, 0xFFB71C1C]),
  ];

  static PostReaction? byKey(String? key) {
    if (key == null) return null;
    try {
      return all.firstWhere((r) => r.key == key);
    } catch (_) {
      return null;
    }
  }
}
