import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/core/di/injection.dart';
import 'package:app/core/network/httpClient.dart' as http;
import 'package:app/core/config/appConfig.dart';
import 'package:app/core/services/cacheService.dart';
import 'package:app/features/auth/providers/authRepository.dart';

class NotificationState extends ChangeNotifier {
  final AuthRepository _authRepository;

  NotificationState(this._authRepository);

  int _unreadCount = CacheService.get<int>('global_unread_count') ?? 0;

  int get unreadCount => _unreadCount;

  void setUnreadCount(int count) {
    _unreadCount = count;
    CacheService.set('global_unread_count', count);
    notifyListeners();
  }

  Future<void> fetchUnreadCount() async {
    final authRepo = _authRepository;
    if (!authRepo.isLoggedIn) {
      _unreadCount = 0;
      CacheService.set('global_unread_count', 0);
      notifyListeners();
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('${AppConfig.apiUrl}/notifications?type=all'),
        headers: authRepo.authHeaders,
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final data = decoded['data'] ?? decoded;
        final count = data['unread_count'] as int? ?? 0;
        _unreadCount = count;
        CacheService.set('global_unread_count', count);
      } else {
        _unreadCount = 0;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[NotificationState] fetch error: $e');
    }
  }

  void markAllRead() {
    _unreadCount = 0;
    CacheService.set('global_unread_count', 0);
    notifyListeners();
  }

  void decrement() {
    if (_unreadCount > 0) {
      _unreadCount--;
      CacheService.set('global_unread_count', _unreadCount);
      notifyListeners();
    }
  }
}

final notificationStateProvider = ChangeNotifierProvider<NotificationState>((ref) {
  return NotificationState(ref.watch(authRepositoryProvider));
});
