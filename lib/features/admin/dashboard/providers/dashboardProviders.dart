import 'package:flutter_riverpod/flutter_riverpod.dart';

final adminMainTabIndexProvider = StateProvider.autoDispose<int>((ref) => 0);

final adminLeaderboardSearchQueryProvider = StateProvider.autoDispose<String>((ref) => '');

final adminLeaderboardSelectedTabProvider = StateProvider.autoDispose<String>((ref) => 'customer');

final adminLeaderboardIsRefreshingProvider = StateProvider.autoDispose<bool>((ref) => false);

class AdminDashboardState {
  final bool isLoading;
  final List<dynamic> users;
  final List<dynamic> categories;
  final List<dynamic> subcategories;
  final List<dynamic> orders;
  final List<dynamic> tickets;
  final List<dynamic> promotions;
  final List<dynamic> approvals;

  const AdminDashboardState({
    this.isLoading = true,
    this.users = const [],
    this.categories = const [],
    this.subcategories = const [],
    this.orders = const [],
    this.tickets = const [],
    this.promotions = const [],
    this.approvals = const [],
  });

  AdminDashboardState copyWith({
    bool? isLoading,
    List<dynamic>? users,
    List<dynamic>? categories,
    List<dynamic>? subcategories,
    List<dynamic>? orders,
    List<dynamic>? tickets,
    List<dynamic>? promotions,
    List<dynamic>? approvals,
  }) {
    return AdminDashboardState(
      isLoading: isLoading ?? this.isLoading,
      users: users ?? this.users,
      categories: categories ?? this.categories,
      subcategories: subcategories ?? this.subcategories,
      orders: orders ?? this.orders,
      tickets: tickets ?? this.tickets,
      promotions: promotions ?? this.promotions,
      approvals: approvals ?? this.approvals,
    );
  }
}

class AdminDashboardNotifier extends StateNotifier<AdminDashboardState> {
  AdminDashboardNotifier() : super(const AdminDashboardState());

  void setLoading(bool value) => state = state.copyWith(isLoading: value);
  void setCategories(List<dynamic> categories) =>
      state = state.copyWith(categories: categories);

  void setAllData({
    required List<dynamic> users,
    required List<dynamic> categories,
    required List<dynamic> subcategories,
    required List<dynamic> orders,
    required List<dynamic> tickets,
    required List<dynamic> promotions,
    required List<dynamic> approvals,
    bool isLoading = false,
  }) {
    state = state.copyWith(
      users: users,
      categories: categories,
      subcategories: subcategories,
      orders: orders,
      tickets: tickets,
      promotions: promotions,
      approvals: approvals,
      isLoading: isLoading,
    );
  }
}

final adminDashboardProvider = StateNotifierProvider.autoDispose<
    AdminDashboardNotifier, AdminDashboardState>((ref) {
  return AdminDashboardNotifier();
});
