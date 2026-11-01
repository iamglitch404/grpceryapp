import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class LocationResult {
  final LatLng point;
  final String address;
  final bool isLive;

  const LocationResult({
    required this.point,
    required this.address,
    required this.isLive,
  });
}

/// Shared device hardware and network geolocation service.
/// Provides device coordinates, IP geolocation fallback, and reverse geocoding.
class LocationService {
  static LatLng? _cachedPoint;
  static String? _cachedAddress;

  static LatLng get defaultPoint => _cachedPoint ?? const LatLng(27.7108, 85.3251);
  static String get defaultAddress => _cachedAddress ?? 'Current Device Location, Kathmandu';

  /// Fetches live location using Device GPS or Network Geolocation + OSM Reverse Geocoding
  static Future<LocationResult> getLiveLocation() async {
    LatLng? detectedPoint;

    // 1. Try Device Hardware GPS via Geolocator
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }

        if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
          final pos = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
            timeLimit: const Duration(seconds: 4),
          );
          detectedPoint = LatLng(pos.latitude, pos.longitude);
        }
      }
    } catch (e) {
      debugPrint('[LocationService] Geolocator attempt failed: $e');
    }

    // 2. Fallback to Network Geolocation via IP if GPS failed or unavailable
    if (detectedPoint == null) {
      try {
        final ipRes = await http
            .get(Uri.parse('https://ipapi.co/json/'))
            .timeout(const Duration(seconds: 4));
        if (ipRes.statusCode == 200) {
          final ipData = jsonDecode(ipRes.body);
          final lat = (ipData['latitude'] as num?)?.toDouble();
          final lon = (ipData['longitude'] as num?)?.toDouble();
          if (lat != null && lon != null) {
            detectedPoint = LatLng(lat, lon);
          }
        }
      } catch (e) {
        debugPrint('[LocationService] IP Geolocation failed: $e');
      }
    }

    // 3. Fallback to default Kathmandu central coordinate if all detection failed
    bool isLive = true;
    if (detectedPoint == null) {
      detectedPoint = defaultPoint;
      isLive = false;
    }

    _cachedPoint = detectedPoint;

    // 4. Reverse Geocoding via OpenStreetMap Nominatim
    String address = await reverseGeocode(detectedPoint);
    _cachedAddress = address;

    return LocationResult(
      point: detectedPoint,
      address: address,
      isLive: isLive,
    );
  }

  /// Reverse geocodes [point] using Nominatim OSM API
  static Future<String> reverseGeocode(LatLng point) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=${point.latitude}&lon=${point.longitude}&zoom=18&addressdetails=1',
      );
      final res = await http.get(url, headers: {
        'User-Agent': 'DovanApp/1.0',
      }).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final displayName = data['display_name'];
        if (displayName != null && displayName.toString().isNotEmpty) {
          return displayName.toString();
        }
      }
    } catch (e) {
      debugPrint('[LocationService] Reverse geocoding error: $e');
    }
    return '${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}';
  }
}
