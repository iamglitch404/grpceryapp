import 'package:cubepod_state/cubepod_state.dart';

enum AuthViewMode { login, signup, forgotPassword }

class AuthViewState {
  final StateSignal<AuthViewMode> currentView = StateSignal(AuthViewMode.login);

  void switchView(AuthViewMode mode) {
    currentView.value = mode;
  }
}
