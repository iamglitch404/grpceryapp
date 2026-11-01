import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:app/core/di/injection.dart';
import 'package:app/core/models/routeStep.dart';
import 'package:app/features/admin/orders/providers/orderRepository.dart';

final adminOrderStatusFilterProvider = StateProvider.autoDispose<String>((ref) => 'All');

final adminOrderSearchQueryProvider = StateProvider.autoDispose<String>((ref) => '');

final adminOrderSortProvider = StateProvider.autoDispose<String>((ref) => 'Newest');

class AdminOrdersState {
  final bool isLoading;
  final List<dynamic> orders;

  const AdminOrdersState({
    this.isLoading = true,
    this.orders = const [],
  });

  AdminOrdersState copyWith({
    bool? isLoading,
    List<dynamic>? orders,
  }) {
    return AdminOrdersState(
      isLoading: isLoading ?? this.isLoading,
      orders: orders ?? this.orders,
    );
  }
}

class AdminOrdersNotifier extends StateNotifier<AdminOrdersState> {
  final AdminOrderRepository _repo;

  AdminOrdersNotifier(this._repo) : super(const AdminOrdersState()) {
    fetchOrders();
  }

  Future<void> fetchOrders() async {
    state = state.copyWith(isLoading: true);
    try {
      final orders = await _repo.fetchOrders();
      if (!mounted) return;
      state = state.copyWith(isLoading: false, orders: orders);
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false);
    }
  }

  Future<bool> updateOrderStatus(dynamic orderId, String newStatus) async {
    final success = await _repo.updateOrderStatus(orderId, newStatus);
    if (!mounted) return false;
    if (success) {
      await fetchOrders();
    }
    return success;
  }
}

final adminOrdersNotifierProvider =
    StateNotifierProvider.autoDispose<AdminOrdersNotifier, AdminOrdersState>((ref) {
  final repo = ref.watch(adminOrderRepositoryProvider);
  return AdminOrdersNotifier(repo);
});

// ── Admin Live Location State ────────────────────────────────────────────────
class AdminLocationState {
  final LatLng adminPoint;
  final String adminAddress;
  final bool isLocating;

  const AdminLocationState({
    this.adminPoint = const LatLng(27.7108, 85.3251),
    this.adminAddress = 'Kathmandu, Nepal',
    this.isLocating = false,
  });

  AdminLocationState copyWith({
    LatLng? adminPoint,
    String? adminAddress,
    bool? isLocating,
  }) {
    return AdminLocationState(
      adminPoint: adminPoint ?? this.adminPoint,
      adminAddress: adminAddress ?? this.adminAddress,
      isLocating: isLocating ?? this.isLocating,
    );
  }
}

class AdminLocationNotifier extends StateNotifier<AdminLocationState> {
  AdminLocationNotifier() : super(const AdminLocationState());

  void setLocating(bool value) => state = state.copyWith(isLocating: value);
  void setLocation({
    required LatLng point,
    required String address,
    bool isLocating = false,
  }) {
    state = state.copyWith(
      adminPoint: point,
      adminAddress: address,
      isLocating: isLocating,
    );
  }
}

final adminLocationProvider = StateNotifierProvider.autoDispose<
    AdminLocationNotifier, AdminLocationState>((ref) {
  return AdminLocationNotifier();
});

// ── Order Details UI State ───────────────────────────────────────────────────
class OrderDetailsUiState {
  final String currentStatus;
  final Map<String, dynamic>? assignedPartner;
  final LatLng adminPoint;
  final String adminAddress;
  final bool isLocatingAdmin;

  const OrderDetailsUiState({
    this.currentStatus = 'Pending',
    this.assignedPartner,
    this.adminPoint = const LatLng(27.7108, 85.3251),
    this.adminAddress = 'Kathmandu, Nepal',
    this.isLocatingAdmin = false,
  });

  OrderDetailsUiState copyWith({
    String? currentStatus,
    Map<String, dynamic>? assignedPartner,
    LatLng? adminPoint,
    String? adminAddress,
    bool? isLocatingAdmin,
  }) {
    return OrderDetailsUiState(
      currentStatus: currentStatus ?? this.currentStatus,
      assignedPartner: assignedPartner ?? this.assignedPartner,
      adminPoint: adminPoint ?? this.adminPoint,
      adminAddress: adminAddress ?? this.adminAddress,
      isLocatingAdmin: isLocatingAdmin ?? this.isLocatingAdmin,
    );
  }
}

class OrderDetailsUiNotifier extends StateNotifier<OrderDetailsUiState> {
  OrderDetailsUiNotifier() : super(const OrderDetailsUiState());

  void init({
    required String currentStatus,
    Map<String, dynamic>? assignedPartner,
  }) {
    state = state.copyWith(
      currentStatus: currentStatus,
      assignedPartner: assignedPartner,
    );
  }

  void setStatus(String status) => state = state.copyWith(currentStatus: status);
  void setAssignedPartner(Map<String, dynamic> partner, {String? newStatus}) {
    state = state.copyWith(
      assignedPartner: partner,
      currentStatus: newStatus ?? state.currentStatus,
    );
  }

  void setLocatingAdmin(bool value) =>
      state = state.copyWith(isLocatingAdmin: value);
  void setAdminLocation({
    required LatLng point,
    required String address,
    bool isLocating = false,
  }) {
    state = state.copyWith(
      adminPoint: point,
      adminAddress: address,
      isLocatingAdmin: isLocating,
    );
  }
}

final orderDetailsUiProvider = StateNotifierProvider.autoDispose<
    OrderDetailsUiNotifier, OrderDetailsUiState>((ref) {
  return OrderDetailsUiNotifier();
});

// ── Order Navigation State ───────────────────────────────────────────────────
class OrderNavigationState {
  final bool isLoadingRoute;
  final String mapLayer;
  final List<LatLng> roadRoutePoints;
  final List<RouteStep> routeSteps;
  final double totalDistanceMeters;
  final double totalDurationSecs;
  final bool isNavigating;
  final int currentStepIndex;
  final int simulationCoordIndex;
  final LatLng? simulatedCurrentPosition;
  final bool isMuted;
  final bool showStepsSheet;

  const OrderNavigationState({
    this.isLoadingRoute = true,
    this.mapLayer = 'standard',
    this.roadRoutePoints = const [],
    this.routeSteps = const [],
    this.totalDistanceMeters = 0.0,
    this.totalDurationSecs = 0.0,
    this.isNavigating = false,
    this.currentStepIndex = 0,
    this.simulationCoordIndex = 0,
    this.simulatedCurrentPosition,
    this.isMuted = false,
    this.showStepsSheet = false,
  });

  OrderNavigationState copyWith({
    bool? isLoadingRoute,
    String? mapLayer,
    List<LatLng>? roadRoutePoints,
    List<RouteStep>? routeSteps,
    double? totalDistanceMeters,
    double? totalDurationSecs,
    bool? isNavigating,
    int? currentStepIndex,
    int? simulationCoordIndex,
    LatLng? simulatedCurrentPosition,
    bool? isMuted,
    bool? showStepsSheet,
  }) {
    return OrderNavigationState(
      isLoadingRoute: isLoadingRoute ?? this.isLoadingRoute,
      mapLayer: mapLayer ?? this.mapLayer,
      roadRoutePoints: roadRoutePoints ?? this.roadRoutePoints,
      routeSteps: routeSteps ?? this.routeSteps,
      totalDistanceMeters: totalDistanceMeters ?? this.totalDistanceMeters,
      totalDurationSecs: totalDurationSecs ?? this.totalDurationSecs,
      isNavigating: isNavigating ?? this.isNavigating,
      currentStepIndex: currentStepIndex ?? this.currentStepIndex,
      simulationCoordIndex: simulationCoordIndex ?? this.simulationCoordIndex,
      simulatedCurrentPosition:
          simulatedCurrentPosition ?? this.simulatedCurrentPosition,
      isMuted: isMuted ?? this.isMuted,
      showStepsSheet: showStepsSheet ?? this.showStepsSheet,
    );
  }
}

class OrderNavigationNotifier extends StateNotifier<OrderNavigationState> {
  OrderNavigationNotifier() : super(const OrderNavigationState());

  void setLoadingRoute(bool value) =>
      state = state.copyWith(isLoadingRoute: value);
  void setSimulatedPosition(LatLng pos) =>
      state = state.copyWith(simulatedCurrentPosition: pos);
  void toggleMapLayer() => state = state.copyWith(
        mapLayer: state.mapLayer == 'standard' ? 'satellite' : 'standard',
      );
  void toggleMuted() => state = state.copyWith(isMuted: !state.isMuted);
  void setShowStepsSheet(bool value) =>
      state = state.copyWith(showStepsSheet: value);
  void toggleStepsSheet() =>
      state = state.copyWith(showStepsSheet: !state.showStepsSheet);
  void setNavigating(bool value) => state = state.copyWith(isNavigating: value);
  void startNavigation({bool resetIndices = false}) {
    state = state.copyWith(
      isNavigating: true,
      simulationCoordIndex: resetIndices ? 0 : state.simulationCoordIndex,
      currentStepIndex: resetIndices ? 0 : state.currentStepIndex,
    );
  }

  void advanceSimulation({
    required int coordIndex,
    required LatLng position,
    required int stepIndex,
  }) {
    state = state.copyWith(
      simulationCoordIndex: coordIndex,
      simulatedCurrentPosition: position,
      currentStepIndex: stepIndex,
    );
  }

  void selectStep(int index) {
    state = state.copyWith(
      currentStepIndex: index,
      showStepsSheet: false,
    );
  }

  void setRouteResult({
    required List<LatLng> roadRoutePoints,
    List<RouteStep>? routeSteps,
    double? totalDistanceMeters,
    double? totalDurationSecs,
    LatLng? simulatedCurrentPosition,
    bool isLoadingRoute = false,
  }) {
    state = state.copyWith(
      roadRoutePoints: roadRoutePoints,
      routeSteps: routeSteps,
      totalDistanceMeters: totalDistanceMeters,
      totalDurationSecs: totalDurationSecs,
      simulatedCurrentPosition: simulatedCurrentPosition,
      isLoadingRoute: isLoadingRoute,
    );
  }
}

final orderNavigationProvider = StateNotifierProvider.autoDispose<
    OrderNavigationNotifier, OrderNavigationState>((ref) {
  return OrderNavigationNotifier();
});

// ── InDrive Order Map Dialog State ───────────────────────────────────────────
class InDriveOrderMapDialogState {
  final String mapLayer;
  final bool showOrderItems;
  final List<LatLng> roadRoutePoints;
  final bool isLoadingRoute;
  final double? roadDistanceKm;
  final int? roadDurationMins;

  const InDriveOrderMapDialogState({
    this.mapLayer = 'standard',
    this.showOrderItems = false,
    this.roadRoutePoints = const [],
    this.isLoadingRoute = false,
    this.roadDistanceKm,
    this.roadDurationMins,
  });

  InDriveOrderMapDialogState copyWith({
    String? mapLayer,
    bool? showOrderItems,
    List<LatLng>? roadRoutePoints,
    bool? isLoadingRoute,
    double? roadDistanceKm,
    int? roadDurationMins,
  }) {
    return InDriveOrderMapDialogState(
      mapLayer: mapLayer ?? this.mapLayer,
      showOrderItems: showOrderItems ?? this.showOrderItems,
      roadRoutePoints: roadRoutePoints ?? this.roadRoutePoints,
      isLoadingRoute: isLoadingRoute ?? this.isLoadingRoute,
      roadDistanceKm: roadDistanceKm ?? this.roadDistanceKm,
      roadDurationMins: roadDurationMins ?? this.roadDurationMins,
    );
  }
}

class InDriveOrderMapDialogNotifier
    extends StateNotifier<InDriveOrderMapDialogState> {
  InDriveOrderMapDialogNotifier() : super(const InDriveOrderMapDialogState());

  void setLoadingRoute(bool value) =>
      state = state.copyWith(isLoadingRoute: value);
  void toggleMapLayer() => state = state.copyWith(
        mapLayer: state.mapLayer == 'standard' ? 'satellite' : 'standard',
      );
  void toggleShowOrderItems() =>
      state = state.copyWith(showOrderItems: !state.showOrderItems);
  void setRoute({
    required List<LatLng> points,
    double? distanceKm,
    int? durationMins,
    bool isLoading = false,
  }) {
    state = state.copyWith(
      roadRoutePoints: points,
      roadDistanceKm: distanceKm,
      roadDurationMins: durationMins,
      isLoadingRoute: isLoading,
    );
  }
}

final inDriveOrderMapDialogProvider = StateNotifierProvider.autoDispose<
    InDriveOrderMapDialogNotifier, InDriveOrderMapDialogState>((ref) {
  return InDriveOrderMapDialogNotifier();
});
