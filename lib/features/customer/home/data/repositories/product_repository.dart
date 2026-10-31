import 'package:app/core/network/http_client.dart' as http;
import 'dart:convert';
import 'package:app/core/config/app_config.dart';
import 'package:app/core/services/cache_service.dart';

class ProductRepository {
  List<dynamic> getCachedCategories() {
    return CacheService.get<List>('categories') ?? [];
  }

  Future<List<dynamic>> fetchCategoriesHome() async {
    final cached = getCachedCategories();
    try {
      final res = await http.get(Uri.parse('${AppConfig.apiUrl}/categories'));
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body)['categories'] ?? [];
        if (list is List) {
          CacheService.set('categories', list);
          return list;
        }
      }
    } catch (_) {}
    return cached;
  }

  List<dynamic> getCachedHomeDeals() {
    return CacheService.get<List>('home_deals') ?? [];
  }

  Future<List<dynamic>> fetchHomeDeals() async {
    final cached = getCachedHomeDeals();
    try {
      final res = await http.get(Uri.parse('${AppConfig.apiUrl}/home-deals'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final list = data['home_deals'] ?? data['promotions'] ?? [];
        if (list is List) {
          CacheService.set('home_deals', list);
          return list;
        }
      }
    } catch (_) {}
    return cached.isNotEmpty ? cached : fetchPromotions();
  }

  Future<List<dynamic>> fetchPromotions() async {
    final cached = CacheService.get<List>('promotions') ?? [];
    try {
      final res = await http.get(Uri.parse('${AppConfig.apiUrl}/promotions'));
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body)['promotions'] ?? jsonDecode(res.body)['home_deals'] ?? [];
        if (list is List) {
          CacheService.set('promotions', list);
          return list;
        }
      }
    } catch (_) {}
    return cached;
  }

  List<dynamic> getCachedTodaysChoice() {
    return CacheService.get<List>('todays_choice') ?? [];
  }

  Future<List<dynamic>> fetchTodaysChoice() async {
    final cached = getCachedTodaysChoice();
    try {
      final res = await http.get(
        Uri.parse('${AppConfig.apiUrl}/products?is_todays_choice=true'),
      );
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body)['products'] ?? [];
        if (list is List) {
          CacheService.set('todays_choice', list);
          return list;
        }
      }
    } catch (_) {}
    return cached;
  }

  List<dynamic> getCachedSpecialDeals() {
    return CacheService.get<List>('special_deals') ?? [];
  }

  Future<List<dynamic>> fetchSpecialDeals() async {
    final cached = getCachedSpecialDeals();
    try {
      final res = await http.get(
        Uri.parse('${AppConfig.apiUrl}/products?is_special_deal=true'),
      );
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body)['products'] ?? [];
        if (list is List) {
          CacheService.set('special_deals', list);
          return list;
        }
      }
    } catch (_) {}
    return cached;
  }

  List<dynamic> getCachedPopularItems() {
    return CacheService.get<List>('popular_items') ?? [];
  }

  Future<List<dynamic>> fetchPopularItems() async {
    final cached = getCachedPopularItems();
    try {
      final res = await http.get(
        Uri.parse('${AppConfig.apiUrl}/products?is_popular=true&limit=10'),
      );
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body)['products'] ?? [];
        if (list is List) {
          CacheService.set('popular_items', list);
          return list;
        }
      }
    } catch (_) {}
    return cached;
  }

  Future<List<dynamic>> fetchOtherItems() async {
    try {
      final res = await http.get(
        Uri.parse('${AppConfig.apiUrl}/products?limit=10'),
      );
      if (res.statusCode == 200) return jsonDecode(res.body)['products'] ?? [];
    } catch (_) {}
    return [];
  }

  Future<Map<String, dynamic>> fetchProductDetailsData(String id) async {
    final simRes = http.get(
      Uri.parse('${AppConfig.apiUrl}/products?limit=5&offset=5'),
    );
    final likeRes = http.get(Uri.parse('${AppConfig.apiUrl}/products?limit=5'));

    final responses = await Future.wait([simRes, likeRes]);
    return {
      'similarItems': responses[0].statusCode == 200
          ? jsonDecode(responses[0].body)['data'] ?? []
          : [],
      'youMightAlsoLike': responses[1].statusCode == 200
          ? jsonDecode(responses[1].body)['data'] ?? []
          : [],
    };
  }

  Future<List<dynamic>> searchProducts(String query, String categoryId) async {
    String url = '${AppConfig.apiUrl}/products?';
    if (query.isNotEmpty) url += 'search=$query&';
    if (categoryId.isNotEmpty) url += 'category_id=$categoryId';

    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      return jsonDecode(response.body)['products'] ?? [];
    }
    return [];
  }

  Future<List<dynamic>> fetchCategories() async {
    return fetchCategoriesHome();
  }

  Future<List<dynamic>> fetchProductsByCategory(String categoryId) async {
    final cacheKey = 'products_cat_$categoryId';
    final cached = CacheService.get<List>(cacheKey) ?? [];

    try {
      final res = await http.get(
        Uri.parse('${AppConfig.apiUrl}/products?category_id=$categoryId'),
      );
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body)['products'] ?? [];
        if (list is List) {
          CacheService.set(cacheKey, list);
          return list;
        }
      }
    } catch (_) {}
    return cached;
  }

  Future<List<dynamic>> fetchCampaignProducts({
    String? categoryId,
    List<String>? productIds,
    bool isRandom = false,
  }) async {
    final cacheKey = 'campaign_p_${categoryId ?? ""}_${productIds?.join("_") ?? ""}';
    final cached = CacheService.get<List>(cacheKey) ?? [];

    try {
      String url = '${AppConfig.apiUrl}/products?limit=50';
      if (productIds != null && productIds.isNotEmpty) {
        url += '&ids=${productIds.join(',')}';
      } else if (categoryId != null && categoryId.isNotEmpty && categoryId != 'null' && categoryId != 'all') {
        url += '&category_id=$categoryId';
      }
      if (isRandom) {
        url += '&random=true';
      }
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final list = data['products'] ?? [];
        if (list is List) {
          CacheService.set(cacheKey, list);
          return list;
        }
      }
    } catch (_) {}
    return cached.isNotEmpty ? cached : fetchProducts();
  }

  Future<List<dynamic>> fetchProducts() async {
    final cached = CacheService.get<List>('products_all') ?? [];
    try {
      final res = await http.get(
        Uri.parse('${AppConfig.apiUrl}/products'),
      );
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body)['products'] ?? [];
        if (list is List) {
          CacheService.set('products_all', list);
          return list;
        }
      }
    } catch (_) {}
    return cached;
  }
}
