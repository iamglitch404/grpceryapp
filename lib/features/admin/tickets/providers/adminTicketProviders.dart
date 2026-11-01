import 'package:flutter_riverpod/flutter_riverpod.dart';

final adminTicketFilterProvider = StateProvider.autoDispose<String>((ref) => 'All');

final adminTicketSortProvider = StateProvider.autoDispose<String>((ref) => 'Latest');

final adminTicketSearchQueryProvider = StateProvider.autoDispose<String>((ref) => '');

final adminTicketsListProvider = StateProvider.autoDispose<List<dynamic>>((ref) => []);

final adminTicketsLoadingProvider = StateProvider.autoDispose<bool>((ref) => true);

final adminTicketsFetchingFreshProvider = StateProvider.autoDispose<bool>((ref) => false);

