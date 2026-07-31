// lib/services/push_dispatcher.dart
//
// Firebase Cloud Functions need the Blaze plan to deploy at all, which
// this project isn't using. This is the alternative: a small standalone
// server (see /push_server in the project root, deployed separately —
// e.g. on Render's free tier) does the same job a Firestore-triggered
// Cloud Function would have. Since there's no Firestore trigger without
// Cloud Functions, the app calls it directly right after writing a
// notification to Firestore.
//
// Fire-and-forget by design: a failure here should never block or break
// anything — the in-app notification has already been written to
// Firestore successfully by the time this runs. Worst case if this fails
// or isn't configured yet: no OS push arrives, but the in-app
// notification (bell icon, list) still works exactly as before.
import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
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
      if (idToken == null) return;

      final body = notification.toMap();
      body['toUserId'] = toUserId;

      await http
          .post(
            Uri.parse('$serverUrl/send-notification'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $idToken',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 8));
    } catch (_) {
      // Free-tier hosts can be asleep/slow, or the server might not be
      // deployed yet — never let that break the actual notification flow.
    }
  }
}
