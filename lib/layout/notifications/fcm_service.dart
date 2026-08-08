import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;

import '../../models/notification_model.dart';
import '../../services/repositories/chat_repository.dart';
import '../../share/network/notification_router.dart';

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
  await _markDeliveredIfMessage(message.data);
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
  /// instead of replacing it or spawning a separate one. Session-only — not
  /// persisted to disk, so this resets on app restart. That's an acceptable
  /// simplification: worst case after a restart is the notification starts
  /// a fresh thread instead of continuing an old one, which still looks
  /// correct, just without the older lines.
  static final Map<String, List<Message>> _chatHistory = {};

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
        if (r.payload != null) _onLocalTap(r.payload!);
      },
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

  static Future<void> _showBanner(RemoteMessage msg) async {
    final n = msg.notification;
    if (n == null) return;

    final data      = msg.data;
    final type      = data['type'] as String?;
    final fromName  = (data['fromUserName'] as String?)?.trim().isNotEmpty == true
        ? data['fromUserName'] as String
        : (n.title ?? 'Vibely');
    final fromImage = data['fromUserImage'] as String?;
    final body      = n.body ?? '';

    final avatarBytes = await _fetchAvatar(fromImage);
    final AndroidBitmap<Object> largeIcon = avatarBytes != null
        ? ByteArrayAndroidBitmap(avatarBytes)
        : const DrawableResourceAndroidBitmap('@mipmap/ic_launcher');
    final personIcon =
    avatarBytes != null ? ByteArrayAndroidIcon(avatarBytes) : null;

    late final int notifId;
    late final StyleInformation style;
    late final String groupKey;

    if (type == 'message') {
      // ── WhatsApp-style: grouped by conversation, sender avatar + bubbles ──
      final chatId = data['chatId'] as String? ?? (msg.messageId ?? 'chat');
      notifId  = chatId.hashCode;
      groupKey = 'chat_$chatId';

      final sender = Person(name: fromName, icon: personIcon, key: chatId);
      final history = _chatHistory.putIfAbsent(chatId, () => []);
      history.add(Message(body, DateTime.now(), sender));
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
          category: type == 'message'
              ? AndroidNotificationCategory.message
              : AndroidNotificationCategory.social,
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