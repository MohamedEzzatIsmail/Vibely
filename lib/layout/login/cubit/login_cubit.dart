// lib/layout/login/cubit/login_cubit.dart
//
// Uses LoginStates (updated base class name) + AuthService for uid retrieval.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../services/repositories/user_repository.dart';
import '../../../share/local/cashe_helper.dart';
import 'login_states.dart';

class LoginCubit extends Cubit<LoginStates> {
  LoginCubit() : super(LoginInitialState());

  static LoginCubit get(context) => BlocProvider.of(context);

  bool isPassword = true;
  IconData suffix = Icons.remove_red_eye_outlined;

  Future<void> userLogin({
    required String email,
    required String password,
  }) async {
    emit(LoginLoadingState());
    try {
      final credential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      var user = credential.user!;
      // Reload to get the freshest emailVerified value from Firebase Auth —
      // the token cached on the credential can be stale if the user verified
      // via the email link in a browser and came straight back to log in.
      await user.reload();
      user = FirebaseAuth.instance.currentUser!;

      if (!user.emailVerified) {
        // Do NOT persist 'uId' here — the splash/auth-gate screen uses that
        // to decide whether to auto-open Home, and an unverified account
        // must never land there. The Firebase session itself stays active
        // so the verification screen's resend/check calls keep working.
        emit(LoginNeedsVerificationState(email.trim()));
        return;
      }

      // Keep Firestore's copy of the flag in sync (covers accounts that
      // verified before this field existed, or via the email link only).
      await UserRepository.markEmailVerified(user.uid);

      final uid = user.uid;
      await CashHelper.saveData(key: 'uId', value: uid);
      emit(LoginSuccessState(uid));
    } on FirebaseAuthException catch (e) {
      emit(LoginErrorState(_friendlyError(e)));
    } catch (e) {
      emit(LoginErrorState(e.toString()));
    }
  }

  void showPassword() {
    isPassword = !isPassword;
    suffix = isPassword
        ? Icons.remove_red_eye_outlined
        : Icons.visibility_off_outlined;
    emit(LoginPasswordState());
  }

  String _friendlyError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      default:
        return e.message ?? 'Login failed. Please try again.';
    }
  }
}
