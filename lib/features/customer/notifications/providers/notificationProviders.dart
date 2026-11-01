import 'package:flutter_riverpod/flutter_riverpod.dart';

final notificationsSelectedFilterIndexProvider =
    StateProvider.autoDispose<int>((ref) => 0);

final notificationsListProvider =
    StateProvider.autoDispose<List<Map<String, dynamic>>>((ref) => []);

final notificationsUnreadCountProvider =
    StateProvider.autoDispose<int>((ref) => 0);
