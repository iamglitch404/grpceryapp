// Campaign banner carousel with pagination dots for HomePage.
// Extracted from homePage.dart to reduce its size.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:app/features/customer/home/screens/campaignDealsPage.dart';

/// Signature C-shaped curve clipper for campaign hero images
class CCurveClipper extends CustomClipper<Path> {
  const CCurveClipper();

  @override
  Path getClip(Size size) {
    final path = Path();
    // Start top-left
    path.moveTo(size.width * 0.16, 0);
    // Smooth C-shaped arc along the left edge
    path.quadraticBezierTo(
      0,
      size.height * 0.5,
      size.width * 0.16,
      size.height,
    );
    // Bottom-right corner
    path.lineTo(size.width, size.height);
    // Top-right corner
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// Parses a hex color string with fallback.
Color parseHexColor(String? hex, Color fallback) {
  if (hex == null || hex.isEmpty) return fallback;
  try {
    final clean = hex.replaceAll('#', '');
    return Color(int.parse('FF$clean', radix: 16));
  } catch (_) {
    return fallback;
  }
}

/// Campaign banner carousel widget.
class HomeBannerCarousel extends StatelessWidget {
  final List<dynamic> promotions;
  final int currentBannerIndex;
  final PageController pageController;
  final ValueChanged<int> onPageChanged;
  final bool isLoading;

  const HomeBannerCarousel({
    super.key,
    required this.promotions,
    required this.currentBannerIndex,
    required this.pageController,
    required this.onPageChanged,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading && promotions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          height: 182,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              colors: [Color(0xFFE8F5EE), Color(0xFFF1F8F4)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: const Color(0xFFC7E6D7), width: 1.2),
          ),
        ),
      );
    }

    if (promotions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SizedBox(
        height: 182,
        child: PageView.builder(
          controller: pageController,
          onPageChanged: onPageChanged,
          itemCount: promotions.length,
          itemBuilder: (context, index) {
            final promo = promotions[index];
            final title = promo['title']?.toString() ?? '';
            final subtitle = (promo['subtitle'] ?? promo['description'])?.toString() ?? '';
            final badge = promo['badge_text']?.toString() ?? '';
            final btnText = promo['button_text']?.toString() ?? 'Shop Now';
            final image = promo['image_url']?.toString() ?? '';

            final Color bgColor = parseHexColor(
              promo['bg_color']?.toString(),
              const Color(0xFFE8F5EE),
            );
            final Color btnColor = parseHexColor(
              promo['button_color']?.toString(),
              const Color(0xFF185B3A),
            );

            final Map<String, dynamic> campaignData = Map<String, dynamic>.from(promo);

            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CampaignDealsPage(campaign: campaignData),
                  ),
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: btnColor.withValues(alpha: 0.18), width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: btnColor.withValues(alpha: 0.06),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Row(
                    children: [
                      // Left Text Column
                      Expanded(
                        flex: 11,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(18, 14, 10, 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (badge.isNotEmpty) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                                  decoration: BoxDecoration(
                                    color: btnColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: btnColor.withValues(alpha: 0.2),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.bolt_rounded,
                                        size: 12,
                                        color: btnColor,
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        badge,
                                        style: GoogleFonts.outfit(
                                          color: btnColor,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 6),
                              ],
                              Text(
                                title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.outfit(
                                  color: const Color(0xFF0F172A),
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w800,
                                  height: 1.15,
                                ),
                              ),
                              if (subtitle.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  subtitle,
                                  maxLines: 2,
                                  style: GoogleFonts.outfit(
                                    color: const Color(0xFF475569),
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w500,
                                    height: 1.25,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: btnColor,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: btnColor.withValues(alpha: 0.25),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      btnText,
                                      style: GoogleFonts.outfit(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(
                                      Icons.arrow_forward_rounded,
                                      color: Colors.white,
                                      size: 12,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Right Image with Signature "C" Curve
                      if (image.isNotEmpty)
                        Expanded(
                          flex: 9,
                          child: ClipPath(
                            clipper: const CCurveClipper(),
                            child: SizedBox.expand(
                              child: Image.network(
                                image,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => Container(
                                  color: btnColor.withValues(alpha: 0.08),
                                  child: Icon(
                                    Icons.shopping_bag_outlined,
                                    color: btnColor,
                                    size: 36,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Banner pagination dots.
class HomeBannerPaginationDots extends StatelessWidget {
  final int currentBannerIndex;
  final int promotionCount;

  const HomeBannerPaginationDots({
    super.key,
    required this.currentBannerIndex,
    required this.promotionCount,
  });

  @override
  Widget build(BuildContext context) {
    if (promotionCount <= 1) return const SizedBox.shrink();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        promotionCount,
        (index) => AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: currentBannerIndex == index ? 22 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: currentBannerIndex == index
                ? const Color(0xFF185B3A)
                : const Color(0xFFCBD5E1),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ),
    );
  }
}
