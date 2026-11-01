import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/core/di/injection.dart';
import 'package:app/features/delivery/dashboard/screens/standbyPage.dart';
import 'package:flutter/material.dart';

void main() {
  test('setupDependencies registers core, customer, and admin repositories with Riverpod', () {
    setupDependencies();

    // Riverpod ProviderContainer resolution
    expect(appProviderContainer.read(routingServiceProvider), isNotNull);
    expect(appProviderContainer.read(customerOrderRepositoryProvider), isNotNull);
    expect(appProviderContainer.read(submissionRepositoryProvider), isNotNull);
    expect(appProviderContainer.read(adminOrderRepositoryProvider), isNotNull);
  });

  testWidgets('StandbyPage renders role boundary correctly', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: StandbyPage(),
        ),
      ),
    );

    expect(find.text('Dovan Logistics'), findsOneWidget);
    expect(find.text('Sign Out'), findsNothing); // Tooltip on IconButton
    expect(find.byIcon(Icons.logout_rounded), findsNWidgets(2));
  });
}
