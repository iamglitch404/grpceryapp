import 'package:flutter/material.dart';
import 'package:app/core/network/http_client.dart' as http;
import 'package:app/core/config/app_config.dart';
import 'package:cubepod_core/cubepod_core.dart';
import 'dart:convert';
import 'package:app/features/auth/data/repositories/auth_repository.dart';
import 'package:app/features/auth/presentation/pages/auth_page.dart';

class ProductReviewsPage extends StatefulWidget {
  final dynamic productId;
  final String productName;

  const ProductReviewsPage({super.key, required this.productName, this.productId});

  @override
  State<ProductReviewsPage> createState() => _ProductReviewsPageState();
}

class _ProductReviewsPageState extends State<ProductReviewsPage> {
  final TextEditingController _reviewController = TextEditingController();
  int _selectedRating = 5;

  List<Map<String, dynamic>> _reviews = [];
  bool _isLoadingReviews = false;
  List<dynamic> _similarProducts = [];
  List<dynamic> _youMayAlsoLike = [];

  @override
  void initState() {
    super.initState();
    _fetchReviews();
    _fetchRelatedProducts();
  }


  Future<void> _fetchRelatedProducts() async {
    try {
      final simRes = await http.get(Uri.parse('${AppConfig.apiUrl}/products?limit=5&offset=5'));
      final likeRes = await http.get(Uri.parse('${AppConfig.apiUrl}/products?limit=5'));
      
      if (simRes.statusCode == 200 && likeRes.statusCode == 200) {
        if (mounted) {
          setState(() {
            _similarProducts = jsonDecode(simRes.body)['data']['products'] ?? [];
            _youMayAlsoLike = jsonDecode(likeRes.body)['data']['products'] ?? [];
            if (widget.productId != null) {
              _similarProducts.removeWhere((p) => p['id'] == widget.productId);
              _youMayAlsoLike.removeWhere((p) => p['id'] == widget.productId);
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching related products: $e');
    }
  }
  Future<void> _fetchReviews() async {
    if (widget.productId == null) return;
    setState(() => _isLoadingReviews = true);
    try {
      final response = await http.get(Uri.parse('${AppConfig.apiUrl}/reviews?product_id=${widget.productId}'));
      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _reviews = List<Map<String, dynamic>>.from(jsonDecode(response.body));
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching reviews: $e');
    } finally {
      if (mounted) setState(() => _isLoadingReviews = false);
    }
  }



  Future<void> _submitReview() async {
    if (_reviewController.text.trim().isEmpty) return;
    if (!CubePod.get<AuthRepository>().isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to review'), backgroundColor: Colors.red),
      );
      Navigator.push(context, MaterialPageRoute(builder: (context) => const AuthPage()));
      return;
    }

    final experience = _reviewController.text.trim();
    final rating = _selectedRating;

    FocusScope.of(context).unfocus();

    try {
      final response = await http.post(
        Uri.parse('${AppConfig.apiUrl}/reviews'),
        headers: CubePod.get<AuthRepository>().authHeaders,
        body: jsonEncode({
          'product_id': widget.productId,
          'comment': experience,
          'rating': rating,
        }),
      );

      if (response.statusCode == 201 && mounted) {
        final data = jsonDecode(response.body);
        final newRev = data['data'];
        
        setState(() {
          _reviews.insert(0, {
            'id': newRev['id'],
            'user_id': CubePod.get<AuthRepository>().currentUser!['id'],
            'comment': experience,
            'rating': rating,
            'users': {
               'name': CubePod.get<AuthRepository>().currentUser?['name'] ?? 'You',
               'avatar_url': CubePod.get<AuthRepository>().currentUser?['avatar_url'] ?? 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&w=100&q=80',
            },
            'created_at': DateTime.now().toIso8601String(),
          });
          _reviewController.clear();
          _selectedRating = 5;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Review submitted successfully!'), backgroundColor: Color(0xFF42A769)),
        );
      }
    } catch (e) {
      debugPrint('Could not submit review. Please try again.');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not submit review. Please try again.'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Reviews for ${widget.productName}',
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Column(
              children: [
                Expanded(
                  child: _isLoadingReviews 
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF42A769)))
                    : _reviews.isEmpty
                        ? const Center(child: Text('No reviews yet. Be the first to review!', style: TextStyle(color: Colors.grey)))
                        : ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(20),
                            itemCount: _reviews.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 16),
                            itemBuilder: (context, index) {
                              final review = _reviews[index];
                              final user = review['users'] ?? {};
                              final name = user['name'] ?? 'User';
                              final image = user['avatar_url'] != null && user['avatar_url'].toString().isNotEmpty ? user['avatar_url'] : 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&w=100&q=80';
                              final rating = review['rating'] ?? 5;
                              final comment = review['experience'] ?? '';
                              final time = review['created_at'] != null ? review['created_at'].toString().substring(0, 10) : 'Just now';

                              return _buildReviewItem(
                                name: name,
                                image: image,
                                rating: rating,
                                time: time,
                                comment: comment,
                              );
                            },
                          ),
                ),
                _buildWriteReviewSection(),
                if (_similarProducts.isNotEmpty) ...[
                  const Divider(color: Color(0xFFEEEEEE), thickness: 1, height: 32),
                  _buildHorizontalProductList('Similar to ${widget.productName}', _similarProducts),
                ],
                if (_youMayAlsoLike.isNotEmpty) ...[
                  const SizedBox(height: 32),
                  _buildHorizontalProductList('You may also like', _youMayAlsoLike),
                  const SizedBox(height: 32),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewItem({
    required String name,
    required String image,
    required int rating,
    required String time,
    required String comment,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundImage: NetworkImage(image),
                radius: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: List.generate(5, (index) {
                        return Icon(
                          index < rating ? Icons.star : Icons.star_border,
                          color: Colors.orange,
                          size: 14,
                        );
                      }),
                    ),
                  ],
                ),
              ),
              Text(
                time,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            comment,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.black87,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWriteReviewSection() {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, -4),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Write a Review',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(5, (index) {
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedRating = index + 1;
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Icon(
                    index < _selectedRating ? Icons.star : Icons.star_border,
                    color: Colors.orange,
                    size: 24,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _reviewController,
                  maxLines: 3,
                  minLines: 1,
                  decoration: InputDecoration(
                    hintText: 'Share your experience...',
                    hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                    filled: true,
                    fillColor: const Color(0xFFF5F5F5),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              InkWell(
                onTap: _submitReview,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: Color(0xFF42A769),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.send,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  Widget _buildHorizontalProductList(String sectionTitle, List<dynamic> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            sectionTitle,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 290,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            itemBuilder: (context, index) {
              return _buildProductCard(items[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildProductCard(dynamic product) {
    final image = product['image'] as String? ?? '';
    final title = product['title'] as String? ?? 'No Title';
    
    int priceVal = 0;
    if (product['price'] != null) {
      if (product['price'] is int) {
        priceVal = product['price'];
      } else {
        priceVal = int.tryParse(product['price'].toString().replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      }
    }
    final price = '₹${priceVal.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}';
    
    int origPriceVal = 0;
    if (product['original_price'] != null) {
      if (product['original_price'] is int) {
        origPriceVal = product['original_price'];
      } else {
        origPriceVal = int.tryParse(product['original_price'].toString().replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      }
    }
    final originalPrice = origPriceVal > 0 ? '₹${origPriceVal.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}' : '';
    final unit = product['unit'] as String? ?? '1 kg';

    return Container(
      width: 150,
      margin: const EdgeInsets.only(right: 15, bottom: 10, top: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 100,
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Color(0xFFF9F9F9),
                  borderRadius: BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
                  child: Image.network(image, fit: BoxFit.cover, errorBuilder: (_,_,_) => const Icon(Icons.image_not_supported)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.star, color: Colors.orange, size: 12),
                        const SizedBox(width: 2),
                        Text(product['avg_rating']?.toString() ?? '0.0', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black54)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(unit, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(price, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E523A))),
                        const SizedBox(width: 4),
                        if (originalPrice.isNotEmpty)
                          Text(originalPrice, style: const TextStyle(fontSize: 11, color: Colors.grey, decoration: TextDecoration.lineThrough)),
                      ],
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(color: const Color(0xFF3BA772), borderRadius: BorderRadius.circular(20)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.shopping_cart_outlined, color: Colors.white, size: 14),
                    SizedBox(width: 4),
                    Text('Add to cart', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
