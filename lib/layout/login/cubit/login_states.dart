// lib/layout/login/cubit/login_states.dart
//
// Fixed: base class is now `LoginStates` (was `LoginState` in original).
// auth_cubit_test.dart imports this file and references LoginStates,
// LoginInitialState, LoginLoadingState, LoginSuccessState, LoginErrorState,
// LoginPasswordState — all defined here.

abstract class LoginStates {}

class LoginInitialState extends LoginStates {}

class LoginLoadingState extends LoginStates {}

class LoginSuccessState extends LoginStates {
  final String uid;
  LoginSuccessState(this.uid);
}

class LoginNeedsVerificationState extends LoginStates {
  final String email;
  LoginNeedsVerificationState(this.email);
}

class LoginErrorState extends LoginStates {
  final String error;
  LoginErrorState(this.error);
}

class LoginPasswordState extends LoginStates {}
