import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:app/core/network/http_client.dart' as http;
import 'dart:convert';
import 'package:app/core/config/app_config.dart';
import 'package:app/features/auth/data/repositories/auth_repository.dart';
import 'package:cubepod_core/cubepod_core.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http_parser/http_parser.dart';
import 'package:app/core/widgets/skeleton_image.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:app/features/admin/presentation/pages/product_review_page.dart';
import 'package:app/core/services/cache_service.dart';
import 'package:app/core/widgets/toast.dart';

http.MultipartFile _buildImageMultipartFile(List<int> bytes, String filename) {
  final ext = filename.toLowerCase().split('.').last;
  final subType = (ext == 'png' || ext == 'webp' || ext == 'gif' || ext == 'heic') ? ext : 'jpeg';
  return http.MultipartFile.fromBytes(
    'file',
    bytes,
    filename: filename,
    contentType: MediaType('image', subType),
  );
}

class ProductsPage extends StatefulWidget {
  final bool autoOpenAddDialog;
  const ProductsPage({super.key, this.autoOpenAddDialog = false});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _products = [];
  List<dynamic> _categories = [];
  String _searchQuery = '';
  String _selectedCategory = 'All';
  String _selectedSubcategory = 'All';
  String _selectedStockStatus = 'All';
  String _selectedStatus = 'All';
  int _pendingReviewCount = 0;


  List<dynamic> _getSubcategoriesForCategory(dynamic category) {
    if (category == null) return [];
    if (category['subcategories'] is List && (category['subcategories'] as List).isNotEmpty) {
      return List<dynamic>.from(category['subcategories']);
    }
    final catId = category['id']?.toString();
    if (catId != null) {
      for (final c in _categories) {
        if (c is Map && c['id']?.toString() == catId && c['subcategories'] is List) {
          return List<dynamic>.from(c['subcategories']);
        }
      }
    }
    return [];
  }

  bool _productBelongsToCategory(Map<String, dynamic> p, dynamic cat) {
    if (cat == null) return false;
    final catId = cat['id']?.toString() ?? '';
    final catName = (cat['name'] ?? cat['label'] ?? '').toString().trim().toLowerCase();
    final pCatId = p['category_id']?.toString() ?? '';
    final pCatName = (p['category_name'] ?? '').toString().trim().toLowerCase();

    if (catId.isNotEmpty && pCatId.isNotEmpty && catId == pCatId) return true;
    if (catName.isNotEmpty && pCatName.isNotEmpty && catName == pCatName) return true;
    return false;
  }



  int get _activeFilterCount {
    int count = 0;
    if (_selectedCategory != 'All') count++;
    if (_selectedSubcategory != 'All') count++;
    if (_selectedStockStatus != 'All') count++;
    if (_selectedStatus != 'All') count++;
    return count;
  }

  bool get _hasActiveFilters => _activeFilterCount > 0;

  @override
  void initState() {
    super.initState();
    _fetchData();
    if (widget.autoOpenAddDialog) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showAddOptionsSheet();
      });
    }
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _fetchProducts(),
      _fetchCategories(),
    ]);
    if (mounted) setState(() => _isLoading = false);
  }

  int _extractPricePaise(dynamic p) {
    if (p == null) return 0;
    if (p['price_paise'] != null) {
      final raw = p['price_paise'];
      if (raw is num) return raw.toInt();
      return (int.tryParse(raw.toString()) ?? 0);
    }
    if (p['price'] != null) {
      final raw = p['price'];
      if (raw is num) return (raw * 100).round();
      final parsed = double.tryParse(raw.toString()) ?? 0.0;
      return (parsed * 100).round();
    }
    return 0;
  }

  int? _extractOrigPricePaise(dynamic p) {
    if (p == null) return null;
    if (p['original_price_paise'] != null) {
      final raw = p['original_price_paise'];
      if (raw is num) return raw.toInt();
      return int.tryParse(raw.toString());
    }
    if (p['original_price'] != null) {
      final raw = p['original_price'];
      if (raw is num) return (raw * 100).round();
      final parsed = double.tryParse(raw.toString());
      if (parsed != null && parsed > 0) return (parsed * 100).round();
    }
    return null;
  }

  Map<String, dynamic> _normalizeProduct(dynamic raw) {
    final Map<String, dynamic> map = Map<String, dynamic>.from(raw is Map ? raw : {});
    final id = map['id']?.toString() ?? '';
    final title = (map['title'] ?? map['name'] ?? 'Product').toString();
    final pricePaise = _extractPricePaise(map);
    final origPricePaise = _extractOrigPricePaise(map);
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
      for (final cat in _categories) {
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
      for (final cat in _categories) {
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

  Future<void> _fetchProducts() async {
    List<dynamic> rawList = [];

    // 1. Try primary admin endpoint
    try {
      final res = await http.get(
        Uri.parse('${AppConfig.apiUrl}/admin/products'),
        headers: CubePod.get<AuthRepository>().authHeaders,
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is List) {
          rawList = data;
        } else if (data is Map) {
          if (data['products'] is List) {
            rawList = data['products'];
          } else if (data['data'] is List) {
            rawList = data['data'];
          }
        }
      }
    } catch (e) {
      debugPrint('[ProductsPage] Admin fetch error: $e');
    }

    // 2. Fallback to public catalog if admin endpoint returned empty or failed
    if (rawList.isEmpty) {
      try {
        final fallbackRes = await http.get(
          Uri.parse('${AppConfig.apiUrl}/products?limit=200'),
          headers: CubePod.get<AuthRepository>().authHeaders,
        );
        if (fallbackRes.statusCode == 200) {
          final data = jsonDecode(fallbackRes.body);
          if (data is Map && data['products'] is List) {
            rawList = data['products'];
          } else if (data is List) {
            rawList = data;
          }
        }
      } catch (e) {
        debugPrint('[ProductsPage] Fallback fetch error: $e');
      }
    }

    int pendingCount = 0;
    try {
      final reviewRes = await http.get(
        Uri.parse('${AppConfig.apiUrl}/admin/product-approvals?status=pending'),
        headers: CubePod.get<AuthRepository>().authHeaders,
      );
      if (reviewRes.statusCode == 200) {
        final rData = jsonDecode(reviewRes.body);
        final list = (rData['submissions'] ?? rData['data'] ?? []) as List;
        pendingCount = list.length;
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _products = rawList.map((item) => _normalizeProduct(item)).toList();
        _pendingReviewCount = pendingCount;
      });
    }
  }

  Future<void> _fetchCategories() async {
    // 0. Instant 0ms cache read
    final cached = CacheService.get<List>('categories');
    if (cached != null && cached.isNotEmpty && _categories.isEmpty && mounted) {
      setState(() {
        _categories = cached;
      });
    }

    // 1. Try admin categories endpoint (direct Supabase admin)
    try {
      final res = await http.get(
        Uri.parse('${AppConfig.apiUrl}/admin/categories'),
        headers: CubePod.get<AuthRepository>().authHeaders,
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        List<dynamic> list = [];
        if (data is List) {
          list = data;
        } else if (data is Map && data['data'] is List) {
          list = data['data'];
        } else if (data is Map && data['categories'] is List) {
          list = data['categories'];
        }
        if (list.isNotEmpty && mounted) {
          setState(() {
            _categories = list;
          });
          CacheService.set('categories', list);
          return;
        }
      }
    } catch (e) {
      debugPrint('[ProductsPage] Admin categories fetch error: $e');
    }

    // 2. Fallback to public categories endpoint
    try {
      final res = await http.get(
        Uri.parse('${AppConfig.apiUrl}/categories'),
        headers: CubePod.get<AuthRepository>().authHeaders,
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (mounted) {
          setState(() {
            _categories = (data is Map ? data['categories'] : null) ?? [];
          });
        }
      }
    } catch (e) {
      debugPrint('[ProductsPage] Error fetching categories: $e');
    }
  }

  Future<void> _deleteProduct(dynamic id, String title) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFE11D48), size: 22),
            ),
            const SizedBox(width: 12),
            Text('Delete Product?', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 17)),
          ],
        ),
        content: Text(
          'Are you sure you want to permanently remove "$title" from the store catalog?',
          style: GoogleFonts.outfit(color: const Color(0xFF475569), fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.outfit(color: const Color(0xFF64748B), fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE11D48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final previousList = List<Map<String, dynamic>>.from(_products);
    setState(() {
      _products.removeWhere((p) => p['id'] == id);
    });

    try {
      final res = await http.delete(
        Uri.parse('${AppConfig.apiUrl}/admin/products?id=$id'),
        headers: CubePod.get<AuthRepository>().authHeaders,
      );

      if (res.statusCode == 200 || res.statusCode == 204) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Product "$title" deleted successfully'),
            backgroundColor: const Color(0xFF185B3A),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      } else {
        if (mounted) setState(() => _products = previousList);
        messenger.showSnackBar(
          const SnackBar(content: Text('Failed to delete product on server')),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _products = previousList);
      messenger.showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _quickUpdateStock(Map<String, dynamic> product, int newStock) async {
    final id = product['id'];
    if (id == null) return;

    setState(() {
      final idx = _products.indexWhere((p) => p['id'] == id);
      if (idx != -1) {
        _products[idx]['stock_quantity'] = newStock;
      }
    });

    try {
      final payload = {'id': id, 'stock_quantity': newStock};
      await http.patch(
        Uri.parse('${AppConfig.apiUrl}/admin/products'),
        headers: {
          ...CubePod.get<AuthRepository>().authHeaders,
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );
    } catch (e) {
      debugPrint('[ProductsPage] quick stock update error: $e');
    }
  }

  Future<void> _quickToggleActive(Map<String, dynamic> product) async {
    final id = product['id'];
    if (id == null) return;
    final newStatus = !(product['is_active'] == true);
    final messenger = ScaffoldMessenger.of(context);

    setState(() {
      final idx = _products.indexWhere((p) => p['id'] == id);
      if (idx != -1) {
        _products[idx]['is_active'] = newStatus;
      }
    });

    try {
      final payload = {'id': id, 'is_active': newStatus};
      await http.patch(
        Uri.parse('${AppConfig.apiUrl}/admin/products'),
        headers: {
          ...CubePod.get<AuthRepository>().authHeaders,
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );
      messenger.showSnackBar(
        SnackBar(
          content: Text(newStatus ? 'Product marked Active' : 'Product hidden from catalog'),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      debugPrint('[ProductsPage] quick active toggle error: $e');
    }
  }

  List<Map<String, dynamic>> get _filteredProducts {
    var list = List<Map<String, dynamic>>.from(_products);

    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((p) {
        final title = (p['title'] ?? '').toString().toLowerCase();
        final code = (p['product_code'] ?? '').toString().toLowerCase();
        final desc = (p['description'] ?? '').toString().toLowerCase();
        final sub = (p['subcategory_name'] ?? '').toString().toLowerCase();
        return title.contains(q) || code.contains(q) || desc.contains(q) || sub.contains(q);
      }).toList();
    }

    if (_selectedCategory != 'All') {
      list = list.where((p) {
        final catId = p['category_id']?.toString() ?? '';
        final catName = p['category_name']?.toString() ?? '';
        return catId == _selectedCategory ||
            catName.toLowerCase() == _selectedCategory.toLowerCase();
      }).toList();
    }

    if (_selectedSubcategory != 'All') {
      list = list.where((p) {
        final subId = p['subcategory_id']?.toString() ?? '';
        final subName = p['subcategory_name']?.toString() ?? '';
        return subId == _selectedSubcategory ||
            subName.toLowerCase() == _selectedSubcategory.toLowerCase();
      }).toList();
    }

    if (_selectedStockStatus == 'In Stock') {
      list = list.where((p) => (p['stock_quantity'] as int? ?? 0) > 0).toList();
    } else if (_selectedStockStatus == 'Out of Stock') {
      list = list.where((p) => (p['stock_quantity'] as int? ?? 0) <= 0).toList();
    }

    if (_selectedStatus == 'Active') {
      list = list.where((p) => p['is_active'] == true).toList();
    } else if (_selectedStatus == 'Hidden') {
      list = list.where((p) => p['is_active'] == false).toList();
    }

    return list;
  }

  void _showProductDialog({
    Map<String, dynamic>? product,
    String? initialCategoryId,
    String? initialSubcategoryId,
  }) {
    final isEdit = product != null;
    final titleCtrl = TextEditingController(text: isEdit ? product['title'] : '');
    final descCtrl = TextEditingController(text: isEdit ? (product['description'] ?? '') : '');

    final pricePaise = isEdit ? (product['price_paise'] as int? ?? 0) : 0;
    final origPricePaise = isEdit ? (product['original_price_paise'] as int? ?? 0) : 0;

    final priceCtrl = TextEditingController(
        text: isEdit && pricePaise > 0 ? (pricePaise / 100).round().toString() : '');
    final origPriceCtrl = TextEditingController(
        text: isEdit && origPricePaise > 0 ? (origPricePaise / 100).round().toString() : '');

    final unitCtrl = TextEditingController(text: isEdit ? (product['unit'] ?? '1 kg') : '1 kg');
    final stockCtrl = TextEditingController(
        text: isEdit ? (product['stock_quantity']?.toString() ?? '50') : '50');
    final imageCtrl = TextEditingController(
        text: isEdit ? (product['image_url'] ?? '') : '');

    String? selectedCatId = isEdit
        ? product['category_id']?.toString()
        : (initialCategoryId ?? (_categories.isNotEmpty ? _categories.first['id']?.toString() : null));

    String? selectedSubId = isEdit ? product['subcategory_id']?.toString() : initialSubcategoryId;

    bool isTodaysChoice = isEdit ? product['is_todays_choice'] == true : false;
    bool isSpecialDeal = isEdit ? product['is_special_deal'] == true : false;
    bool isPopular = isEdit ? product['is_popular'] == true : false;
    bool isActive = isEdit ? product['is_active'] != false : true;

    bool isUploading = false;
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Find current category's real subcategories
            List<dynamic> dialogSubcategories = [];
            if (selectedCatId != null) {
              final cat = _categories.firstWhere(
                (c) => c['id']?.toString() == selectedCatId,
                orElse: () => null,
              );
              if (cat != null && cat['subcategories'] is List) {
                dialogSubcategories = cat['subcategories'];
              }
            }

            Future<void> handleSave() async {
              if (titleCtrl.text.trim().isEmpty || priceCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Title and Price are required')),
                );
                return;
              }

              setDialogState(() => isSaving = true);
              try {
                final pPaise = ((double.tryParse(priceCtrl.text) ?? 0) * 100).round();
                final origPPaise = origPriceCtrl.text.isNotEmpty
                    ? ((double.tryParse(origPriceCtrl.text) ?? 0) * 100).round()
                    : null;

                final payload = {
                  if (isEdit) 'id': product['id'],
                  'title': titleCtrl.text.trim(),
                  'description': descCtrl.text.trim(),
                  'price_paise': pPaise,
                  'original_price_paise': origPPaise,
                  'unit': unitCtrl.text.trim(),
                  'stock_quantity': int.tryParse(stockCtrl.text) ?? 50,
                  'category_id': selectedCatId,
                  'subcategory_id': selectedSubId,
                  'image_url': imageCtrl.text.trim(),
                  'is_todays_choice': isTodaysChoice,
                  'is_special_deal': isSpecialDeal,
                  'is_popular': isPopular,
                  'is_active': isActive,
                };

                final headers = {
                  ...CubePod.get<AuthRepository>().authHeaders,
                  'Content-Type': 'application/json',
                };
                final url = Uri.parse('${AppConfig.apiUrl}/admin/products');
                final messenger = ScaffoldMessenger.of(context);

                http.Response res;
                if (isEdit) {
                  res = await http.patch(
                    url,
                    headers: headers,
                    body: jsonEncode(payload),
                  );
                  if (res.statusCode == 404 || res.statusCode == 405) {
                    res = await http.put(
                      url,
                      headers: headers,
                      body: jsonEncode(payload),
                    );
                  }
                } else {
                  res = await http.post(
                    url,
                    headers: headers,
                    body: jsonEncode(payload),
                  );
                }

                if (res.statusCode == 200 || res.statusCode == 201) {
                  if (modalContext.mounted) {
                    Navigator.pop(modalContext);
                  }
                  _fetchProducts();
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(isEdit ? 'Product updated!' : 'Product added!'),
                      backgroundColor: const Color(0xFF185B3A),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                } else {
                  messenger.showSnackBar(
                    SnackBar(content: Text('Failed to save: ${res.statusCode}')),
                  );
                }
              } catch (e) {
                debugPrint('Error saving product: $e');
              } finally {
                setDialogState(() => isSaving = false);
              }
            }

            return Container(
              height: MediaQuery.of(context).size.height * 0.92,
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(3)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isEdit ? 'Product Details & Edit' : 'Add New Product',
                              style: GoogleFonts.outfit(fontSize: 19, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                            ),
                            Text(
                              isEdit ? 'View & edit details, prices & category' : 'Fill details to add to catalog',
                              style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF64748B)),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            if (isEdit) ...[
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626)),
                                tooltip: 'Delete Product',
                                onPressed: () {
                                  Navigator.pop(modalContext);
                                  _deleteProduct(product['id'], product['title']);
                                },
                              ),
                              const SizedBox(width: 4),
                            ],
                            IconButton(
                              icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildField('Product Title *', titleCtrl, 'e.g. Royal Gala Apples'),
                          const SizedBox(height: 14),
                          _buildField('Description', descCtrl, 'e.g. Crisp, sweet organic farm-picked apples', maxLines: 2),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(child: _buildField('Price (₹) *', priceCtrl, '120', isNumber: true)),
                              const SizedBox(width: 12),
                              Expanded(child: _buildField('Original Price (₹)', origPriceCtrl, '160', isNumber: true)),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(child: _buildField('Unit (Weight/Qty)', unitCtrl, '1 kg / 500 g / 1 dozen')),
                              const SizedBox(width: 12),
                              Expanded(child: _buildField('Stock Quantity', stockCtrl, '50', isNumber: true)),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Real Category Dropdown
                          Text('Category *', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF334155))),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                              borderRadius: BorderRadius.circular(12),
                              color: const Color(0xFFF8FAFC),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                isExpanded: true,
                                value: selectedCatId,
                                hint: Text('Select Category', style: GoogleFonts.outfit(fontSize: 13)),
                                items: _categories.map<DropdownMenuItem<String>>((cat) {
                                  final id = cat['id']?.toString();
                                  final name = (cat['name'] ?? cat['label'] ?? 'Category').toString();
                                  return DropdownMenuItem<String>(
                                    value: id,
                                    child: Text(name, style: GoogleFonts.outfit(fontSize: 13.5, fontWeight: FontWeight.w600)),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  setDialogState(() {
                                    selectedCatId = val;
                                    selectedSubId = null; // Reset subcategory when category changes
                                  });
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Real Subcategory Dropdown (Dynamic)
                          Text('Subcategory', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF334155))),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                              borderRadius: BorderRadius.circular(12),
                              color: dialogSubcategories.isEmpty ? const Color(0xFFF1F5F9) : const Color(0xFFF8FAFC),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                isExpanded: true,
                                value: selectedSubId,
                                hint: Text(
                                  dialogSubcategories.isEmpty
                                      ? 'Select a category first'
                                      : 'Select Subcategory (Optional)',
                                  style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF94A3B8)),
                                ),
                                items: dialogSubcategories.map<DropdownMenuItem<String>>((sub) {
                                  final id = sub['id']?.toString();
                                  final name = (sub['name'] ?? 'Subcategory').toString();
                                  return DropdownMenuItem<String>(
                                    value: id,
                                    child: Text(name, style: GoogleFonts.outfit(fontSize: 13.5)),
                                  );
                                }).toList(),
                                onChanged: dialogSubcategories.isEmpty
                                    ? null
                                    : (val) => setDialogState(() => selectedSubId = val),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Image Upload & Preview
                          Text('Product Image', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF334155))),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: imageCtrl,
                                  onChanged: (_) => setDialogState(() {}),
                                  style: GoogleFonts.outfit(fontSize: 13),
                                  decoration: InputDecoration(
                                    hintText: 'Image URL or pick an image...',
                                    hintStyle: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF94A3B8)),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF185B3A),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  elevation: 0,
                                ),
                                onPressed: isUploading ? null : () async {
                                  final picker = ImagePicker();
                                  final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
                                  if (picked != null) {
                                    setDialogState(() => isUploading = true);
                                    try {
                                      final bytes = await picked.readAsBytes();
                                      final uri = Uri.parse('${AppConfig.apiUrl}/admin/products/upload');
                                      final request = http.MultipartRequest('POST', uri);
                                      request.headers.addAll(CubePod.get<AuthRepository>().multipartAuthHeaders);
                                      request.files.add(_buildImageMultipartFile(bytes, picked.name));
                                      final streamedRes = await request.send();
                                      final res = await http.Response.fromStream(streamedRes);
                                      if (res.statusCode == 200 || res.statusCode == 201) {
                                        final data = jsonDecode(res.body);
                                        final uploadedUrl = data['image_url'] ?? data['url'] ?? data['data']?['url'];
                                        if (uploadedUrl != null) {
                                          setDialogState(() {
                                            imageCtrl.text = uploadedUrl.toString();
                                          });
                                        }
                                      } else {
                                        String errTxt = 'Upload failed (${res.statusCode})';
                                        try {
                                          final d = jsonDecode(res.body);
                                          errTxt = d['error'] ?? d['message'] ?? errTxt;
                                        } catch (_) {}
                                        if (res.statusCode == 401) {
                                          errTxt = 'Session expired. Please log in again.';
                                        }
                                        if (context.mounted) {
                                          AppToast.error(context, errTxt);
                                        }
                                      }
                                    } catch (e) {
                                      debugPrint('Error uploading product image: $e');
                                      if (context.mounted) {
                                        AppToast.error(context, 'Image upload failed: $e');
                                      }
                                    } finally {
                                      setDialogState(() => isUploading = false);
                                    }
                                  }
                                },
                                icon: isUploading
                                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : const Icon(Icons.upload_file, size: 16, color: Colors.white),
                                label: Text('Pick', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                              ),
                            ],
                          ),

                          if (imageCtrl.text.trim().isNotEmpty) ...[
                            const SizedBox(height: 10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: SizedBox(
                                height: 120,
                                width: double.infinity,
                                child: SkeletonImage(
                                  imageUrl: imageCtrl.text.trim(),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ],

                          const SizedBox(height: 18),

                          // Toggle Badges
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            activeThumbColor: const Color(0xFF185B3A),
                            title: Text("Active in Catalog", style: GoogleFonts.outfit(fontSize: 13.5, fontWeight: FontWeight.w600)),
                            subtitle: Text("Display and allow purchase in the store", style: GoogleFonts.outfit(fontSize: 11.5, color: const Color(0xFF64748B))),
                            value: isActive,
                            onChanged: (val) => setDialogState(() => isActive = val),
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            activeThumbColor: const Color(0xFF185B3A),
                            title: Text("Today's Choice", style: GoogleFonts.outfit(fontSize: 13.5, fontWeight: FontWeight.w600)),
                            subtitle: Text("Feature on Home Screen Today's Choice section", style: GoogleFonts.outfit(fontSize: 11.5, color: const Color(0xFF64748B))),
                            value: isTodaysChoice,
                            onChanged: (val) => setDialogState(() => isTodaysChoice = val),
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            activeThumbColor: const Color(0xFF185B3A),
                            title: Text('Special Deal', style: GoogleFonts.outfit(fontSize: 13.5, fontWeight: FontWeight.w600)),
                            subtitle: Text('Showcase in Deals & Super Savers', style: GoogleFonts.outfit(fontSize: 11.5, color: const Color(0xFF64748B))),
                            value: isSpecialDeal,
                            onChanged: (val) => setDialogState(() => isSpecialDeal = val),
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            activeThumbColor: const Color(0xFF185B3A),
                            title: Text('Popular Item', style: GoogleFonts.outfit(fontSize: 13.5, fontWeight: FontWeight.w600)),
                            subtitle: Text('Display in trending & popular grocery list', style: GoogleFonts.outfit(fontSize: 11.5, color: const Color(0xFF64748B))),
                            value: isPopular,
                            onChanged: (val) => setDialogState(() => isPopular = val),
                          ),
                          const SizedBox(height: 24),

                          // Action Buttons: Delete (if isEdit) + Save
                          if (isEdit) ...[
                            Row(
                              children: [
                                Expanded(
                                  flex: 1,
                                  child: SizedBox(
                                    height: 52,
                                    child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(color: Color(0xFFFCA5A5)),
                                        backgroundColor: const Color(0xFFFEF2F2),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                      ),
                                      icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFDC2626)),
                                      label: Text(
                                        'Delete',
                                        style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFFDC2626)),
                                      ),
                                      onPressed: isSaving
                                          ? null
                                          : () {
                                              Navigator.pop(modalContext);
                                              _deleteProduct(product['id'], product['title']);
                                            },
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 2,
                                  child: SizedBox(
                                    height: 52,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF185B3A),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                        elevation: 0,
                                      ),
                                      onPressed: isSaving ? null : handleSave,
                                      child: isSaving
                                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                          : Text(
                                              'Save Changes',
                                              style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                                            ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ] else ...[
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF185B3A),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  elevation: 0,
                                ),
                                onPressed: isSaving ? null : handleSave,
                                child: isSaving
                                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                    : Text(
                                        'Add to Catalog',
                                        style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                                      ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildField(String label, TextEditingController ctrl, String hint, {bool isNumber = false, int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF334155))),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          maxLines: maxLines,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          style: GoogleFonts.outfit(fontSize: 13.5),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.outfit(fontSize: 12.5, color: const Color(0xFF94A3B8)),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildStepperBtn({required IconData icon, required VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: onTap != null ? Colors.white : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Icon(icon, size: 13, color: onTap != null ? const Color(0xFF0F172A) : const Color(0xFFCBD5E1)),
      ),
    );
  }

  void _showAddOptionsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(28),
            topRight: Radius.circular(28),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: const Color(0xFF185B3A).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF185B3A), size: 20),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Create New',
                      style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                    ),
                    Text(
                      'Select what you want to add to the catalog',
                      style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF64748B)),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Option 1: Product
            _buildActionOptionTile(
              title: 'Product',
              subtitle: 'Add grocery item with price, image and stock',
              icon: Icons.inventory_2_rounded,
              iconColor: const Color(0xFF185B3A),
              bgColor: const Color(0xFFDCFCE7),
              onTap: () {
                Navigator.pop(ctx);
                _showProductDialog();
              },
            ),
            const SizedBox(height: 10),

            // Option 2: Category
            _buildActionOptionTile(
              title: 'Category',
              subtitle: 'Create a main department (e.g. Fruits, Dairy)',
              icon: Icons.category_rounded,
              iconColor: const Color(0xFF2563EB),
              bgColor: const Color(0xFFDBEAFE),
              onTap: () {
                Navigator.pop(ctx);
                _showAddCategoryDialog();
              },
            ),
            const SizedBox(height: 10),

            // Option 3: Subcategory
            _buildActionOptionTile(
              title: 'Subcategory',
              subtitle: 'Add a section under an existing category (e.g. Fresh Fruits)',
              icon: Icons.account_tree_rounded,
              iconColor: const Color(0xFFD97706),
              bgColor: const Color(0xFFFEF3C7),
              onTap: () {
                Navigator.pop(ctx);
                _showAddSubcategoryDialog();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionOptionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.outfit(
                      fontSize: 11.5,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }

  Color _parseHexColor(String hex) {
    var cleaned = hex.replaceAll('#', '').trim();
    if (cleaned.length == 3) {
      cleaned = cleaned.split('').map((c) => '$c$c').join();
    }
    if (cleaned.length == 6) {
      cleaned = 'FF$cleaned';
    } else if (cleaned.length != 8) {
      return const Color(0xFF185B3A);
    }
    return Color(int.tryParse(cleaned, radix: 16) ?? 0xFF185B3A);
  }

  int _colorR(Color c) => (c.r * 255.0).round().clamp(0, 255);
  int _colorG(Color c) => (c.g * 255.0).round().clamp(0, 255);
  int _colorB(Color c) => (c.b * 255.0).round().clamp(0, 255);

  String _rgbToHex(int r, int g, int b) {
    final rs = r.clamp(0, 255).toRadixString(16).padLeft(2, '0');
    final gs = g.clamp(0, 255).toRadixString(16).padLeft(2, '0');
    final bs = b.clamp(0, 255).toRadixString(16).padLeft(2, '0');
    return '#$rs$gs$bs'.toUpperCase();
  }

  Widget _buildRgbSlider({
    required String label,
    required Color labelColor,
    required int value,
    required LinearGradient gradient,
    required ValueChanged<int> onChanged,
  }) {
    return Row(
      children: [
        Container(
          width: 22,
          alignment: Alignment.center,
          child: Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: labelColor,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          width: 44,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: Text(
            value.toString(),
            style: GoogleFonts.outfit(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1E293B),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SizedBox(
            height: 30,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  height: 12,
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    gradient: gradient,
                    border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
                  ),
                ),
                SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 12,
                    activeTrackColor: Colors.transparent,
                    inactiveTrackColor: Colors.transparent,
                    thumbColor: Colors.white,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 8,
                      elevation: 3,
                    ),
                    overlayColor: labelColor.withValues(alpha: 0.12),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                  ),
                  child: Slider(
                    value: value.toDouble().clamp(0.0, 255.0),
                    min: 0,
                    max: 255,
                    onChanged: (v) => onChanged(v.round()),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _openRgbColorPickerDialog(String? initialHex, ValueChanged<String?> onSelected) {
    Color currentColor = initialHex != null ? _parseHexColor(initialHex) : const Color(0xFF185B3A);
    int r = _colorR(currentColor);
    int g = _colorG(currentColor);
    int b = _colorB(currentColor);
    final hexTextCtrl = TextEditingController(text: _rgbToHex(r, g, b));

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setPickerState) {
            final activeColor = Color.fromARGB(255, r, g, b);
            final hexString = _rgbToHex(r, g, b);
            final rgbString = 'rgb($r, $g, $b)';

            void updateRgb(int newR, int newG, int newB) {
              setPickerState(() {
                r = newR.clamp(0, 255);
                g = newG.clamp(0, 255);
                b = newB.clamp(0, 255);
                currentColor = Color.fromARGB(255, r, g, b);
                hexTextCtrl.text = _rgbToHex(r, g, b);
              });
            }

            void updateFromColor(Color c) {
              setPickerState(() {
                currentColor = c;
                r = _colorR(c);
                g = _colorG(c);
                b = _colorB(c);
                hexTextCtrl.text = _rgbToHex(r, g, b);
              });
            }

            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: Container(
                width: 360,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.9,
                ),
                padding: const EdgeInsets.all(20),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF185B3A).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.palette_rounded, size: 18, color: Color(0xFF185B3A)),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'RGB Color Picker',
                                style: GoogleFonts.outfit(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                            onPressed: () => Navigator.pop(dialogCtx),
                            splashRadius: 20,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Swatch Box + RGB / HEX Inputs
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 68,
                            height: 74,
                            decoration: BoxDecoration(
                              color: activeColor,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.black.withValues(alpha: 0.1), width: 1.5),
                              boxShadow: [
                                BoxShadow(
                                  color: activeColor.withValues(alpha: 0.35),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              children: [
                                Container(
                                  height: 34,
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          rgbString,
                                          style: GoogleFonts.outfit(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF1E293B),
                                          ),
                                        ),
                                      ),
                                      InkWell(
                                        onTap: () {
                                          Clipboard.setData(ClipboardData(text: rgbString));
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('Copied $rgbString to clipboard!'),
                                              duration: const Duration(seconds: 1),
                                              behavior: SnackBarBehavior.floating,
                                            ),
                                          );
                                        },
                                        child: const Padding(
                                          padding: EdgeInsets.all(4),
                                          child: Icon(Icons.copy_rounded, size: 14, color: Color(0xFF64748B)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  height: 34,
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: hexTextCtrl,
                                          style: GoogleFonts.outfit(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFF1E293B),
                                          ),
                                          decoration: const InputDecoration(
                                            border: InputBorder.none,
                                            isDense: true,
                                            contentPadding: EdgeInsets.zero,
                                          ),
                                          onChanged: (val) {
                                            final parsed = _parseHexColor(val);
                                            setPickerState(() {
                                              r = _colorR(parsed);
                                              g = _colorG(parsed);
                                              b = _colorB(parsed);
                                              currentColor = parsed;
                                            });
                                          },
                                        ),
                                      ),
                                      InkWell(
                                        onTap: () {
                                          Clipboard.setData(ClipboardData(text: hexString));
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('Copied $hexString to clipboard!'),
                                              duration: const Duration(seconds: 1),
                                              behavior: SnackBarBehavior.floating,
                                            ),
                                          );
                                        },
                                        child: const Padding(
                                          padding: EdgeInsets.all(4),
                                          child: Icon(Icons.copy_rounded, size: 14, color: Color(0xFF64748B)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // RGB Sliders Section
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          children: [
                            _buildRgbSlider(
                              label: 'R',
                              labelColor: const Color(0xFFEF4444),
                              value: r,
                              gradient: LinearGradient(
                                colors: [
                                  Color.fromARGB(255, 0, g, b),
                                  Color.fromARGB(255, 255, g, b),
                                ],
                              ),
                              onChanged: (val) => updateRgb(val, g, b),
                            ),
                            const SizedBox(height: 8),
                            _buildRgbSlider(
                              label: 'G',
                              labelColor: const Color(0xFF10B981),
                              value: g,
                              gradient: LinearGradient(
                                colors: [
                                  Color.fromARGB(255, r, 0, b),
                                  Color.fromARGB(255, r, 255, b),
                                ],
                              ),
                              onChanged: (val) => updateRgb(r, val, b),
                            ),
                            const SizedBox(height: 8),
                            _buildRgbSlider(
                              label: 'B',
                              labelColor: const Color(0xFF3B82F6),
                              value: b,
                              gradient: LinearGradient(
                                colors: [
                                  Color.fromARGB(255, r, g, 0),
                                  Color.fromARGB(255, r, g, 255),
                                ],
                              ),
                              onChanged: (val) => updateRgb(r, g, val),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 2D Color Canvas & Hue Slider
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: ColorPicker(
                          pickerColor: activeColor,
                          onColorChanged: updateFromColor,
                          colorPickerWidth: 320,
                          pickerAreaHeightPercent: 0.55,
                          enableAlpha: false,
                          displayThumbColor: true,
                          paletteType: PaletteType.hsvWithHue,
                          labelTypes: const [],
                          pickerAreaBorderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Quick preset palette
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Presets',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                          Wrap(
                            spacing: 8,
                            children: [
                              '#185B3A',
                              '#10B981',
                              '#3B82F6',
                              '#F59E0B',
                              '#EF4444',
                              '#8B5CF6',
                              '#06B6D4',
                              '#1E293B',
                            ].map((hex) {
                              final c = _parseHexColor(hex);
                              final isCur = hexString.toUpperCase() == hex.toUpperCase();
                              return GestureDetector(
                                onTap: () => updateFromColor(c),
                                child: Container(
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    color: c,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isCur ? Colors.black87 : Colors.white,
                                      width: isCur ? 2 : 1.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 2),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Action Buttons (with No Color option!)
                      Row(
                        children: [
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFFEF4444),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                            onPressed: () {
                              onSelected(null);
                              Navigator.pop(dialogCtx);
                            },
                            icon: const Icon(Icons.block_rounded, size: 16, color: Color(0xFFEF4444)),
                            label: Text(
                              'No Color',
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFFEF4444),
                              ),
                            ),
                          ),
                          const Spacer(),
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFFCBD5E1)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            ),
                            onPressed: () => Navigator.pop(dialogCtx),
                            child: Text(
                              'Cancel',
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: activeColor,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              elevation: 2,
                            ),
                            onPressed: () {
                              onSelected(hexString);
                              Navigator.pop(dialogCtx);
                            },
                            child: Text(
                              'Apply Color',
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: activeColor.computeLuminance() > 0.5 ? Colors.black87 : Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showAddCategoryDialog() {
    final nameCtrl = TextEditingController();
    final imageCtrl = TextEditingController();
    Uint8List? pickedImageBytes;
    String? pickedImageName;
    String? selectedColor = '#185B3A';
    bool isSaving = false;
    bool showInlineRgb = false;

    final presetColors = [
      {'name': 'Emerald', 'hex': '#185B3A'},
      {'name': 'Forest', 'hex': '#10B981'},
      {'name': 'Blue', 'hex': '#3B82F6'},
      {'name': 'Amber', 'hex': '#F59E0B'},
      {'name': 'Rose', 'hex': '#EF4444'},
      {'name': 'Purple', 'hex': '#8B5CF6'},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.88,
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              left: 20,
              right: 20,
              top: 12,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(28),
                topRight: Radius.circular(28),
              ),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('New Category', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Divider(height: 1),
                  const SizedBox(height: 16),
                  _buildField('Category Name *', nameCtrl, 'e.g. Spices & Masalas'),
                  const SizedBox(height: 14),
                  
                  // Category Image URL + Upload Button
                  Text('Category Image', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF334155))),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: imageCtrl,
                          onChanged: (_) {
                            pickedImageBytes = null;
                            pickedImageName = null;
                            setSheetState(() {});
                          },
                          style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF0F172A)),
                          decoration: InputDecoration(
                            hintText: 'Image URL or pick from device...',
                            hintStyle: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF94A3B8)),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF185B3A), width: 1.5)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF185B3A),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        onPressed: () async {
                          final picker = ImagePicker();
                          final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
                          if (picked != null) {
                            final bytes = await picked.readAsBytes();
                            setSheetState(() {
                              pickedImageBytes = bytes;
                              pickedImageName = picked.name;
                              imageCtrl.text = picked.name;
                            });
                          }
                        },
                        icon: const Icon(Icons.upload_file_rounded, size: 16, color: Colors.white),
                        label: Text('Upload', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ],
                  ),
                  if (pickedImageBytes != null || imageCtrl.text.trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            height: 110,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: pickedImageBytes != null
                                ? Image.memory(
                                    pickedImageBytes!,
                                    fit: BoxFit.cover,
                                  )
                                : SkeletonImage(
                                    imageUrl: imageCtrl.text.trim(),
                                    fit: BoxFit.cover,
                                  ),
                          ),
                        ),
                        Positioned(
                          top: 6,
                          right: 6,
                          child: GestureDetector(
                            onTap: () => setSheetState(() {
                              pickedImageBytes = null;
                              pickedImageName = null;
                              imageCtrl.clear();
                            }),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                              child: const Icon(Icons.close_rounded, size: 14, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Theme Color', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF334155))),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () {
                          _openRgbColorPickerDialog(selectedColor, (newHex) {
                            setSheetState(() => selectedColor = newHex);
                          });
                        },
                        icon: const Icon(Icons.colorize_rounded, size: 14, color: Color(0xFF185B3A)),
                        label: Text('RGB Picker', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF185B3A))),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Preset chips + Custom chip + Rainbow Picker button
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // "No Color (Null)" Chip
                      GestureDetector(
                        onTap: () => setSheetState(() => selectedColor = null),
                        child: Tooltip(
                          message: 'No Color (Null)',
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: selectedColor == null ? const Color(0xFF0F172A) : const Color(0xFFCBD5E1),
                                width: selectedColor == null ? 2.5 : 1.5,
                              ),
                              boxShadow: selectedColor == null
                                  ? [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 6, offset: const Offset(0, 2))]
                                  : null,
                            ),
                            child: Center(
                              child: selectedColor == null
                                  ? const Icon(Icons.check, size: 18, color: Color(0xFF0F172A))
                                  : const Icon(Icons.block_rounded, size: 16, color: Color(0xFF94A3B8)),
                            ),
                          ),
                        ),
                      ),

                      ...presetColors.map((col) {
                        final hex = col['hex']!;
                        final isSel = selectedColor != null && selectedColor!.toUpperCase() == hex.toUpperCase();
                        final c = _parseHexColor(hex);
                        return GestureDetector(
                          onTap: () => setSheetState(() => selectedColor = hex),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSel ? Colors.black87 : Colors.transparent,
                                width: 2.5,
                              ),
                              boxShadow: isSel
                                  ? [BoxShadow(color: c.withValues(alpha: 0.4), blurRadius: 6, offset: const Offset(0, 2))]
                                  : null,
                            ),
                            child: isSel ? const Icon(Icons.check, size: 18, color: Colors.white) : null,
                          ),
                        );
                      }),
                      if (selectedColor != null && !presetColors.any((col) => col['hex']!.toUpperCase() == selectedColor!.toUpperCase())) ...[
                        Builder(builder: (_) {
                          final c = _parseHexColor(selectedColor!);
                          return Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.black87, width: 2.5),
                              boxShadow: [BoxShadow(color: c.withValues(alpha: 0.4), blurRadius: 6, offset: const Offset(0, 2))],
                            ),
                            child: const Icon(Icons.check, size: 18, color: Colors.white),
                          );
                        }),
                      ],
                      // Rainbow Picker button
                      GestureDetector(
                        onTap: () {
                          _openRgbColorPickerDialog(selectedColor, (newHex) {
                            setSheetState(() => selectedColor = newHex);
                          });
                        },
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const SweepGradient(
                              colors: [
                                Color(0xFFFF0000),
                                Color(0xFFFF8800),
                                Color(0xFFFFFF00),
                                Color(0xFF00FF00),
                                Color(0xFF00FFFF),
                                Color(0xFF0000FF),
                                Color(0xFFFF00FF),
                                Color(0xFFFF0000),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 4, offset: const Offset(0, 2)),
                            ],
                          ),
                          child: Container(
                            margin: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                            child: const Icon(Icons.palette_rounded, size: 16, color: Color(0xFF1E293B)),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  if (selectedColor == null) ...[
                    // No Color Selected card
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
                            ),
                            child: const Icon(Icons.block_rounded, size: 20, color: Color(0xFF64748B)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'No Color Selected (Null)',
                                  style: GoogleFonts.outfit(fontSize: 13.5, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                                ),
                                Text(
                                  'Category will display with default neutral styling',
                                  style: GoogleFonts.outfit(fontSize: 11.5, color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF185B3A),
                              side: const BorderSide(color: Color(0xFF185B3A)),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () {
                              _openRgbColorPickerDialog(null, (newHex) {
                                setSheetState(() => selectedColor = newHex);
                              });
                            },
                            icon: const Icon(Icons.palette_rounded, size: 14),
                            label: Text('Pick Color', style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    // Color Summary Card (Swatch, RGB, HEX, and quick adjust toggle)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: _parseHexColor(selectedColor!),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.black12, width: 1),
                                  boxShadow: [
                                    BoxShadow(color: _parseHexColor(selectedColor!).withValues(alpha: 0.3), blurRadius: 6, offset: const Offset(0, 2)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      selectedColor!.toUpperCase(),
                                      style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                                    ),
                                    Text(
                                      () {
                                        final c = _parseHexColor(selectedColor!);
                                        return 'rgb(${_colorR(c)}, ${_colorG(c)}, ${_colorB(c)})';
                                      }(),
                                      style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                              ),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF185B3A),
                                  side: const BorderSide(color: Color(0xFF185B3A)),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: () {
                                  _openRgbColorPickerDialog(selectedColor, (newHex) {
                                    setSheetState(() => selectedColor = newHex);
                                  });
                                },
                                icon: const Icon(Icons.tune_rounded, size: 14),
                                label: Text('RGB Picker', style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),

                          // Inline quick sliders toggle
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: () => setSheetState(() => showInlineRgb = !showInlineRgb),
                            borderRadius: BorderRadius.circular(6),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Icon(showInlineRgb ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, size: 16, color: const Color(0xFF64748B)),
                                  const SizedBox(width: 4),
                                  Text(
                                    showInlineRgb ? 'Hide RGB sliders' : 'Quick RGB sliders',
                                    style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          if (showInlineRgb) ...[
                            const SizedBox(height: 8),
                            Builder(builder: (_) {
                              final c = _parseHexColor(selectedColor!);
                              int r = _colorR(c);
                              int g = _colorG(c);
                              int b = _colorB(c);
                              return Column(
                                children: [
                                  _buildRgbSlider(
                                    label: 'R',
                                    labelColor: const Color(0xFFEF4444),
                                    value: r,
                                    gradient: LinearGradient(colors: [Color.fromARGB(255, 0, g, b), Color.fromARGB(255, 255, g, b)]),
                                    onChanged: (newR) => setSheetState(() => selectedColor = _rgbToHex(newR, g, b)),
                                  ),
                                  const SizedBox(height: 6),
                                  _buildRgbSlider(
                                    label: 'G',
                                    labelColor: const Color(0xFF10B981),
                                    value: g,
                                    gradient: LinearGradient(colors: [Color.fromARGB(255, r, 0, b), Color.fromARGB(255, r, 255, b)]),
                                    onChanged: (newG) => setSheetState(() => selectedColor = _rgbToHex(r, newG, b)),
                                  ),
                                  const SizedBox(height: 6),
                                  _buildRgbSlider(
                                    label: 'B',
                                    labelColor: const Color(0xFF3B82F6),
                                    value: b,
                                    gradient: LinearGradient(colors: [Color.fromARGB(255, r, g, 0), Color.fromARGB(255, r, g, 255)]),
                                    onChanged: (newB) => setSheetState(() => selectedColor = _rgbToHex(r, g, newB)),
                                  ),
                                ],
                              );
                            }),
                          ],
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF185B3A),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      onPressed: isSaving ? null : () async {
                        final name = nameCtrl.text.trim();
                        if (name.isEmpty) {
                          AppToast.warning(context, 'Please enter category name');
                          return;
                        }

                        if (pickedImageBytes == null && imageCtrl.text.trim().isEmpty) {
                          AppToast.warning(context, 'Please select or upload a category image');
                          return;
                        }

                        setSheetState(() => isSaving = true);
                        try {
                          String? finalImageUrl;

                          // 1. If an image was picked and cached locally, upload it now upon creation!
                          if (pickedImageBytes != null) {
                            String uploadErr = '';
                            try {
                              final uri = Uri.parse('${AppConfig.apiUrl}/admin/categories/upload');
                              final request = http.MultipartRequest('POST', uri);
                              request.headers.addAll(CubePod.get<AuthRepository>().multipartAuthHeaders);
                              request.fields['type'] = 'category';
                              request.fields['name'] = name;
                              request.files.add(_buildImageMultipartFile(pickedImageBytes!, pickedImageName ?? 'category.jpg'));
                              final streamedRes = await request.send();
                              final res = await http.Response.fromStream(streamedRes);
                              if (res.statusCode == 200 || res.statusCode == 201) {
                                final data = jsonDecode(res.body);
                                final uploadedUrl = data['image_url'] ?? data['url'] ?? data['data']?['url'];
                                if (uploadedUrl != null) {
                                  finalImageUrl = uploadedUrl.toString();
                                }
                              } else {
                                try {
                                  final d = jsonDecode(res.body);
                                  uploadErr = d['error'] ?? d['message'] ?? '';
                                } catch (_) {}
                                if (res.statusCode == 401) {
                                  uploadErr = 'Session expired. Please log in again.';
                                }

                                final fbUri = Uri.parse('${AppConfig.apiUrl}/admin/products/upload');
                                final fbReq = http.MultipartRequest('POST', fbUri);
                                fbReq.headers.addAll(CubePod.get<AuthRepository>().multipartAuthHeaders);
                                fbReq.files.add(_buildImageMultipartFile(pickedImageBytes!, pickedImageName ?? 'category.jpg'));
                                final fbStreamed = await fbReq.send();
                                final fbRes = await http.Response.fromStream(fbStreamed);
                                if (fbRes.statusCode == 200 || fbRes.statusCode == 201) {
                                  final fbData = jsonDecode(fbRes.body);
                                  final uploadedUrl = fbData['image_url'] ?? fbData['url'] ?? fbData['data']?['url'];
                                  if (uploadedUrl != null) {
                                    finalImageUrl = uploadedUrl.toString();
                                    uploadErr = '';
                                  }
                                } else if (uploadErr.isEmpty) {
                                  try {
                                    final d = jsonDecode(fbRes.body);
                                    uploadErr = d['error'] ?? d['message'] ?? '';
                                  } catch (_) {}
                                }
                              }
                            } catch (e) {
                              debugPrint('Error uploading category image: $e');
                              uploadErr = e.toString();
                            }

                            if (finalImageUrl == null || finalImageUrl.isEmpty) {
                              if (mounted) {
                                AppToast.error(
                                  context,
                                  uploadErr.isNotEmpty
                                      ? 'Failed to upload category image: $uploadErr'
                                      : 'Failed to upload category image. Please try again.',
                                );
                              }
                              return;
                            }
                          } else if (imageCtrl.text.trim().isNotEmpty) {
                            finalImageUrl = imageCtrl.text.trim();
                          }

                          if (pickedImageBytes != null && (finalImageUrl == null || finalImageUrl.isEmpty)) {
                            if (mounted) {
                              AppToast.error(context, 'Failed to upload category image. Please try again.');
                            }
                            return;
                          }

                          // 2. Save category to database
                          final payload = {
                            'name': name,
                            'label': name,
                            'color_hex': selectedColor,
                            'color': selectedColor,
                            'image_url': finalImageUrl,
                            'image': finalImageUrl,
                          };
                          final res = await http.post(
                            Uri.parse('${AppConfig.apiUrl}/admin/categories'),
                            headers: {
                              ...CubePod.get<AuthRepository>().authHeaders,
                              'Content-Type': 'application/json',
                            },
                            body: jsonEncode(payload),
                          );
                          if (res.statusCode == 200 || res.statusCode == 201) {
                            if (modalCtx.mounted) Navigator.pop(modalCtx);
                            _fetchCategories();

                            // Optimistically update device cache so it's instantly available
                            try {
                              final currentCache = CacheService.get<List>('categories') ?? [];
                              final dynamic resJson = jsonDecode(res.body);
                              final createdCat = resJson is Map ? (resJson['data'] ?? resJson['category'] ?? payload) : payload;
                              CacheService.set('categories', [...currentCache, createdCat]);
                            } catch (_) {}

                            if (mounted) {
                              AppToast.success(context, 'Category created successfully!');
                            }
                          } else {
                            String errorMsg = 'Failed to create category';
                            try {
                              final errData = jsonDecode(res.body);
                              errorMsg = errData['error'] ?? errData['message'] ?? errorMsg;
                            } catch (_) {}

                            if (errorMsg.contains('categories_slug_key') ||
                                errorMsg.contains('duplicate key') ||
                                errorMsg.contains('unique constraint')) {
                              errorMsg = 'A category named "$name" already exists. Please use a different name.';
                            }

                            if (mounted) {
                              AppToast.error(context, errorMsg);
                            }
                          }
                        } catch (e) {
                          debugPrint('Error creating category: $e');
                          if (mounted) {
                            AppToast.error(context, 'Error creating category: $e');
                          }
                        } finally {
                          setSheetState(() => isSaving = false);
                        }
                      },
                      child: isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : Text('Create Category', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showAddSubcategoryDialog({String? initialCategoryId}) {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final imageCtrl = TextEditingController();
    String? selectedParentId = initialCategoryId ?? (_categories.isNotEmpty ? _categories.first['id']?.toString() : null);
    bool isSaving = false;
    bool isUploading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.88,
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              left: 20,
              right: 20,
              top: 12,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(28),
                topRight: Radius.circular(28),
              ),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('New Subcategory', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Divider(height: 1),
                  const SizedBox(height: 16),
                  Text('Parent Category *', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF334155))),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      borderRadius: BorderRadius.circular(12),
                      color: const Color(0xFFF8FAFC),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: selectedParentId,
                        items: _categories.map<DropdownMenuItem<String>>((cat) {
                          final id = cat['id']?.toString();
                          final name = (cat['name'] ?? cat['label'] ?? 'Category').toString();
                          return DropdownMenuItem<String>(
                            value: id,
                            child: Text(name, style: GoogleFonts.outfit(fontSize: 13.5, fontWeight: FontWeight.w600)),
                          );
                        }).toList(),
                        onChanged: (val) => setSheetState(() => selectedParentId = val),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildField('Subcategory Name *', nameCtrl, 'e.g. Whole Spices, Green Apples'),
                  const SizedBox(height: 14),
                  
                  // Subcategory Image URL + Upload Button
                  Text('Subcategory Image', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF334155))),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: imageCtrl,
                          onChanged: (_) => setSheetState(() {}),
                          style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF0F172A)),
                          decoration: InputDecoration(
                            hintText: 'Image URL or pick image...',
                            hintStyle: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF94A3B8)),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF185B3A), width: 1.5)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD97706),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        onPressed: isUploading ? null : () async {
                          final picker = ImagePicker();
                          final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
                          if (picked != null) {
                            setSheetState(() => isUploading = true);
                            try {
                              final bytes = await picked.readAsBytes();
                              final uri = Uri.parse('${AppConfig.apiUrl}/admin/categories/upload');
                              final request = http.MultipartRequest('POST', uri);
                              request.headers.addAll(CubePod.get<AuthRepository>().multipartAuthHeaders);
                              request.fields['type'] = 'subcategory';
                              request.fields['name'] = nameCtrl.text.trim().isNotEmpty ? nameCtrl.text.trim() : 'subcategory';
                              request.files.add(_buildImageMultipartFile(bytes, picked.name));
                              final streamedRes = await request.send();
                              final res = await http.Response.fromStream(streamedRes);
                              if (res.statusCode == 200 || res.statusCode == 201) {
                                final data = jsonDecode(res.body);
                                final uploadedUrl = data['image_url'] ?? data['url'] ?? data['data']?['url'];
                                if (uploadedUrl != null) {
                                  setSheetState(() {
                                    imageCtrl.text = uploadedUrl.toString();
                                  });
                                }
                              } else {
                                final fbUri = Uri.parse('${AppConfig.apiUrl}/admin/products/upload');
                                final fbReq = http.MultipartRequest('POST', fbUri);
                                fbReq.headers.addAll(CubePod.get<AuthRepository>().multipartAuthHeaders);
                                fbReq.files.add(_buildImageMultipartFile(bytes, picked.name));
                                final fbStreamed = await fbReq.send();
                                final fbRes = await http.Response.fromStream(fbStreamed);
                                if (fbRes.statusCode == 200 || fbRes.statusCode == 201) {
                                  final fbData = jsonDecode(fbRes.body);
                                  final uploadedUrl = fbData['image_url'] ?? fbData['url'] ?? fbData['data']?['url'];
                                  if (uploadedUrl != null) {
                                    setSheetState(() {
                                      imageCtrl.text = uploadedUrl.toString();
                                    });
                                  }
                                } else {
                                  String errTxt = 'Upload failed (${res.statusCode})';
                                  try {
                                    final d = jsonDecode(res.body);
                                    errTxt = d['error'] ?? d['message'] ?? errTxt;
                                  } catch (_) {}
                                  if (res.statusCode == 401) {
                                    errTxt = 'Session expired. Please log in again.';
                                  }
                                  if (mounted) {
                                    AppToast.error(context, errTxt);
                                  }
                                }
                              }
                            } catch (e) {
                              debugPrint('Error uploading subcategory image: $e');
                              if (mounted) {
                                AppToast.error(context, 'Upload failed: $e');
                              }
                            } finally {
                              setSheetState(() => isUploading = false);
                            }
                          }
                        },
                        icon: isUploading
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.upload_file_rounded, size: 16, color: Colors.white),
                        label: Text(isUploading ? 'Uploading...' : 'Upload', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ],
                  ),
                  if (imageCtrl.text.trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            height: 110,
                            width: double.infinity,
                            child: SkeletonImage(
                              imageUrl: imageCtrl.text.trim(),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 6,
                          right: 6,
                          child: GestureDetector(
                            onTap: () => setSheetState(() => imageCtrl.clear()),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                              child: const Icon(Icons.close_rounded, size: 14, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 14),
                  _buildField('Description (Optional)', descCtrl, 'Brief description of subcategory items'),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD97706),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      onPressed: isSaving ? null : () async {
                        final name = nameCtrl.text.trim();
                        if (name.isEmpty) {
                          AppToast.warning(context, 'Please enter subcategory name');
                          return;
                        }
                        if (selectedParentId == null) {
                          AppToast.warning(context, 'Please select a parent category');
                          return;
                        }
                        setSheetState(() => isSaving = true);
                        try {
                          final payload = {
                            'category_id': selectedParentId,
                            'name': name,
                            'image_url': imageCtrl.text.trim().isNotEmpty ? imageCtrl.text.trim() : null,
                            'description': descCtrl.text.trim().isNotEmpty ? descCtrl.text.trim() : null,
                          };
                          final res = await http.post(
                            Uri.parse('${AppConfig.apiUrl}/admin/subcategories'),
                            headers: {
                              ...CubePod.get<AuthRepository>().authHeaders,
                              'Content-Type': 'application/json',
                            },
                            body: jsonEncode(payload),
                          );
                          if (res.statusCode == 200 || res.statusCode == 201) {
                            if (modalCtx.mounted) Navigator.pop(modalCtx);
                            _fetchCategories();
                            if (mounted) {
                              AppToast.success(context, 'Subcategory created successfully!');
                            }
                          } else {
                            String errorMsg = 'Failed to create subcategory';
                            try {
                              final errData = jsonDecode(res.body);
                              errorMsg = errData['error'] ?? errData['message'] ?? errorMsg;
                            } catch (_) {}

                            if (errorMsg.contains('duplicate key') || errorMsg.contains('unique constraint')) {
                              errorMsg = 'A subcategory named "$name" already exists.';
                            }

                            if (mounted) {
                              AppToast.error(context, errorMsg);
                            }
                          }
                        } catch (e) {
                          debugPrint('Error creating subcategory: $e');
                          if (mounted) {
                            AppToast.error(context, 'Error creating subcategory: $e');
                          }
                        } finally {
                          setSheetState(() => isSaving = false);
                        }
                      },
                      child: isSaving
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text('Create Subcategory', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalCount = _products.length;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 16,
          title: Row(
            children: [
              Text(
                'Manage Products',
                style: GoogleFonts.outfit(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$totalCount',
                  style: GoogleFonts.outfit(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF15803D),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            // Review Section Button on top side of Manage Products
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Center(
                child: InkWell(
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ProductReviewPage()),
                    );
                    _fetchProducts();
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _pendingReviewCount > 0 ? const Color(0xFFFEF3C7) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _pendingReviewCount > 0 ? const Color(0xFFFDE68A) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.rate_review_outlined,
                          size: 15,
                          color: _pendingReviewCount > 0 ? const Color(0xFFD97706) : const Color(0xFF185B3A),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Review',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _pendingReviewCount > 0 ? const Color(0xFF92400E) : const Color(0xFF185B3A),
                          ),
                        ),
                        if (_pendingReviewCount > 0) ...[
                          const SizedBox(width: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$_pendingReviewCount',
                              style: GoogleFonts.outfit(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: const Color(0xFF185B3A),
          elevation: 3,
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          label: Text(
            'Add',
            style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
          ),
          onPressed: () => _showAddOptionsSheet(),
        ),
        body: Column(
          children: [
            // Search & Filter Header Container
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Search Input
                      Expanded(
                        child: Container(
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            children: [
                              const Icon(Icons.search_rounded, color: Color(0xFF94A3B8), size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  onChanged: (val) => setState(() => _searchQuery = val),
                                  style: GoogleFonts.outfit(fontSize: 13.5, color: const Color(0xFF0F172A)),
                                  decoration: InputDecoration(
                                    hintText: 'Search by title, code or subcategory...',
                                    hintStyle: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF94A3B8)),
                                    border: InputBorder.none,
                                    isDense: true,
                                  ),
                                ),
                              ),
                              if (_searchQuery.isNotEmpty)
                                GestureDetector(
                                  onTap: () => setState(() => _searchQuery = ''),
                                  child: const Icon(Icons.close_rounded, color: Color(0xFF64748B), size: 18),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Filter Button
                      InkWell(
                        onTap: _showFilterSheet,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          height: 44,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: _hasActiveFilters ? const Color(0xFF185B3A) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _hasActiveFilters ? const Color(0xFF185B3A) : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.tune_rounded,
                                size: 18,
                                color: _hasActiveFilters ? Colors.white : const Color(0xFF334155),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _hasActiveFilters ? 'Filter ($_activeFilterCount)' : 'Filter',
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: _hasActiveFilters ? Colors.white : const Color(0xFF334155),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Active Filter Badges (Only appears when filters are active from sheet)
                  if (_hasActiveFilters) ...[
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          if (_selectedCategory != 'All') ...[
                            _buildActiveFilterBadge(
                              'Cat: $_selectedCategory',
                              onRemove: () => setState(() {
                                _selectedCategory = 'All';
                                _selectedSubcategory = 'All';
                              }),
                            ),
                            const SizedBox(width: 6),
                          ],
                          if (_selectedSubcategory != 'All') ...[
                            _buildActiveFilterBadge(
                              'Subcat: $_selectedSubcategory',
                              onRemove: () => setState(() {
                                _selectedSubcategory = 'All';
                              }),
                            ),
                            const SizedBox(width: 6),
                          ],
                          if (_selectedStockStatus != 'All') ...[
                            _buildActiveFilterBadge(
                              _selectedStockStatus,
                              onRemove: () => setState(() => _selectedStockStatus = 'All'),
                            ),
                            const SizedBox(width: 6),
                          ],
                          if (_selectedStatus != 'All') ...[
                            _buildActiveFilterBadge(
                              'Status: $_selectedStatus',
                              onRemove: () => setState(() => _selectedStatus = 'All'),
                            ),
                            const SizedBox(width: 6),
                          ],
                          TextButton(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () {
                              setState(() {
                                _selectedCategory = 'All';
                                _selectedSubcategory = 'All';
                                _selectedStockStatus = 'All';
                                _selectedStatus = 'All';
                              });
                            },
                            child: Text(
                              'Clear all',
                              style: GoogleFonts.outfit(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFFEF4444),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),

            // Main Catalog Section Down
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF185B3A)))
                  : (_searchQuery.trim().isNotEmpty)
                      ? _buildSearchResultsView()
                      : _buildAllProductsCatalogView(),
            ),
          ],
        ),
      );
    }

  // ALL PRODUCTS DIRECT CATALOG VIEW
  Widget _buildAllProductsCatalogView() {
    final products = _filteredProducts;

    return Column(
      children: [
        // Category Pills Filter Row
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildCategoryFilterPill('All', _products.length),
                ..._categories.map((cat) {
                  final name = (cat['name'] ?? cat['label'] ?? '').toString();
                  final count = _products.where((p) => _productBelongsToCategory(p, cat)).length;
                  return _buildCategoryFilterPill(name, count);
                }),
              ],
            ),
          ),
        ),

        // Subcategory Pills Filter Row (if a category is selected)
        if (_selectedCategory != 'All' && _activeCategorySubcategories.isNotEmpty) ...[
          Container(
            color: const Color(0xFFF8FAFC),
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _buildSubcategoryFilterPill('All'),
                  ..._activeCategorySubcategories.map((sub) {
                    final name = (sub['name'] ?? '').toString();
                    return _buildSubcategoryFilterPill(name);
                  }),
                ],
              ),
            ),
          ),
        ],

        // Quick Stats & Status Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: const Color(0xFFF8FAFC),
          child: Row(
            children: [
              Text(
                '${products.length} Products',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const Spacer(),
              _buildQuickFilterChip(
                label: 'All (${_products.length})',
                isSelected: _selectedStockStatus == 'All',
                onTap: () => setState(() => _selectedStockStatus = 'All'),
              ),
              const SizedBox(width: 6),
              _buildQuickFilterChip(
                label: 'In Stock (${_products.where((p) => (p['stock_quantity'] as int? ?? 0) > 0).length})',
                isSelected: _selectedStockStatus == 'In Stock',
                onTap: () => setState(() => _selectedStockStatus = _selectedStockStatus == 'In Stock' ? 'All' : 'In Stock'),
              ),
              const SizedBox(width: 6),
              _buildQuickFilterChip(
                label: 'Out of Stock (${_products.where((p) => (p['stock_quantity'] as int? ?? 0) <= 0).length})',
                isSelected: _selectedStockStatus == 'Out of Stock',
                onTap: () => setState(() => _selectedStockStatus = _selectedStockStatus == 'Out of Stock' ? 'All' : 'Out of Stock'),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xFFE2E8F0)),

        // Products List
        Expanded(
          child: products.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: const BoxDecoration(
                            color: Color(0xFFDCFCE7),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.inventory_2_rounded, size: 42, color: Color(0xFF15803D)),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No Products Found',
                          style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Try resetting your search or filters.',
                          style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: () => setState(() {
                            _selectedCategory = 'All';
                            _selectedSubcategory = 'All';
                            _selectedStockStatus = 'All';
                            _searchQuery = '';
                          }),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF185B3A),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.restart_alt_rounded, size: 18),
                          label: Text(
                            'Show All Products',
                            style: GoogleFonts.outfit(fontSize: 13.5, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  color: const Color(0xFF185B3A),
                  onRefresh: _fetchData,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                    itemCount: products.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final p = products[index];
                      return _buildProductCard(p);
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildCategoryFilterPill(String name, int count) {
    final isSelected = _selectedCategory == name;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () => setState(() {
          _selectedCategory = name;
          _selectedSubcategory = 'All';
        }),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF185B3A) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name,
                style: GoogleFonts.outfit(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? Colors.white : const Color(0xFF334155),
                ),
              ),
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white.withValues(alpha: 0.2) : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: GoogleFonts.outfit(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : const Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<dynamic> get _activeCategorySubcategories {
    if (_selectedCategory == 'All') return [];
    for (final cat in _categories) {
      final name = (cat['name'] ?? cat['label'] ?? '').toString();
      final id = cat['id']?.toString() ?? '';
      if (name.toLowerCase() == _selectedCategory.toLowerCase() || id == _selectedCategory) {
        return _getSubcategoriesForCategory(cat);
      }
    }
    return [];
  }

  Widget _buildSubcategoryFilterPill(String name) {
    final isSelected = _selectedSubcategory == name;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: () => setState(() => _selectedSubcategory = name),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF0F172A) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFCBD5E1),
            ),
          ),
          child: Text(
            name,
            style: GoogleFonts.outfit(
              fontSize: 11.5,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? Colors.white : const Color(0xFF475569),
            ),
          ),
        ),
      ),
    );
  }

  // SEARCH RESULTS VIEW: When user types in search bar
  Widget _buildSearchResultsView() {
    final filtered = _filteredProducts;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: const Color(0xFFF8FAFC),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${filtered.length} products found for "$_searchQuery"',
                style: GoogleFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.w700, color: const Color(0xFF475569)),
              ),
              InkWell(
                onTap: () => setState(() => _searchQuery = ''),
                child: Text(
                  'Clear',
                  style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFFEF4444)),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xFFF1F5F9)),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: const BoxDecoration(
                            color: Color(0xFFF1F5F9),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.search_off_rounded, size: 42, color: Color(0xFF94A3B8)),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No Matching Products',
                          style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Try checking for typos or clear your search query.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 20),
                        TextButton.icon(
                          onPressed: () => setState(() => _searchQuery = ''),
                          icon: const Icon(Icons.close_rounded, size: 17, color: Color(0xFF185B3A)),
                          label: Text(
                            'Clear Search',
                            style: GoogleFonts.outfit(color: const Color(0xFF185B3A), fontWeight: FontWeight.w700, fontSize: 13.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final p = filtered[index];
                    return _buildProductCard(p);
                  },
                ),
        ),
      ],
    );
  }

  // REUSABLE PRODUCT CARD
  Widget _buildProductCard(Map<String, dynamic> p) {
    final title = p['title'] ?? 'Product';
    final image = p['image_url'] ?? '';
    final unit = p['unit'] ?? '1 kg';
    final pricePaise = p['price_paise'] as int? ?? 0;
    final origPricePaise = p['original_price_paise'] as int? ?? 0;
    final priceVal = (pricePaise / 100).round();
    final origVal = (origPricePaise / 100).round();
    final stock = p['stock_quantity'] as int? ?? 0;
    final isActive = p['is_active'] != false;
    final catName = p['category_name']?.toString() ?? '';
    final subName = p['subcategory_name']?.toString() ?? '';

    int? discountPercent;
    if (origVal > priceVal && origVal > 0) {
      discountPercent = (((origVal - priceVal) / origVal) * 100).round();
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isActive ? const Color(0xFFE2E8F0) : const Color(0xFFF1F5F9),
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showProductDialog(product: p),
          borderRadius: BorderRadius.circular(18),
          child: Column(
            children: [
              // Card Top Header: Category/Subcategory & Actions
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 12, 8),
                child: Row(
                  children: [
                    // Category & Subcategory Badge
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF185B3A).withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              catName.isNotEmpty ? catName : 'General',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF185B3A),
                              ),
                            ),
                          ),
                          if (subName.isNotEmpty) ...[
                            const SizedBox(width: 4),
                            Text('›', style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF94A3B8))),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                subName,
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF475569),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Horizontal Action Bar: Active Toggle + Chevron Indicator
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Active Toggle Pill
                        GestureDetector(
                          onTap: () => _quickToggleActive(p),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                            decoration: BoxDecoration(
                              color: isActive ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isActive ? const Color(0xFF86EFAC) : const Color(0xFFCBD5E1),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isActive ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isActive ? 'Active' : 'Hidden',
                                  style: GoogleFonts.outfit(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: isActive ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),

                        // Chevron Right Indicator for Tappable Details
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: 20,
                          color: Color(0xFF94A3B8),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Card Body: Image + Product Info + Stock
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Product Image
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: SizedBox(
                            width: 76,
                            height: 76,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                SkeletonImage(imageUrl: image, fit: BoxFit.cover),
                                if (!isActive)
                                  Container(
                                    color: Colors.black.withValues(alpha: 0.40),
                                    child: Center(
                                      child: Text(
                                        'Inactive',
                                        style: GoogleFonts.outfit(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Product Details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: GoogleFonts.outfit(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: isActive ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),

                              // Price Row
                              Row(
                                children: [
                                  Text(
                                    '₹$priceVal',
                                    style: GoogleFonts.outfit(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF185B3A),
                                    ),
                                  ),
                                  if (origVal > priceVal) ...[
                                    const SizedBox(width: 6),
                                    Text(
                                      '₹$origVal',
                                      style: GoogleFonts.outfit(
                                        fontSize: 12,
                                        color: const Color(0xFF94A3B8),
                                        decoration: TextDecoration.lineThrough,
                                      ),
                                    ),
                                  ],
                                  if (discountPercent != null && discountPercent > 0) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFDCFCE7),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '$discountPercent% OFF',
                                        style: GoogleFonts.outfit(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w800,
                                          color: const Color(0xFF16A34A),
                                        ),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(width: 6),
                                  Text('• $unit', style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF64748B))),
                                ],
                              ),
                              const SizedBox(height: 6),

                              // Tag Badges
                              Wrap(
                                spacing: 5,
                                runSpacing: 4,
                                children: [
                                  if (p['is_special_deal'] == true)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(4)),
                                      child: Text('Deal', style: GoogleFonts.outfit(fontSize: 9.5, fontWeight: FontWeight.bold, color: const Color(0xFFD97706))),
                                    ),
                                  if (p['is_todays_choice'] == true)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: const Color(0xFFE0E7FF), borderRadius: BorderRadius.circular(4)),
                                      child: Text("Today's Choice", style: GoogleFonts.outfit(fontSize: 9.5, fontWeight: FontWeight.bold, color: const Color(0xFF4338CA))),
                                    ),
                                  if (p['is_popular'] == true)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: const Color(0xFFFCE7F3), borderRadius: BorderRadius.circular(4)),
                                      child: Text('Popular', style: GoogleFonts.outfit(fontSize: 9.5, fontWeight: FontWeight.bold, color: const Color(0xFFBE185D))),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Divider(height: 1, thickness: 0.8, color: Color(0xFFF1F5F9)),
                    const SizedBox(height: 8),

                    // Stock Row
                    Row(
                      children: [
                        Text(
                          'Stock',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: const Color(0xFF64748B),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),

                        // Stepper Quick Increment/Decrement
                        _buildStepperBtn(
                          icon: Icons.remove,
                          onTap: stock > 0 ? () => _quickUpdateStock(p, (stock - 1).clamp(0, 99999)) : null,
                        ),
                        GestureDetector(
                          onTap: () => _showStockPrompt(p),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Text(
                              '$stock',
                              style: GoogleFonts.outfit(
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                          ),
                        ),
                        _buildStepperBtn(
                          icon: Icons.add,
                          onTap: () => _quickUpdateStock(p, stock + 1),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Quick Filter Chip helper for Subcategory Products
  Widget _buildQuickFilterChip({required String label, required bool isSelected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF185B3A) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF185B3A) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  void _showStockPrompt(Map<String, dynamic> product) {
    final currentStock = product['stock_quantity'] as int? ?? 0;
    final ctrl = TextEditingController(text: currentStock.toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Update Stock', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 17)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(product['title'] ?? 'Product', style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF64748B))),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Available Units',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.outfit(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF185B3A),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            onPressed: () {
              final newStock = int.tryParse(ctrl.text);
              if (newStock != null) {
                Navigator.pop(ctx);
                _quickUpdateStock(product, newStock);
              }
            },
            child: Text('Update', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }



  Widget _buildActiveFilterBadge(String label, {required VoidCallback onRemove}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF185B3A).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF185B3A).withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF185B3A),
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: onRemove,
            child: const Icon(Icons.close_rounded, size: 14, color: Color(0xFF185B3A)),
          ),
        ],
      ),
    );
  }

  Widget _buildModalChip(String label, {required bool isSelected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF185B3A) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF185B3A) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 12.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF334155),
          ),
        ),
      ),
    );
  }

  void _showFilterSheet() {
    String tempCategory = _selectedCategory;
    String tempSubcategory = _selectedSubcategory;
    String tempStock = _selectedStockStatus;
    String tempStatus = _selectedStatus;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          // Safe category resolution from database categories
          final matchingCat = _categories.firstWhere(
            (c) => (c['name'] ?? c['label'] ?? '').toString().toLowerCase() == tempCategory.toLowerCase(),
            orElse: () => null,
          );
          final safeCategoryValue = matchingCat != null
              ? (matchingCat['name'] ?? matchingCat['label'] ?? '').toString()
              : 'All';

          // Compute available subcategories for tempCategory
          List<dynamic> tempSubcats = [];
          if (safeCategoryValue == 'All') {
            for (final cat in _categories) {
              if (cat['subcategories'] is List) {
                for (final s in cat['subcategories']) {
                  if (s is Map && !tempSubcats.any((existing) => (existing['name'] ?? '') == (s['name'] ?? ''))) {
                    tempSubcats.add(s);
                  }
                }
              }
            }
          } else {
            if (matchingCat != null && matchingCat['subcategories'] is List) {
              tempSubcats = List<dynamic>.from(matchingCat['subcategories']);
            }
          }

          // Safe subcategory resolution
          final matchingSub = tempSubcats.firstWhere(
            (s) => (s['name'] ?? '').toString().toLowerCase() == tempSubcategory.toLowerCase(),
            orElse: () => null,
          );
          final safeSubValue = matchingSub != null ? (matchingSub['name'] ?? '').toString() : 'All';

          // Build unique Category dropdown items from database
          final seenCatNames = <String>{'All'};
          final List<DropdownMenuItem<String>> categoryItems = [
            DropdownMenuItem<String>(
              value: 'All',
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF185B3A).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.grid_view_rounded, size: 15, color: Color(0xFF185B3A)),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'All Categories',
                    style: GoogleFonts.outfit(fontSize: 13.5, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                  ),
                ],
              ),
            ),
          ];

          for (final c in _categories) {
            final name = (c['name'] ?? c['label'] ?? '').toString().trim();
            if (name.isEmpty || seenCatNames.contains(name)) continue;
            seenCatNames.add(name);

            final colorHex = c['color_hex']?.toString() ?? c['color']?.toString();
            Color dotColor = const Color(0xFF185B3A);
            if (colorHex != null && colorHex.isNotEmpty && colorHex != 'null') {
              try {
                final hex = colorHex.replaceAll('#', '');
                dotColor = Color(int.parse('FF$hex', radix: 16));
              } catch (_) {}
            }

            categoryItems.add(
              DropdownMenuItem<String>(
                value: name,
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: dotColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black12, width: 1),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        name,
                        style: GoogleFonts.outfit(fontSize: 13.5, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          // Build unique Subcategory dropdown items from database
          final seenSubNames = <String>{'All'};
          final List<DropdownMenuItem<String>> subcategoryItems = [
            DropdownMenuItem<String>(
              value: 'All',
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF64748B).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.subdirectory_arrow_right_rounded, size: 15, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    safeCategoryValue == 'All' ? 'All Subcategories' : 'All in $safeCategoryValue',
                    style: GoogleFonts.outfit(fontSize: 13.5, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                  ),
                ],
              ),
            ),
          ];

          for (final s in tempSubcats) {
            final name = (s['name'] ?? '').toString().trim();
            if (name.isEmpty || seenSubNames.contains(name)) continue;
            seenSubNames.add(name);

            subcategoryItems.add(
              DropdownMenuItem<String>(
                value: name,
                child: Row(
                  children: [
                    const Icon(Icons.circle, size: 6, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        name,
                        style: GoogleFonts.outfit(fontSize: 13.5, fontWeight: FontWeight.w500, color: const Color(0xFF1E293B)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.85,
            ),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(28),
                topRight: Radius.circular(28),
              ),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF185B3A).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.tune_rounded, size: 18, color: Color(0xFF185B3A)),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Filter Products',
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                      TextButton(
                        onPressed: () {
                          setSheetState(() {
                            tempCategory = 'All';
                            tempSubcategory = 'All';
                            tempStock = 'All';
                            tempStatus = 'All';
                          });
                        },
                        child: Text(
                          'Reset All',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFFEF4444),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 1),
                  const SizedBox(height: 18),

                  // Category Input Field (Database backed)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Category',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF334155),
                        ),
                      ),
                      if (tempCategory != 'All')
                        InkWell(
                          onTap: () => setSheetState(() {
                            tempCategory = 'All';
                            tempSubcategory = 'All';
                          }),
                          child: Text(
                            'Reset',
                            style: GoogleFonts.outfit(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF185B3A),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      borderRadius: BorderRadius.circular(12),
                      color: const Color(0xFFF8FAFC),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        menuMaxHeight: 350,
                        value: safeCategoryValue,
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B)),
                        items: categoryItems,
                        onChanged: (val) {
                          if (val != null) {
                            setSheetState(() {
                              tempCategory = val;
                              tempSubcategory = 'All';
                            });
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Subcategory Input Field (Database backed)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Subcategory',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF334155),
                        ),
                      ),
                      if (tempSubcategory != 'All')
                        InkWell(
                          onTap: () => setSheetState(() => tempSubcategory = 'All'),
                          child: Text(
                            'Reset',
                            style: GoogleFonts.outfit(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF185B3A),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      borderRadius: BorderRadius.circular(12),
                      color: tempSubcats.isEmpty ? const Color(0xFFF1F5F9) : const Color(0xFFF8FAFC),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        menuMaxHeight: 350,
                        value: safeSubValue,
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B)),
                        items: subcategoryItems,
                        onChanged: tempSubcats.isEmpty
                            ? null
                            : (val) {
                                if (val != null) {
                                  setSheetState(() => tempSubcategory = val);
                                }
                              },
                      ),
                    ),
                  ),
                  if (tempCategory != 'All' && tempSubcats.isEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'No subcategories found in database for $tempCategory',
                      style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF94A3B8)),
                    ),
                  ],
                  const SizedBox(height: 18),

                  // Stock Availability
                  Text(
                    'Stock Availability',
                    style: GoogleFonts.outfit(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF334155),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildModalChip('All Stock', isSelected: tempStock == 'All', onTap: () => setSheetState(() => tempStock = 'All')),
                      _buildModalChip('In Stock Only', isSelected: tempStock == 'In Stock', onTap: () => setSheetState(() => tempStock = 'In Stock')),
                      _buildModalChip('Out of Stock', isSelected: tempStock == 'Out of Stock', onTap: () => setSheetState(() => tempStock = 'Out of Stock')),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Visibility Status
                  Text(
                    'Visibility Status',
                    style: GoogleFonts.outfit(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF334155),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildModalChip('All Status', isSelected: tempStatus == 'All', onTap: () => setSheetState(() => tempStatus = 'All')),
                      _buildModalChip('Active in Catalog', isSelected: tempStatus == 'Active', onTap: () => setSheetState(() => tempStatus = 'Active')),
                      _buildModalChip('Hidden / Inactive', isSelected: tempStatus == 'Hidden', onTap: () => setSheetState(() => tempStatus = 'Hidden')),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Bottom Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: () => Navigator.pop(modalCtx),
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF185B3A),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 0,
                          ),
                          onPressed: () {
                            setState(() {
                              _selectedCategory = tempCategory;
                              _selectedSubcategory = tempSubcategory;
                              _selectedStockStatus = tempStock;
                              _selectedStatus = tempStatus;
                            });
                            Navigator.pop(modalCtx);
                          },
                          child: Text(
                            'Apply Filters',
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// Retain alias for backward compatibility
typedef ManageProductsPage = ProductsPage;
