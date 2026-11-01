import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/core/di/injection.dart';
import 'package:app/features/auth/screens/authPage.dart';
import 'package:app/features/customer/favorites/widgets/favoriteProductCard.dart';
import 'package:app/features/customer/favorites/providers/favoritesState.dart';

class FavoritesPage extends ConsumerStatefulWidget {
  const FavoritesPage({super.key});

  @override
  ConsumerState<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends ConsumerState<FavoritesPage> {
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

  @override
  Widget build(BuildContext context) {
    final favState = ref.watch(favoritesStateProvider);
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
      body: _buildBody(
        favState.favorites,
        favState.isLoading,
        favState.errorMessage,
      ),
    );
  }

  Widget _buildBody(
    List<Map<String, dynamic>> favorites,
    bool isLoading,
    String? errorMessage,
  ) {
    final isLoggedIn = ref.read(authRepositoryProvider).isLoggedIn;
    if (!isLoggedIn) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.favorite_border, size: 80, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              const Text(
                'Sign in to save favorites',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E2022),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Log in to view and manage your favorite products.',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AuthPage()),
                  ).then((_) => _fetchFavorites());
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF42A769),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                ),
                child: const Text('Log In / Sign Up'),
              ),
            ],
          ),
        ),
      );
    }

    if (isLoading && favorites.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF42A769)),
      );
    }

    if (errorMessage != null && favorites.isEmpty) {
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

    final validFavorites = favorites.where((f) {
      final prod = f['product'] is Map ? f['product'] : f;
      return prod is Map;
    }).toList();

    if (validFavorites.isEmpty) {
      return RefreshIndicator(
        onRefresh: _fetchFavorites,
        color: const Color(0xFF42A769),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.22),
            Center(
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
        itemCount: validFavorites.length,
        itemBuilder: (context, index) {
          final favoriteItem = validFavorites[index];
          final product = Map<String, dynamic>.from(
            (favoriteItem['product'] is Map ? favoriteItem['product'] : favoriteItem) as Map,
          );
          return FavoriteProductCard(
            item: product,
            onReturned: _fetchFavorites,
          );
        },
      ),
    );
  }
}
