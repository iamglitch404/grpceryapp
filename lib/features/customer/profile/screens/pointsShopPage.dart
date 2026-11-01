import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/core/widgets/bounceButton.dart';
import 'package:app/core/di/injection.dart';
import 'package:app/features/customer/profile/providers/profileProviders.dart';

class PointsShopPage extends ConsumerStatefulWidget {
  final int userPoints;
  const PointsShopPage({super.key, this.userPoints = 0});

  @override
  ConsumerState<PointsShopPage> createState() => _PointsShopPageState();
}

class _PointsShopPageState extends ConsumerState<PointsShopPage> {
  int get _currentPoints => ref.watch(pointsShopCurrentPointsProvider);
  String get _selectedCategory => ref.watch(pointsShopSelectedCategoryProvider);

  final List<String> _categories = ['All', 'Free Items', 'Vouchers', 'Delivery Passes'];
  List<Map<String, dynamic>> get _rewardItems => ref.watch(pointsShopRewardItemsProvider);
  bool get _isRedeeming => ref.watch(pointsShopRedeemingProvider);

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(pointsShopCurrentPointsProvider.notifier).state = widget.userPoints;
      _loadData();
    });
  }

  Future<void> _loadData() async {
    try {
      final headers = ref.read(authRepositoryProvider).authHeaders;
      final userRepo = ref.read(userRepositoryProvider);

      final items = await userRepo.fetchRewardItems();
      final stats = await userRepo.fetchStats(headers);

      if (mounted) {
        if (stats.containsKey('points')) {
          ref.read(pointsShopCurrentPointsProvider.notifier).state = (stats['points'] as num).toInt();
        }

        if (items.isNotEmpty) {
          final mapped = items.map((item) {
            IconData icon = Icons.card_giftcard_rounded;
            if (item['category'] == 'Delivery Passes') icon = Icons.local_shipping_outlined;
            if (item['category'] == 'Free Items') icon = Icons.inventory_2_outlined;
            if (item['category'] == 'Vouchers') icon = Icons.local_offer_outlined;

            return {
              'id': item['id']?.toString() ?? '',
              'title': item['title'] ?? 'Reward Item',
              'category': item['category'] ?? 'Free Items',
              'points': item['points_cost'] ?? 100,
              'tag': item['tag'] ?? 'REWARD',
              'desc': item['description'] ?? 'Redeemable reward item',
              'icon': icon,
              'stock': item['stock_quantity'] ?? 100,
            };
          }).toList();
          ref.read(pointsShopRewardItemsProvider.notifier).state = mapped;
        }
      }
    } catch (e) {
      debugPrint('[PointsShopPage] Error loading data: $e');
    }
  }

  Future<void> _redeemItem(Map<String, dynamic> item) async {
    final itemPoints = item['points'] as int;

    if (_currentPoints < itemPoints) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'You need ${itemPoints - _currentPoints} more points to redeem this item.',
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFD32F2F),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Color(0xFFEAF5EF),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.card_giftcard_rounded, color: Color(0xFF1B3D2F), size: 22),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Confirm Exchange',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF1E2022)),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Exchange $itemPoints Points for:',
              style: const TextStyle(fontSize: 13, color: Color(0xFF717784)),
            ),
            const SizedBox(height: 6),
            Text(
              item['title'] as String,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF1E2022)),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFEEF0F2)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Remaining Balance:', style: TextStyle(fontSize: 12, color: Color(0xFF5A6B62))),
                  Text(
                    '${_currentPoints - itemPoints} Pts',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF1B3D2F)),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF717784), fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            onPressed: _isRedeeming
                ? null
                : () async {
                    Navigator.pop(ctx);
                    ref.read(pointsShopRedeemingProvider.notifier).state = true;

                    final headers = ref.read(authRepositoryProvider).authHeaders;
                    final res = await ref.read(userRepositoryProvider).redeemRewardItem(headers, item['id']);

                    if (mounted) {
                      ref.read(pointsShopRedeemingProvider.notifier).state = false;
                      if (res != null && res['remainingPoints'] != null) {
                        ref.read(pointsShopCurrentPointsProvider.notifier).state =
                            (res['remainingPoints'] as num).toInt();
                      } else {
                        ref.read(pointsShopCurrentPointsProvider.notifier).state =
                            _currentPoints - itemPoints;
                      }

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Redeemed "${item['title']}"! Added to your vouchers.',
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ),
                          backgroundColor: const Color(0xFF1B3D2F),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1B3D2F),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: const Text('Redeem Now', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredItems = _selectedCategory == 'All'
        ? _rewardItems
        : _rewardItems.where((i) => i['category'] == _selectedCategory).toList();

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
            'Points Rewards Shop',
            style: TextStyle(
              color: Color(0xFF1E2022),
              fontWeight: FontWeight.w900,
              fontSize: 18,
              letterSpacing: -0.3,
            ),
          ),
          centerTitle: true,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF5EF),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFD6F3E2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.stars_rounded, color: Color(0xFF3BA772), size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '$_currentPoints Pts',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1B3D2F),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          children: [
            // Points Balance Hero Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFE5F0EA),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(Icons.stars_rounded, color: Color(0xFF3BA772), size: 30),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Available Points Balance',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF5A6B62),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$_currentPoints Points',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF1B3D2F),
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Earn +100 pts for every friend who joins & orders!',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF717784),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // Category Filter Pills
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _categories.map((cat) {
                  final isSelected = _selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: BounceButton(
                      onTap: () => ref.read(pointsShopSelectedCategoryProvider.notifier).state = cat,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF1B3D2F) : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected ? const Color(0xFF1B3D2F) : const Color(0xFFEEF0F2),
                          ),
                        ),
                        child: Text(
                          cat,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                            color: isSelected ? Colors.white : const Color(0xFF5A6B62),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 18),

            // Section Header
            Text(
              'Rewards Catalogue (${filteredItems.length})',
              style: const TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1E2022),
              ),
            ),

            const SizedBox(height: 12),

            // Items List
            if (filteredItems.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                alignment: Alignment.center,
                child: const Text(
                  'No items found in this category.',
                  style: TextStyle(color: Color(0xFF717784), fontSize: 13),
                ),
              )
            else
              for (final item in filteredItems)
                Builder(
                  builder: (context) {
                    final itemPoints = item['points'] as int;
                    final canAfford = _currentPoints >= itemPoints;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFF1F3F5), width: 1.2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.015),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF4FBF7),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE5F0EA)),
                            ),
                            child: Icon(
                              item['icon'] as IconData,
                              color: const Color(0xFF1B3D2F),
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEAF5EF),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        item['tag'] as String,
                                        style: const TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF1B3D2F),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Row(
                                      children: [
                                        const Icon(Icons.stars_rounded, color: Color(0xFF3BA772), size: 14),
                                        const SizedBox(width: 3),
                                        Text(
                                          '$itemPoints Pts',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w900,
                                            color: Color(0xFF1B3D2F),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item['title'] as String,
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF1E2022),
                                    height: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  item['desc'] as String,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF717784),
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          BounceButton(
                            onTap: () => _redeemItem(item),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                              decoration: BoxDecoration(
                                color: canAfford ? const Color(0xFF1B3D2F) : Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                'Exchange',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: canAfford ? Colors.white : Colors.grey.shade600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
          ],
        ),
      ),
    );
  }
}
