import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/core/di/injection.dart';
import 'package:app/features/delivery/dashboard/providers/deliveryRepository.dart';

final deliveryDashboardTabIndexProvider = StateProvider.autoDispose<int>((ref) => 0);

class DeliveryDashboardState {
  final bool isLoading;
  final bool isOnline;
  final Map<String, dynamic>? partner;
  final Map<String, dynamic>? activeShift;
  final List<dynamic> pendingAssignments;
  final List<dynamic> activeOrders;
  final List<dynamic> completedToday;

  const DeliveryDashboardState({
    this.isLoading = true,
    this.isOnline = false,
    this.partner,
    this.activeShift,
    this.pendingAssignments = const [],
    this.activeOrders = const [],
    this.completedToday = const [],
  });

  DeliveryDashboardState copyWith({
    bool? isLoading,
    bool? isOnline,
    Map<String, dynamic>? partner,
    Map<String, dynamic>? activeShift,
    List<dynamic>? pendingAssignments,
    List<dynamic>? activeOrders,
    List<dynamic>? completedToday,
  }) {
    return DeliveryDashboardState(
      isLoading: isLoading ?? this.isLoading,
      isOnline: isOnline ?? this.isOnline,
      partner: partner ?? this.partner,
      activeShift: activeShift ?? this.activeShift,
      pendingAssignments: pendingAssignments ?? this.pendingAssignments,
      activeOrders: activeOrders ?? this.activeOrders,
      completedToday: completedToday ?? this.completedToday,
    );
  }
}

class DeliveryDashboardNotifier extends StateNotifier<DeliveryDashboardState> {
  final DeliveryRepository _repo;

  DeliveryDashboardNotifier(this._repo) : super(const DeliveryDashboardState()) {
    loadDashboardData();
  }

  Future<void> loadDashboardData() async {
    state = state.copyWith(isLoading: true);
    final results = await Future.wait([
      _repo.fetchProfile(),
      _repo.fetchOrders(),
    ]);
    if (!mounted) return;
    final profileData = results[0];
    final ordersData = results[1];
    final partner = profileData?['partner'];
    final isOnline = partner?['status'] == 'online' || partner?['status'] == 'on_delivery';
    state = state.copyWith(
      isLoading: false,
      partner: partner,
      activeShift: profileData?['active_shift'],
      isOnline: isOnline,
      pendingAssignments: ordersData?['pending_assignments'] ?? [],
      activeOrders: ordersData?['active_orders'] ?? [],
      completedToday: ordersData?['completed_today'] ?? [],
    );
  }

  Future<void> loadOrdersOnly() async {
    final ordersData = await _repo.fetchOrders();
    if (!mounted || ordersData == null) return;
    state = state.copyWith(
      pendingAssignments: ordersData['pending_assignments'] ?? [],
      activeOrders: ordersData['active_orders'] ?? [],
      completedToday: ordersData['completed_today'] ?? [],
    );
  }

  Future<bool> toggleOnlineStatus(bool value) async {
    final newStatus = value ? 'online' : 'offline';
    state = state.copyWith(isOnline: value);
    final success = await _repo.updateStatus(newStatus);
    if (!mounted) return false;
    if (!success) {
      state = state.copyWith(isOnline: !value);
    }
    return success;
  }

  Future<bool> performOrderAction(String orderId, String action) async {
    final success = await _repo.performAction(orderId, action);
    if (!mounted) return false;
    if (success) {
      await loadOrdersOnly();
    }
    return success;
  }
}

final deliveryDashboardNotifierProvider =
    StateNotifierProvider.autoDispose<DeliveryDashboardNotifier, DeliveryDashboardState>((ref) {
  final repo = ref.watch(deliveryRepositoryProvider);
  return DeliveryDashboardNotifier(repo);
});

