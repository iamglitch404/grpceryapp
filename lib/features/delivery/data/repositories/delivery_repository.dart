import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:app/core/network/http_client.dart' as http;
import 'package:app/core/config/app_config.dart';
import 'package:cubepod_core/cubepod_core.dart';
import 'package:app/features/auth/data/repositories/auth_repository.dart';

class DeliveryRepository {
  Map<String, String> get _headers => CubePod.get<AuthRepository>().authHeaders;

  /// Fetches delivery partner profile and active shift
  Future<Map<String, dynamic>?> fetchProfile() async {
    try {
      final res = await http.get(
        Uri.parse('${AppConfig.apiUrl}/delivery/profile'),
        headers: _headers,
      );
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final data = jsonDecode(res.body);
        return data is Map<String, dynamic> ? data : null;
      }
    } catch (e) {
      debugPrint('[DeliveryRepository] fetchProfile error: $e');
    }
    return null;
  }

  /// Updates online/offline status and live GPS coordinates
  Future<bool> updateStatus(String status, {double? lat, double? lng}) async {
    try {
      final body = <String, dynamic>{'status': status};
      if (lat != null && lng != null) {
        body['current_latitude'] = lat;
        body['current_longitude'] = lng;
      }
      final res = await http.patch(
        Uri.parse('${AppConfig.apiUrl}/delivery/profile'),
        headers: _headers,
        body: jsonEncode(body),
      );
      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (e) {
      debugPrint('[DeliveryRepository] updateStatus error: $e');
      return false;
    }
  }

  /// Fetches assigned, active, and completed orders for this delivery partner
  Future<Map<String, dynamic>?> fetchOrders() async {
    try {
      final res = await http.get(
        Uri.parse('${AppConfig.apiUrl}/delivery/orders'),
        headers: _headers,
      );
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final data = jsonDecode(res.body);
        return data is Map<String, dynamic> ? data : null;
      }
    } catch (e) {
      debugPrint('[DeliveryRepository] fetchOrders error: $e');
    }
    return null;
  }

  /// Performs delivery lifecycle action: 'accept', 'decline', 'arrived_store', 'pick_up', 'deliver'
  Future<bool> performAction(String orderId, String action, {String? notes}) async {
    try {
      final res = await http.post(
        Uri.parse('${AppConfig.apiUrl}/delivery/orders/action'),
        headers: _headers,
        body: jsonEncode({
          'order_id': orderId,
          'action': action,
          'notes': ?notes,
        }),
      );
      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (e) {
      debugPrint('[DeliveryRepository] performAction error: $e');
      return false;
    }
  }

  /// Fetches shift history and working hours summary
  Future<Map<String, dynamic>?> fetchShifts() async {
    try {
      final res = await http.get(
        Uri.parse('${AppConfig.apiUrl}/delivery/shifts'),
        headers: _headers,
      );
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final data = jsonDecode(res.body);
        return data is Map<String, dynamic> ? data : null;
      }
    } catch (e) {
      debugPrint('[DeliveryRepository] fetchShifts error: $e');
    }
    return null;
  }

  /// Clocks in to start working shift
  Future<bool> clockIn() async {
    try {
      final res = await http.post(
        Uri.parse('${AppConfig.apiUrl}/delivery/shifts'),
        headers: _headers,
        body: jsonEncode({'action': 'clock_in'}),
      );
      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (e) {
      debugPrint('[DeliveryRepository] clockIn error: $e');
      return false;
    }
  }

  /// Clocks out to end working shift
  Future<bool> clockOut() async {
    try {
      final res = await http.post(
        Uri.parse('${AppConfig.apiUrl}/delivery/shifts'),
        headers: _headers,
        body: jsonEncode({'action': 'clock_out'}),
      );
      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (e) {
      debugPrint('[DeliveryRepository] clockOut error: $e');
      return false;
    }
  }

  /// Fetches delivery partners leaderboard
  Future<Map<String, dynamic>?> fetchLeaderboard() async {
    try {
      final res = await http.get(
        Uri.parse('${AppConfig.apiUrl}/delivery/leaderboard'),
        headers: _headers,
      );
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final data = jsonDecode(res.body);
        return data is Map<String, dynamic> ? data : null;
      }
    } catch (e) {
      debugPrint('[DeliveryRepository] fetchLeaderboard error: $e');
    }
    return null;
  }

  /// Fetches reviews and ratings for this partner
  Future<Map<String, dynamic>?> fetchReviews() async {
    try {
      final res = await http.get(
        Uri.parse('${AppConfig.apiUrl}/delivery/reviews'),
        headers: _headers,
      );
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final data = jsonDecode(res.body);
        return data is Map<String, dynamic> ? data : null;
      }
    } catch (e) {
      debugPrint('[DeliveryRepository] fetchReviews error: $e');
    }
    return null;
  }

  /// Admin: Fetches list of all delivery partners for assignment
  Future<List<Map<String, dynamic>>> fetchAvailableDeliveryPartners() async {
    try {
      final res = await http.get(
        Uri.parse('${AppConfig.apiUrl}/admin/delivery-partners'),
        headers: _headers,
      );
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final data = jsonDecode(res.body);
        if (data is Map && data['partners'] is List) {
          return List<Map<String, dynamic>>.from(data['partners']);
        }
      }
    } catch (e) {
      debugPrint('[DeliveryRepository] fetchAvailableDeliveryPartners error: $e');
    }
    return [];
  }

  /// Admin: Assigns an order to a delivery partner
  Future<bool> assignDeliveryPartner(String orderId, String partnerId) async {
    try {
      final res = await http.post(
        Uri.parse('${AppConfig.apiUrl}/admin/delivery-partners'),
        headers: _headers,
        body: jsonEncode({
          'order_id': orderId,
          'delivery_partner_id': partnerId,
        }),
      );
      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (e) {
      debugPrint('[DeliveryRepository] assignDeliveryPartner error: $e');
      return false;
    }
  }
}

