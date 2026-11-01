import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/features/auth/providers/authProviders.dart';

void main() {
  group('Auth Providers Unit Tests', () {
    test('LoginUiNotifier updates state correctly', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(loginUiProvider).isLoading, false);
      expect(container.read(loginUiProvider).obscurePassword, true);
      expect(container.read(loginUiProvider).rememberMe, false);

      container.read(loginUiProvider.notifier).setLoading(true);
      expect(container.read(loginUiProvider).isLoading, true);

      container.read(loginUiProvider.notifier).toggleObscurePassword();
      expect(container.read(loginUiProvider).obscurePassword, false);

      container.read(loginUiProvider.notifier).setRememberMe(true);
      expect(container.read(loginUiProvider).rememberMe, true);
    });

    test('SignupUiNotifier updates state correctly', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(signupUiProvider).isLoading, false);
      expect(container.read(signupUiProvider).obscurePassword, true);

      container.read(signupUiProvider.notifier).setLoading(true);
      expect(container.read(signupUiProvider).isLoading, true);

      container.read(signupUiProvider.notifier).toggleObscurePassword();
      expect(container.read(signupUiProvider).obscurePassword, false);
    });

    test('ForgotPasswordNotifier handles multi-step reset workflow', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(forgotPasswordProvider.notifier);

      expect(container.read(forgotPasswordProvider).isLoading, false);
      expect(container.read(forgotPasswordProvider).otpSent, false);
      expect(container.read(forgotPasswordProvider).resendTimer, 45);

      notifier.setLoading(true);
      expect(container.read(forgotPasswordProvider).isLoading, true);

      notifier.setOtpSent(true);
      expect(container.read(forgotPasswordProvider).otpSent, true);

      notifier.setOtpVerified(true);
      expect(container.read(forgotPasswordProvider).otpVerified, true);

      notifier.setResetSuccess(true);
      expect(container.read(forgotPasswordProvider).resetSuccess, true);

      notifier.decrementResendTimer();
      expect(container.read(forgotPasswordProvider).resendTimer, 44);

      notifier.triggerRebuild();
      expect(container.read(forgotPasswordProvider).formRebuildCounter, 1);
    });
  });
}

