import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:app/core/di/injection.dart';

final homeSearchQueryProvider = StateProvider.autoDispose<String>((ref) => '');

final homeSelectedCategoryProvider = StateProvider.autoDispose<String?>((ref) => null);

final homeProductsFutureProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  return ref.watch(productRepositoryProvider).fetchTodaysChoice();
});

final homeCategoriesFutureProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  return ref.watch(productRepositoryProvider).fetchCategoriesHome();
});

final homeDealsFutureProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  return ref.watch(productRepositoryProvider).fetchHomeDeals();
});

// ── FilterPage Providers ──
final filterPriceRangeProvider = StateProvider.autoDispose<RangeValues>(
  (ref) => const RangeValues(20, 248),
);

final filterSelectedRatingProvider = StateProvider.autoDispose<String>(
  (ref) => '5 Stars',
);

final filterVeganFriendlyProvider = StateProvider.autoDispose<String>(
  (ref) => 'Yes',
);

// ── CampaignDealsPage State & Notifier ──
class CampaignDealsState {
  final bool isLoading;
  final List<dynamic> products;
  final String selectedFilter;
  final String searchQuery;

  const CampaignDealsState({
    this.isLoading = true,
    this.products = const [],
    this.selectedFilter = 'All',
    this.searchQuery = '',
  });

  CampaignDealsState copyWith({
    bool? isLoading,
    List<dynamic>? products,
    String? selectedFilter,
    String? searchQuery,
  }) {
    return CampaignDealsState(
      isLoading: isLoading ?? this.isLoading,
      products: products ?? this.products,
      selectedFilter: selectedFilter ?? this.selectedFilter,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

class CampaignDealsNotifier extends StateNotifier<CampaignDealsState> {
  CampaignDealsNotifier() : super(const CampaignDealsState());

  void setLoading(bool value) {
    state = state.copyWith(isLoading: value);
  }

  void setProductsAndLoading(List<dynamic> products, bool isLoading) {
    state = state.copyWith(products: products, isLoading: isLoading);
  }

  void setSelectedFilter(String filter) {
    state = state.copyWith(selectedFilter: filter);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }
}

final campaignDealsProvider =
    StateNotifierProvider.autoDispose<CampaignDealsNotifier, CampaignDealsState>(
  (ref) => CampaignDealsNotifier(),
);

// ── HomePage State & Notifier ──
class HomeCatalogState {
  final List<dynamic> categories;
  final List<dynamic> todaysChoice;
  final List<dynamic> specialDeals;
  final List<dynamic> popularItems;
  final List<dynamic> promotions;
  final List<dynamic> otherProducts;
  final String? userLocation;
  final bool isLocationSheetOpen;
  final bool isLoading;
  final bool isSearchOpen;
  final int searchCategoryIndex;
  final int currentBannerIndex;

  const HomeCatalogState({
    this.categories = const [],
    this.todaysChoice = const [],
    this.specialDeals = const [],
    this.popularItems = const [],
    this.promotions = const [],
    this.otherProducts = const [],
    this.userLocation,
    this.isLocationSheetOpen = false,
    this.isLoading = false,
    this.isSearchOpen = false,
    this.searchCategoryIndex = 0,
    this.currentBannerIndex = 0,
  });

  HomeCatalogState copyWith({
    List<dynamic>? categories,
    List<dynamic>? todaysChoice,
    List<dynamic>? specialDeals,
    List<dynamic>? popularItems,
    List<dynamic>? promotions,
    List<dynamic>? otherProducts,
    String? userLocation,
    bool? isLocationSheetOpen,
    bool? isLoading,
    bool? isSearchOpen,
    int? searchCategoryIndex,
    int? currentBannerIndex,
  }) {
    return HomeCatalogState(
      categories: categories ?? this.categories,
      todaysChoice: todaysChoice ?? this.todaysChoice,
      specialDeals: specialDeals ?? this.specialDeals,
      popularItems: popularItems ?? this.popularItems,
      promotions: promotions ?? this.promotions,
      otherProducts: otherProducts ?? this.otherProducts,
      userLocation: userLocation ?? this.userLocation,
      isLocationSheetOpen: isLocationSheetOpen ?? this.isLocationSheetOpen,
      isLoading: isLoading ?? this.isLoading,
      isSearchOpen: isSearchOpen ?? this.isSearchOpen,
      searchCategoryIndex: searchCategoryIndex ?? this.searchCategoryIndex,
      currentBannerIndex: currentBannerIndex ?? this.currentBannerIndex,
    );
  }
}

class HomeCatalogNotifier extends StateNotifier<HomeCatalogState> {
  HomeCatalogNotifier(super.initial);

  void setLoading(bool value) => state = state.copyWith(isLoading: value);
  void setCategories(List<dynamic> data) => state = state.copyWith(categories: data);
  void setPromotions(List<dynamic> data) => state = state.copyWith(promotions: data);
  void setTodaysChoice(List<dynamic> data) => state = state.copyWith(todaysChoice: data);
  void setSpecialDeals(List<dynamic> data) => state = state.copyWith(specialDeals: data);
  void setPopularItems(List<dynamic> data) => state = state.copyWith(popularItems: data);
  void setOtherProducts(List<dynamic> data) => state = state.copyWith(otherProducts: data);
  void setUserLocation(String? loc) => state = state.copyWith(userLocation: loc);
  void setLocationSheetOpen(bool isOpen) => state = state.copyWith(isLocationSheetOpen: isOpen);
  void setSearchOpen(bool isOpen, {int? categoryIndex}) => state = state.copyWith(
        isSearchOpen: isOpen,
        searchCategoryIndex: categoryIndex ?? state.searchCategoryIndex,
      );
  void setCurrentBannerIndex(int index) => state = state.copyWith(currentBannerIndex: index);
}

final homeCatalogProvider =
    StateNotifierProvider<HomeCatalogNotifier, HomeCatalogState>((ref) {
  final repo = ref.read(productRepositoryProvider);
  final categories = repo.getCachedCategories();
  final promotions = repo.getCachedHomeDeals();
  final todaysChoice = repo.getCachedTodaysChoice();
  final specialDeals = repo.getCachedSpecialDeals();
  final popularItems = repo.getCachedPopularItems();
  final isLoading = categories.isEmpty && todaysChoice.isEmpty && promotions.isEmpty;
  return HomeCatalogNotifier(
    HomeCatalogState(
      categories: categories,
      promotions: promotions,
      todaysChoice: todaysChoice,
      specialDeals: specialDeals,
      popularItems: popularItems,
      isLoading: isLoading,
    ),
  );
});

// ── LocationPickerPage State & Notifier ──
class LocationPickerState {
  final LatLng center;
  final LatLng? userLocation;
  final bool isLoading;
  final String currentAddress;
  final String mainAddress;
  final String subAddress;
  final List<dynamic> suggestions;
  final bool isSearching;
  final String currentMapLayer;
  final bool isTrackingUser;
  final bool showLayerMenu;
  final String mapProvider;
  final bool showProviderMenu;

  const LocationPickerState({
    this.center = const LatLng(27.7172, 85.3240),
    this.userLocation,
    this.isLoading = false,
    this.currentAddress = 'Kathmandu, Nepal',
    this.mainAddress = 'Kathmandu',
    this.subAddress = 'Bagmati Province, Nepal',
    this.suggestions = const [],
    this.isSearching = false,
    this.currentMapLayer = 'standard',
    this.isTrackingUser = false,
    this.showLayerMenu = false,
    this.mapProvider = 'osm',
    this.showProviderMenu = false,
  });

  LocationPickerState copyWith({
    LatLng? center,
    LatLng? userLocation,
    bool? isLoading,
    String? currentAddress,
    String? mainAddress,
    String? subAddress,
    List<dynamic>? suggestions,
    bool? isSearching,
    String? currentMapLayer,
    bool? isTrackingUser,
    bool? showLayerMenu,
    String? mapProvider,
    bool? showProviderMenu,
  }) {
    return LocationPickerState(
      center: center ?? this.center,
      userLocation: userLocation ?? this.userLocation,
      isLoading: isLoading ?? this.isLoading,
      currentAddress: currentAddress ?? this.currentAddress,
      mainAddress: mainAddress ?? this.mainAddress,
      subAddress: subAddress ?? this.subAddress,
      suggestions: suggestions ?? this.suggestions,
      isSearching: isSearching ?? this.isSearching,
      currentMapLayer: currentMapLayer ?? this.currentMapLayer,
      isTrackingUser: isTrackingUser ?? this.isTrackingUser,
      showLayerMenu: showLayerMenu ?? this.showLayerMenu,
      mapProvider: mapProvider ?? this.mapProvider,
      showProviderMenu: showProviderMenu ?? this.showProviderMenu,
    );
  }
}

class LocationPickerNotifier extends StateNotifier<LocationPickerState> {
  LocationPickerNotifier() : super(const LocationPickerState());

  void update(LocationPickerState Function(LocationPickerState s) updater) {
    state = updater(state);
  }
}

final locationPickerProvider =
    StateNotifierProvider.autoDispose<LocationPickerNotifier, LocationPickerState>(
  (ref) => LocationPickerNotifier(),
);

// ── ProductDetailPage State & Notifier ──
class ProductDetailState {
  final int quantity;
  final int selectedRating;
  final bool isFavorite;
  final List<Map<String, dynamic>> reviews;
  final bool isLoadingReviews;
  final List<dynamic> similarProducts;
  final List<dynamic> youMayAlsoLike;

  const ProductDetailState({
    this.quantity = 1,
    this.selectedRating = 5,
    this.isFavorite = false,
    this.reviews = const [],
    this.isLoadingReviews = false,
    this.similarProducts = const [],
    this.youMayAlsoLike = const [],
  });

  ProductDetailState copyWith({
    int? quantity,
    int? selectedRating,
    bool? isFavorite,
    List<Map<String, dynamic>>? reviews,
    bool? isLoadingReviews,
    List<dynamic>? similarProducts,
    List<dynamic>? youMayAlsoLike,
  }) {
    return ProductDetailState(
      quantity: quantity ?? this.quantity,
      selectedRating: selectedRating ?? this.selectedRating,
      isFavorite: isFavorite ?? this.isFavorite,
      reviews: reviews ?? this.reviews,
      isLoadingReviews: isLoadingReviews ?? this.isLoadingReviews,
      similarProducts: similarProducts ?? this.similarProducts,
      youMayAlsoLike: youMayAlsoLike ?? this.youMayAlsoLike,
    );
  }
}

class ProductDetailNotifier extends StateNotifier<ProductDetailState> {
  ProductDetailNotifier() : super(const ProductDetailState());

  void update(ProductDetailState Function(ProductDetailState s) updater) {
    state = updater(state);
  }
}

final productDetailProvider = StateNotifierProvider.autoDispose
    .family<ProductDetailNotifier, ProductDetailState, String>(
  (ref, key) => ProductDetailNotifier(),
);

// ── ProductReviewsPage State & Notifier ──
class ProductReviewsState {
  final int selectedRating;
  final List<Map<String, dynamic>> reviews;
  final bool isLoadingReviews;
  final List<dynamic> similarProducts;
  final List<dynamic> youMayAlsoLike;

  const ProductReviewsState({
    this.selectedRating = 5,
    this.reviews = const [],
    this.isLoadingReviews = false,
    this.similarProducts = const [],
    this.youMayAlsoLike = const [],
  });

  ProductReviewsState copyWith({
    int? selectedRating,
    List<Map<String, dynamic>>? reviews,
    bool? isLoadingReviews,
    List<dynamic>? similarProducts,
    List<dynamic>? youMayAlsoLike,
  }) {
    return ProductReviewsState(
      selectedRating: selectedRating ?? this.selectedRating,
      reviews: reviews ?? this.reviews,
      isLoadingReviews: isLoadingReviews ?? this.isLoadingReviews,
      similarProducts: similarProducts ?? this.similarProducts,
      youMayAlsoLike: youMayAlsoLike ?? this.youMayAlsoLike,
    );
  }
}

class ProductReviewsNotifier extends StateNotifier<ProductReviewsState> {
  ProductReviewsNotifier() : super(const ProductReviewsState());

  void update(ProductReviewsState Function(ProductReviewsState s) updater) {
    state = updater(state);
  }
}

final productReviewsProvider = StateNotifierProvider.autoDispose
    .family<ProductReviewsNotifier, ProductReviewsState, String>(
  (ref, key) => ProductReviewsNotifier(),
);

// ── SearchPage & HomeSearchComponent State & Notifier ──
class SearchCatalogState {
  final int selectedCategoryIndex;
  final bool isLoading;
  final List<dynamic> categories;
  final List<dynamic> products;

  const SearchCatalogState({
    this.selectedCategoryIndex = 0,
    this.isLoading = true,
    this.categories = const [],
    this.products = const [],
  });

  SearchCatalogState copyWith({
    int? selectedCategoryIndex,
    bool? isLoading,
    List<dynamic>? categories,
    List<dynamic>? products,
  }) {
    return SearchCatalogState(
      selectedCategoryIndex: selectedCategoryIndex ?? this.selectedCategoryIndex,
      isLoading: isLoading ?? this.isLoading,
      categories: categories ?? this.categories,
      products: products ?? this.products,
    );
  }
}

class SearchCatalogNotifier extends StateNotifier<SearchCatalogState> {
  SearchCatalogNotifier() : super(const SearchCatalogState());

  void update(SearchCatalogState Function(SearchCatalogState s) updater) {
    state = updater(state);
  }
}

final searchPageProvider =
    StateNotifierProvider.autoDispose<SearchCatalogNotifier, SearchCatalogState>(
  (ref) => SearchCatalogNotifier(),
);

final homeSearchComponentProvider =
    StateNotifierProvider.autoDispose<SearchCatalogNotifier, SearchCatalogState>(
  (ref) => SearchCatalogNotifier(),
);
