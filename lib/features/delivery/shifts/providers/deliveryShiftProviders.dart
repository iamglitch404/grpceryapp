import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/core/di/injection.dart';
import 'package:app/features/delivery/dashboard/providers/deliveryRepository.dart';

class DeliveryShiftsState {
  final bool isLoading;
  final bool isProcessing;
  final List<dynamic> shifts;
  final Map<String, dynamic>? activeShift;
  final double totalHours;
  final Duration activeDuration;

  const DeliveryShiftsState({
    this.isLoading = true,
    this.isProcessing = false,
    this.shifts = const [],
    this.activeShift,
    this.totalHours = 0.0,
    this.activeDuration = Duration.zero,
  });

  DeliveryShiftsState copyWith({
    bool? isLoading,
    bool? isProcessing,
    List<dynamic>? shifts,
    Map<String, dynamic>? activeShift,
    bool clearActiveShift = false,
    double? totalHours,
    Duration? activeDuration,
  }) {
    return DeliveryShiftsState(
      isLoading: isLoading ?? this.isLoading,
      isProcessing: isProcessing ?? this.isProcessing,
      shifts: shifts ?? this.shifts,
      activeShift: clearActiveShift ? null : (activeShift ?? this.activeShift),
      totalHours: totalHours ?? this.totalHours,
      activeDuration: activeDuration ?? this.activeDuration,
    );
  }
}

class DeliveryShiftsNotifier extends StateNotifier<DeliveryShiftsState> {
  final DeliveryRepository _repo;

  DeliveryShiftsNotifier(this._repo) : super(const DeliveryShiftsState()) {
    loadShifts();
  }

  Future<void> loadShifts() async {
    state = state.copyWith(isLoading: true);
    final data = await _repo.fetchShifts();
    if (!mounted) return;
    if (data != null) {
      final shifts = data['shifts'] ?? [];
      final totalHours = (data['total_hours'] ?? 0.0).toDouble();
      final active = shifts.cast<Map<String, dynamic>>().firstWhere(
        (s) => s['status'] == 'active',
        orElse: () => {},
      );
      final activeShift = active.isNotEmpty ? active : null;
      Duration duration = Duration.zero;
      if (activeShift != null && activeShift['clock_in_at'] != null) {
        final inTime = DateTime.tryParse(activeShift['clock_in_at']);
        if (inTime != null) {
          duration = DateTime.now().difference(inTime);
        }
      }
      state = state.copyWith(
        isLoading: false,
        shifts: shifts,
        activeShift: activeShift,
        clearActiveShift: activeShift == null,
        totalHours: totalHours,
        activeDuration: duration,
      );
    } else {
      state = state.copyWith(isLoading: false);
    }
  }

  void tickDuration() {
    if (state.activeShift != null && state.activeShift!['clock_in_at'] != null) {
      final inTime = DateTime.tryParse(state.activeShift!['clock_in_at']);
      if (inTime != null) {
        state = state.copyWith(activeDuration: DateTime.now().difference(inTime));
      }
    }
  }

  Future<bool> toggleShift() async {
    state = state.copyWith(isProcessing: true);
    final isClockedIn = state.activeShift != null;
    final success = isClockedIn ? await _repo.clockOut() : await _repo.clockIn();
    if (!mounted) return false;
    state = state.copyWith(isProcessing: false);
    if (success) {
      await loadShifts();
    }
    return success;
  }
}

final deliveryShiftsNotifierProvider =
    StateNotifierProvider.autoDispose<DeliveryShiftsNotifier, DeliveryShiftsState>((ref) {
  final repo = ref.watch(deliveryRepositoryProvider);
  return DeliveryShiftsNotifier(repo);
});

