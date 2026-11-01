import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/core/config/appConfig.dart';
import 'package:app/core/di/injection.dart';
import 'package:app/core/network/httpClient.dart' as http;

final adminProductReviewTabProvider = StateProvider.autoDispose<String>((ref) => 'pending');

final adminProductSearchQueryProvider = StateProvider.autoDispose<String>((ref) => '');

final adminProductSubmissionsFutureProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final selectedTab = ref.watch(adminProductReviewTabProvider);
  final authRepo = ref.watch(authRepositoryProvider);
  try {
    final uri = Uri.parse('${AppConfig.apiUrl}/admin/product-approvals?status=$selectedTab');
    final res = await http.get(uri, headers: authRepo.authHeaders);
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body);
      final list = (body['submissions'] ?? body['data'] ?? []) as List;
      return list.map((item) => Map<String, dynamic>.from(item)).toList();
    }
  } catch (e) {
    debugPrint('[adminProductSubmissionsFutureProvider] fetch error: $e');
  }
  return [];
});

// CategoriesPage providers
final adminCategoriesLoadingProvider = StateProvider.autoDispose<bool>((ref) => true);
final adminCategoriesListProvider = StateProvider.autoDispose<List<dynamic>>((ref) => []);

// ProductsPage providers
final adminProductsLoadingProvider = StateProvider.autoDispose<bool>((ref) => true);
final adminProductsListProvider = StateProvider.autoDispose<List<Map<String, dynamic>>>((ref) => []);
final adminProductCategoriesProvider = StateProvider.autoDispose<List<dynamic>>((ref) => []);
final adminProductsSearchQueryProvider = StateProvider.autoDispose<String>((ref) => '');
final adminProductsSelectedCategoryProvider = StateProvider.autoDispose<String>((ref) => 'All');
final adminProductsSelectedSubcategoryProvider = StateProvider.autoDispose<String>((ref) => 'All');
final adminProductsSelectedStockStatusProvider = StateProvider.autoDispose<String>((ref) => 'All');
final adminProductsSelectedStatusProvider = StateProvider.autoDispose<String>((ref) => 'All');
final adminProductsPendingReviewCountProvider = StateProvider.autoDispose<int>((ref) => 0);

// ProductAddEditDialog State & Notifier
class ProductAddEditUiState {
  final bool isSaving;
  final bool isUploading;
  final String? selectedCatId;
  final String? selectedSubId;
  final bool isTodaysChoice;
  final bool isSpecialDeal;
  final bool isPopular;
  final bool isActive;

  const ProductAddEditUiState({
    this.isSaving = false,
    this.isUploading = false,
    this.selectedCatId,
    this.selectedSubId,
    this.isTodaysChoice = false,
    this.isSpecialDeal = false,
    this.isPopular = false,
    this.isActive = true,
  });

  ProductAddEditUiState copyWith({
    bool? isSaving,
    bool? isUploading,
    String? selectedCatId,
    String? selectedSubId,
    bool? isTodaysChoice,
    bool? isSpecialDeal,
    bool? isPopular,
    bool? isActive,
  }) {
    return ProductAddEditUiState(
      isSaving: isSaving ?? this.isSaving,
      isUploading: isUploading ?? this.isUploading,
      selectedCatId: selectedCatId ?? this.selectedCatId,
      selectedSubId: selectedSubId ?? this.selectedSubId,
      isTodaysChoice: isTodaysChoice ?? this.isTodaysChoice,
      isSpecialDeal: isSpecialDeal ?? this.isSpecialDeal,
      isPopular: isPopular ?? this.isPopular,
      isActive: isActive ?? this.isActive,
    );
  }
}

class ProductAddEditUiNotifier extends StateNotifier<ProductAddEditUiState> {
  ProductAddEditUiNotifier() : super(const ProductAddEditUiState());

  void init({
    String? catId,
    String? subId,
    bool todaysChoice = false,
    bool specialDeal = false,
    bool popular = false,
    bool active = true,
  }) {
    state = ProductAddEditUiState(
      selectedCatId: catId,
      selectedSubId: subId,
      isTodaysChoice: todaysChoice,
      isSpecialDeal: specialDeal,
      isPopular: popular,
      isActive: active,
    );
  }

  void setSaving(bool val) => state = state.copyWith(isSaving: val);
  void setUploading(bool val) => state = state.copyWith(isUploading: val);
  void selectCategory(String? catId) => state = state.copyWith(selectedCatId: catId, selectedSubId: null);
  void selectSubcategory(String? subId) => state = state.copyWith(selectedSubId: subId);
  void setTodaysChoice(bool val) => state = state.copyWith(isTodaysChoice: val);
  void setSpecialDeal(bool val) => state = state.copyWith(isSpecialDeal: val);
  void setPopular(bool val) => state = state.copyWith(isPopular: val);
  void setActive(bool val) => state = state.copyWith(isActive: val);
}

final productAddEditUiProvider =
    StateNotifierProvider.autoDispose<ProductAddEditUiNotifier, ProductAddEditUiState>((ref) {
  return ProductAddEditUiNotifier();
});

// Category & Subcategory Dialogs State & Notifiers
class AddCategoryUiState {
  final bool isSaving;
  final String? selectedColor;
  final Uint8List? pickedImageBytes;
  final String? pickedImageName;

  const AddCategoryUiState({
    this.isSaving = false,
    this.selectedColor = '#185B3A',
    this.pickedImageBytes,
    this.pickedImageName,
  });

  AddCategoryUiState copyWith({
    bool? isSaving,
    String? selectedColor,
    Uint8List? pickedImageBytes,
    String? pickedImageName,
  }) {
    return AddCategoryUiState(
      isSaving: isSaving ?? this.isSaving,
      selectedColor: selectedColor ?? this.selectedColor,
      pickedImageBytes: pickedImageBytes ?? this.pickedImageBytes,
      pickedImageName: pickedImageName ?? this.pickedImageName,
    );
  }
}

class AddCategoryUiNotifier extends StateNotifier<AddCategoryUiState> {
  AddCategoryUiNotifier() : super(const AddCategoryUiState());

  void setSaving(bool val) => state = state.copyWith(isSaving: val);
  void setColor(String? hex) => state = state.copyWith(selectedColor: hex);
  void setImage({Uint8List? bytes, String? name}) =>
      state = state.copyWith(pickedImageBytes: bytes, pickedImageName: name);
  void reset() => state = const AddCategoryUiState();
}

final addCategoryUiProvider =
    StateNotifierProvider.autoDispose<AddCategoryUiNotifier, AddCategoryUiState>((ref) {
  return AddCategoryUiNotifier();
});

class AddSubcategoryUiState {
  final bool isSaving;
  final bool isUploading;
  final String? selectedParentId;

  const AddSubcategoryUiState({
    this.isSaving = false,
    this.isUploading = false,
    this.selectedParentId,
  });

  AddSubcategoryUiState copyWith({
    bool? isSaving,
    bool? isUploading,
    String? selectedParentId,
  }) {
    return AddSubcategoryUiState(
      isSaving: isSaving ?? this.isSaving,
      isUploading: isUploading ?? this.isUploading,
      selectedParentId: selectedParentId ?? this.selectedParentId,
    );
  }
}

class AddSubcategoryUiNotifier extends StateNotifier<AddSubcategoryUiState> {
  AddSubcategoryUiNotifier() : super(const AddSubcategoryUiState());

  void init(String? parentId) => state = AddSubcategoryUiState(selectedParentId: parentId);
  void setParentId(String? parentId) => state = state.copyWith(selectedParentId: parentId);
  void setSaving(bool val) => state = state.copyWith(isSaving: val);
  void setUploading(bool val) => state = state.copyWith(isUploading: val);
}

final addSubcategoryUiProvider =
    StateNotifierProvider.autoDispose<AddSubcategoryUiNotifier, AddSubcategoryUiState>((ref) {
  return AddSubcategoryUiNotifier();
});

