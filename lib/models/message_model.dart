// lib/models/message_model.dart

class MessageModel {
  String? senderId;
  String? receiverId;
  String? text;
  String? dateTime;
  bool? seen;
  /// True once the recipient's device has confirmed receipt of the push
  /// for this message (set by ChatRepository.markDelivered — see
  /// fcm_service.dart) — independent of `seen`, which only flips once
  /// they open the conversation. Mirrors WhatsApp's grey-vs-blue ticks.
  bool? delivered;
  String? deliveredAt;
  bool? deleted;
  bool? edited;
  String? videoUrl;
  String? imageUrl;      // NEW: image messages
  String? audioUrl;      // NEW: voice messages
  int? audioDuration;    // voice message duration in seconds
  List<double> waveformData; // amplitude bars for waveform display
  bool? isGroupMsg;      // NEW: group chat flag

  // Delete-for-me / delete-for-everyone
  // 'deleted'       = true means hard delete (for everyone, sender's own msgs)
  // 'deletedForMe'  = list of uids who hid this message on their side
  // 'deletedByOther'= true means the other party deleted their own msg (hint shown)
  List<String> deletedForMe;
  bool? deletedByOther;  // NEW: hint "X deleted this message"

  // Forward
  bool? isForwarded;    // NEW

  // Shared post mini-card
  String? sharedPostId;
  String? sharedPostOwnerName;
  String? sharedPostOwnerImage;
  String? sharedPostText;
  String? sharedPostImage;
  String? sharedPostVideo;
  bool? sharedPostDeleted;

  // Reply-to (WhatsApp-style quote)
  String? replyToId;
  String? replyToSenderName;
  String? replyToText;
  String? replyToMediaUrl;
  bool? replyToIsStory;

  // Emoji reactions  { emoji: [uid, uid, …] }
  Map<String, List<String>> reactions;

  MessageModel({
    this.senderId,
    this.receiverId,
    this.text,
    this.dateTime,
    this.seen,
    this.delivered,
    this.deliveredAt,
    this.deleted,
    this.edited,
    this.videoUrl,
    this.imageUrl,
    this.audioUrl,
    this.audioDuration,
    this.waveformData = const [],
    this.isGroupMsg,
    this.deletedForMe = const [],
    this.deletedByOther,
    this.isForwarded,
    this.sharedPostId,
    this.sharedPostOwnerName,
    this.sharedPostOwnerImage,
    this.sharedPostText,
    this.sharedPostImage,
    this.sharedPostVideo,
    this.sharedPostDeleted,
    this.replyToId,
    this.replyToSenderName,
    this.replyToText,
    this.replyToMediaUrl,
    this.replyToIsStory,
    this.reactions = const {},
  });

  bool get isSharedPost => sharedPostId != null && sharedPostId!.isNotEmpty;
  bool get hasVideo     => videoUrl != null && videoUrl!.isNotEmpty;
  bool get hasImage     => imageUrl != null && imageUrl!.isNotEmpty;
  bool get hasAudio     => audioUrl != null && audioUrl!.isNotEmpty;
  bool get isDeleted    => deleted == true;
  bool get hasReply     => replyToId != null && replyToId!.isNotEmpty;

  /// Returns true if this message should be hidden for [uid]
  bool isHiddenFor(String uid) =>
      deleted == true || (deletedForMe.contains(uid));

  MessageModel.fromJson(Map<String, dynamic> json)
      : senderId         = json['senderId'],
        receiverId       = json['receiverId'],
        text             = json['text'],
        dateTime         = json['dateTime'],
        seen             = json['seen'] ?? false,
        delivered        = json['delivered'] ?? false,
        deliveredAt      = json['deliveredAt'],
        deleted          = json['deleted'] ?? false,
        edited           = json['edited'] ?? false,
        videoUrl         = json['videoUrl'],
        imageUrl         = json['imageUrl'],
        audioUrl         = json['audioUrl'],
        audioDuration    = json['audioDuration'] as int?,
        waveformData     = List<double>.from(
            (json['waveformData'] as List<dynamic>? ?? [])
                .map((e) => (e as num).toDouble())),
        isGroupMsg       = json['isGroupMsg'] as bool?,
        deletedForMe     = List<String>.from(json['deletedForMe'] ?? []),
        deletedByOther   = json['deletedByOther'] as bool?,
        isForwarded      = json['isForwarded'] as bool?,
        sharedPostId         = json['sharedPostId'],
        sharedPostOwnerName  = json['sharedPostOwnerName'],
        sharedPostOwnerImage = json['sharedPostOwnerImage'],
        sharedPostText       = json['sharedPostText'],
        sharedPostImage      = json['sharedPostImage'],
        sharedPostVideo      = json['sharedPostVideo'],
        sharedPostDeleted    = json['sharedPostDeleted'] ?? false,
        replyToId         = json['replyToId'],
        replyToSenderName = json['replyToSenderName'],
        replyToText       = json['replyToText'],
        replyToMediaUrl   = json['replyToMediaUrl'],
        replyToIsStory    = json['replyToIsStory'] ?? false,
        reactions = (json['reactions'] as Map<String, dynamic>? ?? {}).map(
          (k, v) => MapEntry(k, List<String>.from(v as List)),
        );

  Map<String, dynamic> toMap() => {
        'senderId':   senderId,
        'receiverId': receiverId,
        'text':       text,
        'dateTime':   dateTime,
        'seen':       seen ?? false,
        if (delivered == true) 'delivered': true,
        if (deliveredAt != null) 'deliveredAt': deliveredAt,
        'deleted':    deleted ?? false,
        'edited':     edited ?? false,
        if (videoUrl       != null) 'videoUrl':       videoUrl,
        if (imageUrl       != null) 'imageUrl':       imageUrl,
        if (audioUrl       != null) 'audioUrl':       audioUrl,
        if (audioDuration  != null) 'audioDuration':  audioDuration,
        if (waveformData.isNotEmpty) 'waveformData':  waveformData,
        if (isGroupMsg     != null) 'isGroupMsg':     isGroupMsg,
        'deletedForMe':   deletedForMe,
        if (deletedByOther == true)  'deletedByOther': true,
        if (isForwarded    == true)  'isForwarded':    true,
        if (sharedPostId         != null) 'sharedPostId':         sharedPostId,
        if (sharedPostOwnerName  != null) 'sharedPostOwnerName':  sharedPostOwnerName,
        if (sharedPostOwnerImage != null) 'sharedPostOwnerImage': sharedPostOwnerImage,
        if (sharedPostText       != null) 'sharedPostText':       sharedPostText,
        if (sharedPostImage      != null) 'sharedPostImage':      sharedPostImage,
        if (sharedPostVideo      != null) 'sharedPostVideo':      sharedPostVideo,
        if (sharedPostDeleted == true) 'sharedPostDeleted': true,
        if (replyToId         != null) 'replyToId':         replyToId,
        if (replyToSenderName != null) 'replyToSenderName': replyToSenderName,
        if (replyToText       != null) 'replyToText':       replyToText,
        if (replyToMediaUrl   != null) 'replyToMediaUrl':   replyToMediaUrl,
        if (replyToIsStory == true)    'replyToIsStory':    true,
        'reactions': reactions.map((k, v) => MapEntry(k, v)),
      };
}
