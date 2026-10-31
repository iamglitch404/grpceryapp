import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cubepod/cubepod.dart';
import 'package:app/features/customer/explore/data/repositories/explore_repository.dart';
import 'package:app/core/widgets/bounce_button.dart';
import 'package:app/features/customer/explore/presentation/pages/my_offers_page.dart';
import 'package:app/features/customer/support/presentation/pages/help_support_page.dart';

class PromotionsPage extends StatefulWidget {
  const PromotionsPage({super.key});

  @override
  State<PromotionsPage> createState() => _PromotionsPageState();
}

class _PromotionsPageState extends State<PromotionsPage> {
  final TextEditingController _promoCodeController = TextEditingController();
  String? _appliedCode;

  List<Map<String, dynamic>> _offers = [];

  @override
  void initState() {
    super.initState();
    final cached = CubePod.get<ExploreRepository>().getCachedPromotions();
    if (cached.isNotEmpty) {
      _mapAndSetOffers(cached);
    }
    _fetchPromotions();
  }

  @override
  void dispose() {
    _promoCodeController.dispose();
    super.dispose();
  }

  void _mapAndSetOffers(List<dynamic> backendPromos) {
    final mapped = backendPromos.map((p) {
      final discountType = p['discount_type'] ?? 'percentage';
      final badge = p['badge_text'] ?? (discountType == 'free_delivery' ? 'FREE DELIVERY' : '${p['discount_value'] ?? 10}% OFF');
      final badgeParts = badge.toString().split(' ');
      final termsList = (p['terms'] as List<dynamic>?) ?? 
          (p['terms_and_conditions'] != null ? [p['terms_and_conditions']] : [
            'Valid on all eligible grocery orders.',
            'Cannot be combined with other offers.',
          ]);

      return {
        'id': p['id']?.toString() ?? '',
        'code': p['code'] ?? 'OFFER',
        'badge_text': badgeParts.isNotEmpty ? badgeParts.first : 'OFF',
        'badge_sub': badgeParts.length > 1 ? badgeParts.sublist(1).join(' ') : 'OFF',
        'tag': p['category_tag'] ?? 'SITEWIDE',
        'title': p['title'] ?? 'Exclusive Grocery Discount',
        'conditions': p['description'] ?? 'Valid on grocery orders',
        'expiry': 'Valid till 31 May 2026',
        'terms': termsList,
      };
    }).toList();

    setState(() {
      _offers = List<Map<String, dynamic>>.from(mapped);
    });
  }

  Future<void> _fetchPromotions() async {
    try {
      final backendPromos = await CubePod.get<ExploreRepository>().fetchPromotions();
      if (mounted) {
        _mapAndSetOffers(backendPromos);
      }
    } catch (e) {
      debugPrint('[PromotionsPage] Background fetch: $e');
    }
  }

  void _applyCoupon(String code) {
    final cleanCode = code.trim().toUpperCase();
    if (cleanCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter a promo code'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    final matched = _offers.firstWhere(
      (o) => o['code'].toString().toUpperCase() == cleanCode,
      orElse: () => {},
    );

    if (matched.isNotEmpty) {
      setState(() {
        _appliedCode = cleanCode;
      });
      Clipboard.setData(ClipboardData(text: cleanCode));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Code "$cleanCode" applied & copied!',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF1B3D2F),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Text('Promo code "$cleanCode" is invalid or expired.'),
            ],
          ),
          backgroundColor: const Color(0xFFD32F2F),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void _showTermsModal(Map<String, dynamic> offer) {
    final terms = (offer['terms'] as List<dynamic>?) ?? ['Standard terms and conditions apply.'];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Terms & Conditions (${offer['code']})',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1E2022),
                    ),
                  ),
                  BounceButton(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close_rounded, size: 22, color: Color(0xFF1E2022)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...terms.map((term) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: Icon(Icons.circle, size: 5, color: Color(0xFF3BA772)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            term.toString(),
                            style: const TextStyle(fontSize: 13, color: Color(0xFF5A6B62), height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  )),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _applyCoupon(offer['code']);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B3D2F),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: Text(
                    'Apply ${offer['code']}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showHelpDetailModal(String title, String description) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1E2022),
                      ),
                    ),
                  ),
                  BounceButton(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close_rounded, size: 22, color: Color(0xFF1E2022)),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                description,
                style: const TextStyle(fontSize: 13.5, color: Color(0xFF5A6B62), height: 1.45),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B3D2F),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Got it',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // UI Components
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildHeroBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFE5F0EA),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: const TextSpan(
                    children: [
                      TextSpan(
                        text: 'Save more with\n',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1E2022),
                          height: 1.22,
                          letterSpacing: -0.3,
                        ),
                      ),
                      TextSpan(
                        text: 'Exciting Offers!',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1B3D2F),
                          height: 1.22,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Apply promo codes and enjoy exclusive discounts.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF5A6B62),
                    fontWeight: FontWeight.w400,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Image.asset(
            'assets/images/offers_hero.png',
            width: 120,
            height: 90,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return const Icon(
                Icons.card_giftcard_rounded,
                size: 48,
                color: Color(0xFF3BA772),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPromoInputCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F3F5), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.015),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Have a promo code?',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E2022),
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Enter your code and get discount',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF717784),
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 46,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.local_offer_outlined,
                        color: Colors.grey.shade400,
                        size: 17,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _promoCodeController,
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(
                            hintText: 'Enter promo code',
                            hintStyle: TextStyle(
                              color: Color(0xFF9CA3AF),
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E2022),
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              BounceButton(
                onTap: () => _applyCoupon(_promoCodeController.text),
                child: Container(
                  height: 46,
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B3D2F),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'Apply',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCouponCard(Map<String, dynamic> offer) {
    final isApplied = _appliedCode == offer['code'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isApplied ? const Color(0xFF3BA772) : const Color(0xFFF1F3F5),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.015),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left Ticket Stub
            Container(
              width: 86,
              decoration: const BoxDecoration(
                color: Color(0xFFEAF5EF),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    offer['badge_text'] ?? 'OFF',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1B3D2F),
                      height: 1.1,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    offer['badge_sub'] ?? 'OFF',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1B3D2F),
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),

            // Right Voucher Details
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEAF5EF),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  offer['tag'] ?? 'SITEWIDE',
                                  style: const TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF1B3D2F),
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                offer['title'] ?? '',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF1E2022),
                                  height: 1.2,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        BounceButton(
                          onTap: () => _applyCoupon(offer['code']),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: isApplied ? const Color(0xFF1B3D2F) : Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isApplied ? const Color(0xFF1B3D2F) : const Color(0xFFD1D5DB),
                                width: 1.1,
                              ),
                            ),
                            child: Text(
                              isApplied ? 'Applied' : 'Apply',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isApplied ? Colors.white : const Color(0xFF1B3D2F),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      offer['conditions'] ?? '',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF717784),
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 5),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.access_time_rounded, size: 12, color: Color(0xFF8C9199)),
                            const SizedBox(width: 4),
                            Text(
                              offer['expiry'] ?? 'Valid till 31 May 2026',
                              style: const TextStyle(
                                fontSize: 10.5,
                                color: Color(0xFF8C9199),
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                        BounceButton(
                          onTap: () => _showTermsModal(offer),
                          child: const Text(
                            'T&C',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF3BA772),
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHowToUseBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF4FBF4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5F0EA), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: const BoxDecoration(
              color: Color(0xFFEAF5EF),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.percent_rounded,
              color: Color(0xFF3BA772),
              size: 14,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'How to use?',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1B3D2F),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Add items to cart → Go to checkout → Apply code → Enjoy discount!',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF5A6B62),
                    fontWeight: FontWeight.w400,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArticlesSection() {
    final articles = [
      {
        'title': 'How to use\npromo codes?',
        'sheetTitle': 'How to use promo codes?',
        'desc': 'Browse our available offers or enter a custom voucher code. Tap "Apply" to copy and lock in your discount. When proceeding to checkout, your discount will be automatically applied to the total bill!',
        'icon': Icons.local_offer_outlined,
      },
      {
        'title': 'Terms &\nconditions',
        'sheetTitle': 'Promotional Terms & Conditions',
        'desc': 'Promotional codes are valid only for eligible items and must meet the minimum order value. Discounts are not convertible to cash and cannot be combined unless explicitly stated.',
        'icon': Icons.percent_rounded,
      },
      {
        'title': 'Frequently\nasked questions',
        'sheetTitle': 'Frequently Asked Questions',
        'desc': 'Q: Can I use multiple coupons?\nA: Only one promo coupon can be applied per order.\n\nQ: Why did my code fail?\nA: Check if the minimum spend threshold is met or if the coupon has expired.',
        'icon': Icons.chat_bubble_outline_rounded,
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Help',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1E2022),
                letterSpacing: -0.3,
              ),
            ),
            BounceButton(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const HelpSupportPage()),
                );
              },
              child: const Text(
                'View All',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF3BA772),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: articles.map((article) {
            return Expanded(
              child: BounceButton(
                onTap: () => _showHelpDetailModal(article['sheetTitle'] as String, article['desc'] as String),
                child: Container(
                  margin: EdgeInsets.only(
                    right: article != articles.last ? 8 : 0,
                  ),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFF1F3F5), width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.015),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF4F5F6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          article['icon'] as IconData,
                          size: 16,
                          color: const Color(0xFF2D2D2D),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        article['title'] as String,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E2022),
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Align(
                        alignment: Alignment.bottomRight,
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          size: 14,
                          color: Color(0xFF3BA772),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF9F9F9),
        appBar: AppBar(
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
          ),
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          scrolledUnderElevation: 0,
          elevation: 0,
          leading: BounceButton(
            onTap: () => Navigator.pop(context),
            child: const Icon(
              Icons.arrow_back,
              color: Color(0xFF1E2022),
              size: 24,
            ),
          ),
          title: const Text(
            'Promotions & Offers',
            style: TextStyle(
              color: Color(0xFF1E2022),
              fontWeight: FontWeight.w900,
              fontSize: 18,
              letterSpacing: -0.3,
            ),
          ),
          centerTitle: true,
          actions: [
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: BounceButton(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MyOffersPage(initialTabIndex: 0),
                      ),
                    );
                  },
                  child: const Text(
                    'My Offers',
                    style: TextStyle(
                      color: Color(0xFF3BA772),
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        body: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                    // 1. Hero Banner
                    _buildHeroBanner(),
                    const SizedBox(height: 18),

                    // 2. Have a promo code Box
                    _buildPromoInputCard(),
                    const SizedBox(height: 22),

                    // 3. Available Offers Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Available Offers',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF1E2022),
                            letterSpacing: -0.3,
                          ),
                        ),
                        BounceButton(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const MyOffersPage(initialTabIndex: 1),
                              ),
                            );
                          },
                          child: const Text(
                            'View Past Offers',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF3BA772),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Available Offers List
                    if (_offers.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFF1F3F5), width: 1.2),
                        ),
                        alignment: Alignment.center,
                        child: Column(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: const Color(0xFF1B3D2F).withValues(alpha: 0.08),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.local_offer_outlined, color: Color(0xFF1B3D2F), size: 24),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'No active coupons available',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1E2022),
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Check back later for special promotions or enter a custom promo code above.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF717784),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ..._offers.map((offer) => _buildCouponCard(offer)),
                    const SizedBox(height: 8),

                    // 4. How to use banner
                    _buildHowToUseBanner(),
                    const SizedBox(height: 22),

                    // 5. Articles & Help Section
                    _buildArticlesSection(),
                    const SizedBox(height: 28),
                  ],
                ),
              ),
      ),
    );
  }
}
