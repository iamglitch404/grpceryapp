import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:app/core/di/injection.dart';
import 'package:app/core/models/routeStep.dart';

final availableDeliveryPartnersFutureProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(deliveryRepositoryProvider).fetchAvailableDeliveryPartners();
});

final assignPartnerSearchQueryProvider = StateProvider.autoDispose<String>((ref) => '');

final assigningPartnerIdProvider = StateProvider.autoDispose<String?>((ref) => null);

class DeliveryNavigationState {
  final bool isLoadingRoute;
  final LatLng? driverLocation;
  final List<LatLng> roadPoints;
  final List<RouteStep> routeSteps;
  final double totalDistanceMeters;
  final double totalDurationSecs;
  final int currentStepIndex;

  const DeliveryNavigationState({
    this.isLoadingRoute = true,
    this.driverLocation,
    this.roadPoints = const [],
    this.routeSteps = const [],
    this.totalDistanceMeters = 0.0,
    this.totalDurationSecs = 0.0,
    this.currentStepIndex = 0,
  });

  DeliveryNavigationState copyWith({
    bool? isLoadingRoute,
    LatLng? driverLocation,
    List<LatLng>? roadPoints,
    List<RouteStep>? routeSteps,
    double? totalDistanceMeters,
    double? totalDurationSecs,
    int? currentStepIndex,
  }) {
    return DeliveryNavigationState(
      isLoadingRoute: isLoadingRoute ?? this.isLoadingRoute,
      driverLocation: driverLocation ?? this.driverLocation,
      roadPoints: roadPoints ?? this.roadPoints,
      routeSteps: routeSteps ?? this.routeSteps,
      totalDistanceMeters: totalDistanceMeters ?? this.totalDistanceMeters,
      totalDurationSecs: totalDurationSecs ?? this.totalDurationSecs,
      currentStepIndex: currentStepIndex ?? this.currentStepIndex,
    );
  }
}

class DeliveryNavigationNotifier extends StateNotifier<DeliveryNavigationState> {
  DeliveryNavigationNotifier() : super(const DeliveryNavigationState());

  void setLoadingRoute(bool value) => state = state.copyWith(isLoadingRoute: value);
  void setDriverLocation(LatLng loc) => state = state.copyWith(driverLocation: loc);
  void setRouteData({
    required List<LatLng> roadPoints,
    List<RouteStep>? routeSteps,
    double? totalDistanceMeters,
    double? totalDurationSecs,
    bool isLoadingRoute = false,
  }) {
    state = state.copyWith(
      roadPoints: roadPoints,
      routeSteps: routeSteps,
      totalDistanceMeters: totalDistanceMeters,
      totalDurationSecs: totalDurationSecs,
      isLoadingRoute: isLoadingRoute,
    );
  }
}

final deliveryNavigationProvider = StateNotifierProvider.autoDispose<
    DeliveryNavigationNotifier, DeliveryNavigationState>((ref) {
  return DeliveryNavigationNotifier();
});
