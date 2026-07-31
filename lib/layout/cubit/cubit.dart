// lib/layout/cubit/cubit.dart

import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import '../../layout/chats/chats_screen.dart';
import '../../layout/feeds/feeds_screen.dart';
import '../../layout/setting/setting_screen.dart';
import '../../layout/users/users_screen.dart';
import '../../layout/explore/explore_screen.dart';
import '../../models/user_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import '../../share/local/cashe_helper.dart';
import '../../share/local/media_permission_service.dart';
import '../../services/auth_service.dart';
import '../../services/repositories/user_repository.dart';
import '../notifications/fcm_service.dart';
import 'chat/chat_cubit.dart';
import 'states.dart';

class MainCubit extends Cubit<MainStates> {
  MainCubit() : super(MainInitStates());
  static MainCubit get(context) => BlocProvider.of(context);

  UserModel? model;

  /// Current user's UID — sourced from Firebase Auth, not a global variable.
  String? get uID => AuthService.instance.currentUid;

  // ── User data ─────────────────────────────────────────────────────────────
  /// Loads the CURRENT user's own profile — public + private data merged.
  /// Never call this to view someone else's profile (see
  /// other_profile_screen.dart, which reads the public doc directly).
  Future<void> getUserData(String? uid) async {
    if (uid == null || uid.isEmpty) {
      emit(MainGetUserDataErrorStates('UID is null'));
      return;
    }

    emit(MainGetUserDataLoadingStates());

    try {
      final doc = await UserRepository.getUser(uid);

      if (!doc.exists || doc.data() == null) {
        emit(MainGetUserDataErrorStates('User not found'));
        return;
      }

      final data = doc.data()!;

      if (!data.containsKey('uid') || data['uid'] == null) {
        await UserRepository.ensureUidField(uid: uid);
        data['uid'] = uid;
      }

      model = await UserRepository.getFullUserModel(uid);
      emit(MainGetUserDataSuccessStates());
    } catch (e) {
      emit(MainGetUserDataErrorStates(e.toString()));
    }
  }

  // ── Update profile ────────────────────────────────────────────────────────
  Future<void> updateProfileData({
    required String name,
    required String bio,
    required String phone,
    String? imageUrl,
    String? coverUrl,
    String? password,
    String? currentPassword, // required when changing password
    BuildContext? context,
  }) async {
    if (model == null) return;
    emit(UpdateProfileLoadingState());

    try {
      final user = AuthService.instance.currentUser!;
      final uid = user.uid;

      final Map<String, dynamic> updateData = {
        'name': name,
        'bio': bio,
        // Mirrors the private doc's real phone, but nulled out if the user
        // has chosen to hide it — see UserModel.toMap's doc comment.
        'phone': model!.hidePhone ? null : phone,
      };

      if (imageUrl != null) updateData['image'] = imageUrl;
      if (coverUrl != null) updateData['cover'] = coverUrl;

      await UserRepository.updateProfile(uid: uid, data: updateData);
      await UserRepository.updatePrivateData(
          uid: uid, data: {'realPhone': phone});

      if (password != null && password.isNotEmpty) {
        // Re-authenticate before changing password (Firebase requirement)
        if (currentPassword == null || currentPassword.isEmpty) {
          emit(UpdateProfileErrorState(
              'Current password is required to change your password.'));
          return;
        }
        await AuthService.instance.reauthenticate(
          currentPassword: currentPassword,
        );
        await AuthService.instance.updatePassword(password);
      }

      model!
        ..name = name
        ..bio = bio
        ..phone = phone;

      if (imageUrl != null) model!.image = imageUrl;
      if (coverUrl != null) model!.cover = coverUrl;

      emit(UpdateProfileSuccessState());
    } catch (error) {
      emit(UpdateProfileErrorState(error.toString()));
    }
  }

  // ── Delete account ────────────────────────────────────────────────────────
  Future<void> deleteAccount({
    required String password,
    required BuildContext context,
  }) async {
    emit(DeleteAccountLoadingState());
    try {
      final uid = uID;
      if (uid == null) {
        emit(DeleteAccountErrorState('Not signed in.'));
        return;
      }

      // Step 1: Re-authenticate (Firebase requires this before account deletion)
      await AuthService.instance.reauthenticate(currentPassword: password);

      // Step 2: Delete Firestore data
      await UserRepository.deleteUserFirestoreData(uid);

      // Step 3: Delete Firebase Auth account
      await AuthService.instance.deleteAccount();

      // Step 4: Clear local session
      await CashHelper.saveData(key: 'uId', value: null);

      emit(DeleteAccountSuccessState());
    } on FirebaseAuthException catch (e) {
      final msg = e.code == 'wrong-password'
          ? 'Incorrect password. Please try again.'
          : e.message ?? 'Authentication failed.';
      emit(DeleteAccountErrorState(msg));
    } catch (e) {
      emit(DeleteAccountErrorState(e.toString()));
    }
  }

  // ── Upload images ─────────────────────────────────────────────────────────
  File? profileImage;
  File? coverImage;

  Future<void> pickProfileImage({BuildContext? ctx}) async {
    if (ctx != null) {
      final ok =
          await MediaPermissionService.requestMediaPermission(ctx);
      if (!ok) return;
    }
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      profileImage = File(pickedFile.path);
      emit(ProfileImagePickedSuccessState());
    }
  }

  Future<void> pickCoverImage({BuildContext? ctx}) async {
    if (ctx != null) {
      final ok =
          await MediaPermissionService.requestMediaPermission(ctx);
      if (!ok) return;
    }
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      coverImage = File(pickedFile.path);
      emit(CoverImagePickedSuccessState());
    }
  }

  Future<void> uploadImagesToSupabase() async {
    if (model == null) return;
    emit(UpdateProfileLoadingState());

    try {
      String? profileUrl;
      String? coverUrl;
      final uid = AuthService.instance.currentUser!.uid;

      if (profileImage != null) {
        profileUrl = await UserRepository.uploadProfileImage(
          uid: uid,
          bytes: await profileImage!.readAsBytes(),
        );
      }

      if (coverImage != null) {
        coverUrl = await UserRepository.uploadCoverImage(
          uid: uid,
          bytes: await coverImage!.readAsBytes(),
        );
      }

      await UserRepository.updateProfile(
        uid: uid,
        data: {
          if (profileUrl != null) 'image': profileUrl,
          if (coverUrl != null) 'cover': coverUrl,
        },
      );

      if (profileUrl != null) model!.image = profileUrl;
      if (coverUrl != null) model!.cover = coverUrl;

      profileImage = null;
      coverImage = null;

      emit(UpdateProfileSuccessState());
    } catch (e) {
      emit(UpdateProfileErrorState(e.toString()));
    }
  }

  // ── Bottom nav ─────────────────────────────────────────────────────────────
  int currentIndex = 0;

  List<Widget> get screens => [
        FeedsScreen(),
        const ExploreScreen(),
        ChatsScreen(),
        const UsersScreen(),
        SettingsScreen(),
      ];

  void changeBottomNav(int index) {
    currentIndex = index;
    _refreshCurrentTab(index);
    emit(ChangingBottomNavStates());
  }

  Future<void> _refreshCurrentTab(int index) async {
    switch (index) {
      case 0:
        // Feed refreshes via its own RefreshIndicator; nothing needed here
        break;

      case 1:
        // Explore — no auto-refresh needed
        break;

      case 2:
        // Chats: reload users list to surface new conversations
        // Using the context stored in the cubit is unsafe here, so we
        // emit a state change and let ChatsScreen handle the reload.
        emit(ChangingBottomNavStates());
        break;

      case 3:
        // Notifications tab — refresh user data to update unread count
        await getUserData(uID);
        break;

      case 4:
        // Settings — refresh user profile
        await getUserData(uID);
        break;
    }
  }

  // ── Initialize app ─────────────────────────────────────────────────────────
  Future<void> initializeApp() async {
    final firebaseUser = AuthService.instance.currentUser;
    if (firebaseUser == null) return;
    await getUserData(firebaseUser.uid);
    await saveFCMToken();
    listenToTokenRefresh();
  }

  Future<void> initChatUser(BuildContext context) async {
    final firebaseUser = AuthService.instance.currentUser;
    if (firebaseUser == null) return;
    final userModel = await UserRepository.getFullUserModel(firebaseUser.uid);
    final cubit = ChatCubit.get(context);
    cubit.setCurrentUser(userModel);
    cubit.loadUsers();
  }

  // ── FCM token ─────────────────────────────────────────────────────────────
  Future<void> saveFCMToken() async {
    if (uID == null) return;
    final token = await FCMService.getValidToken();
    if (token == null) return;
    try {
      final doc = await UserRepository.getPrivateData(uID!);
      final currentToken = doc.data()?['fcmToken'];
      if (currentToken == token) return;
      await UserRepository.updateFcmToken(uid: uID!, token: token);
      if (kDebugMode) debugPrint('✅ FCM token saved');
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error saving FCM token: $e');
    }
  }

  void listenToTokenRefresh() {
    FCMService.listenTokenRefresh((newToken) async {
      if (uID == null) return;
      try {
        await UserRepository.updateFcmToken(uid: uID!, token: newToken);
        if (kDebugMode) debugPrint('🔄 Token refreshed & updated');
      } catch (e) {
        if (kDebugMode)
          debugPrint('❌ Error updating refreshed token: $e');
      }
    });
  }
}
