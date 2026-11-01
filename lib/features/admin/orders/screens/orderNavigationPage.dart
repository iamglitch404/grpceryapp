import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:app/core/di/injection.dart';
import 'package:app/core/models/routeStep.dart';
import 'package:app/features/admin/orders/providers/adminOrderProviders.dart';
import 'package:app/features/admin/orders/widgets/positionBarFloating.dart';

/// Dedicated Full-Screen Google Maps / inDrive Style Navigation Page
class OrderNavigationPage extends ConsumerStatefulWidget {
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

  const OrderNavigationPage({
    super.key,
    required this.order,
    required this.adminPoint,
    required this.adminAddress,
    this.devicePoint,
    this.deviceAddress,
    this.destPoint,
    required this.destAddress,
    required this.discrepancyKm,
    required this.deliveryDistanceKm,
    required this.isFraudFlagged,
    this.onStatusUpdate,
  });

  @override
  ConsumerState<OrderNavigationPage> createState() => _OrderNavigationPageState();
}

class _OrderNavigationPageState extends ConsumerState<OrderNavigationPage>
    with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();

  // Navigation State
  bool get _isLoadingRoute => ref.read(orderNavigationProvider).isLoadingRoute;
  String get _mapLayer => ref.read(orderNavigationProvider).mapLayer;
  List<LatLng> get _roadRoutePoints => ref.read(orderNavigationProvider).roadRoutePoints;
  List<RouteStep> get _routeSteps => ref.read(orderNavigationProvider).routeSteps;
  double get _totalDistanceMeters => ref.read(orderNavigationProvider).totalDistanceMeters;
  double get _totalDurationSecs => ref.read(orderNavigationProvider).totalDurationSecs;

  // Active Turn-by-Turn Navigation & Simulation
  bool get _isNavigating => ref.read(orderNavigationProvider).isNavigating;
  int get _currentStepIndex => ref.read(orderNavigationProvider).currentStepIndex;
  int get _simulationCoordIndex => ref.read(orderNavigationProvider).simulationCoordIndex;
  Timer? _simulationTimer;
  LatLng? get _simulatedCurrentPosition => ref.read(orderNavigationProvider).simulatedCurrentPosition;
  bool get _isMuted => ref.read(orderNavigationProvider).isMuted;
  bool get _showStepsSheet => ref.read(orderNavigationProvider).showStepsSheet;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      ref.read(orderNavigationProvider.notifier).setSimulatedPosition(widget.adminPoint);
      _fetchRoadRouteWithSteps();
    });
  }

  @override
  void dispose() {
    _simulationTimer?.cancel();
    super.dispose();
  }

  /// Fetches real road coordinates and turn-by-turn steps from OSRM driving engine
  Future<void> _fetchRoadRouteWithSteps() async {
    if (!mounted) return;
    final notifier = ref.read(orderNavigationProvider.notifier);
    notifier.setLoadingRoute(true);

    final waypoints = <LatLng>[widget.adminPoint];
    if (widget.devicePoint != null) waypoints.add(widget.devicePoint!);
    if (widget.destPoint != null) waypoints.add(widget.destPoint!);

    if (waypoints.length < 2) {
      if (mounted) notifier.setLoadingRoute(false);
      return;
    }

    try {
      final result = await ref.read(routingServiceProvider).fetchRoute(
        waypoints,
        fallbackOrigin: widget.adminPoint,
      );

      if (result != null && mounted) {
        notifier.setRouteResult(
          roadRoutePoints: result.points,
          routeSteps: result.steps,
          totalDistanceMeters: result.distanceMeters,
          totalDurationSecs: result.durationSecs,
          isLoadingRoute: false,
          simulatedCurrentPosition:
              result.points.isNotEmpty ? result.points.first : widget.adminPoint,
        );
        _fitRoute();
        return;
      }
    } catch (e) {
      debugPrint('Error fetching OSRM road steps: $e');
    }

    if (mounted) {
      notifier.setRouteResult(
        roadRoutePoints: waypoints,
        isLoadingRoute: false,
      );
      _fitRoute();
    }
  }

  void _fitRoute() {
    final points = _roadRoutePoints.isNotEmpty
        ? _roadRoutePoints
        : [widget.adminPoint, if (widget.destPoint != null) widget.destPoint!];
    if (points.isEmpty) return;

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    final center = LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);
    _mapController.move(center, 14.2);
  }

  /// Starts or pauses the simulated driver traveling along the actual street route
  void _toggleLiveNavigationSimulation() {
    final notifier = ref.read(orderNavigationProvider.notifier);
    if (_isNavigating) {
      // Pause
      _simulationTimer?.cancel();
      notifier.setNavigating(false);
    } else {
      if (_roadRoutePoints.isEmpty) return;
      notifier.startNavigation(
        resetIndices: _simulationCoordIndex >= _roadRoutePoints.length - 1,
      );

      // Animate driver smoothly along road coordinates
      _simulationTimer = Timer.periodic(const Duration(milliseconds: 350), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }

        if (_simulationCoordIndex < _roadRoutePoints.length - 1) {
          final nextCoordIndex = _simulationCoordIndex + 1;
          final nextPosition = _roadRoutePoints[nextCoordIndex];
          var nextStepIdx = _currentStepIndex;

          // Progress current turn step as driver gets closer to each step waypoint
          if (nextStepIdx < _routeSteps.length - 1) {
            final nextStepLoc = _routeSteps[nextStepIdx + 1].location;
            const distCalc = Distance();
            final meters = distCalc.as(LengthUnit.Meter, nextPosition, nextStepLoc);
            if (meters < 45) {
              nextStepIdx++;
            }
          }

          notifier.advanceSimulation(
            coordIndex: nextCoordIndex,
            position: nextPosition,
            stepIndex: nextStepIdx,
          );

          // Keep camera centered on moving driver in navigation mode
          _mapController.move(nextPosition, 16.5);
        } else {
          // Arrived at destination
          timer.cancel();
          notifier.setNavigating(false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '🏁 Arrived at Delivery Destination (${widget.destAddress})',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
              ),
              backgroundColor: const Color(0xFF16A34A),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      });
    }
  }

  /// Launch external native Google Maps app with full multi-stop navigation
  Future<void> _launchNativeGoogleMaps() async {
    final origin = widget.adminPoint;
    final dest = widget.destPoint ?? widget.adminPoint;
    final waypoint = widget.devicePoint;

    String url;
    if (waypoint != null) {
      url =
          'https://www.google.com/maps/dir/?api=1&origin=${origin.latitude},${origin.longitude}&destination=${dest.latitude},${dest.longitude}&waypoints=${waypoint.latitude},${waypoint.longitude}&travelmode=driving';
    } else {
      url =
          'https://www.google.com/maps/dir/?api=1&origin=${origin.latitude},${origin.longitude}&destination=${dest.latitude},${dest.longitude}&travelmode=driving';
    }

    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Error launching native maps: $e');
    }
  }

  /// Phone call helper
  Future<void> _callCustomer(String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (clean.isEmpty) return;
    final uri = Uri.parse('tel:$clean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  String _getTileUrl() {
    if (_mapLayer == 'satellite') {
      return 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
    }
    return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(orderNavigationProvider);
    final order = widget.order;
    final orderId = order['id']?.toString() ?? 'Order';
    final customerName = order['customer_name'] ?? order['full_name'] ?? 'Customer';
    final customerPhone = order['phone_number'] ?? order['customer_phone'] ?? '';

    final currentStep = _routeSteps.isNotEmpty && _currentStepIndex < _routeSteps.length
        ? _routeSteps[_currentStepIndex]
        : null;

    final roadKm = _totalDistanceMeters > 0 ? (_totalDistanceMeters / 1000.0) : widget.deliveryDistanceKm;
    final roadMins = _totalDurationSecs > 0 ? (_totalDurationSecs / 60.0).round() : ((roadKm * 2.8).round().clamp(2, 90));

    // Calculate approximate ETA time (e.g. 10:45 PM)
    final etaTime = DateTime.now().add(Duration(minutes: roadMins));
    final etaString = '${etaTime.hour > 12 ? etaTime.hour - 12 : (etaTime.hour == 0 ? 12 : etaTime.hour)}:${etaTime.minute.toString().padLeft(2, '0')} ${etaTime.hour >= 12 ? 'PM' : 'AM'}';

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Stack(
        children: [
          // 1. FULL-SCREEN INTERACTIVE MAP CANVAS
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: widget.destPoint ?? widget.adminPoint,
              initialZoom: 14.5,
              maxZoom: 18.5,
              minZoom: 4.0,
            ),
            children: [
              TileLayer(
                urlTemplate: _getTileUrl(),
                userAgentPackageName: 'com.dovan.groceryapp',
              ),

              // REAL ROAD STREET POLYLINE (Pathao / InDrive Dual-Layer)
              PolylineLayer(
                polylines: [
                  // Outer contrast casing
                  Polyline(
                    points: _roadRoutePoints.isNotEmpty
                        ? _roadRoutePoints
                        : [widget.adminPoint, if (widget.destPoint != null) widget.destPoint!],
                    strokeWidth: 7.0,
                    color: const Color(0xFF064E3B).withValues(alpha: 0.85),
                  ),
                  // Inner vibrant neon emerald road line
                  Polyline(
                    points: _roadRoutePoints.isNotEmpty
                        ? _roadRoutePoints
                        : [widget.adminPoint, if (widget.destPoint != null) widget.destPoint!],
                    strokeWidth: 4.5,
                    color: const Color(0xFF10B981),
                  ),
                  // Fraud discrepancy line (if buyer GPS far from destination)
                  if (widget.devicePoint != null && widget.destPoint != null && widget.isFraudFlagged)
                    Polyline(
                      points: [widget.devicePoint!, widget.destPoint!],
                      strokeWidth: 2.5,
                      color: const Color(0xFFE11D48),
                    ),
                ],
              ),

              // MARKERS
              MarkerLayer(
                markers: [
                  // Stop A: Admin Fulfillment Hub
                  Marker(
                    point: widget.adminPoint,
                    width: 140,
                    height: 52,
                    alignment: Alignment.topCenter,
                    child: _buildWaypointMarker(
                      label: 'A: Store Hub',
                      color: const Color(0xFF16A34A),
                      icon: Icons.storefront_rounded,
                    ),
                  ),

                  // Stop B: Orderer User Device GPS (if present)
                  if (widget.devicePoint != null)
                    Marker(
                      point: widget.devicePoint!,
                      width: 150,
                      height: 52,
                      alignment: Alignment.topCenter,
                      child: _buildWaypointMarker(
                        label: 'B: Buyer GPS',
                        color: const Color(0xFF2563EB),
                        icon: Icons.phonelink_ring_rounded,
                      ),
                    ),

                  // Stop C: Delivery Destination
                  if (widget.destPoint != null)
                    Marker(
                      point: widget.destPoint!,
                      width: 150,
                      height: 52,
                      alignment: Alignment.topCenter,
                      child: _buildWaypointMarker(
                        label: 'C: Drop-off',
                        color: const Color(0xFFE11D48),
                        icon: Icons.location_on_rounded,
                      ),
                    ),

                  // Active Moving Courier / Delivery Marker (During Simulation)
                  if (_simulatedCurrentPosition != null)
                    Marker(
                      point: _simulatedCurrentPosition!,
                      width: 44,
                      height: 44,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF10B981).withValues(alpha: 0.5),
                              blurRadius: 12,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.navigation_rounded, color: Colors.white, size: 22),
                      ),
                    ),
                ],
              ),
            ],
          ),

          // 2. TOP GOOGLE MAPS STYLE NAVIGATION GUIDANCE BANNER
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Column(
                children: [
                  // Google Maps Turn Instruction Card
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      border: Border.all(color: const Color(0xFF334155), width: 1),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        // Maneuver Icon
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: const Color(0xFF16A34A),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF16A34A).withValues(alpha: 0.4),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: Icon(
                            currentStep?.icon ?? Icons.navigation_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 14),

                        // Maneuver Text & Distance
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_isLoadingRoute) ...[
                                Text(
                                  'Calculating Kathmandu Street Route...',
                                  style: GoogleFonts.outfit(
                                    fontSize: 14,
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ] else if (currentStep != null) ...[
                                Text(
                                  currentStep.formattedDistance,
                                  style: GoogleFonts.outfit(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF4ADE80),
                                    height: 1.1,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  currentStep.instruction,
                                  style: GoogleFonts.outfit(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ] else ...[
                                Text(
                                  '${roadKm.toStringAsFixed(1)} km to Drop-off',
                                  style: GoogleFonts.outfit(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  widget.destAddress,
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    color: const Color(0xFF94A3B8),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),

                        // Audio/Mute Toggle
                        IconButton(
                          onPressed: () {
                            ref.read(orderNavigationProvider.notifier).toggleMuted();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(_isMuted ? 'Audio Guidance Muted' : 'Audio Guidance Active'),
                                duration: const Duration(seconds: 1),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          icon: Icon(
                            _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                            color: Colors.white70,
                            size: 22,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. FLOATING ACTION BUTTONS (Back, Satellite, Recenter, Steps)
          PositionBarFloating(
            onBack: () => Navigator.of(context).pop(),
            mapLayer: _mapLayer,
            onToggleLayer: () {
              ref.read(orderNavigationProvider.notifier).toggleMapLayer();
            },
            onRecenter: _fitRoute,
            onToggleSteps: () {
              ref.read(orderNavigationProvider.notifier).toggleStepsSheet();
            },
            stepsCount: _routeSteps.length,
          ),

          // 4. BOTTOM GOOGLE MAPS NAVIGATION CARD & ACTIONS
          Align(
            alignment: Alignment.bottomCenter,
            child: _buildBottomNavigationSheet(
              orderId: orderId,
              customerName: customerName,
              customerPhone: customerPhone,
              roadKm: roadKm,
              roadMins: roadMins,
              etaString: etaString,
            ),
          ),

          // 5. EXPANDABLE TURN-BY-TURN STEPS OVERLAY (When toggled)
          if (_showStepsSheet)
            Positioned.fill(
              child: GestureDetector(
                onTap: () => ref.read(orderNavigationProvider.notifier).setShowStepsSheet(false),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.5),
                  alignment: Alignment.bottomCenter,
                  child: GestureDetector(
                    onTap: () {}, // Prevent dismissal when tapping the sheet
                    child: _buildStepsListSheet(),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Marker widget for Stops A, B, C with high-contrast pill
  Widget _buildWaypointMarker({
    required String label,
    required Color color,
    required IconData icon,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 12),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  style: GoogleFonts.outfit(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 2,
          height: 8,
          color: color,
        ),
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 1.5),
          ),
        ),
      ],
    );
  }

  /// Bottom Google Maps / InDrive Navigation Sheet
  Widget _buildBottomNavigationSheet({
    required String orderId,
    required String customerName,
    required String customerPhone,
    required double roadKm,
    required int roadMins,
    required String etaString,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Main ETA & Road Distance Row (Google Maps Navigation Style)
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$roadMins',
                style: GoogleFonts.outfit(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF15803D),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'min',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF15803D),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '•  ${roadKm.toStringAsFixed(1)} km',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF475569),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '•  ETA $etaString',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          ),

          // Route subtitle
          Text(
            'Fastest route via Kathmandu street network',
            style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF64748B)),
          ),
          const SizedBox(height: 12),

          // Waypoints Summary Strip (A -> B -> C)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                _buildWaypointDot(const Color(0xFF16A34A), 'Store Hub'),
                _buildDotConnector(),
                _buildWaypointDot(
                  const Color(0xFF2563EB),
                  widget.devicePoint != null ? 'Buyer GPS' : 'No GPS',
                ),
                _buildDotConnector(),
                _buildWaypointDot(const Color(0xFFE11D48), 'Drop-off'),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Recipient Contact & Action Row
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customerName,
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      widget.destAddress,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: const Color(0xFF64748B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (customerPhone.isNotEmpty) ...[
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF185B3A),
                    side: const BorderSide(color: Color(0xFF86EFAC)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _callCustomer(customerPhone),
                  icon: const Icon(Icons.call_rounded, size: 15),
                  label: Text('Call', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
          const SizedBox(height: 14),

          // PRIMARY BUTTONS: Start Navigation Simulation vs Open Native Google Maps
          Row(
            children: [
              // Start / Pause Live Route Simulation
              Expanded(
                flex: 3,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isNavigating ? const Color(0xFFE11D48) : const Color(0xFF185B3A),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _toggleLiveNavigationSimulation,
                  icon: Icon(_isNavigating ? Icons.pause_rounded : Icons.navigation_rounded, size: 18),
                  label: Text(
                    _isNavigating ? 'Pause Navigation' : 'Start Live Navigation',
                    style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Open in Native Google Maps App
              Expanded(
                flex: 2,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0F172A),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _launchNativeGoogleMaps,
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: Text(
                    'Google Maps',
                    style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWaypointDot(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          text,
          style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF334155)),
        ),
      ],
    );
  }

  Widget _buildDotConnector() {
    return Expanded(
      child: Container(
        height: 1.5,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        color: const Color(0xFFCBD5E1),
      ),
    );
  }

  /// Turn-by-Turn Steps Sheet (Expandable)
  Widget _buildStepsListSheet() {
    return Container(
      width: double.infinity,
      height: MediaQuery.of(context).size.height * 0.65,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Turn-by-Turn Guidance',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      '${_routeSteps.length} street maneuvers • Kathmandu Network',
                      style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF64748B)),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                  onPressed: () => ref.read(orderNavigationProvider.notifier).setShowStepsSheet(false),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          Expanded(
            child: _routeSteps.isEmpty
                ? Center(
                    child: Text(
                      'No turn steps available for this route',
                      style: GoogleFonts.outfit(color: const Color(0xFF94A3B8)),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _routeSteps.length,
                    separatorBuilder: (context, index) => const Divider(height: 16, color: Color(0xFFF1F5F9)),
                    itemBuilder: (ctx, idx) {
                      final step = _routeSteps[idx];
                      final isPassed = idx < _currentStepIndex;
                      final isCurrent = idx == _currentStepIndex;

                      return InkWell(
                        onTap: () {
                          ref.read(orderNavigationProvider.notifier).selectStep(idx);
                          _mapController.move(step.location, 16.0);
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            color: isCurrent ? const Color(0xFFDCFCE7) : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: isCurrent
                                      ? const Color(0xFF16A34A)
                                      : (isPassed ? const Color(0xFFCBD5E1) : const Color(0xFFF1F5F9)),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  step.icon,
                                  size: 20,
                                  color: isCurrent ? Colors.white : const Color(0xFF334155),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      step.instruction,
                                      style: GoogleFonts.outfit(
                                        fontSize: 13.5,
                                        fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
                                        color: isCurrent ? const Color(0xFF15803D) : const Color(0xFF0F172A),
                                      ),
                                    ),
                                    Text(
                                      step.streetName,
                                      style: GoogleFonts.outfit(
                                        fontSize: 11.5,
                                        color: const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                step.formattedDistance,
                                style: GoogleFonts.outfit(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF475569),
                                ),
                              ),
                            ],
                          ),
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
typedef AdminOrderNavigationPage = OrderNavigationPage;
