import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;

import '../../models/notification_model.dart';
import '../../services/repositories/chat_repository.dart';
import '../../share/network/notification_router.dart';

const String _actionMarkSeen = 'mark_seen';

/// Marks the message this push refers to as 'delivered' — called from both
/// the background/terminated handler and the foreground onMessage listener
/// below, so the sender's tick flips grey->double-grey the moment this
/// device receives the push, regardless of app state. Only applies to
/// type == 'message' pushes, which are the only ones carrying a chatId +
/// messageId pair (see push_dispatcher.dart / send-notification.js).
Future<void> _markDeliveredIfMessage(Map<String, dynamic> data) async {
  if (data['type'] != 'message') return;
  final chatId = data['chatId'] as String?;
  final messageId = data['messageId'] as String?;
  if (chatId == null || chatId.isEmpty) return;
  if (messageId == null || messageId.isEmpty) return;
  try {
    if (Firebase.apps.isEmpty) await Firebase.initializeApp();
    await ChatRepository.markDelivered(chatId: chatId, messageId: messageId);
  } catch (e) {
    // Best-effort — a failure here should never crash the background
    // isolate or block the notification banner from showing.
    debugPrint('❌ [FCM] markDelivered: $e');
  }
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('📩 [FCM] Background: ${message.messageId}');
  if (Firebase.apps.isEmpty) await Firebase.initializeApp();
  await _markDeliveredIfMessage(message.data);
  await FCMService.showBackgroundBanner(message);
}

/// Handles "Reply" / "Mark as read" being tapped on a notification action —
/// runs in its own isolate when the app is backgrounded/terminated, or
/// inline if the app happens to be running. Must be a top-level function
/// with this exact pragma for the background case to work.
@pragma('vm:entry-point')
Future<void> notificationBackgroundHandler(NotificationResponse response) async {
  debugPrint('🔔 [FCM] action tapped: id=${response.actionId} '
      'type=${response.notificationResponseType} input=${response.input}');

  if (response.notificationResponseType !=
      NotificationResponseType.selectedNotificationAction) {
    debugPrint('🔕 [FCM] action: not an action tap, ignoring');
    return;
  }
  // Reply no longer sends silently in the background — see the action
  // definition in _showBanner below for why. It's now a plain "open app"
  // action, which goes through the normal notification-tap routing
  // (_route/_onLocalTap/handleTerminatedMessage), not this handler. This
  // handler now only deals with Mark as read.
  if (response.actionId != _actionMarkSeen) return;

  final payload = response.payload;
  if (payload == null) {
    debugPrint('❌ [FCM] action: no payload attached');
    return;
  }

  Map<String, dynamic> data;
  try {
    data = jsonDecode(payload) as Map<String, dynamic>;
  } catch (e) {
    debugPrint('❌ [FCM] action: payload decode failed: $e');
    return;
  }
  if (data['type'] != 'message') {
    debugPrint('🔕 [FCM] action: not a message-type payload');
    return;
  }

  final chatId = data['chatId'] as String?;
  if (chatId == null || chatId.isEmpty) {
    debugPrint('❌ [FCM] action: missing chatId in payload');
    return;
  }

  try {
    if (Firebase.apps.isEmpty) await Firebase.initializeApp();
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) {
      debugPrint('❌ [FCM] action: no signed-in user in this isolate');
      return;
    }
    debugPrint('👁️ [FCM] action: marking seen for $chatId');
    await ChatRepository.markAsSeen(chatId: chatId, myUid: myUid);
    debugPrint('✅ [FCM] action: marked seen');

    FCMService.clearChatHistory(chatId);
    await FlutterLocalNotificationsPlugin().cancel(id: chatId.hashCode);
  } catch (e) {
    debugPrint('❌ [FCM] notification action FAILED: $e');
  }
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class FCMService {
  FCMService._();

  static final FirebaseMessaging            _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _local =
  FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'high_importance_channel',
    'High Importance Notifications',
    description:       'Vibely push notifications',
    importance:        Importance.max,
    playSound:         true,
    enableVibration:   true,
  );

  // ── Lifecycle tracking ─────────────────────────────────────────────────────
  static AppLifecycleState _lifecycle = AppLifecycleState.resumed;
  static void updateLifecycle(AppLifecycleState s) => _lifecycle = s;

  /// The chatId that is currently open (set by ChatScreen on enter/exit).
  /// Used to suppress in-app banners for the currently-viewed conversation.
  static String? _activeChatId;
  static void setActiveChatId(String? id) => _activeChatId = id;

  // ── Avatar cache ───────────────────────────────────────────────────────────
  /// Sender profile photos, downloaded once per URL and reused across
  /// notifications — avoids re-downloading the same avatar on every message
  /// from the same person within this app session.
  static final Map<String, Uint8List> _avatarCache = {};

  static Future<Uint8List?> _fetchAvatar(String? url) async {
    if (url == null || url.isEmpty) return null;
    final cached = _avatarCache[url];
    if (cached != null) return cached;
    try {
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        _avatarCache[url] = res.bodyBytes;
        return res.bodyBytes;
      }
    } catch (e) {
      debugPrint('❌ [FCM] avatar fetch: $e');
    }
    return null;
  }

  // ── Chat message history (for WhatsApp-style stacked bubbles) ─────────────
  /// Per-chat running list of recent messages, so a second message from the
  /// same conversation appends onto the same notification (like WhatsApp)
  /// instead of replacing it or spawning a separate one, shown oldest to
  /// newest. Session-only — not persisted to disk, so this resets on app
  /// restart. That's an acceptable simplification: worst case after a
  /// restart is the notification starts a fresh thread instead of
  /// continuing an old one, which still looks correct, just without the
  /// older lines.
  static final Map<String, List<Message>> _chatHistory = {};

  static void clearChatHistory(String chatId) => _chatHistory.remove(chatId);

  static bool _localInitializedInThisIsolate = false;

  static Future<void> showBackgroundBanner(RemoteMessage msg) async {
    debugPrint('🔔 [FCM] showBackgroundBanner: ${msg.messageId}');
    final mediaType = msg.data['mediaType'] as String?;
    if (mediaType == 'video') {
      debugPrint('🔕 [FCM] showBackgroundBanner: video, skipping');
      return;
    }
    if (!_localInitializedInThisIsolate) {
      debugPrint('🔔 [FCM] showBackgroundBanner: initializing local plugin');
      await _initLocalForBackgroundShowOnly();
      _localInitializedInThisIsolate = true;
    }
    try {
      // fetchAvatar: false — a background isolate gets a tight execution
      // window from Android before it's killed. The earlier version
      // awaited a network image download here, which sometimes lost that
      // race and the notification never got shown at all — this is why it
      // "sometimes worked" (whenever the avatar happened to already be
      // cached from an earlier successful call). Using the plain app icon
      // in the background is a small visual downgrade in exchange for the
      // notification actually reliably showing up every time.
      await _showBanner(msg, fetchAvatar: false);
      debugPrint('✅ [FCM] showBackgroundBanner: shown');
    } catch (e) {
      debugPrint('❌ [FCM] showBackgroundBanner FAILED: $e');
    }
  }

  // ── Public API ─────────────────────────────────────────────────────────────
  static Future<void> init() async {
    await _requestPermission();
    await _createAndroidChannel();
    await _initLocal();
    _setupForeground();
    _setupBackgroundTap();
  }

  static Future<void> handleTerminatedMessage(BuildContext context) async {
    final msg = await _messaging.getInitialMessage();
    if (msg != null) _route(context, msg.data);
  }

  static Future<String?> getToken() async {
    try {
      return await _messaging.getToken();
    } catch (e) {
      debugPrint('❌ [FCM] getToken: $e');
      return null;
    }
  }

  static Future<String?> getValidToken() => getToken();

  static void listenTokenRefresh(void Function(String) cb) =>
      _messaging.onTokenRefresh.listen(cb);

  // ── Private ────────────────────────────────────────────────────────────────
  static Future<void> _requestPermission() async {
    final s = await _messaging.requestPermission(
        alert: true, badge: true, sound: true);
    debugPrint('🔔 [FCM] ${s.authorizationStatus.name}');
  }

  static Future<void> _createAndroidChannel() async {
    final AndroidFlutterLocalNotificationsPlugin? androidImpl = _local
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl == null) return;
    await androidImpl.createNotificationChannel(_channel);
  }

  static Future<void> _initLocal() async {
    await _local.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (r) {
        if (r.notificationResponseType ==
            NotificationResponseType.selectedNotificationAction) {
          // App happens to be running — handle it inline rather than
          // waiting on the background isolate.
          unawaited(notificationBackgroundHandler(r));
          return;
        }
        if (r.payload != null) _onLocalTap(r.payload!);
      },
      onDidReceiveBackgroundNotificationResponse: notificationBackgroundHandler,
    );
  }

  /// Used only from [showBackgroundBanner] — enough setup for `.show()` to
  /// work, but deliberately does NOT re-register
  /// onDidReceiveNotificationResponse / onDidReceiveBackgroundNotification-
  /// Response. Those must only ever be registered once, from the app's
  /// real startup in [init] below — the plugin persists that registration
  /// natively so a separate background isolate can dispatch to it later
  /// when a notification action is tapped. Re-registering it here, from
  /// this throwaway isolate that gets torn down right after showing the
  /// banner, risks overwriting that persisted link with one tied to an
  /// isolate that's already gone — which silently breaks action handling:
  /// Android waits forever for a response dispatcher that no longer
  /// resolves to anything, which looks exactly like a stuck "sending..."
  /// spinner on the Reply action.
  static Future<void> _initLocalForBackgroundShowOnly() async {
    await _local.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
  }

  static void _setupForeground() {
    _messaging.setForegroundNotificationPresentationOptions(
        alert: true, badge: true, sound: true);

    FirebaseMessaging.onMessage.listen((msg) {
      unawaited(_markDeliveredIfMessage(msg.data));

      // ── Video message gate ─────────────────────────────────────────────────
      // Spec: "Notifications sent on text and shared post.
      //        NOT sent on video messages."
      // We also suppress image / voice by checking the `mediaType` field
      // only if you want strict text+sharedPost only. Currently we allow
      // image and voice but block video. Adjust the condition as needed.
      final mediaType = msg.data['mediaType'] as String?;
      if (mediaType == 'video') {
        debugPrint('🔕 [FCM] Suppressed: video message notification');
        return;
      }

      // ── Active-chat gate ───────────────────────────────────────────────────
      // Don't show a banner if the user already has this chat open.
      final incomingChatId = msg.data['chatId'] as String?;
      if (_lifecycle == AppLifecycleState.resumed &&
          incomingChatId != null &&
          incomingChatId == _activeChatId) {
        debugPrint('🔕 [FCM] Suppressed: chat is currently open');
        return;
      }

      unawaited(_showBanner(msg));
    });
  }

  static void _setupBackgroundTap() {
    FirebaseMessaging.onMessageOpenedApp.listen((msg) {
      final ctx = navigatorKey.currentContext;
      if (ctx != null) _route(ctx, msg.data);
    });
  }

  static void _onLocalTap(String payload) {
    final ctx = navigatorKey.currentContext;
    if (ctx == null) return;
    try {
      _route(ctx, jsonDecode(payload) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('❌ [FCM] payload: $e');
    }
  }

  static void _route(BuildContext ctx, Map<String, dynamic> data) {
    final typeStr = data['type'] as String?;
    if (typeStr == null) return;
    try {
      NotificationRouter.open(
          ctx,
          AppNotification(
            id:            data['notificationId'] as String? ?? '',
            type:          AppNotification.stringToType(typeStr),
            fromUserId:    data['fromUserId']    as String? ?? '',
            fromUserName:  data['fromUserName']  as String? ?? '',
            fromUserImage: data['fromUserImage'] as String? ?? '',
            postId:        data['postId']    as String?,
            commentId:     data['commentId'] as String?,
            replyId:       data['replyId']   as String?,
            chatId:        data['chatId']    as String?,
            text:          data['text']      as String?,
            dateTime:      data['dateTime']  as String? ??
                DateTime.now().toIso8601String(),
            isGroup:       (data['isGroup'] as String?) == 'true' ||
                data['isGroup'] == true,
          ));
    } catch (e) {
      debugPrint('❌ [FCM] route: $e');
    }
  }

  /// Mirrors actionText() in push_server/api/send-notification.js — keep
  /// in sync. Needed here because message-type pushes are now data-only
  /// (see send-notification.js), so there's no server-built notification
  /// body to read for those; for consistency this builds it the same way
  /// for every type, whether or not a notification block is present.
  static String _actionText(String? type) {
    switch (type) {
      case 'postLike':     return 'reacted to your post';
      case 'postComment':  return 'commented on your post';
      case 'commentLike':  return 'liked your comment';
      case 'commentReply': return 'replied to your comment';
      case 'follow':       return 'started following you';
      case 'mention':      return 'mentioned you';
      case 'blocked':      return 'blocked you';
      default:              return 'sent you a notification';
    }
  }

  static Future<void> _showBanner(RemoteMessage msg, {bool fetchAvatar = true}) async {
    final data      = msg.data;
    final type      = data['type'] as String?;
    final isMessage = type == 'message';
    final fromName  = (data['fromUserName'] as String?)?.trim().isNotEmpty == true
        ? data['fromUserName'] as String
        : (msg.notification?.title ?? 'Vibely');
    final fromImage = data['fromUserImage'] as String?;
    final body = isMessage
        ? ((data['text'] as String?)?.trim().isNotEmpty == true
        ? data['text'] as String
        : 'Sent you a message')
        : (msg.notification?.body ?? _actionText(type));

    final avatarBytes = fetchAvatar ? await _fetchAvatar(fromImage) : null;
    final AndroidBitmap<Object> largeIcon = avatarBytes != null
        ? ByteArrayAndroidBitmap(avatarBytes)
        : const DrawableResourceAndroidBitmap('@mipmap/ic_launcher');
    final personIcon =
    avatarBytes != null ? ByteArrayAndroidIcon(avatarBytes) : null;

    late final int notifId;
    late final StyleInformation style;
    late final String groupKey;

    if (isMessage) {
      // ── WhatsApp-style: grouped by conversation, sender avatar + bubbles,
      //    oldest-to-newest, hidden on the lock screen until unlocked/opened ──
      final chatId = data['chatId'] as String? ?? (msg.messageId ?? 'chat');
      notifId  = chatId.hashCode;
      groupKey = 'chat_$chatId';

      final sender = Person(name: fromName, icon: personIcon, key: chatId);
      final history = _chatHistory.putIfAbsent(chatId, () => []);
      history.add(Message(body, DateTime.now(), sender)); // appended = newest last
      if (history.length > 5) history.removeAt(0); // keep it short

      style = MessagingStyleInformation(
        sender,
        groupConversation:
        (data['isGroup'] as String?) == 'true' || data['isGroup'] == true,
        conversationTitle: fromName,
        messages: history,
      );
    } else {
      // ── Facebook-style: name + action text, expandable if long ────────────
      notifId  = msg.messageId.hashCode;
      groupKey = 'social';
      style = BigTextStyleInformation(body, contentTitle: fromName);
    }

    await _local.show(
      id: notifId,
      title: fromName,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id, _channel.name,
          channelDescription: _channel.description,
          importance: Importance.max,
          priority:   Priority.high,
          icon:       '@mipmap/ic_launcher',
          largeIcon:  largeIcon,
          styleInformation: style,
          groupKey: groupKey,
          category: isMessage
              ? AndroidNotificationCategory.message
              : AndroidNotificationCategory.social,
          // Content hidden on the lock screen until the phone is unlocked —
          // matches WhatsApp. Whether this actually redacts depends on the
          // phone's own lock-screen privacy setting; the app can only
          // request it, the OS decides.
          visibility: isMessage ? NotificationVisibility.private : null,
          actions: isMessage
              ? <AndroidNotificationAction>[
            const AndroidNotificationAction(
              _actionMarkSeen,
              'Mark as read',
              showsUserInterface: false,
              cancelNotification: true,
            ),
          ]
              : null,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: jsonEncode(msg.data),
    );
  }
}