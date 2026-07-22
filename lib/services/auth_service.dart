// lib/services/auth_service.dart
//
// Reactive auth state service.
// Replace the global `String? uID` in constants.dart with this singleton.
// Usage:
//   AuthService.instance.currentUid  — synchronous (may be null before auth)
//   AuthService.instance.authChanges — Stream<User?>

import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Stream of Firebase auth state changes.
  Stream<User?> get authChanges => _auth.authStateChanges();

  /// Current signed-in user UID, or null if not authenticated.
  String? get currentUid => _auth.currentUser?.uid;

  /// Current Firebase User object.
  User? get currentUser => _auth.currentUser;

  /// Sign out and clear all local session data.
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Returns true if a user is currently authenticated.
  bool get isAuthenticated => _auth.currentUser != null;

  /// Server-fresh check of both sign-in and email-verification status —
  /// use this (not [isAuthenticated]) anywhere the result decides whether
  /// to let the person into the app, since a signed-in-but-unverified
  /// session must never be treated as a completed login.
  /// Returns null if there's no signed-in user at all.
  Future<bool?> checkVerifiedSession() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    try {
      await user.reload();
    } catch (_) {
      // Reload can fail offline/token-expired — fall back to the cached
      // value rather than blocking app entry entirely.
    }
    return _auth.currentUser?.emailVerified ?? false;
  }

  /// Re-authenticates the current user with their email + current password.
  /// Required by Firebase before sensitive operations like changing password.
  /// Throws if there is no signed-in user or if re-authentication fails.
  Future<void> reauthenticate({required String currentPassword}) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw StateError('No signed-in user with an email to re-authenticate.');
    }
    final credential = EmailAuthProvider.credential(
      email: user.email!,
      password: currentPassword,
    );
    await user.reauthenticateWithCredential(credential);
  }

  /// Updates the signed-in user's password. Call [reauthenticate] first —
  /// Firebase requires a recent sign-in for this to succeed.
  Future<void> updatePassword(String newPassword) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('No signed-in user to update the password for.');
    }
    await user.updatePassword(newPassword);
  }

  /// Deletes the current user's Firebase Auth account.
  /// IMPORTANT: Call this AFTER deleting all Firestore data and AFTER
  /// re-authenticating with [reauthenticate]. Firebase requires a recent
  /// sign-in before account deletion — throw a clear error if not done.
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('No signed-in user to delete.');
    }
    await user.delete();
  }
}
