import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/core/di/injection.dart';

class MyOffersData {
  final List<Map<String, dynamic>> activeOffers;
  final List<Map<String, dynamic>> usedOffers;
  final List<Map<String, dynamic>> expiredOffers;

  const MyOffersData({
    this.activeOffers = const [],
    this.usedOffers = const [],
    this.expiredOffers = const [],
  });
}

final myOffersCopiedCodeProvider = StateProvider.autoDispose<String?>((ref) => null);

final myOffersFutureProvider = FutureProvider.autoDispose<MyOffersData>((ref) async {
  final authRepo = ref.watch(authRepositoryProvider);
  final exploreRepo = ref.watch(exploreRepositoryProvider);
  try {
    final offersData = await exploreRepo.fetchMyOffers(authRepo.authHeaders);
    return MyOffersData(
      activeOffers: (offersData['active'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e))
              .toList() ??
          [],
      usedOffers: (offersData['used'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e))
              .toList() ??
          [],
      expiredOffers: (offersData['expired'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e))
              .toList() ??
          [],
    );
  } catch (_) {
    return const MyOffersData();
  }
});

// ── DealsPage Providers ──
final dealsCurrentHeroIndexProvider = StateProvider.autoDispose<int>((ref) => 0);

final dealsSelectedCategoryProvider = StateProvider.autoDispose<String>((ref) => 'all');

final dealsSearchQueryProvider = StateProvider.autoDispose<String>((ref) => '');

final dealsHomeDealsProvider = StateProvider.autoDispose<List<dynamic>>((ref) => []);

final dealsCategoriesProvider = StateProvider.autoDispose<List<dynamic>>((ref) => []);

final dealsFlashDealsProvider = StateProvider.autoDispose<List<dynamic>>((ref) => []);

final dealsTrendingDealsProvider = StateProvider.autoDispose<List<dynamic>>((ref) => []);

final dealsAllDealsProvider = StateProvider.autoDispose<List<dynamic>>((ref) => []);

final dealsIsLoadingProvider = StateProvider.autoDispose<bool>((ref) => true);

final dealsTimeLeftProvider = StateProvider.autoDispose<Duration>(
  (ref) => const Duration(hours: 2, minutes: 45, seconds: 32),
);

// ── ExplorePage Providers ──
final exploreCategoriesProvider = StateProvider.autoDispose<List<dynamic>>((ref) => []);

final exploreSearchQueryProvider = StateProvider.autoDispose<String>((ref) => '');

// ── PromotionsPage Providers ──
final promotionsAppliedCodeProvider = StateProvider.autoDispose<String?>((ref) => null);

final promotionsOffersProvider =
    StateProvider.autoDispose<List<Map<String, dynamic>>>((ref) => []);


