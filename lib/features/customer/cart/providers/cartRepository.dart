import 'package:flutter/foundation.dart';
import 'package:app/core/network/httpClient.dart' as http;
import 'dart:convert';
import 'package:app/core/config/appConfig.dart';
import 'package:app/features/auth/providers/authRepository.dart';

class CartRepository {
  final AuthRepository _authRepository;

  CartRepository([AuthRepository? authRepository])
      : _authRepository = authRepository ?? AuthRepository();

  Future<List<dynamic>> fetchCartItems(String userId) async {
    try {
      final headers = _authRepository.authHeaders;
      final response = await http.get(
        Uri.parse('${AppConfig.apiUrl}/cart'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return data['items'] ?? [];
        }
      }
    } catch (e) {
      debugPrint('Error fetching cart: $e');
    }
    return [];
  }

  Future<void> updateQuantity(String cartItemId, int newQuantity) async {
    try {
      final headers = _authRepository.authHeaders;
      await http.patch(
        Uri.parse('${AppConfig.apiUrl}/cart/$cartItemId'),
        headers: headers,
        body: jsonEncode({'quantity': newQuantity}),
      );
    } catch (e) {
      debugPrint('Error updating quantity: $e');
    }
  }

  Future<void> removeItem(String cartItemId) async {
    try {
      final headers = _authRepository.authHeaders;
      await http.delete(
        Uri.parse('${AppConfig.apiUrl}/cart/$cartItemId'),
        headers: headers,
      );
    } catch (e) {
      debugPrint('Error removing item: $e');
    }
  }

  Future<bool> addToCart(String userId, String productId, int quantity) async {
    try {
      final headers = _authRepository.authHeaders;
      final response = await http.post(
        Uri.parse('${AppConfig.apiUrl}/cart'),
        headers: headers,
        body: jsonEncode({
          'product_id': productId,
          'quantity': quantity,
        }),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return true;
      }
    } catch (e) {
      debugPrint('Error adding to cart: $e');
    }
    return false;
  }
}
