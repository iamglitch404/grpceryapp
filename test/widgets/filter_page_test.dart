import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/features/customer/home/screens/filterPage.dart';

void main() {
  testWidgets('FilterPage renders controls and allows selecting options', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: FilterPage(),
        ),
      ),
    );

    // Verify Title and Section Headers
    expect(find.text('Sort & Filter'), findsOneWidget);
    expect(find.text('Price Range'), findsOneWidget);
    expect(find.text('Ratings'), findsOneWidget);
    expect(find.text('Vegan Friendly'), findsOneWidget);
    expect(find.text('Apply Filter'), findsOneWidget);

    // Verify rating options exist
    expect(find.text('5 Stars'), findsOneWidget);
    expect(find.text('4 Stars'), findsOneWidget);
    expect(find.text('3 Stars'), findsOneWidget);

    // Tap on a rating option
    await tester.tap(find.text('4 Stars'));
    await tester.pumpAndSettle();
  });
}
