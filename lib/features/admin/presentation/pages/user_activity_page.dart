import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'package:app/core/network/http_client.dart' as http;
import 'package:app/core/config/app_config.dart';
import 'package:app/features/auth/data/repositories/auth_repository.dart';
import 'package:cubepod_core/cubepod_core.dart';
import 'package:app/features/admin/presentation/widgets/order_map_widget.dart';
import 'package:app/features/admin/presentation/pages/order_details_page.dart';

class UserActivityPage extends StatefulWidget {
  final Map<String, dynamic> user;
  final String initialCategory;
  final List<dynamic>? initialOrders;
  final List<dynamic>? initialPointsLedger;
  final List<dynamic>? initialCart;
  final List<dynamic>? initialNotifications;
  final List<dynamic>? initialAddresses;
  final List<dynamic>? initialReviews;
  final List<dynamic>? initialFavorites;
  final Map<String, dynamic>? initialStats;

  const UserActivityPage({
    super.key,
    required this.user,
    this.initialCategory = 'orders',
    this.initialOrders,
    this.initialPointsLedger,
    this.initialCart,
    this.initialNotifications,
    this.initialAddresses,
    this.initialReviews,
    this.initialFavorites,
    this.initialStats,
  });

  @override
  State<UserActivityPage> createState() => _UserActivityPageState();
}

class _UserActivityPageState extends State<UserActivityPage>
    with SingleTickerProviderStateMixin {
  late String _selectedCategory;
  bool _isLoading = false;

  late AnimationController _skeletonController;
  late Animation<Color?> _skeletonAnimation;

  List<dynamic> _orders = [];
  List<dynamic> _pointsLedger = [];
  List<dynamic> _cart = [];
  List<dynamic> _notifications = [];
  List<dynamic> _addresses = [];
  List<dynamic> _reviews = [];
  List<dynamic> _favorites = [];
  Map<String, dynamic> _stats = {};

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

    _selectedCategory = widget.initialCategory;
    _orders = widget.initialOrders ?? [];
    _pointsLedger = widget.initialPointsLedger ?? [];
    _cart = widget.initialCart ?? [];
    _notifications = widget.initialNotifications ?? [];
    _addresses = widget.initialAddresses ?? [];
    _reviews = widget.initialReviews ?? [];
    _favorites = widget.initialFavorites ?? [];
    _stats = widget.initialStats ?? {};

    _fetchUserActivity();
  }

  @override
  void dispose() {
    _skeletonController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserActivity() async {
    final userId = widget.user['id'];
    setState(() => _isLoading = true);
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.apiUrl}/admin/users/$userId/activity'),
        headers: CubePod.get<AuthRepository>().authHeaders,
      );
      if (response.statusCode == 200 && mounted) {
        final data = jsonDecode(response.body);
        setState(() {
          _orders = data['orders'] ?? [];
          _pointsLedger = data['points_ledger'] ?? [];
          _cart = data['cart'] ?? [];
          _notifications = data['notifications'] ?? [];
          _addresses = data['addresses'] ?? [];
          _reviews = data['reviews'] ?? [];
          _favorites = data['favorites'] ?? [];
          _stats = data['stats'] ?? {};
        });
      }
    } catch (e) {
      debugPrint('Error fetching activity: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatDateTime(dynamic dtString) {
    if (dtString == null || dtString.toString().trim().isEmpty) return 'Not recorded';
    try {
      final dt = DateTime.parse(dtString.toString()).toLocal();
      final year = dt.year;
      final month = dt.month.toString().padLeft(2, '0');
      final day = dt.day.toString().padLeft(2, '0');
      final hourNum = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final min = dt.minute.toString().padLeft(2, '0');
      final period = dt.hour >= 12 ? 'PM' : 'AM';
      return '$year-$month-$day • $hourNum:$min $period';
    } catch (_) {
      return dtString.toString().split('T').first;
    }
  }

  void _showAdjustPointsSheet() {
    final amountCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    bool isCredit = true;
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.stars_rounded, color: Color(0xFFD97706), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Adjust Loyalty Points', style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
                          Text('Current Balance: ${_stats['points_balance'] ?? 0} Pts', style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF64748B))),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setModalState(() => isCredit = true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: isCredit ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: isCredit ? const Color(0xFF16A34A) : const Color(0xFFE2E8F0), width: isCredit ? 1.5 : 1),
                          ),
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_circle_outline_rounded, size: 16, color: isCredit ? const Color(0xFF16A34A) : const Color(0xFF64748B)),
                                const SizedBox(width: 6),
                                Text('Add Points (+)', style: GoogleFonts.outfit(fontSize: 13, fontWeight: isCredit ? FontWeight.bold : FontWeight.w600, color: isCredit ? const Color(0xFF16A34A) : const Color(0xFF64748B))),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setModalState(() => isCredit = false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: !isCredit ? const Color(0xFFFFF1F2) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: !isCredit ? const Color(0xFFE11D48) : const Color(0xFFE2E8F0), width: !isCredit ? 1.5 : 1),
                          ),
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.remove_circle_outline_rounded, size: 16, color: !isCredit ? const Color(0xFFE11D48) : const Color(0xFF64748B)),
                                const SizedBox(width: 6),
                                Text('Deduct Points (-)', style: GoogleFonts.outfit(fontSize: 13, fontWeight: !isCredit ? FontWeight.bold : FontWeight.w600, color: !isCredit ? const Color(0xFFE11D48) : const Color(0xFF64748B))),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text('Points Amount', style: GoogleFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.w700, color: const Color(0xFF334155))),
                const SizedBox(height: 6),
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: GoogleFonts.outfit(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'e.g. 100, 250, 500',
                    hintStyle: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF94A3B8)),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 12),
                Text('Reason / Description', style: GoogleFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.w700, color: const Color(0xFF334155))),
                const SizedBox(height: 6),
                TextField(
                  controller: reasonCtrl,
                  style: GoogleFonts.outfit(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'e.g. VIP Bonus, Referral Reward, Compensation',
                    hintStyle: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF94A3B8)),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isCredit ? const Color(0xFF185B3A) : const Color(0xFFE11D48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            final amt = int.tryParse(amountCtrl.text.trim()) ?? 0;
                            final reason = reasonCtrl.text.trim();
                            if (amt <= 0 || reason.isEmpty) return;

                            final delta = isCredit ? amt : -amt;
                            setModalState(() => isSubmitting = true);
                            try {
                              final res = await http.post(
                                Uri.parse('${AppConfig.apiUrl}/admin/users/points'),
                                headers: {
                                  ...CubePod.get<AuthRepository>().authHeaders,
                                  'Content-Type': 'application/json',
                                },
                                body: jsonEncode({
                                  'user_id': widget.user['id'],
                                  'delta': delta,
                                  'reason': reason,
                                }),
                              );
                              if (mounted && ctx.mounted) {
                                Navigator.pop(ctx);
                                if (res.statusCode == 200) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(isCredit ? '$amt points granted successfully' : '$amt points deducted'),
                                      backgroundColor: isCredit ? const Color(0xFF185B3A) : const Color(0xFFE11D48),
                                    ),
                                  );
                                  _fetchUserActivity();
                                }
                              }
                            } catch (_) {}
                          },
                    icon: isSubmitting
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 18),
                    label: Text(
                      isSubmitting ? 'Updating...' : (isCredit ? 'Credit Points' : 'Deduct Points'),
                      style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showNotificationComposer() {
    final titleCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();
    String selectedType = 'system';
    bool isSending = false;
    final targetName = widget.user['name'] ?? widget.user['email'] ?? 'User';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.notifications_active_rounded, color: Color(0xFF2563EB), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Direct Push Notification', style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
                          Text('Sending to: $targetName', style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF64748B))),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text('Notification Title', style: GoogleFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.w700, color: const Color(0xFF334155))),
                const SizedBox(height: 6),
                TextField(
                  controller: titleCtrl,
                  style: GoogleFonts.outfit(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'e.g. Order Update / Exclusive Reward',
                    hintStyle: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF94A3B8)),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 12),
                Text('Message Details', style: GoogleFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.w700, color: const Color(0xFF334155))),
                const SizedBox(height: 6),
                TextField(
                  controller: bodyCtrl,
                  maxLines: 3,
                  style: GoogleFonts.outfit(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Type your message...',
                    hintStyle: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF94A3B8)),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF185B3A),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    onPressed: isSending
                        ? null
                        : () async {
                            final title = titleCtrl.text.trim();
                            final body = bodyCtrl.text.trim();
                            if (title.isEmpty || body.isEmpty) return;

                            setModalState(() => isSending = true);
                            try {
                              final res = await http.post(
                                Uri.parse('${AppConfig.apiUrl}/notifications'),
                                headers: {
                                  ...CubePod.get<AuthRepository>().authHeaders,
                                  'Content-Type': 'application/json',
                                },
                                body: jsonEncode({
                                  'user_id': widget.user['id'],
                                  'title': title,
                                  'body': body,
                                  'type': selectedType,
                                }),
                              );
                              if (mounted && ctx.mounted) {
                                Navigator.pop(ctx);
                                if (res.statusCode == 200) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Notification sent to $targetName'), backgroundColor: const Color(0xFF185B3A)),
                                  );
                                  _fetchUserActivity();
                                }
                              }
                            } catch (_) {}
                          },
                    icon: isSending
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                    label: Text(
                      isSending ? 'Sending...' : 'Send Notification',
                      style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = (widget.user['name'] ?? widget.user['username'] ?? 'User').toString();

    final categoryMeta = {
      'orders': {
        'title': 'Orders & Purchases',
        'subtitle': _orders.isEmpty ? 'No orders placed yet' : '${_orders.length} order(s) placed',
        'icon': Icons.shopping_bag_outlined,
      },
      'points': {
        'title': 'Points & Rewards',
        'subtitle': '${_stats['points_balance'] ?? 0} Pts balance',
        'icon': Icons.stars_rounded,
      },
      'cart': {
        'title': 'Active Shopping Cart',
        'subtitle': _cart.isEmpty ? 'Cart is currently empty' : '${_cart.length} item(s) pending',
        'icon': Icons.shopping_cart_outlined,
      },
      'notifications': {
        'title': 'Push Notifications',
        'subtitle': _notifications.isEmpty ? 'No notifications logged' : '${_notifications.length} message(s) sent',
        'icon': Icons.notifications_active_outlined,
      },
      'addresses': {
        'title': 'Delivery Addresses',
        'subtitle': _addresses.isEmpty ? 'No addresses saved' : '${_addresses.length} saved address(es)',
        'icon': Icons.location_on_outlined,
      },
      'reviews': {
        'title': 'Product Reviews',
        'subtitle': _reviews.isEmpty ? 'No reviews written' : '${_reviews.length} written review(s)',
        'icon': Icons.rate_review_outlined,
      },
      'favorites': {
        'title': 'Saved Wishlist',
        'subtitle': _favorites.isEmpty ? 'No wishlist items' : '${_favorites.length} saved product(s)',
        'icon': Icons.favorite_outline_rounded,
      },
    };

    final currentMeta = categoryMeta[_selectedCategory] ?? categoryMeta['orders']!;
    final subtitleText = _isLoading ? 'Loading records...' : (currentMeta['subtitle'] as String);

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
          leading: Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Center(
              child: InkWell(
                onTap: () => Navigator.pop(context),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A), size: 16),
                ),
              ),
            ),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                currentMeta['title'] as String,
                style: GoogleFonts.outfit(fontSize: 16.5, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
              ),
              Text(
                _isLoading ? name : '$name • $subtitleText',
                style: GoogleFonts.outfit(fontSize: 11.5, color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
              ),
            ],
          ),
          centerTitle: true,
          actions: [
            if (_selectedCategory == 'points')
              IconButton(
                icon: const Icon(Icons.add_circle_outline_rounded, size: 22, color: Color(0xFFD97706)),
                tooltip: 'Adjust Points',
                onPressed: _showAdjustPointsSheet,
              ),
            if (_selectedCategory == 'notifications')
              IconButton(
                icon: const Icon(Icons.add_comment_outlined, size: 20, color: Color(0xFF2563EB)),
                tooltip: 'Compose Notification',
                onPressed: _showNotificationComposer,
              ),
            PopupMenuButton<String>(
              icon: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Icon(Icons.swap_vert_rounded, size: 18, color: Color(0xFF475569)),
              ),
              tooltip: 'Switch Activity Category',
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              onSelected: (catKey) {
                HapticFeedback.selectionClick();
                setState(() => _selectedCategory = catKey);
              },
              itemBuilder: (ctx) => [
                _buildCategoryMenuItem('orders', 'Orders', _orders.length, Icons.shopping_bag_outlined, const Color(0xFF185B3A)),
                _buildCategoryMenuItem('points', 'Points & Rewards', _pointsLedger.length, Icons.stars_rounded, const Color(0xFFD97706)),
                _buildCategoryMenuItem('cart', 'Shopping Cart', _cart.length, Icons.shopping_cart_outlined, const Color(0xFF2563EB)),
                _buildCategoryMenuItem('notifications', 'Push Notifications', _notifications.length, Icons.notifications_active_outlined, const Color(0xFF7C3AED)),
                _buildCategoryMenuItem('addresses', 'Delivery Addresses', _addresses.length, Icons.location_on_outlined, const Color(0xFF059669)),
                _buildCategoryMenuItem('reviews', 'Reviews & Ratings', _reviews.length, Icons.rate_review_outlined, const Color(0xFFEA580C)),
                _buildCategoryMenuItem('favorites', 'Saved Wishlist', _favorites.length, Icons.favorite_outline_rounded, const Color(0xFFE11D48)),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded, size: 20, color: Color(0xFF64748B)),
              tooltip: 'Refresh',
              onPressed: _fetchUserActivity,
            ),
            const SizedBox(width: 6),
          ],
        ),
        body: _buildCategoryView(),
      ),
    );
  }

  PopupMenuItem<String> _buildCategoryMenuItem(
    String key,
    String label,
    int count,
    IconData icon,
    Color color,
  ) {
    final isSelected = _selectedCategory == key;
    return PopupMenuItem<String>(
      value: key,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 13.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF475569),
              ),
            ),
          ),
          if (count > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected ? color.withValues(alpha: 0.15) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? color : const Color(0xFF64748B),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSkeletonList() {
    return AnimatedBuilder(
      animation: _skeletonAnimation,
      builder: (context, _) {
        final shimmer = _skeletonAnimation.value ?? const Color(0xFFF1F5F9);
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: 5,
          physics: const NeverScrollableScrollPhysics(),
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (ctx, i) {
            return Container(
              padding: const EdgeInsets.all(16),
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
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: shimmer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 130,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: shimmer,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                width: 85,
                                height: 11,
                                decoration: BoxDecoration(
                                  color: shimmer,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Container(
                        width: 55,
                        height: 22,
                        decoration: BoxDecoration(
                          color: shimmer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    height: 1,
                    color: const Color(0xFFF8FAFC),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: shimmer,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 160,
                        height: 12,
                        decoration: BoxDecoration(
                          color: shimmer,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCategoryView() {
    if (_isLoading) {
      return _buildSkeletonList();
    }
    switch (_selectedCategory) {
      case 'orders':
        return _buildOrdersView();
      case 'points':
        return _buildPointsView();
      case 'cart':
        return _buildCartView();
      case 'notifications':
        return _buildNotificationsView();
      case 'addresses':
        return _buildAddressesView();
      case 'reviews':
        return _buildReviewsView();
      case 'favorites':
        return _buildFavoritesView();
      default:
        return _buildOrdersView();
    }
  }

  Widget _buildOrdersView() {
    if (_orders.isEmpty) {
      return _buildEmptyState('No order history found for this user', Icons.shopping_bag_outlined);
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _orders.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (ctx, i) {
        final o = _orders[i];
        final status = (o['status'] ?? 'Pending').toString();
        final total = o['total_amount'] ?? '0';
        final date = _formatDateTime(o['created_at']);
        final items = (o['order_items'] ?? []) as List;

        Color statusBg = const Color(0xFFFEF3C7);
        Color statusText = const Color(0xFFD97706);
        if (status.toLowerCase() == 'delivered') {
          statusBg = const Color(0xFFDCFCE7);
          statusText = const Color(0xFF15803D);
        } else if (status.toLowerCase() == 'cancelled') {
          statusBg = const Color(0xFFFEE2E2);
          statusText = const Color(0xFFB91C1C);
        }

        final discrepancyKm = (o['location_discrepancy_km'] as num?)?.toDouble() ?? 0.0;
        final isFraudFlagged = o['is_fraud_flagged'] == true || discrepancyKm > 15;
        final snapshot = o['address_snapshot'] is Map ? o['address_snapshot'] as Map : null;
        final destAddress = o['destination_address']?.toString() ??
            (snapshot != null ? (snapshot['address'] ?? snapshot['street'] ?? snapshot['details'])?.toString() : null) ??
            'Delivery Address';

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isFraudFlagged ? const Color(0xFFFDA4AF) : const Color(0xFFE2E8F0),
              width: isFraudFlagged ? 1.5 : 1.0,
            ),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 2)),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => OrderDetailsPage(order: o)),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Order #${o['id'].toString().substring(0, 8)}',
                              style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                            ),
                            const SizedBox(height: 2),
                            Text(date, style: GoogleFonts.outfit(fontSize: 11.5, color: const Color(0xFF94A3B8))),
                          ],
                        ),
                        Row(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'Rs $total',
                                  style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFF185B3A)),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                                  decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(6)),
                                  child: Text(
                                    status.toUpperCase(),
                                    style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w800, color: statusText, letterSpacing: 0.4),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Color(0xFF94A3B8)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Destination Address
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFFE11D48)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            destAddress,
                            style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF475569)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Minimal GPS Discrepancy badge & Items summary
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: isFraudFlagged ? const Color(0xFFFEE2E2) : const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isFraudFlagged ? Icons.warning_amber_rounded : Icons.shield_rounded,
                                size: 12,
                                color: isFraudFlagged ? const Color(0xFFB91C1C) : const Color(0xFF15803D),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isFraudFlagged
                                    ? 'High Risk: ${discrepancyKm.toStringAsFixed(1)} km discrepancy'
                                    : (discrepancyKm > 0
                                        ? 'GPS Verified • ${discrepancyKm.toStringAsFixed(1)} km'
                                        : 'GPS Verified • Match'),
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isFraudFlagged ? const Color(0xFFB91C1C) : const Color(0xFF15803D),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${items.length} item(s) • Details →',
                          style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.w600, color: const Color(0xFF185B3A)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPointsView() {
    return Column(
      children: [
        // Balance Header
        Container(
          margin: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF3C7),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFDE68A)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.stars_rounded, color: Color(0xFFD97706), size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Current Loyalty Balance', style: GoogleFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.w600, color: const Color(0xFF92400E))),
                    Text('${_stats['points_balance'] ?? 0} Points', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w800, color: const Color(0xFF78350F))),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: _showAdjustPointsSheet,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD97706),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.tune_rounded, color: Colors.white, size: 14),
                label: Text('Adjust', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ],
          ),
        ),

        Expanded(
          child: _pointsLedger.isEmpty
              ? _buildEmptyState('No points or rewards ledger history', Icons.stars_rounded)
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _pointsLedger.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (ctx, i) {
                    final p = _pointsLedger[i];
                    final delta = int.tryParse(p['delta'].toString()) ?? 0;
                    final isEarned = delta > 0;
                    final reason = p['reason'] ?? 'Reward';
                    final date = _formatDateTime(p['created_at']);

                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isEarned ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isEarned ? Icons.add_rounded : Icons.remove_rounded,
                              size: 16,
                              color: isEarned ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  reason.toString().replaceAll('_', ' ').toUpperCase(),
                                  style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                                ),
                                const SizedBox(height: 2),
                                Text(date, style: GoogleFonts.outfit(fontSize: 11.5, color: const Color(0xFF94A3B8))),
                              ],
                            ),
                          ),
                          Text(
                            '${isEarned ? '+' : ''}$delta Pts',
                            style: GoogleFonts.outfit(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: isEarned ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildCartView() {
    if (_cart.isEmpty) {
      return _buildEmptyState('User cart is currently empty', Icons.remove_shopping_cart_outlined);
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _cart.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (ctx, i) {
        final item = _cart[i];
        final product = item['products'] ?? {};
        final qty = item['quantity'] ?? 1;
        final price = double.tryParse(product['price']?.toString() ?? '0') ?? 0;
        final img = product['image'] ?? product['thumbnail'] ?? '';

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: img.toString().isNotEmpty
                    ? Image.network(img, width: 50, height: 50, fit: BoxFit.cover, errorBuilder: (_, _, _) => Container(width: 50, height: 50, color: const Color(0xFFF1F5F9), child: const Icon(Icons.image_outlined)))
                    : Container(width: 50, height: 50, color: const Color(0xFFF1F5F9), child: const Icon(Icons.image_outlined)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product['title'] ?? 'Product', style: GoogleFonts.outfit(fontSize: 13.5, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
                    const SizedBox(height: 3),
                    Text('Qty: $qty × Rs $price', style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF64748B))),
                  ],
                ),
              ),
              Text(
                'Rs ${price * qty}',
                style: GoogleFonts.outfit(fontSize: 14.5, fontWeight: FontWeight.w800, color: const Color(0xFF185B3A)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNotificationsView() {
    if (_notifications.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Color(0xFFFAF5FF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.notifications_off_outlined, size: 42, color: Color(0xFF7C3AED)),
              ),
              const SizedBox(height: 16),
              Text(
                'No Notifications Yet',
                style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
              ),
              const SizedBox(height: 6),
              Text(
                'No push notifications or system alerts have been sent to this user yet.',
                style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF64748B)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _showNotificationComposer,
                icon: const Icon(Icons.send_rounded, size: 16),
                label: Text(
                  'Send Push Notification',
                  style: GoogleFonts.outfit(fontSize: 13.5, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _notifications.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (ctx, i) {
        if (i == 0) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFAF5FF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE9D5FF)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.notifications_active_rounded, size: 18, color: Color(0xFF7C3AED)),
                    const SizedBox(width: 8),
                    Text(
                      '${_notifications.length} Notification(s) Sent',
                      style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF581C87)),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7C3AED),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _showNotificationComposer,
                  icon: const Icon(Icons.send_rounded, size: 14),
                  label: Text('Compose', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        }

        final n = _notifications[i - 1];
        final title = n['title'] ?? 'Notification';
        final body = n['body'] ?? n['message'] ?? '';
        final date = _formatDateTime(n['created_at']);
        final isRead = n['is_read'] == true;
        final data = n['data'] is Map ? n['data'] as Map : null;
        final rawType = (data?['type'] ?? n['type'] ?? '').toString().toLowerCase();

        IconData typeIcon = Icons.notifications_rounded;
        Color typeColor = const Color(0xFF7C3AED);
        Color typeBg = const Color(0xFFFAF5FF);
        String typeLabel = 'ALERT';

        if (rawType.contains('order') || title.toLowerCase().contains('order')) {
          typeIcon = Icons.local_shipping_outlined;
          typeColor = const Color(0xFF16A34A);
          typeBg = const Color(0xFFF0FDF4);
          typeLabel = 'ORDER UPDATE';
        } else if (rawType.contains('promo') || rawType.contains('reward') || rawType.contains('point') || title.toLowerCase().contains('reward')) {
          typeIcon = Icons.stars_rounded;
          typeColor = const Color(0xFFD97706);
          typeBg = const Color(0xFFFEF3C7);
          typeLabel = 'REWARD';
        } else if (rawType.contains('security') || rawType.contains('login') || rawType.contains('session')) {
          typeIcon = Icons.shield_outlined;
          typeColor = const Color(0xFF2563EB);
          typeBg = const Color(0xFFEFF6FF);
          typeLabel = 'SECURITY';
        }

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
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
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(color: typeBg, borderRadius: BorderRadius.circular(6)),
                        child: Icon(typeIcon, size: 13, color: typeColor),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: typeBg, borderRadius: BorderRadius.circular(6)),
                        child: Text(
                          typeLabel,
                          style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.w800, color: typeColor),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isRead ? const Color(0xFFDCFCE7) : const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isRead ? 'READ' : 'UNREAD',
                          style: GoogleFonts.outfit(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: isRead ? const Color(0xFF15803D) : const Color(0xFF2563EB),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(date, style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF94A3B8))),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(title, style: GoogleFonts.outfit(fontSize: 14.5, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
              if (body.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(body, style: GoogleFonts.outfit(fontSize: 12.5, color: const Color(0xFF475569), height: 1.35)),
              ],
              if (data?['order_id'] != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Order #${data!['order_id'].toString().length > 8 ? data['order_id'].toString().substring(0, 8) : data['order_id']}',
                    style: GoogleFonts.outfit(fontSize: 10.5, fontWeight: FontWeight.bold, color: const Color(0xFF475569)),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildAddressesView() {
    if (_addresses.isEmpty) {
      return _buildEmptyState('No delivery addresses saved', Icons.location_off_outlined);
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _addresses.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (ctx, i) {
        final a = _addresses[i];
        final label = (a['label'] ?? 'Home').toString();
        final isDefault = a['is_default'] == true;
        final recName = a['name'] ?? '';
        final phone = a['phone'] ?? '';
        final street = a['street'] ?? '';
        final details = a['details'] ?? '';

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isDefault ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0), width: isDefault ? 1.5 : 1),
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
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                        decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(6)),
                        child: Text(label.toUpperCase(), style: GoogleFonts.outfit(fontSize: 9.5, fontWeight: FontWeight.w800, color: const Color(0xFF2563EB))),
                      ),
                      if (isDefault) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                          decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(6)),
                          child: Text('DEFAULT', style: GoogleFonts.outfit(fontSize: 9.5, fontWeight: FontWeight.w800, color: const Color(0xFF15803D))),
                        ),
                      ],
                    ],
                  ),
                  if (phone.isNotEmpty) Text(phone, style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
                ],
              ),
              const SizedBox(height: 8),
              if (recName.isNotEmpty)
                Text(recName, style: GoogleFonts.outfit(fontSize: 13.5, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
              Text(street, style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF334155))),
              if (details.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(details, style: GoogleFonts.outfit(fontSize: 11.5, color: const Color(0xFF94A3B8))),
              ],
              AddressLocationMapWidget(address: a),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReviewsView() {
    if (_reviews.isEmpty) {
      return _buildEmptyState('No product reviews written yet', Icons.rate_review_outlined);
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _reviews.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (ctx, i) {
        final r = _reviews[i];
        final product = r['products'] ?? {};
        final rating = r['rating'] ?? 5;
        final experience = (r['experience'] ?? r['comment'] ?? '').toString();

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      product['title'] ?? 'Product Review',
                      style: GoogleFonts.outfit(fontSize: 13.5, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Row(
                    children: List.generate(
                      5,
                      (star) => Icon(
                        star < rating ? Icons.star_rounded : Icons.star_outline_rounded,
                        size: 15,
                        color: const Color(0xFFF59E0B),
                      ),
                    ),
                  ),
                ],
              ),
              if (experience.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(experience, style: GoogleFonts.outfit(fontSize: 12.5, color: const Color(0xFF475569))),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildFavoritesView() {
    if (_favorites.isEmpty) {
      return _buildEmptyState('No products in wishlist', Icons.favorite_outline_rounded);
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _favorites.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (ctx, i) {
        final f = _favorites[i];
        final product = f['products'] ?? {};
        final price = product['price'] ?? '0';
        final img = product['image'] ?? product['thumbnail'] ?? '';

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: img.toString().isNotEmpty
                    ? Image.network(img, width: 50, height: 50, fit: BoxFit.cover, errorBuilder: (_, _, _) => Container(width: 50, height: 50, color: const Color(0xFFF1F5F9), child: const Icon(Icons.image_outlined)))
                    : Container(width: 50, height: 50, color: const Color(0xFFF1F5F9), child: const Icon(Icons.image_outlined)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product['title'] ?? 'Product', style: GoogleFonts.outfit(fontSize: 13.5, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
                    const SizedBox(height: 3),
                    Text('Rs $price', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF185B3A))),
                  ],
                ),
              ),
              const Icon(Icons.favorite_rounded, color: Color(0xFFE11D48), size: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: const Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 14),
            Text(
              message,
              style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// Retain alias for backward compatibility
typedef AdminUserActivityPage = UserActivityPage;
