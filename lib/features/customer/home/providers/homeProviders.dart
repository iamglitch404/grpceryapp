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
  return HomeCatalogNotifier(
    HomeCatalogState(
      categories: categories,
      promotions: promotions,
      todaysChoice: todaysChoice,
      specialDeals: specialDeals,
      popularItems: popularItems,
      isLoading: false,
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
  final Set<dynamic> markers;
  final bool isTrackingUser;
  final bool showLayerMenu;
  final String mapProvider;
  final bool showProviderMenu;

  const LocationPickerState({
    required this.center,
    this.userLocation,
    this.isLoading = false,
    this.currentAddress = 'Select Location',
    this.mainAddress = 'Select Location',
    this.subAddress = 'Tap search or move map to select',
    this.suggestions = const [],
    this.isSearching = false,
    this.currentMapLayer = 'streets',
    this.markers = const {},
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
    Set<dynamic>? markers,
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
      markers: markers ?? this.markers,
      isTrackingUser: isTrackingUser ?? this.isTrackingUser,
      showLayerMenu: showLayerMenu ?? this.showLayerMenu,
      mapProvider: mapProvider ?? this.mapProvider,
      showProviderMenu: showProviderMenu ?? this.showProviderMenu,
    );
  }
}

class LocationPickerNotifier extends StateNotifier<LocationPickerState> {
  LocationPickerNotifier()
      : super(const LocationPickerState(center: LatLng(27.7172, 85.3240)));

  void update(LocationPickerState Function(LocationPickerState s) updater) {
    state = updater(state);
  }

  void setCenter(LatLng pos) => state = state.copyWith(center: pos);
  void setUserLocation(LatLng pos) => state = state.copyWith(userLocation: pos);
  void setLoading(bool val) => state = state.copyWith(isLoading: val);
  void setAddress({required String current, required String main, required String sub}) {
    state = state.copyWith(currentAddress: current, mainAddress: main, subAddress: sub);
  }
  void setSuggestions(List<dynamic> list) => state = state.copyWith(suggestions: list);
  void setSearching(bool val) => state = state.copyWith(isSearching: val);
  void setMapLayer(String layer) => state = state.copyWith(currentMapLayer: layer);
  void setMarkers(Set<dynamic> m) => state = state.copyWith(markers: m);
}

final locationPickerProvider =
    StateNotifierProvider.autoDispose<LocationPickerNotifier, LocationPickerState>(
  (ref) => LocationPickerNotifier(),
);

// ── ProductDetail State & Notifier ──
class ProductDetailState {
  final int quantity;
  final bool isFavorite;
  final int selectedRating;
  final bool isLoadingReviews;
  final List<Map<String, dynamic>> reviews;
  final List<dynamic> similarProducts;
  final List<dynamic> youMayAlsoLike;

  const ProductDetailState({
    this.quantity = 1,
    this.isFavorite = false,
    this.selectedRating = 5,
    this.isLoadingReviews = false,
    this.reviews = const [],
    this.similarProducts = const [],
    this.youMayAlsoLike = const [],
  });

  ProductDetailState copyWith({
    int? quantity,
    bool? isFavorite,
    int? selectedRating,
    bool? isLoadingReviews,
    List<Map<String, dynamic>>? reviews,
    List<dynamic>? similarProducts,
    List<dynamic>? youMayAlsoLike,
  }) {
    return ProductDetailState(
      quantity: quantity ?? this.quantity,
      isFavorite: isFavorite ?? this.isFavorite,
      selectedRating: selectedRating ?? this.selectedRating,
      isLoadingReviews: isLoadingReviews ?? this.isLoadingReviews,
      reviews: reviews ?? this.reviews,
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

final productDetailProvider = StateNotifierProvider.family
    .autoDispose<ProductDetailNotifier, ProductDetailState, String>(
  (ref, key) => ProductDetailNotifier(),
);

// ── ProductReviews State & Notifier ──
class ProductReviewsState {
  final bool isLoadingReviews;
  final List<Map<String, dynamic>> reviews;
  final int selectedRating;
  final List<dynamic> similarProducts;
  final List<dynamic> youMayAlsoLike;

  const ProductReviewsState({
    this.isLoadingReviews = false,
    this.reviews = const [],
    this.selectedRating = 5,
    this.similarProducts = const [],
    this.youMayAlsoLike = const [],
  });

  ProductReviewsState copyWith({
    bool? isLoadingReviews,
    List<Map<String, dynamic>>? reviews,
    int? selectedRating,
    List<dynamic>? similarProducts,
    List<dynamic>? youMayAlsoLike,
  }) {
    return ProductReviewsState(
      isLoadingReviews: isLoadingReviews ?? this.isLoadingReviews,
      reviews: reviews ?? this.reviews,
      selectedRating: selectedRating ?? this.selectedRating,
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

final productReviewsProvider = StateNotifierProvider.family
    .autoDispose<ProductReviewsNotifier, ProductReviewsState, String>(
  (ref, key) => ProductReviewsNotifier(),
);

// ── SearchCatalog State & Notifier ──
class SearchCatalogState {
  final int selectedCategoryIndex;
  final bool isLoading;
  final List<dynamic> categories;
  final List<dynamic> products;
  final String searchQuery;

  const SearchCatalogState({
    this.selectedCategoryIndex = 0,
    this.isLoading = true,
    this.categories = const [],
    this.products = const [],
    this.searchQuery = '',
  });

  SearchCatalogState copyWith({
    int? selectedCategoryIndex,
    bool? isLoading,
    List<dynamic>? categories,
    List<dynamic>? products,
    String? searchQuery,
  }) {
    return SearchCatalogState(
      selectedCategoryIndex: selectedCategoryIndex ?? this.selectedCategoryIndex,
      isLoading: isLoading ?? this.isLoading,
      categories: categories ?? this.categories,
      products: products ?? this.products,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

class SearchCatalogNotifier extends StateNotifier<SearchCatalogState> {
  SearchCatalogNotifier() : super(const SearchCatalogState());

  void update(SearchCatalogState Function(SearchCatalogState s) updater) {
    state = updater(state);
  }
}

final searchPageProvider = StateNotifierProvider
    .autoDispose<SearchCatalogNotifier, SearchCatalogState>(
  (ref) => SearchCatalogNotifier(),
);

final homeSearchComponentProvider = StateNotifierProvider
    .autoDispose<SearchCatalogNotifier, SearchCatalogState>(
  (ref) => SearchCatalogNotifier(),
);
