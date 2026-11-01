import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:app/features/delivery/dashboard/providers/deliveryDashboardProviders.dart';
import 'package:app/features/delivery/orders/providers/deliveryOrderProviders.dart';

void main() {
  group('Delivery Providers Unit Tests', () {
    test('Delivery dashboard tab provider updates correctly', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(deliveryDashboardTabIndexProvider), 0);
      container.read(deliveryDashboardTabIndexProvider.notifier).state = 1;
      expect(container.read(deliveryDashboardTabIndexProvider), 1);
    });

    test('Assign partner providers update state correctly', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(assignPartnerSearchQueryProvider), '');
      container.read(assignPartnerSearchQueryProvider.notifier).state = 'Ramesh';
      expect(container.read(assignPartnerSearchQueryProvider), 'Ramesh');

      expect(container.read(assigningPartnerIdProvider), isNull);
      container.read(assigningPartnerIdProvider.notifier).state = 'partner-456';
      expect(container.read(assigningPartnerIdProvider), 'partner-456');
    });

    test('DeliveryNavigationState model copyWith works properly', () {
      const initial = DeliveryNavigationState();
      expect(initial.isLoadingRoute, true);
      expect(initial.currentStepIndex, 0);

      const driverLoc = LatLng(27.71, 85.32);
      final updated = initial.copyWith(
        isLoadingRoute: false,
        driverLocation: driverLoc,
        totalDistanceMeters: 4500.0,
        currentStepIndex: 2,
      );

      expect(updated.isLoadingRoute, false);
      expect(updated.driverLocation, driverLoc);
      expect(updated.totalDistanceMeters, 4500.0);
      expect(updated.currentStepIndex, 2);
    });
  });
}

