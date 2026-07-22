// ─────────────────────────────────────────────────────────────────────────────
//  lib/share/local/app_config.dart
//
//  !! THIS FILE IS GITIGNORED — NEVER COMMIT IT !!
//
//  Credentials are injected at build-time via --dart-define-from-file=.env
//  No fallback values — the app will throw clearly if env vars are missing.
//
//  Setup:
//    1. cp .env.example .env
//    2. Fill in your Supabase URL and anon key in .env
//    3. In Android Studio: Run > Edit Configurations > Additional run args:
//       --dart-define-from-file=.env
// ─────────────────────────────────────────────────────────────────────────────

class AppConfig {
  AppConfig._(); // prevent instantiation

  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Call this at startup to give a clear error if credentials are missing.
  static void validate() {
    assert(supabaseUrl.isNotEmpty,
        'SUPABASE_URL is not set. Add it to .env and pass --dart-define-from-file=.env');
    assert(supabaseAnonKey.isNotEmpty,
        'SUPABASE_ANON_KEY is not set. Add it to .env and pass --dart-define-from-file=.env');
  }
}
