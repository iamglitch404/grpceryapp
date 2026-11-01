import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/core/di/injection.dart';
import 'package:app/features/customer/orders/screens/orderDetailPage.dart';
import 'package:app/features/customer/orders/screens/orderTrackingPage.dart';
import 'package:app/features/customer/cart/screens/checkoutSummaryPage.dart';
import 'package:app/features/auth/screens/authPage.dart';
import 'package:app/features/customer/cart/widgets/cartGuestPrompt.dart';
import 'package:app/features/customer/cart/providers/cartState.dart';
import 'package:app/features/customer/cart/providers/cartProviders.dart';

class CartPage extends ConsumerStatefulWidget {
  const CartPage({super.key});

  @override
  ConsumerState<CartPage> createState() => _CartPageState();
}

class _CartPageState extends ConsumerState<CartPage> {

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Canceled':
      case 'Cancelled': return Colors.red;
      case 'Pending': return Colors.orange;
      case 'Processing':
      case 'Packed': return Colors.brown;
      case 'Out for Delivery':
      case 'On the way': return Colors.blue;
      case 'Delivered': default: return const Color(0xFF42A769);
    }
  }

  Color _getStatusBgColor(String status) {
    switch (status) {
      case 'Canceled':
      case 'Cancelled': return const Color(0xFFFFEBEE);
      case 'Pending': return Colors.orange.shade50;
      case 'Processing':
      case 'Packed': return Colors.brown.shade50;
      case 'Out for Delivery':
      case 'On the way': return Colors.blue.shade50;
      case 'Delivered': default: return const Color(0xFFE8F5E9);
    }
  }

  int get _selectedTab => ref.read(cartSelectedTabProvider);

  // Current Orders
  List<Map<String, dynamic>> get _currentOrders => ref.read(cartCurrentOrdersProvider);
  bool get _isLoadingOrders => ref.read(cartIsLoadingOrdersProvider);

  // Previous Orders
  List<Map<String, dynamic>> get _previousOrders => ref.read(cartPreviousOrdersProvider);
  bool get _isLoadingPreviousOrders => ref.read(cartIsLoadingPreviousOrdersProvider);

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      _fetchCartItems();
      _fetchCurrentOrders();
      _fetchPreviousOrders();
    });
  }

  Future<void> _cancelOrder(String orderId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Order'),
        content: const Text('Are you sure you want to cancel this order?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Yes, Cancel', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await ref.read(customerOrderRepositoryProvider).cancelOrder(orderId);
      
      _fetchCurrentOrders();
      _fetchPreviousOrders();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order cancelled successfully'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      debugPrint('Error cancelling order: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to cancel order'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _fetchPreviousOrders() async {
    if (!ref.read(authRepositoryProvider).isLoggedIn) return;
    ref.read(cartIsLoadingPreviousOrdersProvider.notifier).state = true;
    
    try {
      final userId = ref.read(authRepositoryProvider).currentUser!['id'];
      final response = await ref.read(customerOrderRepositoryProvider).fetchPreviousOrders(userId);
          
      if (mounted) {
        ref.read(cartPreviousOrdersProvider.notifier).state =
            List<Map<String, dynamic>>.from(response);
      }
    } catch (e) {
      debugPrint('Error fetching previous orders: $e');
    } finally {
      if (mounted) {
        ref.read(cartIsLoadingPreviousOrdersProvider.notifier).state = false;
      }
    }
  }

  Future<void> _fetchCurrentOrders() async {
    if (!ref.read(authRepositoryProvider).isLoggedIn) return;
    ref.read(cartIsLoadingOrdersProvider.notifier).state = true;
    
    try {
      final userId = ref.read(authRepositoryProvider).currentUser!['id'];
      final response = await ref.read(customerOrderRepositoryProvider).fetchCurrentOrders(userId);
          
      if (mounted) {
        ref.read(cartCurrentOrdersProvider.notifier).state =
            List<Map<String, dynamic>>.from(response);
      }
    } catch (e) {
      debugPrint('Error fetching current orders: $e');
    } finally {
      if (mounted) {
        ref.read(cartIsLoadingOrdersProvider.notifier).state = false;
      }
    }
  }

  Future<void> _fetchCartItems() async {
    if (!ref.read(authRepositoryProvider).isLoggedIn) return;
    await ref.read(cartStateProvider).fetchCartItems();
  }

  final int _deliveryFee = 40;

  void _toggleSelectAll(bool currentAllSelected) {
    ref.read(cartStateProvider).toggleSelectAll(!currentAllSelected);
  }

  void _toggleSelectItem(int index) {
    ref.read(cartStateProvider).toggleSelectItem(index);
  }

  Future<void> _incrementQuantity(int index) async {
    await ref.read(cartStateProvider).incrementQuantity(index);
  }

  Future<void> _decrementQuantity(int index) async {
    await ref.read(cartStateProvider).decrementQuantity(index);
  }

  Future<void> _removeItem(int index) async {
    await ref.read(cartStateProvider).removeItem(index);
  }

  String _formatCurrency(int amount) {
    String result = amount.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');
    return 'Rs $result';
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(cartSelectedTabProvider);
    ref.watch(cartCurrentOrdersProvider);
    ref.watch(cartIsLoadingOrdersProvider);
    ref.watch(cartPreviousOrdersProvider);
    ref.watch(cartIsLoadingPreviousOrdersProvider);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
          ),
          backgroundColor: Colors.white,
          elevation: 0,
          automaticallyImplyLeading: false,
          title: const Text(
            'Cart',
            style: TextStyle(
              color: Color(0xFF1E2022),
              fontWeight: FontWeight.w900,
              fontSize: 20,
              letterSpacing: -0.5,
            ),
          ),
          centerTitle: true,
        ),
        body: Column(
          children: [
            // Tabs navigation matching mock reference
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildTabItem(0, 'My Cart'),
                  _buildTabItem(1, 'Current Order'),
                  _buildTabItem(2, 'Previous Order'),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFF0F2F5)),
            Expanded(
              child: _buildTabContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabItem(int index, String title) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () {
        ref.read(cartSelectedTabProvider.notifier).state = index;
        if (index == 0) {
          _fetchCartItems();
        } else if (index == 1) {
          _fetchCurrentOrders();
        } else if (index == 2) {
          _fetchPreviousOrders();
        }
      },
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
              color: isSelected ? const Color(0xFF1E2022) : Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 2.5,
            width: isSelected ? 48 : 0,
            decoration: BoxDecoration(
              color: const Color(0xFF1E2022),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_selectedTab) {
      case 0:
        return _buildMyCartView();
      case 1:
        return _buildCurrentOrderView();
      case 2:
        return _buildPreviousOrderView();
      default:
        return _buildMyCartView();
    }
  }

  // --- MY CART TAB ---
  Widget _buildMyCartView() {
    final isLoggedIn = ref.read(authRepositoryProvider).isLoggedIn;
    if (!isLoggedIn) {
      return const GuestCartPromptView();
    }

    return Consumer(
      builder: (context, ref, _) {
        final cartState = ref.watch(cartStateProvider);
        final cartItems = cartState.cartItems;
        final isLoading = cartState.isLoading;

        if (isLoading && cartItems.isEmpty) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF42A769)));
        }

        if (cartItems.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    color: Color(0xFFE8F5E9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.shopping_basket_rounded,
                    size: 60,
                    color: Color(0xFF42A769),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Your cart is empty',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D2D2D),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Items you add to your cart will show up here',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          );
        }

        final isAllSelected = cartItems.isNotEmpty && cartItems.every((item) => item['selected'] == true);
        int subtotal = 0;
        int selectedCount = 0;
        for (var item in cartItems) {
          if (item['selected'] == true) {
            subtotal += (item['price'] as int) * (item['quantity'] as int);
            selectedCount++;
          }
        }
        int total = subtotal + (selectedCount == 0 ? 0 : _deliveryFee);

        return Column(
          children: [
            // Select All Header Bar
            Padding(
              padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => _toggleSelectAll(isAllSelected),
                    behavior: HitTestBehavior.opaque,
                    child: Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: isAllSelected ? const Color(0xFF42A769) : Colors.transparent,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isAllSelected ? const Color(0xFF42A769) : Colors.grey.shade400,
                              width: 2,
                            ),
                          ),
                          padding: const EdgeInsets.all(2),
                          child: Icon(
                            Icons.check_rounded,
                            size: 12,
                            color: isAllSelected ? Colors.white : Colors.transparent,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Select All ($selectedCount/${cartItems.length})',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2D2D2D),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                itemCount: cartItems.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final item = cartItems[index];
                  final isSelected = item['selected'] as bool;
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // Selection Checkbox
                        GestureDetector(
                          onTap: () => _toggleSelectItem(index),
                          behavior: HitTestBehavior.opaque,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 12, left: 4),
                            child: Container(
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFF42A769) : Colors.transparent,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected ? const Color(0xFF42A769) : Colors.grey.shade300,
                                  width: 2,
                                ),
                              ),
                              padding: const EdgeInsets.all(2),
                              child: Icon(
                                Icons.check_rounded,
                                size: 12,
                                color: isSelected ? Colors.white : Colors.transparent,
                              ),
                            ),
                          ),
                        ),
                        Container(
                          height: 80,
                          width: 80,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.network(
                              item['image'] as String,
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
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      item['title'] as String,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF2D2D2D),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () => _removeItem(index),
                                    child: Icon(
                                      Icons.delete_outline_rounded,
                                      color: Colors.grey.shade400,
                                      size: 20,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item['unit'] as String,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade400,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _formatCurrency((item['price'] as int) * (item['quantity'] as int)),
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF42A769),
                                    ),
                                  ),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF3F4F6),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        GestureDetector(
                                          onTap: () => _decrementQuantity(index),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            child: Icon(
                                              Icons.remove_rounded,
                                              size: 16,
                                              color: Colors.grey.shade700,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          '${item['quantity']}',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF2D2D2D),
                                          ),
                                        ),
                                        GestureDetector(
                                          onTap: () => _incrementQuantity(index),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            child: Icon(
                                              Icons.add_rounded,
                                              size: 16,
                                              color: Colors.grey.shade700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 15,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              padding: const EdgeInsets.only(left: 24, right: 24, top: 20, bottom: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Subtotal',
                        style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w500),
                      ),
                      Text(
                        _formatCurrency(subtotal),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF2D2D2D)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Delivery Fee',
                        style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w500),
                      ),
                      Text(
                        _formatCurrency(selectedCount == 0 ? 0 : _deliveryFee),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF2D2D2D)),
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Divider(height: 1, color: Color(0xFFF3F4F6)),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Total Price',
                            style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _formatCurrency(total),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF2D2D2D),
                            ),
                          ),
                        ],
                      ),
                      ElevatedButton(
                        onPressed: selectedCount > 0
                            ? () {
                                final isLoggedIn = ref.read(authRepositoryProvider).isLoggedIn;
                                if (!isLoggedIn) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => const AuthPage()),
                                  );
                                } else {
                                  final selectedItems =
                                      cartItems.where((item) => item['selected'] == true).toList();
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => CheckoutSummaryPage(
                                        items: selectedItems,
                                        deliveryFee: _deliveryFee,
                                      ),
                                    ),
                                  ).then((value) {
                                    if (value == true) {
                                      _fetchCartItems();
                                      _fetchCurrentOrders();
                                      _fetchPreviousOrders();
                                      ref.read(cartSelectedTabProvider.notifier).state = 1;
                                    }
                                  });
                                }
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF42A769),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Text(
                              'Proceed to Order',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            SizedBox(width: 8),
                            Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Colors.white),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // --- CURRENT ORDER TAB ---
  Widget _buildCurrentOrderView() {
    final isLoggedIn = ref.read(authRepositoryProvider).isLoggedIn;
    if (!isLoggedIn) {
      return const GuestOrderPromptView();
    }

    if (_isLoadingOrders) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF42A769)));
    }

    if (_currentOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Color(0xFFE8F5E9),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.receipt_long_rounded,
                size: 60,
                color: Color(0xFF42A769),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No active orders',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D2D2D),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      itemCount: _currentOrders.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final order = _currentOrders[index];
        final orderItems = order['order_items'] as List? ?? [];
        final itemsCount = orderItems.length;
        
        int total = 0;
        if (order['total_paise'] != null && order['total_paise'] is num) {
          total = (order['total_paise'] as num).toInt() ~/ 100;
        } else if (order['total_amount'] != null) {
          if (order['total_amount'] is int) {
            total = order['total_amount'];
          } else {
            final totalStr = order['total_amount'].toString().replaceAll(RegExp(r'[^0-9]'), '');
            total = int.tryParse(totalStr) ?? 0;
          }
        }
        
        final store = order['store'] ?? 'Nippon Mart';

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFF42A769).withValues(alpha: 0.2)),
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Order Status: ${order['status'] ?? 'Pending'}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: Color(0xFF1E2022),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusBgColor(order['status'] ?? 'Pending'),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      order['status'] ?? 'Pending',
                      style: TextStyle(
                        color: _getStatusColor(order['status'] ?? 'Pending'),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                store,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 24),
              Builder(
                builder: (context) {
                  final s = (order['status'] ?? 'Pending').toString().toLowerCase();
                  final isDelivered = s == 'delivered';
                  final isOnTheWay = s == 'on the way' || s == 'out for delivery' || isDelivered;
                  final isPacked = s == 'packed' || s == 'processing' || isOnTheWay;
                  return Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: const Color(0xFF42A769),
                            size: 20,
                          ),
                          Expanded(
                            child: Container(
                              height: 2,
                              color: isPacked ? const Color(0xFF42A769) : Colors.grey.shade300,
                            ),
                          ),
                          Icon(
                            Icons.inventory_2_rounded,
                            color: isPacked ? const Color(0xFF42A769) : Colors.grey.shade300,
                            size: 20,
                          ),
                          Expanded(
                            child: Container(
                              height: 2,
                              color: isOnTheWay ? const Color(0xFF42A769) : Colors.grey.shade300,
                            ),
                          ),
                          Icon(
                            Icons.local_shipping,
                            color: isOnTheWay ? const Color(0xFF42A769) : Colors.grey.shade300,
                            size: 22,
                          ),
                          Expanded(
                            child: Container(
                              height: 2,
                              color: isDelivered ? const Color(0xFF42A769) : Colors.grey.shade300,
                            ),
                          ),
                          Icon(
                            Icons.home,
                            color: isDelivered ? const Color(0xFF42A769) : Colors.grey.shade300,
                            size: 20,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Placed',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFF42A769),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Packed',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: isPacked ? const Color(0xFF42A769) : Colors.grey,
                              fontWeight: isPacked ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          Text(
                            'On the Way',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: isOnTheWay ? const Color(0xFF42A769) : Colors.grey,
                              fontWeight: isOnTheWay ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          Text(
                            'Delivered',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: isDelivered ? const Color(0xFF42A769) : Colors.grey,
                              fontWeight: isDelivered ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),
              const Divider(height: 1, color: Color(0xFFF0F2F5)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_formatCurrency(total)} • $itemsCount Items',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E2022)),
                  ),
                  Row(
                    children: [
                      if (order['status'] == 'Pending') ...[
                        GestureDetector(
                          onTap: () => _cancelOrder(order['id']),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.red),
                          ),
                        ),
                        const SizedBox(width: 14),
                      ],
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => OrderDetailPage(order: order),
                            ),
                          );
                        },
                        child: const Text(
                          'Details',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF64748B)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => OrderTrackingPage(order: order),
                            ),
                          ).then((_) {
                            _fetchCurrentOrders();
                            _fetchPreviousOrders();
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF185B3A),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.my_location_rounded, size: 13, color: Colors.white),
                              SizedBox(width: 5),
                              Text(
                                'Track Live',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // --- PREVIOUS ORDER TAB ---
  Widget _buildPreviousOrderView() {
    final isLoggedIn = ref.read(authRepositoryProvider).isLoggedIn;
    if (!isLoggedIn) {
      return const GuestOrderPromptView();
    }

    if (_isLoadingPreviousOrders) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF42A769)));
    }

    if (_previousOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Color(0xFFE8F5E9),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.history_rounded,
                size: 60,
                color: Color(0xFF42A769),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No previous orders',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D2D2D),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      itemCount: _previousOrders.length,
      itemBuilder: (context, index) {
        final order = _previousOrders[index];
        final orderItems = order['order_items'] as List? ?? [];
        final itemsCount = orderItems.length;
        
        int total = 0;
        if (order['total_paise'] != null && order['total_paise'] is num) {
          total = (order['total_paise'] as num).toInt() ~/ 100;
        } else if (order['total_amount'] != null) {
          if (order['total_amount'] is int) {
            total = order['total_amount'];
          } else {
            final totalStr = order['total_amount'].toString().replaceAll(RegExp(r'[^0-9]'), '');
            total = int.tryParse(totalStr) ?? 0;
          }
        }
        
        final store = order['store'] ?? 'Nippon Mart';
        final createdAt = order['created_at'] != null ? order['created_at'].toString().substring(0, 10) : '';

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Order Status: ${order['status'] ?? 'Delivered'}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF2D2D2D)),
                      ),
                      Text(
                        createdAt,
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getStatusBgColor(order['status'] ?? 'Delivered'),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          order['status'] ?? 'Delivered',
                          style: TextStyle(
                            color: _getStatusColor(order['status'] ?? 'Delivered'), 
                            fontSize: 12, 
                            fontWeight: FontWeight.bold
                          ),
                        ),
                      ),
                      const Spacer(),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            store,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF2D2D2D)),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_formatCurrency(total)} • $itemsCount Items',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => OrderDetailPage(order: order),
                            ),
                          );
                        },
                        child: const Text(
                          'View Detail',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF42A769)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (index < _previousOrders.length - 1)
              const Divider(height: 1, color: Color(0xFFF0F2F5)),
          ],
        );
      },
    );
  }
}
