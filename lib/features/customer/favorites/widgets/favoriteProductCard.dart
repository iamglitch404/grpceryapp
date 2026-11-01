import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/core/widgets/skeletonImage.dart';
import 'package:app/features/customer/cart/providers/cartState.dart';
import 'package:app/features/customer/widgets/favoriteButton.dart';
import 'package:app/features/customer/home/screens/productDetailPage.dart';

class FavoriteProductCard extends ConsumerWidget {
  final Map<String, dynamic> item;
  final VoidCallback onReturned;

  const FavoriteProductCard({
    super.key,
    required this.item,
    required this.onReturned,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = (item['title'] ?? item['name'] ?? '').toString();
    final imageUrl = (item['image_url'] ?? item['image'] ?? '').toString();
    final id = item['id']?.toString() ?? '';
    final pricePaise = (item['price_paise'] as num?)?.toInt() ?? 0;
    final originalPricePaise = (item['original_price_paise'] as num?)?.toInt() ?? pricePaise;
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
        onReturned();
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
                  ref.read(cartStateProvider).addToCart(context, id);
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
