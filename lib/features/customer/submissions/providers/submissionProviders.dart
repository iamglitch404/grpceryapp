import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:app/core/di/injection.dart';
import 'package:app/features/auth/providers/authRepository.dart';
import 'package:app/features/customer/submissions/providers/submissionRepository.dart';

final submissionSearchQueryProvider = StateProvider.autoDispose<String>((ref) => '');

final submissionStatusTabProvider = StateProvider.autoDispose<String>((ref) => 'All');

// ── SubmitProductPage State Providers ──
final submitProductSelectedPickupTimeProvider =
    StateProvider.autoDispose<String>((ref) => 'Morning (9 AM - 12 PM)');
final submitProductCategoriesProvider =
    StateProvider.autoDispose<List<Map<String, dynamic>>>((ref) => []);
final submitProductSelectedCategoryIdProvider =
    StateProvider.autoDispose<String?>((ref) => null);
final submitProductSelectedSubcategoryIdProvider =
    StateProvider.autoDispose<String?>((ref) => null);
final submitProductImageUrlProvider =
    StateProvider.autoDispose<String?>((ref) => null);
final submitProductSelectedImageProvider =
    StateProvider.autoDispose<XFile?>((ref) => null);
final submitProductIsSavingProvider =
    StateProvider.autoDispose<bool>((ref) => false);
final submitProductUnitTickProvider =
    StateProvider.autoDispose<int>((ref) => 0);

class SubmissionsState {
  final bool isLoading;
  final List<Map<String, dynamic>> products;

  const SubmissionsState({
    this.isLoading = true,
    this.products = const [],
  });

  SubmissionsState copyWith({
    bool? isLoading,
    List<Map<String, dynamic>>? products,
  }) {
    return SubmissionsState(
      isLoading: isLoading ?? this.isLoading,
      products: products ?? this.products,
    );
  }
}

class SubmissionsNotifier extends StateNotifier<SubmissionsState> {
  final SubmissionRepository _repo;
  final AuthRepository _authRepo;

  SubmissionsNotifier(this._repo, this._authRepo) : super(const SubmissionsState()) {
    loadData();
  }

  Future<void> loadData() async {
    state = state.copyWith(isLoading: true);
    try {
      final user = _authRepo.currentUser;
      final isAdmin = user?['role'] == 'admin';
      final prods = isAdmin
          ? await _repo.fetchProducts(_authRepo.authHeaders)
          : await _repo.fetchMySubmissions(_authRepo.authHeaders);
      if (!mounted) return;
      state = state.copyWith(isLoading: false, products: prods);
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false);
    }
  }

  Future<bool> toggleProductStock(Map<String, dynamic> product) async {
    final id = product['id']?.toString() ?? '';
    final currentActive = product['is_active'] ?? true;
    final nextActive = !currentActive;

    final updatedList = state.products.map((p) {
      if (p['id']?.toString() == id) {
        return {...p, 'is_active': nextActive};
      }
      return p;
    }).toList();
    state = state.copyWith(products: updatedList);

    final success = await _repo.updateProduct(_authRepo.authHeaders, id, {
      'is_active': nextActive,
    });
    if (!mounted) return false;
    if (!success) {
      final revertedList = state.products.map((p) {
        if (p['id']?.toString() == id) {
          return {...p, 'is_active': currentActive};
        }
        return p;
      }).toList();
      state = state.copyWith(products: revertedList);
    }
    return success;
  }

  Future<bool> deleteProduct(String id) async {
    final success = await _repo.deleteProduct(_authRepo.authHeaders, id);
    if (!mounted) return false;
    if (success) {
      state = state.copyWith(
        products: state.products.where((p) => p['id']?.toString() != id).toList(),
      );
    }
    return success;
  }
}

final submissionsNotifierProvider =
    StateNotifierProvider.autoDispose<SubmissionsNotifier, SubmissionsState>((ref) {
  final repo = ref.watch(submissionRepositoryProvider);
  final authRepo = ref.watch(authRepositoryProvider);
  return SubmissionsNotifier(repo, authRepo);
});

