import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:app/core/network/httpClient.dart' as http;
import 'package:app/core/config/appConfig.dart';
import 'package:app/core/services/cacheService.dart';
import 'package:app/features/customer/submissions/screens/submissionsPage.dart';
import 'package:app/features/customer/orders/screens/orderHistoryPage.dart';
import 'package:app/features/customer/explore/screens/promotionsPage.dart';
import 'package:app/core/widgets/productQrSheet.dart';
import 'package:app/features/customer/notifications/widgets/notificationCard.dart';
import 'package:app/core/di/injection.dart';
import 'package:app/features/customer/notifications/providers/notificationState.dart';
import 'package:app/features/customer/notifications/providers/notificationProviders.dart';

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  int get _selectedFilterIndex => ref.read(notificationsSelectedFilterIndexProvider);
  final List<String> _filters = ['All', 'Announcements', 'Product Updates', 'Orders', 'Offers & Deals'];
  final List<String> _filterKeys = ['all', 'announcements', 'products', 'orders', 'promos'];

  List<Map<String, dynamic>> get _notifications => ref.read(notificationsListProvider);
  int get _unreadCount => ref.read(notificationsUnreadCountProvider);

  String _cacheKey(String key) => 'notifs_$key';
  String _unreadCacheKey(String key) => 'notifs_unread_$key';

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      _loadCachedNotifications();
      _fetchNotifications();
    });
  }

  void _loadCachedNotifications() {
    final key = _filterKeys[_selectedFilterIndex];
    final cached = CacheService.get<List>(_cacheKey(key));
    final cachedCount = CacheService.get<int>(_unreadCacheKey(key));

    if (cached != null) {
      ref.read(notificationsListProvider.notifier).state = List<Map<String, dynamic>>.from(
        cached.map((e) => Map<String, dynamic>.from(e as Map)),
      );
      if (cachedCount != null) {
        ref.read(notificationsUnreadCountProvider.notifier).state = cachedCount;
      }
    } else {
      CacheService.getAsync<List>(_cacheKey(key)).then((diskList) {
        if (diskList != null && mounted && _notifications.isEmpty) {
          final count = CacheService.get<int>(_unreadCacheKey(key)) ?? 0;
          ref.read(notificationsListProvider.notifier).state = List<Map<String, dynamic>>.from(
            diskList.map((e) => Map<String, dynamic>.from(e as Map)),
          );
          ref.read(notificationsUnreadCountProvider.notifier).state = count;
        }
      });
    }
  }

  Future<void> _fetchNotifications() async {
    final authRepo = ref.read(authRepositoryProvider);
    if (!authRepo.isLoggedIn) {
      if (mounted) {
        ref.read(notificationsListProvider.notifier).state = [];
        ref.read(notificationsUnreadCountProvider.notifier).state = 0;
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
          ref.read(notificationsListProvider.notifier).state = List<Map<String, dynamic>>.from(list);
          ref.read(notificationsUnreadCountProvider.notifier).state = count;
          ref.read(notificationStateProvider).setUnreadCount(count);
          CacheService.set('global_unread_count', count);
        }
      }
    } catch (e) {
      debugPrint('[NotificationsPage] background fetch error: $e');
    }
  }

  Future<void> _markAllAsRead() async {
    final authRepo = ref.read(authRepositoryProvider);
    try {
      await http.patch(
        Uri.parse('${AppConfig.apiUrl}/notifications'),
        headers: authRepo.authHeaders,
        body: jsonEncode({'mark_all_read': true}),
      );
    } catch (_) {}

    final updated = _notifications.map((n) => {...n, 'is_read': true}).toList();
    ref.read(notificationsListProvider.notifier).state = updated;
    ref.read(notificationsUnreadCountProvider.notifier).state = 0;
    final key = _filterKeys[_selectedFilterIndex];
    CacheService.set(_cacheKey(key), _notifications);
    CacheService.set(_unreadCacheKey(key), 0);
    ref.read(notificationStateProvider).markAllRead();
    _showToast('All notifications marked as read');
  }

  Future<void> _markSingleAsRead(Map<String, dynamic> item) async {
    final id = item['id']?.toString() ?? '';
    final isAnnouncement = item['is_global'] == true || item['type'] == 'announcement';

    item['is_read'] = true;
    ref.read(notificationsListProvider.notifier).state = [..._notifications];
    if (_unreadCount > 0) {
      ref.read(notificationsUnreadCountProvider.notifier).state = _unreadCount - 1;
    }
    final key = _filterKeys[_selectedFilterIndex];
    CacheService.set(_cacheKey(key), _notifications);
    CacheService.set(_unreadCacheKey(key), _unreadCount);
    ref.read(notificationStateProvider).decrement();

    final authRepo = ref.read(authRepositoryProvider);
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

    ref.read(notificationsListProvider.notifier).state =
        _notifications.where((n) => n['id']?.toString() != id).toList();
    final key = _filterKeys[_selectedFilterIndex];
    CacheService.set(_cacheKey(key), _notifications);
    CacheService.set(_unreadCacheKey(key), _unreadCount);

    final authRepo = ref.read(authRepositoryProvider);
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
    ref.watch(notificationsSelectedFilterIndexProvider);
    ref.watch(notificationsListProvider);
    ref.watch(notificationsUnreadCountProvider);

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
                          ref.read(notificationsSelectedFilterIndexProvider.notifier).state = index;
                          _loadCachedNotifications();
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
                                return NotificationCard(
                                  item: item,
                                  timeStr: _formatTime(item['created_at']?.toString()),
                                  onDismissed: _deleteNotification,
                                  onAction: _handleCardAction,
                                  onMarkRead: _markSingleAsRead,
                                );
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
}
