import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:app/core/config/appConfig.dart';
import 'package:app/core/di/injection.dart';
import 'package:app/core/network/httpClient.dart' as http;

final orderHistorySelectedTabProvider = StateProvider.autoDispose<int>((ref) => 0);

// ── OrderTrackingPage State Providers ──
final orderTrackingOrderProvider =
    StateProvider.autoDispose<Map<String, dynamic>?>((ref) => null);
final orderTrackingIsLoadingProvider =
    StateProvider.autoDispose<bool>((ref) => false);
final orderTrackingCustomerLocationProvider =
    StateProvider.autoDispose<LatLng>((ref) => const LatLng(27.7025, 85.3120));
final orderTrackingRiderLocationProvider =
    StateProvider.autoDispose<LatLng?>((ref) => null);
final orderTrackingRoutePointsProvider =
    StateProvider.autoDispose<List<LatLng>>((ref) => []);
final orderTrackingDistanceMetersProvider =
    StateProvider.autoDispose<double>((ref) => 0);
final orderTrackingDurationSecsProvider =
    StateProvider.autoDispose<double>((ref) => 0);

final currentOrdersFutureProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final authRepo = ref.watch(authRepositoryProvider);
  if (!authRepo.isLoggedIn) return [];
  try {
    final response = await http.get(
      Uri.parse('${AppConfig.apiUrl}/orders?status=active'),
      headers: authRepo.authHeaders,
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        final list = data['orders'] ?? data['data']?['orders'] ?? [];
        return List<Map<String, dynamic>>.from(list);
      }
    }
  } catch (e) {
    debugPrint('[currentOrdersFutureProvider] error: $e');
  }
  return [];
});

final previousOrdersFutureProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final authRepo = ref.watch(authRepositoryProvider);
  if (!authRepo.isLoggedIn) return [];
  try {
    final response = await http.get(
      Uri.parse('${AppConfig.apiUrl}/orders?status=history'),
      headers: authRepo.authHeaders,
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        final list = data['orders'] ?? data['data']?['orders'] ?? [];
        return List<Map<String, dynamic>>.from(list);
      }
    }
  } catch (e) {
    debugPrint('[previousOrdersFutureProvider] error: $e');
  }
  return [];
});
