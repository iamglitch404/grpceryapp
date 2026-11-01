import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:app/features/admin/orders/providers/adminOrderProviders.dart';
import 'package:app/features/admin/orders/providers/liveLocationService.dart';
import 'package:app/features/admin/orders/widgets/orderMapHelpers.dart';

/// InDrive-Style 3-Location Order Widget
/// Displays a sleek route summary in order cards, and opens the interactive InDrive navigation
/// modal when clicked with 3 locations:
/// 1. Admin / Store Location (Fulfillment Hub)
/// 2. Orderer User Device GPS (Captured at Checkout)
/// 3. Delivery Destination (Customer Address)
class OrderMapWidget extends ConsumerStatefulWidget {
  final Map<String, dynamic> order;
  final bool showMapByDefault;
  final Function(dynamic orderId, String newStatus)? onStatusUpdate;

  const OrderMapWidget({
    super.key,
    required this.order,
    this.showMapByDefault = false,
    this.onStatusUpdate,
  });

  @override
  ConsumerState<OrderMapWidget> createState() => _OrderMapWidgetState();
}

class _OrderMapWidgetState extends ConsumerState<OrderMapWidget> {
  AdminLocationState get _adminLocation => ref.watch(adminLocationProvider);
  LatLng get _adminPoint => _adminLocation.adminPoint;
  String get _adminAddress => _adminLocation.adminAddress;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _fetchAdminLocation());
  }

  Future<void> _fetchAdminLocation() async {
    try {
      final loc = await LiveLocationService.getLiveLocation();
      if (mounted) {
        ref.read(adminLocationProvider.notifier).setLocation(
          point: loc.point,
          address: loc.address,
        );
      }
    } catch (_) {
      if (mounted) {
        ref.read(adminLocationProvider.notifier).setLocation(
          point: LiveLocationService.defaultPoint,
          address: LiveLocationService.defaultAddress,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(adminLocationProvider);
    final order = widget.order;

    // 1. Orderer User Device Location
    final double? deviceLat = toDouble(order['device_latitude']);
    final double? deviceLng = toDouble(order['device_longitude']);
    final LatLng? devicePoint =
        (deviceLat != null && deviceLng != null) ? LatLng(deviceLat, deviceLng) : null;
    final String? deviceAddress = order['device_location_address']?.toString();

    // 2. Delivery Destination Location
    final snapshot = order['address_snapshot'] is Map ? order['address_snapshot'] as Map : null;
    final double? destLat = toDouble(order['destination_latitude']) ??
        (snapshot != null ? toDouble(snapshot['latitude']) : null);
    final double? destLng = toDouble(order['destination_longitude']) ??
        (snapshot != null ? toDouble(snapshot['longitude']) : null);
    final LatLng? destPoint =
        (destLat != null && destLng != null) ? LatLng(destLat, destLng) : null;

    final String destAddress = order['destination_address']?.toString() ??
        (snapshot != null
            ? (snapshot['address'] ?? snapshot['street'] ?? snapshot['details'])?.toString()
            : null) ??
        'Delivery Destination';

    // 3. Discrepancy & Fraud Analysis
    double discrepancyKm = (order['location_discrepancy_km'] as num?)?.toDouble() ?? 0.0;
    if (discrepancyKm == 0 && devicePoint != null && destPoint != null) {
      discrepancyKm = calcDistanceKm(devicePoint, destPoint);
    }
    final bool isFraudFlagged = order['is_fraud_flagged'] == true || discrepancyKm > 15.0;

    // Direct Delivery Distance (Admin Hub -> Destination)
    final double deliveryDistanceKm = destPoint != null
        ? calcDistanceKm(_adminPoint, destPoint)
        : (devicePoint != null ? calcDistanceKm(_adminPoint, devicePoint) : 0.0);

    return Container(
      decoration: BoxDecoration(
        color: isFraudFlagged ? const Color(0xFFFFF1F2) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isFraudFlagged ? const Color(0xFFFDA4AF) : const Color(0xFFE2E8F0),
          width: isFraudFlagged ? 1.5 : 1.0,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => openInDriveMapModal(
            context: context,
            order: order,
            adminPoint: _adminPoint,
            adminAddress: _adminAddress,
            devicePoint: devicePoint,
            deviceAddress: deviceAddress,
            destPoint: destPoint,
            destAddress: destAddress,
            discrepancyKm: discrepancyKm,
            deliveryDistanceKm: deliveryDistanceKm,
            isFraudFlagged: isFraudFlagged,
            onStatusUpdate: widget.onStatusUpdate,
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Fraud & Verification Banner
                Row(
                  children: [
                    Icon(
                      isFraudFlagged ? Icons.warning_amber_rounded : Icons.verified_user_rounded,
                      size: 16,
                      color: isFraudFlagged ? const Color(0xFFE11D48) : const Color(0xFF16A34A),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        isFraudFlagged
                            ? '🚨 High Discrepancy (${discrepancyKm.toStringAsFixed(2)} km) • Risk Flagged'
                            : (discrepancyKm > 0
                                ? '🛡️ Location Verified: Placed ${discrepancyKm.toStringAsFixed(2)} km from drop-off'
                                : '🛡️ Location Verified: GPS & Destination Match'),
                        style: GoogleFonts.outfit(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: isFraudFlagged ? const Color(0xFFE11D48) : const Color(0xFF16A34A),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF185B3A).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '3 LOCATIONS',
                        style: GoogleFonts.outfit(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF185B3A),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // InDrive-Style 3-Stop Stepper
                _buildInDriveStopRow(
                  stopLabel: 'A',
                  stopColor: const Color(0xFF16A34A),
                  title: 'Admin Live Location (Origin)',
                  subtitle: _adminAddress,
                  coords: '${_adminPoint.latitude.toStringAsFixed(4)}, ${_adminPoint.longitude.toStringAsFixed(4)}',
                  isFirst: true,
                ),
                _buildInDriveStepDivider('🚗 ${deliveryDistanceKm.toStringAsFixed(1)} km delivery leg'),
                _buildInDriveStopRow(
                  stopLabel: 'B',
                  stopColor: const Color(0xFF2563EB),
                  title: 'Orderer GPS (Captured at Checkout)',
                  subtitle: deviceAddress ?? (devicePoint != null ? 'Device GPS Recorded' : 'GPS Not Captured'),
                  coords: devicePoint != null
                      ? '${devicePoint.latitude.toStringAsFixed(4)}, ${devicePoint.longitude.toStringAsFixed(4)}'
                      : 'No GPS data',
                ),
                _buildInDriveStepDivider('📍 ${discrepancyKm.toStringAsFixed(1)} km to drop-off'),
                _buildInDriveStopRow(
                  stopLabel: 'C',
                  stopColor: const Color(0xFFE11D48),
                  title: 'Deliver To (Destination)',
                  subtitle: destAddress,
                  coords: destPoint != null
                      ? '${destPoint.latitude.toStringAsFixed(4)}, ${destPoint.longitude.toStringAsFixed(4)}'
                      : 'Address only',
                  isLast: true,
                ),
                const SizedBox(height: 12),

                // InDrive Action Buttons Row
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF185B3A),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => openInDriveMapModal(
                          context: context,
                          order: order,
                          adminPoint: _adminPoint,
                          adminAddress: _adminAddress,
                          devicePoint: devicePoint,
                          deviceAddress: deviceAddress,
                          destPoint: destPoint,
                          destAddress: destAddress,
                          discrepancyKm: discrepancyKm,
                          deliveryDistanceKm: deliveryDistanceKm,
                          isFraudFlagged: isFraudFlagged,
                          onStatusUpdate: widget.onStatusUpdate,
                        ),
                        icon: const Icon(Icons.map_rounded, size: 16),
                        label: Text(
                          'View in Map & Route',
                          style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF1E293B),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                            const SnackBar(content: Text('Destination coordinates not available')),
                          );
                        }
                      },
                      icon: const Icon(Icons.navigation_rounded, size: 15, color: Color(0xFF16A34A)),
                      label: Text(
                        'Navigate',
                        style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInDriveStopRow({
    required String stopLabel,
    required Color stopColor,
    required String title,
    required String subtitle,
    required String coords,
    bool isFirst = false,
    bool isLast = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: stopColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: stopColor.withValues(alpha: 0.3), blurRadius: 4, offset: const Offset(0, 2)),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                stopLabel,
                style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white),
              ),
            ),
          ],
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF475569)),
              ),
              Text(
                subtitle,
                style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                coords,
                style: GoogleFonts.outfit(fontSize: 10, color: const Color(0xFF94A3B8)),
              ),
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
        border: Border(
          left: BorderSide(color: Color(0xFFCBD5E1), width: 1.5, style: BorderStyle.solid),
        ),
      ),
      child: Text(
        label,
        style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
      ),
    );
  }
}

/// Opens the Fullscreen InDrive-style 3-Location Navigation Modal
void openInDriveMapModal({
  required BuildContext context,
  required Map<String, dynamic> order,
  required LatLng adminPoint,
  required String adminAddress,
  required LatLng? devicePoint,
  required String? deviceAddress,
  required LatLng? destPoint,
  required String destAddress,
  required double discrepancyKm,
  required double deliveryDistanceKm,
  required bool isFraudFlagged,
  Function(dynamic orderId, String newStatus)? onStatusUpdate,
}) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (ctx) => InDriveOrderMapDialog(
        order: order,
        adminPoint: adminPoint,
        adminAddress: adminAddress,
        devicePoint: devicePoint,
        deviceAddress: deviceAddress,
        destPoint: destPoint,
        destAddress: destAddress,
        discrepancyKm: discrepancyKm,
        deliveryDistanceKm: deliveryDistanceKm,
        isFraudFlagged: isFraudFlagged,
        onStatusUpdate: onStatusUpdate,
      ),
    ),
  );
}

/// InDrive Style Interactive Navigation & Order Details Dialog
class InDriveOrderMapDialog extends ConsumerStatefulWidget {
  final Map<String, dynamic> order;
  final LatLng adminPoint;
  final String adminAddress;
  final LatLng? devicePoint;
  final String? deviceAddress;
  final LatLng? destPoint;
  final String destAddress;
  final double discrepancyKm;
  final double deliveryDistanceKm;
  final bool isFraudFlagged;
  final Function(dynamic orderId, String newStatus)? onStatusUpdate;

  const InDriveOrderMapDialog({
    super.key,
    required this.order,
    required this.adminPoint,
    required this.adminAddress,
    required this.devicePoint,
    required this.deviceAddress,
    required this.destPoint,
    required this.destAddress,
    required this.discrepancyKm,
    required this.deliveryDistanceKm,
    required this.isFraudFlagged,
    this.onStatusUpdate,
  });

  @override
  ConsumerState<InDriveOrderMapDialog> createState() => _InDriveOrderMapDialogState();
}

class _InDriveOrderMapDialogState extends ConsumerState<InDriveOrderMapDialog> {
  final MapController _mapController = MapController();
  InDriveOrderMapDialogState get _dialogState => ref.watch(inDriveOrderMapDialogProvider);
  String get _mapLayer => _dialogState.mapLayer;
  bool get _showOrderItems => _dialogState.showOrderItems;

  late LatLng _center;
  late double _zoom;

  List<LatLng> get _roadRoutePoints => _dialogState.roadRoutePoints;
  bool get _isLoadingRoute => _dialogState.isLoadingRoute;
  double? get _roadDistanceKm => _dialogState.roadDistanceKm;
  int? get _roadDurationMins => _dialogState.roadDurationMins;

  @override
  void initState() {
    super.initState();
    _calculateInitialCamera();
    Future.microtask(() => _fetchRoadRoute());
  }

  Future<void> _fetchRoadRoute() async {
    final points = <LatLng>[widget.adminPoint];
    if (widget.devicePoint != null) points.add(widget.devicePoint!);
    if (widget.destPoint != null) points.add(widget.destPoint!);

    if (points.length < 2) return;

    if (mounted) ref.read(inDriveOrderMapDialogProvider.notifier).setLoadingRoute(true);

    final routeData = await fetchRoadRoute(points);

    if (mounted) {
      if (routeData != null) {
        ref.read(inDriveOrderMapDialogProvider.notifier).setRoute(
          points: routeData['points'],
          distanceKm: routeData['distanceKm'],
          durationMins: routeData['durationMins'],
          isLoading: false,
        );
      } else {
        ref.read(inDriveOrderMapDialogProvider.notifier).setRoute(
          points: points,
          isLoading: false,
        );
      }
    }
  }

  void _calculateInitialCamera() {
    final points = <LatLng>[widget.adminPoint];
    if (widget.devicePoint != null) points.add(widget.devicePoint!);
    if (widget.destPoint != null) points.add(widget.destPoint!);

    double sumLat = 0;
    double sumLng = 0;
    for (final p in points) {
      sumLat += p.latitude;
      sumLng += p.longitude;
    }
    _center = LatLng(sumLat / points.length, sumLng / points.length);

    double maxDist = 0;
    for (int i = 0; i < points.length; i++) {
      for (int j = i + 1; j < points.length; j++) {
        final d = calcDistanceKm(points[i], points[j]);
        if (d > maxDist) maxDist = d;
      }
    }

    if (maxDist < 2.0) {
      _zoom = 14.5;
    } else if (maxDist < 6.0) {
      _zoom = 13.0;
    } else if (maxDist < 15.0) {
      _zoom = 11.5;
    } else {
      _zoom = 9.5;
    }
  }

  void _recenterRoute() {
    _mapController.move(_center, _zoom);
  }

  String _getTileUrl() {
    if (_mapLayer == 'satellite') {
      return 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
    }
    return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(inDriveOrderMapDialogProvider);
    final order = widget.order;
    final orderId = (order['id'] ?? '').toString();
    final status = (order['status'] ?? 'Pending').toString();
    final total = order['total_amount'] ?? order['total'] ?? '0';
    final user = order['account'] ?? order['user'] ?? {};
    final customerName = user['full_name'] ?? user['name'] ?? order['customer_name'] ?? 'Customer';
    final customerPhone = user['phone'] ?? order['phone'] ?? '';
    final paymentMethod = order['payment_method'] ?? 'COD';
    final items = (order['order_items'] is List)
        ? (order['order_items'] as List)
        : ((order['items'] is List) ? (order['items'] as List) : []);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: double.infinity,
          height: MediaQuery.of(context).size.height * 0.90,
          color: Colors.white,
          child: Column(
            children: [
              // Top Header (InDrive Ride Header Style)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: Color(0xFF0F172A),
                  boxShadow: [
                    BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: const Color(0xFF16A34A).withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.navigation_rounded, color: Color(0xFF4ADE80), size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Order #${orderId.length > 8 ? orderId.substring(0, 8) : orderId}',
                                style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF185B3A),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  status.toUpperCase(),
                                  style: GoogleFonts.outfit(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            _isLoadingRoute
                                ? 'Calculating street route...'
                                : _roadDistanceKm != null
                                    ? '${_roadDistanceKm!.toStringAsFixed(1)} km road (~${_roadDurationMins ?? 1} min) • Pathao/InDrive Route'
                                    : 'inDrive Navigation Mode • 3 Waypoints Route',
                            style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                    ),

                    // Layer Switcher
                    IconButton(
                      tooltip: 'Toggle Satellite / Map',
                      onPressed: () {
                        ref.read(inDriveOrderMapDialogProvider.notifier).toggleMapLayer();
                      },
                      icon: Icon(
                        _mapLayer == 'satellite' ? Icons.map_outlined : Icons.satellite_alt_rounded,
                        color: Colors.white70,
                        size: 20,
                      ),
                    ),

                    // Recenter Route
                    IconButton(
                      tooltip: 'Fit All 3 Waypoints',
                      onPressed: _recenterRoute,
                      icon: const Icon(Icons.my_location_rounded, color: Color(0xFF4ADE80), size: 20),
                    ),

                    // Close Dialog
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 22),
                    ),
                  ],
                ),
              ),

              // Interactive OpenStreetMap (Takes top flexible space)
              Expanded(
                flex: 11,
                child: Stack(
                  children: [
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: _center,
                        initialZoom: _zoom,
                        maxZoom: 18.0,
                        minZoom: 4.0,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: _getTileUrl(),
                          userAgentPackageName: 'com.dovan.groceryapp',
                        ),

                        // Route Polyline (Pathao / InDrive Real Road Connecting Path)
                        PolylineLayer(
                          polylines: [
                            // 1. Street Navigation Outer Shadow/Casing (Pathao / InDrive style)
                            Polyline(
                              points: _roadRoutePoints.isNotEmpty
                                  ? _roadRoutePoints
                                  : [
                                      widget.adminPoint,
                                      if (widget.devicePoint != null) widget.devicePoint!,
                                      if (widget.destPoint != null) widget.destPoint!,
                                    ],
                              strokeWidth: 6.5,
                              color: const Color(0xFF0F5132).withValues(alpha: 0.75),
                            ),

                            // 2. Real Road Navigation Core Line (Smooth street curves)
                            Polyline(
                              points: _roadRoutePoints.isNotEmpty
                                  ? _roadRoutePoints
                                  : [
                                      widget.adminPoint,
                                      if (widget.devicePoint != null) widget.devicePoint!,
                                      if (widget.destPoint != null) widget.destPoint!,
                                    ],
                              strokeWidth: 4.5,
                              color: const Color(0xFF10B981),
                            ),

                            // 3. Discrepancy leg between Device GPS and Destination (Warning dashed effect)
                            if (widget.devicePoint != null && widget.destPoint != null && widget.isFraudFlagged)
                              Polyline(
                                points: [widget.devicePoint!, widget.destPoint!],
                                strokeWidth: 2.5,
                                color: const Color(0xFFE11D48),
                              ),
                          ],
                        ),

                        // 3 Custom inDrive Pin Markers
                        MarkerLayer(
                          markers: [
                            // Point A: Admin Store / Hub
                            Marker(
                              point: widget.adminPoint,
                              width: 130,
                              height: 64,
                              child: _buildPinBadge(
                                label: 'A: Admin Hub',
                                icon: Icons.store_rounded,
                                badgeColor: const Color(0xFF16A34A),
                              ),
                            ),

                            // Point B: Orderer User GPS
                            if (widget.devicePoint != null)
                              Marker(
                                point: widget.devicePoint!,
                                width: 140,
                                height: 64,
                                child: _buildPinBadge(
                                  label: 'B: Orderer GPS',
                                  icon: Icons.phone_android_rounded,
                                  badgeColor: const Color(0xFF2563EB),
                                ),
                              ),

                            // Point C: Delivery Destination
                            if (widget.destPoint != null)
                              Marker(
                                point: widget.destPoint!,
                                width: 130,
                                height: 64,
                                child: _buildPinBadge(
                                  label: 'C: Deliver To',
                                  icon: Icons.flag_rounded,
                                  badgeColor: const Color(0xFFE11D48),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),

                    // Floating InDrive Mini Route Legend
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                        ),
                        child: Row(
                          children: [
                            _buildLegendItem('A: Hub', const Color(0xFF16A34A)),
                            const SizedBox(width: 8),
                            _buildLegendItem('B: Buyer GPS', const Color(0xFF2563EB)),
                            const SizedBox(width: 8),
                            _buildLegendItem('C: Drop-off', const Color(0xFFE11D48)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Bottom InDrive Navigation & Order Card (Scrollable bottom panel)
              Expanded(
                flex: 9,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Customer & Financial Quick Summary
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: const Color(0xFF185B3A).withValues(alpha: 0.1),
                                  child: const Icon(Icons.person_rounded, size: 18, color: Color(0xFF185B3A)),
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      customerName,
                                      style: GoogleFonts.outfit(fontSize: 13.5, fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      '$paymentMethod • ₹$total',
                                      style: GoogleFonts.outfit(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF185B3A),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            if (customerPhone.isNotEmpty)
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2563EB),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: () => launchPhoneCall(customerPhone),
                                icon: const Icon(Icons.phone_rounded, size: 14),
                                label: Text('Call $customerPhone', style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.bold)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // InDrive Waypoints Card
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            children: [
                              _buildModalStopItem(
                                label: 'A',
                                color: const Color(0xFF16A34A),
                                title: 'Admin Live Location (Origin)',
                                subtitle: widget.adminAddress,
                                coords: '${widget.adminPoint.latitude.toStringAsFixed(5)}, ${widget.adminPoint.longitude.toStringAsFixed(5)}',
                              ),
                              const Divider(height: 14, color: Color(0xFFE2E8F0)),
                              _buildModalStopItem(
                                label: 'B',
                                color: const Color(0xFF2563EB),
                                title: 'Orderer User GPS (Captured at Checkout)',
                                subtitle: widget.deviceAddress ?? 'Buyer Device Coordinates Recorded',
                                coords: widget.devicePoint != null
                                    ? '${widget.devicePoint!.latitude.toStringAsFixed(5)}, ${widget.devicePoint!.longitude.toStringAsFixed(5)}'
                                    : 'GPS data unavailable',
                              ),
                              const Divider(height: 14, color: Color(0xFFE2E8F0)),
                              _buildModalStopItem(
                                label: 'C',
                                color: const Color(0xFFE11D48),
                                title: 'Delivery Destination (Drop-off Address)',
                                subtitle: widget.destAddress,
                                coords: widget.destPoint != null
                                    ? '${widget.destPoint!.latitude.toStringAsFixed(5)}, ${widget.destPoint!.longitude.toStringAsFixed(5)}'
                                    : 'Coordinates unavailable',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Fraud & Discrepancy Status
                        Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: widget.isFraudFlagged ? const Color(0xFFFFF1F2) : const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: widget.isFraudFlagged ? const Color(0xFFFECDD3) : const Color(0xFFBBF7D0),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                widget.isFraudFlagged ? Icons.warning_rounded : Icons.shield_rounded,
                                size: 16,
                                color: widget.isFraudFlagged ? const Color(0xFFE11D48) : const Color(0xFF16A34A),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  widget.isFraudFlagged
                                      ? '🚨 Fraud Warning: Device is ${widget.discrepancyKm.toStringAsFixed(2)} km away from destination!'
                                      : '🛡️ Safe Distance: Device was placed ${widget.discrepancyKm.toStringAsFixed(2)} km from destination',
                                  style: GoogleFonts.outfit(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                    color: widget.isFraudFlagged ? const Color(0xFFE11D48) : const Color(0xFF16A34A),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Main InDrive Turn-by-Turn Navigation Action
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF16A34A),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () {
                              if (widget.destPoint != null) {
                                launchGoogleMapsNavigation(
                                  origin: widget.adminPoint,
                                  destination: widget.destPoint!,
                                  waypoint: widget.devicePoint,
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Destination coordinates not available')),
                                );
                              }
                            },
                            icon: const Icon(Icons.navigation_rounded, size: 20),
                            label: Text(
                              'Start Turn-by-Turn Navigation (Google Maps)',
                              style: GoogleFonts.outfit(fontSize: 13.5, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Order Items Toggle & Quick Status Actions
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            TextButton.icon(
                              onPressed: () {
                                ref.read(inDriveOrderMapDialogProvider.notifier).toggleShowOrderItems();
                              },
                              icon: Icon(_showOrderItems ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 18),
                              label: Text(
                                '${items.length} Order Item(s)',
                                style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF475569)),
                              ),
                            ),

                            // In-Map Status Actions
                            if (widget.onStatusUpdate != null)
                              Row(
                                children: [
                                  if (status.toLowerCase() == 'pending')
                                    _buildStatusButton('Pack', const Color(0xFF2563EB), () {
                                      widget.onStatusUpdate!(order['id'], 'Packed');
                                      Navigator.of(context).pop();
                                    }),
                                  if (status.toLowerCase() == 'packed')
                                    _buildStatusButton('Dispatch', const Color(0xFF7C3AED), () {
                                      widget.onStatusUpdate!(order['id'], 'On the way');
                                      Navigator.of(context).pop();
                                    }),
                                  if (status.toLowerCase() == 'on the way')
                                    _buildStatusButton('Deliver', const Color(0xFF16A34A), () {
                                      widget.onStatusUpdate!(order['id'], 'Delivered');
                                      Navigator.of(context).pop();
                                    }),
                                ],
                              ),
                          ],
                        ),

                        // Order Items List Expanded
                        if (_showOrderItems && items.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              children: [
                                for (final it in items)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 3),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            it['title_snapshot'] ?? it['title'] ?? it['name'] ?? 'Item',
                                            style: GoogleFonts.outfit(fontSize: 11.5, color: const Color(0xFF334155)),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Text(
                                          '× ${it['quantity'] ?? 1}',
                                          style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPinBadge({required String label, required IconData icon, required Color badgeColor}) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: badgeColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: Colors.white),
              const SizedBox(width: 4),
              Text(
                label,
                style: GoogleFonts.outfit(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ],
          ),
        ),
        Icon(Icons.arrow_drop_down, color: badgeColor, size: 18),
      ],
    );
  }

  Widget _buildLegendItem(String text, Color color) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(text, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF334155))),
      ],
    );
  }

  Widget _buildModalStopItem({
    required String label,
    required Color color,
    required String title,
    required String subtitle,
    required String coords,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Text(label, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF64748B))),
              Text(subtitle, style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A))),
              Text(coords, style: GoogleFonts.outfit(fontSize: 9.5, color: const Color(0xFF94A3B8))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusButton(String text, Color color, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        onPressed: onTap,
        child: Text(text, style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

/// Retain alias for backward compatibility
typedef OrderLocationMapWidget = OrderMapWidget;
