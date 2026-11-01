import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/core/network/httpClient.dart' as http;

import 'package:app/core/widgets/skeletonImage.dart';
import 'package:app/features/customer/home/widgets/shareProductBottomSheet.dart';
import 'package:app/core/di/injection.dart';
import 'package:app/features/customer/home/providers/homeProviders.dart';
import 'package:app/features/auth/screens/authPage.dart';
import 'package:app/features/customer/cart/providers/cartState.dart';
import 'package:app/features/customer/cart/screens/cartPage.dart';
import 'package:app/core/config/appConfig.dart';
import 'dart:convert';
import 'productReviewsPage.dart';


class ProductDetailPage extends ConsumerStatefulWidget {
  final dynamic id;
  final String image;
  final String title;
  final String price;
  final String unit;
  final String originalPrice;
  final String? description;
  final dynamic rating;

  const ProductDetailPage({
    super.key,
    this.id,
    required this.image,
    required this.title,
    required this.price,
    required this.unit,
    required this.originalPrice,
    this.description,
    this.rating,
  });

  @override
  ConsumerState<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends ConsumerState<ProductDetailPage> {
  final TextEditingController _reviewController = TextEditingController();

  String get _providerKey => '${widget.id ?? ''}_${widget.title}';

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      _checkFavorite();
      _fetchReviews();
      _fetchRelatedProducts();
    });
  }

  Future<void> _fetchRelatedProducts() async {
    try {
      final simRes = await http.get(Uri.parse('${AppConfig.apiUrl}/products?limit=5&offset=5'));
      final likeRes = await http.get(Uri.parse('${AppConfig.apiUrl}/products?limit=5'));
      
      if (simRes.statusCode == 200 && likeRes.statusCode == 200) {
        if (mounted) {
          final simList = List<dynamic>.from(jsonDecode(simRes.body)['data']['products'] ?? []);
          final likeList = List<dynamic>.from(jsonDecode(likeRes.body)['data']['products'] ?? []);
          simList.removeWhere((p) => p['id'] == widget.id);
          likeList.removeWhere((p) => p['id'] == widget.id);
          ref.read(productDetailProvider(_providerKey).notifier).update(
                (s) => s.copyWith(
                  similarProducts: simList,
                  youMayAlsoLike: likeList,
                ),
              );
        }
      }
    } catch (e) {
      debugPrint('Error fetching related products: $e');
    }
  }

  Future<void> _fetchReviews() async {
    if (widget.id == null) return;
    ref.read(productDetailProvider(_providerKey).notifier).update(
          (s) => s.copyWith(isLoadingReviews: true),
        );
    try {
      final response = await http.get(Uri.parse('${AppConfig.apiUrl}/reviews?product_id=${widget.id}'));
      if (response.statusCode == 200) {
        if (mounted) {
          ref.read(productDetailProvider(_providerKey).notifier).update(
                (s) => s.copyWith(
                  reviews: List<Map<String, dynamic>>.from(jsonDecode(response.body)),
                ),
              );
        }
      }
    } catch (e) {
      debugPrint('Error fetching reviews: $e');
    } finally {
      if (mounted) {
        ref.read(productDetailProvider(_providerKey).notifier).update(
              (s) => s.copyWith(isLoadingReviews: false),
            );
      }
    }
  }

  Future<void> _checkFavorite() async {
    if (!ref.read(authRepositoryProvider).isLoggedIn || widget.id == null) return;
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.apiUrl}/favorites'),
        headers: ref.read(authRepositoryProvider).authHeaders,
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final favorites = data['data']['favorites'] as List;
          final exists = favorites.any((f) => f['product_id'] == widget.id);
          if (mounted && exists) {
            ref.read(productDetailProvider(_providerKey).notifier).update(
                  (s) => s.copyWith(isFavorite: true),
                );
          }
        }
      }
    } catch (e) {
      debugPrint('Could not fetch favorites. Please try again.');
    }
  }

  Future<void> _deleteReview(String reviewId, int index) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Review'),
        content: const Text('Are you sure you want to delete this review?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final response = await http.delete(
        Uri.parse('${AppConfig.apiUrl}/reviews?review_id=$reviewId'),
        headers: ref.read(authRepositoryProvider).authHeaders,
      );
      if (response.statusCode == 200 && mounted) {
        ref.read(productDetailProvider(_providerKey).notifier).update((s) {
          final updated = List<Map<String, dynamic>>.from(s.reviews);
          updated.removeAt(index);
          return s.copyWith(reviews: updated);
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Review deleted'), backgroundColor: Colors.green));
      } else {
        throw Exception('Failed to delete review: ${response.body}');
      }
    } catch (e) {
      debugPrint('Error deleting review: $e');
    }
  }

  Future<void> _editReviewDialog(Map<String, dynamic> review, int index) async {
    final TextEditingController editController = TextEditingController(text: review['comment'] ?? '');
    int editRating = review['rating'] ?? 5;
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Edit Review'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (starIndex) {
                      return IconButton(
                        icon: Icon(Icons.star_rounded, color: starIndex < editRating ? Colors.orange : Colors.grey.shade300, size: 32),
                        onPressed: () => setDialogState(() => editRating = starIndex + 1),
                      );
                    }),
                  ),
                  TextField(controller: editController, maxLines: 3, decoration: const InputDecoration(hintText: 'Share your experience...')),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                TextButton(
                  onPressed: () async {
                    if (editController.text.trim().isEmpty) return;
                    Navigator.pop(context);
                    try {
                      final response = await http.patch(
                        Uri.parse('${AppConfig.apiUrl}/reviews'),
                        headers: ref.read(authRepositoryProvider).authHeaders,
                        body: jsonEncode({
                          'review_id': review['id'],
                          'comment': editController.text.trim(),
                          'rating': editRating,
                        }),
                      );
                      
                      if (response.statusCode == 200 && mounted) {
                        ref.read(productDetailProvider(_providerKey).notifier).update((s) {
                          final updated = List<Map<String, dynamic>>.from(s.reviews);
                          updated[index] = {
                            ...updated[index],
                            'comment': editController.text.trim(),
                            'rating': editRating,
                          };
                          return s.copyWith(reviews: updated);
                        });
                      } else {
                        throw Exception('Failed to update review: ${response.body}');
                      }
                    } catch (e) {
                      debugPrint('Error updating review: $e');
                    }
                  },
                  child: const Text('Update'),
                ),
              ],
            );
          }
        );
      }
    );
  }

  Future<void> _submitReview() async {
    if (_reviewController.text.trim().isEmpty) return;
    if (!ref.read(authRepositoryProvider).isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to review'), backgroundColor: Colors.red),
      );
      Navigator.push(context, MaterialPageRoute(builder: (context) => const AuthPage()));
      return;
    }
    
    final experience = _reviewController.text.trim();
    final rating = ref.read(productDetailProvider(_providerKey)).selectedRating;

    FocusScope.of(context).unfocus();

    try {
      final response = await http.post(
        Uri.parse('${AppConfig.apiUrl}/reviews'),
        headers: ref.read(authRepositoryProvider).authHeaders,
        body: jsonEncode({
          'product_id': widget.id,
          'comment': experience,
          'rating': rating,
        }),
      );

      if (response.statusCode == 201 && mounted) {
        final data = jsonDecode(response.body);
        final newRev = data['data'];
        
        ref.read(productDetailProvider(_providerKey).notifier).update((s) {
          final updated = List<Map<String, dynamic>>.from(s.reviews);
          updated.insert(0, {
            'id': newRev['id'],
            'user_id': ref.read(authRepositoryProvider).currentUser!['id'],
            'comment': experience,
            'rating': rating,
            'users': {
              'name': ref.read(authRepositoryProvider).currentUser?['name'] ?? 'You',
              'avatar_url': ref.read(authRepositoryProvider).currentUser?['avatar_url'] ?? 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&w=100&q=80',
            },
            'created_at': DateTime.now().toIso8601String(),
          });
          return s.copyWith(
            reviews: updated,
            selectedRating: 5,
          );
        });
        _reviewController.clear();
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
    final detailState = ref.watch(productDetailProvider(_providerKey));
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              _buildSliverAppBar(detailState),
              SliverToBoxAdapter(
                child: Container(
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 70, top: 0), // Space for bottom bar
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                          _buildProductInfo(detailState),
                          const Divider(color: Color(0xFFEEEEEE), thickness: 1, height: 32),
                          _buildDescription(),
                          const Divider(color: Color(0xFFEEEEEE), thickness: 1, height: 32),
                          _buildReviews(detailState),
                          const SizedBox(height: 32),
                          _buildHorizontalProductList('Similar to ${widget.title}', detailState.similarProducts),
                          const SizedBox(height: 32),
                          _buildHorizontalProductList('You may also like', detailState.youMayAlsoLike),
                        ],
                      ),
                    ),
                  ),
              ),
            ],
          ),
          _buildBottomNavigationBar(detailState.quantity),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(ProductDetailState detailState) {
    return SliverAppBar(
      expandedHeight: 320.0,
      pinned: true,
      backgroundColor: Colors.white,
      elevation: 0,
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black87, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              icon: const Icon(Icons.share, color: Colors.black87, size: 20),
              onPressed: () => ShareProductBottomSheet.show(
                context,
                title: widget.title,
                image: widget.image,
                price: widget.price,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              icon: Icon(
                detailState.isFavorite ? Icons.favorite : Icons.favorite_border,
                color: detailState.isFavorite ? const Color(0xFFE57373) : Colors.grey,
                size: 20,
              ),
              onPressed: () async {
                if (!ref.read(authRepositoryProvider).isLoggedIn) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please login to use this feature'), backgroundColor: Colors.red),
                  );
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const AuthPage()));
                  return;
                }
                
                if (widget.id == null) {
                   ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Cannot favourite this item'), backgroundColor: Colors.red),
                  );
                  return;
                }

                // Optimistic UI update
                final nextFav = !detailState.isFavorite;
                ref.read(productDetailProvider(_providerKey).notifier).update(
                      (s) => s.copyWith(isFavorite: nextFav),
                    );
                
                try {
                  if (!nextFav) { 
                    // Target is false, meaning it WAS true, so we DELETE
                    final response = await http.delete(
                      Uri.parse('${AppConfig.apiUrl}/favorites?product_id=${widget.id}'),
                      headers: ref.read(authRepositoryProvider).authHeaders,
                    );
                    
                    if (response.statusCode == 200 && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Removed from Favorites'), backgroundColor: Colors.grey, duration: Duration(seconds: 1)),
                      );
                    } else if (response.statusCode != 200) {
                       throw Exception('Failed to remove: ${response.body}');
                    }
                  } else {
                    // Target is true, meaning it WAS false, so we POST
                    final response = await http.post(
                      Uri.parse('${AppConfig.apiUrl}/favorites'),
                      headers: ref.read(authRepositoryProvider).authHeaders,
                      body: jsonEncode({'product_id': widget.id}),
                    );
                    
                    if (response.statusCode == 201 && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Added to Favorites!'), backgroundColor: Color(0xFF42A769), duration: Duration(seconds: 1)),
                      );
                    } else if (response.statusCode != 201) {
                      throw Exception('Failed to add: ${response.body}');
                    }
                  }
                } catch (e) {
                   // Revert on error
                   if (mounted) {
                      ref.read(productDetailProvider(_providerKey).notifier).update(
                            (s) => s.copyWith(isFavorite: !nextFav),
                          );
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Could not update favorites. Please try again.'), backgroundColor: Colors.red),
                      );
                   }
                }
              },
            ),
          ),
        ),
        const SizedBox(width: 12),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(30),
        child: Container(
          height: 30,
          width: double.infinity,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(30),
              topRight: Radius.circular(30),
            ),
          ),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          color: const Color(0xFFF5F5F5),
          child: SkeletonImage(
            imageUrl: widget.image,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }

  Widget _buildProductInfo(ProductDetailState detailState) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.star, color: Colors.orange, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      widget.rating?.toString() ?? '0.0',
                      style: const TextStyle(
                        color: Color(0xFF42A769),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                widget.price,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF42A769),
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  widget.unit,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  widget.originalPrice,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              const Text(
                'Quantity',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove, color: Colors.black87, size: 20),
                      onPressed: () {
                        if (detailState.quantity > 1) {
                          ref.read(productDetailProvider(_providerKey).notifier).update(
                                (s) => s.copyWith(quantity: s.quantity - 1),
                              );
                        }
                      },
                    ),
                    Text(
                      '${detailState.quantity}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add, color: Colors.black87, size: 20),
                      onPressed: () {
                        ref.read(productDetailProvider(_providerKey).notifier).update(
                              (s) => s.copyWith(quantity: s.quantity + 1),
                            );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDescription() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Description',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            widget.description?.isNotEmpty == true ? widget.description! : 'No description available for this product.',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black54,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviews(ProductDetailState detailState) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Reviews (${detailState.reviews.length})',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProductReviewsPage(productName: widget.title, productId: widget.id),
                    ),
                  );
                },
                child: Row(
                  children: const [
                    Text(
                      'See All',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF42A769),
                      ),
                    ),
                    Icon(Icons.chevron_right, color: Color(0xFF42A769), size: 20),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (detailState.isLoadingReviews)
            const Padding(
              padding: EdgeInsets.all(20.0),
              child: Center(child: CircularProgressIndicator(color: Color(0xFF42A769))),
            )
          else if (detailState.reviews.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text('No reviews yet. Be the first to review!', style: TextStyle(color: Colors.grey)),
            )
          else
            ...detailState.reviews.take(3).toList().asMap().entries.map((entry) {
              final index = entry.key;
              final review = entry.value;
              final user = review['users'] ?? {};
              final name = user['name'] ?? 'User';
              final image = user['avatar_url'] != null && user['avatar_url'].toString().isNotEmpty ? user['avatar_url'] : 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&w=100&q=80';
              final rating = review['rating'] ?? 5;
              final comment = review['experience'] ?? '';
              final time = review['created_at'] != null ? review['created_at'].toString().substring(0, 10) : 'Just now';
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _buildReviewItem(
                  review: review,
                  index: index,
                  name: name,
                  image: image,
                  rating: rating,
                  time: time,
                  comment: comment,
                ),
              );
            }),
          const SizedBox(height: 8),
          _buildWriteReviewSection(detailState.selectedRating),
        ],
      ),
    );
  }

  Widget _buildReviewItem({
    required Map<String, dynamic> review,
    required int index,
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
              if (ref.read(authRepositoryProvider).currentUser != null && review['user_id'] == ref.read(authRepositoryProvider).currentUser!['id'])
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.more_vert, color: Colors.grey, size: 20),
                  onSelected: (value) {
                    if (value == 'edit') {
                      _editReviewDialog(review, index);
                    } else if (value == 'delete') {
                      _deleteReview(review['id'], index);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
                  ],
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

  Widget _buildBottomNavigationBar(int quantity) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Total Price',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.price,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF42A769),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    ref.read(cartStateProvider).addToCart(context, widget.id, quantity: quantity);
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    side: const BorderSide(color: Color(0xFF42A769), width: 1.5),
                  ),
                  child: const Text(
                    'Add to Cart',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF42A769),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    ref.read(cartStateProvider).addToCart(context, widget.id, quantity: quantity);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const CartPage()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF42A769),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Buy Now',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHorizontalProductList(String sectionTitle, List<dynamic> items) {
    if (items.isEmpty) return const SizedBox();
    
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
          height: 250,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return _buildProductCard(item);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildProductCard(dynamic product) {
    final image = product['image_url'] ?? '';
    final title = product['title'] ?? '';
    String price = '';
    if (product['price_paise'] != null) price = '₹${(product['price_paise'] / 100).toStringAsFixed(2)}'.replaceAll('.00', '');
    String originalPrice = '';
    if (product['original_price_paise'] != null) originalPrice = '₹${(product['original_price_paise'] / 100).toStringAsFixed(2)}'.replaceAll('.00', '');
    final unit = product['unit'] ?? '';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailPage(
              id: product['id'],
              image: image,
              title: title,
              price: price,
              unit: unit,
              originalPrice: originalPrice,
              description: product['description'],
              rating: product['avg_rating'],
            ),
          ),
        );
      },
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 15, bottom: 10, top: 5),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.15),
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
                Container(
                  height: 120,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(15),
                      topRight: Radius.circular(15),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(15),
                      topRight: Radius.circular(15),
                    ),
                    child: SkeletonImage(
                      imageUrl: image,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Padding(
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
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.orange, size: 12),
                          const SizedBox(width: 2),
                          Text(
                            product['avg_rating']?.toString() ?? '0.0',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black54),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            price,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Color(0xFF42A769),
                            ),
                          ),
                          Text(
                            unit,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        originalPrice,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => ShareProductBottomSheet.show(
                      context,
                      title: widget.title,
                      image: widget.image,
                      price: widget.price,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.share, color: Colors.white, size: 16),
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () {
                      if (!ref.read(authRepositoryProvider).isLoggedIn) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please login to use this feature'), backgroundColor: Colors.red),
                        );
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const AuthPage()));
                        return;
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Added to Favorites!'), backgroundColor: Color(0xFF42A769), duration: Duration(seconds: 1)),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.favorite_border, color: Colors.white, size: 16),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              bottom: 12,
              right: 12,
              child: GestureDetector(
                onTap: () {
                  if (!ref.read(authRepositoryProvider).isLoggedIn) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please login to use this feature'), backgroundColor: Colors.red),
                    );
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const AuthPage()));
                    return;
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Added to Cart!'),
                      backgroundColor: Color(0xFF42A769),
                      duration: Duration(seconds: 1),
                    ),
                  );
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
                    size: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildWriteReviewSection(int selectedRating) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.withValues(alpha: 0.1))),
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
                  ref.read(productDetailProvider(_providerKey).notifier).update(
                        (s) => s.copyWith(selectedRating: index + 1),
                      );
                },
                child: Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Icon(
                    index < selectedRating ? Icons.star : Icons.star_border,
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

}
