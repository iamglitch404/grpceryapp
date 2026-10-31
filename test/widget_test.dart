import 'package:flutter_test/flutter_test.dart';
import 'package:cubepod_core/cubepod_core.dart';
import 'package:app/core/di/injection.dart';
import 'package:app/core/services/routing_service.dart';
import 'package:app/features/customer/orders/data/repositories/order_repository.dart' as customer_orders;
import 'package:app/features/admin/data/repositories/order_repository.dart' as admin_orders;
import 'package:app/features/customer/submissions/data/repositories/submission_repository.dart';
import 'package:app/features/delivery/presentation/pages/standby_page.dart';
import 'package:flutter/material.dart';

void main() {
  test('setupDependencies registers core, customer, and admin repositories', () {
    setupDependencies();

    // Core Shared Geospatial Service
    expect(CubePod.get<RoutingService>(), isNotNull);

    // Customer Domain Repositories
    expect(CubePod.get<customer_orders.OrderRepository>(), isNotNull);
    expect(CubePod.get<SubmissionRepository>(), isNotNull);

    // Admin Domain Repository
    expect(CubePod.get<admin_orders.OrderRepository>(), isNotNull);
  });

  testWidgets('StandbyPage renders role boundary correctly', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: StandbyPage(),
      ),
    );

    expect(find.text('Dovan Logistics'), findsOneWidget);
    expect(find.text('Sign Out'), findsNothing); // Tooltip on IconButton
    expect(find.byIcon(Icons.logout_rounded), findsNWidgets(2));
  });
}
