// Categories section for HomePage with section header and horizontal scroll.
// Extracted from homePage.dart to reduce its size.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Returns an icon for a category name.
IconData getCategoryIcon(String name) {
  final n = name.toLowerCase();
  if (n.contains('fruit') || n.contains('veg')) return Icons.eco_rounded;
  if (n.contains('dairy') || n.contains('milk') || n.contains('egg') || n.contains('breakfast')) return Icons.egg_outlined;
  if (n.contains('beverage') || n.contains('drink') || n.contains('tea') || n.contains('coffee') || n.contains('juice')) return Icons.local_cafe_outlined;
  if (n.contains('bakery') || n.contains('bread') || n.contains('snack') || n.contains('cookie')) return Icons.bakery_dining_outlined;
  if (n.contains('organic') || n.contains('farm') || n.contains('honey') || n.contains('ghee')) return Icons.spa_rounded;
  return Icons.grid_view_rounded;
}

/// Returns a color for a category name, using hex if provided.
Color getCategoryColor(String name, String? hex) {
  if (hex != null && hex.isNotEmpty) {
    try {
      final cleanHex = hex.replaceAll('#', '');
      return Color(int.parse('FF$cleanHex', radix: 16));
    } catch (_) {}
  }
  final n = name.toLowerCase();
  if (n.contains('fruit') || n.contains('veg')) return const Color(0xFF185B3A);
  if (n.contains('dairy') || n.contains('milk') || n.contains('egg')) return const Color(0xFFD97706);
  if (n.contains('beverage') || n.contains('drink')) return const Color(0xFF0284C7);
  if (n.contains('bakery') || n.contains('snack')) return const Color(0xFFE11D48);
  if (n.contains('organic')) return const Color(0xFF059669);
  return const Color(0xFF185B3A);
}

/// Categories section header row.
Widget buildCategoriesHeader({
  required BuildContext context,
  required VoidCallback onViewAll,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            'Shop by Categories',
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
          onTap: onViewAll,
          child: Row(
            children: [
              Text(
                'View all',
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

/// Categories horizontal scroll section.
class HomeCategoriesSection extends StatelessWidget {
  final List<dynamic> categories;
  final bool isLoading;
  final ValueChanged<int> onCategoryTap;

  const HomeCategoriesSection({
    super.key,
    required this.categories,
    required this.isLoading,
    required this.onCategoryTap,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading && categories.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Shop by Categories',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
                letterSpacing: -0.2,
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 96,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: 5,
              separatorBuilder: (_, _) => const SizedBox(width: 14),
              itemBuilder: (context, index) {
                return Column(
                  children: [
                    Container(
                      width: 62,
                      height: 62,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE2E8F0),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 54,
                      height: 10,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      );
    }

    if (categories.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildCategoriesHeader(
          context: context,
          onViewAll: () {
            // View all handler is provided by parent via onCategoryTap
            // This is handled by the parent's _openSearch() call
          },
        ),
        const SizedBox(height: 10),

        // Categories Horizontal Scroll with Edge-to-Edge Padding & Zero Stretching
        SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: categories.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final cat = categories[index];
              final name = cat['label'] ?? cat['name'] ?? 'Category';
              final image = cat['image'] ?? cat['image_url'];
              final colorHex = cat['color_hex'];
              final themeColor = getCategoryColor(name, colorHex);
              final iconData = getCategoryIcon(name);
              final hasImage = image != null && image.toString().trim().isNotEmpty;

              return GestureDetector(
                onTap: () => onCategoryTap(index),
                child: SizedBox(
                  width: 72,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 62,
                        height: 62,
                        decoration: BoxDecoration(
                          color: themeColor.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: themeColor.withValues(alpha: 0.25),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: themeColor.withValues(alpha: 0.15),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Center(
                          child: hasImage
                              ? ClipOval(
                                  child: Image.network(
                                    image.toString(),
                                    width: 62,
                                    height: 62,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => Icon(
                                      iconData,
                                      color: themeColor,
                                      size: 26,
                                    ),
                                  ),
                                )
                              : Icon(
                                  iconData,
                                  color: themeColor,
                                  size: 26,
                                ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      SizedBox(
                        height: 28,
                        child: Text(
                          name,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            fontSize: 10.5,
                            color: const Color(0xFF1E293B),
                            fontWeight: FontWeight.w600,
                            height: 1.15,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
