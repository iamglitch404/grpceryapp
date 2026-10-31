import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cubepod_core/cubepod_core.dart';
import 'package:app/core/widgets/toast.dart';
import 'package:app/features/delivery/data/repositories/delivery_repository.dart';
import 'package:app/features/delivery/presentation/pages/delivery_navigation_page.dart';
import 'package:app/features/delivery/presentation/pages/delivery_shifts_page.dart';
import 'package:app/features/delivery/presentation/pages/delivery_leaderboard_page.dart';
import 'package:app/features/delivery/presentation/pages/delivery_profile_page.dart';

class DeliveryDashboardPage extends StatefulWidget {
  const DeliveryDashboardPage({super.key});

  @override
  State<DeliveryDashboardPage> createState() => _DeliveryDashboardPageState();
}

class _DeliveryDashboardPageState extends State<DeliveryDashboardPage> {
  int _currentTabIndex = 0;

  // Data State
  bool _isLoading = true;
  bool _isOnline = false;
  Map<String, dynamic>? _partner;
  Map<String, dynamic>? _activeShift;
  List<dynamic> _pendingAssignments = [];
  List<dynamic> _activeOrders = [];
  List<dynamic> _completedToday = [];
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
    // Auto-refresh orders every 12 seconds for new admin assignments
    _refreshTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      if (_currentTabIndex == 0 && mounted) {
        _loadOrdersOnly();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    final repo = CubePod.get<DeliveryRepository>();
    final results = await Future.wait([
      repo.fetchProfile(),
      repo.fetchOrders(),
    ]);

    if (mounted) {
      final profileData = results[0];
      final ordersData = results[1];

      setState(() {
        _partner = profileData?['partner'];
        _activeShift = profileData?['active_shift'];
        _isOnline = _partner?['status'] == 'online' || _partner?['status'] == 'on_delivery';

        _pendingAssignments = ordersData?['pending_assignments'] ?? [];
        _activeOrders = ordersData?['active_orders'] ?? [];
        _completedToday = ordersData?['completed_today'] ?? [];
        _isLoading = false;
      });
    }
  }

  Future<void> _loadOrdersOnly() async {
    final ordersData = await CubePod.get<DeliveryRepository>().fetchOrders();
    if (mounted && ordersData != null) {
      setState(() {
        _pendingAssignments = ordersData['pending_assignments'] ?? [];
        _activeOrders = ordersData['active_orders'] ?? [];
        _completedToday = ordersData['completed_today'] ?? [];
      });
    }
  }

  Future<void> _toggleOnlineStatus(bool value) async {
    final newStatus = value ? 'online' : 'offline';
    setState(() => _isOnline = value);

    final success = await CubePod.get<DeliveryRepository>().updateStatus(newStatus);
    if (!success && mounted) {
      setState(() => _isOnline = !value);
      AppToast.error(context, 'Failed to update online status');
    } else {
      if (mounted) {
        AppToast.success(context, value ? 'You are now ONLINE for orders' : 'You are now OFFLINE');
      }
    }
  }

  Future<void> _handleOrderAction(String orderId, String action) async {
    final success = await CubePod.get<DeliveryRepository>().performAction(orderId, action);
    if (success) {
      if (mounted) {
        String msg = 'Action confirmed';
        if (action == 'accept') msg = 'Order accepted! Navigate to pickup';
        if (action == 'decline') msg = 'Order assignment declined';
        if (action == 'arrived_store') msg = 'Arrived at pickup location';
        if (action == 'pick_up') msg = 'Items picked up! Navigate to customer';
        if (action == 'deliver') msg = 'Delivery completed successfully!';
        AppToast.success(context, msg);
        _loadOrdersOnly();
      }
    } else {
      if (mounted) AppToast.error(context, 'Failed to update order action');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: IndexedStack(
        index: _currentTabIndex,
        children: [
          // Tab 0: Deliveries Home
          _buildDeliveriesTab(),
          // Tab 1: Live Navigation Map for Active Order or Hub
          _buildMapShortcutTab(),
          // Tab 2: Working Hours / Shifts
          const DeliveryShiftsPage(),
          // Tab 3: Leaderboard
          const DeliveryLeaderboardPage(),
          // Tab 4: Profile & Reviews
          const DeliveryProfilePage(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentTabIndex,
          onTap: (index) {
            setState(() => _currentTabIndex = index);
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: const Color(0xFF185B3A),
          unselectedItemColor: const Color(0xFF94A3B8),
          selectedLabelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 11),
          unselectedLabelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w500, fontSize: 11),
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.delivery_dining_rounded),
              activeIcon: Icon(Icons.delivery_dining_rounded, size: 26),
              label: 'Deliveries',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.navigation_outlined),
              activeIcon: Icon(Icons.navigation_rounded, size: 26),
              label: 'GPS Map',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.access_time_rounded),
              activeIcon: Icon(Icons.access_time_filled_rounded, size: 26),
              label: 'Hours',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.military_tech_outlined),
              activeIcon: Icon(Icons.military_tech_rounded, size: 26),
              label: 'Leaderboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline_rounded),
              activeIcon: Icon(Icons.person_rounded, size: 26),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TAB 0: DELIVERIES DASHBOARD
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildDeliveriesTab() {
    final name = _partner?['full_name'] ?? 'Rider';
    final completedCount = _completedToday.length;
    final totalEarnings = completedCount * 50; // Rs 50 payout per delivery

    return _isLoading
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF185B3A)))
        : RefreshIndicator(
            onRefresh: _loadDashboardData,
            color: const Color(0xFF185B3A),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: MediaQuery.of(context).padding.top),

                  // Header with Online Toggle
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Namaste, $name 👋', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
                          Text('Dovan Delivery Partner', style: GoogleFonts.outfit(fontSize: 12.5, color: const Color(0xFF64748B))),
                        ],
                      ),
                      // Online / Offline Switch Container
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _isOnline ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: _isOnline ? const Color(0xFF86EFAC) : const Color(0xFFCBD5E1)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: _isOnline ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _isOnline ? 'ONLINE' : 'OFFLINE',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: _isOnline ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Transform.scale(
                              scale: 0.7,
                              child: Switch(
                                value: _isOnline,
                                onChanged: _toggleOnlineStatus,
                                activeThumbColor: const Color(0xFF16A34A),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Working Shift Quick Pill
                  InkWell(
                    onTap: () => setState(() => _currentTabIndex = 2),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: _activeShift != null ? const Color(0xFFF0FDF4) : const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _activeShift != null ? const Color(0xFFBBF7D0) : const Color(0xFFFDE68A),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _activeShift != null ? Icons.timelapse_rounded : Icons.access_time_rounded,
                            size: 18,
                            color: _activeShift != null ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _activeShift != null
                                  ? 'Active Shift in progress • Tap to log hours'
                                  : 'Off Duty • Tap to clock in your shift',
                              style: GoogleFonts.outfit(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: _activeShift != null ? const Color(0xFF16A34A) : const Color(0xFF92400E),
                              ),
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFF64748B)),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Today's KPIs
                  Row(
                    children: [
                      Expanded(child: _buildKpiCard('Delivered Today', '$completedCount', Icons.local_shipping_outlined, const Color(0xFF185B3A))),
                      const SizedBox(width: 12),
                      Expanded(child: _buildKpiCard('Today\'s Payout', 'Rs $totalEarnings', Icons.payments_outlined, const Color(0xFF10B981))),
                      const SizedBox(width: 12),
                      Expanded(child: _buildKpiCard('Rating', '${_partner?['rating'] ?? 5.0} ★', Icons.star_rounded, const Color(0xFFF59E0B))),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // ── SECTION 1: INCOMING ADMIN ASSIGNMENTS ──────────────────
                  if (_pendingAssignments.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Assigned by Admin (${_pendingAssignments.length})',
                              style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                            ),
                          ],
                        ),
                        Text('Action required', style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFFEF4444), fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ..._pendingAssignments.map((ord) => _buildAssignmentCard(ord)),
                    const SizedBox(height: 20),
                  ],

                  // ── SECTION 2: ACTIVE IN-PROGRESS ORDERS ───────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Active Deliveries (${_activeOrders.length})',
                        style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                      ),
                      if (_activeOrders.isNotEmpty)
                        Text('In Progress', style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF16A34A), fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (_activeOrders.isEmpty && _pendingAssignments.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: const BoxDecoration(color: Color(0xFFF1F5F9), shape: BoxShape.circle),
                            child: const Icon(Icons.moped_rounded, size: 32, color: Color(0xFF94A3B8)),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            _isOnline ? 'Waiting for New Orders' : 'You are currently Offline',
                            style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _isOnline
                                ? 'Orders assigned by the Dovan Admin will alert here automatically.'
                                : 'Switch your status to Online to begin receiving delivery dispatches.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF64748B), height: 1.4),
                          ),
                        ],
                      ),
                    )
                  else
                    ..._activeOrders.map((ord) => _buildActiveOrderCard(ord)),

                  const SizedBox(height: 24),

                  // ── SECTION 3: COMPLETED DELIVERIES TODAY ─────────────────
                  if (_completedToday.isNotEmpty) ...[
                    Text('Delivered Today (${_completedToday.length})', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
                    const SizedBox(height: 12),
                    ..._completedToday.map((ord) => _buildCompletedCard(ord)),
                  ],
                ],
              ),
            ),
          );
  }

  // Incoming Order Assignment Card (Accept / Decline)
  Widget _buildAssignmentCard(Map<String, dynamic> ord) {
    final orderId = ord['id']?.toString() ?? '';
    final shortId = orderId.length >= 8 ? orderId.substring(0, 8) : orderId;
    final customerName = ord['customer_name'] ?? 'Customer';
    final address = ord['customer_address'] ?? 'Kathmandu';
    final totalPaise = ord['total_paise'] ?? 0;
    final totalRs = (totalPaise / 100).toStringAsFixed(0);
    final hasGps = ord['has_device_gps'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFDE68A), width: 1.5),
        boxShadow: [
          BoxShadow(color: const Color(0xFFD97706).withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(8)),
                child: Text('NEW DISPATCH #$shortId', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 11.5, color: const Color(0xFF92400E))),
              ),
              Text('Rs $totalRs', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 16, color: const Color(0xFF185B3A))),
            ],
          ),
          const SizedBox(height: 12),
          // Customer & Address
          Row(
            children: [
              const Icon(Icons.person_outline_rounded, size: 16, color: Color(0xFF64748B)),
              const SizedBox(width: 8),
              Text(customerName, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14, color: const Color(0xFF0F172A))),
              if (hasGps) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(4)),
                  child: Row(
                    children: [
                      const Icon(Icons.gps_fixed_rounded, size: 10, color: Color(0xFF16A34A)),
                      const SizedBox(width: 3),
                      Text('GPS VERIFIED', style: GoogleFonts.outfit(fontSize: 9.5, fontWeight: FontWeight.w800, color: const Color(0xFF16A34A))),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on_outlined, size: 16, color: Color(0xFF64748B)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(address, style: GoogleFonts.outfit(fontSize: 12.5, color: const Color(0xFF64748B))),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Buttons Row
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _handleOrderAction(orderId, 'decline'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    foregroundColor: const Color(0xFF64748B),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Decline', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13.5)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: () => _handleOrderAction(orderId, 'accept'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF185B3A),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.check_rounded, color: Colors.white, size: 18),
                  label: Text('Accept Order', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Active In-Progress Delivery Card
  Widget _buildActiveOrderCard(Map<String, dynamic> ord) {
    final orderId = ord['id']?.toString() ?? '';
    final shortId = orderId.length >= 8 ? orderId.substring(0, 8) : orderId;
    final customerName = ord['customer_name'] ?? 'Customer';
    final address = ord['customer_address'] ?? 'Kathmandu';
    final deliveryStatus = ord['delivery_status'] ?? 'accepted';

    String actionBtnText = 'Arrived at Store';
    String nextAction = 'arrived_store';
    IconData actionIcon = Icons.storefront_rounded;

    if (deliveryStatus == 'arrived_store') {
      actionBtnText = 'Confirm Picked Up Items';
      nextAction = 'pick_up';
      actionIcon = Icons.inventory_2_outlined;
    } else if (deliveryStatus == 'picked_up' || deliveryStatus == 'in_transit') {
      actionBtnText = 'Complete Delivery';
      nextAction = 'deliver';
      actionIcon = Icons.check_circle_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF86EFAC), width: 1.5),
        boxShadow: [
          BoxShadow(color: const Color(0xFF16A34A).withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Order Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Order #$shortId', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15, color: const Color(0xFF0F172A))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(8)),
                child: Text(
                  deliveryStatus.toString().replaceAll('_', ' ').toUpperCase(),
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 11, color: const Color(0xFF16A34A)),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          Text(customerName, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14, color: const Color(0xFF334155))),
          const SizedBox(height: 2),
          Text(address, style: GoogleFonts.outfit(fontSize: 12.5, color: const Color(0xFF64748B))),

          const SizedBox(height: 16),

          // Primary Navigation Button (Direct OSRM / Google Maps Navigation)
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DeliveryNavigationPage(
                      order: ord,
                      onOrderUpdated: _loadOrdersOnly,
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              icon: const Icon(Icons.navigation_rounded, color: Color(0xFF10B981), size: 18),
              label: Text('Open Live GPS Navigation Map', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13.5)),
            ),
          ),

          const SizedBox(height: 10),

          // Secondary Action Step Button
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              onPressed: () => _handleOrderAction(orderId, nextAction),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF185B3A),
                side: const BorderSide(color: Color(0xFF185B3A)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: Icon(actionIcon, size: 16),
              label: Text(actionBtnText, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }

  // Completed Delivery Card
  Widget _buildCompletedCard(Map<String, dynamic> ord) {
    final orderId = ord['id']?.toString() ?? '';
    final shortId = orderId.length >= 8 ? orderId.substring(0, 8) : orderId;
    final customerName = ord['customer_name'] ?? 'Customer';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Order #$shortId', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13.5, color: const Color(0xFF0F172A))),
                Text(customerName, style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF64748B))),
              ],
            ),
          ),
          Text('+Rs 50', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 13.5, color: const Color(0xFF16A34A))),
        ],
      ),
    );
  }

  // KPI Metric Card
  Widget _buildKpiCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(value, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
          const SizedBox(height: 2),
          Text(label, style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF64748B), fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  // Map Shortcut Tab (If active order exists, launch GPS navigation directly, else show Hub map)
  Widget _buildMapShortcutTab() {
    if (_activeOrders.isNotEmpty) {
      return DeliveryNavigationPage(order: _activeOrders.first, onOrderUpdated: _loadOrdersOnly);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: Text('GPS Navigation', style: GoogleFonts.outfit(color: const Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(color: Color(0xFFDCFCE7), shape: BoxShape.circle),
                child: const Icon(Icons.navigation_rounded, color: Color(0xFF16A34A), size: 40),
              ),
              const SizedBox(height: 16),
              Text('No Active Delivery to Navigate', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
              const SizedBox(height: 8),
              Text(
                'Accept an order dispatch from the Deliveries tab to launch real-time GPS turn-by-turn road navigation.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF64748B), height: 1.4),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => setState(() => _currentTabIndex = 0),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF185B3A),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 16),
                label: Text('View Deliveries', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
