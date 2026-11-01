import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:app/features/customer/widgets/favoriteButton.dart';
import 'package:app/core/di/injection.dart';
import 'package:app/features/customer/home/providers/homeProviders.dart';
import 'package:app/features/customer/home/screens/productDetailPage.dart';
import 'package:app/core/widgets/skeletonImage.dart';
import 'package:app/features/customer/cart/providers/cartState.dart';

class HomeSearchComponent extends ConsumerStatefulWidget {
  final TextEditingController searchController;
  final int initialCategoryIndex;

  const HomeSearchComponent({
    super.key,
    required this.searchController,
    this.initialCategoryIndex = 0,
  });

  @override
  ConsumerState<HomeSearchComponent> createState() => HomeSearchComponentState();
}

class HomeSearchComponentState extends ConsumerState<HomeSearchComponent> {
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    widget.searchController.addListener(_onSearchChanged);
    Future.microtask(() {
      ref.read(homeSearchComponentProvider.notifier).update(
            (s) => s.copyWith(selectedCategoryIndex: widget.initialCategoryIndex),
          );
      _fetchData();
    });
  }

  @override
  void didUpdateWidget(covariant HomeSearchComponent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchController != widget.searchController) {
      oldWidget.searchController.removeListener(_onSearchChanged);
      widget.searchController.addListener(_onSearchChanged);
    }
    if (oldWidget.initialCategoryIndex != widget.initialCategoryIndex) {
      Future.microtask(() {
        ref.read(homeSearchComponentProvider.notifier).update(
              (s) => s.copyWith(selectedCategoryIndex: widget.initialCategoryIndex),
            );
        _fetchData();
      });
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    widget.searchController.removeListener(_onSearchChanged);
    super.dispose();
  }

  void _onSearchChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        _fetchData();
      }
    });
  }

  void setCategoryIndex(int index) {
    if (mounted) {
      ref.read(homeSearchComponentProvider.notifier).update(
            (s) => s.copyWith(selectedCategoryIndex: index),
          );
      _fetchData();
    }
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    ref.read(homeSearchComponentProvider.notifier).update((s) => s.copyWith(isLoading: true));
    try {
      final parsedCategories =
          await ref.read(productRepositoryProvider).fetchCategories();
      var selectedIdx = ref.read(homeSearchComponentProvider).selectedCategoryIndex;

      String? categoryId;
      if (parsedCategories.isNotEmpty) {
        if (selectedIdx >= parsedCategories.length) {
          selectedIdx = 0;
        }
        categoryId = parsedCategories[selectedIdx]['id'];
      }

      final parsedProducts =
          await ref.read(productRepositoryProvider).searchProducts(
        widget.searchController.text.trim(),
        categoryId ?? '',
      );

      if (mounted) {
        ref.read(homeSearchComponentProvider.notifier).update(
              (s) => s.copyWith(
                selectedCategoryIndex: selectedIdx,
                categories: parsedCategories,
                products: parsedProducts.map((p) => {
                      ...p,
                      'image': p['image_url'],
                      'price': '₹${(p['price_paise'] ?? 0) ~/ 100}',
                      'original_price': p['original_price_paise'] != null
                          ? '₹${p['original_price_paise'] ~/ 100}'
                          : '',
                    }).toList(),
                isLoading: false,
              ),
            );
      }
    } catch (e) {
      debugPrint('Error fetching search data: $e');
      if (mounted) {
        ref.read(homeSearchComponentProvider.notifier).update((s) => s.copyWith(isLoading: false));
      }
    }
  }

  Color _parseColor(String colorString) {
    try {
      if (colorString.startsWith('0x') || colorString.startsWith('0X')) {
        return Color(int.parse(colorString));
      }
      return const Color(0xFFE8F5E9);
    } catch (e) {
      return const Color(0xFFE8F5E9);
    }
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(homeSearchComponentProvider);
    return Column(
      children: [
        const SizedBox(height: 6),
        _buildCategoryList(searchState),
        if (searchState.categories.isNotEmpty) const SizedBox(height: 8),
        Expanded(
          child: searchState.isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF185B3A),
                  ),
                )
              : RefreshIndicator(
                  color: const Color(0xFF185B3A),
                  onRefresh: _fetchData,
                  child: _buildProductGrid(searchState),
                ),
        ),
      ],
    );
  }

  Widget _buildCategoryList(SearchCatalogState searchState) {
    if (searchState.categories.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 98,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: searchState.categories.length,
        itemBuilder: (context, index) {
          final cat = searchState.categories[index];
          final isSelected = index == searchState.selectedCategoryIndex;

          return GestureDetector(
            onTap: () {
              ref.read(homeSearchComponentProvider.notifier).update(
                    (s) => s.copyWith(selectedCategoryIndex: index),
                  );
              _fetchData();
            },
            child: Padding(
              padding: const EdgeInsets.only(right: 14.0),
              child: Column(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: _parseColor(
                          cat['color']?.toString() ?? '0xFFE8F5E9'),
                      borderRadius: BorderRadius.circular(16),
                      border: isSelected
                          ? Border.all(
                              color: const Color(0xFF185B3A),
                              width: 2.2,
                            )
                          : Border.all(
                              color: Colors.grey.withValues(alpha: 0.15),
                              width: 1,
                            ),
                      image: cat['image'] != null && cat['image'] != ''
                          ? DecorationImage(
                              image: NetworkImage(cat['image']),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    cat['label'] ?? '',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 11.5,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected
                          ? const Color(0xFF185B3A)
                          : const Color(0xFF334155),
                    ),
                  ),
                  if (isSelected)
                    Container(
                      margin: const EdgeInsets.only(top: 3),
                      width: 28,
                      height: 2.5,
                      decoration: BoxDecoration(
                        color: const Color(0xFF185B3A),
                        borderRadius: BorderRadius.circular(10),
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

  Widget _buildProductGrid(SearchCatalogState searchState) {
    if (searchState.products.isEmpty) {
      final query = widget.searchController.text.trim();
      return Center(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: const Color(0xFF185B3A).withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.search_off_rounded,
                    size: 26,
                    color: Color(0xFF185B3A),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  query.isNotEmpty
                      ? 'No items found matching "$query"'
                      : 'No products found',
                  style: GoogleFonts.outfit(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  query.isNotEmpty
                      ? 'Try checking for typos or searching for a different product.'
                      : 'Products will appear here once added to the store.',
                  style: GoogleFonts.outfit(
                    fontSize: 12.5,
                    color: const Color(0xFF64748B),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 30, top: 4),
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.70,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
      ),
      itemCount: searchState.products.length,
      itemBuilder: (context, index) {
        final product = searchState.products[index];
        return _buildGridProductCard(
          id: product['id'],
          image: product['image'] ?? '',
          title: product['title'] ?? '',
          price: product['price'] ?? '',
          unit: product['unit'] ?? '',
          originalPrice: product['original_price'] ?? '',
        );
      },
    );
  }

  Widget _buildGridProductCard({
    required dynamic id,
    required String image,
    required String title,
    required String price,
    required String unit,
    required String originalPrice,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailPage(
              id: id,
              image: image,
              title: title,
              price: price,
              unit: unit,
              originalPrice: originalPrice,
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.grey.withValues(alpha: 0.15),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              spreadRadius: 1,
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 5,
                  child: Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                      child: SkeletonImage(
                        imageUrl: image,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: const Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              price,
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                fontSize: 13.5,
                                color: const Color(0xFF185B3A),
                              ),
                            ),
                            if (unit.isNotEmpty) ...[
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  unit,
                                  style: GoogleFonts.outfit(
                                    fontSize: 10.5,
                                    color: const Color(0xFF64748B),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (originalPrice.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            originalPrice,
                            style: GoogleFonts.outfit(
                              fontSize: 10.5,
                              color: const Color(0xFF94A3B8),
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Positioned(
              top: 6,
              right: 6,
              child: FavoriteButton(productId: id, isDarkBackground: true),
            ),
            Positioned(
              bottom: 8,
              right: 8,
              child: GestureDetector(
                onTap: () {
                  ref.read(cartStateProvider).addToCart(context, id);
                },
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF185B3A),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF185B3A).withValues(alpha: 0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.add,
                    color: Colors.white,
                    size: 17,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
