import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/core/config/appConfig.dart';
import 'package:app/core/di/injection.dart';
import 'package:app/core/network/httpClient.dart' as http;
import 'package:app/core/services/countryService.dart';
import 'package:app/features/customer/support/providers/mistralChatService.dart';

final myTicketsFutureProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final authRepo = ref.watch(authRepositoryProvider);
  final user = authRepo.currentUser;
  if (user == null || user['id'] == null) return [];

  try {
    final response = await http.get(
      Uri.parse('${AppConfig.apiUrl}/tickets'),
      headers: authRepo.authHeaders,
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['tickets'] ?? [];
    }
  } catch (e) {
    debugPrint('[myTicketsFutureProvider] error: $e');
  }
  return [];
});

final myReviewsFutureProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final authRepo = ref.watch(authRepositoryProvider);
  if (!authRepo.isLoggedIn || authRepo.currentUser?['id'] == null) return [];

  try {
    final response = await http.get(
      Uri.parse('${AppConfig.apiUrl}/reviews?user_id=${authRepo.currentUser!['id']}'),
      headers: authRepo.authHeaders,
    );
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    }
  } catch (e) {
    debugPrint('[myReviewsFutureProvider] error: $e');
  }
  return [];
});

final liveChatMessagesProvider = StateProvider.autoDispose<List<dynamic>>((ref) => []);
final liveChatTypingProvider = StateProvider.autoDispose<bool>((ref) => false);
final mistralChatServiceProvider = Provider<MistralChatService>((ref) => MistralChatService());

final callUsCountryProvider = StateProvider.autoDispose<CountryInfo?>((ref) => null);
final callUsCopiedProvider = StateProvider.autoDispose<bool>((ref) => false);
final callUsSubmittingProvider = StateProvider.autoDispose<bool>((ref) => false);
final callUsPhoneTextProvider = StateProvider.autoDispose<String>((ref) => '');

final helpSupportSubmittingProvider = StateProvider.autoDispose<bool>((ref) => false);
final helpSupportAttachmentsProvider = StateProvider.autoDispose<List<dynamic>>((ref) => []);
final helpSupportExpandedFaqsProvider = StateProvider.autoDispose<List<bool>>((ref) => []);
final helpSupportMessageTextProvider = StateProvider.autoDispose<String>((ref) => '');


