/// All Firestore + Supabase access for user-profile data (reads, profile
/// updates, image uploads, account deletion). Kept as a static-only class so
/// MainCubit never touches Firestore/Supabase directly for this data.

import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/user_model.dart';

class UserRepository {
  UserRepository._();

  static final _firestore = FirebaseFirestore.instance;
  static final _supabase = Supabase.instance.client;

  static DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _firestore.collection('Users').doc(uid);

  static DocumentReference<Map<String, dynamic>> _privateDoc(String uid) =>
      _userDoc(uid).collection('private').doc('data');

  // ── Read ──────────────────────────────────────────────────────────────────
  /// Fetches a single user's public Firestore document — safe to call for
  /// any user, not just yourself.
  static Future<DocumentSnapshot<Map<String, dynamic>>> getUser(String uid) {
    return _userDoc(uid).get();
  }

  /// Fetches [uid]'s private document. Only ever call this for your OWN
  /// account — the security rules only allow the owner to read it anyway,
  /// so calling this for another user's uid will throw permission-denied.
  static Future<DocumentSnapshot<Map<String, dynamic>>> getPrivateData(String uid) {
    return _privateDoc(uid).get();
  }

  /// Fetches and merges both documents into one fully-populated [UserModel]
  /// — use this whenever loading the CURRENT user's own profile (login,
  /// chat setup, settings). Never use this for viewing another user's
  /// profile; use [getUser] alone for that.
  static Future<UserModel> getFullUserModel(String uid) async {
    final publicSnap = await getUser(uid);
    final model = UserModel.fromJson(publicSnap.data() ?? {});
    try {
      final privateSnap = await getPrivateData(uid);
      if (privateSnap.exists) model.mergePrivateData(privateSnap.data()!);
    } catch (_) {
      // Private doc doesn't exist yet (e.g. account created before this
      // split existed) — the model just keeps its default private-field
      // values, which is safe.
    }
    return model;
  }

  // ── Write ─────────────────────────────────────────────────────────────────
  /// Makes sure the user document has its own `uid` field set (some flows
  /// create the doc before this is known). Safe to call repeatedly.
  static Future<void> ensureUidField({
    required String uid,
  }) async {
    await _userDoc(uid).set({'uid': uid}, SetOptions(merge: true));
  }

  /// Merges [data] into the user's PUBLIC profile document. Only ever pass
  /// public fields here — see [UserModel.toMap] for which ones those are.
  static Future<void> updateProfile({
    required String uid,
    required Map<String, dynamic> data,
  }) async {
    await _userDoc(uid).set(data, SetOptions(merge: true));
  }

  /// Merges [data] into the user's PRIVATE document — email, phone, block
  /// lists, bookmarks, pinned chats, close friends. See
  /// [UserModel.toPrivateMap] for the full field set.
  static Future<void> updatePrivateData({
    required String uid,
    required Map<String, dynamic> data,
  }) async {
    await _privateDoc(uid).set(data, SetOptions(merge: true));
  }

  /// Stores the device's current FCM push token. Lives on the private doc —
  /// no other user's client ever needs to read it; the push server reads it
  /// with the Admin SDK, which isn't subject to these rules anyway.
  static Future<void> updateFcmToken({
    required String uid,
    required String token,
  }) async {
    await _privateDoc(uid).set({'fcmToken': token}, SetOptions(merge: true));
  }

  /// Syncs Firestore's copy of the verification flag once Firebase Auth
  /// confirms the user has verified their email (via the link or a fresh
  /// [User.reload]). Safe to call repeatedly — it's a merge write.
  static Future<void> markEmailVerified(String uid) async {
    await _privateDoc(uid).set(
      {'emailVerified': true},
      SetOptions(merge: true),
    );
  }

  // ── Profile / cover image upload ─────────────────────────────────────────
  /// Uploads a new profile photo to Supabase Storage and returns its public
  /// URL. Does not write the URL to Firestore — call [updateProfile] with it.
  static Future<String> uploadProfileImage({
    required String uid,
    required Uint8List bytes,
  }) async {
    final fileName =
        'profile_${uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await _supabase.storage.from('user-images').uploadBinary(
          fileName,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );
    return _supabase.storage.from('user-images').getPublicUrl(fileName);
  }

  /// Uploads a new cover photo to Supabase Storage and returns its public
  /// URL. Does not write the URL to Firestore — call [updateProfile] with it.
  static Future<String> uploadCoverImage({
    required String uid,
    required Uint8List bytes,
  }) async {
    final fileName =
        'cover_${uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await _supabase.storage.from('user-images').uploadBinary(
          fileName,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );
    return _supabase.storage.from('user-images').getPublicUrl(fileName);
  }

  // ── Delete ────────────────────────────────────────────────────────────────
  /// Deletes the user's Firestore document and their FCM token.
  /// Call this before deleting the Firebase Auth account.
  /// Note: Supabase media files (profile/cover images, post images, voice
  /// messages, chat media) use filenames prefixed with the uid — these can
  /// be cleaned up in a scheduled Cloud Function or left to expire via
  /// Supabase storage lifecycle rules. They are not deleted here because
  /// listing all of a user's files across multiple Supabase folders from
  /// the client is not safe (requires service-role key).
  static Future<void> deleteUserFirestoreData(String uid) async {
    // Delete the private doc first (fcmToken, email/phone, block lists, etc.)
    try {
      await _privateDoc(uid).delete();
    } catch (_) {}

    // Delete the user document itself
    // Note: sub-collections (posts, notifications, chats) are not auto-deleted
    // by Firestore when the parent document is deleted. Add a Cloud Function
    // trigger on user deletion to clean these up for production.
    await _userDoc(uid).delete();
  }
}
