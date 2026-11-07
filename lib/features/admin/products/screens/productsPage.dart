import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:app/core/config/appConfig.dart';
import 'package:app/core/di/injection.dart';
import 'package:app/core/network/httpClient.dart' as http;
import 'package:app/core/services/cacheService.dart';
import 'package:app/features/admin/products/providers/adminProductProviders.dart';
import 'package:app/features/admin/products/screens/productReviewPage.dart';
import 'package:app/features/admin/products/widgets/adminProductItemCard.dart';
import 'package:app/features/admin/products/widgets/productAddEditDialog.dart';
import 'package:app/features/admin/products/widgets/productCategoryDialogs.dart';
import 'package:app/features/admin/products/widgets/productNormalizers.dart';

class ProductsPage extends ConsumerStatefulWidget {
  final bool autoOpenAddDialog;
  const ProductsPage({super.key, this.autoOpenAddDialog = false});

  @override
  ConsumerState<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends ConsumerState<ProductsPage> {
  bool get _isLoading => ref.read(adminProductsLoadingProvider);
  List<Map<String, dynamic>> get _products => ref.read(adminProductsListProvider);
  List<dynamic> get _categories => ref.read(adminProductCategoriesProvider);
  String get _searchQuery => ref.read(adminProductsSearchQueryProvider);
  String get _selectedCategory => ref.read(adminProductsSelectedCategoryProvider);
  String get _selectedSubcategory => ref.read(adminProductsSelectedSubcategoryProvider);
  String get _selectedStockStatus => ref.read(adminProductsSelectedStockStatusProvider);
  String get _selectedStatus => ref.read(adminProductsSelectedStatusProvider);
  int get _pendingReviewCount => ref.read(adminProductsPendingReviewCountProvider);


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
    return productBelongsToCategory(p, cat);
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _fetchData();
      if (widget.autoOpenAddDialog) {
        _showAddOptionsSheet();
      }
    });
  }

  Future<void> _fetchData() async {
    ref.read(adminProductsLoadingProvider.notifier).state = true;
    await Future.wait([
      _fetchProducts(),
      _fetchCategories(),
    ]);
    if (mounted) ref.read(adminProductsLoadingProvider.notifier).state = false;
  }

  Map<String, dynamic> _normalizeProduct(dynamic raw) {
    return normalizeProduct(raw, _categories);
  }

  Future<void> _fetchProducts() async {
    List<dynamic> rawList = [];

    // 1. Try primary admin endpoint
    try {
      final res = await http.get(
        Uri.parse('${AppConfig.apiUrl}/admin/products'),
        headers: ref.read(authRepositoryProvider).authHeaders,
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
          headers: ref.read(authRepositoryProvider).authHeaders,
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
        headers: ref.read(authRepositoryProvider).authHeaders,
      );
      if (reviewRes.statusCode == 200) {
        final rData = jsonDecode(reviewRes.body);
        final list = (rData['submissions'] ?? rData['data'] ?? []) as List;
        pendingCount = list.length;
      }
    } catch (_) {}

    if (mounted) {
      ref.read(adminProductsListProvider.notifier).state =
          rawList.map((item) => _normalizeProduct(item)).toList();
      ref.read(adminProductsPendingReviewCountProvider.notifier).state = pendingCount;
    }
  }

  Future<void> _fetchCategories() async {
    // 0. Instant 0ms cache read
    final cached = CacheService.get<List>('categories');
    if (cached != null && cached.isNotEmpty && _categories.isEmpty && mounted) {
      ref.read(adminProductCategoriesProvider.notifier).state = cached;
    }

    // 1. Try admin categories endpoint (direct Supabase admin)
    try {
      final res = await http.get(
        Uri.parse('${AppConfig.apiUrl}/admin/categories'),
        headers: ref.read(authRepositoryProvider).authHeaders,
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
          ref.read(adminProductCategoriesProvider.notifier).state = list;
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
        headers: ref.read(authRepositoryProvider).authHeaders,
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (mounted) {
          ref.read(adminProductCategoriesProvider.notifier).state =
              (data is Map ? data['categories'] : null) ?? [];
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
    ref.read(adminProductsListProvider.notifier).state =
        _products.where((p) => p['id'] != id).toList();

    try {
      final res = await http.delete(
        Uri.parse('${AppConfig.apiUrl}/admin/products?id=$id'),
        headers: ref.read(authRepositoryProvider).authHeaders,
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
        if (mounted) ref.read(adminProductsListProvider.notifier).state = previousList;
        messenger.showSnackBar(
          const SnackBar(content: Text('Failed to delete product on server')),
        );
      }
    } catch (e) {
      if (mounted) ref.read(adminProductsListProvider.notifier).state = previousList;
      messenger.showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _quickUpdateStock(Map<String, dynamic> product, int newStock) async {
    final id = product['id'];
    if (id == null) return;

    final updated = List<Map<String, dynamic>>.from(_products);
    final idx = updated.indexWhere((p) => p['id'] == id);
    if (idx != -1) {
      updated[idx] = {...updated[idx], 'stock_quantity': newStock};
      ref.read(adminProductsListProvider.notifier).state = updated;
    }

    try {
      final payload = {'id': id, 'stock_quantity': newStock};
      await http.patch(
        Uri.parse('${AppConfig.apiUrl}/admin/products'),
        headers: {
          ...ref.read(authRepositoryProvider).authHeaders,
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

    final updated = List<Map<String, dynamic>>.from(_products);
    final idx = updated.indexWhere((p) => p['id'] == id);
    if (idx != -1) {
      updated[idx] = {...updated[idx], 'is_active': newStatus};
      ref.read(adminProductsListProvider.notifier).state = updated;
    }

    try {
      final payload = {'id': id, 'is_active': newStatus};
      await http.patch(
        Uri.parse('${AppConfig.apiUrl}/admin/products'),
        headers: {
          ...ref.read(authRepositoryProvider).authHeaders,
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) => ProductAddEditDialog(
        product: product,
        initialCategoryId: initialCategoryId,
        initialSubcategoryId: initialSubcategoryId,
        categories: _categories,
        onSave: () {
          Navigator.pop(modalCtx);
          _fetchProducts();
        },
        onDelete: () {
          Navigator.pop(modalCtx);
          if (isEdit) {
            _deleteProduct(product['id'], product['title']);
          }
        },
        isEdit: isEdit,
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


  void _showAddCategoryDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) => AddCategoryDialog(
        categories: _categories,
        onCategoryCreated: () {
          Navigator.pop(modalCtx);
          _fetchCategories();
        },
      ),
    );
  }

  void _showAddSubcategoryDialog({String? initialCategoryId}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) => AddSubcategoryDialog(
        categories: _categories,
        initialCategoryId: initialCategoryId,
        onSubcategoryCreated: () {
          Navigator.pop(modalCtx);
          _fetchCategories();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(adminProductsLoadingProvider);
    ref.watch(adminProductsListProvider);
    ref.watch(adminProductCategoriesProvider);
    ref.watch(adminProductsSearchQueryProvider);
    ref.watch(adminProductsSelectedCategoryProvider);
    ref.watch(adminProductsSelectedSubcategoryProvider);
    ref.watch(adminProductsSelectedStockStatusProvider);
    ref.watch(adminProductsSelectedStatusProvider);
    ref.watch(adminProductsPendingReviewCountProvider);
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
                                  onChanged: (val) => ref.read(adminProductsSearchQueryProvider.notifier).state = val,
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
                                  onTap: () => ref.read(adminProductsSearchQueryProvider.notifier).state = '',
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
                              onRemove: () {
                                ref.read(adminProductsSelectedCategoryProvider.notifier).state = 'All';
                                ref.read(adminProductsSelectedSubcategoryProvider.notifier).state = 'All';
                              },
                            ),
                            const SizedBox(width: 6),
                          ],
                          if (_selectedSubcategory != 'All') ...[
                            _buildActiveFilterBadge(
                              'Subcat: $_selectedSubcategory',
                              onRemove: () {
                                ref.read(adminProductsSelectedSubcategoryProvider.notifier).state = 'All';
                              },
                            ),
                            const SizedBox(width: 6),
                          ],
                          if (_selectedStockStatus != 'All') ...[
                            _buildActiveFilterBadge(
                              _selectedStockStatus,
                              onRemove: () => ref.read(adminProductsSelectedStockStatusProvider.notifier).state = 'All',
                            ),
                            const SizedBox(width: 6),
                          ],
                          if (_selectedStatus != 'All') ...[
                            _buildActiveFilterBadge(
                              'Status: $_selectedStatus',
                              onRemove: () => ref.read(adminProductsSelectedStatusProvider.notifier).state = 'All',
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
                              ref.read(adminProductsSelectedCategoryProvider.notifier).state = 'All';
                              ref.read(adminProductsSelectedSubcategoryProvider.notifier).state = 'All';
                              ref.read(adminProductsSelectedStockStatusProvider.notifier).state = 'All';
                              ref.read(adminProductsSelectedStatusProvider.notifier).state = 'All';
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
                label: 'All Stock (${_products.length})',
                isSelected: _selectedStockStatus == 'All',
                onTap: () => ref.read(adminProductsSelectedStockStatusProvider.notifier).state = 'All',
              ),
              const SizedBox(width: 6),
              _buildQuickFilterChip(
                label: 'In Stock (${_products.where((p) => (p['stock_quantity'] as int? ?? 0) > 0).length})',
                isSelected: _selectedStockStatus == 'In Stock',
                onTap: () => ref.read(adminProductsSelectedStockStatusProvider.notifier).state =
                    _selectedStockStatus == 'In Stock' ? 'All' : 'In Stock',
              ),
              const SizedBox(width: 6),
              _buildQuickFilterChip(
                label: 'Out of Stock (${_products.where((p) => (p['stock_quantity'] as int? ?? 0) <= 0).length})',
                isSelected: _selectedStockStatus == 'Out of Stock',
                onTap: () => ref.read(adminProductsSelectedStockStatusProvider.notifier).state =
                    _selectedStockStatus == 'Out of Stock' ? 'All' : 'Out of Stock',
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
                          onPressed: () {
                            ref.read(adminProductsSelectedCategoryProvider.notifier).state = 'All';
                            ref.read(adminProductsSelectedSubcategoryProvider.notifier).state = 'All';
                            ref.read(adminProductsSelectedStockStatusProvider.notifier).state = 'All';
                            ref.read(adminProductsSearchQueryProvider.notifier).state = '';
                          },
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
        onTap: () {
          ref.read(adminProductsSelectedCategoryProvider.notifier).state = name;
          ref.read(adminProductsSelectedSubcategoryProvider.notifier).state = 'All';
        },
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
        onTap: () => ref.read(adminProductsSelectedSubcategoryProvider.notifier).state = name,
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
                onTap: () => ref.read(adminProductsSearchQueryProvider.notifier).state = '',
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
                          onPressed: () => ref.read(adminProductsSearchQueryProvider.notifier).state = '',
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
    return AdminProductItemCard(
      product: p,
      onTap: () => _showProductDialog(product: p),
      onQuickToggleActive: () => _quickToggleActive(p),
      onStockUpdate: (newStock) => _quickUpdateStock(p, newStock),
      onStockPrompt: () => _showStockPrompt(p),
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
                            ref.read(adminProductsSelectedCategoryProvider.notifier).state = tempCategory;
                            ref.read(adminProductsSelectedSubcategoryProvider.notifier).state = tempSubcategory;
                            ref.read(adminProductsSelectedStockStatusProvider.notifier).state = tempStock;
                            ref.read(adminProductsSelectedStatusProvider.notifier).state = tempStatus;
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
