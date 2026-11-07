// Main scrollable home catalog view.
// Extracted from homePage.dart to reduce its size.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/core/widgets/skeletonLoader.dart';
import 'package:app/features/customer/home/widgets/homeBannerCarousel.dart';
import 'package:app/features/customer/home/widgets/homeCategoriesSection.dart';
import 'package:app/features/customer/home/widgets/homeEmptyCatalogState.dart';
import 'package:app/features/customer/home/widgets/homeOffersBanner.dart';
import 'package:app/features/customer/home/widgets/homeSectionWithSeeMore.dart';

/// The scrollable home catalog content.
class HomeScrollView extends ConsumerWidget {
  final List<dynamic> categories;
  final List<dynamic> promotions;
  final List<dynamic> todaysChoice;
  final List<dynamic> specialDeals;
  final List<dynamic> popularItems;
  final List<dynamic> otherProducts;
  final bool isLoading;
  final bool isCatalogEmpty;
  final String? userLocation;
  final bool isLocationSheetOpen;
  final GlobalKey searchBarKey;
  final PageController pageController;
  final int currentBannerIndex;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onLocationTap;
  final VoidCallback onOpenSearch;
  final Widget searchBar;
  final Future<void> Function()? onRefresh;

  const HomeScrollView({
    super.key,
    required this.categories,
    required this.promotions,
    required this.todaysChoice,
    required this.specialDeals,
    required this.popularItems,
    required this.otherProducts,
    required this.isLoading,
    required this.isCatalogEmpty,
    required this.userLocation,
    required this.isLocationSheetOpen,
    required this.searchBarKey,
    required this.pageController,
    required this.currentBannerIndex,
    required this.onPageChanged,
    required this.onLocationTap,
    required this.onOpenSearch,
    required this.searchBar,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: RefreshIndicator(
        onRefresh: onRefresh ?? () async {},
        color: const Color(0xFF185B3A),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          padding: const EdgeInsets.only(bottom: 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Location row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GestureDetector(
                  onTap: onLocationTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 6,
                    ),
                    decoration: const BoxDecoration(
                      color: Colors.transparent,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          color: Color(0xFF42A769),
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Delivering to',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 10,
                                ),
                              ),
                              Text(
                                userLocation ?? 'Set Location',
                                style: const TextStyle(
                                  color: Colors.black87,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        AnimatedRotation(
                          turns: isLocationSheetOpen ? 0.5 : 0.0,
                          duration: const Duration(milliseconds: 300),
                          child: const Icon(
                            Icons.keyboard_arrow_down,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Movable Search Bar in the Home Section
              Padding(
                key: searchBarKey,
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                child: searchBar,
              ),

              if (isLoading &&
                  categories.isEmpty &&
                  promotions.isEmpty &&
                  todaysChoice.isEmpty &&
                  specialDeals.isEmpty &&
                  popularItems.isEmpty &&
                  otherProducts.isEmpty) ...[
                const HomeCatalogSkeleton(),
              ] else if (isCatalogEmpty) ...[
                const HomeEmptyCatalogState(),
              ] else ...[
                const SizedBox(height: 10),
                if (promotions.isNotEmpty) ...[
                  HomeBannerCarousel(
                    promotions: promotions,
                    currentBannerIndex: currentBannerIndex,
                    pageController: pageController,
                    onPageChanged: onPageChanged,
                    isLoading: false,
                  ),
                  const SizedBox(height: 8),
                ],
                HomeCategoriesSection(
                  categories: categories,
                  isLoading: isLoading,
                  onCategoryTap: (index) => onOpenSearch(),
                ),
                if (todaysChoice.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  HomeSectionWithSeeMore(
                    title: "Today's Picks",
                    products: todaysChoice,
                  ),
                ],
                if (specialDeals.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  HomeSectionWithSeeMore(
                    title: 'Special Deal',
                    products: specialDeals,
                  ),
                ],
                const SizedBox(height: 12),
                const HomeOffersBanner(),
                if (popularItems.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  HomeSectionWithSeeMore(
                    title: 'Popular Items',
                    products: popularItems,
                  ),
                ],
                if (otherProducts.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  HomeSectionWithSeeMore(
                    title: 'Explore All Products',
                    products: otherProducts,
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
