import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/core/network/httpClient.dart' as http;
import 'package:app/core/services/routingService.dart';
import 'package:app/features/auth/providers/authRepository.dart';
import 'package:app/features/customer/cart/providers/cartRepository.dart';
import 'package:app/features/customer/orders/providers/orderRepository.dart' as customer_orders;
import 'package:app/features/customer/explore/providers/exploreRepository.dart';
import 'package:app/features/customer/home/providers/productRepository.dart';
import 'package:app/features/customer/home/providers/reviewRepository.dart';
import 'package:app/features/customer/profile/providers/userRepository.dart';
import 'package:app/features/customer/submissions/providers/submissionRepository.dart';
import 'package:app/features/admin/orders/providers/orderRepository.dart' as admin_orders;
import 'package:app/features/delivery/dashboard/providers/deliveryRepository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Riverpod Providers for Core Services & Repositories
// ─────────────────────────────────────────────────────────────────────────────

final routingServiceProvider = Provider<RoutingService>((ref) => RoutingService());
final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository());
final cartRepositoryProvider = Provider<CartRepository>(
  (ref) => CartRepository(ref.watch(authRepositoryProvider)),
);
final customerOrderRepositoryProvider = Provider<customer_orders.OrderRepository>(
  (ref) => customer_orders.OrderRepository(ref.watch(authRepositoryProvider)),
);
final exploreRepositoryProvider = Provider<ExploreRepository>((ref) => ExploreRepository());
final productRepositoryProvider = Provider<ProductRepository>((ref) => ProductRepository());
final reviewRepositoryProvider = Provider<ReviewRepository>((ref) => ReviewRepository());
final userRepositoryProvider = Provider<UserRepository>((ref) => UserRepository());
final submissionRepositoryProvider = Provider<SubmissionRepository>((ref) => SubmissionRepository());
final adminOrderRepositoryProvider = Provider<admin_orders.OrderRepository>(
  (ref) => admin_orders.OrderRepository(ref.watch(authRepositoryProvider)),
);
final deliveryRepositoryProvider = Provider<DeliveryRepository>(
  (ref) => DeliveryRepository(ref.watch(authRepositoryProvider)),
);

/// Global Riverpod ProviderContainer backing the application
late ProviderContainer appProviderContainer;

void setupDependencies() {
  appProviderContainer = ProviderContainer();

  // Core Network unauthorized hook
  http.onUnauthorizedResponse = () {
    try {
      appProviderContainer.read(authRepositoryProvider).logout();
    } catch (_) {}
  };
}
