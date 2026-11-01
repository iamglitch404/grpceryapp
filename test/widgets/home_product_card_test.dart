import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/features/customer/home/widgets/homeProductCard.dart';
import 'package:app/core/di/injection.dart';

void main() {
  setUp(() {
    setupDependencies();
  });

  testWidgets('HomeProductCard renders title, price, discount and Add to Cart', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: HomeProductCard(
              id: 'prod-99',
              image: 'https://example.com/item.png',
              title: 'Fresh Organic Apples',
              price: '100',
              unit: '1 kg',
              originalPrice: '150',
              rating: 4.9,
            ),
          ),
        ),
      ),
    );

    // Verify Title and pricing
    expect(find.text('Fresh Organic Apples'), findsOneWidget);
    expect(find.text('₹100'), findsOneWidget);
    expect(find.text('₹150'), findsOneWidget);
    expect(find.text('33% OFF'), findsOneWidget);
    expect(find.text('Add to Cart'), findsOneWidget);
    expect(find.text('4.9'), findsOneWidget);
  });
}

