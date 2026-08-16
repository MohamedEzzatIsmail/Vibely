// lib/services/presence_service.dart
//
// Real online/offline presence using Firebase Realtime Database.
//
// WHY THIS EXISTS:
// Firestore alone cannot detect a dropped connection, a force-killed app,
// a crash, or a phone losing signal — there is no server-side hook for any
// of that in Firestore. The app can only ever WRITE "online" or "offline"
// itself, and if the process dies before it writes "offline" (which is the
// common case — OS kills, battery dies, app is swiped away, plane mode),
// the last value written ("online") stays in Firestore forever.
//
// Firebase Realtime Database solves this with onDisconnect(): a hook
// registered with the RTDB SERVER itself, not the device. The moment the
// client's socket disconnects for ANY reason, the server runs the
// onDisconnect() write automatically — no code on the device needs to run,
// no clean shutdown needed. This is the same mechanism WhatsApp/Messenger
// use for "online" indicators.
//
// FLOW:
//   1. On login: write isOnline=true to RTDB at /status/{uid}.
//      Register onDisconnect() to write isOnline=false + lastSeen the
//      INSTANT the connection drops (crash, kill, network loss, anything).
//   2. A Cloud Function (or, if you don't want one, the mirroring listener
//      below) copies /status/{uid} from RTDB into Firestore Users/{uid}
//      so all your existing UI code reading UserModel.isOnline / lastSeen
//      from Firestore keeps working with ZERO changes to chat.dart,
//      other_profile_screen.dart, etc.
//   3. On logout: explicitly write isOnline=false before signing out,
//      AND cancel the RTDB listener so it doesn't fight the explicit write.
//
// SETUP REQUIRED (one-time, see bottom of file for full instructions):
//   - Add firebase_database to pubspec.yaml
//   - Enable Realtime Database in Firebase Console
//   - Add the RTDB security rules shown at the bottom of this file

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';

class PresenceService {
  PresenceService._();
  static final PresenceService instance = PresenceService._();

  final FirebaseDatabase _rtdb = FirebaseDatabase.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  StreamSubscription<DatabaseEvent>? _connectionSub;
  StreamSubscription<DatabaseEvent>? _mirrorSub;
  String? _activeUid;

  /// Call this once, right after a successful login (and on app start if
  /// a user is already signed in). Sets up the disconnect hook and starts
  /// mirroring RTDB presence into Firestore for that user.
  void start(String uid) {
    // If presence was already running for a different account (account
    // switch without explicit logout), tear it down first.
    if (_activeUid != null && _activeUid != uid) {
      stop(_activeUid!);
    }
    if (_activeUid == uid) return; // already running for this user

    _activeUid = uid;

    final statusRef    = _rtdb.ref('status/$uid');
    final connectedRef = _rtdb.ref('.info/connected');

    _connectionSub = connectedRef.onValue.listen((event) {
      final connected = event.snapshot.value == true;
      if (!connected) return;

      // Server-side hook: the INSTANT this client's socket disconnects
      // for any reason (crash, kill, network loss, plane mode, anything),
      // the RTDB server itself runs this write. No device code required.
      statusRef.onDisconnect().set({
        'isOnline':  false,
        'lastSeen':  ServerValue.timestamp,
      });

      // Now that the disconnect hook is armed, mark this client online.
      statusRef.set({
        'isOnline':  true,
        'lastSeen':  ServerValue.timestamp,
      });
    });

    // Mirror RTDB → Firestore so existing UI (UserModel.isOnline/lastSeen
    // read from Firestore Users/{uid}) updates automatically with zero
    // changes to chat.dart / other_profile_screen.dart / chats_screen.dart.
    _mirrorSub = statusRef.onValue.listen((event) {
      final data = event.snapshot.value;
      if (data == null || data is! Map) return;
      final isOnline   = data['isOnline'] == true;
      final lastSeenMs  = data['lastSeen'];

      final update = <String, dynamic>{'isOnline': isOnline};
      if (!isOnline && lastSeenMs is int) {
        update['lastSeen'] =
            DateTime.fromMillisecondsSinceEpoch(lastSeenMs).toIso8601String();
      }
      _firestore.collection('Users').doc(uid).update(update).catchError((_) {
        // Document may not exist yet on very first sign-up — safe to ignore.
      });
    });
  }

  /// Watches another user's live presence directly from Realtime Database —
  /// the authoritative source. Unlike the Firestore mirror above (which can
  /// only ever reflect a write made by that user's OWN device while it's
  /// still running), this works correctly even when that device crashed,
  /// was force-killed, or lost network — because RTDB's onDisconnect()
  /// hook fires server-side, with no dependence on any device still being
  /// alive to relay it anywhere. This is what other people's online dots
  /// should actually be reading from.
  StreamSubscription<DatabaseEvent> watchStatus(
      String uid,
      void Function(bool isOnline, DateTime? lastSeen) onData,
      ) {
    return _rtdb.ref('status/$uid').onValue.listen((event) {
      final data = event.snapshot.value;
      if (data == null || data is! Map) {
        onData(false, null);
        return;
      }
      final isOnline = data['isOnline'] == true;
      final lastSeenMs = data['lastSeen'];
      final lastSeen = lastSeenMs is int
          ? DateTime.fromMillisecondsSinceEpoch(lastSeenMs)
          : null;
      onData(isOnline, lastSeen);
    });
  }

  /// Call this on explicit logout, BEFORE FirebaseAuth.signOut().
  /// Writes isOnline=false immediately and tears down the listeners so the
  /// disconnect hook for the OLD account doesn't fire after a new account
  /// logs in on the same device (which would wrongly mark account A offline
  /// using account B's connection drop, or vice versa).
  Future<void> stop(String uid) async {
    await _connectionSub?.cancel();
    await _mirrorSub?.cancel();
    _connectionSub = null;
    _mirrorSub     = null;

    final statusRef = _rtdb.ref('status/$uid');
    // Cancel the pending onDisconnect write — we're handling it manually now.
    await statusRef.onDisconnect().cancel();
    await statusRef.set({
      'isOnline': false,
      'lastSeen': ServerValue.timestamp,
    });

    await _firestore.collection('Users').doc(uid).update({
      'isOnline': false,
      'lastSeen': DateTime.now().toIso8601String(),
    }).catchError((_) {});

    if (_activeUid == uid) _activeUid = null;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ONE-TIME SETUP — read this before running the app
// ─────────────────────────────────────────────────────────────────────────────
//
// 1. pubspec.yaml — add:
//      firebase_database: ^12.0.3
//    (run `flutter pub get` after)
//
// 2. Firebase Console → Build → Realtime Database → Create Database.
//    Pick any region (it does not need to match Firestore's region).
//
// 3. Realtime Database → Rules tab → paste this and Publish:
//    {
//      "rules": {
//        "status": {
//          "$uid": {
//            ".read": true,
//            ".write": "auth != null && auth.uid == $uid"
//          }
//        }
//      }
//    }
//    This lets any signed-in user READ everyone's status (needed to show
//    other people's online dot) but only WRITE their own status node.
//
// 4. google-services.json (Android) / GoogleService-Info.plist (iOS) —
//    no changes needed, RTDB uses the same Firebase project config.
//
// 5. If `flutterfire configure` was used originally, the RTDB URL is
//    already embedded in firebase_options.dart once you re-run
//    `flutterfire configure` after enabling RTDB in step 2. If you set up
//    Firebase manually, add the databaseURL to your Firebase options.