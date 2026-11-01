// Map helpers, constants, and navigation utilities for order map widgets.
// Extracted from orderMapWidget.dart to reduce its size.
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

/// Central Hub / Admin Warehouse Coordinates (Default: Dovan Main Fulfillment Hub, Kathmandu)
const LatLng kDovanAdminHub = LatLng(27.7172, 85.3240);
const String kDovanAdminHubAddress = 'Dovan Central Fulfillment Hub, Kathmandu';

/// Formatter helper for double
double? toDouble(dynamic val) {
  if (val == null) return null;
  if (val is num) return val.toDouble();
  return double.tryParse(val.toString());
}

/// Helper to calculate distance in km
double calcDistanceKm(LatLng a, LatLng b) {
  const distance = Distance();
  return distance.as(LengthUnit.Meter, a, b) / 1000.0;
}

/// Helper to launch navigation in Google Maps with Origin, Waypoints, and Destination
Future<void> launchGoogleMapsNavigation({
  required LatLng origin,
  required LatLng destination,
  LatLng? waypoint,
}) async {
  String url;
  if (waypoint != null) {
    url =
        'https://www.google.com/maps/dir/?api=1&origin=${origin.latitude},${origin.longitude}&destination=${destination.latitude},${destination.longitude}&waypoints=${waypoint.latitude},${waypoint.longitude}&travelmode=driving';
  } else {
    url =
        'https://www.google.com/maps/dir/?api=1&origin=${origin.latitude},${origin.longitude}&destination=${destination.latitude},${destination.longitude}&travelmode=driving';
  }

  final uri = Uri.parse(url);
  try {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  } catch (e) {
    debugPrint('Could not launch navigation: $e');
  }
}

/// Helper to initiate a phone call
Future<void> launchPhoneCall(String phone) async {
  final clean = phone.replaceAll(RegExp(r'[^0-9+]'), '');
  if (clean.isEmpty) return;
  final uri = Uri.parse('tel:$clean');
  try {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  } catch (e) {
    debugPrint('Could not launch phone: $e');
  }
}

/// Fetch road route from OSRM (Open Source Routing Machine)
Future<Map<String, dynamic>?> fetchRoadRoute(List<LatLng> points) async {
  if (points.length < 2) return null;

  try {
    final coords = points
        .map((p) => '${p.longitude.toStringAsFixed(6)},${p.latitude.toStringAsFixed(6)}')
        .join(';');
    final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/$coords?overview=full&geometries=geojson');
    final res = await http.get(url).timeout(const Duration(seconds: 5));
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      if (data['code'] == 'Ok' && data['routes'] is List && (data['routes'] as List).isNotEmpty) {
        final route = data['routes'][0];
        final geometry = route['geometry'];
        final distanceMeters = (route['distance'] as num?)?.toDouble() ?? 0.0;
        final durationSecs = (route['duration'] as num?)?.toDouble() ?? 0.0;

        if (geometry != null && geometry['coordinates'] is List) {
          final List cList = geometry['coordinates'];
          final roadCoords = cList
              .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
              .toList();

          return {
            'points': roadCoords,
            'distanceKm': distanceMeters / 1000.0,
            'durationMins': (durationSecs / 60).round(),
          };
        }
      }
    }
  } catch (e) {
    debugPrint('OSRM road route fetch error: $e');
  }
  return null;
}
