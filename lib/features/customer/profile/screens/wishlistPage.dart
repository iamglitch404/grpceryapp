import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:app/features/customer/cart/providers/cartState.dart';
import 'package:app/features/customer/favorites/providers/favoritesState.dart';
import 'package:app/features/customer/home/screens/productDetailPage.dart';

class WishlistPage extends ConsumerStatefulWidget {
  const WishlistPage({super.key});

  @override
  ConsumerState<WishlistPage> createState() => _WishlistPageState();
}

class _WishlistPageState extends ConsumerState<WishlistPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(favoritesStateProvider).fetchFavorites();
      }
    });
  }

  Future<void> _fetchFavorites() async {
    await ref.read(favoritesStateProvider).fetchFavorites();
  }

  Future<void> _removeFavorite(String productId) async {
    final success = await ref.read(favoritesStateProvider).removeFavorite(productId);
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to remove item'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _addToCart(Map<String, dynamic> product) async {
    final prodId = product['id']?.toString() ?? '';
    if (prodId.isNotEmpty) {
      await ref.read(cartStateProvider).addToCart(context, prodId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final favState = ref.watch(favoritesStateProvider);
    final rawFavorites = favState.favorites;
    final isLoading = favState.isLoading;
    final favorites = rawFavorites.where((f) {
      final prod = f['product'] is Map ? f['product'] : f;
      return prod is Map && (prod['title'] != null || prod['name'] != null);
    }).toList();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
            backgroundColor: const Color(0xFFF8FAFC),
            appBar: AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Color(0xFF0F172A),
                  size: 18,
                ),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text(
                'My Wishlist',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0F172A),
                ),
              ),
              centerTitle: true,
              actions: [
                if (favorites.isNotEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5EE),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${favorites.length} items',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF185B3A),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            body: isLoading && favorites.isEmpty
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF185B3A)))
                : favorites.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        color: const Color(0xFF185B3A),
                        onRefresh: _fetchFavorites,
                        child: GridView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 14,
                            childAspectRatio: 0.68,
                          ),
                          itemCount: favorites.length,
                          itemBuilder: (context, index) {
                            final fav = favorites[index];
                            final prod = Map<String, dynamic>.from(
                              (fav['product'] is Map ? fav['product'] : fav) as Map,
                            );
                            final prodId = (prod['id'] ?? fav['product_id'] ?? '').toString();
                            final title = (prod['title'] ?? prod['name'] ?? 'Product').toString();
                            final pricePaise = (prod['price_paise'] as num?)?.toInt() ??
                                ((prod['price'] ?? 50) * 100).toInt();
                            final priceRs = (pricePaise / 100).round();
                            final origPaise = (prod['original_price_paise'] as num?)?.toInt();
                            final origRs = origPaise != null && origPaise > pricePaise
                                ? (origPaise / 100).round()
                                : null;
                            final imgUrl = (prod['image_url'] ?? prod['image'] ?? '').toString();
                            final unit = (prod['unit'] ?? '1 kg').toString();

                            return GestureDetector(
                              onTap: () {
                                if (prodId.isNotEmpty) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ProductDetailPage(
                                        id: prodId,
                                        title: title,
                                        price: 'Rs $priceRs',
                                        unit: unit,
                                        image: imgUrl,
                                        originalPrice: origRs != null ? 'Rs $origRs' : '',
                                      ),
                                    ),
                                  );
                                }
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.02),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Stack(
                                      children: [
                                        ClipRRect(
                                          borderRadius: const BorderRadius.only(
                                            topLeft: Radius.circular(16),
                                            topRight: Radius.circular(16),
                                          ),
                                          child: Container(
                                            height: 120,
                                            width: double.infinity,
                                            color: const Color(0xFFF1F5F9),
                                            child: imgUrl.isNotEmpty
                                                ? Image.network(
                                                    imgUrl,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (context, error, stackTrace) =>
                                                        const Center(
                                                      child: Icon(
                                                        Icons.inventory_2_outlined,
                                                        color: Colors.grey,
                                                        size: 36,
                                                      ),
                                                    ),
                                                  )
                                                : const Center(
                                                    child: Icon(
                                                      Icons.inventory_2_outlined,
                                                      color: Colors.grey,
                                                      size: 36,
                                                    ),
                                                  ),
                                          ),
                                        ),
                                        Positioned(
                                          top: 8,
                                          right: 8,
                                          child: GestureDetector(
                                            onTap: () => _removeFavorite(prodId),
                                            child: Container(
                                              padding: const EdgeInsets.all(6),
                                              decoration: BoxDecoration(
                                                color: Colors.white.withValues(alpha: 0.9),
                                                shape: BoxShape.circle,
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black.withValues(alpha: 0.1),
                                                    blurRadius: 4,
                                                  ),
                                                ],
                                              ),
                                              child: const Icon(
                                                Icons.favorite_rounded,
                                                color: Color(0xFFE11D48),
                                                size: 16,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(10),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.outfit(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.bold,
                                              color: const Color(0xFF0F172A),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            unit,
                                            style: GoogleFonts.outfit(
                                              fontSize: 11,
                                              color: const Color(0xFF64748B),
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              Text(
                                                'Rs $priceRs',
                                                style: GoogleFonts.outfit(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w800,
                                                  color: const Color(0xFF185B3A),
                                                ),
                                              ),
                                              if (origRs != null) ...[
                                                const SizedBox(width: 6),
                                                Text(
                                                  'Rs $origRs',
                                                  style: GoogleFonts.outfit(
                                                    fontSize: 11,
                                                    color: const Color(0xFF94A3B8),
                                                    decoration: TextDecoration.lineThrough,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Spacer(),
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                                      child: SizedBox(
                                        width: double.infinity,
                                        height: 34,
                                        child: ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF185B3A),
                                            elevation: 0,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            padding: EdgeInsets.zero,
                                          ),
                                          icon: const Icon(
                                            Icons.add_shopping_cart_rounded,
                                            size: 14,
                                            color: Colors.white,
                                          ),
                                          label: Text(
                                            'Add',
                                            style: GoogleFonts.outfit(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                          onPressed: () => _addToCart(prod),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.favorite_border_rounded,
                size: 56,
                color: Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Your Wishlist is Empty',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Save your favorite grocery items and seasonal fruits to access them quickly anytime.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: const Color(0xFF64748B),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF185B3A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                elevation: 0,
              ),
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Explore Store',
                style: GoogleFonts.outfit(fontSize: 13.5, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
