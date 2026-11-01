import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:app/features/customer/widgets/favoriteButton.dart';
import 'package:app/core/di/injection.dart';
import 'package:app/features/customer/home/providers/homeProviders.dart';
import 'package:app/features/customer/home/screens/productDetailPage.dart';
import 'package:app/core/widgets/skeletonImage.dart';
import 'package:app/features/customer/cart/providers/cartState.dart';
import 'package:app/features/customer/home/screens/filterPage.dart';

class SmoothRectTween extends RectTween {
  SmoothRectTween({super.begin, super.end});

  @override
  Rect? lerp(double t) {
    final double curvedT = Curves.easeInOutCubic.transform(t.clamp(0.0, 1.0));
    return super.lerp(curvedT);
  }
}

class SearchPage extends ConsumerStatefulWidget {
  final int initialCategoryIndex;
  final String? heroTag;

  const SearchPage({
    super.key,
    this.initialCategoryIndex = 0,
    this.heroTag,
  });

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(searchPageProvider.notifier).update(
            (s) => s.copyWith(selectedCategoryIndex: widget.initialCategoryIndex),
          );
      _fetchData();
    });
  }

  Future<void> _fetchData() async {
    ref.read(searchPageProvider.notifier).update((s) => s.copyWith(isLoading: true));
    try {
      final parsedCategories = await ref.read(productRepositoryProvider).fetchCategories();
      var selectedIdx = ref.read(searchPageProvider).selectedCategoryIndex;

      String? categoryId;
      if (parsedCategories.isNotEmpty) {
        if (selectedIdx >= parsedCategories.length) {
          selectedIdx = 0;
        }
        categoryId = parsedCategories[selectedIdx]['id'];
      }
      
      final parsedProducts = await ref.read(productRepositoryProvider).searchProducts(
        _searchController.text, 
        categoryId ?? '',
      );

      if (mounted) {
        ref.read(searchPageProvider.notifier).update(
              (s) => s.copyWith(
                selectedCategoryIndex: selectedIdx,
                categories: parsedCategories,
                products: parsedProducts.map((p) => {
                  ...p,
                  'image': p['image_url'],
                  'price': '₹${(p['price_paise'] ?? 0) ~/ 100}',
                  'original_price': p['original_price_paise'] != null ? '₹${p['original_price_paise'] ~/ 100}' : '',
                }).toList(),
                isLoading: false,
              ),
            );
      }
    } catch (e) {
      debugPrint('Error fetching data: $e');
      if (mounted) {
        ref.read(searchPageProvider.notifier).update((s) => s.copyWith(isLoading: false));
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
    final searchState = ref.watch(searchPageProvider);
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        body: SafeArea(
          child: Column(
            children: [
              _buildTopBar(),
              const SizedBox(height: 10),
              if (searchState.isLoading)
                const Expanded(
                  child: Center(
                    child: CircularProgressIndicator(color: Color(0xFF185B3A)),
                  ),
                )
              else ...[
                _buildCategoryList(searchState),
                if (searchState.categories.isNotEmpty) const SizedBox(height: 10),
                Expanded(
                  child: RefreshIndicator(
                    color: const Color(0xFF185B3A),
                    onRefresh: _fetchData,
                    child: _buildProductGrid(searchState),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      child: Row(
        children: [
          if (Navigator.canPop(context)) ...[
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 20),
              onPressed: () {
                FocusScope.of(context).unfocus();
                Navigator.pop(context);
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: widget.heroTag != null
                ? Hero(
                    tag: widget.heroTag!,
                    createRectTween: (begin, end) =>
                        SmoothRectTween(begin: begin, end: end),
                    child: Material(
                      type: MaterialType.transparency,
                      child: _buildSearchBarContainer(),
                    ),
                  )
                : _buildSearchBarContainer(),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.grey.withValues(alpha: 0.3),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withValues(alpha: 0.08),
                  spreadRadius: 1,
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: const Icon(Icons.qr_code_scanner, size: 24),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBarContainer() {
    return Container(
      height: 45,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.08),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          const Icon(Icons.search, color: Colors.grey, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (_) => _fetchData(),
              style: const TextStyle(fontSize: 13, color: Colors.black87),
              decoration: const InputDecoration(
                hintText: 'Search for fruits, vegetables, meat...',
                hintStyle: TextStyle(color: Colors.grey, fontSize: 13),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const FilterPage()),
              );
            },
            child: Icon(Icons.tune, color: Colors.grey[600], size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryList(SearchCatalogState searchState) {
    if (searchState.categories.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 105,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: searchState.categories.length,
        itemBuilder: (context, index) {
          final cat = searchState.categories[index];
          final isSelected = index == searchState.selectedCategoryIndex;
          
          return GestureDetector(
            onTap: () {
              ref.read(searchPageProvider.notifier).update(
                    (s) => s.copyWith(selectedCategoryIndex: index),
                  );
              _fetchData(); // Fetch products for the new category
            },
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Column(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: _parseColor(cat['color']?.toString() ?? '0xFFE8F5E9'),
                      borderRadius: BorderRadius.circular(16),
                      border: isSelected 
                          ? Border.all(color: const Color(0xFF42A769), width: 2)
                          : null,
                      image: DecorationImage(
                        image: NetworkImage(cat['image'] ?? ''),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    cat['label'] ?? '',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? const Color(0xFF42A769) : Colors.black87,
                    ),
                  ),
                  if (isSelected)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      width: 40,
                      height: 3,
                      decoration: BoxDecoration(
                        color: const Color(0xFF42A769),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    )
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
      final query = _searchController.text.trim();
      return Center(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
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
                    Icons.search_off_rounded,
                    size: 28,
                    color: Color(0xFF185B3A),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  query.isNotEmpty
                      ? 'No items found matching "$query"'
                      : 'No products found',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  query.isNotEmpty
                      ? 'Try checking for typos or search for a different product.'
                      : 'Products will appear here once added to the store.',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
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
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 20, top: 5),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.70,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
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
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.1),
              spreadRadius: 1,
              blurRadius: 5,
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
                      color: Color(0xFFF5F5F5),
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
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Text(
                              price,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Color(0xFF42A769),
                              ),
                            ),
                            Text(
                              unit,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          originalPrice,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Positioned(
              top: 8,
              right: 8,
              child: FavoriteButton(productId: id, isDarkBackground: true),
            ),
            Positioned(
              bottom: 12,
              right: 12,
              child: GestureDetector(
                onTap: () {
                  ref.read(cartStateProvider).addToCart(context, id);
                },
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF42A769), width: 1.5),
                  ),
                  child: const Icon(
                    Icons.add,
                    color: Color(0xFF42A769),
                    size: 18,
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
