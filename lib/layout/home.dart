import 'cubit/cubit.dart';
import 'cubit/states.dart';
import 'package:flutter/material.dart';
import '../share/style/app_colors.dart';
import '../share/local/app_strings.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import '../share/local/cashe_helper.dart';
import '../share/network/notification_router.dart';
import 'cubit/chat/chat_cubit.dart';
import 'cubit/chat/chat_states.dart';
import 'cubit/notifications/notifications_cubit.dart';
import 'cubit/post/post_cubit.dart';
import 'feeds/post_details_screen.dart';
import 'stories/stories_cubit.dart';
import '../share/local/media_permission_service.dart';
import '../services/presence_service.dart';
import 'dart:async';
import 'package:app_links/app_links.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _showWelcomeBanner = false;
  bool _checkedWelcome    = false;
  StreamSubscription<Uri>? _linkSub;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_checkedWelcome) return;
    _checkedWelcome = true;
    _handleWelcome();
  }

  Future<void> _handleWelcome() async {
    final shown = await CashHelper.getData(key: 'welcomeShown');
    if (shown == true) {
      // Not first launch — still check silently in case permission was revoked
      // No dialog, just update internal state. If user tries to use media,
      // the individual gates will prompt them.
      return;
    }
    await CashHelper.saveData(key: 'welcomeShown', value: true);
    if (!mounted) return;
    setState(() => _showWelcomeBanner = true);
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) setState(() => _showWelcomeBanner = false);
    });

    // First launch: request media permission with rationale bottom-sheet,
    // similar to how FCMService requests notification permission.
    // Short delay so the welcome banner is visible first.
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) {
      await MediaPermissionService.requestWithRationale(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => StoriesCubit(),
      child: BlocConsumer<MainCubit, MainStates>(
        listener: (context, state) {
          if (state is MainGetUserDataSuccessStates) {
            final model = MainCubit.get(context).model;
            if (model != null) {
              PostsCubit.get(context)
                ..setCurrentUser(model)
                ..setContext(context);
              ChatCubit.get(context).setContext(context);
              NotificationsCubit.get(context).setUser(model.uid!);
              StoriesCubit.get(context)
                ..setUser(model)
                ..loadStories();
              PresenceService.instance.start(model.uid!);
            }
          }
        },
        builder: (context, state) {
          final cubit = MainCubit.get(context);
          return Scaffold(
            backgroundColor: AppColors.of(context).surface,
            // appBar: AppBar(
            //   backgroundColor: AppColors.of(context).surface,
            //   elevation: 0,
            //   // leading: IconButton(
            //   //   icon: const Icon(Icons.logout, color: Colors.grey, size: 20),
            //   //   onPressed: () async {
            //   //     PostsCubit.get(context).goOffline();
            //   //     await CashHelper.removeData(key: 'uID');
            //   //     await FirebaseAuth.instance.signOut();
            //   //     navigateAndReplacement(context, LoginScreen());
            //   //   },
            //   // ),
            //   title: const Text('Vibely',
            //     style: TextStyle(
            //       color: Color(0xFFe5c687),
            //       fontSize: 22,
            //       fontWeight: FontWeight.bold,
            //       letterSpacing: 1,
            //     ),
            //   ),
            //   centerTitle: true,
            //   actions: [
            //     // Notification bell with badge
            //     BlocBuilder<NotificationsCubit, NotificationsState>(
            //       builder: (context, _) {
            //         final nc = NotificationsCubit.get(context);
            //         return Stack(children: [
            //           IconButton(
            //             icon: Icon(Icons.notifications_outlined, color: AppColors.of(context).text),
            //             onPressed: () {
            //               Navigator.push(context, MaterialPageRoute(
            //                 builder: (_) => const NotificationsScreen()));
            //               nc.markAllAsSeen();
            //             },
            //           ),
            //           if (nc.unreadCount > 0)
            //             Positioned(
            //               right: 8, top: 8,
            //               child: Container(
            //                 padding: const EdgeInsets.all(3),
            //                 decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
            //                 child: Text(
            //                   nc.unreadCount > 9 ? '9+' : '${nc.unreadCount}',
            //                   style: TextStyle(color: AppColors.of(context).text, fontSize: 9, fontWeight: FontWeight.bold)),
            //               ),
            //             ),
            //         ]);
            //       },
            //     ),
            //     // Search icon navigates to explore tab
            //     IconButton(
            //       icon: Icon(Icons.search, color: AppColors.of(context).text),
            //       onPressed: () => cubit.changeBottomNav(1), // Explore is index 1
            //     ),
            //   ],
            // ),

            body: Column(
              children: [
                // Welcome banner
                AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOut,
                  height: _showWelcomeBanner ? 50 : 0,
                  child: ClipRect(
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 300),
                      opacity: _showWelcomeBanner ? 1 : 0,
                      child: Container(
                        width: double.infinity,
                        alignment: Alignment.center,
                        color: const Color(0xFFe5c687),
                        child: Text(AppStrings.of(context).welcomeMessage,
                          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ),
                Expanded(child: cubit.screens[cubit.currentIndex]),
              ],
            ),

            bottomNavigationBar: Container(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.of(context).border)),
              ),
              child: BottomNavigationBar(
                currentIndex: cubit.currentIndex,
                onTap: cubit.changeBottomNav,
                type: BottomNavigationBarType.fixed,
                backgroundColor: AppColors.of(context).surface,
                showSelectedLabels: false,
                showUnselectedLabels: false,
                selectedItemColor: const Color(0xFFe5c687),
                unselectedItemColor: const Color(0xFF404040),
                items: [
                  const BottomNavigationBarItem(icon: Icon(Icons.home_outlined),    activeIcon: Icon(Icons.home_rounded),    label: ''),
                  const BottomNavigationBarItem(icon: Icon(Icons.explore_outlined),  activeIcon: Icon(Icons.explore_rounded), label: ''),
                  BottomNavigationBarItem(
                    icon: BlocBuilder<ChatCubit, ChatStates>(
                      builder: (ctx, _) {
                        final unread = ChatCubit.get(ctx).totalUnreadCount;
                        return Stack(clipBehavior: Clip.none, children: [
                          const Icon(Icons.chat_bubble_outline),
                          if (unread > 0)
                            Positioned(
                              top: -4, right: -6,
                              child: Container(
                                padding:  const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(8)),
                                child: Text(unread > 99 ? '99+' : '$unread',
                                    style:  TextStyle(color: AppColors.of(context).text, fontSize: 9, fontWeight: FontWeight.bold)),
                              ),
                            ),
                        ]);
                      },
                    ),
                    activeIcon: const Icon(Icons.chat_bubble_rounded),
                    label: ''),
                  const BottomNavigationBarItem(icon: Icon(Icons.person_outline),    activeIcon: Icon(Icons.person_rounded),  label: ''),
                  const BottomNavigationBarItem(icon: Icon(Icons.settings_outlined), activeIcon: Icon(Icons.settings_rounded),label: ''),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

    @override
    void initState() {
        super.initState();
        _handleInitialLink();    // for when app was closed
        _linkSub = AppLinks()    // for when app is already open
                .uriLinkStream
                .listen(_openPost);
      }

    @override
    void dispose() {
        _linkSub?.cancel();
        super.dispose();
      }

    Future<void> _handleInitialLink() async {
        final uri = await AppLinks().getInitialLink();
        if (uri != null && mounted) _openPost(uri);
      }

    void _openPost(Uri uri) {
        // vibely://post/ID → scheme=vibely, host=post, pathSegments=[ID]
        // https://vibely.app/post/ID → pathSegments=[post, ID]
        String? postId;
        if (uri.scheme == 'vibely' && uri.host == 'post' && uri.pathSegments.isNotEmpty) {
          postId = uri.pathSegments.first;
        } else if ((uri.scheme == 'https' || uri.scheme == 'http') &&
                   uri.pathSegments.length >= 2 && uri.pathSegments[0] == 'post') {
          postId = uri.pathSegments[1];
        }
        if (postId == null || postId.isEmpty || !mounted) return;
        Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute(builder: (_) =>
            PostDetailsScreen(postId: postId!,
              navigationTarget: const PostNavigationTarget.none())),
        );
      }
}
