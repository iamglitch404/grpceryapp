import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:app/features/admin/dashboard/providers/dashboardProviders.dart';
import 'package:app/features/admin/orders/providers/adminOrderProviders.dart';

void main() {
  group('Admin Providers Unit Tests', () {
    test('Admin navigation and leaderboard providers work correctly', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(adminMainTabIndexProvider), 0);
      container.read(adminMainTabIndexProvider.notifier).state = 2;
      expect(container.read(adminMainTabIndexProvider), 2);

      expect(container.read(adminLeaderboardSelectedTabProvider), 'customer');
      container.read(adminLeaderboardSelectedTabProvider.notifier).state = 'deliveryman';
      expect(container.read(adminLeaderboardSelectedTabProvider), 'deliveryman');

      expect(container.read(adminLeaderboardIsRefreshingProvider), false);
      container.read(adminLeaderboardIsRefreshingProvider.notifier).state = true;
      expect(container.read(adminLeaderboardIsRefreshingProvider), true);
    });

    test('AdminLocationNotifier sets live location and address', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(adminLocationProvider.notifier);
      const newPoint = LatLng(27.7000, 85.3000);

      notifier.setLocation(point: newPoint, address: 'Patan Durbar Square');
      final state = container.read(adminLocationProvider);

      expect(state.adminPoint, newPoint);
      expect(state.adminAddress, 'Patan Durbar Square');
    });

    test('InDriveOrderMapDialogNotifier configures map dialog state', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(inDriveOrderMapDialogProvider.notifier);

      expect(container.read(inDriveOrderMapDialogProvider).mapLayer, 'standard');
      notifier.toggleMapLayer();
      expect(container.read(inDriveOrderMapDialogProvider).mapLayer, 'satellite');

      expect(container.read(inDriveOrderMapDialogProvider).showOrderItems, false);
      notifier.toggleShowOrderItems();
      expect(container.read(inDriveOrderMapDialogProvider).showOrderItems, true);

      notifier.setRoute(
        points: [const LatLng(27.7, 85.3), const LatLng(27.71, 85.31)],
        distanceKm: 2.5,
        durationMins: 8,
      );

      final updated = container.read(inDriveOrderMapDialogProvider);
      expect(updated.roadRoutePoints.length, 2);
      expect(updated.roadDistanceKm, 2.5);
      expect(updated.roadDurationMins, 8);
    });
  });
}
