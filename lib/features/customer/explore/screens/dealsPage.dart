import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:app/core/di/injection.dart';
import 'package:app/features/customer/widgets/customerTopBar.dart';
import 'package:app/core/widgets/skeletonImage.dart';
import 'package:app/features/customer/home/screens/productDetailPage.dart';
import 'package:app/features/customer/home/screens/campaignDealsPage.dart';
import 'package:app/features/customer/explore/screens/promotionsPage.dart';
import 'package:app/features/customer/explore/providers/exploreProviders.dart';
import 'package:app/features/customer/cart/providers/cartState.dart';
import 'package:app/features/customer/widgets/favoriteButton.dart';

class DealsPage extends ConsumerStatefulWidget {
  const DealsPage({super.key});

  @override
  ConsumerState<DealsPage> createState() => _DealsPageState();
}

class _DealsPageState extends ConsumerState<DealsPage> {
  int get _currentHeroIndex => ref.read(dealsCurrentHeroIndexProvider);
  String get _selectedCategory => ref.read(dealsSelectedCategoryProvider);
  String get _searchQuery => ref.read(dealsSearchQueryProvider);
  final TextEditingController _searchController = TextEditingController();

  List<dynamic> get _homeDeals => ref.read(dealsHomeDealsProvider);
  List<dynamic> get _categories => ref.read(dealsCategoriesProvider);
  List<dynamic> get _flashDeals => ref.read(dealsFlashDealsProvider);
  List<dynamic> get _trendingDeals => ref.read(dealsTrendingDealsProvider);
  List<dynamic> get _allDeals => ref.read(dealsAllDealsProvider);
  bool get _isLoading => ref.read(dealsIsLoadingProvider);

  // Countdown timer state for Flash Deals
  Duration get _timeLeft => ref.read(dealsTimeLeftProvider);
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final cached = ref.read(exploreRepositoryProvider).getCachedDealsData();
      if (cached != null && cached.isNotEmpty) {
        ref.read(dealsHomeDealsProvider.notifier).state = cached['homeDeals'] ?? [];
        ref.read(dealsCategoriesProvider.notifier).state = cached['categories'] ?? [];
        ref.read(dealsFlashDealsProvider.notifier).state = cached['flashDeals'] ?? [];
        ref.read(dealsTrendingDealsProvider.notifier).state = cached['trendingDeals'] ?? [];
        ref.read(dealsAllDealsProvider.notifier).state = cached['recentDeals'] ?? [];
        ref.read(dealsIsLoadingProvider.notifier).state = false;
      }
      _fetchDeals();
    });

    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        final current = ref.read(dealsTimeLeftProvider);
        if (current.inSeconds > 0) {
          ref.read(dealsTimeLeftProvider.notifier).state =
              current - const Duration(seconds: 1);
        }
      }
    });
  }

  String _formatTimer(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(d.inHours);
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return '$hours : $minutes : $seconds';
  }

  Future<void> _fetchDeals() async {
    try {
      final data = await ref.read(exploreRepositoryProvider).fetchDealsData();

      if (mounted) {
        ref.read(dealsHomeDealsProvider.notifier).state = data['homeDeals'] ?? [];
        ref.read(dealsCategoriesProvider.notifier).state = data['categories'] ?? [];
        ref.read(dealsFlashDealsProvider.notifier).state = data['flashDeals'] ?? [];
        ref.read(dealsTrendingDealsProvider.notifier).state = data['trendingDeals'] ?? [];
        ref.read(dealsAllDealsProvider.notifier).state = data['recentDeals'] ?? [];
        ref.read(dealsIsLoadingProvider.notifier).state = false;
      }
    } catch (e) {
      debugPrint('Error fetching deals: $e');
      if (mounted) ref.read(dealsIsLoadingProvider.notifier).state = false;
    }
  }

  List<dynamic> get _filteredGridDeals {
    List<dynamic> list;
    if (_selectedCategory == 'flash') {
      list = _flashDeals.isNotEmpty ? _flashDeals : _allDeals;
    } else if (_selectedCategory == 'super') {
      list = _trendingDeals.isNotEmpty ? _trendingDeals : _allDeals;
    } else if (_selectedCategory != 'all') {
      list = (_allDeals.isNotEmpty ? _allDeals : _flashDeals).where((p) {
        final catId = p['category_id']?.toString() ?? '';
        final catName = (p['categories'] is Map ? p['categories']['name'] : p['category_name'])?.toString().toLowerCase() ?? '';
        return catId == _selectedCategory || catName.contains(_selectedCategory.toLowerCase());
      }).toList();
    } else {
      list = _allDeals.isNotEmpty ? _allDeals : _flashDeals;
    }

    if (_searchQuery.trim().isNotEmpty) {
      list = list.where((p) {
        final title = (p['title'] ?? '').toString().toLowerCase();
        return title.contains(_searchQuery.toLowerCase());
      }).toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(dealsCurrentHeroIndexProvider);
    ref.watch(dealsSelectedCategoryProvider);
    ref.watch(dealsSearchQueryProvider);
    ref.watch(dealsHomeDealsProvider);
    ref.watch(dealsCategoriesProvider);
    ref.watch(dealsFlashDealsProvider);
    ref.watch(dealsTrendingDealsProvider);
    ref.watch(dealsAllDealsProvider);
    ref.watch(dealsIsLoadingProvider);
    ref.watch(dealsTimeLeftProvider);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: const CustomerAppBar(),
        body: RefreshIndicator(
          color: const Color(0xFF185B3A),
          onRefresh: _fetchDeals,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                _buildSearchBar(),
                  if (_isLoading && _allDeals.isEmpty && _flashDeals.isEmpty && _homeDeals.isEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 60),
                      child: Center(
                        child: CircularProgressIndicator(color: Color(0xFF185B3A)),
                      ),
                    ),
                  ] else if (_hasNoDeals) ...[
                    _buildEmptyDealsState(),
                  ] else ...[
                    const SizedBox(height: 12),
                    _buildHeroCarousel(),
                    const SizedBox(height: 20),
                    _buildCategoryPills(),
                    const SizedBox(height: 24),
                    _buildFlashDealsSection(),
                    const SizedBox(height: 20),
                    _buildOffersVoucherBanner(),
                    const SizedBox(height: 24),
                    _buildSuperSaversSection(),
                    const SizedBox(height: 36),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
  }

  bool get _hasNoDeals =>
      !_isLoading &&
      _allDeals.isEmpty &&
      _flashDeals.isEmpty &&
      _trendingDeals.isEmpty &&
      _homeDeals.isEmpty;

  Widget _buildEmptyDealsState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
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
              child: const Icon(
                Icons.local_offer_outlined,
                size: 28,
                color: Color(0xFF185B3A),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No active deals or promotions right now',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Check back later for exclusive deals and discounts.',
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

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            const SizedBox(width: 14),
            const Icon(Icons.search_rounded, color: Color(0xFF94A3B8), size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _searchController,
                onChanged: (val) => ref.read(dealsSearchQueryProvider.notifier).state = val,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF0F172A),
                ),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Search discount deals, fruits, snacks...',
                  hintStyle: GoogleFonts.outfit(
                    color: const Color(0xFF94A3B8),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w400,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            if (_searchQuery.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF94A3B8)),
                onPressed: () {
                  _searchController.clear();
                  ref.read(dealsSearchQueryProvider.notifier).state = '';
                },
              ),
            const SizedBox(width: 6),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroCarousel() {
    if (_homeDeals.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        SizedBox(
          height: 165,
          child: PageView.builder(
            onPageChanged: (idx) => ref.read(dealsCurrentHeroIndexProvider.notifier).state = idx,
            itemCount: _homeDeals.length,
            itemBuilder: (context, index) {
              final deal = _homeDeals[index];
              final title = deal['title'] ?? 'Exclusive Deal';
              final subtitle = deal['subtitle'] ?? deal['description'] ?? 'Special Discount Today';
              final badge = deal['discount_badge'] ?? 'SPECIAL OFFER';
              final imageUrl = deal['image_url'] ?? '';

              Color startColor = const Color(0xFF185B3A);
              Color endColor = const Color(0xFF277E53);
              if (deal['theme_color'] != null) {
                try {
                  final hex = deal['theme_color'].toString().replaceAll('#', '');
                  if (hex.length == 6) {
                    startColor = Color(int.parse('0xFF$hex'));
                    endColor = Color(int.parse('0xFF$hex')).withValues(alpha: 0.85);
                  }
                } catch (_) {}
              }

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CampaignDealsPage(
                        campaign: deal is Map<String, dynamic> ? deal : Map<String, dynamic>.from(deal),
                      ),
                    ),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [startColor, endColor],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: startColor.withValues(alpha: 0.25),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      if (imageUrl.isNotEmpty)
                        Positioned(
                          right: -10,
                          bottom: 0,
                          top: 0,
                          width: 170,
                          child: ClipRRect(
                            borderRadius: const BorderRadius.only(
                              topRight: Radius.circular(20),
                              bottomRight: Radius.circular(20),
                              topLeft: Radius.circular(60),
                              bottomLeft: Radius.circular(60),
                            ),
                            child: SkeletonImage(
                              imageUrl: imageUrl,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                badge.toString().toUpperCase(),
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: 170,
                              child: Text(
                                title,
                                style: GoogleFonts.outfit(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: -0.5,
                                  height: 1.15,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(height: 4),
                            SizedBox(
                              width: 160,
                              child: Text(
                                subtitle,
                                style: GoogleFonts.outfit(
                                  fontSize: 11.5,
                                  color: Colors.white.withValues(alpha: 0.88),
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        if (_homeDeals.length > 1) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_homeDeals.length, (index) {
              final isSel = _currentHeroIndex == index;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: isSel ? 18 : 6,
                height: 5,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  color: isSel ? const Color(0xFF185B3A) : const Color(0xFFCBD5E1),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }

  Widget _buildCategoryPills() {
    final defaultTabs = [
      {'id': 'all', 'label': 'All Deals', 'icon': Icons.local_offer_rounded},
      {'id': 'flash', 'label': '⚡ Flash Deals', 'icon': Icons.bolt_rounded},
      {'id': 'super', 'label': '🔥 Super Saver', 'icon': Icons.discount_rounded},
    ];

    final dynamicTabs = _categories.map((c) {
      return {
        'id': c['id']?.toString() ?? c['name']?.toString() ?? '',
        'label': c['name']?.toString() ?? 'Category',
        'icon': Icons.shopping_bag_outlined,
      };
    }).toList();

    final allTabs = [...defaultTabs, ...dynamicTabs];

    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: allTabs.length,
        itemBuilder: (context, index) {
          final tab = allTabs[index];
          final tabId = tab['id'] as String;
          final isSelected = _selectedCategory == tabId;

          return GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              ref.read(dealsSelectedCategoryProvider.notifier).state = tabId;
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF185B3A) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? const Color(0xFF185B3A) : const Color(0xFFE2E8F0),
                  width: 1.2,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: const Color(0xFF185B3A).withValues(alpha: 0.2),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: Text(
                  tab['label'] as String,
                  style: GoogleFonts.outfit(
                    fontSize: 12.5,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    color: isSelected ? Colors.white : const Color(0xFF475569),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFlashDealsSection() {
    if (_flashDeals.isEmpty && !_isLoading) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.bolt_rounded, color: Color(0xFFD97706), size: 20),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Flash Deals',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F6EF),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFBCE3D1)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.timer_outlined, size: 14, color: Color(0xFF185B3A)),
                    const SizedBox(width: 5),
                    Text(
                      _formatTimer(_timeLeft),
                      style: GoogleFonts.outfit(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF185B3A),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 242,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF185B3A)))
              : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  itemCount: _flashDeals.length,
                  itemBuilder: (context, index) {
                    final p = _flashDeals[index];
                    return _buildProductCard(p);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildOffersVoucherBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 18),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE8F6EF), Color(0xFFF4FAF6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFBCE3D1), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF185B3A).withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF185B3A), Color(0xFF277E53)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF185B3A).withValues(alpha: 0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(Icons.local_offer_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Save More with Coupons',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Claim flat & percentage discounts at checkout',
                  style: GoogleFonts.outfit(
                    fontSize: 11.5,
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PromotionsPage()),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFF185B3A),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Explore →',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuperSaversSection() {
    final deals = _filteredGridDeals;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Super Savers & Top Picks',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
              Text(
                '${deals.length} items',
                style: GoogleFonts.outfit(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: deals.isEmpty
              ? Container(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  alignment: Alignment.center,
                  child: Column(
                    children: [
                      const Icon(Icons.search_off_rounded, size: 48, color: Color(0xFF94A3B8)),
                      const SizedBox(height: 10),
                      Text(
                        'No deals found matching filter',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Try selecting a different category or search term.',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                )
              : GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: deals.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 0.61,
                  ),
                  itemBuilder: (context, index) {
                    final p = deals[index];
                    return _buildGridDealCard(p);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildProductCard(dynamic p) {
    final id = p['id'];
    final image = p['image'] as String? ?? p['image_url'] as String? ?? '';
    final title = p['title'] as String? ?? 'Deal Product';
    final unit = p['unit'] as String? ?? '1 kg';
    final rating = p['avg_rating'] ?? 4.8;

    int priceVal = 0;
    if (p['price_paise'] != null) {
      priceVal = ((p['price_paise'] as num) / 100).round();
    } else if (p['price'] != null) {
      priceVal = int.tryParse(p['price'].toString().replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    }
    final priceStr = '₹$priceVal';

    int origVal = 0;
    if (p['original_price_paise'] != null) {
      origVal = ((p['original_price_paise'] as num) / 100).round();
    } else if (p['original_price'] != null) {
      origVal = int.tryParse(p['original_price'].toString().replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    }
    final origStr = origVal > priceVal ? '₹$origVal' : '';

    int discountPct = 0;
    if (origVal > priceVal && origVal > 0) {
      discountPct = (((origVal - priceVal) / origVal) * 100).round();
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductDetailPage(
              id: id,
              image: image,
              title: title,
              price: priceStr,
              unit: unit,
              originalPrice: origStr,
              description: p['description'],
              rating: rating,
            ),
          ),
        );
      },
      child: Container(
        width: 154,
        margin: const EdgeInsets.only(right: 12, bottom: 4, top: 2),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 108,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                    child: SkeletonImage(imageUrl: image, fit: BoxFit.cover),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: 32,
                        child: Text(
                          title,
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                            color: const Color(0xFF0F172A),
                            height: 1.18,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 13),
                          const SizedBox(width: 2),
                          Text(
                            rating.toString(),
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w700,
                              fontSize: 10.5,
                              color: const Color(0xFF475569),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '•  $unit',
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              color: const Color(0xFF94A3B8),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            priceStr,
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: const Color(0xFF185B3A),
                            ),
                          ),
                          const SizedBox(width: 5),
                          if (origStr.isNotEmpty)
                            Text(
                              origStr,
                              style: GoogleFonts.outfit(
                                fontSize: 10.5,
                                color: const Color(0xFF94A3B8),
                                decoration: TextDecoration.lineThrough,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    ref.read(cartStateProvider).addToCart(context, id);
                  },
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF185B3A), Color(0xFF277E53)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF185B3A).withValues(alpha: 0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.add_shopping_cart_rounded, color: Colors.white, size: 13),
                        const SizedBox(width: 5),
                        Text(
                          'Add to Cart',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (discountPct > 0)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE11D48),
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFE11D48).withValues(alpha: 0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Text(
                    '$discountPct% OFF',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            Positioned(
              top: 8,
              right: 8,
              child: FavoriteButton(
                productId: id,
                iconSize: 16,
                padding: 6,
                hasShadow: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridDealCard(dynamic p) {
    final id = p['id'];
    final image = p['image'] as String? ?? p['image_url'] as String? ?? '';
    final title = p['title'] as String? ?? 'Deal Product';
    final unit = p['unit'] as String? ?? '1 kg';
    final rating = p['avg_rating'] ?? 4.8;

    int priceVal = 0;
    if (p['price_paise'] != null) {
      priceVal = ((p['price_paise'] as num) / 100).round();
    } else if (p['price'] != null) {
      priceVal = int.tryParse(p['price'].toString().replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    }
    final priceStr = '₹$priceVal';

    int origVal = 0;
    if (p['original_price_paise'] != null) {
      origVal = ((p['original_price_paise'] as num) / 100).round();
    } else if (p['original_price'] != null) {
      origVal = int.tryParse(p['original_price'].toString().replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    }
    final origStr = origVal > priceVal ? '₹$origVal' : '';

    int discountPct = 0;
    if (origVal > priceVal && origVal > 0) {
      discountPct = (((origVal - priceVal) / origVal) * 100).round();
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductDetailPage(
              id: id,
              image: image,
              title: title,
              price: priceStr,
              unit: unit,
              originalPrice: origStr,
              description: p['description'],
              rating: rating,
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                      child: SkeletonImage(imageUrl: image, fit: BoxFit.cover),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: 34,
                        child: Text(
                          title,
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: const Color(0xFF0F172A),
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 14),
                          const SizedBox(width: 2),
                          Text(
                            rating.toString(),
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                              color: const Color(0xFF475569),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '•  $unit',
                            style: GoogleFonts.outfit(
                              fontSize: 10.5,
                              color: const Color(0xFF94A3B8),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            priceStr,
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w800,
                              fontSize: 14.5,
                              color: const Color(0xFF185B3A),
                            ),
                          ),
                          const SizedBox(width: 5),
                          if (origStr.isNotEmpty)
                            Text(
                              origStr,
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                color: const Color(0xFF94A3B8),
                                decoration: TextDecoration.lineThrough,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    ref.read(cartStateProvider).addToCart(context, id);
                  },
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF185B3A), Color(0xFF277E53)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF185B3A).withValues(alpha: 0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.add_shopping_cart_rounded, color: Colors.white, size: 13),
                        const SizedBox(width: 5),
                        Text(
                          'Add to Cart',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (discountPct > 0)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE11D48),
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFE11D48).withValues(alpha: 0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Text(
                    '$discountPct% OFF',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            Positioned(
              top: 8,
              right: 8,
              child: FavoriteButton(
                productId: id,
                iconSize: 16,
                padding: 6,
                hasShadow: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
