// Section header with "See more" and horizontal product list.
// Extracted from homePage.dart to reduce its size.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:app/features/customer/home/screens/seeMorePage.dart';
import 'package:app/features/customer/home/widgets/homeProductCard.dart';

/// Section header row with title and "See more" link.
Widget buildSectionHeader({
  required BuildContext context,
  required String title,
  required VoidCallback onSeeMore,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            title,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
              letterSpacing: -0.2,
            ),
          ),
        ),
        GestureDetector(
          onTap: onSeeMore,
          child: Row(
            children: [
              Text(
                'See more',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF185B3A),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF185B3A),
                size: 17,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// Section with horizontal product list (Today's Picks, Special Deals, Popular Items).
class HomeSectionWithSeeMore extends StatelessWidget {
  final String title;
  final List<dynamic> products;

  const HomeSectionWithSeeMore({
    super.key,
    required this.title,
    required this.products,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildSectionHeader(
          context: context,
          title: title,
          onSeeMore: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SeeMorePage(title: title, products: products),
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 236,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            scrollDirection: Axis.horizontal,
            children: products
                .map(
                  (product) => HomeProductCard(
                    id: product['id'],
                    image: product['image'] ?? '',
                    title: product['title'] ?? '',
                    price: product['price'] ?? '',
                    unit: product['unit'] ?? '',
                    originalPrice: product['original_price'] ?? '',
                    description: product['description'],
                    rating: product['avg_rating'],
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}
