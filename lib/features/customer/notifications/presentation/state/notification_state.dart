import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cubepod_core/cubepod_core.dart';
import 'package:cubepod_state/cubepod_state.dart';
import 'package:app/core/network/http_client.dart' as http;
import 'package:app/core/config/app_config.dart';
import 'package:app/core/services/cache_service.dart';
import 'package:app/features/auth/data/repositories/auth_repository.dart';

class NotificationState {
  final StateSignal<int> unreadCount = StateSignal(
    CacheService.get<int>('global_unread_count') ?? 0,
  );

  Future<void> fetchUnreadCount() async {
    final authRepo = CubePod.get<AuthRepository>();
    if (!authRepo.isLoggedIn) {
      unreadCount.value = 0;
      CacheService.set('global_unread_count', 0);
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
        unreadCount.value = count;
        CacheService.set('global_unread_count', count);
      } else {
        unreadCount.value = 0;
      }
    } catch (e) {
      debugPrint('[NotificationState] fetch error: $e');
    }
  }

  void markAllRead() {
    unreadCount.value = 0;
    CacheService.set('global_unread_count', 0);
  }

  void decrement() {
    if (unreadCount.value > 0) {
      unreadCount.value--;
      CacheService.set('global_unread_count', unreadCount.value);
    }
  }
}
