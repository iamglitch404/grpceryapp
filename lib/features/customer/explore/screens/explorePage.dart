import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:app/core/di/injection.dart';
import 'package:app/features/customer/widgets/customerTopBar.dart';
import 'package:app/features/customer/home/screens/searchPage.dart';
import 'package:app/features/customer/explore/providers/exploreProviders.dart';

class ExplorePage extends ConsumerStatefulWidget {
  const ExplorePage({super.key});

  @override
  ConsumerState<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends ConsumerState<ExplorePage> {
  List<dynamic> get _categories => ref.read(exploreCategoriesProvider);
  final TextEditingController _searchController = TextEditingController();
  String get _searchQuery => ref.read(exploreSearchQueryProvider);

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final repo = ref.read(exploreRepositoryProvider);
      var cats = repo.getCachedCategories();
      if (cats.isEmpty) {
        try {
          cats = ref.read(productRepositoryProvider).getCachedCategories();
        } catch (_) {}
      }
      ref.read(exploreCategoriesProvider.notifier).state = cats;
      _fetchCategories();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<dynamic> get _filteredCategories {
    if (_searchQuery.trim().isEmpty) return _categories;
    final q = _searchQuery.trim().toLowerCase();
    return _categories.where((cat) {
      final name = (cat['label'] ?? cat['name'] ?? '').toString().toLowerCase();
      if (name.contains(q)) return true;
      final subs = _getSubcategoriesForCategory(name, cat['subcategories'] as List?);
      return subs.any((s) {
        final subName = (s['name'] ?? s['title'] ?? s['label'] ?? '').toString().toLowerCase();
        return subName.contains(q);
      });
    }).toList();
  }

  Future<void> _fetchCategories() async {
    try {
      final categories = await ref.read(exploreRepositoryProvider).fetchCategories();
      if (mounted && categories.isNotEmpty) {
        ref.read(exploreCategoriesProvider.notifier).state = categories;
      }
    } catch (e) {
      debugPrint('Error fetching categories: $e');
    }
  }

  IconData _getCategoryIcon(String name) {
    final n = name.toLowerCase();
    if (n.contains('fruit') || n.contains('veg')) return Icons.eco_rounded;
    if (n.contains('dairy') || n.contains('milk') || n.contains('egg') || n.contains('breakfast')) return Icons.egg_outlined;
    if (n.contains('beverage') || n.contains('drink') || n.contains('tea') || n.contains('coffee') || n.contains('juice')) return Icons.local_cafe_outlined;
    if (n.contains('bakery') || n.contains('bread') || n.contains('snack') || n.contains('cookie')) return Icons.bakery_dining_outlined;
    if (n.contains('organic') || n.contains('farm') || n.contains('honey') || n.contains('ghee')) return Icons.spa_rounded;
    return Icons.grid_view_rounded;
  }

  Color _getCategoryColor(String name, String? hex) {
    if (hex != null && hex.isNotEmpty) {
      try {
        final cleanHex = hex.replaceAll('#', '');
        return Color(int.parse('FF$cleanHex', radix: 16));
      } catch (_) {}
    }
    final n = name.toLowerCase();
    if (n.contains('fruit') || n.contains('veg')) return const Color(0xFF185B3A);
    if (n.contains('dairy') || n.contains('milk') || n.contains('egg')) return const Color(0xFFD97706);
    if (n.contains('beverage') || n.contains('drink')) return const Color(0xFF0284C7);
    if (n.contains('bakery') || n.contains('snack')) return const Color(0xFFE11D48);
    if (n.contains('organic')) return const Color(0xFF059669);
    return const Color(0xFF185B3A);
  }

  List<Map<String, dynamic>> _getSubcategoriesForCategory(String name, List? apiSubs) {
    if (apiSubs != null && apiSubs.isNotEmpty) {
      return apiSubs.map((s) => Map<String, dynamic>.from(s as Map)).toList();
    }
    return const [];
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(exploreCategoriesProvider);
    ref.watch(exploreSearchQueryProvider);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: const CustomerAppBar(),
        body: RefreshIndicator(
          color: const Color(0xFF185B3A),
          onRefresh: _fetchCategories,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 6),

                      // Search Bar
                      Container(
                        height: 46,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            const SizedBox(width: 14),
                            const Icon(Icons.search_rounded, color: Color(0xFF94A3B8), size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                onChanged: (val) => ref.read(exploreSearchQueryProvider.notifier).state = val,
                                style: GoogleFonts.outfit(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF0F172A),
                                ),
                                decoration: InputDecoration(
                                  isDense: true,
                                  border: InputBorder.none,
                                  hintText: 'Search categories or items...',
                                  hintStyle: GoogleFonts.outfit(
                                    color: const Color(0xFF94A3B8),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w400,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(vertical: 11),
                                ),
                              ),
                            ),
                            if (_searchQuery.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF94A3B8)),
                                onPressed: () {
                                  _searchController.clear();
                                  ref.read(exploreSearchQueryProvider.notifier).state = '';
                                },
                              )
                            else
                              IconButton(
                                icon: const Icon(Icons.tune_rounded, color: Color(0xFF64748B), size: 18),
                                tooltip: 'Search Products',
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => const SearchPage()),
                                  );
                                },
                              ),
                            const SizedBox(width: 4),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Section Title
                      Row(
                        children: [
                          Text(
                            'Explore Categories',
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0F172A),
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.eco, color: Color(0xFF185B3A), size: 16),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Select a category or tap a subcategory to browse',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: const Color(0xFF64748B),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),

              // Category Cards or Empty States
              if (_categories.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: const Color(0xFF185B3A).withValues(alpha: 0.08),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.category_outlined,
                              size: 28,
                              color: Color(0xFF185B3A),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'No categories found',
                            style: GoogleFonts.outfit(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Categories will appear here once added in the catalog.',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: const Color(0xFF64748B),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else if (_filteredCategories.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.search_off_rounded,
                            size: 44,
                            color: Color(0xFF94A3B8),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No categories found for "$_searchQuery"',
                            style: GoogleFonts.outfit(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF0F172A),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () {
                              _searchController.clear();
                              ref.read(exploreSearchQueryProvider.notifier).state = '';
                            },
                            child: Text(
                              'Clear search',
                              style: GoogleFonts.outfit(
                                color: const Color(0xFF185B3A),
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                  sliver: SliverList.separated(
                    itemCount: _filteredCategories.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final cat = _filteredCategories[index];
                      final label = cat['label'] ?? cat['name'] ?? 'Category';
                      final image = cat['image'] ?? cat['image_url'];
                      final colorHex = cat['color_hex'];
                      final themeColor = _getCategoryColor(label, colorHex);
                      final iconData = _getCategoryIcon(label);
                      final hasImage = image != null && image.toString().trim().isNotEmpty;
                      final subcategories = _getSubcategoriesForCategory(label, cat['subcategories'] as List?);

                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFFF1F5F9),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.025),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ── Category Header ──
                              InkWell(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => SearchPage(initialCategoryIndex: index),
                                    ),
                                  );
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Row(
                                  children: [
                                    // Category Thumbnail
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: themeColor.withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: themeColor.withValues(alpha: 0.2),
                                          width: 1.2,
                                        ),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: hasImage
                                            ? Image.network(
                                                image.toString(),
                                                width: 48,
                                                height: 48,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, _, _) => Icon(
                                                  iconData,
                                                  color: themeColor,
                                                  size: 24,
                                                ),
                                              )
                                            : Icon(
                                                iconData,
                                                color: themeColor,
                                                size: 24,
                                              ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),

                                    // Category Title & Count
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            label,
                                            style: GoogleFonts.outfit(
                                              fontSize: 14.5,
                                              fontWeight: FontWeight.w700,
                                              color: const Color(0xFF0F172A),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            subcategories.isNotEmpty
                                                ? '${subcategories.length} subcategories'
                                                : 'Tap to browse products',
                                            style: GoogleFonts.outfit(
                                              fontSize: 12,
                                              color: const Color(0xFF64748B),
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // View All Badge
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: themeColor.withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(9),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'View all',
                                            style: GoogleFonts.outfit(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: themeColor,
                                            ),
                                          ),
                                          const SizedBox(width: 3),
                                          Icon(
                                            Icons.chevron_right_rounded,
                                            size: 14,
                                            color: themeColor,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // ── Subcategories Pill Chips ──
                              if (subcategories.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 7,
                                  runSpacing: 7,
                                  children: subcategories.map((sub) {
                                    final subName = sub['name']?.toString() ?? 'Item';

                                    return InkWell(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => SearchPage(initialCategoryIndex: index),
                                          ),
                                        );
                                      },
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF8FAFC),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: const Color(0xFFE2E8F0),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              width: 5,
                                              height: 5,
                                              decoration: BoxDecoration(
                                                color: themeColor,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              subName,
                                              style: GoogleFonts.outfit(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                                color: const Color(0xFF334155),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
