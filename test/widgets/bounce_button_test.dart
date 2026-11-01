import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/core/widgets/bounceButton.dart';

void main() {
  testWidgets('BounceButton renders child and triggers onTap', (WidgetTester tester) async {
    bool tapped = false;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: BounceButton(
              onTap: () {
                tapped = true;
              },
              child: const Text('Click Me'),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Click Me'), findsOneWidget);

    await tester.tap(find.text('Click Me'));
    await tester.pumpAndSettle();

    expect(tapped, isTrue);
  });
}

