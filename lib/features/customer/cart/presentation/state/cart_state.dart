import 'package:flutter/material.dart';
import 'package:app/features/auth/data/repositories/auth_repository.dart';
import 'package:cubepod_core/cubepod_core.dart';
import 'package:cubepod_state/cubepod_state.dart';
import 'package:app/features/customer/cart/data/repositories/cart_repository.dart';
import 'package:app/features/auth/presentation/pages/auth_page.dart';

class CartState {
  final StateSignal<List<Map<String, dynamic>>> cartItems = StateSignal([]);
  final StateSignal<bool> isLoading = StateSignal(false);

  Future<void> fetchCartItems() async {
    final user = CubePod.get<AuthRepository>().currentUser;
    if (user == null) return;
    isLoading.value = true;
    try {
      final items = await CubePod.get<CartRepository>().fetchCartItems(user['id']);
      final mappedItems = items.map((item) {
        return {
          'id': item['id'],
          'product_id': item['product_id'],
          'title': item['foods']?['title'] ?? 'Unknown Item',
          'image': item['foods']?['image_url'] ?? '',
          'price': item['foods']?['price_paise'] != null ? (item['foods']['price_paise'] as int) ~/ 100 : 0,
          'unit': item['foods']?['unit'] != null && item['foods']['unit'].toString().startsWith('/') ? item['foods']['unit'] : ' / ${item['foods']?['unit'] ?? 'unit'}',
          'quantity': item['quantity'] ?? 1,
          'selected': true,
        };
      }).toList();
      cartItems.value = mappedItems;
    } catch (e) {
      debugPrint('Error fetching cart: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> incrementQuantity(int index) async {
    final currentList = List<Map<String, dynamic>>.from(cartItems.value);
    final cartItem = currentList[index];
    final newQuantity = (cartItem['quantity'] as int) + 1;
    currentList[index]['quantity'] = newQuantity;
    cartItems.value = currentList; // Trigger reactive update

    try {
      await CubePod.get<CartRepository>().updateQuantity(cartItem['id'], newQuantity);
    } catch (e) {
      debugPrint('Error incrementing cart quantity: $e');
    }
  }

  Future<void> decrementQuantity(int index) async {
    final currentList = List<Map<String, dynamic>>.from(cartItems.value);
    final cartItem = currentList[index];
    if ((cartItem['quantity'] as int) > 1) {
      final newQuantity = (cartItem['quantity'] as int) - 1;
      currentList[index]['quantity'] = newQuantity;
      cartItems.value = currentList;

      try {
        await CubePod.get<CartRepository>().updateQuantity(cartItem['id'], newQuantity);
      } catch (e) {
        debugPrint('Error decrementing cart quantity: $e');
      }
    }
  }

  Future<void> removeItem(int index) async {
    final currentList = List<Map<String, dynamic>>.from(cartItems.value);
    final cartItem = currentList[index];
    currentList.removeAt(index);
    cartItems.value = currentList;

    try {
      await CubePod.get<CartRepository>().removeItem(cartItem['id']);
    } catch (e) {
      debugPrint('Error removing cart item: $e');
    }
  }

  void toggleSelectAll(bool target) {
    final currentList = List<Map<String, dynamic>>.from(cartItems.value);
    for (var item in currentList) {
      item['selected'] = target;
    }
    cartItems.value = currentList;
  }

  void toggleSelectItem(int index) {
    final currentList = List<Map<String, dynamic>>.from(cartItems.value);
    currentList[index]['selected'] = !(currentList[index]['selected'] as bool);
    cartItems.value = currentList;
  }

  Future<void> addToCart(BuildContext context, dynamic productId, {int quantity = 1}) async {
    if (!CubePod.get<AuthRepository>().isLoggedIn) {
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
      final user = CubePod.get<AuthRepository>().currentUser;
      if (user == null) return;
      final success = await CubePod.get<CartRepository>().addToCart(user['id'], productId.toString(), quantity);

      if (context.mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Added to Cart!'),
              backgroundColor: Color(0xFF42A769),
              duration: Duration(seconds: 2),
            ),
          );
          fetchCartItems();
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
