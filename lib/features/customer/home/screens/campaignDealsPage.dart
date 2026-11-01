import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:app/core/di/injection.dart';
import 'package:app/features/customer/home/providers/homeProviders.dart';
import 'package:app/features/customer/home/screens/productDetailPage.dart';
import 'package:app/features/customer/cart/providers/cartState.dart';
import 'package:app/features/customer/widgets/favoriteButton.dart';
import 'package:app/core/widgets/skeletonImage.dart';

class CampaignDealsPage extends ConsumerStatefulWidget {
  final Map<String, dynamic> campaign;

  const CampaignDealsPage({
    super.key,
    required this.campaign,
  });

  @override
  ConsumerState<CampaignDealsPage> createState() => _CampaignDealsPageState();
}

class _CampaignDealsPageState extends ConsumerState<CampaignDealsPage> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(_fetchCampaignProducts);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchCampaignProducts() async {
    ref.read(campaignDealsProvider.notifier).setLoading(true);
    try {
      final productRepo = ref.read(productRepositoryProvider);
      final targetType = widget.campaign['target_type']?.toString().toLowerCase();
      final targetId = widget.campaign['target_id']?.toString() ?? widget.campaign['target_category_id']?.toString();
      
      List<String>? specificProductIds;
      if (widget.campaign['product_ids'] is List) {
        specificProductIds = (widget.campaign['product_ids'] as List).map((e) => e.toString()).toList();
      }

      final bool isRandom = targetType == 'random' || widget.campaign['is_random'] == true;

      final products = await productRepo.fetchCampaignProducts(
        categoryId: targetType == 'category' ? targetId : null,
        productIds: specificProductIds,
        isRandom: isRandom,
      );

      if (mounted) {
        ref.read(campaignDealsProvider.notifier).setProductsAndLoading(products, false);
      }
    } catch (e) {
      debugPrint('[CampaignDealsPage] Error loading products: $e');
      if (mounted) {
        ref.read(campaignDealsProvider.notifier).setLoading(false);
      }
    }
  }

  Color _parseHex(String? hex, Color fallback) {
    if (hex == null || hex.isEmpty) return fallback;
    try {
      final clean = hex.replaceAll('#', '');
      if (clean.length == 6) {
        return Color(int.parse('0xFF$clean'));
      }
      return fallback;
    } catch (_) {
      return fallback;
    }
  }

  List<dynamic> _getFilteredProducts(CampaignDealsState dealsState) {
    var list = List<dynamic>.from(dealsState.products);

    // Search query filter
    if (dealsState.searchQuery.trim().isNotEmpty) {
      list = list.where((p) {
        final title = (p['title'] ?? p['name'] ?? '').toString().toLowerCase();
        return title.contains(dealsState.searchQuery.toLowerCase());
      }).toList();
    }

    // Quick tab filters
    if (dealsState.selectedFilter == 'Under ₹100') {
      list = list.where((p) {
        final price = _parsePriceVal(p['price'] ?? p['price_paise']);
        return price > 0 && price <= 100;
      }).toList();
    } else if (dealsState.selectedFilter == 'Rating 4.5+') {
      list = list.where((p) {
        final rating = double.tryParse((p['avg_rating'] ?? p['rating'] ?? 0).toString()) ?? 0.0;
        return rating >= 4.5;
      }).toList();
    } else if (dealsState.selectedFilter == 'Special Deals') {
      list = list.where((p) => p['is_special_deal'] == true || p['original_price'] != null || p['original_price_paise'] != null).toList();
    }

    return list;
  }

  int _parsePriceVal(dynamic raw) {
    if (raw == null) return 0;
    if (raw is int) {
      return raw > 1000 ? (raw / 100).round() : raw;
    }
    final cleaned = raw.toString().replaceAll(RegExp(r'[^0-9]'), '');
    final val = int.tryParse(cleaned) ?? 0;
    return val > 1000 ? (val / 100).round() : val;
  }

  @override
  Widget build(BuildContext context) {
    final dealsState = ref.watch(campaignDealsProvider);
    final title = widget.campaign['title']?.toString() ?? 'Exclusive Deals';
    final subtitle = widget.campaign['subtitle']?.toString() ?? widget.campaign['description']?.toString() ?? 'Grab the best deals today!';
    final badge = widget.campaign['badge_text']?.toString() ?? widget.campaign['discount_badge']?.toString() ?? '⚡ FLASH SALE';
    final imageUrl = widget.campaign['image_url']?.toString() ?? '';
    final discount = widget.campaign['discount_percent']?.toString() ?? '25';
    final bgColor = _parseHex(widget.campaign['bg_color']?.toString() ?? widget.campaign['theme_color']?.toString(), const Color(0xFFFDF2F4));
    final btnColor = _parseHex(widget.campaign['button_color']?.toString(), const Color(0xFF185B3A));

    final filteredList = _getFilteredProducts(dealsState);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A), size: 19),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
            ),
          ),
          centerTitle: true,
        ),
        body: Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                color: const Color(0xFF185B3A),
                onRefresh: _fetchCampaignProducts,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),

                      // ── Search Bar ──
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
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
                                  onChanged: (val) => ref.read(campaignDealsProvider.notifier).setSearchQuery(val),
                                  style: GoogleFonts.outfit(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFF0F172A),
                                  ),
                                  decoration: InputDecoration(
                                    border: InputBorder.none,
                                    hintText: 'Search items in this campaign...',
                                    hintStyle: GoogleFonts.outfit(
                                      color: const Color(0xFF94A3B8),
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w400,
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                                  ),
                                ),
                              ),
                              if (dealsState.searchQuery.isNotEmpty)
                                IconButton(
                                  icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF94A3B8)),
                                  onPressed: () {
                                    _searchController.clear();
                                    ref.read(campaignDealsProvider.notifier).setSearchQuery('');
                                  },
                                ),
                              const SizedBox(width: 6),
                            ],
                          ),
                        ),
                      ),

                      // ── Hero Campaign Banner ──
                      Container(
                        margin: const EdgeInsets.fromLTRB(18, 8, 18, 14),
                        decoration: BoxDecoration(
                          color: bgColor,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFE2E8F0).withValues(alpha: 0.8)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Row(
                            children: [
                              // Left Text
                              Expanded(
                                flex: 11,
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
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
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.bolt_rounded, size: 13, color: btnColor),
                                              const SizedBox(width: 3),
                                              Text(
                                                badge.toUpperCase(),
                                                style: GoogleFonts.outfit(
                                                  color: btnColor,
                                                  fontSize: 9.5,
                                                  fontWeight: FontWeight.w800,
                                                  letterSpacing: 0.4,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                      ],
                                      Text(
                                        title,
                                        style: GoogleFonts.outfit(
                                          color: const Color(0xFF0F172A),
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          height: 1.15,
                                          letterSpacing: -0.4,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (subtitle.isNotEmpty) ...[
                                        const SizedBox(height: 5),
                                        Text(
                                          subtitle,
                                          style: GoogleFonts.outfit(
                                            color: const Color(0xFF475569),
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w500,
                                            height: 1.25,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),

                              // Right Image with Signature "C" Curve
                              if (imageUrl.isNotEmpty)
                                Expanded(
                                  flex: 9,
                                  child: ClipPath(
                                    clipper: const CCurveClipper(),
                                    child: SizedBox(
                                      height: 135,
                                      child: SkeletonImage(
                                        imageUrl: imageUrl,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),

                      // ── Quick Filter Chips ──
                      SizedBox(
                        height: 38,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          children: [
                            _buildFilterChip('All', dealsState.selectedFilter),
                            _buildFilterChip('Special Deals', dealsState.selectedFilter),
                            _buildFilterChip('Under ₹100', dealsState.selectedFilter),
                            _buildFilterChip('Rating 4.5+', dealsState.selectedFilter),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // ── Section Title & Count ──
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Exclusive Deal Items',
                              style: GoogleFonts.outfit(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE2E8F0),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${filteredList.length} items',
                                style: GoogleFonts.outfit(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF475569),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // ── Product Grid ──
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        child: dealsState.isLoading
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 40),
                                  child: CircularProgressIndicator(color: Color(0xFF185B3A)),
                                ),
                              )
                            : filteredList.isEmpty
                                ? Container(
                                    padding: const EdgeInsets.symmetric(vertical: 40),
                                    alignment: Alignment.center,
                                    child: Column(
                                      children: [
                                        const Icon(Icons.search_off_rounded, size: 48, color: Color(0xFF94A3B8)),
                                        const SizedBox(height: 10),
                                        Text(
                                          'No items found matching criteria',
                                          style: GoogleFonts.outfit(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : GridView.builder(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      mainAxisSpacing: 14,
                                      crossAxisSpacing: 14,
                                      childAspectRatio: 0.61,
                                    ),
                                    itemCount: filteredList.length,
                                    itemBuilder: (context, index) {
                                      final p = filteredList[index];
                                      return _buildProductCard(p, discount);
                                    },
                                  ),
                      ),
                      const SizedBox(height: 36),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String selectedFilter) {
    final isSelected = selectedFilter == label;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        ref.read(campaignDealsProvider.notifier).setSelectedFilter(label);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF185B3A) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF185B3A) : const Color(0xFFE2E8F0),
            width: 1.1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF185B3A).withValues(alpha: 0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 12.5,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              color: isSelected ? Colors.white : const Color(0xFF475569),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductCard(dynamic p, String defaultDiscount) {
    final id = p['id'];
    final image = p['image'] as String? ?? p['image_url'] as String? ?? '';
    final title = p['title'] as String? ?? p['name'] as String? ?? 'Product';
    final unit = p['unit'] as String? ?? '1 kg';
    final rating = p['avg_rating'] ?? p['rating'] ?? 4.8;

    int priceVal = _parsePriceVal(p['price'] ?? p['price_paise']);
    final priceStr = '₹$priceVal';

    int origVal = _parsePriceVal(p['original_price'] ?? p['original_price_paise']);
    if (origVal <= priceVal && priceVal > 0) {
      final double discountDbl = double.tryParse(defaultDiscount) ?? 25;
      origVal = (priceVal * (1 + (discountDbl / 100))).round();
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
              description: p['description']?.toString(),
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

/// Precise "C" Curve Bezier Clipper matching hero banner aesthetics
class CCurveClipper extends CustomClipper<Path> {
  const CCurveClipper();

  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(size.width * 0.16, 0);

    path.quadraticBezierTo(
      0,
      size.height * 0.5,
      size.width * 0.16,
      size.height,
    );

    path.lineTo(size.width, size.height);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
