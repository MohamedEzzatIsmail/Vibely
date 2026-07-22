// lib/layout/register/cubit/register_cubit.dart
//
// Changes from original:
//  • userRegister() now accepts an optional avatarFile (dart:io File).
//  • If avatarFile is provided it is uploaded; otherwise falls back to the
//    bundled default_avatar.png (original behaviour preserved).
//  • No other logic changed.

import 'dart:io';

import 'package:vibely/layout/register/cubit/register_states.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/user_model.dart';
import '../../../services/repositories/user_repository.dart';

class RegisterCubit extends Cubit<RegisterStates> {
  bool isPassword = true;
  IconData suffix = Icons.visibility_outlined;

  RegisterCubit() : super(RegisterInitStates());
  static RegisterCubit get(context) => BlocProvider.of(context);

  void showPassword() {
    isPassword = !isPassword;
    suffix = isPassword
        ? Icons.visibility_outlined
        : Icons.visibility_off_outlined;
    emit(const RegisterPasswordStates());
  }

  Future<void> userRegister({
    required String name,
    required String email,
    required String password,
    required String phone,
    File? avatarFile, // optional — user-picked photo
  }) async {
    emit(RegisterLoadingStates());
    try {
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      // Send verification email before writing Firestore document
      await credential.user!.sendEmailVerification();

      // Upload avatar: user-picked image takes priority over bundled default
      final avatarUrl = avatarFile != null
          ? await _uploadPickedAvatar(credential.user!.uid, avatarFile)
          : await _uploadDefaultAvatar(credential.user!.uid);

      // Create Firestore user document
      await _createUser(
        name: name,
        email: email,
        phone: phone,
        uID: credential.user!.uid,
        imageUrl: avatarUrl,
      );

      emit(RegisterNeedsVerificationState(email: email));
    } on FirebaseAuthException catch (e) {
      emit(RegisterErrorState(_friendlyAuthError(e)));
    } catch (e) {
      if (kDebugMode) debugPrint('[RegisterCubit] $e');
      emit(RegisterErrorState(e.toString()));
    }
  }

  /// Uploads a user-picked image file to Supabase and returns the public URL.
  Future<String> _uploadPickedAvatar(String uid, File file) async {
    try {
      final bytes    = await file.readAsBytes();
      final filename = 'avatars/avatar_$uid.jpg';
      await Supabase.instance.client.storage
          .from('user-images')
          .uploadBinary(
            filename,
            bytes,
            fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'),
          );
      return Supabase.instance.client.storage
          .from('user-images')
          .getPublicUrl(filename);
    } catch (e) {
      if (kDebugMode) debugPrint('[RegisterCubit] Avatar upload failed: $e');
      // Fall back to bundled default
      return _uploadDefaultAvatar(uid);
    }
  }

  /// Uploads the bundled default_avatar.png to Supabase and returns the URL.
  Future<String> _uploadDefaultAvatar(String uid) async {
    try {
      final bytes    = await rootBundle.load('assets/images/default_avatar.png');
      final data     = bytes.buffer.asUint8List();
      final filename = 'avatars/default_$uid.png';
      await Supabase.instance.client.storage
          .from('user-images')
          .uploadBinary(
            filename,
            data,
            fileOptions: const FileOptions(upsert: true, contentType: 'image/png'),
          );
      return Supabase.instance.client.storage
          .from('user-images')
          .getPublicUrl(filename);
    } catch (e) {
      if (kDebugMode) debugPrint('[RegisterCubit] Default avatar upload failed: $e');
      return '';
    }
  }

  Future<void> _createUser({
    required String name,
    required String email,
    required String phone,
    required String uID,
    String imageUrl = '',
  }) async {
    final model = UserModel(
      name:       name,
      email:      email,
      phone:      phone,
      uid:        uID,
      image:      imageUrl,
      cover:      '',
      bio:        '',
      isVerified: false,
    );

    await FirebaseFirestore.instance
        .collection('Users')
        .doc(uID)
        .set(model.toMap());

    emit(RegisterSuccessStates());
  }

  Future<void> resendVerification() async {
    try {
      await FirebaseAuth.instance.currentUser?.sendEmailVerification();
      emit(RegisterVerificationResent());
    } catch (e) {
      emit(RegisterErrorState('Could not resend email. Try again later.'));
    }
  }

  Future<bool> checkEmailVerified() async {
    final user = FirebaseAuth.instance.currentUser;
    await user?.reload();
    final verified = FirebaseAuth.instance.currentUser?.emailVerified ?? false;
    if (verified && user != null) {
      // Keep our Firestore copy in sync so login gating (and anything
      // else that reads UserModel.emailVerified) sees the real status.
      await UserRepository.markEmailVerified(user.uid);
    }
    return verified;
  }

  String _friendlyAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'An account with this email already exists.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      default:
        return e.message ?? 'Registration failed. Please try again.';
    }
  }
}
