import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:app/core/widgets/bounce_button.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cubepod_core/cubepod_core.dart';
import 'package:app/features/customer/profile/data/repositories/user_repository.dart';
import 'package:app/features/customer/profile/presentation/pages/leaderboard_page.dart';
import 'package:app/features/customer/profile/presentation/pages/settings_page.dart';
import 'package:app/features/customer/profile/presentation/pages/payment_methods_page.dart';
import 'package:app/features/customer/support/presentation/pages/help_support_page.dart';
import 'package:app/features/customer/profile/presentation/pages/personal_info_page.dart';
import 'package:app/features/customer/explore/presentation/pages/promotions_page.dart';
import 'package:app/features/customer/support/presentation/pages/reviews_page.dart';
import 'package:app/features/customer/orders/presentation/pages/order_history_page.dart';
import 'package:app/features/customer/profile/presentation/pages/saved_addresses_page.dart';
import 'package:app/features/customer/profile/presentation/pages/wishlist_page.dart';
import 'package:app/features/customer/profile/presentation/pages/refer_and_earn_page.dart';
import 'package:app/features/auth/presentation/pages/auth_page.dart';
import 'package:app/features/auth/data/repositories/auth_repository.dart';
import 'package:app/features/customer/notifications/presentation/pages/notifications_page.dart';
import 'package:cubepod_flutter/cubepod_flutter.dart';
import 'package:app/features/customer/notifications/presentation/state/notification_state.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  Future<Map<String, dynamic>> _fetchUserStats() async {
    try {
      final userRepo = CubePod.get<UserRepository>();
      final authRepo = CubePod.get<AuthRepository>();
      if (authRepo.isLoggedIn) {
        authRepo.syncCurrentUser();
      }
      final headers = authRepo.authHeaders;
      final stats = await userRepo.fetchStats(headers);
      if (stats.isNotEmpty) return stats;

      final cached = await userRepo.getCachedStats();
      if (cached != null && cached.isNotEmpty) return cached;
    } catch (e) {
      debugPrint('Error fetching stats: $e');
    }
    return {
      'points': 0,
      'totalOrders': 0,
      'globalRank': '-',
      'tier': 'Bronze',
      'pointsLastUpdatedAt': DateTime.now().toIso8601String(),
    };
  }

  void _navigateToProtectedPage(BuildContext context, Widget target) {
    if (CubePod.get<AuthRepository>().isLoggedIn) {
      Navigator.push(context, CupertinoPageRoute(builder: (context) => target));
    } else {
      Navigator.push(
        context,
        CupertinoPageRoute(builder: (context) => const AuthPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<String, dynamic>?>(
      valueListenable: CubePod.get<AuthRepository>().authStateNotifier,
      builder: (context, currentUser, child) {
        final isLoggedIn = currentUser != null;
        final userName = isLoggedIn
            ? (currentUser['name'] ?? 'User')
            : 'Hello, Guest!';
        final userEmail = isLoggedIn
            ? (currentUser['email'] ?? '')
            : 'Log in / Sign up to unlock full features\nand get the best experience.';

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
          ),
          child: Scaffold(
            backgroundColor: const Color(0xFFF9F9F9),
            body: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _buildHeaderSection(
                    context,
                    isLoggedIn,
                    userName,
                    userEmail,
                    currentUser,
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      isLoggedIn
                          ? _buildUserStatsBanner(context)
                          : _buildJoinDovanBanner(context),
                      const SizedBox(height: 24),
                      _buildSectionHeader('My Account', 'View Profile', () {
                        _navigateToProtectedPage(
                          context,
                          const PersonalInfoPage(),
                        );
                      }),
                      const SizedBox(height: 12),
                      _buildSettingsGroup([
                        _buildSettingItem(
                          context,
                          icon: Icons.location_on,
                          iconBgColor: const Color(0xFFE8F5E9),
                          iconColor: const Color(0xFF42A769),
                          title: 'Saved Addresses',
                          subtitle: 'Manage your delivery addresses',
                          onTap: () => _navigateToProtectedPage(
                            context,
                            const SavedAddressesPage(),
                          ),
                        ),
                        _buildSettingItem(
                          context,
                          icon: Icons.credit_card,
                          iconBgColor: const Color(0xFFE8F5E9),
                          iconColor: const Color(0xFF42A769),
                          title: 'Payment Methods',
                          subtitle: 'Add or manage payment options',
                          onTap: () => _navigateToProtectedPage(
                            context,
                            const PaymentMethodsPage(),
                          ),
                        ),
                        _buildSettingItem(
                          context,
                          icon: Icons.shopping_bag_outlined,
                          iconBgColor: Colors.orange.withValues(alpha: 0.15),
                          iconColor: Colors.orange,
                          title: 'Order History',
                          subtitle: 'View and track your past orders',
                          onTap: () => _navigateToProtectedPage(
                            context,
                            const OrderHistoryPage(),
                          ),
                        ),
                        _buildSettingItem(
                          context,
                          icon: Icons.star_border,
                          iconBgColor: Colors.purple.withValues(alpha: 0.15),
                          iconColor: Colors.purple,
                          title: 'My Reviews',
                          subtitle: 'Reviews & ratings for your orders',
                          onTap: () => _navigateToProtectedPage(
                            context,
                            const ReviewsPage(),
                          ),
                        ),
                        _buildSettingItem(
                          context,
                          icon: Icons.favorite_border,
                          iconBgColor: Colors.red.withValues(alpha: 0.15),
                          iconColor: Colors.red,
                          title: 'Wishlist',
                          subtitle: 'Your saved items',
                          onTap: () => _navigateToProtectedPage(
                            context,
                            const WishlistPage(),
                          ),
                          showDivider: false,
                        ),
                      ]),
                      const SizedBox(height: 24),
                      _buildSettingsGroup([
                        _buildSettingItem(
                          context,
                          icon: Icons.local_offer_outlined,
                          iconBgColor: const Color(0xFFE8F5E9),
                          iconColor: const Color(0xFF42A769),
                          title: 'Promotions & Offers',
                          subtitle: 'Grab best deals and discounts',
                          onTap: () => _navigateToProtectedPage(
                            context,
                            const PromotionsPage(),
                          ),
                        ),
                        _buildSettingItem(
                          context,
                          icon: Icons.card_giftcard,
                          iconBgColor: Colors.orange.withValues(alpha: 0.15),
                          iconColor: Colors.orange,
                          title: 'Refer & Earn',
                          subtitle: 'Invite friends & earn rewards',
                          onTap: () => _navigateToProtectedPage(
                            context,
                            const ReferAndEarnPage(),
                          ),
                          showDivider: false,
                        ),
                      ]),

                      const SizedBox(height: 24),
                      _buildSettingsGroup([
                        _buildSettingItem(
                          context,
                          icon: Icons.headset_mic_outlined,
                          iconBgColor: Colors.blue.withValues(alpha: 0.15),
                          iconColor: Colors.blue,
                          title: 'Help & Support',
                          subtitle: 'FAQs, support & help center',
                          onTap: () {
                            Navigator.push(
                              context,
                              CupertinoPageRoute(
                                builder: (context) => const HelpSupportPage(),
                              ),
                            );
                          },
                        ),
                        _buildSettingItem(
                          context,
                          icon: Icons.settings_outlined,
                          iconBgColor: Colors.grey.withValues(alpha: 0.2),
                          iconColor: Colors.grey.shade700,
                          title: 'Settings',
                          subtitle: 'Manage app preferences',
                          onTap: () {
                            Navigator.push(
                              context,
                              CupertinoPageRoute(
                                builder: (context) => const SettingsPage(),
                              ),
                            );
                          },
                          showDivider: isLoggedIn ? true : false,
                        ),
                        if (isLoggedIn)
                          _buildSettingItem(
                            context,
                            icon: Icons.logout,
                            iconBgColor: Colors.red.withValues(alpha: 0.15),
                            iconColor: Colors.red,
                            title: 'Log Out',
                            subtitle: 'Sign out of your account',
                            onTap: () async {
                              await CubePod.get<AuthRepository>().logout();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Logged out successfully!'),
                                    backgroundColor: Color(0xFF42A769),
                                  ),
                                );
                              }
                            },
                            showDivider: false,
                          ),
                      ]),
                      const SizedBox(height: 24),
                      _buildPrivacyBanner(),
                      const SizedBox(height: 16),
                      const Center(
                        child: Text(
                          'App Version 1.0.0',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(
                        height: 16,
                      ), // Small padding for bottom of list
                    ]),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeaderSection(
    BuildContext context,
    bool isLoggedIn,
    String userName,
    String userEmail,
    Map<String, dynamic>? currentUser,
  ) {
    final scale = MediaQuery.of(context).size.width / 400;
    return Container(
      color: Colors.white,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Top Action Bar
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 16 * scale,
                vertical: 8 * scale,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        CupertinoPageRoute(
                          builder: (context) => const NotificationsPage(),
                        ),
                      );
                    },
                    child: CubeBuilder(
                      builder: (context, watch) {
                        final notifState = CubePod.get<NotificationState>();
                        final unread = watch(notifState.unreadCount);

                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            SvgPicture.asset(
                              'assets/icons/ic_bell.svg',
                              width: 24 * scale,
                              height: 24 * scale,
                              colorFilter: const ColorFilter.mode(
                                Color(0xFF4A4A4A),
                                BlendMode.srcIn,
                              ),
                            ),
                            if (unread > 0)
                              Positioned(
                                right: -2 * scale,
                                top: -2 * scale,
                                child: Container(
                                  padding: EdgeInsets.all(3 * scale),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    unread > 99 ? '99+' : unread.toString(),
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 8 * scale,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                  SizedBox(width: 16 * scale),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        CupertinoPageRoute(
                          builder: (context) => const SettingsPage(),
                        ),
                      );
                    },
                    child: SvgPicture.asset(
                      'assets/icons/ic_settings.svg',
                      width: 24 * scale,
                      height: 24 * scale,
                      colorFilter: const ColorFilter.mode(
                        Color(0xFF4A4A4A),
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                  if (isLoggedIn) ...[
                    SizedBox(width: 14 * scale),
                    GestureDetector(
                      onTap: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            title: Text('Log Out?', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                            content: Text('Are you sure you want to sign out of your account?', style: GoogleFonts.outfit()),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: Text('Cancel', style: GoogleFonts.outfit(color: const Color(0xFF64748B))),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE11D48)),
                                onPressed: () => Navigator.pop(ctx, true),
                                child: Text('Log Out', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await CubePod.get<AuthRepository>().logout();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Logged out successfully!'),
                                backgroundColor: Color(0xFF185B3A),
                              ),
                            );
                          }
                        }
                      },
                      child: Container(
                        padding: EdgeInsets.all(5 * scale),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF1F2),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFFECDD3)),
                        ),
                        child: Icon(
                          Icons.logout_rounded,
                          size: 16 * scale,
                          color: const Color(0xFFE11D48),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Profile Info
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16 * scale),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 28 * scale, // Reduced from 32
                        backgroundColor: const Color(0xFFE8F5E9),
                        backgroundImage:
                            isLoggedIn &&
                                currentUser!['avatar_url'] != null &&
                                currentUser['avatar_url'].toString().isNotEmpty
                            ? NetworkImage(currentUser['avatar_url'])
                            : null,
                        child:
                            (!isLoggedIn ||
                                currentUser!['avatar_url'] == null ||
                                currentUser['avatar_url'].toString().isEmpty)
                            ? Icon(
                                Icons.person,
                                size: 30 * scale,
                                color: Color(0xFF3BA772),
                              ) // Reduced from 36
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: EdgeInsets.all(4 * scale),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF1B3D2F,
                            ), // Dark green background
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white,
                              width: 2 * scale,
                            ),
                          ),
                          child: Icon(
                            Icons.camera_alt,
                            size: 10 * scale,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(width: 12 * scale),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userName,
                          style: TextStyle(
                            fontSize: 16 * scale,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1B3D2F),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 2 * scale),
                        Text(
                          userEmail,
                          style: TextStyle(
                            fontSize: 11 * scale,
                            color: Colors.grey.shade600,
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 8 * scale),
                  if (!isLoggedIn)
                    BounceButton(
                      onTap: () {
                        Navigator.push(
                          context,
                          CupertinoPageRoute(
                            builder: (context) => const AuthPage(),
                          ),
                        );
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16 * scale,
                          vertical: 10 * scale,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3BA772),
                          borderRadius: BorderRadius.circular(20 * scale),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Login / Register',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14 * scale,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    )
                  else
                    const SizedBox.shrink(),
                ],
              ),
            ),
            SizedBox(height: 20 * scale),
          ],
        ),
      ),
    );
  }

  Widget _buildJoinDovanBanner(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF4FBF4),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Join Dovan & enjoy',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildBannerFeature(
                      Icons.local_shipping,
                      'Track Orders',
                      'In real-time',
                    ),
                    _buildBannerFeature(
                      Icons.local_offer,
                      'Exclusive Offers',
                      'For members',
                    ),
                    _buildBannerFeature(
                      Icons.workspace_premium,
                      'Reward Points',
                      'On every order',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBannerFeature(IconData icon, String title, String subtitle) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF3BA772), size: 18),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1B3D2F),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 10, color: Colors.grey),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  String _formatLastUpdated(dynamic rawDate) {
    if (rawDate == null) return 'Just now';
    try {
      final date = DateTime.parse(rawDate.toString()).toLocal();
      final now = DateTime.now();
      final diff = now.difference(date);
      if (diff.inSeconds < 60) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays == 1) return 'Yesterday';
      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return 'Just now';
    }
  }

  Widget _buildUserStatsBanner(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _fetchUserStats(),
      builder: (context, snapshot) {
        final stats =
            snapshot.data ?? {'points': 0, 'totalOrders': 0, 'globalRank': '-', 'tier': 'Bronze'};
        final points = stats['points']?.toString() ?? '0';
        final orders = stats['totalOrders']?.toString() ?? '0';
        final rawRank = stats['globalRank'];
        final rank = (rawRank == null || rawRank.toString().isEmpty) 
            ? '-' 
            : rawRank.toString().replaceAll('#', '');
        final tier = stats['tier']?.toString() ?? 'Bronze';
        final lastUpdated = _formatLastUpdated(stats['pointsLastUpdatedAt']);

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2E8B57).withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
            border: Border.all(color: const Color(0xFFF4FBF4), width: 2),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF9E6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.emoji_events,
                          color: Color(0xFFE6C117),
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Dovan Leaderboard',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF4D6),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          tier,
                          style: GoogleFonts.outfit(
                            color: const Color(0xFFB8860B),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        CupertinoPageRoute(
                          builder: (context) => const LeaderboardPage(),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4FBF4),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Text(
                            'View All',
                            style: GoogleFonts.outfit(
                              color: const Color(0xFF3BA772),
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Icon(
                            Icons.arrow_forward_ios,
                            color: Color(0xFF3BA772),
                            size: 10,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildStatFeature(
                    Icons.shopping_bag_outlined,
                    orders,
                    'Orders',
                  ),
                  _buildStatFeature(
                    Icons.emoji_events_outlined,
                    '#$rank',
                    'Global Rank',
                    isHighlight: true,
                  ),
                  _buildStatFeature(Icons.stars_outlined, points, 'Points'),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAF8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.access_time_rounded,
                      size: 12,
                      color: Color(0xFF7A8B7B),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Points updated: $lastUpdated',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        color: const Color(0xFF6B7E6C),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatFeature(
    IconData icon,
    String value,
    String subtitle, {
    bool isHighlight = false,
  }) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(isHighlight ? 10 : 8),
            decoration: BoxDecoration(
              color: isHighlight
                  ? const Color(0xFFFFF9E6)
                  : const Color(0xFFF4FBF4),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: isHighlight
                  ? const Color(0xFFE6C117)
                  : const Color(0xFF3BA772),
              size: isHighlight ? 20 : 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: isHighlight ? 18 : 15,
              fontWeight: FontWeight.w800,
              color: isHighlight
                  ? const Color(0xFFB39200)
                  : const Color(0xFF1B3D2F),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    String title,
    String actionText,
    VoidCallback onAction,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Colors.black87,
          ),
        ),
        GestureDetector(
          onTap: onAction,
          child: Row(
            children: [
              Text(
                actionText,
                style: const TextStyle(
                  color: Color(0xFF3BA772),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: Color(0xFF3BA772),
                size: 16,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsGroup(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSettingItem(
    BuildContext context, {
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool showDivider = true,
  }) {
    return BounceButton(
      onTap: onTap,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13.5,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: Colors.grey.shade400,
                  size: 20,
                ),
              ],
            ),
          ),
          if (showDivider)
            Padding(
              padding: const EdgeInsets.only(left: 50, right: 12),
              child: Divider(height: 1, color: Colors.grey.shade100),
            ),
        ],
      ),
    );
  }

  Widget _buildPrivacyBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF4FBF4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.eco, color: Color(0xFF3BA772), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'We care about your privacy',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Your data is safe and secure with us.',
                  style: TextStyle(color: Colors.grey, fontSize: 11),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFF3BA772)),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Learn More',
              style: TextStyle(
                color: Color(0xFF3BA772),
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
