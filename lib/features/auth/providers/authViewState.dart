import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AuthViewMode { login, signup, forgotPassword }

class AuthViewState extends ChangeNotifier {
  AuthViewMode _currentView = AuthViewMode.login;

  AuthViewMode get currentView => _currentView;

  void switchView(AuthViewMode mode) {
    if (_currentView != mode) {
      _currentView = mode;
      notifyListeners();
    }
  }
}

final authViewStateProvider = ChangeNotifierProvider<AuthViewState>((ref) {
  return AuthViewState();
});
