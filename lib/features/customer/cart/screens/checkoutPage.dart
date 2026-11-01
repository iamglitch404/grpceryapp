import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/core/network/httpClient.dart' as http;
import 'dart:convert';
import 'package:app/core/config/appConfig.dart';
import 'package:app/core/di/injection.dart';
import 'package:app/features/customer/home/screens/locationPickerPage.dart';
import 'package:app/features/customer/cart/providers/cartProviders.dart';
import 'orderSuccessPage.dart';


class CheckoutPage extends ConsumerStatefulWidget {
  final List<Map<String, dynamic>> items;
  final int deliveryFee;

  const CheckoutPage({
    super.key,
    required this.items,
    required this.deliveryFee,
  });

  @override
  ConsumerState<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends ConsumerState<CheckoutPage> {
  late PageController _pageController;
  int get _currentStep => ref.read(checkoutCurrentStepProvider);

  // --- Address State ---
  int get _selectedAddressIndex => ref.read(checkoutSelectedAddressIndexProvider);
  bool get _isLoadingAddresses => ref.read(checkoutIsLoadingAddressesProvider);
  List<Map<String, dynamic>> get _addresses => ref.read(checkoutAddressesProvider);

  // --- Delivery State ---
  int get _selectedSlotIndex => ref.read(checkoutSelectedSlotIndexProvider);
  List<Map<String, dynamic>> get _slots => ref.read(checkoutSlotsProvider);

  // --- Payment State ---
  int get _selectedMethodIndex => ref.read(checkoutSelectedMethodIndexProvider);
  final TextEditingController _couponController = TextEditingController();
  final List<Map<String, dynamic>> _paymentMethods = [
    {
      'title': 'Cash on Delivery',
      'icon': Icons.payments_rounded,
    },
    {
      'title': 'Debit / Credit Card',
      'icon': Icons.credit_card_rounded,
    },
    {
      'title': 'eSewa / Khalti / Digital Wallet',
      'icon': Icons.account_balance_wallet_rounded,
    },
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    Future.microtask(() {
      _fetchAddresses();
      _fetchCheckoutConfig();
    });
  }

  Future<void> _fetchCheckoutConfig() async {
    try {
      final response = await http.get(Uri.parse('${AppConfig.apiUrl}/checkout-config'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          final rawSlots = List<Map<String, dynamic>>.from(data['deliverySlots'] ?? []);
          if (rawSlots.isNotEmpty) {
            ref.read(checkoutSlotsProvider.notifier).state = rawSlots
                .map((s) => {
                      'title': s['slot_time'] ?? 'Unknown',
                      'price': 'Rs 20',
                      'isFree': false,
                    })
                .toList();
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching checkout config: $e');
    }
  }

  Future<void> _fetchAddresses() async {
    final userRepo = ref.read(userRepositoryProvider);
    
    // 1. Read cached addresses immediately (zero lag)
    final cached = await userRepo.getCachedAddresses();
    if (cached.isNotEmpty && mounted) {
      ref.read(checkoutAddressesProvider.notifier).state = cached
          .map((a) => {
                'id': a['id'],
                'label': a['label'],
                'isDefault': a['is_default'],
                'address': '${a['street'] ?? ''}\n${a['details'] ?? ''}'.trim(),
                'name': a['name'] ?? '',
                'phone': a['phone'] ?? '',
              })
          .toList();
      ref.read(checkoutIsLoadingAddressesProvider.notifier).state = false;
    }

    // 2. Fetch fresh from server
    try {
      final addrs = await userRepo.fetchAddresses(ref.read(authRepositoryProvider).authHeaders);
      if (mounted) {
        ref.read(checkoutAddressesProvider.notifier).state = addrs
            .map((a) => {
                  'id': a['id'],
                  'label': a['label'],
                  'isDefault': a['is_default'],
                  'address': '${a['street'] ?? ''}\n${a['details'] ?? ''}'.trim(),
                  'name': a['name'] ?? '',
                  'phone': a['phone'] ?? '',
                })
            .toList();
        ref.read(checkoutIsLoadingAddressesProvider.notifier).state = false;
      }
    } catch (e) {
      debugPrint('Error fetching addresses: $e');
      if (mounted) ref.read(checkoutIsLoadingAddressesProvider.notifier).state = false;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _couponController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.pop(context);
    }
  }

  // --- Bill Calculations ---
  int get _itemTotal {
    return widget.items.fold(0, (sum, item) {
      final price = double.tryParse(item['price'].toString().replaceAll(RegExp(r'[^0-9.]'), ''))?.toInt() ?? 0;
      final quantity = item['quantity'] as int? ?? 1;
      return sum + (price * quantity);
    });
  }

  int get _originalTotal {
    return widget.items.fold(0, (sum, item) {
      final originalPrice = double.tryParse(item['originalPrice'].toString().replaceAll(RegExp(r'[^0-9.]'), ''))?.toInt() ?? 0;
      final price = double.tryParse(item['price'].toString().replaceAll(RegExp(r'[^0-9.]'), ''))?.toInt() ?? 0;
      final actualPrice = originalPrice > 0 ? originalPrice : price;
      final quantity = item['quantity'] as int? ?? 1;
      return sum + (actualPrice * quantity);
    });
  }

  int get _savings => _originalTotal - _itemTotal;
  int get _platformFee => 10;
  int get _slotFee => _slots[_selectedSlotIndex]['isFree'] ? 0 : 20;
  int get _totalAmount => _itemTotal + widget.deliveryFee + _platformFee + _slotFee;

  @override
  Widget build(BuildContext context) {
    ref.watch(checkoutCurrentStepProvider);
    ref.watch(checkoutSelectedAddressIndexProvider);
    ref.watch(checkoutIsLoadingAddressesProvider);
    ref.watch(checkoutAddressesProvider);
    ref.watch(checkoutSelectedSlotIndexProvider);
    ref.watch(checkoutSlotsProvider);
    ref.watch(checkoutSelectedMethodIndexProvider);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: _previousStep,
        ),
        title: const Text(
          'Checkout',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: Column(
        children: [
          _buildTopStepper(),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(), // Disable manual swipe
              onPageChanged: (index) {
                ref.read(checkoutCurrentStepProvider.notifier).state = index;
              },
              children: [
                _buildAddressStep(),
                _buildDeliveryStep(),
                _buildPaymentStep(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // SHARED: Stepper
  // ==========================================
  Widget _buildTopStepper() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 40),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepIcon(1, 'Address', _currentStep >= 0, isCompleted: _currentStep > 0),
          Expanded(child: _buildStepLine(_currentStep > 0)),
          _buildStepIcon(2, 'Delivery', _currentStep >= 1, isCompleted: _currentStep > 1),
          Expanded(child: _buildStepLine(_currentStep > 1)),
          _buildStepIcon(3, 'Payment', _currentStep >= 2, isCompleted: false),
        ],
      ),
    );
  }

  Widget _buildStepIcon(int step, String label, bool isActive, {bool isCompleted = false}) {
    return Column(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF2E8B57) : Colors.grey[200],
            shape: BoxShape.circle,
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check, color: Colors.white, size: 16)
                : Text(
                    step.toString(),
                    style: TextStyle(
                      color: isActive ? Colors.white : Colors.grey[500],
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
            color: isActive ? Colors.black87 : Colors.grey[500],
          ),
        ),
      ],
    );
  }

  Widget _buildStepLine(bool isCompleted) {
    return Container(
      height: 1,
      margin: const EdgeInsets.only(top: 12, left: 8, right: 8),
      color: isCompleted ? const Color(0xFF2E8B57) : Colors.grey[300],
    );
  }

  // ==========================================
  // STEP 1: Address
  // ==========================================
  Widget _buildAddressStep() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Delivery Address',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const LocationPickerPage(isAddingNewAddress: true),
                          ),
                        );
                      },
                      icon: const Icon(Icons.add, size: 16, color: Color(0xFF2E8B57)),
                      label: const Text(
                        'Add New',
                        style: TextStyle(
                          color: Color(0xFF2E8B57),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_isLoadingAddresses)
                  const Center(child: CircularProgressIndicator(color: Color(0xFF2E8B57)))
                else if (_addresses.isEmpty)
                  const Center(child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Text('No addresses found. Please add a new delivery address.'),
                  ))
                else
                  ...List.generate(_addresses.length, (index) {
                    return _buildAddressCard(index, _addresses[index]);
                  }),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _nextStep,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E8B57),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Deliver Here',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAddressCard(int index, Map<String, dynamic> address) {
    final isSelected = _selectedAddressIndex == index;

    return GestureDetector(
      onTap: () {
        ref.read(checkoutSelectedAddressIndexProvider.notifier).state = index;
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF4F9F6) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF2E8B57) : Colors.grey.shade300,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                color: isSelected ? const Color(0xFF2E8B57) : Colors.grey[400],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(
                          address['name'],
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Colors.black87,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            address['label'],
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[700],
                            ),
                          ),
                        ),
                        if (address['isDefault'])
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'DEFAULT',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2E8B57),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      address['address'],
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Phone: ${address['phone']}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20, color: Colors.black54),
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // STEP 2: Delivery
  // ==========================================
  Widget _buildDeliveryStep() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select Delivery Slot',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                  ...List.generate(_slots.length, (index) {
                    return _buildSlotCard(index, _slots[index]);
                  }),
                const SizedBox(height: 24),
                const Text(
                  'Order Summary',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                ...widget.items.map((item) => _buildOrderItem(item)),
                const SizedBox(height: 24),
                _buildBillDetails(),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _nextStep,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E8B57),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Continue to Payment',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSlotCard(int index, Map<String, dynamic> slot) {
    final isSelected = _selectedSlotIndex == index;

    return GestureDetector(
      onTap: () {
        ref.read(checkoutSelectedSlotIndexProvider.notifier).state = index;
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF2E8B57) : Colors.grey.shade300,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: isSelected ? const Color(0xFF2E8B57) : Colors.grey[400],
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                slot['title'],
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 14,
                  color: Colors.black87,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              slot['price'],
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: slot['isFree'] ? const Color(0xFF2E8B57) : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderItem(Map<String, dynamic> item) {
    final String imagePath = item['image'] ?? 'assets/images/placeholder.jpg';
    final int quantity = item['quantity'] ?? 1;
    final int price = double.tryParse(item['price'].toString().replaceAll(RegExp(r'[^0-9.]'), ''))?.toInt() ?? 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              image: DecorationImage(
                image: AssetImage(imagePath),
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['title'] ?? 'Product',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$quantity x ${item['unit'] ?? '1 unit'}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Text(
            'Rs ${price * quantity}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF2E8B57),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBillDetails() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          _buildBillRow('Item Total', 'Rs $_itemTotal'),
          const SizedBox(height: 12),
          _buildBillRow(
            'Delivery Charges', 
            widget.deliveryFee == 0 ? 'FREE' : 'Rs ${widget.deliveryFee}',
            isStrikethrough: widget.deliveryFee == 0,
            originalValue: widget.deliveryFee == 0 ? 'Rs 40' : null,
          ),
          const SizedBox(height: 12),
          _buildBillRow('Platform Fee', 'Rs $_platformFee'),
          if (_slotFee > 0) ...[
            const SizedBox(height: 12),
            _buildBillRow('Slot Fee', 'Rs $_slotFee'),
          ],
          const SizedBox(height: 12),
          _buildBillRow('You Save', '- Rs $_savings', isGreen: true),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Amount',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.black87,
                ),
              ),
              Text(
                'Rs $_totalAmount',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Color(0xFF2E8B57),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBillRow(String label, String value, {bool isGreen = false, bool isStrikethrough = false, String? originalValue}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[700],
          ),
        ),
        Row(
          children: [
            if (originalValue != null)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  originalValue,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
              ),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isGreen || isStrikethrough ? FontWeight.bold : FontWeight.w500,
                color: isGreen || isStrikethrough ? const Color(0xFF2E8B57) : Colors.black87,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ==========================================
  // STEP 3: Payment
  // ==========================================
  Widget _buildPaymentStep() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select Payment Method',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                  ...List.generate(_paymentMethods.length, (index) {
                    return _buildPaymentCard(index, _paymentMethods[index]);
                  }),
                const SizedBox(height: 24),
                const Text(
                  'Apply Coupon',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                _buildCouponField(),
                const SizedBox(height: 24),
                _buildFinalBill(),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _placeOrder,
                icon: const Icon(Icons.lock_outline, size: 18, color: Colors.white),
                label: Text(
                  'Pay Rs $_totalAmount',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E8B57),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _placeOrder() async {
    if (_addresses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a delivery address'), backgroundColor: Colors.red),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: Color(0xFF2E8B57))),
    );

    try {
      final addressId = _addresses[_selectedAddressIndex]['id'];
      final slotTitle = _slots[_selectedSlotIndex]['title'];
      final paymentMethod = _paymentMethods[_selectedMethodIndex]['title'];
      final slotFeePaise = _slotFee * 100;

      final response = await http.post(
        Uri.parse('${AppConfig.apiUrl}/orders'),
        headers: ref.read(authRepositoryProvider).authHeaders,
        body: jsonEncode({
          'address_id': addressId,
          'delivery_slot': slotTitle,
          'payment_method': paymentMethod,
          'slot_fee_paise': slotFeePaise,
        }),
      );

      final data = jsonDecode(response.body);
      
      // Pop loading dialog
      if (mounted) Navigator.pop(context);

      if (response.statusCode == 201 && data['success'] == true) {
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => OrderSuccessPage(
                totalAmount: data['data']['total_paise'] ~/ 100,
                paymentMethod: paymentMethod,
                selectedSlot: slotTitle,
                selectedAddress: _addresses[_selectedAddressIndex]['address'],
                orderId: data['data']['order_id'],
              ),
            ),
            (route) => false,
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['error'] ?? 'Order failed'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); // Pop loading dialog
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildPaymentCard(int index, Map<String, dynamic> method) {
    final isSelected = _selectedMethodIndex == index;

    return GestureDetector(
      onTap: () {
        ref.read(checkoutSelectedMethodIndexProvider.notifier).state = index;
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF2E8B57) : Colors.grey.shade300,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: isSelected ? const Color(0xFF2E8B57) : Colors.grey[400],
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                method['title'],
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Colors.black87,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            if (method['icon'] != null)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(method['icon'] as IconData, color: Colors.indigo, size: 20),
              )
            else if (method['icons'] != null)
              Row(
                children: (method['icons'] as List<String>).map((iconPath) {
                  return Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(4),
                        image: DecorationImage(
                          image: AssetImage(iconPath),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCouponField() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _couponController,
            decoration: InputDecoration(
              hintText: 'Enter code',
              hintStyle: TextStyle(color: Colors.grey[400]),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF2E8B57)),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton(
          onPressed: () {
            // Apply coupon logic
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2E8B57),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            elevation: 0,
          ),
          child: const Text(
            'Apply',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFinalBill() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F9F6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Amount',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                'Rs $_totalAmount',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'You Save',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF2E8B57),
                ),
              ),
              Text(
                'Rs $_savings',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2E8B57),
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'To Pay',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.black87,
                ),
              ),
              Text(
                'Rs $_totalAmount',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                  color: Color(0xFF2E8B57),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
