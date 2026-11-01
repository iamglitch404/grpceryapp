import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/core/di/injection.dart';
import 'package:app/features/auth/screens/authPage.dart';
import 'package:app/features/customer/favorites/providers/favoritesState.dart';

class FavoriteButton extends ConsumerWidget {
  final dynamic productId;
  final bool isDarkBackground;
  final double iconSize;
  final double padding;
  final bool hasShadow;

  const FavoriteButton({
    super.key,
    required this.productId,
    this.isDarkBackground = false,
    this.iconSize = 16,
    this.padding = 6,
    this.hasShadow = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoritesState = ref.watch(favoritesStateProvider);
    final favList = favoritesState.favorites;
    final idStr = productId?.toString() ?? '';
    final isFavorite = idStr.isNotEmpty &&
        favList.any((f) {
          final prodId = (f['product_id'] ?? f['product']?['id'] ?? f['id'] ?? '').toString();
          return prodId == idStr;
        });

    return GestureDetector(
      onTap: () async {
        if (!ref.read(authRepositoryProvider).isLoggedIn) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please login to use this feature'),
              backgroundColor: Colors.red,
            ),
          );
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AuthPage()),
          );
          return;
        }

        if (productId == null || idStr.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cannot favourite this item'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        final willBeFavorite = !isFavorite;
        final success = willBeFavorite
            ? await ref.read(favoritesStateProvider).addFavorite(idStr)
            : await ref.read(favoritesStateProvider).removeFavorite(idStr);

        if (!context.mounted) return;
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                willBeFavorite ? 'Added to Favorites!' : 'Removed from Favorites',
              ),
              backgroundColor: willBeFavorite ? const Color(0xFF42A769) : Colors.grey,
              duration: const Duration(seconds: 1),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not update favorites. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      child: Container(
        padding: EdgeInsets.all(padding),
        decoration: BoxDecoration(
          color: isDarkBackground ? Colors.black.withValues(alpha: 0.3) : Colors.white,
          shape: BoxShape.circle,
          boxShadow: hasShadow
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Icon(
          isFavorite ? Icons.favorite : Icons.favorite_border,
          color: isFavorite
              ? const Color(0xFFE57373)
              : (isDarkBackground ? Colors.white : Colors.grey),
          size: iconSize,
        ),
      ),
    );
  }
}
