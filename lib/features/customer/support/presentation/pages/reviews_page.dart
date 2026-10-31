import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:app/core/config/app_config.dart';
import 'package:app/core/network/http_client.dart' as http;
import 'dart:convert';
import 'package:app/features/auth/data/repositories/auth_repository.dart';
import 'package:cubepod_core/cubepod_core.dart';

class ReviewsPage extends StatefulWidget {
  const ReviewsPage({super.key});

  @override
  State<ReviewsPage> createState() => _ReviewsPageState();
}

class _ReviewsPageState extends State<ReviewsPage> {
  List<dynamic> _reviews = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchMyReviews();
  }

  Future<void> _fetchMyReviews() async {
    if (!CubePod.get<AuthRepository>().isLoggedIn) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('${AppConfig.apiUrl}/reviews?user_id=${CubePod.get<AuthRepository>().currentUser!['id']}'),
        headers: CubePod.get<AuthRepository>().authHeaders,
      );

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _reviews = List<Map<String, dynamic>>.from(jsonDecode(response.body));
            _isLoading = false;
          });
        }
      } else {
        throw Exception('Failed to fetch my reviews: ${response.body}');
      }
    } catch (e) {
      debugPrint('Error fetching my reviews: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteReview(String reviewId, int index) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Review'),
        content: const Text('Are you sure you want to delete this review?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final response = await http.delete(
        Uri.parse('${AppConfig.apiUrl}/reviews?review_id=$reviewId'),
        headers: CubePod.get<AuthRepository>().authHeaders,
      );
      if (response.statusCode == 200 && mounted) {
        setState(() {
          _reviews.removeAt(index);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Review deleted successfully'), backgroundColor: Color(0xFF42A769)),
        );
      } else if (response.statusCode != 200) {
        throw Exception('Failed to delete review: ${response.body}');
      }
    } catch (e) {
      debugPrint('Error deleting review: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting review: $e'), backgroundColor: Colors.red),
        );
      }
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('Edit Review'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (starIndex) {
                      return IconButton(
                        icon: Icon(
                          Icons.star_rounded,
                          color: starIndex < editRating ? const Color(0xFFFFB300) : Colors.grey.shade300,
                          size: 32,
                        ),
                        onPressed: () {
                          setDialogState(() {
                            editRating = starIndex + 1;
                          });
                        },
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: editController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Share your experience...',
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
                TextButton(
                  onPressed: () async {
                    if (editController.text.trim().isEmpty) return;
                    Navigator.pop(context); // close dialog
                    try {
                      final response = await http.patch(
                        Uri.parse('${AppConfig.apiUrl}/reviews'),
                        headers: CubePod.get<AuthRepository>().authHeaders,
                        body: jsonEncode({
                          'review_id': review['id'],
                          'comment': editController.text.trim(),
                          'rating': editRating,
                        }),
                      );
                      
                      if (response.statusCode == 200 && mounted) {
                        setState(() {
                          _reviews[index]['comment'] = editController.text.trim();
                          _reviews[index]['rating'] = editRating;
                        });
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Review updated'), backgroundColor: Color(0xFF42A769)),
                        );
                      } else if (response.statusCode != 200) {
                        throw Exception('Failed to update review: ${response.body}');
                      }
                    } catch (e) {
                      debugPrint('Error updating review: $e');
                      if (mounted) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error updating review: $e'), backgroundColor: Colors.red),
                        );
                      }
                    }
                  },
                  child: const Text('Update', style: TextStyle(color: Color(0xFF42A769), fontWeight: FontWeight.bold)),
                ),
              ],
            );
          }
        );
      }
    );
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
        backgroundColor: const Color(0xFFFAFAFA),
        appBar: AppBar(
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
          ),
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF2D2D2D), size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'My Reviews',
            style: TextStyle(
              color: Color(0xFF1E2022),
              fontWeight: FontWeight.w900,
              fontSize: 20,
              letterSpacing: -0.5,
            ),
          ),
          centerTitle: true,
        ),
        body: _isLoading 
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF42A769)))
            : _reviews.isEmpty
                ? const Center(
                    child: Text('You have not reviewed any products yet.', 
                        style: TextStyle(color: Colors.grey, fontSize: 16)))
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                    itemCount: _reviews.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final review = _reviews[index];
                      final product = review['products'] ?? {};
                      final int rating = review['rating'] ?? 5;
                      final title = product['title'] ?? 'Product';
                      final image = product['image'] ?? 'https://images.unsplash.com/photo-1592924357228-91a4daadcfea?auto=format&fit=crop&w=300&q=80';
                      final date = review['created_at'] != null ? review['created_at'].toString().substring(0, 10) : '';

                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  height: 54,
                                  width: 54,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF9FAFB),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.network(
                                      image,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) =>
                                          const Icon(Icons.broken_image_rounded, color: Colors.grey),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        title,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF2D2D2D),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Row(
                                            children: List.generate(5, (starIndex) {
                                              return Icon(
                                                Icons.star_rounded,
                                                size: 14,
                                                color: starIndex < rating
                                                    ? const Color(0xFFFFB300)
                                                    : Colors.grey.shade200,
                                              );
                                            }),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            date,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.grey.shade400,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert, color: Colors.grey, size: 20),
                                  onSelected: (value) {
                                    if (value == 'edit') {
                                      _editReviewDialog(review, index);
                                    } else if (value == 'delete') {
                                      _deleteReview(review['id'], index);
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: Row(
                                        children: [
                                          Icon(Icons.edit_outlined, size: 18),
                                          SizedBox(width: 8),
                                          Text('Edit'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                          SizedBox(width: 8),
                                          Text('Delete', style: TextStyle(color: Colors.red)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Divider(height: 1, color: Color(0xFFF3F4F6)),
                            const SizedBox(height: 12),
                            Text(
                              (review['comment'] ?? '') as String,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade700,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
