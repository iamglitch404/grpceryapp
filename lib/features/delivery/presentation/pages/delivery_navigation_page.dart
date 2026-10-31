import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cubepod_core/cubepod_core.dart';
import 'package:app/core/models/route_step.dart';
import 'package:app/core/services/routing_service.dart';
import 'package:app/core/services/location_service.dart';
import 'package:app/core/widgets/toast.dart';
import 'package:app/features/delivery/data/repositories/delivery_repository.dart';

class DeliveryNavigationPage extends StatefulWidget {
  final Map<String, dynamic> order;
  final VoidCallback? onOrderUpdated;

  const DeliveryNavigationPage({
    super.key,
    required this.order,
    this.onOrderUpdated,
  });

  @override
  State<DeliveryNavigationPage> createState() => _DeliveryNavigationPageState();
}

class _DeliveryNavigationPageState extends State<DeliveryNavigationPage> {
  final MapController _mapController = MapController();

  // Navigation State
  bool _isLoadingRoute = true;
  LatLng? _driverLocation;
  late LatLng _destinationLocation;
  String _destinationAddress = '';
  String _customerName = '';
  String _customerPhone = '';
  List<LatLng> _roadPoints = [];
  List<RouteStep> _routeSteps = [];
  double _totalDistanceMeters = 0.0;
  double _totalDurationSecs = 0.0;
  final int _currentStepIndex = 0;
  Timer? _locationTimer;

  @override
  void initState() {
    super.initState();
    _extractOrderLocations();
    _initLocationAndRoute();
    // Periodically update live GPS position
    _locationTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _updateLiveGPS();
    });
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    super.dispose();
  }

  void _extractOrderLocations() {
    final ord = widget.order;

    // Customer / Destination coordinates (prioritize live device GPS if available)
    final lat = ord['customer_latitude'] ?? ord['destination_latitude'] ?? ord['device_latitude'];
    final lng = ord['customer_longitude'] ?? ord['destination_longitude'] ?? ord['device_longitude'];

    final double validLat = (lat is num) ? lat.toDouble() : 27.7108;
    final double validLng = (lng is num) ? lng.toDouble() : 85.3251;
    _destinationLocation = LatLng(validLat, validLng);

    _destinationAddress = ord['customer_address'] ?? ord['destination_address'] ?? ord['device_location_address'] ?? 'Customer Delivery Location';
    _customerName = ord['customer_name'] ?? ord['address_snapshot']?['name'] ?? 'Customer';
    _customerPhone = ord['customer_phone'] ?? ord['address_snapshot']?['phone'] ?? '';
  }

  Future<void> _initLocationAndRoute() async {
    setState(() => _isLoadingRoute = true);

    // 1. Get current driver location
    try {
      final loc = await LocationService.getLiveLocation();
      _driverLocation = loc.point;
    } catch (_) {
      _driverLocation = const LatLng(27.7172, 85.3240); // Dovan Hub fallback
    }

    // 2. Fetch OSRM Road Route
    if (_driverLocation != null) {
      try {
        final routing = CubePod.get<RoutingService>();
        final result = await routing.fetchRoute([_driverLocation!, _destinationLocation]);
        if (mounted && result != null) {
          setState(() {
            _roadPoints = result.points;
            _routeSteps = result.steps;
            _totalDistanceMeters = result.distanceMeters;
            _totalDurationSecs = result.durationSecs;
            _isLoadingRoute = false;
          });
        } else if (mounted) {
          setState(() {
            _roadPoints = [_driverLocation!, _destinationLocation];
            _isLoadingRoute = false;
          });
        }
      } catch (e) {
        debugPrint('[DeliveryNavigationPage] Routing error: $e');
        if (mounted) {
          setState(() {
            // Straight line fallback
            _roadPoints = [_driverLocation!, _destinationLocation];
            _isLoadingRoute = false;
          });
        }
      }
    } else {
      if (mounted) setState(() => _isLoadingRoute = false);
    }
  }

  Future<void> _updateLiveGPS() async {
    try {
      final loc = await LocationService.getLiveLocation();
      if (mounted && _driverLocation != null) {
        setState(() => _driverLocation = loc.point);
        // Also sync live location with backend
        CubePod.get<DeliveryRepository>().updateStatus('on_delivery', lat: loc.point.latitude, lng: loc.point.longitude);
      }
    } catch (_) {}
  }

  Future<void> _makePhoneCall(String phone) async {
    if (phone.isEmpty) {
      AppToast.warning(context, 'No contact phone available');
      return;
    }
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) AppToast.error(context, 'Could not launch dialer');
    }
  }

  Future<void> _openExternalMap() async {
    final lat = _destinationLocation.latitude;
    final lng = _destinationLocation.longitude;
    final googleMapsUrl = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
    if (await canLaunchUrl(googleMapsUrl)) {
      await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _handleCompleteDelivery() async {
    final confirm = await showModalBottomSheet<bool>(
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Confirm Delivery', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
                      Text('Order #${widget.order['id']?.toString().substring(0, 8) ?? ''}', style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF64748B))),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Has the order been handed over to $_customerName at the delivery location?',
              style: GoogleFonts.outfit(fontSize: 14, color: const Color(0xFF334155), height: 1.4),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('Cancel', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF185B3A),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: Text('Mark Delivered', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (confirm == true) {
      final success = await CubePod.get<DeliveryRepository>().performAction(
        widget.order['id'].toString(),
        'deliver',
        notes: 'Handed over to customer at destination GPS coordinates.',
      );
      if (success) {
        if (mounted) {
          AppToast.success(context, 'Delivery marked complete! Payout added to your balance.');
          widget.onOrderUpdated?.call();
          Navigator.pop(context);
        }
      } else {
        if (mounted) AppToast.error(context, 'Failed to update order status');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentStep = _routeSteps.isNotEmpty && _currentStepIndex < _routeSteps.length
        ? _routeSteps[_currentStepIndex]
        : null;

    final distanceKm = (_totalDistanceMeters / 1000).toStringAsFixed(1);
    final durationMins = (_totalDurationSecs / 60).round();
    final hasGps = widget.order['has_device_gps'] == true;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Stack(
        children: [
          // 1. Interactive Map
          _driverLocation == null
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)))
              : FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _driverLocation!,
                    initialZoom: 14.5,
                  ),
                  children: [
                    // CartoDB Voyager / OSM Tiles
                    TileLayer(
                      urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                      subdomains: const ['a', 'b', 'c', 'd'],
                      userAgentPackageName: 'com.dovan.groceryapp',
                    ),

                    // Road polyline
                    if (_roadPoints.isNotEmpty)
                      PolylineLayer(
                        polylines: [
                          // Outer glow
                          Polyline(
                            points: _roadPoints,
                            strokeWidth: 7,
                            color: const Color(0xFF10B981).withValues(alpha: 0.4),
                          ),
                          // Main route line
                          Polyline(
                            points: _roadPoints,
                            strokeWidth: 4.5,
                            color: const Color(0xFF185B3A),
                          ),
                        ],
                      ),

                    // Markers
                    MarkerLayer(
                      markers: [
                        // Rider Live GPS Marker
                        Marker(
                          point: _driverLocation!,
                          width: 50,
                          height: 50,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.25),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF185B3A),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2.5),
                                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2))],
                                ),
                                child: const Icon(Icons.two_wheeler_rounded, color: Colors.white, size: 18),
                              ),
                            ],
                          ),
                        ),

                        // Destination Customer Marker
                        Marker(
                          point: _destinationLocation,
                          width: 50,
                          height: 50,
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEF4444),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2.5),
                                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2))],
                                ),
                                child: const Icon(Icons.person_pin_circle_rounded, color: Colors.white, size: 20),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
          if (_isLoadingRoute)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: LinearProgressIndicator(
                  color: Color(0xFF10B981),
                  backgroundColor: Colors.transparent,
                  minHeight: 3,
                ),
              ),
            ),

          // 2. Top Turn-by-Turn Guidance Banner
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            right: 16,
            child: Column(
              children: [
                // Top App Bar Controls
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.white,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(hasGps ? Icons.gps_fixed_rounded : Icons.location_on_rounded, size: 15, color: const Color(0xFF10B981)),
                          const SizedBox(width: 6),
                          Text(
                            hasGps ? 'GPS Pin Pointed' : 'Address Target',
                            style: GoogleFonts.outfit(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    CircleAvatar(
                      backgroundColor: Colors.white,
                      child: IconButton(
                        icon: const Icon(Icons.my_location_rounded, color: Color(0xFF185B3A)),
                        onPressed: () {
                          if (_driverLocation != null) {
                            _mapController.move(_driverLocation!, 15.5);
                          }
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Maneuver / Next Step Guidance Card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 10, offset: Offset(0, 4))],
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.turn_right_rounded, color: Color(0xFF10B981), size: 26),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentStep != null ? currentStep.instruction : 'Head toward destination',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              currentStep != null
                                  ? 'In ${currentStep.distanceMeters.toStringAsFixed(0)} meters'
                                  : '$distanceKm km remaining • ~${durationMins > 0 ? durationMins : 1} mins',
                              style: GoogleFonts.outfit(color: const Color(0xFF94A3B8), fontSize: 12.5),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: _openExternalMap,
                        icon: const Icon(Icons.open_in_new_rounded, color: Colors.white70),
                        tooltip: 'Open Google Maps',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 3. Bottom Customer & Delivery Actions Card
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 16, offset: Offset(0, -4))],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Customer Header
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: const Color(0xFFE2E8F0),
                        child: Text(
                          _customerName.isNotEmpty ? _customerName[0].toUpperCase() : 'C',
                          style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _customerName,
                              style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                            ),
                            Text(
                              _destinationAddress,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(fontSize: 12.5, color: const Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      // Phone button
                      IconButton(
                        onPressed: () => _makePhoneCall(_customerPhone),
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0xFFDCFCE7),
                          foregroundColor: const Color(0xFF16A34A),
                        ),
                        icon: const Icon(Icons.phone_rounded, size: 20),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),
                  const Divider(color: Color(0xFFF1F5F9)),
                  const SizedBox(height: 10),

                  // Delivery Metrics (Distance, Time, Payment)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildMetric(Icons.route_rounded, '$distanceKm km', 'Distance'),
                      _buildMetric(Icons.timer_outlined, '${durationMins > 0 ? durationMins : 1} min', 'Est. Time'),
                      _buildMetric(
                        Icons.payments_outlined,
                        widget.order['payment_method']?.toString().toUpperCase() ?? 'COD',
                        widget.order['payment_status'] == 'paid' ? 'PAID' : 'COLLECT CASH',
                        highlight: widget.order['payment_status'] != 'paid',
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // Action Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF185B3A),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      onPressed: _handleCompleteDelivery,
                      icon: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                      label: Text(
                        'Mark as Delivered',
                        style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetric(IconData icon, String value, String label, {bool highlight = false}) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: highlight ? const Color(0xFFD97706) : const Color(0xFF185B3A)),
            const SizedBox(width: 4),
            Text(
              value,
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: highlight ? const Color(0xFFD97706) : const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(label, style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF94A3B8), fontWeight: FontWeight.w500)),
      ],
    );
  }
}
