import 'package:flutter/material.dart';
import 'package:app/core/config/app_config.dart';
import 'package:app/core/network/http_client.dart' as http;
import 'dart:convert';
import 'package:app/features/auth/data/repositories/auth_repository.dart';
import 'package:cubepod_core/cubepod_core.dart';
import 'package:app/features/auth/presentation/pages/auth_page.dart';

class FavoriteButton extends StatefulWidget {
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
  State<FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends State<FavoriteButton> {
  bool _isFavorite = false;

  @override
  void initState() {
    super.initState();
    _checkFavorite();
  }

  Future<void> _checkFavorite() async {
    if (!CubePod.get<AuthRepository>().isLoggedIn || widget.productId == null) return;
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.apiUrl}/favorites'),
        headers: CubePod.get<AuthRepository>().authHeaders,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final favorites = data['data']['favorites'] as List;
          final exists = favorites.any((f) => f['product_id'] == widget.productId);
          if (mounted && exists) {
            setState(() => _isFavorite = true);
          }
        }
      }
    } catch (e) {
      debugPrint('Could not fetch favorites: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        if (!CubePod.get<AuthRepository>().isLoggedIn) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please login to use this feature'), backgroundColor: Colors.red),
          );
          Navigator.push(context, MaterialPageRoute(builder: (context) => const AuthPage()));
          return;
        }

        if (widget.productId == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cannot favourite this item'), backgroundColor: Colors.red),
          );
          return;
        }

        final willBeFavorite = !_isFavorite;
        setState(() {
          _isFavorite = willBeFavorite;
        });

        try {
          if (!willBeFavorite) {
            // Target is false -> DELETE from favorites
            final response = await http.delete(
              Uri.parse('${AppConfig.apiUrl}/favorites?product_id=${widget.productId}'),
              headers: CubePod.get<AuthRepository>().authHeaders,
            );

            if (response.statusCode == 200 && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Removed from Favorites'), backgroundColor: Colors.grey, duration: Duration(seconds: 1)),
              );
            } else if (response.statusCode != 200) {
              throw Exception('Failed to remove: ${response.body}');
            }
          } else {
            // Target is true -> POST to favorites
            final response = await http.post(
              Uri.parse('${AppConfig.apiUrl}/favorites'),
              headers: CubePod.get<AuthRepository>().authHeaders,
              body: jsonEncode({'product_id': widget.productId}),
            );

            if (response.statusCode == 201 && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Added to Favorites!'), backgroundColor: Color(0xFF42A769), duration: Duration(seconds: 1)),
              );
            } else if (response.statusCode != 201) {
              throw Exception('Failed to add: ${response.body}');
            }
          }
        } catch (e) {
          if (mounted) {
            setState(() {
              _isFavorite = !willBeFavorite;
            });
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Could not update favorites. Please try again.'), backgroundColor: Colors.red),
              );
            }
          }
        }
      },
      child: Container(
        padding: EdgeInsets.all(widget.padding),
        decoration: BoxDecoration(
          color: widget.isDarkBackground ? Colors.black.withValues(alpha: 0.3) : Colors.white,
          shape: BoxShape.circle,
          boxShadow: widget.hasShadow ? [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ] : null,
        ),
        child: Icon(
          _isFavorite ? Icons.favorite : Icons.favorite_border,
          color: _isFavorite ? const Color(0xFFE57373) : (widget.isDarkBackground ? Colors.white : Colors.grey),
          size: widget.iconSize,
        ),
      ),
    );
  }
}
