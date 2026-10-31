import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cubepod_core/cubepod_core.dart';
import 'package:app/core/config/app_config.dart';
import 'package:app/core/network/http_client.dart' as http;
import 'package:app/features/auth/data/repositories/auth_repository.dart';
import 'package:app/features/customer/cart/presentation/state/cart_state.dart';
import 'package:app/features/customer/home/presentation/pages/product_detail_page.dart';

class WishlistPage extends StatefulWidget {
  const WishlistPage({super.key});

  @override
  State<WishlistPage> createState() => _WishlistPageState();
}

class _WishlistPageState extends State<WishlistPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _favorites = [];

  @override
  void initState() {
    super.initState();
    _fetchFavorites();
  }

  Future<void> _fetchFavorites() async {
    final authRepo = CubePod.get<AuthRepository>();
    if (!authRepo.isLoggedIn) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('${AppConfig.apiUrl}/favorites'),
        headers: authRepo.authHeaders,
      );

      if (response.statusCode == 200 && mounted) {
        final data = jsonDecode(response.body);
        final list = (data['data']?['favorites'] as List<dynamic>?) ??
            (data['favorites'] as List<dynamic>?) ??
            [];

        setState(() {
          _favorites = list.map((item) => Map<String, dynamic>.from(item)).toList();
          _isLoading = false;
        });
        return;
      }
    } catch (e) {
      debugPrint('[WishlistPage] Error fetching favorites: $e');
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _removeFavorite(String productId, int index) async {
    final authRepo = CubePod.get<AuthRepository>();
    final removed = _favorites[index];

    setState(() {
      _favorites.removeAt(index);
    });

    try {
      final response = await http.delete(
        Uri.parse('${AppConfig.apiUrl}/favorites?product_id=$productId'),
        headers: authRepo.authHeaders,
      );

      if (response.statusCode != 200 && mounted) {
        // Rollback
        setState(() {
          _favorites.insert(index, removed);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to remove item'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _favorites.insert(index, removed));
      }
    }
  }

  Future<void> _addToCart(Map<String, dynamic> product) async {
    final prodId = product['id']?.toString() ?? '';
    if (prodId.isNotEmpty) {
      await CubePod.get<CartState>().addToCart(context, prodId);
    }
  }

  @override
  Widget build(BuildContext context) {
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
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A), size: 18),
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
            if (_favorites.isNotEmpty)
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
                      '${_favorites.length} items',
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
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF185B3A)))
            : _favorites.isEmpty
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
                      itemCount: _favorites.length,
                      itemBuilder: (context, index) {
                        final fav = _favorites[index];
                        final prod = (fav['product'] is Map ? fav['product'] : fav) as Map<String, dynamic>;
                        final prodId = (prod['id'] ?? fav['product_id'] ?? '').toString();
                        final title = (prod['title'] ?? prod['name'] ?? 'Product').toString();
                        final pricePaise = (prod['price_paise'] as num?)?.toInt() ?? ((prod['price'] ?? 50) * 100).toInt();
                        final priceRs = (pricePaise / 100).round();
                        final origPaise = (prod['original_price_paise'] as num?)?.toInt();
                        final origRs = origPaise != null && origPaise > pricePaise ? (origPaise / 100).round() : null;
                        final imgUrl = prod['image_url'] ?? prod['image'] ?? '';
                        final unit = prod['unit'] ?? '1 kg';

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
                                // Image & Remove Button
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
                                                errorBuilder: (context, error, stackTrace) => const Center(
                                                  child: Icon(Icons.inventory_2_outlined, color: Colors.grey, size: 36),
                                                ),
                                              )
                                            : const Center(
                                                child: Icon(Icons.inventory_2_outlined, color: Colors.grey, size: 36),
                                              ),
                                      ),
                                    ),
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: GestureDetector(
                                        onTap: () => _removeFavorite(prodId, index),
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

                                // Details
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

                                // Add to Cart Button
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                                  child: SizedBox(
                                    width: double.infinity,
                                    height: 34,
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF185B3A),
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        padding: EdgeInsets.zero,
                                      ),
                                      icon: const Icon(Icons.add_shopping_cart_rounded, size: 14, color: Colors.white),
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
