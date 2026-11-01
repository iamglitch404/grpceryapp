import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:app/core/di/injection.dart';
import 'package:app/features/customer/orders/widgets/orderTrackingStepper.dart';
import 'package:app/features/customer/orders/providers/orderProviders.dart';

class OrderTrackingPage extends ConsumerStatefulWidget {
  final Map<String, dynamic> order;

  const OrderTrackingPage({
    super.key,
    required this.order,
  });

  @override
  ConsumerState<OrderTrackingPage> createState() => _OrderTrackingPageState();
}

class _OrderTrackingPageState extends ConsumerState<OrderTrackingPage> {
  final MapController _mapController = MapController();
  Map<String, dynamic> get _order => ref.read(orderTrackingOrderProvider) ?? widget.order;
  bool get _isLoading => ref.read(orderTrackingIsLoadingProvider);
  Timer? _pollTimer;

  static const LatLng _storeHubLocation = LatLng(27.7172, 85.3240);
  LatLng get _customerLocation => ref.read(orderTrackingCustomerLocationProvider);
  LatLng? get _riderLocation => ref.read(orderTrackingRiderLocationProvider);
  List<LatLng> get _routePoints => ref.read(orderTrackingRoutePointsProvider);
  double get _distanceMeters => ref.read(orderTrackingDistanceMetersProvider);
  double get _durationSecs => ref.read(orderTrackingDurationSecsProvider);

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      ref.read(orderTrackingOrderProvider.notifier).state = Map<String, dynamic>.from(widget.order);
      _resolveCoordinates();
      _refreshTracking();
    });
    _pollTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (mounted) _refreshTracking();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _resolveCoordinates() {
    final snap = _order['address_snapshot'] is Map
        ? Map<String, dynamic>.from(_order['address_snapshot'] as Map)
        : <String, dynamic>{};

    final destLat = (_order['destination_latitude'] ??
            snap['latitude'] ??
            _order['device_latitude'] ??
            27.7025) as num;
    final destLng = (_order['destination_longitude'] ??
            snap['longitude'] ??
            _order['device_longitude'] ??
            85.3120) as num;

    final customerLoc = LatLng(destLat.toDouble(), destLng.toDouble());
    ref.read(orderTrackingCustomerLocationProvider.notifier).state = customerLoc;

    final partner = _order['delivery_partner'] is Map
        ? Map<String, dynamic>.from(_order['delivery_partner'] as Map)
        : null;

    if (partner != null &&
        partner['current_latitude'] is num &&
        partner['current_longitude'] is num) {
      ref.read(orderTrackingRiderLocationProvider.notifier).state = LatLng(
        (partner['current_latitude'] as num).toDouble(),
        (partner['current_longitude'] as num).toDouble(),
      );
    } else {
      final status = (_order['status'] ?? 'Pending').toString().toLowerCase();
      if (status == 'on the way' || status == 'out for delivery') {
        ref.read(orderTrackingRiderLocationProvider.notifier).state = LatLng(
          (_storeHubLocation.latitude + customerLoc.latitude) / 2,
          (_storeHubLocation.longitude + customerLoc.longitude) / 2,
        );
      } else if (status == 'delivered') {
        ref.read(orderTrackingRiderLocationProvider.notifier).state = customerLoc;
      } else {
        ref.read(orderTrackingRiderLocationProvider.notifier).state = _storeHubLocation;
      }
    }
  }

  Future<void> _refreshTracking() async {
    final orderId = _order['id']?.toString() ?? '';
    if (orderId.isEmpty) {
      await _computeRoute();
      return;
    }

    if (mounted) ref.read(orderTrackingIsLoadingProvider.notifier).state = true;
    try {
      final updated = await ref.read(customerOrderRepositoryProvider).fetchOrderById(orderId);
      if (updated != null && mounted) {
        ref.read(orderTrackingOrderProvider.notifier).state = updated;
        _resolveCoordinates();
      }
    } catch (_) {}
    await _computeRoute();
    if (mounted) ref.read(orderTrackingIsLoadingProvider.notifier).state = false;
  }

  Future<void> _computeRoute() async {
    final origin = _riderLocation ?? _storeHubLocation;
    try {
      final routing = ref.read(routingServiceProvider);
      final res = await routing.fetchRoute([origin, _customerLocation]);
      if (res != null && mounted) {
        ref.read(orderTrackingRoutePointsProvider.notifier).state = res.points;
        ref.read(orderTrackingDistanceMetersProvider.notifier).state = res.distanceMeters;
        ref.read(orderTrackingDurationSecsProvider.notifier).state = res.durationSecs;
        return;
      }
    } catch (_) {}

    if (mounted) {
      ref.read(orderTrackingRoutePointsProvider.notifier).state = [origin, _customerLocation];
    }
  }

  int _currentStepIndex(String status) {
    final s = status.toLowerCase();
    if (s == 'delivered') return 3;
    if (s == 'out for delivery' || s == 'on the way') return 2;
    if (s == 'processing' || s == 'packed') return 1;
    return 0;
  }

  Future<void> _callRider(String phone) async {
    if (phone.isEmpty) return;
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(orderTrackingOrderProvider);
    ref.watch(orderTrackingIsLoadingProvider);
    ref.watch(orderTrackingCustomerLocationProvider);
    ref.watch(orderTrackingRiderLocationProvider);
    ref.watch(orderTrackingRoutePointsProvider);
    ref.watch(orderTrackingDistanceMetersProvider);
    ref.watch(orderTrackingDurationSecsProvider);

    final status = (_order['status'] ?? 'Pending').toString();
    final isCancelled = status.toLowerCase() == 'cancelled' || status.toLowerCase() == 'canceled';
    final stepIdx = _currentStepIndex(status);
    final shortId = (_order['id']?.toString() ?? '').length > 8
        ? _order['id'].toString().substring(0, 8).toUpperCase()
        : (_order['id']?.toString() ?? '').toUpperCase();

    final partner = _order['delivery_partner'] is Map
        ? Map<String, dynamic>.from(_order['delivery_partner'] as Map)
        : null;
    final riderName = (partner?['full_name'] ?? 'Dovan Express Rider').toString();
    final riderPhone = (partner?['phone'] ?? '').toString();
    final riderVehicle = (partner?['vehicle_type'] ?? 'Bike').toString().toUpperCase();
    final riderRating = (partner?['rating'] ?? 4.9).toString();

    final snap = _order['address_snapshot'] is Map
        ? Map<String, dynamic>.from(_order['address_snapshot'] as Map)
        : <String, dynamic>{};
    final destAddress = (_order['destination_address'] ??
            snap['address'] ??
            snap['street'] ??
            'Delivery Destination')
        .toString();

    final etaMins = stepIdx == 3
        ? 0
        : (_durationSecs > 0 ? (_durationSecs / 60).ceil() + (stepIdx < 2 ? 10 : 2) : 18);
    final distKm = _distanceMeters > 0 ? (_distanceMeters / 1000).toStringAsFixed(1) : '1.8';

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Stack(
          children: [
            // 1. Live Interactive Map
            Positioned.fill(
              bottom: MediaQuery.of(context).size.height * 0.44,
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _riderLocation ?? _customerLocation,
                  initialZoom: 14.2,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                    subdomains: const ['a', 'b', 'c', 'd'],
                    userAgentPackageName: 'com.dovan.groceryapp',
                  ),
                  if (_routePoints.isNotEmpty)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: _routePoints,
                          strokeWidth: 7,
                          color: const Color(0xFF42A769).withValues(alpha: 0.28),
                        ),
                        Polyline(
                          points: _routePoints,
                          strokeWidth: 4,
                          color: const Color(0xFF185B3A),
                        ),
                      ],
                    ),
                  MarkerLayer(
                    markers: [
                      // Store Hub Marker
                      Marker(
                        point: _storeHubLocation,
                        width: 44,
                        height: 44,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFF185B3A), width: 2.5),
                            boxShadow: const [
                              BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
                            ],
                          ),
                          child: const Icon(
                            Icons.storefront_rounded,
                            color: Color(0xFF185B3A),
                            size: 20,
                          ),
                        ),
                      ),
                      // Rider Marker
                      if (_riderLocation != null && !isCancelled)
                        Marker(
                          point: _riderLocation!,
                          width: 52,
                          height: 52,
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF185B3A),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 8,
                                  offset: Offset(0, 3),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.delivery_dining_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                      // Customer Destination Marker
                      Marker(
                        point: _customerLocation,
                        width: 48,
                        height: 48,
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFE11D48),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2.5),
                            boxShadow: const [
                              BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
                            ],
                          ),
                          child: const Icon(
                            Icons.home_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 2. Top Floating Bar
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              left: 16,
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.white,
                    child: IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Color(0xFF0F172A),
                        size: 18,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: isCancelled
                                ? Colors.red
                                : const Color(0xFF16A34A),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Order #$shortId',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ),
                  CircleAvatar(
                    backgroundColor: Colors.white,
                    child: IconButton(
                      icon: _isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF185B3A),
                              ),
                            )
                          : const Icon(
                              Icons.refresh_rounded,
                              color: Color(0xFF185B3A),
                              size: 20,
                            ),
                      onPressed: _refreshTracking,
                    ),
                  ),
                ],
              ),
            ),

            // 3. Bottom Tracking Sheet
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                height: MediaQuery.of(context).size.height * 0.50,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 20,
                      offset: Offset(0, -4),
                    ),
                  ],
                ),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ETA & Status Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isCancelled
                                    ? 'Order Cancelled'
                                    : stepIdx == 3
                                        ? 'Order Delivered!'
                                        : stepIdx == 2
                                            ? 'Rider is on the way'
                                            : stepIdx == 1
                                                ? 'Packing your order'
                                                : 'Order confirmed',
                                style: GoogleFonts.outfit(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                isCancelled
                                    ? 'This order was cancelled'
                                    : stepIdx == 3
                                        ? 'Handed over at destination'
                                        : 'Estimated arrival in ~$etaMins mins ($distKm km)',
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!isCancelled)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5EE),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  stepIdx == 3 ? 'DONE' : '$etaMins',
                                  style: GoogleFonts.outfit(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: const Color(0xFF185B3A),
                                  ),
                                ),
                                if (stepIdx != 3)
                                  Text(
                                    'MINS',
                                    style: GoogleFonts.outfit(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF185B3A),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 22),

                    // 4-Step Live Progress Stepper
                    if (!isCancelled)
                      OrderTrackingStepper(activeStep: stepIdx)
                    else
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFEBEE),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.cancel_rounded, color: Colors.red),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Your order has been cancelled.',
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.red.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 20),

                    // Delivery Partner Card
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: const BoxDecoration(
                              color: Color(0xFFE8F5EE),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.two_wheeler_rounded,
                              color: Color(0xFF185B3A),
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  partner != null ? riderName : 'Delivery Partner',
                                  style: GoogleFonts.outfit(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  partner != null
                                      ? '$riderVehicle • ★ $riderRating'
                                      : 'Assigning nearest Dovan partner...',
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (riderPhone.isNotEmpty)
                            IconButton(
                              onPressed: () => _callRider(riderPhone),
                              style: IconButton.styleFrom(
                                backgroundColor: const Color(0xFF185B3A),
                                foregroundColor: Colors.white,
                              ),
                              icon: const Icon(Icons.phone_rounded, size: 18),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Destination Address Card
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.location_on_rounded,
                            color: Color(0xFF185B3A),
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Delivering To (${snap['label'] ?? 'Address'})',
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  destAddress,
                                  style: GoogleFonts.outfit(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

