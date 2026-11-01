import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:app/core/config/appConfig.dart';
import 'package:app/core/network/httpClient.dart' as http;
import 'package:app/features/auth/providers/authRepository.dart';

/// Repository for Administrative order management and status transitions.
class OrderRepository {
  final AuthRepository _authRepository;

  OrderRepository([AuthRepository? authRepository])
      : _authRepository = authRepository ?? AuthRepository();

  Map<String, String> get _headers => _authRepository.authHeaders;

  /// Fetches store orders with optional status filter, pagination, and sorting.
  Future<List<Map<String, dynamic>>> fetchOrders({
    String? status,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final queryParams = <String, String>{
        'limit': limit.toString(),
        'offset': offset.toString(),
      };
      if (status != null && status.isNotEmpty && status != 'All') {
        queryParams['status'] = status;
      }

      final uri = Uri.parse('${AppConfig.apiUrl}/admin/orders').replace(queryParameters: queryParams);
      final res = await http.get(uri, headers: _headers);

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        final list = decoded['orders'] ?? (decoded is List ? decoded : []);
        if (list is List) {
          return List<Map<String, dynamic>>.from(list);
        }
      } else {
        debugPrint('[AdminOrderRepository] fetchOrders failed: ${res.statusCode} ${res.body}');
      }
    } catch (e) {
      debugPrint('[AdminOrderRepository] fetchOrders error: $e');
    }
    return [];
  }

  /// Updates the status of an existing order (e.g. Processing, Out for Delivery, Delivered, Cancelled).
  Future<bool> updateOrderStatus(dynamic orderId, String newStatus) async {
    try {
      final res = await http.patch(
        Uri.parse('${AppConfig.apiUrl}/admin/orders'),
        headers: {
          ..._headers,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'order_id': orderId,
          'id': orderId,
          'status': newStatus,
        }),
      );

      if (res.statusCode >= 200 && res.statusCode < 300) {
        return true;
      } else {
        debugPrint('[AdminOrderRepository] updateOrderStatus failed: ${res.statusCode} ${res.body}');
      }
    } catch (e) {
      debugPrint('[AdminOrderRepository] updateOrderStatus error: $e');
    }
    return false;
  }
}

// Retain alias for backward compatibility
typedef AdminOrderRepository = OrderRepository;
