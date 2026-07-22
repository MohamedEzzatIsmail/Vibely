class RegisterStates {
  const RegisterStates();
}

class RegisterInitStates extends RegisterStates {
  const RegisterInitStates();
}

class RegisterLoadingStates extends RegisterStates {
  const RegisterLoadingStates();
}

class RegisterSuccessStates extends RegisterStates {
  const RegisterSuccessStates();
}

class RegisterErrorState extends RegisterStates {
  final String error;

  const RegisterErrorState(this.error);
}

class RegisterPasswordStates extends RegisterStates {
  const RegisterPasswordStates();
}

/// Emitted when registration succeeded but email not yet verified.
class RegisterNeedsVerificationState extends RegisterStates {
  final String email;

  const RegisterNeedsVerificationState({
    required this.email,
  });
}

/// Emitted after successfully resending the verification email.
class RegisterVerificationResent extends RegisterStates {
  const RegisterVerificationResent();
}