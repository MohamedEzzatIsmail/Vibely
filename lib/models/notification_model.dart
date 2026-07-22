enum NotificationType {
  postLike,
  postComment,
  commentLike,
  commentReply,
  message,
  follow,
  mention,
  blocked,
}

class AppNotification {
  String? id;
  NotificationType type;
  String fromUserId;
  String fromUserName;
  String fromUserImage;
  String? postId;
  String? commentId;
  String? replyId;
  String? chatId;
  String? text;
  bool isSeen;
  bool isRead;
  String dateTime;
  /// True when [chatId] refers to a Groups/{id} document instead of a
  /// direct Chats/{id} document. Used to route message-tap navigation.
  bool isGroup;

  AppNotification({
    this.id,
    required this.type,
    required this.fromUserId,
    required this.fromUserName,
    required this.fromUserImage,
    this.postId,
    this.commentId,
    this.replyId,
    this.chatId,
    this.text,
    this.isSeen = false,
    this.isRead = false,
    required this.dateTime,
    this.isGroup = false,
  });

  static String typeToString(NotificationType type) =>
      type.toString().split('.').last;

  static NotificationType stringToType(String type) {
    switch (type) {
      case 'postLike':     return NotificationType.postLike;
      case 'postComment':  return NotificationType.postComment;
      case 'commentLike':  return NotificationType.commentLike;
      case 'commentReply': return NotificationType.commentReply;
      case 'message':      return NotificationType.message;
      case 'follow':       return NotificationType.follow;
      case 'mention':      return NotificationType.mention;
      case 'blocked':      return NotificationType.blocked;
      default:             return NotificationType.postLike;
    }
  }

  AppNotification.fromJson(Map<String, dynamic> json)
      : type = stringToType(json['type']),
        fromUserId = json['fromUserId'],
        fromUserName = json['fromUserName'],
        fromUserImage = json['fromUserImage'],
        postId = json['postId'],
        commentId = json['commentId'],
        replyId = json['replyId'],
        chatId = json['chatId'],
        text = json['text'],
        isSeen = json['isSeen'] ?? false,
        isRead = json['isRead'] ?? false,
        dateTime = json['dateTime'],
        isGroup = json['isGroup'] ?? false {
    id = json['id'];
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'type': typeToString(type),
    'fromUserId': fromUserId,
    'fromUserName': fromUserName,
    'fromUserImage': fromUserImage,
    'postId': postId,
    'commentId': commentId,
    'replyId': replyId,
    'chatId': chatId,
    'text': text,
    'isSeen': isSeen,
    'isRead': isRead,
    'dateTime': dateTime,
    'isGroup': isGroup,
  };
}