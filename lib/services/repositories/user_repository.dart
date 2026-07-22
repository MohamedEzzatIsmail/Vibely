// lib/services/repositories/user_repository.dart
//
// Wraps every Firestore + Supabase call that cubit.dart (MainCubit) used to
// make directly for user-profile data. MainCubit should hold no
// FirebaseFirestore/SupabaseClient references of its own after this — it
// only calls UserRepository methods (and AuthService for auth state).
//
// Follows the same static-class convention as the other repositories:
// no instances, a private constructor, static clients, static methods,
// no business logic — pure pass-through I/O.

import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserRepository {
  UserRepository._();

  static final _firestore = FirebaseFirestore.instance;
  static final _supabase = Supabase.instance.client;

  static DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _firestore.collection('Users').doc(uid);

  // ── Read ──────────────────────────────────────────────────────────────────
  static Future<DocumentSnapshot<Map<String, dynamic>>> getUser(String uid) {
    return _userDoc(uid).get();
  }

  // ── Write ─────────────────────────────────────────────────────────────────
  static Future<void> ensureUidField({
    required String uid,
  }) async {
    await _userDoc(uid).set({'uid': uid}, SetOptions(merge: true));
  }

  static Future<void> updateProfile({
    required String uid,
    required Map<String, dynamic> data,
  }) async {
    await _userDoc(uid).set(data, SetOptions(merge: true));
  }

  static Future<void> updateFcmToken({
    required String uid,
    required String token,
  }) async {
    await _userDoc(uid).update({'fcmToken': token});
  }

  /// Syncs Firestore's copy of the verification flag once Firebase Auth
  /// confirms the user has verified their email (via the link or a fresh
  /// [User.reload]). Safe to call repeatedly — it's a merge write.
  static Future<void> markEmailVerified(String uid) async {
    await _userDoc(uid).set(
      {'emailVerified': true},
      SetOptions(merge: true),
    );
  }

  // ── Profile / cover image upload ─────────────────────────────────────────
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
    // Remove FCM token first so no more notifications are sent
    try {
      await _userDoc(uid).update({'fcmToken': FieldValue.delete()});
    } catch (_) {}

    // Delete the user document itself
    // Note: sub-collections (posts, notifications, chats) are not auto-deleted
    // by Firestore when the parent document is deleted. Add a Cloud Function
    // trigger on user deletion to clean these up for production.
    await _userDoc(uid).delete();
  }
}
