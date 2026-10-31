import 'package:flutter/foundation.dart';
import 'package:app/core/network/http_client.dart' as http;
import 'dart:convert';
import 'package:app/core/config/app_config.dart';
import 'package:cubepod_core/cubepod_core.dart';
import 'package:app/features/auth/data/repositories/auth_repository.dart';

class OrderRepository {
  Future<void> cancelOrder(String orderId) async {
    // Currently, backend might not have cancelOrder, 
    // but typically it would be a PATCH to /api/orders/$orderId
    try {
      final headers = CubePod.get<AuthRepository>().authHeaders;
      await http.patch(
        Uri.parse('${AppConfig.apiUrl}/orders/$orderId'),
        headers: headers,
        body: jsonEncode({'status': 'Cancelled'}),
      );
    } catch (e) {
      debugPrint('Error canceling order: $e');
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
    final headers = CubePod.get<AuthRepository>().authHeaders;
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

  Future<List<Map<String, dynamic>>> fetchCurrentOrders(String userId) async {
    try {
      final headers = CubePod.get<AuthRepository>().authHeaders;
      final response = await http.get(
        Uri.parse('${AppConfig.apiUrl}/orders?status=Pending'),
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
      final headers = CubePod.get<AuthRepository>().authHeaders;
      final response = await http.get(
        Uri.parse('${AppConfig.apiUrl}/orders?status=!Pending'),
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
