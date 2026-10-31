import 'package:cubepod_core/cubepod_core.dart';
import 'package:app/core/network/http_client.dart' as http;
import 'package:app/core/services/routing_service.dart';
import 'package:app/features/auth/data/repositories/auth_repository.dart';
import 'package:app/features/auth/presentation/state/auth_view_state.dart';
import 'package:app/features/customer/cart/data/repositories/cart_repository.dart';
import 'package:app/features/customer/cart/presentation/state/cart_state.dart';
import 'package:app/features/customer/notifications/presentation/state/notification_state.dart';
import 'package:app/features/customer/orders/data/repositories/order_repository.dart' as customer_orders;
import 'package:app/features/customer/explore/data/repositories/explore_repository.dart';
import 'package:app/features/customer/home/data/repositories/product_repository.dart';
import 'package:app/features/customer/home/data/repositories/review_repository.dart';
import 'package:app/features/customer/profile/data/repositories/user_repository.dart';
import 'package:app/features/customer/submissions/data/repositories/submission_repository.dart';
import 'package:app/features/admin/data/repositories/order_repository.dart' as admin_orders;
import 'package:app/features/delivery/data/repositories/delivery_repository.dart';

void setupDependencies() {
  // Core Network unauthorized hook
  http.onUnauthorizedResponse = () {
    try {
      CubePod.get<AuthRepository>().logout();
    } catch (_) {}
  };

  // Shared / Core Services
  CubePod.register<RoutingService>((c) => RoutingService(), scope: Scope.singleton);

  // Auth & Core State
  CubePod.register<AuthViewState>((c) => AuthViewState(), scope: Scope.singleton);
  CubePod.register<AuthRepository>((c) => AuthRepository(), scope: Scope.singleton);

  // Customer Domain
  CubePod.register<CartRepository>((c) => CartRepository(), scope: Scope.singleton);
  CubePod.register<CartState>((c) => CartState(), scope: Scope.singleton);
  CubePod.register<NotificationState>((c) => NotificationState(), scope: Scope.singleton);
  CubePod.register<customer_orders.OrderRepository>((c) => customer_orders.OrderRepository(), scope: Scope.singleton);
  CubePod.register<ExploreRepository>((c) => ExploreRepository(), scope: Scope.singleton);
  CubePod.register<ProductRepository>((c) => ProductRepository(), scope: Scope.singleton);
  CubePod.register<ReviewRepository>((c) => ReviewRepository(), scope: Scope.singleton);
  CubePod.register<UserRepository>((c) => UserRepository(), scope: Scope.singleton);
  CubePod.register<SubmissionRepository>((c) => SubmissionRepository(), scope: Scope.singleton);

  // Admin Domain
  CubePod.register<admin_orders.OrderRepository>((c) => admin_orders.OrderRepository(), scope: Scope.singleton);

  // Delivery Domain
  CubePod.register<DeliveryRepository>((c) => DeliveryRepository(), scope: Scope.singleton);
}
