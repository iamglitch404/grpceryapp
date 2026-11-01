import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/core/widgets/bounceButton.dart';
import 'package:app/core/di/injection.dart';
import 'package:app/features/customer/profile/screens/pointsShopPage.dart';
import 'package:app/features/customer/profile/providers/profileProviders.dart';

class ReferAndEarnPage extends ConsumerStatefulWidget {
  const ReferAndEarnPage({super.key});

  @override
  ConsumerState<ReferAndEarnPage> createState() => _ReferAndEarnPageState();
}

class _ReferAndEarnPageState extends ConsumerState<ReferAndEarnPage> {
  String get _referralCode => ref.watch(referAndEarnCodeProvider);
  bool get _isCopied => ref.watch(referAndEarnCopiedProvider);
  int get _userPoints => ref.watch(referAndEarnPointsProvider);
  Map<String, dynamic> get _stats => ref.watch(referAndEarnStatsProvider);
  List<Map<String, dynamic>> get _referralHistory => ref.watch(referAndEarnHistoryProvider);
  List<Map<String, dynamic>> get _quickRewards => ref.watch(referAndEarnQuickRewardsProvider);

  @override
  void initState() {
    super.initState();
    _loadReferralData();
  }

  Future<void> _loadReferralData() async {
    try {
      final headers = ref.read(authRepositoryProvider).authHeaders;
      final userRepo = ref.read(userRepositoryProvider);

      final refData = await userRepo.fetchReferralData(headers);
      final rewardItems = await userRepo.fetchRewardItems();

      if (mounted) {
        if (refData.isNotEmpty) {
          if (refData['referralCode'] != null) {
            ref.read(referAndEarnCodeProvider.notifier).state = refData['referralCode'];
          }
          if (refData['stats'] != null) {
            ref.read(referAndEarnStatsProvider.notifier).state = Map<String, dynamic>.from(refData['stats']);
          }
          final pts = refData['userPoints'] ?? refData['stats']?['totalEarned'] ?? 0;
          ref.read(referAndEarnPointsProvider.notifier).state = pts;

          final rawHistory = refData['history'] as List<dynamic>?;
          if (rawHistory != null && rawHistory.isNotEmpty) {
            final mapped = rawHistory.map<Map<String, dynamic>>((item) {
              final isDone = item['status'] == 'completed';
              return {
                'name': item['referred_name'] ?? 'Friend',
                'date': item['created_at'] != null 
                    ? DateTime.parse(item['created_at']).toLocal().toString().split(' ')[0] 
                    : 'Recent',
                'status': isDone ? 'Completed' : 'Pending First Order',
                'reward': '+${item['points_rewarded'] ?? 100} Pts',
              };
            }).toList();
            ref.read(referAndEarnHistoryProvider.notifier).state = mapped;
          }
        }

        if (rewardItems.isNotEmpty) {
          final mappedRewards = rewardItems.take(3).map<Map<String, dynamic>>((item) {
            IconData icon = Icons.local_offer_outlined;
            if (item['category'] == 'Delivery Passes') icon = Icons.local_shipping_outlined;
            if (item['category'] == 'Free Items') icon = Icons.inventory_2_outlined;

            return {
              'id': item['id']?.toString() ?? '',
              'title': item['title'] ?? 'Reward Item',
              'points': item['points_cost'] ?? 100,
              'icon': icon,
              'category': item['category'] ?? 'Reward',
            };
          }).toList();
          ref.read(referAndEarnQuickRewardsProvider.notifier).state = mappedRewards;
        }
      }
    } catch (e) {
      debugPrint('[ReferAndEarnPage] Error loading referral data: $e');
    }
  }

  void _copyReferralCode() {
    Clipboard.setData(ClipboardData(text: _referralCode));
    ref.read(referAndEarnCopiedProvider.notifier).state = true;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Referral code "$_referralCode" copied to clipboard!',
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

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) ref.read(referAndEarnCopiedProvider.notifier).state = false;
    });
  }

  void _shareVia(String channel) {
    _copyReferralCode();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Sharing referral code via $channel...'),
        backgroundColor: const Color(0xFF3BA772),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _navigateToPointsShop() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PointsShopPage(userPoints: _userPoints),
      ),
    ).then((_) {
      // Re-render if points were used
      if (mounted) _loadReferralData();
    });
  }

  void _showHowItWorksModal() {
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
                  const Text(
                    'How Points & Refer Works',
                    style: TextStyle(
                      fontSize: 16.5,
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
              _buildModalStep(
                step: '1',
                title: 'Share your referral code',
                desc: 'Invite friends using your unique referral code or direct invite link.',
              ),
              const SizedBox(height: 14),
              _buildModalStep(
                step: '2',
                title: 'Friend joins & places first order',
                desc: 'Your friend gets a ₹100 welcome voucher on their first grocery order.',
              ),
              const SizedBox(height: 14),
              _buildModalStep(
                step: '3',
                title: 'You earn 100 Reward Points',
                desc: '100 Points are credited immediately to your balance when their order completes.',
              ),
              const SizedBox(height: 14),
              _buildModalStep(
                step: '4',
                title: 'Exchange points for free items',
                desc: 'Visit our Rewards Shop anytime to redeem points for groceries, free delivery passes & mega vouchers!',
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

  Widget _buildModalStep({required String step, required String title, required String desc}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(
            color: Color(0xFFEAF5EF),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            step,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1B3D2F),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E2022),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                desc,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF5A6B62),
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showHistoryModal() {
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
                  const Text(
                    'Points History',
                    style: TextStyle(
                      fontSize: 16.5,
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
              ..._referralHistory.map((item) {
                final isDone = item['status'] == 'Completed';
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFEEF0F2)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDone ? const Color(0xFFEAF5EF) : const Color(0xFFFFF4E5),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isDone ? Icons.stars_rounded : Icons.hourglass_top_rounded,
                          color: isDone ? const Color(0xFF3BA772) : Colors.orange,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['name'] as String,
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${item['date']} • ${item['status']}',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDone ? const Color(0xFF5A6B62) : Colors.orange.shade800,
                                fontWeight: isDone ? FontWeight.w400 : FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        item['reward'] as String,
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          color: isDone ? const Color(0xFF1B3D2F) : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // UI Widgets
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildHeroBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5EC), // Exact pastel mint green from reference
        borderRadius: BorderRadius.circular(22),
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
                        text: 'Refer Friends,\n',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1E2022),
                          height: 1.22,
                          letterSpacing: -0.3,
                        ),
                      ),
                      TextSpan(
                        text: 'Earn Points!',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1B6B44),
                          height: 1.22,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Invite your friends to join Dovan and\nearn points for free items.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF5A606A),
                    fontWeight: FontWeight.w400,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: const BoxDecoration(
                        color: Color(0xFFD6F3E2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.card_giftcard_rounded,
                        color: Color(0xFF1B6B44),
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'You get 100 Points',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1E2022),
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'when your friend places their first order',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF5A606A),
                              height: 1.25,
                            ),
                            maxLines: 2,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Image.asset(
            'assets/images/refer_earn_gift.png',
            width: 125,
            height: 115,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return const Icon(
                Icons.card_giftcard_rounded,
                size: 56,
                color: Color(0xFF1B6B44),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildReferralCodeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your Referral Code',
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E2022),
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 12),

          // Code Container with Copy Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF4FBF7),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2F3E9), width: 1),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _referralCode,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1B3D2F),
                    letterSpacing: 0.8,
                  ),
                ),
                BounceButton(
                  onTap: _copyReferralCode,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE5E7EB), width: 0.8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isCopied ? Icons.check_rounded : Icons.content_copy_rounded,
                          size: 14,
                          color: const Color(0xFF1B3D2F),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _isCopied ? 'Copied' : 'Copy',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1B3D2F),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Divider with "or share via"
          Row(
            children: [
              Expanded(child: Divider(color: Colors.grey.shade200, thickness: 1)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  'or share via',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(child: Divider(color: Colors.grey.shade200, thickness: 1)),
            ],
          ),

          const SizedBox(height: 14),

          // Social Share Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildShareChannel(
                icon: Icons.chat_bubble_outline_rounded,
                iconColor: const Color(0xFF25D366),
                bgColor: const Color(0xFFEAF8EF),
                label: 'WhatsApp',
                onTap: () => _shareVia('WhatsApp'),
              ),
              _buildShareChannel(
                icon: Icons.camera_alt_outlined,
                iconColor: const Color(0xFFE1306C),
                bgColor: const Color(0xFFFDEEF2),
                label: 'Instagram',
                onTap: () => _shareVia('Instagram'),
              ),
              _buildShareChannel(
                icon: Icons.facebook_rounded,
                iconColor: const Color(0xFF1877F2),
                bgColor: const Color(0xFFEBF3FE),
                label: 'Facebook',
                onTap: () => _shareVia('Facebook'),
              ),
              _buildShareChannel(
                icon: Icons.more_horiz_rounded,
                iconColor: const Color(0xFF4B5563),
                bgColor: const Color(0xFFF3F4F6),
                label: 'More',
                onTap: () => _shareVia('Other Apps'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildShareChannel({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String label,
    required VoidCallback onTap,
  }) {
    return BounceButton(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF5A6B62),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPointsShopSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF5EF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.storefront_rounded, color: Color(0xFF1B3D2F), size: 18),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Points Rewards Shop',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E2022),
                    ),
                  ),
                ],
              ),
              BounceButton(
                onTap: _navigateToPointsShop,
                child: Row(
                  children: const [
                    Text(
                      'View All',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF3BA772),
                      ),
                    ),
                    SizedBox(width: 2),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 13,
                      color: Color(0xFF3BA772),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Exchange your points for free grocery items, discounts & delivery passes.',
            style: TextStyle(
              fontSize: 11.5,
              color: Color(0xFF717784),
            ),
          ),
          const SizedBox(height: 14),

          // Horizontal quick items
          Row(
            children: _quickRewards.map((item) {
              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(
                    right: item != _quickRewards.last ? 8 : 0,
                  ),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFF2F4F6)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF5EF),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(item['icon'] as IconData, size: 16, color: const Color(0xFF1B3D2F)),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item['title'] as String,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1E2022),
                          height: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.stars_rounded, color: Color(0xFF3BA772), size: 12),
                          const SizedBox(width: 3),
                          Text(
                            '${item['points']} Pts',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF1B3D2F),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      BounceButton(
                        onTap: _navigateToPointsShop,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1B3D2F),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            'Exchange',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEarningsAndHowItWorksCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Your Earnings & View History
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Your Earnings',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E2022),
                ),
              ),
              BounceButton(
                onTap: _showHistoryModal,
                child: Row(
                  children: const [
                    Text(
                      'View History',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF3BA772),
                      ),
                    ),
                    SizedBox(width: 2),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 13,
                      color: Color(0xFF3BA772),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 3 Metric Stat Cards
          Row(
            children: [
              Expanded(
                child: _buildStatBox(
                  icon: Icons.stars_rounded,
                  value: '${_stats['totalEarned']} Pts',
                  label: 'Total Earned',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatBox(
                  icon: Icons.people_outline_rounded,
                  value: '${_stats['friendsJoined']}',
                  label: 'Friends Joined',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatBox(
                  icon: Icons.card_giftcard_rounded,
                  value: '${_stats['pendingRewards']} Pts',
                  label: 'Pending Points',
                ),
              ),
            ],
          ),

          const SizedBox(height: 22),

          // How It Works Heading
          const Text(
            'How it works?',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E2022),
            ),
          ),

          const SizedBox(height: 14),

          // 3-Step Timeline with connected line
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildTimelineStep(
                  stepNumber: '1',
                  label: 'Share your code\nwith friends',
                  showTrailingLine: true,
                ),
              ),
              Expanded(
                child: _buildTimelineStep(
                  stepNumber: '2',
                  label: 'They sign up & place\ntheir first order',
                  showTrailingLine: true,
                ),
              ),
              Expanded(
                child: _buildTimelineStep(
                  stepNumber: '3',
                  label: 'You earn loyalty\npoints',
                  showTrailingLine: false,
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // CTA Invite Button
          BounceButton(
            onTap: _copyReferralCode,
            child: Container(
              width: double.infinity,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF1B3D2F),
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.card_giftcard_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Invite Friends Now',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBox({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF3BA772), size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1E2022),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xFF717784),
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineStep({
    required String stepNumber,
    required String label,
    required bool showTrailingLine,
  }) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            if (showTrailingLine)
              Positioned(
                left: 30,
                right: 0,
                top: 13,
                child: Container(
                  height: 1,
                  color: const Color(0xFFD6F3E2),
                ),
              ),
            Container(
              width: 26,
              height: 26,
              decoration: const BoxDecoration(
                color: Color(0xFFEAF5EF),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                stepNumber,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1B3D2F),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 10.5,
            color: Color(0xFF5A6B62),
            height: 1.25,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildTrustBadge() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF4FBF4),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.verified_user_outlined,
            color: Color(0xFF3BA772),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Safe & Secure',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1B3D2F),
                  ),
                ),
                SizedBox(height: 1),
                Text(
                  'We never share your personal information with anyone.',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: Color(0xFF5A6B62),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
            'Refer & Earn',
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
                  onTap: _showHowItWorksModal,
                  child: const Text(
                    'How it works?',
                    style: TextStyle(
                      color: Color(0xFF3BA772),
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
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
              // 1. Hero Promo Card
              _buildHeroBanner(),
              const SizedBox(height: 16),

              // 2. Your Referral Code Card with Social Share
              _buildReferralCodeCard(),
              const SizedBox(height: 16),

              // 3. Points Rewards Shop Section (Item Exchange)
              _buildPointsShopSection(),
              const SizedBox(height: 16),

              // 4. Your Earnings & Step-by-Step Flow Card
              _buildEarningsAndHowItWorksCard(),
              const SizedBox(height: 16),

              // 5. Safe & Secure Trust Badge
              _buildTrustBadge(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
