import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/features/auth/providers/authViewState.dart';
import 'loginPage.dart';
import 'signupPage.dart';
import 'forgotPasswordPage.dart';

class AuthPage extends ConsumerStatefulWidget {
  const AuthPage({super.key});

  @override
  ConsumerState<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends ConsumerState<AuthPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(authViewStateProvider).switchView(AuthViewMode.login);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(authViewStateProvider).currentView;
    switch (mode) {
      case AuthViewMode.login:
        return const LoginPage();
      case AuthViewMode.signup:
        return const SignupPage();
      case AuthViewMode.forgotPassword:
        return const ForgotPasswordPage();
    }
  }
}
