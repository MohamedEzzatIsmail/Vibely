import 'layout/home.dart';
import 'layout/feeds/post_details_screen.dart';
import 'layout/legal/legal_screen.dart';
import 'layout/close_friends/close_friends_screen.dart';
import 'layout/edit_profile/edit_profile_screen.dart';
import 'layout/blocked_users/blocked_users_screen.dart';
import 'layout/onboarding/onboarding_flow.dart';
import 'layout/explore/explore_screen.dart';
import 'share/network/notification_router.dart';
import 'share/local/constants.dart';
import 'share/local/cashe_helper.dart';
import 'share/local/app_config.dart';
import 'share/style/theme.dart';
import 'services/auth_service.dart';
import 'services/repositories/user_repository.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:media_kit/media_kit.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_links/app_links.dart';

import 'layout/cubit/chat/chat_cubit.dart';
import 'layout/cubit/cubit.dart';
import 'layout/cubit/language/language_cubit.dart';
import 'layout/cubit/notifications/notifications_cubit.dart';
import 'layout/cubit/post/post_cubit.dart';
import 'layout/cubit/theme/theme_cubit.dart';
import 'layout/login/cubit/login_cubit.dart';
import 'layout/login/login_screen.dart';
import 'layout/notifications/fcm_service.dart' hide navigatorKey;
import 'layout/register/cubit/register_cubit.dart';
import 'layout/register/email_verification_screen.dart';

export 'layout/notifications/fcm_service.dart'
    show firebaseMessagingBackgroundHandler;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  // ── 1. Firebase ────────────────────────────────────────────────────────────
  await Firebase.initializeApp();

  // ── 2. Crashlytics ─────────────────────────────────────────────────────────
  await FirebaseCrashlytics.instance
      .setCrashlyticsCollectionEnabled(!kDebugMode);
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  // ── 3. FCM ─────────────────────────────────────────────────────────────────
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  await FCMService.init();

  // ── 4. Shared preferences ──────────────────────────────────────────────────
  await CashHelper.init();

  // ── 5. Credentials ─────────────────────────────────────────────────────────
  AppConfig.validate();

  // ── 6. Supabase ────────────────────────────────────────────────────────────
  await Supabase.initialize(
    url:     AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );

  // ── 7. Load persisted theme + language in parallel ─────────────────────────
  final themeCubit    = await ThemeCubit.create();
  final languageCubit = await LanguageCubit.create();

  // ── 8. Run ─────────────────────────────────────────────────────────────────
  runApp(
    MultiBlocProvider(
      providers: [
        BlocProvider.value(value: themeCubit),
        BlocProvider.value(value: languageCubit),
        BlocProvider(create: (_) => RegisterCubit()),
        BlocProvider(create: (_) => LoginCubit()),
        BlocProvider(create: (_) => MainCubit()..initializeApp()),
        BlocProvider(create: (_) => PostsCubit()..getPosts()),
        BlocProvider(create: (_) => ChatCubit()),
        BlocProvider(create: (_) => NotificationsCubit()),
      ],
      child: const MyApp(),
    ),
  );
}

// ──────────────────────────────────────────────────────────────────────────────
//  Root app widget
// ──────────────────────────────────────────────────────────────────────────────
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = navigatorKey.currentContext;
      if (ctx != null) FCMService.handleTerminatedMessage(ctx);
      _setOnline(true);
    });
    _initDeepLinks();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    FCMService.updateLifecycle(state);
    switch (state) {
      case AppLifecycleState.resumed:
        _setOnline(true);
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        _setOnline(false);
        break;
      default:
        break;
    }
  }

  void _setOnline(bool online) {
    final ctx = navigatorKey.currentContext;
    if (ctx == null) return;
    try { ChatCubit.get(ctx).setOnline(online); } catch (_) {}
  }

  void _initDeepLinks() {
    final appLinks = AppLinks();
    appLinks.getInitialLink().then((uri) {
      if (uri != null) _handleDeepLink(uri);
    });
    appLinks.uriLinkStream.listen(_handleDeepLink);
  }

  void _handleDeepLink(Uri uri) {
    final segments = uri.pathSegments;
    String? postId;
    if (uri.scheme == 'vibely' && uri.host == 'post' && segments.isNotEmpty) {
      postId = segments.first;
    } else if ((uri.scheme == 'https' || uri.scheme == 'http') &&
        segments.length >= 2 && segments[0] == 'post') {
      postId = segments[1];
    }
    if (postId != null && postId.isNotEmpty) {
      final ctx = navigatorKey.currentContext;
      if (ctx != null) {
        Navigator.push(ctx, MaterialPageRoute(
          builder: (_) => PostDetailsScreen(
            postId: postId!,
            navigationTarget: const PostNavigationTarget.none(),
          ),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Both theme AND language changes trigger a full rebuild of MaterialApp
    return BlocBuilder<ThemeCubit, ThemeState>(
      builder: (context, themeState) {
        return BlocBuilder<LanguageCubit, LanguageState>(
          builder: (context, langState) {
            return MaterialApp(
              navigatorKey: navigatorKey,
              debugShowCheckedModeBanner: false,

              // ── Theme ──────────────────────────────────────────────
              theme:     lightTheme,
              darkTheme: darkTheme,
              themeMode: themeState is LightThemeState
                  ? ThemeMode.light
                  : ThemeMode.dark,

              // ── Locale & RTL ───────────────────────────────────────
              locale: langState.locale,
              supportedLocales: const [Locale('en'), Locale('ar')],
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],

              // ── Start screen ───────────────────────────────────────
              home: const SplashScreen(),

              // ── Named routes ───────────────────────────────────────
              routes: {
                '/close-friends':  (_) => const CloseFriendsScreen(),
                '/edit-profile':   (_) => const EditProfileScreen(),
                '/blocked-users':  (_) => const BlockedUsersScreen(),
                '/terms':          (_) => const LegalScreen(type: LegalType.terms),
                '/privacy-policy': (_) => const LegalScreen(type: LegalType.privacy),
                // Search lives in ExploreScreen — see
                // lib/layout/search/search_screen.dart.
                '/search':         (_) => const ExploreScreen(),
              },
            );
          },
        );
      },
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
//  Splash screen — runs onboarding flow then routes to Home or Login
// ──────────────────────────────────────────────────────────────────────────────
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
    _runSequence();
  }

  Future<void> _runSequence() async {
    // Step A — show splash
    await _ctrl.forward();
    await Future.delayed(const Duration(milliseconds: 1400));

    if (!mounted) return;

    // Steps C, D, E — language → privacy → notifications
    await OnboardingFlow.run(context);

    if (!mounted) return;

    await _ctrl.reverse();

    if (!mounted) return;

    // Route to home, verification, or login
    final verified = await AuthService.instance.checkVerifiedSession();
    if (!mounted) return;

    Widget destination;
    if (verified == true) {
      final uid = AuthService.instance.currentUser?.uid;
      if (uid != null) await UserRepository.markEmailVerified(uid);
      destination = const HomeScreen();
    } else if (verified == false) {
      // Signed in with Firebase but never finished verifying — send them
      // back into the verification flow instead of dropping them at a
      // bare login form (and instead of letting them into Home, which
      // was the original bug).
      destination = EmailVerificationScreen(
        email: AuthService.instance.currentUser?.email ?? '',
      );
    } else {
      destination = const LoginScreen();
    }

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => destination,
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: FadeTransition(
        opacity: _fade,
        child: Stack(children: [
          Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Image.asset('assets/app_icon/app_icon.png', width: 88, height: 88),
              const SizedBox(height: 20),
              const Text('Vibely',
                  style: TextStyle(
                      color: Color(0xFFe5c687),
                      fontSize: 38,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 3)),
              const SizedBox(height: 8),
              const Text('connect  ·  share  ·  vibe',
                  style: TextStyle(
                      color: Color(0x73E5C687),
                      fontSize: 11,
                      letterSpacing: 4)),
            ]),
          ),
          Positioned(
            bottom: 40, left: 0, right: 0,
            child: Column(children: [
              const Text('a product by',
                  style: TextStyle(
                      color: Color(0x33FFFFFF),
                      fontSize: 12,
                      letterSpacing: 2)),
              Image.asset('assets/app_icon/innova.png', height: 80),
            ]),
          ),
        ]),
      ),
    );
  }
}
