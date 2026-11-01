import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:app/features/customer/profile/screens/savedAddressesPage.dart';
import 'package:app/features/customer/home/screens/locationPickerPage.dart';
import 'package:app/features/customer/orders/screens/orderTrackingPage.dart';
import 'package:app/features/customer/cart/providers/cartState.dart';
import 'package:app/features/customer/cart/providers/cartProviders.dart';
import 'package:app/core/di/injection.dart';

class CheckoutSummaryPage extends ConsumerStatefulWidget {
  final List<Map<String, dynamic>> items;
  final int deliveryFee;

  const CheckoutSummaryPage({
    super.key,
    required this.items,
    required this.deliveryFee,
  });

  @override
  ConsumerState<CheckoutSummaryPage> createState() => _CheckoutSummaryPageState();
}

class _CheckoutSummaryPageState extends ConsumerState<CheckoutSummaryPage> {
  List<Map<String, dynamic>> get _summaryItems =>
      ref.read(checkoutSummaryItemsProvider) ??
      widget.items.map((item) => Map<String, dynamic>.from(item)).toList();
  final double _taxAndFeesRate = 0.05; // 5% tax
  bool get _isProcessing => ref.read(checkoutSummaryIsProcessingProvider);
  bool get _hasValidAddress => ref.read(checkoutSummaryHasValidAddressProvider);

  Map<String, dynamic> get _selectedAddress =>
      ref.read(checkoutSummarySelectedAddressProvider);

  String get _selectedPaymentMethod =>
      ref.read(checkoutSummarySelectedPaymentMethodProvider);
  final List<Map<String, dynamic>> _paymentMethods = const [
    {
      'name': 'Cash on Delivery',
      'subtitle': 'Pay with cash upon package delivery',
      'icon': Icons.payments_rounded,
    },
    {
      'name': 'eSewa / Khalti Wallet',
      'subtitle': 'Instant digital wallet payment',
      'icon': Icons.account_balance_wallet_rounded,
    },
    {
      'name': 'Debit / Credit Card',
      'subtitle': 'Visa, Mastercard & UnionPay',
      'icon': Icons.credit_card_rounded,
    },
  ];

  String get _selectedSlot => ref.read(checkoutSummarySelectedSlotProvider);
  int get _selectedSlotFeeRs => ref.read(checkoutSummarySelectedSlotFeeRsProvider);
  final List<Map<String, dynamic>> _deliverySlots = const [
    {'label': 'Standard (25–35 mins)', 'fee_rs': 0, 'icon': Icons.bolt_rounded},
    {'label': 'Express (15–20 mins)', 'fee_rs': 20, 'icon': Icons.rocket_launch_rounded},
    {'label': 'Evening Slot (5 PM – 8 PM)', 'fee_rs': 0, 'icon': Icons.schedule_rounded},
  ];

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(checkoutSummaryItemsProvider.notifier).state =
          widget.items.map((item) => Map<String, dynamic>.from(item)).toList();
      _loadUserAddress();
    });
  }

  Future<void> _loadUserAddress() async {
    try {
      final userRepo = ref.read(userRepositoryProvider);
      final authRepo = ref.read(authRepositoryProvider);

      // 1. Try selected address from storage
      final saved = await userRepo.getSelectedAddress();
      if (saved != null && mounted) {
        final addrStr = (saved['address'] ?? '${saved['street'] ?? ''} ${saved['details'] ?? ''}'.trim()).toString();
        if (addrStr.isNotEmpty) {
          ref.read(checkoutSummarySelectedAddressProvider.notifier).state = {
            ...saved,
            'address': addrStr,
          };
          ref.read(checkoutSummaryHasValidAddressProvider.notifier).state = true;
          return;
        }
      }

      // 2. Try cached or remote addresses
      final cached = await userRepo.getCachedAddresses();
      final list = cached.isNotEmpty
          ? cached
          : (authRepo.isLoggedIn ? await userRepo.fetchAddresses(authRepo.authHeaders) : []);

      if (list.isNotEmpty && mounted) {
        final def = list.firstWhere((a) => a['is_default'] == true, orElse: () => list.first);
        final fullAddr = '${def['street'] ?? ''} ${def['details'] ?? ''}'.trim();
        ref.read(checkoutSummarySelectedAddressProvider.notifier).state = {
          'id': def['id'],
          'label': def['label'] ?? 'Home',
          'name': def['name'] ?? authRepo.currentUser?['name'] ?? 'Customer',
          'phone': def['phone'] ?? authRepo.currentUser?['phone'] ?? '',
          'address': fullAddr.isNotEmpty ? fullAddr : 'Delivery Address',
          'latitude': def['latitude'],
          'longitude': def['longitude'],
        };
        ref.read(checkoutSummaryHasValidAddressProvider.notifier).state = true;
      }
    } catch (e) {
      debugPrint('[CheckoutSummaryPage] Error loading address: $e');
    }
  }

  Future<void> _chooseAddress() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SavedAddressesPage(isSelecting: true),
      ),
    );
    if (result != null && result is Map<String, dynamic>) {
      final full = (result['address'] ?? '${result['street'] ?? ''} ${result['details'] ?? ''}'.trim()).toString();
      ref.read(checkoutSummarySelectedAddressProvider.notifier).state = {
        ...result,
        'address': full.isNotEmpty ? full : 'Delivery Address',
      };
      ref.read(checkoutSummaryHasValidAddressProvider.notifier).state = true;
    } else {
      await _loadUserAddress();
    }
  }

  Future<void> _pickAddressOnMap() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const LocationPickerPage(isAddingNewAddress: true),
      ),
    );
    await _loadUserAddress();
  }

  void _incrementQuantity(int index) {
    final items = _summaryItems.map((item) => Map<String, dynamic>.from(item)).toList();
    items[index]['quantity'] = (items[index]['quantity'] as int) + 1;
    ref.read(checkoutSummaryItemsProvider.notifier).state = items;
  }

  void _decrementQuantity(int index) {
    final items = _summaryItems.map((item) => Map<String, dynamic>.from(item)).toList();
    if ((items[index]['quantity'] as int) > 1) {
      items[index]['quantity'] = (items[index]['quantity'] as int) - 1;
      ref.read(checkoutSummaryItemsProvider.notifier).state = items;
    }
  }

  String _formatCurrency(int amount) {
    String result = amount.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');
    return 'Rs $result';
  }

  Future<void> _placeOrder() async {
    if (!ref.read(authRepositoryProvider).isLoggedIn || _summaryItems.isEmpty) return;

    if (!_hasValidAddress) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select or add a delivery address first'),
          backgroundColor: Colors.orange,
        ),
      );
      await _chooseAddress();
      if (!_hasValidAddress) return;
    }

    ref.read(checkoutSummaryIsProcessingProvider.notifier).state = true;
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

      await ref.read(customerOrderRepositoryProvider).placeOrder(
        addressId: _selectedAddress['id']?.toString(),
        deliverySlot: _selectedSlot,
        paymentMethod: _selectedPaymentMethod,
        slotFeePaise: _selectedSlotFeeRs * 100,
        userLatitude: userLat,
        userLongitude: userLng,
        deviceLocationAddress: deviceAddress,
        destinationAddress: destAddress,
        destinationLatitude: destLat,
        destinationLongitude: destLng,
        items: _summaryItems,
      );
      ref.read(cartStateProvider).cartItems = [];

      // Fetch the newly placed order so we can offer direct live tracking
      Map<String, dynamic>? latestOrder;
      try {
        final userId = ref.read(authRepositoryProvider).currentUser?['id']?.toString() ?? '';
        if (userId.isNotEmpty) {
          final currentOrders = await ref.read(customerOrderRepositoryProvider).fetchCurrentOrders(userId);
          if (currentOrders.isNotEmpty) {
            latestOrder = currentOrders.first;
          }
        }
      } catch (_) {}

      if (!mounted) return;

      final trackNow = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xFFE8F5E9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF42A769),
                  size: 48,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Order Placed Successfully!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1E2022),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Delivering to ${_selectedAddress['label'] ?? 'Address'}\nPayment: $_selectedPaymentMethod',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF185B3A),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.my_location_rounded, color: Colors.white, size: 18),
                  label: const Text(
                    'Track Order Live',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text(
                  'View in My Orders',
                  style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      );

      if (!mounted) return;
      if (trackNow == true && latestOrder != null) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OrderTrackingPage(order: latestOrder!),
          ),
        );
      }
      if (mounted) {
        Navigator.pop(context, true); // Return true so CartPage switches to Current Order tab
      }
    } catch (e) {
      debugPrint('Error placing order: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to place order: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) ref.read(checkoutSummaryIsProcessingProvider.notifier).state = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(checkoutSummaryItemsProvider);
    ref.watch(checkoutSummaryIsProcessingProvider);
    ref.watch(checkoutSummaryHasValidAddressProvider);
    ref.watch(checkoutSummarySelectedAddressProvider);
    ref.watch(checkoutSummarySelectedPaymentMethodProvider);
    ref.watch(checkoutSummarySelectedSlotProvider);
    ref.watch(checkoutSummarySelectedSlotFeeRsProvider);
    int subtotal = 0;
    for (var item in _summaryItems) {
      subtotal += (item['price'] as int) * (item['quantity'] as int);
    }
    int taxAndFees = (subtotal * _taxAndFeesRate).round();
    int total = subtotal + widget.deliveryFee + _selectedSlotFeeRs + taxAndFees;

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
            'Address & Payment',
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '1. Delivery Address',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E2022),
                  ),
                ),
                TextButton.icon(
                  onPressed: _pickAddressOnMap,
                  icon: const Icon(Icons.add_location_alt_outlined, size: 16, color: Color(0xFF185B3A)),
                  label: const Text(
                    'Pin on Map',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF185B3A),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _chooseAddress,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F8FA),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _hasValidAddress
                        ? const Color(0xFF185B3A).withValues(alpha: 0.35)
                        : Colors.orange.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5EE),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.location_on_rounded,
                        color: Color(0xFF185B3A),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                (_selectedAddress['label'] ?? 'Delivery Address').toString(),
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2D2D2D),
                                ),
                              ),
                              if ((_selectedAddress['phone'] ?? '').toString().isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Text(
                                  '• ${_selectedAddress['phone']}',
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            (_selectedAddress['address'] ??
                                    '${_selectedAddress['street'] ?? ''} ${_selectedAddress['details'] ?? ''}'.trim())
                                .toString(),
                            style: TextStyle(
                              fontSize: 12.5,
                              color: _hasValidAddress ? Colors.grey.shade700 : Colors.orange.shade800,
                              fontWeight: _hasValidAddress ? FontWeight.normal : FontWeight.w600,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'Change',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF185B3A),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Section 2: Delivery Slot
            const Text(
              '2. Delivery Speed & Slot',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E2022),
              ),
            ),
            const SizedBox(height: 10),
            Column(
              children: _deliverySlots.map((slot) {
                final label = slot['label'] as String;
                final feeRs = slot['fee_rs'] as int;
                final icon = slot['icon'] as IconData;
                final isSelected = _selectedSlot == label;
                return GestureDetector(
                  onTap: () {
                    ref.read(checkoutSummarySelectedSlotProvider.notifier).state = label;
                    ref.read(checkoutSummarySelectedSlotFeeRsProvider.notifier).state = feeRs;
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFE8F5EE) : const Color(0xFFF7F8FA),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? const Color(0xFF185B3A) : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          icon,
                          size: 20,
                          color: isSelected ? const Color(0xFF185B3A) : Colors.grey.shade600,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                              color: const Color(0xFF1E2022),
                            ),
                          ),
                        ),
                        Text(
                          feeRs == 0 ? 'FREE' : '+Rs $feeRs',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? const Color(0xFF185B3A) : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 18),

            // Section 3: Payment Method
            const Text(
              '3. Payment Method',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E2022),
              ),
            ),
            const SizedBox(height: 10),
            Column(
              children: _paymentMethods.map((method) {
                final name = method['name'] as String;
                final subtitle = method['subtitle'] as String;
                final icon = method['icon'] as IconData;
                final isSelected = _selectedPaymentMethod == name;
                return GestureDetector(
                  onTap: () {
                    ref.read(checkoutSummarySelectedPaymentMethodProvider.notifier).state = name;
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFE8F5EE) : const Color(0xFFF7F8FA),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? const Color(0xFF185B3A) : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            icon,
                            size: 20,
                            color: isSelected ? const Color(0xFF185B3A) : Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E2022),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                subtitle,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          isSelected
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_off_rounded,
                          color: isSelected ? const Color(0xFF185B3A) : Colors.grey.shade400,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 18),

            // Section 4: Products in Cart
            const Text(
              '4. Order Items',
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

            // Section 5: Bill Details
            const Text(
              'Bill Summary',
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
                        _formatCurrency(widget.deliveryFee + _selectedSlotFeeRs),
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
                    'Total Payable',
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
            const SizedBox(height: 24),

            // Bottom Action Button
            SizedBox(
              height: 54,
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
                    : Text(
                        'Confirm & Place Order • ${_formatCurrency(total)}',
                        style: const TextStyle(
                          fontSize: 15.5,
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
