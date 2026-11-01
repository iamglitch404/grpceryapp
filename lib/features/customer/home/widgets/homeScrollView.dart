// Main scrollable home catalog view.
// Extracted from homePage.dart to reduce its size.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:app/core/di/injection.dart';
import 'package:app/features/auth/screens/authPage.dart';
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
    final isLoggedIn = ref.watch(authRepositoryProvider).isLoggedIn;

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

              if (!isLoggedIn) ...[
                const HomeLoginBanner(),
              ],

              if (!isLoggedIn && isCatalogEmpty) ...[
                const HomeGuestLoginPrompt(),
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

class HomeLoginBanner extends StatelessWidget {
  const HomeLoginBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF185B3A),
            const Color(0xFF185B3A).withValues(alpha: 0.88),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF185B3A).withValues(alpha: 0.22),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lock_open_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Log in to see items',
                  style: GoogleFonts.outfit(
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Sign in to view all items, save favorites & place orders',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.88),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AuthPage()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF185B3A),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              'Log In',
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class HomeGuestLoginPrompt extends StatelessWidget {
  const HomeGuestLoginPrompt({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFF185B3A).withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(
                  Icons.lock_outline_rounded,
                  size: 32,
                  color: Color(0xFF185B3A),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Log in to see items',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F172A),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Please log in to your account to view available grocery items, special deals, and order directly.',
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: const Color(0xFF64748B),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 200,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AuthPage()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF185B3A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Log In / Sign Up',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
