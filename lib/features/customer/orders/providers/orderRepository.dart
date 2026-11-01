import 'package:flutter/foundation.dart';
import 'package:app/core/network/httpClient.dart' as http;
import 'dart:convert';
import 'package:app/core/config/appConfig.dart';
import 'package:app/features/auth/providers/authRepository.dart';

class OrderRepository {
  final AuthRepository _authRepository;

  OrderRepository([AuthRepository? authRepository])
      : _authRepository = authRepository ?? AuthRepository();

  Future<void> cancelOrder(String orderId) async {
    final headers = _authRepository.authHeaders;
    final response = await http.patch(
      Uri.parse('${AppConfig.apiUrl}/orders/$orderId'),
      headers: {
        ...headers,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'status': 'Cancelled'}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      String message = 'Failed to cancel order';
      try {
        final data = jsonDecode(response.body);
        if (data is Map && data['error'] != null) {
          message = data['error'].toString();
        }
      } catch (_) {}
      throw Exception(message);
    }
  }

  Future<void> placeOrder({
    String? addressId,
    required String deliverySlot,
    required String paymentMethod,
    int slotFeePaise = 0,
    double? userLatitude,
    double? userLongitude,
    String? deviceLocationAddress,
    String? destinationAddress,
    double? destinationLatitude,
    double? destinationLongitude,
    List<Map<String, dynamic>>? items,
  }) async {
    final headers = _authRepository.authHeaders;
    final payload = {
      'address_id': ?addressId,
      'delivery_slot': deliverySlot,
      'payment_method': paymentMethod,
      'slot_fee_paise': slotFeePaise,
      'user_latitude': ?userLatitude,
      'user_longitude': ?userLongitude,
      'device_location_address': ?deviceLocationAddress,
      'destination_address': ?destinationAddress,
      'destination_latitude': ?destinationLatitude,
      'destination_longitude': ?destinationLongitude,
      'items': ?items,
    };

    final response = await http.post(
      Uri.parse('${AppConfig.apiUrl}/orders'),
      headers: {
        ...headers,
        'Content-Type': 'application/json',
      },
      body: jsonEncode(payload),
    );
    
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    } else {
      final data = jsonDecode(response.body);
      throw Exception(data['error'] ?? 'Failed to place order');
    }
  }

  Future<Map<String, dynamic>?> fetchOrderById(String orderId) async {
    try {
      final headers = _authRepository.authHeaders;
      final response = await http.get(
        Uri.parse('${AppConfig.apiUrl}/orders/$orderId'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final ord = data['order'] ?? data['data']?['order'];
          if (ord is Map) {
            return Map<String, dynamic>.from(ord);
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching order detail: $e');
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> fetchCurrentOrders(String userId) async {
    try {
      final headers = _authRepository.authHeaders;
      final response = await http.get(
        Uri.parse('${AppConfig.apiUrl}/orders?status=active'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final ordersList = data['data']?['orders'] ?? data['orders'] ?? [];
          return List<Map<String, dynamic>>.from(ordersList);
        }
      }
    } catch (e) {
      debugPrint('Error fetching current orders: $e');
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> fetchPreviousOrders(String userId) async {
    try {
      final headers = _authRepository.authHeaders;
      final response = await http.get(
        Uri.parse('${AppConfig.apiUrl}/orders?status=history'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final ordersList = data['data']?['orders'] ?? data['orders'] ?? [];
          return List<Map<String, dynamic>>.from(ordersList);
        }
      }
    } catch (e) {
      debugPrint('Error fetching previous orders: $e');
    }
    return [];
  }
}
