import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/core/di/injection.dart';

class DeliveryProfileData {
  final Map<String, dynamic>? partner;
  final List<dynamic> reviews;
  final double overallRating;

  const DeliveryProfileData({
    this.partner,
    this.reviews = const [],
    this.overallRating = 5.0,
  });
}

class DeliveryLeaderboardData {
  final List<dynamic> leaderboard;
  final Map<String, dynamic>? myRank;

  const DeliveryLeaderboardData({
    this.leaderboard = const [],
    this.myRank,
  });
}

final deliveryProfileFutureProvider = FutureProvider.autoDispose<DeliveryProfileData>((ref) async {
  final repo = ref.watch(deliveryRepositoryProvider);
  final results = await Future.wait([
    repo.fetchProfile(),
    repo.fetchReviews(),
  ]);

  final profileData = results[0];
  final reviewsData = results[1];

  return DeliveryProfileData(
    partner: profileData?['partner'],
    reviews: reviewsData?['reviews'] ?? [],
    overallRating: (reviewsData?['overall_rating'] ?? 5.0).toDouble(),
  );
});

final deliveryLeaderboardFutureProvider = FutureProvider.autoDispose<DeliveryLeaderboardData>((ref) async {
  final repo = ref.watch(deliveryRepositoryProvider);
  final data = await repo.fetchLeaderboard();
  return DeliveryLeaderboardData(
    leaderboard: data?['leaderboard'] ?? [],
    myRank: data?['my_rank'],
  );
});

