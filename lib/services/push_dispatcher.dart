import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/notification_model.dart';

class PushDispatcher {
  PushDispatcher._();

  /// The deployed /push_server instance (see project root, deployed on
  /// Vercel). Left empty, this is a safe no-op so nothing breaks if it's
  /// ever undeployed.
  static const String serverUrl = 'https://vibely-xi.vercel.app';

  static Future<void> notify({
    required AppNotification notification,
    required String toUserId,
  }) async {
    if (serverUrl.isEmpty) return;
    if (toUserId.isEmpty || toUserId == notification.fromUserId) return;

    try {
      final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (idToken == null) {
        debugPrint('❌ [Push] no ID token — not signed in?');
        return;
      }

      final body = notification.toMap();
      body['toUserId'] = toUserId;

      final response = await http
          .post(
        Uri.parse('$serverUrl/send-notification'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode(body),
      )
          .timeout(const Duration(seconds: 8));
      if (kDebugMode) debugPrint('📮 [Push] ${response.statusCode}: ${response.body}');
    } catch (e) {
      debugPrint('❌ [Push] request failed: $e');
      // Free-tier hosts can be asleep/slow, or the server might not be
      // deployed yet — never let that break the actual notification flow.
    }
  }
}