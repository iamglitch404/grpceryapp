import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:app/features/admin/orders/providers/adminOrderProviders.dart';
import 'package:app/features/admin/orders/screens/orderDetailsPage.dart';

class OrdersPage extends ConsumerStatefulWidget {
  const OrdersPage({super.key});

  @override
  ConsumerState<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends ConsumerState<OrdersPage> with SingleTickerProviderStateMixin {
  late final AnimationController _skeletonController;
  late final Animation<Color?> _skeletonAnimation;

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
  }

  @override
  void dispose() {
    _skeletonController.dispose();
    super.dispose();
  }

  Future<void> _updateOrderStatus(dynamic orderId, String newStatus) async {
    HapticFeedback.mediumImpact();
    try {
      final success = await ref.read(adminOrdersNotifierProvider.notifier).updateOrderStatus(orderId, newStatus);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order status updated to $newStatus', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error updating order status: $e');
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'cancelled':
      case 'canceled':
        return const Color(0xFFE11D48);
      case 'pending':
        return const Color(0xFFD97706);
      case 'packed':
        return const Color(0xFF2563EB);
      case 'on the way':
      case 'out for delivery':
        return const Color(0xFF7C3AED);
      case 'delivered':
      default:
        return const Color(0xFF16A34A);
    }
  }

  Color _getStatusBg(String status) {
    switch (status.toLowerCase()) {
      case 'cancelled':
      case 'canceled':
        return const Color(0xFFFEE2E2);
      case 'pending':
        return const Color(0xFFFEF3C7);
      case 'packed':
        return const Color(0xFFDBEAFE);
      case 'on the way':
      case 'out for delivery':
        return const Color(0xFFEDE9FE);
      case 'delivered':
      default:
        return const Color(0xFFDCFCE7);
    }
  }

  List<dynamic> _filterOrders(
    List<dynamic> orders,
    String selectedStatus,
    String searchQuery,
    String selectedSort,
  ) {
    List<dynamic> list = List.from(orders);

    // Filter by status tab
    if (selectedStatus != 'All') {
      list = list.where((o) {
        final s = (o['status'] ?? '').toString().toLowerCase();
        return s == selectedStatus.toLowerCase();
      }).toList();
    }

    // Filter by search query (Order ID, customer name, phone, destination address)
    if (searchQuery.trim().isNotEmpty) {
      final q = searchQuery.trim().toLowerCase();
      list = list.where((o) {
        final id = (o['id'] ?? '').toString().toLowerCase();
        final addr = (o['destination_address'] ?? o['address_snapshot']?['address'] ?? '').toString().toLowerCase();
        final user = o['account'] ?? o['user'] ?? o['users'] ?? {};
        final name = (user['name'] ?? user['full_name'] ?? o['customer_name'] ?? '').toString().toLowerCase();
        final phone = (user['phone'] ?? o['phone'] ?? '').toString().toLowerCase();
        return id.contains(q) || addr.contains(q) || name.contains(q) || phone.contains(q);
      }).toList();
    }

    // Sort orders
    if (selectedSort == 'Newest') {
      list.sort((a, b) {
        final dtA = DateTime.tryParse(a['created_at']?.toString() ?? '') ?? DateTime(1970);
        final dtB = DateTime.tryParse(b['created_at']?.toString() ?? '') ?? DateTime(1970);
        return dtB.compareTo(dtA);
      });
    } else if (selectedSort == 'Oldest') {
      list.sort((a, b) {
        final dtA = DateTime.tryParse(a['created_at']?.toString() ?? '') ?? DateTime(1970);
        final dtB = DateTime.tryParse(b['created_at']?.toString() ?? '') ?? DateTime(1970);
        return dtA.compareTo(dtB);
      });
    } else if (selectedSort == 'Highest') {
      list.sort((a, b) {
        final amtA = (a['total_paise'] ?? a['total_amount_paise'] ?? ((a['total_amount'] ?? 0) * 100) as num).toDouble();
        final amtB = (b['total_paise'] ?? b['total_amount_paise'] ?? ((b['total_amount'] ?? 0) * 100) as num).toDouble();
        return amtB.compareTo(amtA);
      });
    }

    return list;
  }

  @override
  Widget build(BuildContext context) {
    final ordersState = ref.watch(adminOrdersNotifierProvider);
    final selectedStatus = ref.watch(adminOrderStatusFilterProvider);
    final searchQuery = ref.watch(adminOrderSearchQueryProvider);
    final selectedSort = ref.watch(adminOrderSortProvider);
    final filtered = _filterOrders(ordersState.orders, selectedStatus, searchQuery, selectedSort);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A), size: 19),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        titleSpacing: Navigator.canPop(context) ? 0 : 16,
        title: Row(
          children: [
            Text(
              'Manage Orders',
              style: GoogleFonts.outfit(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${ordersState.orders.length}',
                style: GoogleFonts.outfit(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF15803D),
                ),
              ),
            ),
          ],
        ),

      ),
      body: Column(
        children: [
          // Search & Sort Header (Matching ProductsPage)
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        const Icon(Icons.search_rounded, color: Color(0xFF94A3B8), size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            onChanged: (val) => ref.read(adminOrderSearchQueryProvider.notifier).state = val,
                            style: GoogleFonts.outfit(fontSize: 13.5, color: const Color(0xFF0F172A)),
                            decoration: InputDecoration(
                              hintText: 'Search by Order ID, customer, address...',
                              hintStyle: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF94A3B8)),
                              border: InputBorder.none,
                              isDense: true,
                            ),
                          ),
                        ),
                        if (searchQuery.isNotEmpty)
                          GestureDetector(
                            onTap: () => ref.read(adminOrderSearchQueryProvider.notifier).state = '',
                            child: const Icon(Icons.close_rounded, color: Color(0xFF64748B), size: 18),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Sort Dropdown (Newest default)
                Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedSort,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF64748B)),
                      style: GoogleFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
                      items: const [
                        DropdownMenuItem(value: 'Newest', child: Text('Newest')),
                        DropdownMenuItem(value: 'Oldest', child: Text('Oldest')),
                        DropdownMenuItem(value: 'Highest', child: Text('Highest')),
                      ],
                      onChanged: (val) {
                        if (val != null) ref.read(adminOrderSortProvider.notifier).state = val;
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // Filter Tabs
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SizedBox(
              height: 34,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _buildStatusChip('All', selectedStatus),
                  _buildStatusChip('Pending', selectedStatus),
                  _buildStatusChip('Packed', selectedStatus),
                  _buildStatusChip('On the way', selectedStatus),
                  _buildStatusChip('Delivered', selectedStatus),
                  _buildStatusChip('Cancelled', selectedStatus),
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // Orders List
          Expanded(
            child: ordersState.isLoading
                ? _buildSkeletonList()
                : filtered.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(18),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFDCFCE7),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.local_shipping_rounded,
                                  size: 42,
                                  color: Color(0xFF15803D),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                searchQuery.isNotEmpty
                                    ? 'No orders matching "$searchQuery"'
                                    : (selectedStatus == 'All' ? 'No Orders Yet' : 'No $selectedStatus Orders'),
                                style: GoogleFonts.outfit(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                searchQuery.isNotEmpty
                                    ? 'Try checking for typos or clearing your search filter.'
                                    : (selectedStatus == 'All'
                                        ? 'Customer store orders and delivery dispatches will appear here in real-time.'
                                        : 'There are currently no customer orders under the "$selectedStatus" status filter.'),
                                textAlign: TextAlign.center,
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  color: const Color(0xFF64748B),
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        color: const Color(0xFF185B3A),
                        onRefresh: () => ref.read(adminOrdersNotifierProvider.notifier).fetchOrders(),
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(18, 14, 18, 40),
                          itemCount: filtered.length,
                          separatorBuilder: (_, index) => const SizedBox(height: 14),
                          itemBuilder: (context, index) {
                            final order = filtered[index];
                            final id = order['id']?.toString().substring(0, 8).toUpperCase() ?? 'ORD';
                            final status = order['status']?.toString() ?? 'Pending';
                            final totalPaise = order['total_paise'] ?? order['total_amount_paise'] ?? ((order['total_amount'] ?? 0) * 100);
                            final total = (totalPaise / 100).round();
                            final paymentMethod = order['payment_method'] ?? 'Cash on Delivery';
                            final user = order['users'] is Map ? order['users'] : null;
                            final customerName = user?['full_name'] ?? user?['name'] ?? order['customer_name'] ?? 'Customer';
                            final phone = user?['phone'] ?? order['phone'] ?? '';
                            final items = (order['order_items'] is List)
                                ? (order['order_items'] as List)
                                : ((order['items'] is List) ? (order['items'] as List) : []);

                            final discrepancyKm = (order['location_discrepancy_km'] as num?)?.toDouble() ?? 0.0;
                            final isFraudFlagged = order['is_fraud_flagged'] == true || discrepancyKm > 15;

                            final snapshot = order['address_snapshot'] is Map ? order['address_snapshot'] as Map : null;
                            final destAddress = order['destination_address']?.toString() ??
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
                                  BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2)),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => OrderDetailsPage(
                                          order: order,
                                          onStatusUpdate: (id, newStatus) => _updateOrderStatus(id, newStatus),
                                        ),
                                      ),
                                    );
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Header: Order ID, Status, and Click Affordance
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              children: [
                                                const Icon(Icons.receipt_long_rounded, color: Color(0xFF185B3A), size: 18),
                                                const SizedBox(width: 6),
                                                Text(
                                                  'Order #$id',
                                                  style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                                                ),
                                              ],
                                            ),
                                            Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color: _getStatusBg(status),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    status,
                                                    style: GoogleFonts.outfit(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w800,
                                                      color: _getStatusColor(status),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Color(0xFF94A3B8)),
                                              ],
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),

                                        // Customer Info
                                        Row(
                                          children: [
                                            const Icon(Icons.person_outline_rounded, size: 15, color: Color(0xFF64748B)),
                                            const SizedBox(width: 4),
                                            Text(customerName, style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF334155))),
                                            if (phone.isNotEmpty) ...[
                                              const SizedBox(width: 8),
                                              Text('•  $phone', style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF64748B))),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 5),

                                        // Destination Address (Clean 1-liner)
                                        Row(
                                          children: [
                                            const Icon(Icons.location_on_outlined, size: 15, color: Color(0xFFE11D48)),
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

                                        // Discrepancy & Verification Minimal Badge
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: isFraudFlagged ? const Color(0xFFFEE2E8) : const Color(0xFFDCFCE7),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    isFraudFlagged ? Icons.warning_amber_rounded : Icons.shield_rounded,
                                                    size: 13,
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
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF1F5F9),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                '${items.length} item(s)',
                                                style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        const Divider(height: 1, color: Color(0xFFF1F5F9)),
                                        const SizedBox(height: 10),

                                        // Bottom Row: Total Amount & Status Quick Action Buttons
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text('Total: ₹$total', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w800, color: const Color(0xFF185B3A))),
                                                Text(paymentMethod, style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF64748B))),
                                              ],
                                            ),

                                            // Action Buttons
                                            Row(
                                              children: [
                                                if (status.toLowerCase() == 'pending')
                                                  _buildTransitionBtn('Mark Packed', const Color(0xFF2563EB), () => _updateOrderStatus(order['id'], 'Packed')),
                                                if (status.toLowerCase() == 'packed')
                                                  _buildTransitionBtn('Dispatch', const Color(0xFF7C3AED), () => _updateOrderStatus(order['id'], 'On the way')),
                                                if (status.toLowerCase() == 'on the way')
                                                  _buildTransitionBtn('Mark Delivered', const Color(0xFF16A34A), () => _updateOrderStatus(order['id'], 'Delivered')),
                                                if (status.toLowerCase() != 'delivered' && status.toLowerCase() != 'cancelled') ...[
                                                  const SizedBox(width: 6),
                                                  OutlinedButton(
                                                    style: OutlinedButton.styleFrom(
                                                      foregroundColor: const Color(0xFFE11D48),
                                                      side: const BorderSide(color: Color(0xFFFDA4AF)),
                                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                                      minimumSize: Size.zero,
                                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                    ),
                                                    onPressed: () => _updateOrderStatus(order['id'], 'Cancelled'),
                                                    child: Text('Cancel', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold)),
                                                  ),
                                                ],
                                              ],
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
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransitionBtn(String label, Color color, VoidCallback onTap) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      onPressed: onTap,
      child: Text(
        label,
        style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
      ),
    );
  }

  Widget _buildStatusChip(String label, String selectedStatus) {
    final isSelected = selectedStatus == label;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        ref.read(adminOrderStatusFilterProvider.notifier).state = label;
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF185B3A) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? const Color(0xFF185B3A) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              color: isSelected ? Colors.white : const Color(0xFF64748B),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSkeletonList() {
    return AnimatedBuilder(
      animation: _skeletonAnimation,
      builder: (context, _) {
        final shimmer = _skeletonAnimation.value ?? const Color(0xFFF1F5F9);
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 40),
          itemCount: 4,
          physics: const NeverScrollableScrollPhysics(),
          separatorBuilder: (_, _) => const SizedBox(height: 14),
          itemBuilder: (context, index) {
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
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: shimmer,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 100,
                            height: 16,
                            decoration: BoxDecoration(
                              color: shimmer,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                      Container(
                        width: 70,
                        height: 22,
                        decoration: BoxDecoration(
                          color: shimmer,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: shimmer,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 120,
                            height: 13,
                            decoration: BoxDecoration(
                              color: shimmer,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 5),
                          Container(
                            width: 80,
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
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(width: 16, height: 16, decoration: BoxDecoration(color: shimmer, shape: BoxShape.circle)),
                            const SizedBox(width: 8),
                            Container(width: 130, height: 11, decoration: BoxDecoration(color: shimmer, borderRadius: BorderRadius.circular(3))),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Container(width: 16, height: 16, decoration: BoxDecoration(color: shimmer, shape: BoxShape.circle)),
                            const SizedBox(width: 8),
                            Container(width: 150, height: 11, decoration: BoxDecoration(color: shimmer, borderRadius: BorderRadius.circular(3))),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        width: 90,
                        height: 18,
                        decoration: BoxDecoration(
                          color: shimmer,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      Container(
                        width: 95,
                        height: 28,
                        decoration: BoxDecoration(
                          color: shimmer,
                          borderRadius: BorderRadius.circular(8),
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
}

// Retain alias for backward compatibility
typedef ManageOrdersPage = OrdersPage;
