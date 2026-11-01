// Product price and normalization utilities.
// Extracted from ProductsPage to reduce its size.

/// Extracts price in paise from a raw product map, handling both
/// `price_paise` (integer) and `price` (decimal) field conventions.
int extractPricePaise(dynamic p) {
  if (p == null) return 0;
  if (p['price_paise'] != null) {
    final raw = p['price_paise'];
    if (raw is num) return raw.toInt();
    return int.tryParse(raw.toString()) ?? 0;
  }
  if (p['price'] != null) {
    final raw = p['price'];
    if (raw is num) return (raw * 100).round();
    final parsed = double.tryParse(raw.toString()) ?? 0.0;
    return (parsed * 100).round();
  }
  return 0;
}

/// Extracts original price in paise from a raw product map.
int? extractOrigPricePaise(dynamic p) {
  if (p == null) return null;
  if (p['original_price_paise'] != null) {
    final raw = p['original_price_paise'];
    if (raw is num) return raw.toInt();
    return int.tryParse(raw.toString());
  }
  if (p['original_price'] != null) {
    final raw = p['original_price'];
    if (raw is num) return (raw * 100).round();
    final parsed = double.tryParse(raw.toString()) ?? 0.0;
    if (parsed > 0) return (parsed * 100).round();
  }
  return null;
}

/// Normalizes a raw product map from the backend into a consistent
/// `Map<String, dynamic>` shape used by the admin product UI.
Map<String, dynamic> normalizeProduct(dynamic raw, List<dynamic> categories) {
  final Map<String, dynamic> map = Map<String, dynamic>.from(raw is Map ? raw : {});
  final id = map['id']?.toString() ?? '';
  final title = (map['title'] ?? map['name'] ?? 'Product').toString();
  final pricePaise = extractPricePaise(map);
  final origPricePaise = extractOrigPricePaise(map);
  final unit = (map['unit'] ?? '1 kg').toString();
  final stock = map['stock_quantity'] is num
      ? (map['stock_quantity'] as num).toInt()
      : (int.tryParse(map['stock_quantity']?.toString() ?? '') ?? 50);
  final img = (map['image_url'] ?? map['image'] ?? '').toString();

  String catId = map['category_id']?.toString() ?? '';
  String catName = '';
  if (map['categories'] is Map) {
    catId = map['categories']['id']?.toString() ?? catId;
    catName = (map['categories']['name'] ?? map['categories']['label'] ?? '').toString();
  } else if (map['category_name'] != null) {
    catName = map['category_name'].toString();
  }

  String subId = map['subcategory_id']?.toString() ?? '';
  String subName = '';
  if (map['subcategories'] is Map) {
    subId = map['subcategories']['id']?.toString() ?? subId;
    subName = (map['subcategories']['name'] ?? '').toString();
  } else if (map['subcategory_name'] != null) {
    subName = map['subcategory_name'].toString();
  }

  // Secondary lookup if subName is empty
  if (subName.isEmpty && subId.isNotEmpty) {
    for (final cat in categories) {
      if (cat['subcategories'] is List) {
        for (final sub in cat['subcategories']) {
          if (sub['id']?.toString() == subId) {
            subName = sub['name']?.toString() ?? '';
            if (catName.isEmpty) catName = (cat['name'] ?? cat['label'] ?? '').toString();
            break;
          }
        }
      }
    }
  }

  if (catName.isEmpty && catId.isNotEmpty) {
    for (final cat in categories) {
      if (cat['id']?.toString() == catId) {
        catName = (cat['name'] ?? cat['label'] ?? '').toString();
        break;
      }
    }
  }

  return {
    'id': id,
    'title': title,
    'description': map['description']?.toString() ?? '',
    'price_paise': pricePaise,
    'original_price_paise': origPricePaise,
    'unit': unit,
    'stock_quantity': stock,
    'image_url': img,
    'category_id': catId,
    'category_name': catName,
    'subcategory_id': subId,
    'subcategory_name': subName,
    'is_active': map['is_active'] != false,
    'is_todays_choice': map['is_todays_choice'] == true,
    'is_special_deal': map['is_special_deal'] == true,
    'is_popular': map['is_popular'] == true,
    'product_code': map['product_code']?.toString() ?? '',
    'calories': map['calories']?.toString() ?? '',
    'categories': map['categories'],
    'subcategories': map['subcategories'],
  };
}

/// Checks whether a product belongs to a given category (by ID or name).
bool productBelongsToCategory(Map<String, dynamic> p, dynamic cat) {
  if (cat == null) return false;
  final catId = cat['id']?.toString() ?? '';
  final catName = (cat['name'] ?? cat['label'] ?? '').toString().trim().toLowerCase();
  final pCatId = p['category_id']?.toString() ?? '';
  final pCatName = (p['category_name'] ?? '').toString().trim().toLowerCase();

  if (catId.isNotEmpty && pCatId.isNotEmpty && catId == pCatId) return true;
  if (catName.isNotEmpty && pCatName.isNotEmpty && catName == pCatName) return true;
  return false;
}

/// Extracts subcategories for a given category map.
List<dynamic> getSubcategoriesForCategory(dynamic category) {
  if (category == null) return [];
  if (category['subcategories'] is List && (category['subcategories'] as List).isNotEmpty) {
    return List<dynamic>.from(category['subcategories']);
  }
  final catId = category['id']?.toString();
  if (catId != null) {
    // categories param not available here; caller should pass full list if needed
    return [];
  }
  return [];
}

/// Returns subcategories for a selected category from the full categories list.
List<dynamic> activeCategorySubcategories(List<dynamic> categories, String selectedCategory) {
  if (selectedCategory == 'All') return [];
  for (final cat in categories) {
    final name = (cat['name'] ?? cat['label'] ?? '').toString();
    final id = cat['id']?.toString() ?? '';
    if (name.toLowerCase() == selectedCategory.toLowerCase() || id == selectedCategory) {
      if (cat['subcategories'] is List) {
        return List<dynamic>.from(cat['subcategories']);
      }
    }
  }
  return [];
}
