// lib/utils/validators.dart
//
// Centralised input validators used across all TextFormField widgets.
// Each validator returns null on success or an error String on failure.

class Validators {
  Validators._();

  // ── Post text ─────────────────────────────────────────────────────────────
  static String? postText(String? value) {
    if (value == null || value.isEmpty) return null; // optional
    if (value.length > 2000) return 'Post text must be 2,000 characters or less';
    return null;
  }

  // ── Bio ───────────────────────────────────────────────────────────────────
  static String? bio(String? value) {
    if (value == null || value.isEmpty) return null; // optional
    if (value.length > 150) return 'Bio must be 150 characters or less';
    return null;
  }

  // ── Display name ──────────────────────────────────────────────────────────
  static String? displayName(String? value) {
    if (value == null || value.trim().isEmpty) return 'Name is required';
    final trimmed = value.trim();
    if (trimmed.length < 2) return 'Name must be at least 2 characters';
    if (trimmed.length > 40) return 'Name must be 40 characters or less';
    final validChars = RegExp(r'^[a-zA-Z0-9\u0600-\u06FF\s_]+$');
    if (!validChars.hasMatch(trimmed)) {
      return 'Name may only contain letters, numbers, spaces, and underscores';
    }
    return null;
  }

  // ── Phone (optional, E.164 if provided) ──────────────────────────────────
  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) return null; // optional
    final e164 = RegExp(r'^\+[1-9]\d{7,14}$');
    if (!e164.hasMatch(value.trim())) {
      return 'Enter a valid phone number in E.164 format (e.g. +201234567890)';
    }
    return null;
  }

  // ── Comment text ──────────────────────────────────────────────────────────
  static String? commentText(String? value) {
    if (value == null || value.trim().isEmpty) return 'Comment cannot be empty';
    if (value.length > 500) return 'Comment must be 500 characters or less';
    return null;
  }

  // ── Message text ──────────────────────────────────────────────────────────
  static String? messageText(String? value) {
    if (value == null || value.trim().isEmpty) return 'Message cannot be empty';
    if (value.length > 1000) return 'Message must be 1,000 characters or less';
    return null;
  }

  // ── Email ─────────────────────────────────────────────────────────────────
  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email is required';
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(value.trim())) return 'Enter a valid email address';
    return null;
  }

  // ── Password ──────────────────────────────────────────────────────────────
  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  // ── Character count helper: returns chars remaining when < threshold ──────
  static String? charsRemaining(String value, int max, {int threshold = 20}) {
    final remaining = max - value.length;
    if (remaining <= threshold && remaining >= 0) {
      return '$remaining characters remaining';
    }
    if (remaining < 0) {
      return '${-remaining} characters over limit';
    }
    return null;
  }
}
