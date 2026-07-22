// lib/models/story_model.dart

class StoryModel {
  final String storyId;
  final String uid;
  final String userName;
  final String userImage;
  final String mediaUrl;
  final bool isVideo;
  final String? caption;
  final String dateTime;
  final List<String> seenBy;
  final String expiresAt;
  final int? trimStartMs;
  final int? trimEndMs;
  final String? thumbnailUrl;
  final Map<String, List<String>> reactions;
  final int commentCount;

  /// NEW: when true, only users in the uploader's closeFriendsUids can see this story
  final bool isCloseFriends;

  StoryModel({
    required this.storyId,
    required this.uid,
    required this.userName,
    required this.userImage,
    required this.mediaUrl,
    required this.isVideo,
    this.caption,
    required this.dateTime,
    this.seenBy = const [],
    required this.expiresAt,
    this.trimStartMs,
    this.trimEndMs,
    this.thumbnailUrl,
    this.reactions = const {},
    this.commentCount = 0,
    this.isCloseFriends = false,
  });

  bool get isExpired =>
      DateTime.now().isAfter(DateTime.parse(expiresAt));

  StoryModel.fromJson(Map<String, dynamic> json)
      : storyId = json['storyId'] ?? '',
        uid = json['uid'] ?? '',
        userName = json['userName'] ?? '',
        userImage = json['userImage'] ?? '',
        mediaUrl = json['mediaUrl'] ?? '',
        isVideo = json['isVideo'] ?? false,
        caption = json['caption'],
        dateTime = json['dateTime'] ?? '',
        seenBy = List<String>.from(json['seenBy'] ?? []),
        expiresAt = json['expiresAt'] ?? '',
        trimStartMs = json['trimStartMs'] as int?,
        trimEndMs = json['trimEndMs'] as int?,
        thumbnailUrl = json['thumbnailUrl'] as String?,
        reactions = (json['reactions'] as Map<String, dynamic>? ?? {}).map(
          (k, v) => MapEntry(k, List<String>.from(v as List)),
        ),
        commentCount = (json['commentCount'] as int?) ?? 0,
        isCloseFriends = json['isCloseFriends'] ?? false;

  Map<String, dynamic> toMap() => {
        'storyId': storyId,
        'uid': uid,
        'userName': userName,
        'userImage': userImage,
        'mediaUrl': mediaUrl,
        'isVideo': isVideo,
        'caption': caption,
        'dateTime': dateTime,
        'seenBy': seenBy,
        'expiresAt': expiresAt,
        if (trimStartMs != null) 'trimStartMs': trimStartMs,
        if (trimEndMs != null) 'trimEndMs': trimEndMs,
        if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
        'reactions': reactions.map((k, v) => MapEntry(k, v)),
        'commentCount': commentCount,
        'isCloseFriends': isCloseFriends,
      };
}
