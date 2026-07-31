// lib/models/user_model.dart
// Merged: original fields + chat upgrade additions (pinnedChats, blockedUids already present)
// Nothing removed — only added pinnedChats which was used in chat_cubit.dart

class UserModel {
  String? uid;
  String? name;
  String? email;
  String? phone;
  String? image;
  String? cover;
  String? bio;
  bool? isVerified;
  /// Whether the user has confirmed ownership of their email address via
  /// the Firebase Auth verification link. Distinct from [isVerified],
  /// which is the "verified account" blue-checkmark badge.
  bool emailVerified;

  // ── Follow system ──────────────────────────────────────────────────────────
  List<String> followersUids;
  List<String> followingUids;

  // ── Privacy & account ──────────────────────────────────────────────────────
  bool isPrivateAccount;
  bool notificationsEnabled;
  bool privacyNotifications;
  bool notifyOnPostLike;
  bool notifyOnComment;
  bool notifyOnCommentLike;
  bool notifyOnReply;
  bool notifyOnMessage;
  bool notifyOnFollow;
  bool notifyOnMention;        // added in document

  // ── Bookmarks ──────────────────────────────────────────────────────────────
  List<String> bookmarkedPostIds;

  // ── Online presence ────────────────────────────────────────────────────────
  bool isOnline;
  String? lastSeen;

  // ── Privacy: hide personal info ────────────────────────────────────────────
  bool hideEmail;
  bool hidePhone;

  // ── Blocked ────────────────────────────────────────────────────────────────
  List<String> blockedUids;
  /// UIDs of users who have blocked ME. Maintained by ChatRepository
  /// whenever someone blocks/unblocks this user — lets us know we've been
  /// blocked without fetching the other person's document.
  List<String> blockedByUids;

  // ── Close friends (stories) ────────────────────────────────────────────────
  List<String> closeFriendsUids;  // added in document

  // ── Chat upgrade additions ─────────────────────────────────────────────────
  /// UIDs of conversations this user has pinned — persisted to Firestore.
  /// Read back in ChatCubit.setCurrentUser() to restore pinnedMap on login.
  List<String> pinnedChats;

  UserModel({
    this.uid,
    this.name,
    this.email,
    this.phone,
    this.image,
    this.cover,
    this.bio,
    this.isVerified,
    this.emailVerified        = false,
    this.followersUids        = const [],
    this.followingUids        = const [],
    this.isPrivateAccount     = false,
    this.notificationsEnabled = true,
    this.privacyNotifications = false,
    this.notifyOnPostLike     = true,
    this.notifyOnComment      = true,
    this.notifyOnCommentLike  = true,
    this.notifyOnReply        = true,
    this.notifyOnMessage      = true,
    this.notifyOnFollow       = true,
    this.notifyOnMention      = true,
    this.bookmarkedPostIds    = const [],
    this.isOnline             = false,
    this.lastSeen,
    this.hideEmail            = false,
    this.hidePhone            = false,
    this.blockedUids          = const [],
    this.blockedByUids        = const [],
    this.closeFriendsUids     = const [],
    this.pinnedChats          = const [],   // NEW
  });

  UserModel.fromJson(Map<String, dynamic> json)
      : uid                  = json['uid']          as String?,
        name                 = json['name']         as String?,
        email                = json['email']        as String?,
        phone                = json['phone']        as String?,
        image                = json['image']        as String?,
        cover                = json['cover']        as String?,
        bio                  = json['bio']          as String?,
        isVerified           = json['isVerified']   as bool?,
        emailVerified        = (json['emailVerified'] as bool?) ?? false,
        followersUids        = List<String>.from(json['followersUids']     ?? []),
        followingUids        = List<String>.from(json['followingUids']     ?? []),
        isPrivateAccount     = (json['isPrivateAccount']     as bool?) ?? false,
        notificationsEnabled = (json['notificationsEnabled'] as bool?) ?? true,
        privacyNotifications = (json['privacyNotifications'] as bool?) ?? false,
        notifyOnPostLike     = (json['notifyOnPostLike']     as bool?) ?? true,
        notifyOnComment      = (json['notifyOnComment']      as bool?) ?? true,
        notifyOnCommentLike  = (json['notifyOnCommentLike']  as bool?) ?? true,
        notifyOnReply        = (json['notifyOnReply']        as bool?) ?? true,
        notifyOnMessage      = (json['notifyOnMessage']      as bool?) ?? true,
        notifyOnFollow       = (json['notifyOnFollow']       as bool?) ?? true,
        notifyOnMention      = (json['notifyOnMention']      as bool?) ?? true,
        bookmarkedPostIds    = List<String>.from(json['bookmarkedPostIds']  ?? []),
        isOnline             = (json['isOnline']     as bool?) ?? false,
        lastSeen             = json['lastSeen']      as String?,
        hideEmail            = (json['hideEmail']    as bool?) ?? false,
        hidePhone            = (json['hidePhone']    as bool?) ?? false,
        blockedUids          = List<String>.from(json['blockedUids']        ?? []),
        blockedByUids        = List<String>.from(json['blockedByUids']      ?? []),
        closeFriendsUids     = List<String>.from(json['closeFriendsUids']   ?? []),
        pinnedChats          = List<String>.from(json['pinnedChats']        ?? []);  // NEW

  /// Fills in the fields that live in `Users/{uid}/private/data` instead of
  /// the main public document — real email/phone (overwriting whatever
  /// public-mirror value was already set by [fromJson]), block lists,
  /// bookmarks, pinned chats, and close friends. Call
  /// this only when merging in your OWN private data — never for a model
  /// built from another user's document, since they have no private doc
  /// you're allowed to read.
  void mergePrivateData(Map<String, dynamic> json) {
    email                = (json['realEmail'] as String?) ?? email;
    phone                = (json['realPhone'] as String?) ?? phone;
    emailVerified        = (json['emailVerified'] as bool?) ?? emailVerified;
    bookmarkedPostIds    = List<String>.from(json['bookmarkedPostIds'] ?? bookmarkedPostIds);
    hideEmail            = (json['hideEmail'] as bool?) ?? hideEmail;
    hidePhone            = (json['hidePhone'] as bool?) ?? hidePhone;
    blockedUids          = List<String>.from(json['blockedUids']      ?? blockedUids);
    blockedByUids        = List<String>.from(json['blockedByUids']    ?? blockedByUids);
    closeFriendsUids     = List<String>.from(json['closeFriendsUids'] ?? closeFriendsUids);
    pinnedChats          = List<String>.from(json['pinnedChats']      ?? pinnedChats);
  }

  /// The subset of fields that belong in `Users/{uid}/private/data`, keyed
  /// exactly as [mergePrivateData] expects to read them back.
  Map<String, dynamic> toPrivateMap() => {
        'realEmail':            email,
        'realPhone':            phone,
        'emailVerified':        emailVerified,
        'bookmarkedPostIds':    bookmarkedPostIds,
        'hideEmail':            hideEmail,
        'hidePhone':            hidePhone,
        'blockedUids':          blockedUids,
        'blockedByUids':        blockedByUids,
        'closeFriendsUids':     closeFriendsUids,
        'pinnedChats':          pinnedChats,
      };

  /// The subset of fields that belong on the public `Users/{uid}` document —
  /// readable by any signed-in user. `email`/`phone` here are a MIRROR of
  /// the real values, nulled out when hideEmail/hidePhone is set, so a
  /// direct Firestore read (bypassing the app's own UI) can't see them
  /// either. The true, always-present values live in [toPrivateMap] so the
  /// owner can still edit them from Settings even while hidden from others.
  Map<String, dynamic> toMap() => {
        'uid':                  uid,
        'name':                 name,
        'email':                hideEmail ? null : email,
        'phone':                hidePhone ? null : phone,
        'image':                image,
        'cover':                cover,
        'bio':                  bio,
        'isVerified':           isVerified,
        'followersUids':        followersUids,
        'followingUids':        followingUids,
        'isPrivateAccount':     isPrivateAccount,
        'isOnline':             isOnline,
        'lastSeen':             lastSeen,
        // Notification preferences stay public (not truly sensitive, and
        // NotificationService.send() has to read the RECIPIENT's own
        // preferences from whoever else's device is triggering the
        // notification — that only works if these are readable cross-user).
        'notificationsEnabled': notificationsEnabled,
        'privacyNotifications': privacyNotifications,
        'notifyOnPostLike':     notifyOnPostLike,
        'notifyOnComment':      notifyOnComment,
        'notifyOnCommentLike':  notifyOnCommentLike,
        'notifyOnReply':        notifyOnReply,
        'notifyOnMessage':      notifyOnMessage,
        'notifyOnFollow':       notifyOnFollow,
        'notifyOnMention':      notifyOnMention,
      };

  // ── Convenience helpers ────────────────────────────────────────────────────
  int  get followersCount   => followersUids.length;
  int  get followingCount   => followingUids.length;
  bool isFollowedBy(String uid) => followersUids.contains(uid);
  bool isFollowing(String uid)  => followingUids.contains(uid);
  bool hasBookmarked(String postId) => bookmarkedPostIds.contains(postId);
  bool hasBlocked(String uid)   => blockedUids.contains(uid);
  bool hasBlockedMe(String uid) => blockedByUids.contains(uid);
  /// True if either side has blocked the other.
  bool isBlockedWith(String uid) => hasBlocked(uid) || hasBlockedMe(uid);
  bool isCloseFriend(String uid) => closeFriendsUids.contains(uid);

  UserModel copyWith({
    String? name,
    String? bio,
    String? image,
    String? cover,
    String? phone,
    bool? isPrivateAccount,
    bool? emailVerified,
    bool? notificationsEnabled,
    bool? privacyNotifications,
    bool? notifyOnPostLike,
    bool? notifyOnComment,
    bool? notifyOnCommentLike,
    bool? notifyOnReply,
    bool? notifyOnMessage,
    bool? notifyOnFollow,
    bool? notifyOnMention,
    List<String>? followersUids,
    List<String>? followingUids,
    List<String>? bookmarkedPostIds,
    List<String>? blockedUids,
    List<String>? blockedByUids,
    List<String>? closeFriendsUids,
    List<String>? pinnedChats,       // NEW
    bool? isOnline,
    String? lastSeen,
    bool? hideEmail,
    bool? hidePhone,
  }) =>
      UserModel(
        uid:                  uid,
        email:                email,
        isVerified:           isVerified,
        emailVerified:        emailVerified       ?? this.emailVerified,
        name:                 name                ?? this.name,
        bio:                  bio                 ?? this.bio,
        image:                image               ?? this.image,
        cover:                cover               ?? this.cover,
        phone:                phone               ?? this.phone,
        isPrivateAccount:     isPrivateAccount    ?? this.isPrivateAccount,
        notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
        privacyNotifications: privacyNotifications ?? this.privacyNotifications,
        notifyOnPostLike:     notifyOnPostLike    ?? this.notifyOnPostLike,
        notifyOnComment:      notifyOnComment     ?? this.notifyOnComment,
        notifyOnCommentLike:  notifyOnCommentLike ?? this.notifyOnCommentLike,
        notifyOnReply:        notifyOnReply       ?? this.notifyOnReply,
        notifyOnMessage:      notifyOnMessage     ?? this.notifyOnMessage,
        notifyOnFollow:       notifyOnFollow      ?? this.notifyOnFollow,
        notifyOnMention:      notifyOnMention     ?? this.notifyOnMention,
        followersUids:        followersUids       ?? this.followersUids,
        followingUids:        followingUids       ?? this.followingUids,
        bookmarkedPostIds:    bookmarkedPostIds   ?? this.bookmarkedPostIds,
        blockedUids:          blockedUids         ?? this.blockedUids,
        blockedByUids:        blockedByUids       ?? this.blockedByUids,
        closeFriendsUids:     closeFriendsUids    ?? this.closeFriendsUids,
        pinnedChats:          pinnedChats         ?? this.pinnedChats,  // NEW
        isOnline:             isOnline            ?? this.isOnline,
        lastSeen:             lastSeen            ?? this.lastSeen,
        hideEmail:            hideEmail           ?? this.hideEmail,
        hidePhone:            hidePhone           ?? this.hidePhone,
      );
}
