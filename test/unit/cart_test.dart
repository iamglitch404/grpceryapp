import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/customer/cart/providers/cartState.dart';
import 'package:app/features/auth/providers/authRepository.dart';
import 'package:app/features/customer/cart/providers/cartRepository.dart';

class MockAuthRepository extends AuthRepository {
  @override
  bool get isLoggedIn => true;

  @override
  Map<String, dynamic>? get currentUser => {'id': 'user-123', 'name': 'Test User'};
}

class MockCartRepository extends CartRepository {
  @override
  Future<List<Map<String, dynamic>>> fetchCartItems(String userId) async {
    return [
      {
        'id': 'item-1',
        'quantity': 2,
        'selected': true,
        'foods': {
          'id': 'food-1',
          'title': 'Organic Apples',
          'price': 150,
          'image': 'https://example.com/apple.jpg',
        },
      },
      {
        'id': 'item-2',
        'quantity': 1,
        'selected': false,
        'foods': {
          'id': 'food-2',
          'title': 'Fresh Milk',
          'price': 90,
          'image': 'https://example.com/milk.jpg',
        },
      },
    ];
  }
}

void main() {
  group('Cart State Unit Tests', () {
    test('CartState manages items and selection', () async {
      final authRepo = MockAuthRepository();
      final cartRepo = MockCartRepository();
      final cartState = CartState(authRepo, cartRepo);

      expect(cartState.cartItems, isEmpty);
      expect(cartState.isLoading, false);

      await cartState.fetchCartItems();

      expect(cartState.cartItems.length, 2);
      expect(cartState.cartItems[0]['title'], 'Organic Apples');
      expect(cartState.cartItems[0]['price'], 150);
      expect(cartState.cartItems[0]['quantity'], 2);

      // Test select all
      cartState.toggleSelectAll(true);
      expect(cartState.cartItems.every((item) => item['selected'] == true), true);

      // Test deselect all
      cartState.toggleSelectAll(false);
      expect(cartState.cartItems.every((item) => item['selected'] == false), true);

      // Test toggle item selection
      cartState.toggleSelectItem(0);
      expect(cartState.cartItems[0]['selected'], true);
      expect(cartState.cartItems[1]['selected'], false);
    });
  });
}
