import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:app/features/customer/profile/presentation/pages/saved_addresses_page.dart';
import 'package:app/features/auth/data/repositories/auth_repository.dart';
import 'package:app/features/customer/profile/data/repositories/user_repository.dart';
import 'package:app/features/customer/orders/data/repositories/order_repository.dart';
import 'package:app/features/customer/cart/presentation/state/cart_state.dart';
import 'package:cubepod_core/cubepod_core.dart';

class CheckoutSummaryPage extends StatefulWidget {
  final List<Map<String, dynamic>> items;
  final int deliveryFee;

  const CheckoutSummaryPage({
    super.key,
    required this.items,
    required this.deliveryFee,
  });

  @override
  State<CheckoutSummaryPage> createState() => _CheckoutSummaryPageState();
}

class _CheckoutSummaryPageState extends State<CheckoutSummaryPage> {
  late List<Map<String, dynamic>> _summaryItems;
  final double _taxAndFeesRate = 0.05; // 5% tax
  bool _isProcessing = false;

  Map<String, dynamic> _selectedAddress = {
    'label': 'Home',
    'name': 'Customer',
    'phone': '',
    'address': 'Select delivery address',
  };

  @override
  void initState() {
    super.initState();
    _summaryItems = widget.items.map((item) => Map<String, dynamic>.from(item)).toList();
    _loadUserAddress();
  }

  Future<void> _loadUserAddress() async {
    try {
      final userRepo = CubePod.get<UserRepository>();
      final authRepo = CubePod.get<AuthRepository>();

      // 1. Try selected address from storage
      final saved = await userRepo.getSelectedAddress();
      if (saved != null && mounted) {
        setState(() {
          _selectedAddress = {
            ...saved,
            'address': saved['address'] ?? '${saved['street'] ?? ''} ${saved['details'] ?? ''}'.trim(),
          };
        });
        return;
      }

      // 2. Try cached or remote addresses
      final cached = await userRepo.getCachedAddresses();
      final list = cached.isNotEmpty ? cached : (authRepo.isLoggedIn ? await userRepo.fetchAddresses(authRepo.authHeaders) : []);

      if (list.isNotEmpty && mounted) {
        final def = list.firstWhere((a) => a['is_default'] == true, orElse: () => list.first);
        final fullAddr = '${def['street'] ?? ''} ${def['details'] ?? ''}'.trim();
        setState(() {
          _selectedAddress = {
            'id': def['id'],
            'label': def['label'] ?? 'Home',
            'name': def['name'] ?? authRepo.currentUser?['name'] ?? 'Customer',
            'phone': def['phone'] ?? authRepo.currentUser?['phone'] ?? '',
            'address': fullAddr.isNotEmpty ? fullAddr : 'Delivery Address',
            'latitude': def['latitude'],
            'longitude': def['longitude'],
          };
        });
      }
    } catch (e) {
      debugPrint('[CheckoutSummaryPage] Error loading address: $e');
    }
  }

  void _incrementQuantity(int index) {
    setState(() {
      _summaryItems[index]['quantity']++;
    });
  }

  void _decrementQuantity(int index) {
    setState(() {
      if (_summaryItems[index]['quantity'] > 1) {
        _summaryItems[index]['quantity']--;
      }
    });
  }

  String _formatCurrency(int amount) {
    String result = amount.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');
    return 'Rs $result';
  }

  Future<void> _placeOrder() async {
    if (!CubePod.get<AuthRepository>().isLoggedIn || _summaryItems.isEmpty) return;
    
    setState(() => _isProcessing = true);
    try {
      // Capture live buyer device coordinates via Geolocator
      double userLat = 27.7172;
      double userLng = 85.3240;
      String deviceAddress = 'Current Device GPS Location';

      try {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
          final pos = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.medium,
            timeLimit: const Duration(seconds: 4),
          );
          userLat = pos.latitude;
          userLng = pos.longitude;
          deviceAddress = 'GPS: ${userLat.toStringAsFixed(4)}, ${userLng.toStringAsFixed(4)} (Verified)';
        }
      } catch (geoErr) {
        debugPrint('[CheckoutSummary] Geolocator fallback: $geoErr');
      }

      // Destination coordinates (where package will be delivered)
      final destLat = (_selectedAddress['latitude'] as num?)?.toDouble() ?? 27.7025;
      final destLng = (_selectedAddress['longitude'] as num?)?.toDouble() ?? 85.3120;
      final destAddress = _selectedAddress['address']?.toString() ?? 'Home Delivery Address';

      await CubePod.get<OrderRepository>().placeOrder(
        addressId: _selectedAddress['id']?.toString(),
        deliverySlot: 'Standard',
        paymentMethod: 'Cash on Delivery',
        slotFeePaise: 0,
        userLatitude: userLat,
        userLongitude: userLng,
        deviceLocationAddress: deviceAddress,
        destinationAddress: destAddress,
        destinationLatitude: destLat,
        destinationLongitude: destLng,
        items: _summaryItems,
      );
      CubePod.get<CartState>().cartItems.value = [];

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('Order placed successfully!', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            backgroundColor: const Color(0xFF42A769),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        );
        Navigator.pop(context, true); // Return true so CartPage can refresh
      }
    } catch (e) {
      debugPrint('Error placing order: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to place order!'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    int subtotal = 0;
    for (var item in _summaryItems) {
      subtotal += (item['price'] as int) * (item['quantity'] as int);
    }
    int taxAndFees = (subtotal * _taxAndFeesRate).round();
    int total = subtotal + widget.deliveryFee + taxAndFees;

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
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF2D2D2D), size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'Checkout Summary',
            style: TextStyle(
              color: Color(0xFF1E2022),
              fontWeight: FontWeight.w900,
              fontSize: 20,
              letterSpacing: -0.5,
            ),
          ),
          centerTitle: true,
        ),
        body: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          children: [
            // Section 1: Delivery Address
            const Text(
              'Delivery Address',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E2022),
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SavedAddressesPage(isSelecting: true),
                  ),
                );
                if (result != null && result is Map<String, dynamic>) {
                  final full = result['address'] ?? '${result['street'] ?? ''} ${result['details'] ?? ''}'.trim();
                  setState(() {
                    _selectedAddress = {
                      ...result,
                      'address': full.isNotEmpty ? full : 'Delivery Address',
                    };
                  });
                }
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F8FA),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.location_on_rounded,
                      color: Color(0xFF185B3A),
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (_selectedAddress['label'] ?? 'Delivery Address').toString(),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2D2D2D),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            (_selectedAddress['address'] ?? '${_selectedAddress['street'] ?? ''} ${_selectedAddress['details'] ?? ''}'.trim()).toString(),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.grey,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Section 2: Products in Cart
            const Text(
              'Products in Cart',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E2022),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F8FA),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: List.generate(_summaryItems.length, (index) {
                  final item = _summaryItems[index];
                  final isLast = index == _summaryItems.length - 1;

                  return Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            height: 60,
                            width: 60,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
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
                                Text(
                                  item['title'] as String,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2D2D2D),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item['unit'] as String,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _formatCurrency((item['price'] as int) * (item['quantity'] as int)),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2D2D2D),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Quantity selector
                          Row(
                            children: [
                              GestureDetector(
                                onTap: () => _decrementQuantity(index),
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF1E2022),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.remove,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                '${item['quantity']}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2D2D2D),
                                ),
                              ),
                              const SizedBox(width: 12),
                              GestureDetector(
                                onTap: () => _incrementQuantity(index),
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF1E2022),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.add,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (!isLast) const SizedBox(height: 16),
                    ],
                  );
                }),
              ),
            ),
            const SizedBox(height: 24),

            // Section 3: Bill Details
            const Text(
              'Bill Details',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E2022),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F8FA),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
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
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Delivery Fee',
                        style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w500),
                      ),
                      Text(
                        _formatCurrency(widget.deliveryFee),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF2D2D2D)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Tax & Other Fees',
                        style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w500),
                      ),
                      Text(
                        _formatCurrency(taxAndFees),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF2D2D2D)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Total card container
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F8FA),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E2022),
                    ),
                  ),
                  Text(
                    _formatCurrency(total),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1E2022),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Promo input field
            Container(
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFF7F8FA),
                borderRadius: BorderRadius.circular(24),
              ),
              padding: const EdgeInsets.only(left: 20, right: 4),
              child: Row(
                children: [
                  const Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Add Promo',
                        hintStyle: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ),
                  ),
                  Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E2022),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Center(
                      child: Text(
                        'Apply',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Bottom Action Button
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _isProcessing ? null : () => _placeOrder(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF42A769),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: _isProcessing
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Place Order',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
