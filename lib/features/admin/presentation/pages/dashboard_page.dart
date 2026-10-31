import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:app/core/config/app_config.dart';
import 'package:app/core/network/http_client.dart' as http;
import 'package:app/core/widgets/top_bar.dart';
import 'package:app/features/auth/data/repositories/auth_repository.dart';
import 'package:cubepod_core/cubepod_core.dart';
import 'package:app/features/admin/presentation/pages/edit_account_page.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:app/features/admin/presentation/pages/categories_page.dart';
import 'package:app/features/admin/presentation/pages/orders_page.dart';
import 'package:app/features/admin/presentation/pages/users_page.dart';
import 'package:app/features/admin/presentation/pages/leaderboard_page.dart';
import 'package:app/features/admin/presentation/pages/tickets_page.dart';
import 'package:app/features/admin/presentation/pages/promotions_page.dart';
import 'package:app/features/admin/presentation/pages/product_review_page.dart';
import 'package:app/core/services/cache_service.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> with SingleTickerProviderStateMixin {
  late final AnimationController _skeletonController;
  late final Animation<Color?> _skeletonAnimation;
  static const String _ticketSvg = '''<svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
<path d="M4 8.5C5.38 8.5 6.5 7.38 6.5 6V5C6.5 4.45 6.95 4 7.5 4H16.5C17.05 4 17.5 4.45 17.5 5V6C17.5 7.38 18.62 8.5 20 8.5C20.55 8.5 21 8.95 21 9.5V14.5C21 15.05 20.55 15.5 20 15.5C18.62 15.5 17.5 16.62 17.5 18V19C17.5 19.55 17.05 20 16.5 20H7.5C6.95 20 6.5 19.55 6.5 19V18C6.5 16.62 5.38 15.5 4 15.5C3.45 15.5 3 15.05 3 14.5V9.5C3 8.95 3.45 8.5 4 8.5Z" stroke="#D97706" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/>
<path d="M9.5 9.5H14.5M9.5 12H14.5M9.5 14.5H12" stroke="#D97706" stroke-width="1.8" stroke-linecap="round"/>
</svg>''';

  static const String _categorySvg = '''<svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
<rect x="3" y="3" width="7.5" height="7.5" rx="2" stroke="#16A34A" stroke-width="1.8"/>
<rect x="13.5" y="3" width="7.5" height="7.5" rx="2" stroke="#16A34A" stroke-width="1.8"/>
<rect x="3" y="13.5" width="7.5" height="7.5" rx="2" stroke="#16A34A" stroke-width="1.8"/>
<rect x="13.5" y="13.5" width="7.5" height="7.5" rx="2" stroke="#16A34A" stroke-width="1.8"/>
</svg>''';

  static const String _subcategorySvg = '''<svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
<rect x="3" y="3" width="6" height="6" rx="2" stroke="#7C3AED" stroke-width="1.8"/>
<rect x="15" y="3" width="6" height="6" rx="2" stroke="#7C3AED" stroke-width="1.8"/>
<rect x="15" y="15" width="6" height="6" rx="2" stroke="#7C3AED" stroke-width="1.8"/>
<path d="M6 9V18H15" stroke="#7C3AED" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/>
<path d="M9 6H15" stroke="#7C3AED" stroke-width="1.8" stroke-linecap="round"/>
</svg>''';

  static const String _promoSvg = '''<svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
<path d="M19.5 12.57L12.57 19.5A2.5 2.5 0 019.04 19.5L3.5 13.96V4.5H12.96L19.5 11.04A2.5 2.5 0 0119.5 12.57Z" stroke="#EA580C" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/>
<circle cx="8" cy="8.5" r="1.5" fill="#EA580C"/>
</svg>''';

  static const String _approvalSvg = '''<svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
<path d="M12 3L4 6.5V11.5C4 16.5 7.5 20.5 12 21.5C16.5 20.5 20 16.5 20 11.5V6.5L12 3Z" stroke="#0284C7" stroke-width="1.8" stroke-linejoin="round"/>
<path d="M9 12L11 14L15 10" stroke="#0284C7" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/>
</svg>''';

  bool _isLoading = true;
  List<dynamic> _users = [];
  List<dynamic> _categories = [];
  List<dynamic> _subcategories = [];
  List<dynamic> _orders = [];
  List<dynamic> _tickets = [];
  List<dynamic> _promotions = [];
  List<dynamic> _approvals = [];

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

    _fetchAllData();
  }

  @override
  void dispose() {
    _skeletonController.dispose();
    super.dispose();
  }

  Future<void> _fetchAllData() async {
    final cachedCats = CacheService.get<List>('categories');
    if (cachedCats != null && cachedCats.isNotEmpty && _categories.isEmpty) {
      _categories = cachedCats;
    }
    setState(() => _isLoading = _categories.isEmpty);
    final headers = CubePod.get<AuthRepository>().authHeaders;

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
        parsedApprovals = data['products'] is List ? data['products'] : (data['data'] is List ? data['data'] : (data is List ? data : []));
      }

      setState(() {
        _users = parsedUsers;
        _categories = parsedCategories;
        _subcategories = parsedSubcategories;
        _orders = parsedOrders;
        _tickets = parsedTickets;
        _promotions = parsedPromotions;
        _approvals = parsedApprovals;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      debugPrint('Error fetching dashboard data: $e');
    }
  }

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

  // ── Customer Leaderboard Calculation ─────────────────────────────────────────
  List<Map<String, dynamic>> get _customerLeaderboard {
    final customers = _users.where((u) => _getUserRole(u) == 'customer').toList();
    List<Map<String, dynamic>> list = [];

    for (final c in customers) {
      final uid = c['id'];
      final userOrders = _orders.where((o) => (o['user_id'] ?? o['userId']) == uid).toList();
      final orderCount = userOrders.length;
      int totalSpent = 0;
      for (final o in userOrders) {
        final total = o['total_amount'] ?? (o['total_paise'] != null ? (o['total_paise'] as num) / 100 : 0);
        totalSpent += (num.tryParse(total.toString()) ?? 0).toInt();
      }
      final points = (c['points_balance'] as num?)?.toInt() ?? 0;

      list.add({
        'user': c,
        'name': (c['name'] ?? c['username'] ?? 'Customer').toString(),
        'email': (c['email'] ?? '').toString(),
        'avatar': c['avatar_url'] ?? c['profile_image'],
        'order_count': orderCount,
        'total_spent': totalSpent,
        'points': points,
      });
    }

    list.sort((a, b) {
      final ptsComp = (b['points'] as int).compareTo(a['points'] as int);
      if (ptsComp != 0) return ptsComp;
      return (b['order_count'] as int).compareTo(a['order_count'] as int);
    });

    return list.take(8).toList();
  }

  // ── Deliveryman Leaderboard & Records Calculation ───────────────────────────
  List<Map<String, dynamic>> get _deliverymanLeaderboard {
    final drivers = _users.where((u) => _getUserRole(u) == 'delivery_man').toList();
    List<Map<String, dynamic>> list = [];

    final deliveredOrders = _orders.where((o) {
      final s = (o['status'] ?? '').toString().toLowerCase();
      return s == 'delivered';
    }).toList();

    final activeOrders = _orders.where((o) {
      final s = (o['status'] ?? '').toString().toLowerCase();
      return s == 'on the way' || s == 'packed';
    }).toList();

    for (final d in drivers) {
      final uid = d['id'];
      final driverDelivered = deliveredOrders.where((o) => o['delivery_man_id'] == uid).length;
      final driverActive = activeOrders.where((o) => o['delivery_man_id'] == uid).length;

      // If orders aren't assigned explicitly, display aggregate store deliveries
      final completedCount = driverDelivered > 0 ? driverDelivered : deliveredOrders.length;
      final activeCount = driverActive > 0 ? driverActive : activeOrders.length;
      final points = (d['points_balance'] as num?)?.toInt() ?? (completedCount * 10);

      list.add({
        'user': d,
        'name': (d['name'] ?? d['username'] ?? 'Delivery Partner').toString(),
        'email': (d['email'] ?? '').toString(),
        'phone': (d['phone'] ?? d['phone_number'] ?? '').toString(),
        'avatar': d['avatar_url'] ?? d['profile_image'],
        'completed_deliveries': completedCount,
        'active_deliveries': activeCount,
        'points': points,
        'status': (d['status'] ?? 'active').toString(),
      });
    }

    list.sort((a, b) => (b['completed_deliveries'] as int).compareTo(a['completed_deliveries'] as int));
    return list;
  }

  Future<void> _updateOrderStatus(dynamic orderId, String newStatus) async {
    HapticFeedback.mediumImpact();
    try {
      final res = await http.put(
        Uri.parse('${AppConfig.apiUrl}/admin/orders'),
        headers: {
          ...CubePod.get<AuthRepository>().authHeaders,
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

  @override
  Widget build(BuildContext context) {
    final pendingOrdersList = _pendingOrders;
    final customerRankings = _customerLeaderboard;
    final deliverymanRankings = _deliverymanLeaderboard;

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
                          '''<svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
<path d="M4 8.5C5.38 8.5 6.5 7.38 6.5 6V5C6.5 4.45 6.95 4 7.5 4H16.5C17.05 4 17.5 4.45 17.5 5V6C17.5 7.38 18.62 8.5 20 8.5C20.55 8.5 21 8.95 21 9.5V14.5C21 15.05 20.55 15.5 20 15.5C18.62 15.5 17.5 16.62 17.5 18V19C17.5 19.55 17.05 20 16.5 20H7.5C6.95 20 6.5 19.55 6.5 19V18C6.5 16.62 5.38 15.5 4 15.5C3.45 15.5 3 15.05 3 14.5V9.5C3 8.95 3.45 8.5 4 8.5Z" stroke="#0F172A" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/>
<path d="M9.5 9.5H14.5M9.5 12H14.5M9.5 14.5H12" stroke="#0F172A" stroke-width="1.8" stroke-linecap="round"/>
</svg>''',
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
                      final user = CubePod.get<AuthRepository>().currentUser;
                      final avatar = user?['profile_image'] ?? user?['avatar_url'];
                      final hasAvatar = avatar != null && avatar.toString().isNotEmpty;

                      return GestureDetector(
                        onTap: () {
                          final currentUser = user ?? {};
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => EditAccountPage(
                                user: currentUser,
                                initialName: currentUser['name'] ?? 'Admin',
                                initialGender: currentUser['gender'],
                                role: currentUser['role'] ?? 'admin',
                                status: currentUser['status'] ?? 'active',
                              ),
                            ),
                          );
                        },
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
                      child: _buildMiniStatCard(
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
                      child: _buildMiniStatCard(
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
                      child: _buildMiniStatCard(
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

                // ── LEADERBOARD & RECORDS (Rectangular Button Redirecting to Dedicated Page) ──
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

                // ── MANAGEMENT SECTION ─────────────────────────────────────────
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

                // Management Cards with SVGs and Single Names
                Row(
                  children: [
                    Expanded(
                      child: _buildSvgActionCard(
                        name: 'Tickets',
                        count: _tickets.length,
                        svgXml: _ticketSvg,
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
                      child: _buildSvgActionCard(
                        name: 'Categories',
                        count: _categories.length,
                        svgXml: _categorySvg,
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

                Row(
                  children: [
                    Expanded(
                      child: _buildSvgActionCard(
                        name: 'Subcategories',
                        count: _subcategories.length,
                        svgXml: _subcategorySvg,
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
                      child: _buildSvgActionCard(
                        name: 'Promotions',
                        count: _promotions.length,
                        svgXml: _promoSvg,
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

                Row(
                  children: [
                    Expanded(
                      child: _buildSvgActionCard(
                        name: 'Approvals',
                        count: _approvals.length,
                        svgXml: _approvalSvg,
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

                // ── PENDING ORDERS SECTION ─────────────────────────────────────
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
                  _buildPendingOrdersSkeleton()
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
                      return _buildPendingOrderCard(order);
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniStatCard({
    required String title,
    required int count,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
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
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: bgColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 16, color: accentColor),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: Color(0xFFCBD5E1),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '$count',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
                height: 1.1,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF334155),
              ),
            ),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                fontSize: 10,
                color: const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSvgActionCard({
    required String name,
    required int count,
    required String svgXml,
    required Color accentColor,
    required Color bgColor,
    required VoidCallback onTap,
    bool isHorizontal = false,
  }) {
    if (isHorizontal) {
      return GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: bgColor,
                      shape: BoxShape.circle,
                    ),
                    child: SvgPicture.string(svgXml, width: 20, height: 20),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    name,
                    style: GoogleFonts.outfit(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$count',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: accentColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 13,
                    color: Color(0xFF94A3B8),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: bgColor,
                    shape: BoxShape.circle,
                  ),
                  child: SvgPicture.string(
                    svgXml,
                    width: 20,
                    height: 20,
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 13,
                  color: Color(0xFF94A3B8),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '$count',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
                height: 1.1,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              name,
              style: GoogleFonts.outfit(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1E293B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingOrdersSkeleton() {
    return AnimatedBuilder(
      animation: _skeletonAnimation,
      builder: (context, _) {
        final shimmer = _skeletonAnimation.value ?? const Color(0xFFF1F5F9);
        return Column(
          children: List.generate(
            2,
            (index) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 6,
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
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: shimmer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 110,
                            height: 14,
                            decoration: BoxDecoration(
                              color: shimmer,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                      Container(
                        width: 64,
                        height: 20,
                        decoration: BoxDecoration(
                          color: shimmer,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 140,
                            height: 13,
                            decoration: BoxDecoration(
                              color: shimmer,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            width: 90,
                            height: 11,
                            decoration: BoxDecoration(
                              color: shimmer,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                      Container(
                        width: 75,
                        height: 24,
                        decoration: BoxDecoration(
                          color: shimmer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPendingOrderCard(Map<String, dynamic> order) {
    final id = (order['id'] ?? '').toString();
    final shortId = id.length > 8 ? id.substring(0, 8).toUpperCase() : id;
    final customerName = (order['customer_name'] ?? order['customer']?['name'] ?? 'Customer').toString();
    final phone = (order['customer_phone'] ?? order['phone'] ?? '').toString();
    final total = order['total_amount'] ?? order['total'] ?? '0';
    final paymentMethod = (order['payment_method'] ?? 'COD').toString();

    List<dynamic> items = [];
    if (order['order_items'] is List) {
      items = order['order_items'];
    } else if (order['items'] is List) {
      items = order['items'];
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDE68A)), // Amber accent border
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Order ID & Pending Badge
          Row(
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
                    child: const Icon(
                      Icons.schedule_rounded,
                      size: 15,
                      color: Color(0xFFD97706),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Order #$shortId',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'PENDING',
                  style: GoogleFonts.outfit(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFB45309),
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Customer Row
          Row(
            children: [
              const Icon(Icons.person_outline_rounded, size: 14, color: Color(0xFF64748B)),
              const SizedBox(width: 4),
              Text(
                customerName,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF334155),
                ),
              ),
              if (phone.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(
                  '•  $phone',
                  style: GoogleFonts.outfit(
                    fontSize: 11.5,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),

          // Total & Payment
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total: ₹$total',
                style: GoogleFonts.outfit(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF185B3A),
                ),
              ),
              Text(
                paymentMethod,
                style: GoogleFonts.outfit(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          ),

          // Items preview
          if (items.isNotEmpty) ...[
            const Divider(height: 18, color: Color(0xFFF1F5F9)),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: items.take(3).map((item) {
                final itemTitle = item['title'] ?? item['name'] ?? item['product_title'] ?? 'Product';
                final qty = item['quantity'] ?? item['qty'] ?? 1;
                return Text(
                  '$itemTitle × $qty',
                  style: GoogleFonts.outfit(
                    fontSize: 11.5,
                    color: const Color(0xFF475569),
                  ),
                );
              }).toList(),
            ),
          ],

          const SizedBox(height: 12),

          // Action Buttons: Mark Packed & Cancel
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFE11D48),
                  side: const BorderSide(color: Color(0xFFFDA4AF)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () => _updateOrderStatus(id, 'Cancelled'),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                icon: const Icon(Icons.done_all_rounded, size: 14, color: Colors.white),
                label: Text(
                  'Mark Packed',
                  style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  elevation: 0,
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () => _updateOrderStatus(id, 'Packed'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Retain alias for backward compatibility
typedef AdminDashboardPage = DashboardPage;
