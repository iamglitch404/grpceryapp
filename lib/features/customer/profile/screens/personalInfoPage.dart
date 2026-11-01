import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:app/core/di/injection.dart';
import 'package:app/core/network/httpClient.dart' as http;
import 'package:app/core/config/appConfig.dart';
import 'package:app/features/auth/screens/authPage.dart';
import 'package:app/features/customer/orders/screens/orderHistoryPage.dart';
import 'package:app/features/customer/explore/screens/promotionsPage.dart';
import 'package:app/features/customer/profile/screens/referAndEarnPage.dart';
import 'package:app/features/customer/profile/screens/pointsShopPage.dart';
import 'package:app/features/customer/profile/screens/editProfilePage.dart';
import 'package:app/features/customer/profile/screens/wishlistPage.dart';
import 'package:app/features/customer/profile/providers/profileProviders.dart';

class PersonalInfoPage extends ConsumerStatefulWidget {
  const PersonalInfoPage({super.key});

  @override
  ConsumerState<PersonalInfoPage> createState() => _PersonalInfoPageState();
}

class _PersonalInfoPageState extends ConsumerState<PersonalInfoPage> {
  Map<String, dynamic> get _info => ref.watch(personalInfoStateProvider);
  String get _name => _info['name']?.toString() ?? '';
  String get _username => _info['username']?.toString() ?? '';
  String get _email => _info['email']?.toString() ?? '';
  String get _phone => _info['phone']?.toString() ?? '';
  String? get _avatarUrl => _info['profile_image'] ?? _info['avatar_url'];
  String get _gender => _info['gender']?.toString() ?? 'Not selected';

  String get _tier => _info['tier']?.toString() ?? 'Bronze';
  int get _points => (_info['points'] as num?)?.toInt() ?? 0;
  int get _totalOrders => (_info['totalOrders'] as num?)?.toInt() ?? 0;
  int get _wishlistCount => (_info['wishlistCount'] as num?)?.toInt() ?? 0;
  int get _vouchersCount => (_info['vouchersCount'] as num?)?.toInt() ?? 0;
  String get _referralCode => _info['referral_code']?.toString() ?? '';
  String get _createdAt => _info['created_at']?.toString() ?? '';

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      _initFromCurrentUser();
    });
    ref.read(authRepositoryProvider).authStateNotifier.addListener(_onAuthChanged);
  }

  void _onAuthChanged() {
    if (mounted) {
      _initFromCurrentUser();
    }
  }

  void _initFromCurrentUser() {
    final authRepo = ref.read(authRepositoryProvider);
    final user = authRepo.currentUser;
    if (user != null) {
      ref.read(personalInfoStateProvider.notifier).state = {
        'name': user['name']?.toString() ?? user['username']?.toString() ?? 'User',
        'username': user['username']?.toString() ?? '',
        'email': user['email']?.toString() ?? '',
        'phone': user['phone']?.toString() ?? '',
        'avatar_url': user['profile_image'] ?? user['avatar_url'],
        'gender': user['gender']?.toString() ?? 'Not selected',
        'referral_code': user['referral_code']?.toString() ?? '',
        'created_at': user['created_at']?.toString() ?? '',
      };
      _loadProfileData();
    } else {
      ref.read(personalInfoStateProvider.notifier).state = {};
    }
  }

  @override
  void dispose() {
    ref.read(authRepositoryProvider).authStateNotifier.removeListener(_onAuthChanged);
    super.dispose();
  }

  Future<void> _loadProfileData() async {
    final authRepo = ref.read(authRepositoryProvider);
    if (!authRepo.isLoggedIn) return;
    final userRepo = ref.read(userRepositoryProvider);

    try {
      final profile = await userRepo.fetchMyProfile(authRepo.authHeaders);
      final stats = await userRepo.getCachedStats() ?? await userRepo.fetchStats(authRepo.authHeaders);

      // Fetch real counts for wishlist & vouchers
      int wishlistCount = 0;
      int vouchersCount = 0;
      try {
        final favsRes = await http.get(Uri.parse('${AppConfig.apiUrl}/favorites'), headers: authRepo.authHeaders);
        if (favsRes.statusCode == 200) {
          final d = jsonDecode(favsRes.body);
          final list = (d['data']?['favorites'] as List?) ?? (d['favorites'] as List?) ?? [];
          wishlistCount = list.length;
        }
      } catch (_) {}

      try {
        final offersRes = await http.get(Uri.parse('${AppConfig.apiUrl}/promotions/my-offers'), headers: authRepo.authHeaders);
        if (offersRes.statusCode == 200) {
          final d = jsonDecode(offersRes.body);
          final list = (d['data']?['active'] as List?) ?? (d['active'] as List?) ?? [];
          vouchersCount = list.length;
        }
      } catch (_) {}

      if (mounted) {
        final current = Map<String, dynamic>.from(ref.read(personalInfoStateProvider));
        if (profile['name'] != null && profile['name'].toString().isNotEmpty) {
          current['name'] = profile['name'].toString();
        }
        if (profile['username'] != null && profile['username'].toString().isNotEmpty) {
          current['username'] = profile['username'].toString();
        }
        if (profile['email'] != null && profile['email'].toString().isNotEmpty) {
          current['email'] = profile['email'].toString();
        }
        if (profile['phone'] != null) {
          current['phone'] = profile['phone'].toString();
        }
        if (profile['gender'] != null && profile['gender'].toString().isNotEmpty) {
          current['gender'] = profile['gender'].toString();
        }
        if (profile['profile_image'] != null && profile['profile_image'].toString().isNotEmpty) {
          current['profile_image'] = profile['profile_image'].toString();
        }
        if (profile['referral_code'] != null) {
          current['referral_code'] = profile['referral_code'].toString();
        }
        if (profile['created_at'] != null) {
          current['created_at'] = profile['created_at'].toString();
        }

        current['tier'] = stats['tier']?.toString() ?? 'Bronze';
        current['points'] = stats['points'] is int ? stats['points'] : int.tryParse(stats['points']?.toString() ?? '0') ?? 0;
        current['totalOrders'] = stats['totalOrders'] is int ? stats['totalOrders'] : int.tryParse(stats['totalOrders']?.toString() ?? '0') ?? 0;
        current['wishlistCount'] = wishlistCount;
        current['vouchersCount'] = vouchersCount;

        ref.read(personalInfoStateProvider.notifier).state = current;
      }
    } catch (e) {
      debugPrint('[PersonalInfoPage] Error loading profile: $e');
    }
  }

  Future<void> _openEditProfile() async {
    final authRepo = ref.read(authRepositoryProvider);
    if (!authRepo.isLoggedIn) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AuthPage()),
      );
      return;
    }
    final updated = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const EditProfilePage()),
    );
    if (updated == true && mounted) {
      _initFromCurrentUser();
    }
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13.5),
        ),
        backgroundColor: const Color(0xFF185B3A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _formatJoinDate(String dateStr) {
    if (dateStr.isEmpty) return 'Member';
    try {
      final d = DateTime.parse(dateStr);
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return 'Member since ${months[d.month - 1]} ${d.year}';
    } catch (_) {
      return 'Member';
    }
  }

  @override
  Widget build(BuildContext context) {
    final authRepo = ref.read(authRepositoryProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
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
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A), size: 22),
            onPressed: () => Navigator.pop(context),
          ),
          titleSpacing: 0,
          title: Text(
            'Personal Information',
            style: GoogleFonts.outfit(
              color: const Color(0xFF0F172A),
              fontWeight: FontWeight.bold,
              fontSize: 17.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          centerTitle: false,
          actions: [
            ValueListenableBuilder<Map<String, dynamic>?>(
              valueListenable: authRepo.authStateNotifier,
              builder: (context, user, _) {
                if (user == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Center(
                    child: InkWell(
                      onTap: _openEditProfile,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.edit_outlined,
                              size: 15,
                              color: Color(0xFF185B3A),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'Edit',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: const Color(0xFF185B3A),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        body: ValueListenableBuilder<Map<String, dynamic>?>(
          valueListenable: authRepo.authStateNotifier,
          builder: (context, currentUser, _) {
            if (currentUser == null) {
              return _buildGuestState();
            }

            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              padding: EdgeInsets.fromLTRB(20, 10, 20, MediaQuery.paddingOf(context).bottom + 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── 1. Profile Header with Integrated Stats ──
                  _buildProfileHeader(),

                  const SizedBox(height: 12),

                  // ── 2. Basic Details Section ──
                  _buildSectionHeader('Basic Details'),
                  _buildListTile(
                    icon: Icons.person_outline_rounded,
                    label: 'Full Name',
                    value: _name.isNotEmpty ? _name : 'Not set',
                    onTap: _openEditProfile,
                  ),
                  _buildDivider(),
                  _buildListTile(
                    icon: Icons.alternate_email_rounded,
                    label: 'Username',
                    value: _username.isNotEmpty ? '@$_username' : 'Not set',
                    onTap: _openEditProfile,
                  ),
                  _buildDivider(),
                  _buildListTile(
                    icon: Icons.transgender_rounded,
                    label: 'Gender',
                    value: _gender.isNotEmpty ? _gender : 'Not selected',
                    onTap: _openEditProfile,
                  ),
                  if (_referralCode.isNotEmpty) ...[
                    _buildDivider(),
                    _buildListTile(
                      icon: Icons.card_giftcard_rounded,
                      label: 'Referral Code',
                      value: _referralCode,
                      trailingActionText: 'Share',
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: _referralCode));
                        _showToast('Referral code copied to clipboard!');
                      },
                    ),
                  ],

                  // ── 3. Contact & Account Security Section ──
                  _buildSectionHeader('Contact & Account Security'),
                  _buildListTile(
                    icon: Icons.mail_outline_rounded,
                    label: 'Email Address',
                    value: _email.isNotEmpty ? _email : 'Not added',
                    valueColor: _email.isNotEmpty ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                    badge: _email.isNotEmpty
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.check_circle_rounded, color: Color(0xFF15803D), size: 11),
                                const SizedBox(width: 3),
                                Text(
                                  'Verified',
                                  style: GoogleFonts.outfit(
                                    color: const Color(0xFF15803D),
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : null,
                    trailingActionText: _email.isEmpty ? 'Add' : null,
                    onTap: () {
                      if (_email.isNotEmpty) {
                        _showToast('Email address is verified & secured.');
                      } else {
                        _openEditProfile();
                      }
                    },
                  ),
                  _buildDivider(),
                  _buildListTile(
                    icon: Icons.phone_outlined,
                    label: 'Phone Number',
                    value: _phone.isNotEmpty ? _phone : 'Not added',
                    valueColor: _phone.isNotEmpty ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                    trailingActionText: _phone.isEmpty ? 'Add' : null,
                    onTap: _openEditProfile,
                  ),
                  if (_phone.isEmpty) ...[
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: _openEditProfile,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFDCFCE7)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.shield_outlined, color: Color(0xFF16A34A), size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Add your phone number to secure your account',
                                    style: GoogleFonts.outfit(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    'Receive order updates and important alerts',
                                    style: GoogleFonts.outfit(
                                      fontSize: 11,
                                      color: const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded, color: Color(0xFF16A34A), size: 18),
                          ],
                        ),
                      ),
                    ),
                  ],

                  // ── 4. Loyalty & Referrals Section ──
                  _buildSectionHeader('Loyalty & Referrals'),
                  _buildSimpleNavRow(
                    icon: Icons.stars_rounded,
                    title: 'AeroPoints',
                    actionText: '$_points pts',
                    actionColor: const Color(0xFF185B3A),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const PointsShopPage()),
                      );
                    },
                  ),
                  _buildDivider(),
                  _buildSimpleNavRow(
                    icon: Icons.card_giftcard_rounded,
                    title: 'Refer & Earn',
                    subtitle: 'Invite friends and earn rewards',
                    actionText: 'Invite Now',
                    actionColor: const Color(0xFF185B3A),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ReferAndEarnPage()),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildGuestState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Color(0xFFE8F5EE),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lock_person_outlined,
                size: 56,
                color: Color(0xFF185B3A),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Sign In Required',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You are currently signed out. Please log in to view and manage your personal details, membership tier, and security settings.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 13.5,
                color: const Color(0xFF64748B),
                height: 1.45,
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF185B3A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AuthPage()),
                  );
                },
                icon: const Icon(Icons.login_rounded, size: 18),
                label: Text(
                  'Log In / Sign Up',
                  style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Profile Header with Integrated Stat Counters (Flat & Modern) ──
  Widget _buildProfileHeader() {
    final initials = _name.isNotEmpty
        ? _name.substring(0, 1).toUpperCase()
        : (_username.isNotEmpty ? _username.substring(0, 1).toUpperCase() : 'U');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        // Top Identity Row
        Row(
          children: [
            // Avatar
            GestureDetector(
              onTap: _openEditProfile,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFE8F5EE),
                    ),
                    child: ClipOval(
                      child: _avatarUrl != null && _avatarUrl!.isNotEmpty
                          ? Image.network(
                              _avatarUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => _buildAvatarInitial(initials),
                            )
                          : _buildAvatarInitial(initials),
                    ),
                  ),
                  Positioned(
                    bottom: -2,
                    right: -2,
                    child: Container(
                      padding: const EdgeInsets.all(4.5),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.camera_alt_rounded,
                        size: 11,
                        color: Color(0xFF185B3A),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),

            // User Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _name.isNotEmpty ? _name : 'User',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0F172A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (_username.isNotEmpty) ...[
                    const SizedBox(height: 1),
                    Text(
                      '@$_username',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ] else if (_email.isNotEmpty) ...[
                    const SizedBox(height: 1),
                    Text(
                      _email,
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF64748B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.shield_rounded, size: 10, color: Color(0xFFB45309)),
                            const SizedBox(width: 3),
                            Text(
                              '$_tier Member',
                              style: GoogleFonts.outfit(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFFB45309),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_createdAt.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            _formatJoinDate(_createdAt),
                            style: GoogleFonts.outfit(
                              fontSize: 10.5,
                              color: const Color(0xFF94A3B8),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // 4 Stat Counters in a sleek subtle container
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFF1F5F9)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatCounter(
                icon: Icons.shopping_bag_outlined,
                count: '$_totalOrders',
                label: 'Orders',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const OrderHistoryPage()),
                ),
              ),
              _buildVerticalDivider(),
              _buildStatCounter(
                icon: Icons.favorite_border_rounded,
                count: '$_wishlistCount',
                label: 'Wishlist',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const WishlistPage()),
                ),
              ),
              _buildVerticalDivider(),
              _buildStatCounter(
                icon: Icons.stars_rounded,
                count: '$_points',
                label: 'AeroPoints',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PointsShopPage()),
                ),
              ),
              _buildVerticalDivider(),
              _buildStatCounter(
                icon: Icons.local_offer_outlined,
                count: '$_vouchersCount',
                label: 'Vouchers',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PromotionsPage()),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAvatarInitial(String initials) {
    return Center(
      child: Text(
        initials,
        style: GoogleFonts.outfit(
          fontSize: 26,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF185B3A),
        ),
      ),
    );
  }

  Widget _buildStatCounter({
    required IconData icon,
    required String count,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Column(
          children: [
            Icon(icon, size: 16, color: const Color(0xFF64748B)),
            const SizedBox(height: 4),
            Text(
              count,
              style: GoogleFonts.outfit(
                fontSize: 14.5,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F172A),
              ),
            ),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      width: 1,
      height: 28,
      color: const Color(0xFFE2E8F0),
    );
  }

  // ── Section Header ──
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.outfit(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: const Color(0xFF94A3B8),
        ),
      ),
    );
  }

  // ── List Tile Item ──
  Widget _buildListTile({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
    Widget? badge,
    String? trailingActionText,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Icon(icon, size: 16, color: const Color(0xFF475569)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    value,
                    style: GoogleFonts.outfit(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: valueColor ?? const Color(0xFF0F172A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (badge != null) ...[
              badge,
              const SizedBox(width: 8),
            ],
            if (trailingActionText != null) ...[
              Text(
                trailingActionText,
                style: GoogleFonts.outfit(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF185B3A),
                ),
              ),
              const SizedBox(width: 4),
            ],
            const Icon(Icons.chevron_right_rounded, color: Color(0xFFCBD5E1), size: 18),
          ],
        ),
      ),
    );
  }

  // ── Simple Navigation Row ──
  Widget _buildSimpleNavRow({
    required IconData icon,
    required String title,
    String? subtitle,
    required String actionText,
    required Color actionColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Icon(icon, size: 16, color: const Color(0xFF475569)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Row(
              children: [
                Text(
                  actionText,
                  style: GoogleFonts.outfit(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: actionColor,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right_rounded, color: Color(0xFFCBD5E1), size: 18),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return const Divider(height: 1, thickness: 0.8, color: Color(0xFFF1F5F9), indent: 44);
  }
}
