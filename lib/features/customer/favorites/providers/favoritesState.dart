import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/core/di/injection.dart';
import 'package:app/core/config/appConfig.dart';
import 'package:app/core/network/httpClient.dart' as http;
import 'package:app/features/auth/providers/authRepository.dart';

class FavoritesState extends ChangeNotifier {
  final AuthRepository _authRepository;

  FavoritesState(this._authRepository);

  List<Map<String, dynamic>> _favorites = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<Map<String, dynamic>> get favorites => _favorites;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  bool isFavorite(dynamic productId) {
    if (productId == null) return false;
    final idStr = productId.toString();
    return _favorites.any((f) {
      final prodId = (f['product_id'] ?? f['product']?['id'] ?? f['id'] ?? '').toString();
      return prodId == idStr;
    });
  }

  Future<void> fetchFavorites() async {
    final authRepo = _authRepository;
    if (!authRepo.isLoggedIn) {
      _favorites = [];
      _isLoading = false;
      _errorMessage = null;
      notifyListeners();
      return;
    }

    if (_favorites.isEmpty) {
      _isLoading = true;
    }
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await http.get(
        Uri.parse('${AppConfig.apiUrl}/favorites'),
        headers: authRepo.authHeaders,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final list = (data['favorites'] as List<dynamic>?) ??
              (data['data']?['favorites'] as List<dynamic>?) ??
              [];
          _favorites = list
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
          _isLoading = false;
          notifyListeners();
          return;
        }
      }
      throw Exception('Failed to load favorites');
    } catch (e) {
      debugPrint('[FavoritesState] Error fetching favorites: $e');
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> toggleFavorite(dynamic productId, [Map<String, dynamic>? productDetails]) async {
    if (productId == null) return false;
    final idStr = productId.toString();
    if (isFavorite(idStr)) {
      return removeFavorite(idStr);
    } else {
      return addFavorite(idStr, productDetails);
    }
  }

  Future<bool> addFavorite(String productId, [Map<String, dynamic>? productDetails]) async {
    final authRepo = _authRepository;
    if (!authRepo.isLoggedIn) return false;

    final previous = List<Map<String, dynamic>>.from(_favorites);
    if (!isFavorite(productId)) {
      _favorites = [
        {
          'product_id': productId,
          'product': productDetails ?? {
            'id': productId,
            'title': 'Favorite Product',
          },
        },
        ...previous,
      ];
      notifyListeners();
    }

    try {
      final response = await http.post(
        Uri.parse('${AppConfig.apiUrl}/favorites'),
        headers: {
          ...authRepo.authHeaders,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'product_id': productId}),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        await fetchFavorites();
        return true;
      } else {
        _favorites = previous;
        notifyListeners();
        return false;
      }
    } catch (e) {
      debugPrint('[FavoritesState] Error adding favorite: $e');
      _favorites = previous;
      notifyListeners();
      return false;
    }
  }

  Future<bool> removeFavorite(String productId) async {
    final authRepo = _authRepository;
    if (!authRepo.isLoggedIn) return false;

    final previous = List<Map<String, dynamic>>.from(_favorites);
    _favorites = previous.where((f) {
      final prodId = (f['product_id'] ?? f['product']?['id'] ?? f['id'] ?? '').toString();
      return prodId != productId;
    }).toList();
    notifyListeners();

    try {
      final response = await http.delete(
        Uri.parse('${AppConfig.apiUrl}/favorites?product_id=$productId'),
        headers: authRepo.authHeaders,
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return true;
      } else {
        _favorites = previous;
        notifyListeners();
        return false;
      }
    } catch (e) {
      debugPrint('[FavoritesState] Error removing favorite: $e');
      _favorites = previous;
      notifyListeners();
      return false;
    }
  }
}

final favoritesStateProvider = ChangeNotifierProvider<FavoritesState>((ref) {
  return FavoritesState(ref.watch(authRepositoryProvider));
});
