import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:app/core/config/appConfig.dart';

class SubmissionRepository {
  final http.Client _client = http.Client();

  Future<List<Map<String, dynamic>>> fetchProducts(Map<String, String> headers) async {
    try {
      final res = await _client.get(
        Uri.parse('${AppConfig.apiUrl}/admin/products'),
        headers: headers,
      );

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        final list = decoded is List
            ? decoded
            : (decoded['products'] is List
                ? decoded['products']
                : (decoded['data'] is List ? decoded['data'] : []));
        if (list.isNotEmpty) {
          return List<Map<String, dynamic>>.from(list);
        }
      }

      // Fallback to public catalog
      final fallbackRes = await _client.get(
        Uri.parse('${AppConfig.apiUrl}/products?limit=200'),
        headers: headers,
      );
      if (fallbackRes.statusCode == 200) {
        final decoded = jsonDecode(fallbackRes.body);
        final prods = decoded['products'] ?? decoded['data'];
        if (prods is List) {
          return List<Map<String, dynamic>>.from(prods);
        }
      }
    } catch (e) {
      debugPrint('[SubmissionRepo] fetchProducts error: $e');
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> fetchMySubmissions(Map<String, String> headers, {String status = 'all'}) async {
    try {
      final res = await _client.get(
        Uri.parse('${AppConfig.apiUrl}/products/my-submissions?status=$status'),
        headers: headers,
      );

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        final prods = decoded['data']?['products'] ?? decoded['products'];
        if (prods is List) {
          return List<Map<String, dynamic>>.from(prods);
        }
      }
    } catch (e) {
      debugPrint('[SubmissionRepo] fetchMySubmissions error: $e');
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> fetchCategories() async {
    try {
      final res = await _client.get(
        Uri.parse('${AppConfig.apiUrl}/categories'),
      );

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        final cats = decoded['data']?['categories'] ?? decoded['categories'] ?? decoded['data'];
        if (cats is List) {
          return List<Map<String, dynamic>>.from(cats);
        }
      }
    } catch (e) {
      debugPrint('[SubmissionRepo] fetchCategories error: $e');
    }
    return [];
  }

  Future<String?> uploadProductImage(
    Map<String, String> headers,
    Uint8List bytes,
    String fileName,
  ) async {
    try {
      final uri = Uri.parse('${AppConfig.apiUrl}/admin/products/upload');
      final req = http.MultipartRequest('POST', uri);
      req.headers.addAll(headers);

      final ext = fileName.toLowerCase().split('.').last;
      final subType = (ext == 'png' || ext == 'webp' || ext == 'gif' || ext == 'heic') ? ext : 'jpeg';
      final multipartFile = http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: fileName,
        contentType: MediaType('image', subType),
      );
      req.files.add(multipartFile);

      final streamedRes = await req.send();
      final res = await http.Response.fromStream(streamedRes);

      if (res.statusCode == 200 || res.statusCode == 201) {
        final decoded = jsonDecode(res.body);
        return decoded['data']?['url'] ?? decoded['url'];
      }
    } catch (e) {
      debugPrint('[SubmissionRepo] uploadProductImage error: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> submitProductForApproval(
    Map<String, String> headers,
    Map<String, dynamic> productData,
  ) async {
    try {
      final res = await _client.post(
        Uri.parse('${AppConfig.apiUrl}/products/submit'),
        headers: {
          ...headers,
          'Content-Type': 'application/json',
        },
        body: jsonEncode(productData),
      );

      if (res.statusCode == 200 || res.statusCode == 201) {
        final decoded = jsonDecode(res.body);
        return decoded['data'] != null ? Map<String, dynamic>.from(decoded['data']) : decoded;
      } else {
        debugPrint('[SubmissionRepo] submitProduct failed: ${res.statusCode} ${res.body}');
      }
    } catch (e) {
      debugPrint('[SubmissionRepo] submitProduct error: $e');
    }
    return null;
  }

  Future<bool> updateProduct(
    Map<String, String> headers,
    String productId,
    Map<String, dynamic> productData,
  ) async {
    try {
      final res = await _client.patch(
        Uri.parse('${AppConfig.apiUrl}/admin/products'),
        headers: {
          ...headers,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'id': productId,
          ...productData,
        }),
      );

      return res.statusCode == 200;
    } catch (e) {
      debugPrint('[SubmissionRepo] updateProduct error: $e');
      return false;
    }
  }

  Future<bool> processApprovalAction(
    Map<String, String> headers, {
    required String productId,
    required String action, // 'schedule_pickup', 'list_in_store', 'reject'
    String? pickupTime,
    String? adminNotes,
    String? rejectionReason,
  }) async {
    try {
      final res = await _client.patch(
        Uri.parse('${AppConfig.apiUrl}/admin/product-approvals'),
        headers: {
          ...headers,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'product_id': productId,
          'action': action,
          'pickup_time': pickupTime,
          'admin_notes': adminNotes,
          'rejection_reason': rejectionReason,
        }),
      );

      return res.statusCode == 200;
    } catch (e) {
      debugPrint('[SubmissionRepo] processApprovalAction error: $e');
      return false;
    }
  }

  Future<bool> deleteProduct(
    Map<String, String> headers,
    String productId,
  ) async {
    try {
      final res = await _client.delete(
        Uri.parse('${AppConfig.apiUrl}/admin/products?id=$productId'),
        headers: headers,
      );

      return res.statusCode == 200;
    } catch (e) {
      debugPrint('[SubmissionRepo] deleteProduct error: $e');
      return false;
    }
  }
}

// Retain alias for backward compatibility
typedef ProductManagementRepository = SubmissionRepository;
