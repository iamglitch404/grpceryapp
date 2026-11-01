import 'package:flutter_riverpod/flutter_riverpod.dart';

final adminDealFilterProvider = StateProvider.autoDispose<String>((ref) => 'All');

final adminDealSearchQueryProvider = StateProvider.autoDispose<String>((ref) => '');

final adminHomeDealsLoadingProvider = StateProvider.autoDispose<bool>((ref) => true);

final adminHomeDealsListProvider = StateProvider.autoDispose<List<dynamic>>((ref) => []);

final adminHomeDealsProductsProvider = StateProvider.autoDispose<List<dynamic>>((ref) => []);

final adminPromotionsLoadingProvider = StateProvider.autoDispose<bool>((ref) => true);

final adminPromotionsListProvider = StateProvider.autoDispose<List<dynamic>>((ref) => []);

