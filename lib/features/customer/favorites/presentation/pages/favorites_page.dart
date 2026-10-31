import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cubepod_core/cubepod_core.dart';
import 'package:app/core/config/app_config.dart';
import 'package:app/features/auth/data/repositories/auth_repository.dart';
import 'package:app/features/customer/home/presentation/pages/product_detail_page.dart';
import 'package:app/features/customer/presentation/widgets/favorite_button.dart';
import 'package:app/core/widgets/skeleton_image.dart';
import 'package:app/features/customer/cart/presentation/state/cart_state.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  List<dynamic> _favorites = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchFavorites();
  }

  Future<void> _fetchFavorites() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final headers = CubePod.get<AuthRepository>().authHeaders;
      final response = await http.get(
        Uri.parse('${AppConfig.apiUrl}/favorites'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() {
            _favorites = data['data']['favorites'] ?? [];
            _isLoading = false;
          });
        } else {
          throw Exception('Failed to load favorites');
        }
      } else {
        throw Exception('Failed to load favorites');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF9),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAF9),
        elevation: 0,
        title: const Text(
          'My Favorites',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF42A769)),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(
              'Could not load favorites',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 16),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchFavorites,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF42A769),
                foregroundColor: Colors.white,
              ),
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    if (_favorites.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite_border, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text(
              'No Favorites Yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E2022),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the heart icon on products to save them here.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchFavorites,
      color: const Color(0xFF42A769),
      child: GridView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        physics: const AlwaysScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 0.72,
        ),
        itemCount: _favorites.length,
        itemBuilder: (context, index) {
          final favoriteItem = _favorites[index];
          final product = favoriteItem['product'];
          
          if (product == null) return const SizedBox();

          return _buildProductCard(product);
        },
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> item) {
    final title = item['title']?.toString() ?? '';
    final imageUrl = item['image_url']?.toString() ?? '';
    final id = item['id']?.toString() ?? '';
    final pricePaise = item['price_paise'] as int? ?? 0;
    final originalPricePaise = item['original_price_paise'] as int? ?? pricePaise;
    final unit = item['unit']?.toString() ?? '';

    final price = 'Rs. ${(pricePaise / 100).toStringAsFixed(2)}';
    final originalPrice = 'Rs. ${(originalPricePaise / 100).toStringAsFixed(2)}';
    final discount = originalPricePaise > pricePaise
        ? ((originalPricePaise - pricePaise) / originalPricePaise * 100).round()
        : 0;

    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailPage(
              id: id,
              image: imageUrl,
              title: title,
              price: price,
              unit: unit,
              originalPrice: originalPrice,
            ),
          ),
        );
        _fetchFavorites(); // Refresh when coming back in case they unfavorited
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    child: Stack(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          height: double.infinity,
                          child: imageUrl.isNotEmpty
                              ? SkeletonImage(imageUrl: imageUrl)
                              : Container(color: Colors.grey.shade100),
                        ),
                        if (discount > 0)
                          Positioned(
                            top: 8,
                            left: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE57373),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '-$discount%',
                                style: const TextStyle(
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
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Color(0xFF2D2D2D),
                          ),
                        ),
                        const Spacer(),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              price,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Color(0xFF42A769),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              unit,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                        if (discount > 0) ...[
                          const SizedBox(height: 2),
                          Text(
                            originalPrice,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        ] else
                          const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Positioned(
              top: 8,
              right: 8,
              child: FavoriteButton(productId: id, padding: 4, isDarkBackground: true),
            ),
            Positioned(
              bottom: 12,
              right: 12,
              child: GestureDetector(
                onTap: () {
                  CubePod.get<CartState>().addToCart(context, id);
                },
                child: Container(
                  padding: const EdgeInsets.all(4),
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
