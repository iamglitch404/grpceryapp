import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:app/core/config/appConfig.dart';
import 'package:app/core/network/httpClient.dart' as http;
import 'package:app/core/widgets/topBar.dart';
import 'package:app/core/di/injection.dart';
import 'package:app/features/admin/users/screens/editAccountPage.dart';
import 'package:app/features/admin/products/screens/categoriesPage.dart';
import 'package:app/features/admin/orders/screens/ordersPage.dart';
import 'package:app/features/admin/users/screens/usersPage.dart';
import 'package:app/features/admin/dashboard/screens/leaderboardPage.dart';
import 'package:app/features/admin/tickets/screens/ticketsPage.dart';
import 'package:app/features/admin/promotions/screens/promotionsPage.dart';
import 'package:app/features/admin/products/screens/productReviewPage.dart';
import 'package:app/features/admin/dashboard/providers/dashboardProviders.dart';
import 'package:app/features/admin/dashboard/widgets/adminDashboardPendingOrdersSkeleton.dart';
import 'package:app/features/admin/dashboard/widgets/adminDashboardSvgActionCard.dart';
import 'package:app/features/admin/dashboard/widgets/adminDashboardSvgConstants.dart';
import 'package:app/features/admin/dashboard/widgets/adminDashboardMiniStatCard.dart';
import 'package:app/features/admin/dashboard/widgets/adminDashboardLeaderboard.dart';
import 'package:app/features/admin/dashboard/widgets/pendingOrderCard.dart';
import 'package:app/core/services/cacheService.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> with SingleTickerProviderStateMixin {
  late final AnimationController _skeletonController;
  late final Animation<Color?> _skeletonAnimation;

  bool get _isLoading => ref.read(adminDashboardProvider).isLoading;
  List<dynamic> get _users => ref.read(adminDashboardProvider).users;
  List<dynamic> get _categories => ref.read(adminDashboardProvider).categories;
  List<dynamic> get _subcategories => ref.read(adminDashboardProvider).subcategories;
  List<dynamic> get _orders => ref.read(adminDashboardProvider).orders;
  List<dynamic> get _tickets => ref.read(adminDashboardProvider).tickets;
  List<dynamic> get _promotions => ref.read(adminDashboardProvider).promotions;
  List<dynamic> get _approvals => ref.read(adminDashboardProvider).approvals;

  String _getUserRole(dynamic u) {
    final r = (u['role'] ?? 'customer').toString().toLowerCase();
    if (r == 'delivery_man' || r.contains('delivery')) return 'delivery_man';
    if (r == 'admin') return 'admin';
    return 'customer';
  }

  int get _allUsersCount => _users.length;
  int get _customersCount => _users.where((u) => _getUserRole(u) == 'customer').length;
  int get _deliverymanCount => _users.where((u) => _getUserRole(u) == 'delivery_man').length;

  List<dynamic> get _pendingOrders {
    return _orders.where((o) {
      final status = (o['status'] ?? '').toString().toLowerCase();
      return status == 'pending';
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _skeletonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _skeletonAnimation = ColorTween(
      begin: const Color(0xFFF1F5F9),
      end: const Color(0xFFE2E8F0),
    ).animate(_skeletonController);

    Future.microtask(() => _fetchAllData());
  }

  @override
  void dispose() {
    _skeletonController.dispose();
    super.dispose();
  }

  Future<void> _fetchAllData() async {
    if (!mounted) return;
    final notifier = ref.read(adminDashboardProvider.notifier);
    final cachedCats = CacheService.get<List>('categories');
    if (cachedCats != null && cachedCats.isNotEmpty && _categories.isEmpty) {
      notifier.setCategories(cachedCats);
    }
    notifier.setLoading(_categories.isEmpty);
    final headers = ref.read(authRepositoryProvider).authHeaders;

    try {
      final results = await Future.wait([
        http.get(Uri.parse('${AppConfig.apiUrl}/admin/users'), headers: headers).catchError((_) => http.Response('[]', 500)),
        http.get(Uri.parse('${AppConfig.apiUrl}/admin/categories'), headers: headers).catchError((_) => http.Response('[]', 500)),
        http.get(Uri.parse('${AppConfig.apiUrl}/admin/subcategories'), headers: headers).catchError((_) => http.Response('[]', 500)),
        http.get(Uri.parse('${AppConfig.apiUrl}/admin/orders'), headers: headers).catchError((_) => http.Response('[]', 500)),
        http.get(Uri.parse('${AppConfig.apiUrl}/tickets'), headers: headers).catchError((_) => http.Response('[]', 500)),
        http.get(Uri.parse('${AppConfig.apiUrl}/promotions'), headers: headers).catchError((_) => http.Response('[]', 500)),
        http.get(Uri.parse('${AppConfig.apiUrl}/admin/product-approvals'), headers: headers).catchError((_) => http.Response('[]', 500)),
      ]);

      if (!mounted) return;

      List<dynamic> parsedUsers = [];
      if (results[0].statusCode == 200) {
        final data = jsonDecode(results[0].body);
        if (data is List) {
          parsedUsers = data;
        } else if (data is Map) {
          parsedUsers = data['data'] is List ? data['data'] : (data['users'] is List ? data['users'] : []);
        }
      }

      List<dynamic> parsedCategories = [];
      if (results[1].statusCode == 200) {
        final data = jsonDecode(results[1].body);
        parsedCategories = data is List ? data : (data['data'] is List ? data['data'] : []);
        if (parsedCategories.isNotEmpty) {
          CacheService.set('categories', parsedCategories);
        }
      }

      List<dynamic> parsedSubcategories = [];
      if (results[2].statusCode == 200) {
        final data = jsonDecode(results[2].body);
        parsedSubcategories = data is List ? data : (data['data'] is List ? data['data'] : []);
      }

      List<dynamic> parsedOrders = [];
      if (results[3].statusCode == 200) {
        final data = jsonDecode(results[3].body);
        if (data is Map && data['orders'] is List) {
          parsedOrders = data['orders'];
        } else if (data is List) {
          parsedOrders = data;
        } else if (data is Map && data['data'] is List) {
          parsedOrders = data['data'];
        }
      }

      List<dynamic> parsedTickets = [];
      if (results.length > 4 && results[4].statusCode == 200) {
        final data = jsonDecode(results[4].body);
        parsedTickets = data['tickets'] is List ? data['tickets'] : (data is List ? data : []);
      }

      List<dynamic> parsedPromotions = [];
      if (results.length > 5 && results[5].statusCode == 200) {
        final data = jsonDecode(results[5].body);
        parsedPromotions = data['promotions'] is List ? data['promotions'] : (data['data'] is List ? data['data'] : (data is List ? data : []));
      }

      List<dynamic> parsedApprovals = [];
      if (results.length > 6 && results[6].statusCode == 200) {
        final data = jsonDecode(results[6].body);
        parsedApprovals = data['submissions'] is List
            ? data['submissions']
            : (data['products'] is List
                ? data['products']
                : (data['data'] is List ? data['data'] : (data is List ? data : [])));
      }

      notifier.setAllData(
        users: parsedUsers,
        categories: parsedCategories,
        subcategories: parsedSubcategories,
        orders: parsedOrders,
        tickets: parsedTickets,
        promotions: parsedPromotions,
        approvals: parsedApprovals,
        isLoading: false,
      );
    } catch (e) {
      if (mounted) notifier.setLoading(false);
      debugPrint('Error fetching dashboard data: $e');
    }
  }

  Future<void> _updateOrderStatus(dynamic orderId, String newStatus) async {
    HapticFeedback.mediumImpact();
    try {
      final res = await http.put(
        Uri.parse('${AppConfig.apiUrl}/admin/orders'),
        headers: {
          ...ref.read(authRepositoryProvider).authHeaders,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'id': orderId,
          'status': newStatus,
        }),
      );

      if (res.statusCode == 200 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order #$orderId marked as $newStatus'),
            backgroundColor: const Color(0xFF185B3A),
            behavior: SnackBarBehavior.floating,
          ),
        );
        _fetchAllData();
      }
    } catch (e) {
      debugPrint('Error updating order: $e');
    }
  }

  void _showAdminProfileSheet() {
    final user = ref.read(authRepositoryProvider).currentUser ?? {};
    final name = (user['name'] ?? user['username'] ?? 'Dovan Administrator').toString();
    final email = (user['email'] ?? 'admin@dovan.com').toString();
    final avatar = user['profile_image'] ?? user['avatar_url'];
    final hasAvatar = avatar != null && avatar.toString().isNotEmpty;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF185B3A).withValues(alpha: 0.1),
                border: Border.all(color: const Color(0xFF185B3A), width: 1.5),
              ),
              child: ClipOval(
                child: hasAvatar
                    ? Image.network(
                        avatar.toString(),
                        width: 68,
                        height: 68,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const Icon(
                          Icons.admin_panel_settings_rounded,
                          size: 36,
                          color: Color(0xFF185B3A),
                        ),
                      )
                    : const Icon(
                        Icons.admin_panel_settings_rounded,
                        size: 36,
                        color: Color(0xFF185B3A),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              name,
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              email,
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Administrator Role',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF185B3A),
                ),
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EditAccountPage(
                      user: user,
                      initialName: name,
                      initialGender: user['gender'],
                      role: user['role'] ?? 'admin',
                      status: user['status'] ?? 'active',
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: Text('Edit Account Details', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13.5)),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF0F172A),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
                minimumSize: const Size(double.infinity, 44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await ref.read(authRepositoryProvider).logout();
                },
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: Text('Log Out Admin', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE11D48),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(adminDashboardProvider);
    final pendingOrdersList = _pendingOrders;
    final customerRankings = computeCustomerLeaderboard(_users, _orders);
    final deliverymanRankings = computeDeliverymanLeaderboard(_users, _orders);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(56.0),
          child: Container(
            color: const Color(0xFFF9F9F9),
            child: SafeArea(
              bottom: false,
              child: TopBar(
                customActions: [
                  IconButton(
                    icon: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        SvgPicture.string(
                          ticketSvg,
                          width: 22,
                          height: 22,
                        ),
                        if (_tickets.any((t) => (t['status'] ?? '').toString().toLowerCase() == 'open'))
                          Positioned(
                            top: -2,
                            right: -2,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFFE53935),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                    tooltip: 'Support Tickets & Alerts',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const TicketsPage(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 4),
                  Builder(
                    builder: (context) {
                      final user = ref.read(authRepositoryProvider).currentUser;
                      final avatar = user?['profile_image'] ?? user?['avatar_url'];
                      final hasAvatar = avatar != null && avatar.toString().isNotEmpty;

                      return GestureDetector(
                        onTap: _showAdminProfileSheet,
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF185B3A).withValues(alpha: 0.2),
                              width: 1.2,
                            ),
                          ),
                          child: ClipOval(
                            child: hasAvatar
                                ? Image.network(
                                    avatar.toString(),
                                    width: 34,
                                    height: 34,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => const Center(
                                      child: Icon(
                                        Icons.person_outline_rounded,
                                        color: Color(0xFF0F172A),
                                        size: 18,
                                      ),
                                    ),
                                  )
                                : const Center(
                                    child: Icon(
                                      Icons.person_outline_rounded,
                                      color: Color(0xFF0F172A),
                                      size: 18,
                                    ),
                                  ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        body: RefreshIndicator(
          color: const Color(0xFF185B3A),
          onRefresh: _fetchAllData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Store Overview',
                          style: GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0F172A),
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Leaderboards, delivery records & live dispatch',
                          style: GoogleFonts.outfit(
                            fontSize: 12.5,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ── ROW 1 (UPPER): Users, Customers, Deliveryman ─────────────
                Row(
                  children: [
                    Expanded(
                      child: AdminDashboardMiniStatCard(
                        title: 'Users',
                        count: _allUsersCount,
                        subtitle: 'All accounts',
                        icon: Icons.groups_rounded,
                        accentColor: const Color(0xFF4F46E5),
                        bgColor: const Color(0xFFEEF2FF),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const UsersPage(initialFilter: 'All'),
                            ),
                          ).then((_) => _fetchAllData());
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AdminDashboardMiniStatCard(
                        title: 'Customers',
                        count: _customersCount,
                        subtitle: 'Shoppers',
                        icon: Icons.shopping_bag_rounded,
                        accentColor: const Color(0xFF185B3A),
                        bgColor: const Color(0xFFECFDF5),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const UsersPage(initialFilter: 'Customers'),
                            ),
                          ).then((_) => _fetchAllData());
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AdminDashboardMiniStatCard(
                        title: 'Deliveryman',
                        count: _deliverymanCount,
                        subtitle: 'Fleet & drivers',
                        icon: Icons.two_wheeler_rounded,
                        accentColor: const Color(0xFFD97706),
                        bgColor: const Color(0xFFFFFBEB),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const UsersPage(initialFilter: 'Deliveryman'),
                            ),
                          ).then((_) => _fetchAllData());
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // ── LEADERBOARD & RECORDS ──
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => LeaderboardPage(
                          customerRankings: customerRankings,
                          deliverymanRankings: deliverymanRankings,
                          onRefresh: _fetchAllData,
                        ),
                      ),
                    ).then((_) => _fetchAllData());
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.emoji_events_rounded,
                            color: Color(0xFFD97706),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Leaderboard & Records',
                                style: GoogleFonts.outfit(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Customer points & delivery fleet records',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.outfit(
                                  fontSize: 11.5,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'View',
                                style: GoogleFonts.outfit(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(width: 3),
                              const Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 10,
                                color: Color(0xFF64748B),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // ── MANAGEMENT SECTION ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Management',
                      style: GoogleFonts.outfit(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Management Cards Row 1
                Row(
                  children: [
                    Expanded(
                      child: AdminDashboardSvgActionCard(
                        name: 'Tickets',
                        count: _tickets.length,
                        svgXml: ticketSvg,
                        accentColor: const Color(0xFFD97706),
                        bgColor: const Color(0xFFFEF3C7),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const TicketsPage(),
                            ),
                          ).then((_) => _fetchAllData());
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: AdminDashboardSvgActionCard(
                        name: 'Categories',
                        count: _categories.length,
                        svgXml: categorySvg,
                        accentColor: const Color(0xFF16A34A),
                        bgColor: const Color(0xFFDCFCE7),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const CategoriesPage(),
                            ),
                          ).then((_) => _fetchAllData());
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Management Cards Row 2
                Row(
                  children: [
                    Expanded(
                      child: AdminDashboardSvgActionCard(
                        name: 'Subcategories',
                        count: _subcategories.length,
                        svgXml: subcategorySvg,
                        accentColor: const Color(0xFF7C3AED),
                        bgColor: const Color(0xFFEDE9FE),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const CategoriesPage(),
                            ),
                          ).then((_) => _fetchAllData());
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: AdminDashboardSvgActionCard(
                        name: 'Promotions',
                        count: _promotions.length,
                        svgXml: promoSvg,
                        accentColor: const Color(0xFFEA580C),
                        bgColor: const Color(0xFFFFF7ED),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const PromotionsPage(),
                            ),
                          ).then((_) => _fetchAllData());
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Management Cards Row 3
                Row(
                  children: [
                    Expanded(
                      child: AdminDashboardSvgActionCard(
                        name: 'Approvals',
                        count: _approvals.length,
                        svgXml: approvalSvg,
                        accentColor: const Color(0xFF0284C7),
                        bgColor: const Color(0xFFF0F9FF),
                        isHorizontal: true,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ProductReviewPage(),
                            ),
                          ).then((_) => _fetchAllData());
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),

                // ── PENDING ORDERS SECTION ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Pending Orders',
                          style: GoogleFonts.outfit(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: pendingOrdersList.isNotEmpty ? const Color(0xFFFEF3C7) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: pendingOrdersList.isNotEmpty ? const Color(0xFFFDE68A) : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Text(
                            '${pendingOrdersList.length}',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: pendingOrdersList.isNotEmpty ? const Color(0xFFB45309) : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const OrdersPage(),
                          ),
                        ).then((_) => _fetchAllData());
                      },
                      child: Text(
                        'View All Orders →',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF185B3A),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Pending Orders List / Skeleton / Empty State
                if (_isLoading)
                  AdminDashboardPendingOrdersSkeleton(
                    skeletonAnimation: _skeletonAnimation,
                  )
                else if (pendingOrdersList.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_circle_outline_rounded,
                            size: 32,
                            color: Color(0xFF16A34A),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No Pending Orders',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'All customer orders are packed, dispatched, or completed!',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            fontSize: 12.5,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: pendingOrdersList.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final order = pendingOrdersList[index] as Map<String, dynamic>;
                      return AdminPendingOrderCard(
                        order: order,
                        onUpdateStatus: _updateOrderStatus,
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Retain alias for backward compatibility
typedef AdminDashboardPage = DashboardPage;
