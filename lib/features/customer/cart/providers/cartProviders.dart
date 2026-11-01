import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── CartPage Providers ──
final cartSelectedTabProvider = StateProvider.autoDispose<int>((ref) => 0);

final cartCurrentOrdersProvider =
    StateProvider.autoDispose<List<Map<String, dynamic>>>((ref) => []);

final cartIsLoadingOrdersProvider = StateProvider.autoDispose<bool>((ref) => false);

final cartPreviousOrdersProvider =
    StateProvider.autoDispose<List<Map<String, dynamic>>>((ref) => []);

final cartIsLoadingPreviousOrdersProvider =
    StateProvider.autoDispose<bool>((ref) => false);

// ── CheckoutPage Providers ──
final checkoutCurrentStepProvider = StateProvider.autoDispose<int>((ref) => 0);

final checkoutSelectedAddressIndexProvider = StateProvider.autoDispose<int>((ref) => 0);

final checkoutIsLoadingAddressesProvider = StateProvider.autoDispose<bool>((ref) => true);

final checkoutAddressesProvider =
    StateProvider.autoDispose<List<Map<String, dynamic>>>((ref) => []);

final checkoutSelectedSlotIndexProvider = StateProvider.autoDispose<int>((ref) => 0);

final checkoutSlotsProvider =
    StateProvider.autoDispose<List<Map<String, dynamic>>>((ref) => [
          {
            'title': 'Standard Delivery (Today)',
            'price': 'Rs 20',
            'isFree': false,
          },
          {
            'title': 'Express Delivery (Within 1 Hour)',
            'price': 'Rs 50',
            'isFree': false,
          },
          {
            'title': 'Morning Slot (8:00 AM - 11:00 AM)',
            'price': 'Rs 20',
            'isFree': false,
          },
          {
            'title': 'Evening Slot (5:00 PM - 8:00 PM)',
            'price': 'Rs 20',
            'isFree': false,
          },
        ]);

final checkoutSelectedMethodIndexProvider = StateProvider.autoDispose<int>((ref) => 0);

// ── CheckoutSummaryPage Providers ──
final checkoutSummaryItemsProvider =
    StateProvider.autoDispose<List<Map<String, dynamic>>?>((ref) => null);

final checkoutSummaryIsProcessingProvider = StateProvider.autoDispose<bool>((ref) => false);

final checkoutSummaryHasValidAddressProvider =
    StateProvider.autoDispose<bool>((ref) => false);

final checkoutSummarySelectedAddressProvider =
    StateProvider.autoDispose<Map<String, dynamic>>((ref) => {
          'label': 'Home',
          'name': 'Customer',
          'phone': '',
          'address': 'Tap to select or add delivery address',
        });

final checkoutSummarySelectedPaymentMethodProvider =
    StateProvider.autoDispose<String>((ref) => 'Cash on Delivery');

final checkoutSummarySelectedSlotProvider =
    StateProvider.autoDispose<String>((ref) => 'Standard (25–35 mins)');

final checkoutSummarySelectedSlotFeeRsProvider =
    StateProvider.autoDispose<int>((ref) => 0);
