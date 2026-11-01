// Empty catalog state widget for HomePage.
// Extracted from homePage.dart to reduce its size.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class HomeEmptyCatalogState extends StatelessWidget {
  const HomeEmptyCatalogState({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: const Color(0xFF185B3A).withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(
                  Icons.inventory_2_outlined,
                  size: 28,
                  color: Color(0xFF185B3A),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No products, categories, or deals found',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'The catalog is currently empty. Items will appear once added in the store.',
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: const Color(0xFF64748B),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
