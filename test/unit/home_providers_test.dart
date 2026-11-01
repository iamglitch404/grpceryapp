import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:app/features/customer/home/providers/homeProviders.dart';

void main() {
  group('Home Providers Unit Tests', () {
    test('Search and category filter state providers work correctly', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(homeSearchQueryProvider), '');
      container.read(homeSearchQueryProvider.notifier).state = 'Avocado';
      expect(container.read(homeSearchQueryProvider), 'Avocado');

      expect(container.read(homeSelectedCategoryProvider), isNull);
      container.read(homeSelectedCategoryProvider.notifier).state = 'Fruits';
      expect(container.read(homeSelectedCategoryProvider), 'Fruits');
    });

    test('FilterPage state providers work correctly', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(filterPriceRangeProvider), const RangeValues(20, 248));
      container.read(filterPriceRangeProvider.notifier).state = const RangeValues(50, 300);
      expect(container.read(filterPriceRangeProvider), const RangeValues(50, 300));

      expect(container.read(filterSelectedRatingProvider), '5 Stars');
      container.read(filterSelectedRatingProvider.notifier).state = '4 Stars';
      expect(container.read(filterSelectedRatingProvider), '4 Stars');

      expect(container.read(filterVeganFriendlyProvider), 'Yes');
      container.read(filterVeganFriendlyProvider.notifier).state = 'No';
      expect(container.read(filterVeganFriendlyProvider), 'No');
    });

    test('CampaignDealsNotifier updates state properly', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(campaignDealsProvider.notifier);

      expect(container.read(campaignDealsProvider).isLoading, true);
      notifier.setLoading(false);
      expect(container.read(campaignDealsProvider).isLoading, false);

      notifier.setSelectedFilter('BOGO');
      expect(container.read(campaignDealsProvider).selectedFilter, 'BOGO');

      notifier.setSearchQuery('Snacks');
      expect(container.read(campaignDealsProvider).searchQuery, 'Snacks');

      notifier.setProductsAndLoading([{'id': 'prod-1', 'title': 'Mango'}], false);
      expect(container.read(campaignDealsProvider).products.length, 1);
    });

    test('LocationPickerNotifier updates center and layers', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(locationPickerProvider.notifier);
      const newCenter = LatLng(27.7172, 85.3240);

      notifier.update((s) => s.copyWith(
        center: newCenter,
        currentAddress: 'Kathmandu Durbar Square',
        currentMapLayer: 'satellite',
      ));

      final state = container.read(locationPickerProvider);
      expect(state.center, newCenter);
      expect(state.currentAddress, 'Kathmandu Durbar Square');
      expect(state.currentMapLayer, 'satellite');
    });
  });
}

