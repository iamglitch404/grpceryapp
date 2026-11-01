import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:app/core/config/appConfig.dart';
import 'package:app/core/di/injection.dart';
import 'package:app/core/network/httpClient.dart' as http;

class CustomerLeaderboardData {
  final List<Map<String, dynamic>> topUsers;
  final Map<String, dynamic>? currentUserStats;

  const CustomerLeaderboardData({
    this.topUsers = const [],
    this.currentUserStats,
  });
}

final allUsersSearchQueryProvider = StateProvider.autoDispose<String>((ref) => '');

final allUsersTierFilterProvider = StateProvider.autoDispose<String>((ref) => 'All');

String _getTierFromPoints(int points) {
  if (points >= 2500) return 'Diamond';
  if (points >= 1000) return 'Platinum';
  if (points >= 500) return 'Gold';
  if (points >= 200) return 'Silver';
  return 'Bronze';
}

final customerLeaderboardFutureProvider =
    FutureProvider.autoDispose<CustomerLeaderboardData>((ref) async {
  final authRepo = ref.watch(authRepositoryProvider);
  final userRepo = ref.watch(userRepositoryProvider);
  final headers = authRepo.authHeaders;

  final results = await Future.wait([
    userRepo.fetchLeaderboard(headers),
    userRepo.fetchStats(headers),
  ]);

  final leaderboardData = results[0] as List<dynamic>;
  final statsData = results[1] as Map<String, dynamic>;

  final topUsers = leaderboardData.map<Map<String, dynamic>>((u) {
    final pts = u['points'] is int ? u['points'] : int.tryParse(u['points']?.toString() ?? '0') ?? 0;
    return {
      'rank': u['rank'] ?? 0,
      'user_id': u['user_id']?.toString() ?? '',
      'name': u['name']?.toString() ?? 'Customer',
      'profile_image': u['profile_image']?.toString(),
      'points': pts,
      'tier': u['tier']?.toString() ?? _getTierFromPoints(pts),
    };
  }).toList();

  return CustomerLeaderboardData(
    topUsers: topUsers,
    currentUserStats: statsData,
  );
});

// ── Settings ──
final settingsPushNotificationsProvider = StateProvider.autoDispose<bool>((ref) => true);

// ── Payment Methods ──
final paymentMethodsSelectedProvider = StateProvider.autoDispose<String>((ref) => 'Cash on Delivery');

// ── Add Address ──
final addAddressLoadingProvider = StateProvider.autoDispose<bool>((ref) => false);

// ── Saved Addresses ──
final savedAddressesListProvider = StateProvider.autoDispose<List<Map<String, dynamic>>>((ref) => []);
final savedAddressesLoadingProvider = StateProvider.autoDispose<bool>((ref) => true);

// ── All Users ──
final allUsersListProvider = StateProvider.autoDispose<List<Map<String, dynamic>>>((ref) => []);
final allUsersLoadingProvider = StateProvider.autoDispose<bool>((ref) => false);
final allUsersLoadingMoreProvider = StateProvider.autoDispose<bool>((ref) => false);

// ── Points Shop ──
final pointsShopSelectedCategoryProvider = StateProvider.autoDispose<String>((ref) => 'All');
final pointsShopCurrentPointsProvider = StateProvider.autoDispose<int>((ref) => 0);
final pointsShopRewardItemsProvider = StateProvider.autoDispose<List<Map<String, dynamic>>>((ref) => []);
final pointsShopRedeemingProvider = StateProvider.autoDispose<bool>((ref) => false);

// ── Refer and Earn ──
final referAndEarnCodeProvider = StateProvider.autoDispose<String>((ref) => 'DOVAN50');
final referAndEarnStatsProvider = StateProvider.autoDispose<Map<String, dynamic>>((ref) => {
  'totalEarned': 0,
  'successfulReferrals': 0,
  'pendingReferrals': 0,
});
final referAndEarnPointsProvider = StateProvider.autoDispose<int>((ref) => 0);
final referAndEarnHistoryProvider = StateProvider.autoDispose<List<Map<String, dynamic>>>((ref) => []);
final referAndEarnQuickRewardsProvider = StateProvider.autoDispose<List<Map<String, dynamic>>>((ref) => []);
final referAndEarnCopiedProvider = StateProvider.autoDispose<bool>((ref) => false);

// ── Personal Info & Edit Profile ──
final personalInfoStateProvider = StateProvider.autoDispose<Map<String, dynamic>>((ref) => {});
final editProfileStateProvider = StateProvider.autoDispose<Map<String, dynamic>>((ref) => {});
final editProfileLoadingProvider = StateProvider.autoDispose<bool>((ref) => false);
final editProfileAvatarProvider = StateProvider.autoDispose<XFile?>((ref) => null);

// ── User Stats ──
final userStatsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final authRepo = ref.watch(authRepositoryProvider);
  final headers = authRepo.authHeaders;

  final response = await http.get(
    Uri.parse('${AppConfig.apiUrl}/user/stats'),
    headers: headers,
  );

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    return Map<String, dynamic>.from(data);
  }
  return {};
});

