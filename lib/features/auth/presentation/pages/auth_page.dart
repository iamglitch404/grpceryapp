import 'package:flutter/material.dart';
import 'package:cubepod_core/cubepod_core.dart';
import 'package:cubepod_flutter/cubepod_flutter.dart';
import 'package:app/features/auth/presentation/state/auth_view_state.dart';
import 'login_page.dart';
import 'signup_page.dart';
import 'forgot_password_page.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  @override
  void initState() {
    super.initState();
    // Ensure we start at login when this page is opened
    CubePod.get<AuthViewState>().switchView(AuthViewMode.login);
  }

  @override
  Widget build(BuildContext context) {
    final authViewState = CubePod.get<AuthViewState>();

    return CubeBuilder(
      builder: (context, watch) {
        final mode = watch(authViewState.currentView);
        switch (mode) {
          case AuthViewMode.login:
            return const LoginPage();
          case AuthViewMode.signup:
            return const SignupPage();
          case AuthViewMode.forgotPassword:
            return const ForgotPasswordPage();
        }
      },
    );
  }
}
