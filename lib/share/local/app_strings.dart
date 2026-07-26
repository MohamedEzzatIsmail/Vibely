// lib/share/local/app_strings.dart
//
// All UI-generated strings in one place.
// Usage: AppStrings.of(context).homeTitle
// Adding a new string: add a getter below in both _En and _Ar.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../layout/cubit/language/language_cubit.dart';

part 'app_strings_en.dart';
part 'app_strings_ar.dart';

abstract class AppStrings {
  // ── Factory ───────────────────────────────────────────────────────────────
  factory AppStrings.of(BuildContext context) {
    final lang = BlocProvider.of<LanguageCubit>(context, listen: false);
    return lang.isArabic ? const _Ar() : const _En();
  }

  // ── Navigation / tabs ────────────────────────────────────────────────────
  String get home;
  String get chats;
  String get explore;
  String get notifications;
  String get profile;

  // ── Auth ─────────────────────────────────────────────────────────────────
  String get welcomeBack;
  String get loginSubtitle;
  String get email;
  String get password;
  String get forgotPassword;
  String get login;
  String get noAccount;
  String get registerNow;
  String get createAccount;
  String get registerSubtitle;
  String get fullName;
  String get phone;
  String get addProfilePhoto;
  String get photoOptional;
  String get alreadyHaveAccount;
  String get signIn;

  // ── Feed ─────────────────────────────────────────────────────────────────
  String get whatsOnYourMind;
  String get post;
  String get like;
  String get comment;
  String get share;
  String get follow;
  String get following;
  String get unfollow;
  String get followers;
  String get noPostsYet;

  // ── Chat ─────────────────────────────────────────────────────────────────
  String get messages;
  String get typeAMessage;
  String get today;
  String get yesterday;
  String get online;
  String get offline;
  String get typing;
  String get voiceMessage;
  String get deleteMessage;
  String get editMessage;
  String get replyTo;
  String get forward;
  String get pinMessage;
  String get copyText;
  String get newChat;
  String get createGroup;
  String get noChatsYet;
  String get holdToRecord;
  String get sentAVoiceMessage;

  // ── Settings ─────────────────────────────────────────────────────────────
  String get settings;
  String get editProfile;
  String get appearance;
  String get darkMode;
  String get lightThemeComingSoon;
  String get language;
  String get notifications2;
  String get privacy;
  String get blockedAccounts;
  String get closeFriends;
  String get termsOfService;
  String get privacyPolicy;
  String get logOut;
  String get deleteAccount;

  // ── Explore / Search ─────────────────────────────────────────────────────
  String get searchPeople;
  String get searchHashtags;
  String get trending;
  String get noResults;

  // ── Profile ───────────────────────────────────────────────────────────────
  String get posts;
  String get bio;
  String get editProfileTitle;
  String get saveChanges;
  String get displayName;
  String get currentPassword;
  String get newPassword;
  String get changeCoverPhoto;
  String get changePasswordSection;
  String get keepCurrentPassword;

  // ── Bookmarks ─────────────────────────────────────────────────────────────
  String get bookmarks;
  String get noBookmarks;

  // ── Notifications ─────────────────────────────────────────────────────────
  String get noNotifications;
  String get notificationsTitle;

  // ── Close friends ─────────────────────────────────────────────────────────
  String get closeFriendsTitle;
  String get closeFriendsInfo;
  String get searchPeopleHint;
  String get noFollowersYet;
  String get selected;

  // ── Blocked users ─────────────────────────────────────────────────────────
  String get blockedAccountsTitle;
  String get unblock;
  String get unblockConfirmTitle;
  String get unblockConfirmBody;
  String get cancel;
  String get noBlockedAccounts;
  String get swipeToUnblock;
  String get unblockFailed;

  // ── General ───────────────────────────────────────────────────────────────
  String get save;
  String get discard;
  String get discardChanges;
  String get discardChangesBody;
  String get stay;
  String get loading;
  String get error;
  String get retry;
  String get ok;
  String get delete;
  String get confirm;
  String get photoLibrary;
  String get camera;
  String get sendButton;

  // ── Onboarding dialogs ───────────────────────────────────────────────────
  String get chooseLanguage;
  String get english;
  String get arabic;
  String get privacyTitle;
  String get privacyMessage;
  String get privacyPolicyLink;
  String get iAgree;
  String get privacyMustRead;

  // ── Extended strings (chat, feeds, stories, groups) ─────────────────────
  String get replyLabel;
  String get forwardTo;
  String get reactions;
  String get disappearingMessages;
  String get editingMessage;
  String get youDeletedMessage;
  String get deleteForMe;
  String get deleteForEveryone;
  String get deleteMessages;
  String get deletedMessages;
  String get blockUser;
  String get submitReport;
  String get videoCall;
  String get search;
  String get unmute;
  String get pinChat;
  String get unpinChat;
  String get archiveChat;
  String get unarchiveChat;
  String get noMessagesYet;
  String get sayHello;
  String get encryptedNote;
  String get selectDuration;
  String get off;
  String get sec30;
  String get min5;
  String get hour1;
  String get hour24;
  String get week1;
  String get onlineStatus;
  String get offlineStatus;
  String get recordVideo;
  String get forwardLabel;
  String get copyLabel;
  String get pinLabel;
  String get muteLabel;
  String get editPost;
  String get deletePost;
  String get deletePostConfirm;
  String get bookmarkPost;
  String get bookmarked;
  String get forYou;
  String get closeCircle;
  String get searchVibely;
  String get searchPeoplePosts;
  String get exploreLabel;
  String get newVoices;
  String get noPostsMessage;
  String get publicLabel;
  String get followersLabel;
  String get onlyMeLabel;
  String get editPostTitle;
  String get addComment;
  String get noComments;
  String get deleteComment;
  String get replyComment;
  String get deleteStory;
  String get deleteStoryConfirm;
  String get reportTitle;
  String get reportSubmit;
  String get createPostTitle;
  String get whatsHappening;
  String get postButton;
  String get addMedia;
  String get shareVia;
  String get noUsersYet;
  String get welcomeMessage;
  String get groupInfo;
  String get addMembers;
  String get leaveGroup;
  String get groupName;
  String get makeAdmin;
  String get removeFromGroup;
  String get viewProfile;
  String get mediaFiles;
  String get sharedLinks;

  // ── Settings – notifications section ─────────────────────────────────────
  String get sectionNotifications;
  String get enableNotifications;
  String get notifyPostLikes;
  String get notifyComments;
  String get notifyCommentLikes;
  String get notifyCommentReplies;
  String get notifyNewMessages;
  String get notifyNewFollowers;
  String get notifyMentions;
  String get notifyMentionsSubtitle;

  // ── Settings – privacy section ────────────────────────────────────────────
  String get sectionPrivacy;
  String get privateAccount;
  String get privateAccountSubtitle;
  String get hideEmail;
  String get hidePhone;
  String get blockedAccountsLabel;

  // ── Settings – about section ──────────────────────────────────────────────
  String get sectionAbout;
  String get versionLabel;
  String get madeByLabel;

  // ── Settings – close friends subtitle & logout ────────────────────────────
  String get closeFriendsSubtitle;
  String get logoutLabel;

  // ── Other profile – copy link ─────────────────────────────────────────────
  String get copyLink;
  String get profileLinkCopied;

  // ── Notifications screen ──────────────────────────────────────────────────
  String get markAllRead;

  // ── Group info ────────────────────────────────────────────────────────────
  String get renameGroup;
  String get onlyAdminsSend;
  String get membersCanRead;
  String get members;
  String get add;
  String get makeAdminLabel;
  String get removeFromGroupLabel;
  String get removeConfirmTitle;
  String get leaveGroupConfirmTitle;
  String get leaveGroupConfirmBody;
  String get deleteGroupTitle;
  String get adminBadge;
  String get cannotLeaveTitle;
  String get cannotLeaveBody;

  // ── Chat ─────────────────────────────────────────────────────────────────
  String get deleteForMeLabel;
  String get deleteForEveryoneLabel;
  String get deleteForEveryoneBody;
  String get copiedToClipboard;
  String get sharedMedia;
  String get reportSubmitted;
  String get reportUserTitle;
  String get blockConfirmTitle;
  String get blockConfirmBody;
  String get forwardedLabel;
  String get thisMessageDeleted;
  String get youDeletedThisMessage;
  String get holdToRecord2;

  // ── Stories ───────────────────────────────────────────────────────────────
  String get storyLinkCopied;
  String get replySent;
  String get deleteStoryTitle2;
  String get deleteStoryBody;
  String get videoUnavailable;
  String get holdLabel;
  String get commentsLabel;
  String get beFirstToComment;
  String get noViewersYet;
  String get uploadingStory;
  String get addToStory;

  // ── Report sheet ─────────────────────────────────────────────────────────
  String get reportThanks;
  String get whyReporting;
  String get submitReport2;

  // ── Feed / post actions ───────────────────────────────────────────────────
  String get writeSomethingFirst;
  String get waitBeforePosting;
  String get tryAgain;
  String get linkCopied;
  String get editPostLabel;
  String get bookmarkLabel;
  String get deletePostQuestion;
  String get cannotUndone;
  String get shareLabel;
  String get sendToLabel;
  String get sendLabel;

  // ── Profile ───────────────────────────────────────────────────────────────
  String get profileUpdated;
  String get verifiedLabel;
  String get accountInfoTitle;
  String get messageLabel;
  String get privateAccountTitle;
  String get privateAccountFollow;
  String get noPostsYetFull;
  String get blockUserQuestion;
  String get blockUserBody;
  String get changeCoverPhotoBtn;
  String get sharePost;
  String get more;
  String get people;

  // ── Chats screen ──────────────────────────────────────────────────────────
  String get messagesTitle;
  String get noUnreadMessages;
  String get noGroupsYet;
  String get deleteConversationLabel;
  String get deleteConversationTitle;
  String get deleteConversationBody;
  String get onlyAdminsCanSend;
  String get selectMembers;
  String get noConversationsYet;
  String get tapToStartChatting;
  String get exploreEmptyTitle;
  String get exploreEmptySubtitle;

  // ── Stories bar ───────────────────────────────────────────────────────────
  String get uploadingStoryBar;
  String get addToStoryBar;

  // ── Feed / post details ───────────────────────────────────────────────────
  String get noCommentsYet;
  String get replyLabel2;

  // ── Video trim ────────────────────────────────────────────────────────────
  String get next;
  String get goBack;
  String get loadingVideo;

  // ── Register / auth ───────────────────────────────────────────────────────
  String get emailNotVerifiedYet;
  String get verificationEmailResent;
  String get checkYourEmail;
  String get backToSignIn;
  String get takePhoto;
  String get chooseFromGallery;

  // ── Explore ───────────────────────────────────────────────────────────────
  String get exploreTitle;
  String get discoverTrending;

  // ── Login – first time vs returning ──────────────────────────────────────
  String get welcomeFirst;
  String get welcomeFirstSubtitle;

  // ── Registration form fields ──────────────────────────────────────────────
  String get emailAddress;
  String get passwordLabel;
  String get phoneOptional;
  String get fullNameRequired;
  String get emailRequired;
  String get passwordRequired;
  String get passwordTooShort;
  String get phoneInvalid;

  // ── Permission sheet ──────────────────────────────────────────────────────
  String get permissionRequired;
  String get permissionSettingsBody;
  String get notNow;
  String get openSettings;
  String get allowMediaAccess;
  String get allowMediaBody;
  String get allowAccess;
  String get dontAllow;
  String get mediaDeniedSnack;
  String get settingsLabel;

  // ── Legal screen ──────────────────────────────────────────────────────────
  String get lastUpdated;
  String get termsSection1Title;
  String get termsSection1Body;
  String get termsSection2Title;
  String get termsSection2Body;
  String get termsSection3Title;
  String get termsSection3Body;
  String get termsSection4Title;
  String get termsSection4Body;
  String get termsSection5Title;
  String get termsSection5Body;
  String get termsSection6Title;
  String get termsSection6Body;
  String get termsSection7Title;
  String get termsSection7Body;
  String get termsSection8Title;
  String get termsSection8Body;
  String get termsSection9Title;
  String get termsSection9Body;
  String get privacySection1Title;
  String get privacySection1Body;
  String get privacySection2Title;
  String get privacySection2Body;
  String get privacySection3Title;
  String get privacySection3Body;
  String get privacySection4Title;
  String get privacySection4Body;
  String get privacySection5Title;
  String get privacySection5Body;
  String get privacySection6Title;
  String get privacySection6Body;
  String get privacySection7Title;
  String get privacySection7Body;
  String get privacySection8Title;
  String get privacySection8Body;
  String get privacySection9Title;
  String get privacySection9Body;

  // ── Misc remaining ────────────────────────────────────────────────────────
  String get thisPostDeleted;
  String get tapToView;
  String get noPostsYetOther;
  String get whenSharesPhotos;
  String get notificationDeleted;
  String get userUnblocked;
  String get noUsersFound;
  String get noPostsForQuery;
  String get failedToLoadPosts;
  String get sentTo;
  String get failedToSend;
  String get tapBookmarkHint;
  String get waitSeconds;
  String get postThisDeleted;
}

