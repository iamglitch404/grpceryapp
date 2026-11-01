import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── Forgot Password State ────────────────────────────────────────────────────
class ForgotPasswordState {
  final bool isLoading;
  final bool otpSent;
  final bool otpVerified;
  final bool resetSuccess;
  final bool obscurePassword;
  final bool obscureConfirmPassword;
  final int resendTimer;
  final int formRebuildCounter;

  const ForgotPasswordState({
    this.isLoading = false,
    this.otpSent = false,
    this.otpVerified = false,
    this.resetSuccess = false,
    this.obscurePassword = true,
    this.obscureConfirmPassword = true,
    this.resendTimer = 45,
    this.formRebuildCounter = 0,
  });

  ForgotPasswordState copyWith({
    bool? isLoading,
    bool? otpSent,
    bool? otpVerified,
    bool? resetSuccess,
    bool? obscurePassword,
    bool? obscureConfirmPassword,
    int? resendTimer,
    int? formRebuildCounter,
  }) {
    return ForgotPasswordState(
      isLoading: isLoading ?? this.isLoading,
      otpSent: otpSent ?? this.otpSent,
      otpVerified: otpVerified ?? this.otpVerified,
      resetSuccess: resetSuccess ?? this.resetSuccess,
      obscurePassword: obscurePassword ?? this.obscurePassword,
      obscureConfirmPassword:
          obscureConfirmPassword ?? this.obscureConfirmPassword,
      resendTimer: resendTimer ?? this.resendTimer,
      formRebuildCounter: formRebuildCounter ?? this.formRebuildCounter,
    );
  }
}

class ForgotPasswordNotifier extends StateNotifier<ForgotPasswordState> {
  ForgotPasswordNotifier() : super(const ForgotPasswordState());

  void setLoading(bool value) => state = state.copyWith(isLoading: value);
  void setOtpSent(bool value) => state = state.copyWith(otpSent: value);
  void setOtpVerified(bool value) => state = state.copyWith(otpVerified: value);
  void setResetSuccess(bool value) =>
      state = state.copyWith(resetSuccess: value);
  void toggleObscurePassword() =>
      state = state.copyWith(obscurePassword: !state.obscurePassword);
  void toggleObscureConfirmPassword() => state =
      state.copyWith(obscureConfirmPassword: !state.obscureConfirmPassword);
  void setResendTimer(int value) => state = state.copyWith(resendTimer: value);
  void decrementResendTimer() {
    if (state.resendTimer > 0) {
      state = state.copyWith(resendTimer: state.resendTimer - 1);
    }
  }

  void triggerRebuild() =>
      state = state.copyWith(formRebuildCounter: state.formRebuildCounter + 1);
}

final forgotPasswordProvider = StateNotifierProvider.autoDispose<
    ForgotPasswordNotifier, ForgotPasswordState>((ref) {
  return ForgotPasswordNotifier();
});

// ── Login State ──────────────────────────────────────────────────────────────
class LoginUiState {
  final bool isLoading;
  final bool obscurePassword;
  final bool rememberMe;

  const LoginUiState({
    this.isLoading = false,
    this.obscurePassword = true,
    this.rememberMe = false,
  });

  LoginUiState copyWith({
    bool? isLoading,
    bool? obscurePassword,
    bool? rememberMe,
  }) {
    return LoginUiState(
      isLoading: isLoading ?? this.isLoading,
      obscurePassword: obscurePassword ?? this.obscurePassword,
      rememberMe: rememberMe ?? this.rememberMe,
    );
  }
}

class LoginUiNotifier extends StateNotifier<LoginUiState> {
  LoginUiNotifier() : super(const LoginUiState());

  void setLoading(bool value) => state = state.copyWith(isLoading: value);
  void toggleObscurePassword() =>
      state = state.copyWith(obscurePassword: !state.obscurePassword);
  void setRememberMe(bool value) => state = state.copyWith(rememberMe: value);
}

final loginUiProvider =
    StateNotifierProvider.autoDispose<LoginUiNotifier, LoginUiState>((ref) {
  return LoginUiNotifier();
});

// ── Signup State ─────────────────────────────────────────────────────────────
class SignupUiState {
  final bool isLoading;
  final bool obscurePassword;

  const SignupUiState({
    this.isLoading = false,
    this.obscurePassword = true,
  });

  SignupUiState copyWith({
    bool? isLoading,
    bool? obscurePassword,
  }) {
    return SignupUiState(
      isLoading: isLoading ?? this.isLoading,
      obscurePassword: obscurePassword ?? this.obscurePassword,
    );
  }
}

class SignupUiNotifier extends StateNotifier<SignupUiState> {
  SignupUiNotifier() : super(const SignupUiState());

  void setLoading(bool value) => state = state.copyWith(isLoading: value);
  void toggleObscurePassword() =>
      state = state.copyWith(obscurePassword: !state.obscurePassword);
}

final signupUiProvider =
    StateNotifierProvider.autoDispose<SignupUiNotifier, SignupUiState>((ref) {
  return SignupUiNotifier();
});

// ── Auth OTP Dialog State ────────────────────────────────────────────────────
class AuthOtpDialogState {
  final int step;
  final bool isDialogLoading;
  final bool isResending;
  final String? inlineErrorMessage;

  const AuthOtpDialogState({
    this.step = 1,
    this.isDialogLoading = false,
    this.isResending = false,
    this.inlineErrorMessage,
  });

  AuthOtpDialogState copyWith({
    int? step,
    bool? isDialogLoading,
    bool? isResending,
    String? inlineErrorMessage,
    bool clearError = false,
  }) {
    return AuthOtpDialogState(
      step: step ?? this.step,
      isDialogLoading: isDialogLoading ?? this.isDialogLoading,
      isResending: isResending ?? this.isResending,
      inlineErrorMessage:
          clearError ? null : (inlineErrorMessage ?? this.inlineErrorMessage),
    );
  }
}

class AuthOtpDialogNotifier extends StateNotifier<AuthOtpDialogState> {
  AuthOtpDialogNotifier() : super(const AuthOtpDialogState());

  void reset() => state = const AuthOtpDialogState();
  void setStep(int step) => state = state.copyWith(step: step);
  void setLoading(bool value) => state = state.copyWith(isDialogLoading: value);
  void setResending(bool value, {bool clearError = false}) =>
      state = state.copyWith(isResending: value, clearError: clearError);
  void setError(String? message) => state = state.copyWith(
        inlineErrorMessage: message,
        clearError: message == null,
      );
}

final authOtpDialogProvider = StateNotifierProvider.autoDispose<
    AuthOtpDialogNotifier, AuthOtpDialogState>((ref) {
  return AuthOtpDialogNotifier();
});
