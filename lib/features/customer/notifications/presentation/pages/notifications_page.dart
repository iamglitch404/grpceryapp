import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:app/core/network/http_client.dart' as http;
import 'package:app/core/config/app_config.dart';
import 'package:app/core/services/cache_service.dart';
import 'package:app/features/auth/data/repositories/auth_repository.dart';
import 'package:app/features/customer/submissions/presentation/pages/submissions_page.dart';
import 'package:app/features/customer/orders/presentation/pages/order_history_page.dart';
import 'package:app/features/customer/explore/presentation/pages/promotions_page.dart';
import 'package:app/core/widgets/product_qr_sheet.dart';
import 'package:app/core/widgets/noti_svgs.dart';
import 'package:cubepod_core/cubepod_core.dart';
import 'package:app/features/customer/notifications/presentation/state/notification_state.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  int _selectedFilterIndex = 0;
  final List<String> _filters = ['All', 'Announcements', 'Product Updates', 'Orders', 'Offers & Deals'];
  final List<String> _filterKeys = ['all', 'announcements', 'products', 'orders', 'promos'];

  List<Map<String, dynamic>> _notifications = [];
  int _unreadCount = 0;

  String _cacheKey(String key) => 'notifs_$key';
  String _unreadCacheKey(String key) => 'notifs_unread_$key';

  @override
  void initState() {
    super.initState();
    _loadCachedNotifications();
    _fetchNotifications();
  }

  void _loadCachedNotifications() {
    final key = _filterKeys[_selectedFilterIndex];
    final cached = CacheService.get<List>(_cacheKey(key));
    final cachedCount = CacheService.get<int>(_unreadCacheKey(key));

    if (cached != null) {
      _notifications = List<Map<String, dynamic>>.from(
        cached.map((e) => Map<String, dynamic>.from(e as Map)),
      );
      if (cachedCount != null) {
        _unreadCount = cachedCount;
      }
    } else {
      CacheService.getAsync<List>(_cacheKey(key)).then((diskList) {
        if (diskList != null && mounted && _notifications.isEmpty) {
          final count = CacheService.get<int>(_unreadCacheKey(key)) ?? 0;
          setState(() {
            _notifications = List<Map<String, dynamic>>.from(
              diskList.map((e) => Map<String, dynamic>.from(e as Map)),
            );
            _unreadCount = count;
          });
        }
      });
    }
  }

  Future<void> _fetchNotifications() async {
    final authRepo = CubePod.get<AuthRepository>();
    if (!authRepo.isLoggedIn) {
      if (mounted) {
        setState(() {
          _notifications = [];
          _unreadCount = 0;
        });
      }
      return;
    }

    final currentFilterIndex = _selectedFilterIndex;
    final key = _filterKeys[currentFilterIndex];

    try {
      final response = await http.get(
        Uri.parse('${AppConfig.apiUrl}/notifications?type=$key'),
        headers: authRepo.authHeaders,
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final data = decoded['data'] ?? decoded;
        final list = data['notifications'] as List? ?? [];
        final count = data['unread_count'] as int? ?? 0;

        // Persist immediately on user device storage
        CacheService.set(_cacheKey(key), list);
        CacheService.set(_unreadCacheKey(key), count);

        if (mounted && _selectedFilterIndex == currentFilterIndex) {
          setState(() {
            _notifications = List<Map<String, dynamic>>.from(list);
            _unreadCount = count;
          });
          CubePod.get<NotificationState>().unreadCount.value = count;
          CacheService.set('global_unread_count', count);
        }
      }
    } catch (e) {
      debugPrint('[NotificationsPage] background fetch error: $e');
    }
  }

  Future<void> _markAllAsRead() async {
    final authRepo = CubePod.get<AuthRepository>();
    try {
      await http.patch(
        Uri.parse('${AppConfig.apiUrl}/notifications'),
        headers: authRepo.authHeaders,
        body: jsonEncode({'mark_all_read': true}),
      );
    } catch (_) {}

    setState(() {
      for (var n in _notifications) {
        n['is_read'] = true;
      }
      _unreadCount = 0;
    });
    final key = _filterKeys[_selectedFilterIndex];
    CacheService.set(_cacheKey(key), _notifications);
    CacheService.set(_unreadCacheKey(key), 0);
    CubePod.get<NotificationState>().markAllRead();
    _showToast('All notifications marked as read');
  }

  Future<void> _markSingleAsRead(Map<String, dynamic> item) async {
    final id = item['id']?.toString() ?? '';
    final isAnnouncement = item['is_global'] == true || item['type'] == 'announcement';

    setState(() {
      item['is_read'] = true;
      if (_unreadCount > 0) _unreadCount--;
    });
    final key = _filterKeys[_selectedFilterIndex];
    CacheService.set(_cacheKey(key), _notifications);
    CacheService.set(_unreadCacheKey(key), _unreadCount);
    CubePod.get<NotificationState>().decrement();

    final authRepo = CubePod.get<AuthRepository>();
    try {
      await http.patch(
        Uri.parse('${AppConfig.apiUrl}/notifications'),
        headers: authRepo.authHeaders,
        body: jsonEncode({
          'id': id,
          'is_announcement': isAnnouncement,
        }),
      );
    } catch (_) {}
  }

  Future<void> _deleteNotification(Map<String, dynamic> item) async {
    final id = item['id']?.toString() ?? '';
    final isAnnouncement = item['is_global'] == true || item['type'] == 'announcement';

    setState(() {
      _notifications.removeWhere((n) => n['id']?.toString() == id);
    });
    final key = _filterKeys[_selectedFilterIndex];
    CacheService.set(_cacheKey(key), _notifications);
    CacheService.set(_unreadCacheKey(key), _unreadCount);

    final authRepo = CubePod.get<AuthRepository>();
    try {
      await http.delete(
        Uri.parse('${AppConfig.apiUrl}/notifications?id=$id&is_announcement=$isAnnouncement'),
        headers: authRepo.authHeaders,
      );
    } catch (_) {}
  }

  void _handleCardAction(Map<String, dynamic> item) {
    _markSingleAsRead(item);

    final type = item['type']?.toString() ?? 'general';
    final data = item['data'] as Map<String, dynamic>?;

    if (type.startsWith('product_') || type == 'pickup_scheduled') {
      if (data != null && data.containsKey('product_code')) {
        ProductQrSheet.show(context, data);
      } else {
        Navigator.push(
          context,
          CupertinoPageRoute(builder: (_) => const SubmissionsPage()),
        );
      }
    } else if (type == 'order') {
      Navigator.push(
        context,
        CupertinoPageRoute(builder: (_) => const OrderHistoryPage()),
      );
    } else if (type == 'promo' || type == 'announcement') {
      Navigator.push(
        context,
        CupertinoPageRoute(builder: (_) => const PromotionsPage()),
      );
    }
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13.5)),
        backgroundColor: const Color(0xFF185B3A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _formatTime(String? dateStr) {
    if (dateStr == null) return 'Just now';
    try {
      final date = DateTime.parse(dateStr);
      final diff = DateTime.now().difference(date);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return 'Recently';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF9),
      appBar: AppBar(
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
        backgroundColor: const Color(0xFFF8FAF9),
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A), size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Notifications',
          style: GoogleFonts.outfit(
            color: const Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        actions: [
          if (_notifications.isNotEmpty)
            TextButton(
              onPressed: _markAllAsRead,
              child: Text(
                'Mark all read',
                style: GoogleFonts.outfit(
                  color: const Color(0xFF185B3A),
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Column(
            children: [
              const SizedBox(height: 4),

              // ── Responsive Category Filter Chips ──
              SizedBox(
                height: 32,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _filters.length,
                  itemBuilder: (context, index) {
                    final isSelected = _selectedFilterIndex == index;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: InkWell(
                        onTap: () {
                          if (_selectedFilterIndex == index) return;
                          setState(() {
                            _selectedFilterIndex = index;
                            _loadCachedNotifications();
                          });
                          _fetchNotifications();
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF185B3A) : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected ? const Color(0xFF185B3A) : const Color(0xFFE2E8F0),
                              width: 1.0,
                            ),
                          ),
                          child: Text(
                            _filters[index],
                            style: GoogleFonts.outfit(
                              fontSize: 12.5,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                              color: isSelected ? Colors.white : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 12),

              // ── Live Notification Cards Feed ──
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _fetchNotifications,
                  color: const Color(0xFF185B3A),
                  child: _notifications.isEmpty
                      ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Stack(
                                    clipBehavior: Clip.none,
                                    alignment: Alignment.center,
                                    children: [
                                      SvgPicture.asset(
                                        'assets/icons/ic_bell.svg',
                                        width: 68,
                                        height: 68,
                                        colorFilter: const ColorFilter.mode(Color(0xFF185B3A), BlendMode.srcIn),
                                      ),
                                      Positioned(
                                        top: 2,
                                        right: 6,
                                        child: Container(
                                          width: 14,
                                          height: 14,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF44336),
                                            shape: BoxShape.circle,
                                            border: Border.all(color: const Color(0xFFF8FAF9), width: 2.5),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No notifications in this category',
                                    style: GoogleFonts.outfit(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Stay tuned for product submissions, orders, and offers updates!',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.outfit(fontSize: 12.5, color: const Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                              padding: const EdgeInsets.fromLTRB(16, 6, 16, 32),
                              itemCount: _notifications.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final item = _notifications[index];
                                return _buildNotificationCard(item);
                              },
                            ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> item) {
    final id = item['id']?.toString() ?? '';
    final title = item['title']?.toString() ?? 'Notification';
    final message = item['message']?.toString() ?? '';
    final type = item['type']?.toString() ?? 'general';
    final iconId = item['icon_id']?.toString() ?? item['icon_type']?.toString();
    final isRead = item['is_read'] == true;
    final isGlobal = item['is_global'] == true || type == 'announcement';
    final timeStr = _formatTime(item['created_at']?.toString());

    // Category Pill details
    String categoryPillText;
    Color categoryPillBg;
    Color categoryPillColor;

    if (isGlobal || type == 'announcement') {
      categoryPillText = 'GLOBAL ANNOUNCEMENT';
      categoryPillBg = const Color(0xFFF3E8FF);
      categoryPillColor = const Color(0xFF7C3AED);
    } else if (type == 'product_submission' || type == 'pickup_scheduled' || type == 'product_listed') {
      categoryPillText = 'SELLER & LOGISTICS';
      categoryPillBg = const Color(0xFFFFFBEB);
      categoryPillColor = const Color(0xFFB45309);
    } else if (type == 'order') {
      categoryPillText = 'ORDER UPDATE';
      categoryPillBg = const Color(0xFFE8F5EE);
      categoryPillColor = const Color(0xFF185B3A);
    } else if (type == 'promo') {
      categoryPillText = 'SPECIAL DEAL';
      categoryPillBg = const Color(0xFFFEF3C7);
      categoryPillColor = const Color(0xFFD97706);
    } else {
      categoryPillText = 'NOTICE';
      categoryPillBg = const Color(0xFFF1F5F9);
      categoryPillColor = const Color(0xFF64748B);
    }

    // Action button label & icon
    String? actionBtnText;
    IconData? actionBtnIcon;

    if (type.startsWith('product_') || type == 'pickup_scheduled') {
      actionBtnText = 'View QR & Pickup Pass';
      actionBtnIcon = Icons.qr_code_2_rounded;
    } else if (type == 'order') {
      actionBtnText = 'Track Order';
      actionBtnIcon = Icons.local_shipping_outlined;
    } else if (type == 'promo' || type == 'announcement') {
      actionBtnText = 'Explore Deals & Store';
      actionBtnIcon = Icons.arrow_forward_rounded;
    }

    return Dismissible(
      key: Key(id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _deleteNotification(item),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: const Color(0xFFFEE2E2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFE11D48)),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isRead ? Colors.white : const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isRead ? const Color(0xFFF1F5F9) : const Color(0xFFBBF7D0),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header Row: Icon + Title/Category + Relative Time & Unread Dot ──
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // NotiSvgs DB Vector Icon
                NotiSvgs(iconId: iconId, type: type, size: 20),
                const SizedBox(width: 12),

                // Title + Category + Time
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: categoryPillBg,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              categoryPillText,
                              style: GoogleFonts.outfit(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: categoryPillColor,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            timeStr,
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              color: const Color(0xFF94A3B8),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (!isRead) ...[
                            const SizedBox(width: 6),
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFF185B3A),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        title,
                        style: GoogleFonts.outfit(
                          fontSize: 14.5,
                          fontWeight: isRead ? FontWeight.w600 : FontWeight.bold,
                          color: const Color(0xFF0F172A),
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // ── Message Content ──
            Text(
              message,
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: const Color(0xFF475569),
                height: 1.4,
              ),
            ),

            // ── Responsive Action Buttons Row ──
            if (actionBtnText != null) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  InkWell(
                    onTap: () => _handleCardAction(item),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF185B3A),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (actionBtnIcon != null) ...[
                            Icon(actionBtnIcon, size: 15, color: Colors.white),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            actionBtnText,
                            style: GoogleFonts.outfit(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (!isRead)
                    InkWell(
                      onTap: () => _markSingleAsRead(item),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Text(
                          'Mark as read',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
