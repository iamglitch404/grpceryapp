import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/core/di/injection.dart';
import 'package:app/features/auth/providers/authRepository.dart';
import 'package:app/features/customer/cart/providers/cartRepository.dart';
import 'package:app/features/auth/screens/authPage.dart';

class CartState extends ChangeNotifier {
  final AuthRepository _authRepository;
  final CartRepository _cartRepository;

  CartState(this._authRepository, this._cartRepository);

  List<Map<String, dynamic>> _cartItems = [];
  bool _isLoading = false;

  List<Map<String, dynamic>> get cartItems => _cartItems;
  set cartItems(List<Map<String, dynamic>> value) {
    _cartItems = value;
    notifyListeners();
  }

  bool get isLoading => _isLoading;

  Future<void> fetchCartItems() async {
    final user = _authRepository.currentUser;
    if (user == null) {
      _cartItems = [];
      notifyListeners();
      return;
    }
    if (_cartItems.isEmpty) {
      _isLoading = true;
      notifyListeners();
    }
    try {
      final items = await _cartRepository.fetchCartItems(user['id']);
      final previousSelection = <String, bool>{};
      for (final existing in _cartItems) {
        final key = (existing['id'] ?? existing['product_id'] ?? '').toString();
        if (key.isNotEmpty) {
          previousSelection[key] = existing['selected'] == true;
        }
      }

      final mappedItems = items.map((item) {
        final food = (item['foods'] is Map ? item['foods'] : {}) as Map;
        final rawPaise = item['price_paise'] ?? food['price_paise'];
        int priceRs = 0;
        if (rawPaise is num) {
          priceRs = (rawPaise / 100).round();
        } else if (food['price'] != null) {
          if (food['price'] is num) {
            priceRs = (food['price'] as num).round();
          } else {
            final priceStr = food['price'].toString().replaceAll(RegExp(r'[^0-9]'), '');
            priceRs = int.tryParse(priceStr) ?? 0;
          }
        }

        final rawUnit = (item['unit'] ?? food['unit'] ?? 'unit').toString();
        final unitStr = rawUnit.startsWith('/') ? rawUnit : ' / $rawUnit';
        final itemId = item['id']?.toString() ?? '';
        final prodId = (item['product_id'] ?? item['food_id'] ?? food['id'] ?? '').toString();
        final key = itemId.isNotEmpty ? itemId : prodId;

        return <String, dynamic>{
          'id': item['id'],
          'product_id': prodId,
          'food_id': prodId,
          'title': (item['title'] ?? food['title'] ?? 'Unknown Item').toString(),
          'image': (item['image_url'] ?? food['image_url'] ?? food['image'] ?? '').toString(),
          'image_url': (item['image_url'] ?? food['image_url'] ?? food['image'] ?? '').toString(),
          'price': priceRs,
          'price_paise': rawPaise is num ? rawPaise.toInt() : priceRs * 100,
          'unit': unitStr,
          'quantity': (item['quantity'] as num?)?.toInt() ?? 1,
          'selected': previousSelection[key] ?? true,
        };
      }).toList();
      _cartItems = mappedItems;
    } catch (e) {
      debugPrint('Error fetching cart: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> incrementQuantity(int index) async {
    final currentList = _cartItems.map((e) => Map<String, dynamic>.from(e)).toList();
    if (index < 0 || index >= currentList.length) return;
    final cartItem = currentList[index];
    final newQuantity = (cartItem['quantity'] as int) + 1;
    currentList[index]['quantity'] = newQuantity;
    _cartItems = currentList;
    notifyListeners();

    try {
      await _cartRepository.updateQuantity(cartItem['id'].toString(), newQuantity);
    } catch (e) {
      debugPrint('Error incrementing cart quantity: $e');
    }
  }

  Future<void> decrementQuantity(int index) async {
    final currentList = _cartItems.map((e) => Map<String, dynamic>.from(e)).toList();
    if (index < 0 || index >= currentList.length) return;
    final cartItem = currentList[index];
    if ((cartItem['quantity'] as int) > 1) {
      final newQuantity = (cartItem['quantity'] as int) - 1;
      currentList[index]['quantity'] = newQuantity;
      _cartItems = currentList;
      notifyListeners();

      try {
        await _cartRepository.updateQuantity(cartItem['id'].toString(), newQuantity);
      } catch (e) {
        debugPrint('Error decrementing cart quantity: $e');
      }
    }
  }

  Future<void> removeItem(int index) async {
    final currentList = _cartItems.map((e) => Map<String, dynamic>.from(e)).toList();
    if (index < 0 || index >= currentList.length) return;
    final cartItem = currentList[index];
    currentList.removeAt(index);
    _cartItems = currentList;
    notifyListeners();

    try {
      await _cartRepository.removeItem(cartItem['id'].toString());
    } catch (e) {
      debugPrint('Error removing cart item: $e');
    }
  }

  void toggleSelectAll(bool target) {
    final currentList = _cartItems.map((e) => Map<String, dynamic>.from(e)).toList();
    for (var item in currentList) {
      item['selected'] = target;
    }
    _cartItems = currentList;
    notifyListeners();
  }

  void toggleSelectItem(int index) {
    final currentList = _cartItems.map((e) => Map<String, dynamic>.from(e)).toList();
    if (index < 0 || index >= currentList.length) return;
    currentList[index]['selected'] = !(currentList[index]['selected'] as bool);
    _cartItems = currentList;
    notifyListeners();
  }

  Future<void> addToCart(BuildContext context, dynamic productId, {int quantity = 1}) async {
    if (!_authRepository.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to use this feature'), backgroundColor: Colors.red),
      );
      Navigator.push(context, MaterialPageRoute(builder: (context) => const AuthPage()));
      return;
    }

    if (productId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot add this item to cart'), backgroundColor: Colors.red),
      );
      return;
    }

    try {
      final user = _authRepository.currentUser;
      if (user == null) return;
      final success = await _cartRepository.addToCart(user['id'], productId.toString(), quantity);

      if (success) {
        await fetchCartItems();
      }

      if (context.mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Added to Cart!'),
              backgroundColor: Color(0xFF42A769),
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to add to cart'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not add to cart. Please try again.'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

final cartStateProvider = ChangeNotifierProvider<CartState>((ref) {
  return CartState(
    ref.watch(authRepositoryProvider),
    ref.watch(cartRepositoryProvider),
  );
});
