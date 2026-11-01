import 'package:flutter_riverpod/flutter_riverpod.dart';

final adminUserRoleFilterProvider = StateProvider.autoDispose<String>((ref) => 'All');

final adminUserSearchQueryProvider = StateProvider.autoDispose<String>((ref) => '');

// UsersPage providers
final adminUsersLoadingProvider = StateProvider.autoDispose<bool>((ref) => true);
final adminUsersListProvider = StateProvider.autoDispose<List<dynamic>>((ref) => []);

// EditAccountPage providers
final adminEditAccountGenderProvider =
    StateProvider.autoDispose.family<String?, String?>((ref, initialGender) => initialGender);
final adminEditAccountObscurePasswordProvider = StateProvider.autoDispose<bool>((ref) => true);
final adminEditAccountSavingProvider = StateProvider.autoDispose<bool>((ref) => false);

// UserSessionPage providers
final adminUserSessionsListProvider = StateProvider.autoDispose<List<dynamic>?>((ref) => null);
final adminUserSessionsLoadingProvider = StateProvider.autoDispose<bool>((ref) => false);

// UserDetailsPage state & provider
class AdminUserDetailsState {
  final bool isLoading;
  final String? currentRole;
  final String? currentStatus;
  final String? selectedGender;
  final bool genderModified;
  final String? updatedName;
  final List<dynamic> orders;
  final List<dynamic> sessions;
  final Map<String, dynamic> stats;

  const AdminUserDetailsState({
    this.isLoading = false,
    this.currentRole,
    this.currentStatus,
    this.selectedGender,
    this.genderModified = false,
    this.updatedName,
    this.orders = const [],
    this.sessions = const [],
    this.stats = const {},
  });

  AdminUserDetailsState copyWith({
    bool? isLoading,
    String? currentRole,
    String? currentStatus,
    String? selectedGender,
    bool? genderModified,
    String? updatedName,
    List<dynamic>? orders,
    List<dynamic>? sessions,
    Map<String, dynamic>? stats,
  }) {
    return AdminUserDetailsState(
      isLoading: isLoading ?? this.isLoading,
      currentRole: currentRole ?? this.currentRole,
      currentStatus: currentStatus ?? this.currentStatus,
      selectedGender: genderModified == true ? selectedGender : (selectedGender ?? this.selectedGender),
      genderModified: genderModified ?? this.genderModified,
      updatedName: updatedName ?? this.updatedName,
      orders: orders ?? this.orders,
      sessions: sessions ?? this.sessions,
      stats: stats ?? this.stats,
    );
  }
}

class AdminUserDetailsNotifier extends StateNotifier<AdminUserDetailsState> {
  AdminUserDetailsNotifier() : super(const AdminUserDetailsState());

  void setLoading(bool value) {
    state = state.copyWith(isLoading: value);
  }

  void setRole(String role) {
    state = state.copyWith(currentRole: role);
  }

  void setStatus(String status) {
    state = state.copyWith(currentStatus: status);
  }

  void updateAccountInfo({String? name, String? gender, bool updateGender = false}) {
    state = AdminUserDetailsState(
      isLoading: state.isLoading,
      currentRole: state.currentRole,
      currentStatus: state.currentStatus,
      selectedGender: updateGender ? gender : state.selectedGender,
      genderModified: updateGender ? true : state.genderModified,
      updatedName: name ?? state.updatedName,
      orders: state.orders,
      sessions: state.sessions,
      stats: state.stats,
    );
  }

  void setActivityData({
    required List<dynamic> orders,
    required List<dynamic> sessions,
    required Map<String, dynamic> stats,
  }) {
    state = state.copyWith(
      orders: orders,
      sessions: sessions,
      stats: stats,
    );
  }
}

final adminUserDetailsProvider =
    StateNotifierProvider.autoDispose<AdminUserDetailsNotifier, AdminUserDetailsState>(
  (ref) => AdminUserDetailsNotifier(),
);

// UserActivityPage state & provider
class AdminUserActivityState {
  final String? selectedCategory;
  final bool isLoading;
  final List<dynamic>? orders;
  final List<dynamic>? pointsLedger;
  final List<dynamic>? cart;
  final List<dynamic>? notifications;
  final List<dynamic>? addresses;
  final List<dynamic>? reviews;
  final List<dynamic>? favorites;
  final Map<String, dynamic>? stats;

  const AdminUserActivityState({
    this.selectedCategory,
    this.isLoading = false,
    this.orders,
    this.pointsLedger,
    this.cart,
    this.notifications,
    this.addresses,
    this.reviews,
    this.favorites,
    this.stats,
  });

  AdminUserActivityState copyWith({
    String? selectedCategory,
    bool? isLoading,
    List<dynamic>? orders,
    List<dynamic>? pointsLedger,
    List<dynamic>? cart,
    List<dynamic>? notifications,
    List<dynamic>? addresses,
    List<dynamic>? reviews,
    List<dynamic>? favorites,
    Map<String, dynamic>? stats,
  }) {
    return AdminUserActivityState(
      selectedCategory: selectedCategory ?? this.selectedCategory,
      isLoading: isLoading ?? this.isLoading,
      orders: orders ?? this.orders,
      pointsLedger: pointsLedger ?? this.pointsLedger,
      cart: cart ?? this.cart,
      notifications: notifications ?? this.notifications,
      addresses: addresses ?? this.addresses,
      reviews: reviews ?? this.reviews,
      favorites: favorites ?? this.favorites,
      stats: stats ?? this.stats,
    );
  }
}

class AdminUserActivityNotifier extends StateNotifier<AdminUserActivityState> {
  AdminUserActivityNotifier() : super(const AdminUserActivityState());

  void setLoading(bool value) {
    state = state.copyWith(isLoading: value);
  }

  void setSelectedCategory(String category) {
    state = state.copyWith(selectedCategory: category);
  }

  void setActivityData({
    required List<dynamic> orders,
    required List<dynamic> pointsLedger,
    required List<dynamic> cart,
    required List<dynamic> notifications,
    required List<dynamic> addresses,
    required List<dynamic> reviews,
    required List<dynamic> favorites,
    required Map<String, dynamic> stats,
  }) {
    state = state.copyWith(
      orders: orders,
      pointsLedger: pointsLedger,
      cart: cart,
      notifications: notifications,
      addresses: addresses,
      reviews: reviews,
      favorites: favorites,
      stats: stats,
    );
  }
}

final adminUserActivityProvider =
    StateNotifierProvider.autoDispose<AdminUserActivityNotifier, AdminUserActivityState>(
  (ref) => AdminUserActivityNotifier(),
);
