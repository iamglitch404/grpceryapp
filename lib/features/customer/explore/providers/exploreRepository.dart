import 'package:app/core/network/httpClient.dart' as http;
import 'dart:convert';
import 'package:app/core/config/appConfig.dart';
import 'package:app/core/services/cacheService.dart';

class ExploreRepository {
  List<dynamic> getCachedCategories() {
    return CacheService.get<List>('categories') ?? [];
  }

  Future<List<dynamic>> fetchCategories() async {
    // 1. Return memory cache immediately if available
    final cached = CacheService.get<List>('categories');

    // 2. Fetch fresh in background
    try {
      final response = await http.get(Uri.parse('${AppConfig.apiUrl}/categories'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final list = data['data']?['categories'] ?? data['categories'] ?? [];
        if (list is List) {
          CacheService.set('categories', list);
          return list;
        }
      }
    } catch (_) {}

    return cached ?? (await CacheService.getAsync<List>('categories')) ?? [];
  }

  List<dynamic> getCachedPromotions() {
    return CacheService.get<List>('promotions') ?? [];
  }

  Future<List<dynamic>> fetchPromotions() async {
    final cached = CacheService.get<List>('promotions');
    try {
      final response = await http.get(Uri.parse('${AppConfig.apiUrl}/promotions'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final list = data['data']?['promotions'] ?? data['promotions'] ?? [];
        if (list is List) {
          CacheService.set('promotions', list);
          return list;
        }
      }
    } catch (_) {}
    return cached ?? [];
  }

  Future<List<dynamic>> fetchProducts({String? categoryId, String? subcategoryId, String? search}) async {
    final cacheKey = 'products_${categoryId ?? ""}_${subcategoryId ?? ""}_${search ?? ""}';
    final cached = CacheService.get<List>(cacheKey);

    try {
      String url = '${AppConfig.apiUrl}/products?limit=50';
      if (categoryId != null && categoryId.isNotEmpty) url += '&category_id=$categoryId';
      if (subcategoryId != null && subcategoryId.isNotEmpty) url += '&subcategory_id=$subcategoryId';
      if (search != null && search.isNotEmpty) url += '&search=$search';

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final list = data['data']?['products'] ?? data['products'] ?? [];
        if (list is List) {
          CacheService.set(cacheKey, list);
          return list;
        }
      }
    } catch (_) {}
    return cached ?? [];
  }

  Map<String, dynamic>? getCachedDealsData() {
    return CacheService.get<Map>('deals_data')?.cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> fetchDealsData() async {
    final cached = getCachedDealsData();

    try {
      final hRes = http.get(Uri.parse('${AppConfig.apiUrl}/home-deals'));
      final cRes = http.get(Uri.parse('${AppConfig.apiUrl}/categories'));
      final pRes = http.get(Uri.parse('${AppConfig.apiUrl}/promotions'));
      final fRes = http.get(Uri.parse('${AppConfig.apiUrl}/products?is_special_deal=true'));
      final tRes = http.get(Uri.parse('${AppConfig.apiUrl}/products?is_popular=true'));
      final rRes = http.get(Uri.parse('${AppConfig.apiUrl}/products?limit=30'));
      
      final responses = await Future.wait([hRes, cRes, pRes, fRes, tRes, rRes]);

      List<dynamic> parseList(dynamic resp, String key) {
        if (resp.statusCode != 200) return [];
        try {
          final body = jsonDecode(resp.body);
          if (body is Map) {
            return body['data']?[key] ?? body[key] ?? [];
          }
        } catch (_) {}
        return [];
      }

      final fresh = {
        'homeDeals': parseList(responses[0], 'home_deals').isNotEmpty 
            ? parseList(responses[0], 'home_deals') 
            : parseList(responses[0], 'deals'),
        'categories': parseList(responses[1], 'categories'),
        'promotions': parseList(responses[2], 'promotions'),
        'flashDeals': parseList(responses[3], 'products'),
        'trendingDeals': parseList(responses[4], 'products'),
        'recentDeals': parseList(responses[5], 'products'),
      };

      CacheService.set('deals_data', fresh);

      return fresh;
    } catch (_) {}

    return cached ?? {};
  }

  Future<Map<String, dynamic>> fetchMyOffers(Map<String, String> headers) async {
    final cached = CacheService.get<Map>('my_offers')?.cast<String, dynamic>();

    try {
      final res = await http.get(
        Uri.parse('${AppConfig.apiUrl}/promotions/my-offers'),
        headers: headers,
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final fresh = (data['data'] is Map) ? Map<String, dynamic>.from(data['data']) : <String, dynamic>{};
        CacheService.set('my_offers', fresh);
        return fresh;
      }
    } catch (_) {}

    return cached ?? {'active': [], 'used': [], 'expired': []};
  }
}
