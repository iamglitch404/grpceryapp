import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:cubepod_core/cubepod_core.dart';
import 'package:app/core/widgets/toast.dart';
import 'package:app/features/admin/presentation/widgets/order_map_widget.dart';
import 'package:app/features/admin/presentation/pages/order_navigation_page.dart';
import 'package:app/features/admin/data/services/live_location_service.dart';
import 'package:app/features/delivery/data/repositories/delivery_repository.dart';

class OrderDetailsPage extends StatefulWidget {
  final Map<String, dynamic> order;
  final Function(dynamic orderId, String newStatus)? onStatusUpdate;

  const OrderDetailsPage({
    super.key,
    required this.order,
    this.onStatusUpdate,
  });

  @override
  State<OrderDetailsPage> createState() => _OrderDetailsPageState();
}

class _OrderDetailsPageState extends State<OrderDetailsPage> {
  late Map<String, dynamic> _order;
  late String _currentStatus;
  Map<String, dynamic>? _assignedPartner;

  LatLng _adminPoint = LiveLocationService.defaultPoint;
  String _adminAddress = LiveLocationService.defaultAddress;
  bool _isLocatingAdmin = false;

  @override
  void initState() {
    super.initState();
    _order = Map<String, dynamic>.from(widget.order);
    _currentStatus = (_order['status'] ?? 'Pending').toString();
    _assignedPartner = _order['delivery_partner'] is Map<String, dynamic>
        ? _order['delivery_partner']
        : (_order['delivery_assignment'] is Map && _order['delivery_assignment']['delivery_partner'] is Map
            ? Map<String, dynamic>.from(_order['delivery_assignment']['delivery_partner'])
            : null);
    _fetchAdminLocation();
  }


  Future<void> _fetchAdminLocation() async {
    if (mounted) setState(() => _isLocatingAdmin = true);
    try {
      final loc = await LiveLocationService.getLiveLocation();
      if (mounted) {
        setState(() {
          _adminPoint = loc.point;
          _adminAddress = loc.address;
          _isLocatingAdmin = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _adminPoint = LiveLocationService.defaultPoint;
          _adminAddress = LiveLocationService.defaultAddress;
          _isLocatingAdmin = false;
        });
      }
    }
  }

  double? _toDouble(dynamic val) {
    if (val == null) return null;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString());
  }

  double _calcDistanceKm(LatLng a, LatLng b) {
    const distance = Distance();
    return distance.as(LengthUnit.Meter, a, b) / 1000.0;
  }

  String _formatDateTime(dynamic dt) {
    if (dt == null) return 'N/A';
    try {
      final parsed = DateTime.parse(dt.toString()).toLocal();
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final month = months[parsed.month - 1];
      final day = parsed.day.toString().padLeft(2, '0');
      final year = parsed.year;
      final hour = parsed.hour > 12 ? parsed.hour - 12 : (parsed.hour == 0 ? 12 : parsed.hour);
      final ampm = parsed.hour >= 12 ? 'PM' : 'AM';
      final min = parsed.minute.toString().padLeft(2, '0');
      return '$day $month $year, $hour:$min $ampm';
    } catch (_) {
      return dt.toString();
    }
  }

  Color _getStatusBg(String status) {
    switch (status.toLowerCase()) {
      case 'delivered':
        return const Color(0xFFDCFCE7);
      case 'on the way':
      case 'out for delivery':
        return const Color(0xFFF3E8FF);
      case 'packed':
      case 'processing':
        return const Color(0xFFDBEAFE);
      case 'cancelled':
        return const Color(0xFFFEE2E2);
      default:
        return const Color(0xFFFEF3C7);
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'delivered':
        return const Color(0xFF15803D);
      case 'on the way':
      case 'out for delivery':
        return const Color(0xFF7E22CE);
      case 'packed':
      case 'processing':
        return const Color(0xFF1D4ED8);
      case 'cancelled':
        return const Color(0xFFB91C1C);
      default:
        return const Color(0xFFB45309);
    }
  }

  void _updateStatus(String newStatus) {
    setState(() {
      _currentStatus = newStatus;
      _order['status'] = newStatus;
    });
    if (widget.onStatusUpdate != null) {
      widget.onStatusUpdate!(_order['id'], newStatus);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Order status updated to $newStatus'),
        backgroundColor: const Color(0xFF185B3A),
        duration: const Duration(seconds: 2),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final orderId = (_order['id'] ?? '').toString();
    final total = _order['total_amount'] ?? _order['total'] ?? '0';
    final user = _order['account'] ?? _order['user'] ?? {};
    final customerName = user['full_name'] ?? user['name'] ?? _order['customer_name'] ?? 'Customer';
    final customerPhone = user['phone'] ?? _order['phone'] ?? '';
    final customerEmail = user['email'] ?? _order['email'] ?? '';
    final paymentMethod = _order['payment_method'] ?? 'Cash on Delivery';
    final paymentStatus = _order['payment_status'] ?? 'pending';
    final deliverySlot = _order['delivery_slot'] ?? 'Standard Delivery';
    final createdAt = _formatDateTime(_order['created_at']);
    final items = (_order['order_items'] is List)
        ? (_order['order_items'] as List)
        : ((_order['items'] is List) ? (_order['items'] as List) : []);

    // 1. Orderer User Device Location
    final double? deviceLat = _toDouble(_order['device_latitude']);
    final double? deviceLng = _toDouble(_order['device_longitude']);
    final LatLng? devicePoint =
        (deviceLat != null && deviceLng != null) ? LatLng(deviceLat, deviceLng) : null;
    final String? deviceAddress = _order['device_location_address']?.toString();

    // 2. Delivery Destination Location
    final snapshot = _order['address_snapshot'] is Map ? _order['address_snapshot'] as Map : null;
    final double? destLat = _toDouble(_order['destination_latitude']) ??
        (snapshot != null ? _toDouble(snapshot['latitude']) : null);
    final double? destLng = _toDouble(_order['destination_longitude']) ??
        (snapshot != null ? _toDouble(snapshot['longitude']) : null);
    final LatLng? destPoint =
        (destLat != null && destLng != null) ? LatLng(destLat, destLng) : null;

    final String destAddress = _order['destination_address']?.toString() ??
        (snapshot != null
            ? (snapshot['address'] ?? snapshot['street'] ?? snapshot['details'])?.toString()
            : null) ??
        'Delivery Destination';

    // 3. Discrepancy & Fraud Analysis
    double discrepancyKm = (_order['location_discrepancy_km'] as num?)?.toDouble() ?? 0.0;
    if (discrepancyKm == 0 && devicePoint != null && destPoint != null) {
      discrepancyKm = _calcDistanceKm(devicePoint, destPoint);
    }
    final bool isFraudFlagged = _order['is_fraud_flagged'] == true || discrepancyKm > 15.0;

    // Delivery Leg Distance (Admin Hub -> Destination)
    final double deliveryDistanceKm = destPoint != null
        ? _calcDistanceKm(_adminPoint, destPoint)
        : (devicePoint != null ? _calcDistanceKm(_adminPoint, devicePoint) : 0.0);


    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Order #${orderId.length > 8 ? orderId.substring(0, 8) : orderId}',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 18, color: const Color(0xFF0F172A)),
            ),
            Text(
              createdAt,
              style: GoogleFonts.outfit(fontSize: 11.5, color: const Color(0xFF64748B)),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1E293B), size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _getStatusBg(_currentStatus),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(
              _currentStatus.toUpperCase(),
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: _getStatusColor(_currentStatus),
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFE2E8F0)),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Progression Banner & Quick Actions
            _buildStatusActionCard(),
            const SizedBox(height: 16),

            // Customer & Delivery Address Card
            _buildCustomerCard(customerName, customerPhone, customerEmail, destAddress),
            const SizedBox(height: 16),

            // InDrive 3-Location Route & Fraud Verification Section
            _buildLocationAndMapCard(
              devicePoint: devicePoint,
              deviceAddress: deviceAddress,
              destPoint: destPoint,
              destAddress: destAddress,
              discrepancyKm: discrepancyKm,
              deliveryDistanceKm: deliveryDistanceKm,
              isFraudFlagged: isFraudFlagged,
            ),
            const SizedBox(height: 16),

            // Order Line Items Card
            _buildItemsCard(items),
            const SizedBox(height: 16),

            // Payment & Billing Summary Card
            _buildPaymentCard(total, paymentMethod, paymentStatus, deliverySlot),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusActionCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ORDER STATUS PROGRESSION',
                style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF64748B), letterSpacing: 0.5),
              ),
              Text(
                _currentStatus,
                style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: _getStatusColor(_currentStatus)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Status Stepper Pills
          Row(
            children: [
              _buildStepNode('Pending', 0),
              _buildStepLine(0),
              _buildStepNode('Packed', 1),
              _buildStepLine(1),
              _buildStepNode('On the way', 2),
              _buildStepLine(2),
              _buildStepNode('Delivered', 3),
            ],
          ),
          const SizedBox(height: 16),

          // Action Buttons
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildActionBtn(
                _assignedPartner != null ? 'Reassign Partner' : 'Assign Delivery Partner',
                const Color(0xFFD97706),
                Icons.delivery_dining_rounded,
                _showAssignDeliveryDialog,
              ),
              if (_currentStatus.toLowerCase() == 'pending')
                _buildActionBtn('Mark as Packed', const Color(0xFF2563EB), Icons.inventory_2_outlined, () => _updateStatus('Packed')),
              if (_currentStatus.toLowerCase() == 'packed')
                _buildActionBtn('Dispatch (On the way)', const Color(0xFF7C3AED), Icons.local_shipping_outlined, () => _updateStatus('On the way')),
              if (_currentStatus.toLowerCase() == 'on the way')
                _buildActionBtn('Mark Delivered', const Color(0xFF16A34A), Icons.check_circle_outline_rounded, () => _updateStatus('Delivered')),
              if (_currentStatus.toLowerCase() != 'delivered' && _currentStatus.toLowerCase() != 'cancelled')
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFE11D48),
                    side: const BorderSide(color: Color(0xFFFDA4AF)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _updateStatus('Cancelled'),
                  icon: const Icon(Icons.cancel_outlined, size: 15),
                  label: Text('Cancel Order', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          if (_assignedPartner != null) ...[
            const SizedBox(height: 14),
            _buildAssignedPartnerTile(),
          ],
        ],
      ),
    );
  }

  int _getStatusStepIndex(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 0;
      case 'packed':
        return 1;
      case 'on the way':
      case 'out for delivery':
        return 2;
      case 'delivered':
        return 3;
      default:
        return -1;
    }
  }

  Widget _buildStepNode(String label, int index) {
    final currentIdx = _getStatusStepIndex(_currentStatus);
    final isDone = currentIdx >= index;
    final isCurrent = currentIdx == index;

    return Column(
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: isDone ? const Color(0xFF185B3A) : const Color(0xFFE2E8F0),
            shape: BoxShape.circle,
            border: isCurrent ? Border.all(color: const Color(0xFF4ADE80), width: 2) : null,
          ),
          child: Icon(isDone ? Icons.check : Icons.circle, size: 12, color: isDone ? Colors.white : const Color(0xFF94A3B8)),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 9.5,
            fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
            color: isDone ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
          ),
        ),
      ],
    );
  }

  Widget _buildStepLine(int index) {
    final currentIdx = _getStatusStepIndex(_currentStatus);
    final isDone = currentIdx > index;
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 16),
        color: isDone ? const Color(0xFF185B3A) : const Color(0xFFE2E8F0),
      ),
    );
  }

  Widget _buildActionBtn(String label, Color color, IconData icon, VoidCallback onTap) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onPressed: onTap,
      icon: Icon(icon, size: 15),
      label: Text(label, style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildCustomerCard(String name, String phone, String email, String address) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'CUSTOMER & DELIVERY ADDRESS',
                style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF64748B), letterSpacing: 0.5),
              ),
              if (phone.isNotEmpty)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => launchPhoneCall(phone),
                  icon: const Icon(Icons.phone_rounded, size: 12),
                  label: Text('Call $phone', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: const Color(0xFF185B3A).withValues(alpha: 0.1),
                child: const Icon(Icons.person_outline_rounded, color: Color(0xFF185B3A), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
                    if (email.isNotEmpty) Text(email, style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF64748B))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on_rounded, color: Color(0xFFE11D48), size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Deliver to:', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF64748B))),
                    Text(address, style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF334155))),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLocationAndMapCard({
    required LatLng? devicePoint,
    required String? deviceAddress,
    required LatLng? destPoint,
    required String destAddress,
    required double discrepancyKm,
    required double deliveryDistanceKm,
    required bool isFraudFlagged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isFraudFlagged ? const Color(0xFFFFF1F2) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isFraudFlagged ? const Color(0xFFFDA4AF) : const Color(0xFFE2E8F0),
          width: isFraudFlagged ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Fraud & Verification Status
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '3-LOCATION ROUTE & FRAUD CHECK',
                      style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF64748B), letterSpacing: 0.5),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isFraudFlagged ? const Color(0xFFFEE2E2) : const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isFraudFlagged ? 'HIGH RISK' : 'VERIFIED',
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: isFraudFlagged ? const Color(0xFFB91C1C) : const Color(0xFF15803D),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      isFraudFlagged ? Icons.warning_amber_rounded : Icons.shield_rounded,
                      size: 16,
                      color: isFraudFlagged ? const Color(0xFFE11D48) : const Color(0xFF16A34A),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        isFraudFlagged
                            ? '🚨 High Discrepancy (${discrepancyKm.toStringAsFixed(2)} km) • Device GPS far from delivery point'
                            : (discrepancyKm > 0
                                ? '🛡️ Device GPS verified • Placed ${discrepancyKm.toStringAsFixed(2)} km from destination'
                                : '🛡️ Device GPS and Delivery Address match'),
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isFraudFlagged ? const Color(0xFFE11D48) : const Color(0xFF16A34A),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // InDrive 3-Stop Stepper
                _buildInDriveStop(
                  'A',
                  const Color(0xFF16A34A),
                  'Admin Live Location (Origin)',
                  _adminAddress,
                  '${_adminPoint.latitude.toStringAsFixed(4)}, ${_adminPoint.longitude.toStringAsFixed(4)}',
                  isLive: true,
                  isLoading: _isLocatingAdmin,
                  onRefresh: _fetchAdminLocation,
                ),
                _buildInDriveStepDivider('🚗 ${deliveryDistanceKm.toStringAsFixed(1)} km delivery leg'),
                _buildInDriveStop(
                  'B',
                  const Color(0xFF2563EB),
                  'Orderer User GPS (Captured at Checkout)',
                  deviceAddress ?? (devicePoint != null ? 'GPS Recorded' : 'GPS Not Captured'),
                  devicePoint != null
                      ? '${devicePoint.latitude.toStringAsFixed(4)}, ${devicePoint.longitude.toStringAsFixed(4)}'
                      : 'No GPS data',
                ),
                _buildInDriveStepDivider('📍 ${discrepancyKm.toStringAsFixed(1)} km to drop-off'),
                _buildInDriveStop(
                  'C',
                  const Color(0xFFE11D48),
                  'Deliver To (Destination Address)',
                  destAddress,
                  destPoint != null
                      ? '${destPoint.latitude.toStringAsFixed(4)}, ${destPoint.longitude.toStringAsFixed(4)}'
                      : 'Address only',
                ),
                const SizedBox(height: 14),

                const SizedBox(height: 16),

                // Navigation Actions: "View Full Map & Live Navigation" + "Google Maps"
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF185B3A),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => OrderNavigationPage(
                                order: _order,
                                adminPoint: _adminPoint,
                                adminAddress: _adminAddress,
                                devicePoint: devicePoint,
                                deviceAddress: deviceAddress,
                                destPoint: destPoint,
                                destAddress: destAddress,
                                discrepancyKm: discrepancyKm,
                                deliveryDistanceKm: deliveryDistanceKm,
                                isFraudFlagged: isFraudFlagged,
                                onStatusUpdate: (id, newStatus) {
                                  setState(() => _currentStatus = newStatus);
                                  widget.onStatusUpdate?.call(id, newStatus);
                                },
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.navigation_rounded, size: 18),
                        label: Text(
                          'View Map & Navigation',
                          style: GoogleFonts.outfit(fontSize: 13.5, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF0F172A),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          if (destPoint != null) {
                            launchGoogleMapsNavigation(
                              origin: _adminPoint,
                              destination: destPoint,
                              waypoint: devicePoint,
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Destination coordinates unavailable')),
                            );
                          }
                        },
                        icon: const Icon(Icons.open_in_new_rounded, size: 16, color: Color(0xFF16A34A)),
                        label: Text('Google Maps', style: GoogleFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInDriveStop(
    String label,
    Color color,
    String title,
    String subtitle,
    String coords, {
    bool isLive = false,
    bool isLoading = false,
    VoidCallback? onRefresh,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Text(label, style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(title, style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF475569))),
                  if (isLive) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFF86EFAC), width: 0.8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 5,
                            height: 5,
                            decoration: const BoxDecoration(
                              color: Color(0xFF16A34A),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            'LIVE GPS',
                            style: GoogleFonts.outfit(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF15803D),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (onRefresh != null) ...[
                    const Spacer(),
                    InkWell(
                      onTap: isLoading ? null : onRefresh,
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: isLoading
                            ? const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFF16A34A)),
                              )
                            : const Icon(Icons.refresh_rounded, size: 14, color: Color(0xFF16A34A)),
                      ),
                    ),
                  ],
                ],
              ),
              Text(subtitle, style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A))),
              Text(coords, style: GoogleFonts.outfit(fontSize: 10, color: const Color(0xFF94A3B8))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInDriveStepDivider(String label) {
    return Container(
      margin: const EdgeInsets.only(left: 10, top: 2, bottom: 2),
      padding: const EdgeInsets.only(left: 16),
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: Color(0xFFCBD5E1), width: 1.5)),
      ),
      child: Text(label, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
    );
  }

  Widget _buildItemsCard(List<dynamic> items) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ORDER ITEMS (${items.length})',
                style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF64748B), letterSpacing: 0.5),
              ),
              const Icon(Icons.shopping_bag_outlined, size: 16, color: Color(0xFF64748B)),
            ],
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            Text('No item details attached to this order', style: GoogleFonts.outfit(fontSize: 12.5, color: const Color(0xFF94A3B8)))
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (_, _) => const Divider(height: 16, color: Color(0xFFF1F5F9)),
              itemBuilder: (ctx, idx) {
                final item = items[idx];
                final title = item['title_snapshot'] ?? item['title'] ?? item['name'] ?? item['products']?['title'] ?? 'Product';
                final qty = item['quantity'] ?? item['qty'] ?? 1;
                final unit = item['unit_snapshot'] ?? item['unit'] ?? '';
                final pricePaise = item['price_paise_snapshot'] ?? item['price_paise'] ?? 0;
                final price = pricePaise > 0 ? (pricePaise / 100).toStringAsFixed(0) : (item['price'] ?? '0').toString();
                final img = item['image_url_snapshot'] ?? item['image_url'] ?? item['products']?['image_url'];

                return Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 44,
                        height: 44,
                        color: const Color(0xFFF1F5F9),
                        child: img != null && img.toString().isNotEmpty
                            ? Image.network(img.toString(), fit: BoxFit.cover, errorBuilder: (_, _, _) => const Icon(Icons.image_outlined, color: Color(0xFF94A3B8)))
                            : const Icon(Icons.shopping_bag_outlined, color: Color(0xFF94A3B8)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: GoogleFonts.outfit(fontSize: 13.5, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A))),
                          if (unit.isNotEmpty) Text(unit, style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF94A3B8))),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('₹$price', style: GoogleFonts.outfit(fontSize: 13.5, fontWeight: FontWeight.bold, color: const Color(0xFF185B3A))),
                        Text('Qty: $qty', style: GoogleFonts.outfit(fontSize: 11.5, color: const Color(0xFF64748B))),
                      ],
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildPaymentCard(dynamic total, String paymentMethod, String paymentStatus, String deliverySlot) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PAYMENT & BILLING SUMMARY',
            style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF64748B), letterSpacing: 0.5),
          ),
          const SizedBox(height: 12),
          _buildBillRow('Payment Method', paymentMethod),
          _buildBillRow('Payment Status', paymentStatus.toUpperCase()),
          _buildBillRow('Delivery Slot', deliverySlot),
          const Divider(height: 16, color: Color(0xFFF1F5F9)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Grand Total', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
              Text('₹$total', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800, color: const Color(0xFF185B3A))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBillRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.outfit(fontSize: 12.5, color: const Color(0xFF64748B))),
          Text(value, style: GoogleFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.w600, color: const Color(0xFF334155))),
        ],
      ),
    );
  }

  Widget _buildAssignedPartnerTile() {
    if (_assignedPartner == null) return const SizedBox.shrink();
    final name = _assignedPartner!['full_name'] ?? 'Delivery Partner';
    final phone = _assignedPartner!['phone'] ?? '';
    final vehicle = '${_assignedPartner!['vehicle_type'] ?? 'Bike'} • ${_assignedPartner!['vehicle_number'] ?? 'N/A'}';
    final status = (_assignedPartner!['status'] ?? 'online').toString();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 18,
            backgroundColor: Color(0xFF185B3A),
            child: Icon(Icons.delivery_dining_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Assigned Partner: ',
                      style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF166534)),
                    ),
                    Text(
                      name,
                      style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                    ),
                  ],
                ),
                Text(
                  '$vehicle  •  $phone',
                  style: GoogleFonts.outfit(fontSize: 11.5, color: const Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: status == 'delivering'
                  ? const Color(0xFFEFF6FF)
                  : const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              status.toUpperCase(),
              style: GoogleFonts.outfit(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: status == 'delivering' ? const Color(0xFF2563EB) : const Color(0xFF166534),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAssignDeliveryDialog() async {
    final orderId = _order['id']?.toString() ?? '';
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AssignPartnerBottomSheet(
        orderId: orderId,
        currentAssignedId: _assignedPartner?['id']?.toString(),
        onPartnerAssigned: (partner) {
          setState(() {
            _assignedPartner = partner;
            if (_currentStatus.toLowerCase() == 'pending') {
              _currentStatus = 'Processing';
              _order['status'] = 'Processing';
            }
          });
          if (widget.onStatusUpdate != null) {
            widget.onStatusUpdate!(_order['id'], _currentStatus);
          }
        },
      ),
    );
  }
}

class _AssignPartnerBottomSheet extends StatefulWidget {
  final String orderId;
  final String? currentAssignedId;
  final ValueChanged<Map<String, dynamic>> onPartnerAssigned;

  const _AssignPartnerBottomSheet({
    required this.orderId,
    this.currentAssignedId,
    required this.onPartnerAssigned,
  });

  @override
  State<_AssignPartnerBottomSheet> createState() => _AssignPartnerBottomSheetState();
}

class _AssignPartnerBottomSheetState extends State<_AssignPartnerBottomSheet> {
  bool _isLoading = true;
  String? _assigningPartnerId;
  List<Map<String, dynamic>> _partners = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadPartners();
  }

  Future<void> _loadPartners() async {
    try {
      final partners = await CubePod.get<DeliveryRepository>().fetchAvailableDeliveryPartners();
      if (mounted) {
        setState(() {
          _partners = partners;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _assign(Map<String, dynamic> partner) async {
    final pid = partner['id']?.toString();
    if (pid == null) return;

    setState(() => _assigningPartnerId = pid);
    final success = await CubePod.get<DeliveryRepository>().assignDeliveryPartner(widget.orderId, pid);
    if (!mounted) return;
    setState(() => _assigningPartnerId = null);

    if (success) {
      AppToast.show(
        context,
        'Assigned order to ${partner['full_name'] ?? 'partner'}',
        type: ToastType.success,
      );
      widget.onPartnerAssigned(partner);
      Navigator.pop(context);
    } else {
      AppToast.show(
        context,
        'Failed to assign order. Please try again.',
        type: ToastType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _partners.where((p) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      final name = (p['full_name'] ?? '').toString().toLowerCase();
      final phone = (p['phone'] ?? '').toString().toLowerCase();
      final vehicle = (p['vehicle_number'] ?? '').toString().toLowerCase();
      return name.contains(q) || phone.contains(q) || vehicle.contains(q);
    }).toList();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Assign Delivery Partner',
                      style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                    ),
                    Text(
                      'Order #${widget.orderId.substring(0, widget.orderId.length > 8 ? 8 : widget.orderId.length)}',
                      style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF64748B)),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Search partner by name, phone or vehicle...',
                hintStyle: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF94A3B8)),
                prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF94A3B8)),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF185B3A), width: 1.5),
                ),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF185B3A)))
                : filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.delivery_dining_outlined, size: 48, color: Color(0xFF94A3B8)),
                            const SizedBox(height: 12),
                            Text(
                              'No delivery partners found',
                              style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF475569)),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Add accounts with role="delivery_man" in the database',
                              style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF94A3B8)),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (ctx, i) {
                          final p = filtered[i];
                          final pid = p['id']?.toString() ?? '';
                          final isAssigned = pid == widget.currentAssignedId;
                          final isAssigning = pid == _assigningPartnerId;
                          final status = (p['status'] ?? 'offline').toString();
                          final completed = p['completed_deliveries_count'] ?? 0;
                          final rating = (p['rating'] is num) ? (p['rating'] as num).toDouble() : 5.0;

                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isAssigned ? const Color(0xFFF0FDF4) : Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isAssigned ? const Color(0xFF22C55E) : const Color(0xFFE2E8F0),
                                width: isAssigned ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 22,
                                  backgroundColor: const Color(0xFFF1F5F9),
                                  backgroundImage: (p['avatar_url'] != null && (p['avatar_url'] as String).isNotEmpty)
                                      ? NetworkImage(p['avatar_url'])
                                      : null,
                                  child: (p['avatar_url'] == null || (p['avatar_url'] as String).isEmpty)
                                      ? Text(
                                          (p['full_name'] ?? 'P')[0].toUpperCase(),
                                          style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF185B3A)),
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              p['full_name'] ?? 'Partner',
                                              style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: status == 'online'
                                                  ? const Color(0xFFDCFCE7)
                                                  : (status == 'delivering' ? const Color(0xFFEFF6FF) : const Color(0xFFF1F5F9)),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              status.toUpperCase(),
                                              style: GoogleFonts.outfit(
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                                color: status == 'online'
                                                    ? const Color(0xFF166534)
                                                    : (status == 'delivering' ? const Color(0xFF2563EB) : const Color(0xFF64748B)),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${p['vehicle_type'] ?? 'Bike'} • ${p['vehicle_number'] ?? 'N/A'} • ${p['phone'] ?? ''}',
                                        style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF64748B)),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(Icons.star_rounded, size: 14, color: Color(0xFFEAB308)),
                                          const SizedBox(width: 3),
                                          Text(
                                            rating.toStringAsFixed(1),
                                            style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            '•  $completed deliveries',
                                            style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF94A3B8)),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                if (isAssigned)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF166534),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.check, size: 14, color: Colors.white),
                                        const SizedBox(width: 4),
                                        Text('Assigned', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                                      ],
                                    ),
                                  )
                                else
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF185B3A),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    onPressed: isAssigning ? null : () => _assign(p),
                                    child: isAssigning
                                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                        : Text('Assign', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold)),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

// Retain alias for backward compatibility
typedef AdminOrderDetailsPage = OrderDetailsPage;

