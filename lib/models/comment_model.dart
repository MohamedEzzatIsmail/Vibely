class CommentModel {
  String? commentId;
  String? userId;
  String? userName;
  String? userImage;
  String? text;
  String? dateTime;

  int likes;
  int dislikes;
  int repliesCount;

  Map<String, dynamic> reactions;

  CommentModel({
    this.commentId,
    this.userId,
    this.userName,
    this.userImage,
    this.text,
    this.dateTime,
    this.likes = 0,
    this.dislikes = 0,
    this.repliesCount = 0,
    Map<String, dynamic>? reactions,
  }) : reactions = reactions ?? {};

  /// ---------------- FROM JSON ----------------
  CommentModel.fromJson(Map<String, dynamic> json)
      : likes = json['likes'] ?? 0,
        dislikes = json['dislikes'] ?? 0,
        repliesCount = json['repliesCount'] ?? 0,
        reactions = Map<String, dynamic>.from(json['reactions'] ?? {}) {
    commentId = json['commentId'];
    userId = json['userId'];
    userName = json['userName'];
    userImage = json['userImage'];
    text = json['text'];
    dateTime = json['dateTime'];
  }

  /// ---------------- TO MAP ----------------
  Map<String, dynamic> toMap() {
    return {
      'commentId': commentId,
      'userId': userId,
      'userName': userName,
      'userImage': userImage,
      'text': text,
      'dateTime': dateTime,
      'likes': likes,
      'dislikes': dislikes,
      'repliesCount': repliesCount,
      'reactions': reactions,
    };
  }
}