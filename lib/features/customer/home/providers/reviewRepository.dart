import 'package:app/core/network/httpClient.dart' as http;
import 'dart:convert';
import 'package:app/core/config/appConfig.dart';

class ReviewRepository {
  Future<List<dynamic>> fetchReviews(String productId) async {
    final response = await http.get(Uri.parse('${AppConfig.apiUrl}/reviews?product_id=$productId'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body)['data'] ?? [];
    }
    return [];
  }

  Future<void> submitReview(Map<String, dynamic> reviewData) async {
    await http.post(
      Uri.parse('${AppConfig.apiUrl}/reviews'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(reviewData),
    );
  }

  Future<void> updateReview(String reviewId, Map<String, dynamic> reviewData) async {
    await http.patch(
      Uri.parse('${AppConfig.apiUrl}/reviews/$reviewId'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(reviewData),
    );
  }

  Future<void> deleteReview(String reviewId) async {
    await http.delete(Uri.parse('${AppConfig.apiUrl}/reviews/$reviewId'));
  }
}
