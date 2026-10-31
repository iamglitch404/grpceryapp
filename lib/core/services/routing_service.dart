import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:app/core/models/route_step.dart';

class RouteResult {
  final List<LatLng> points;
  final List<RouteStep> steps;
  final double distanceMeters;
  final double durationSecs;

  const RouteResult({
    required this.points,
    required this.steps,
    required this.distanceMeters,
    required this.durationSecs,
  });
}

/// Service for calculating real-world driving directions and turn-by-turn routing via OSRM.
class RoutingService {
  Future<RouteResult?> fetchRoute(List<LatLng> waypoints, {LatLng? fallbackOrigin}) async {
    if (waypoints.length < 2) return null;

    try {
      final coordsParam = waypoints
          .map((p) => '${p.longitude.toStringAsFixed(6)},${p.latitude.toStringAsFixed(6)}')
          .join(';');

      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/$coordsParam?overview=full&geometries=geojson&steps=true',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['code'] == 'Ok' && data['routes'] is List && (data['routes'] as List).isNotEmpty) {
          final route = data['routes'][0];
          final geometry = route['geometry'];
          final distanceMeters = (route['distance'] as num?)?.toDouble() ?? 0.0;
          final durationSecs = (route['duration'] as num?)?.toDouble() ?? 0.0;

          // Parse full geometry polyline coordinates
          List<LatLng> fullCoords = [];
          if (geometry != null && geometry['coordinates'] is List) {
            final List cList = geometry['coordinates'];
            fullCoords = cList
                .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
                .toList();
          }

          // Parse turn-by-turn routing steps
          final List<RouteStep> steps = [];
          final defaultLocation = fallbackOrigin ?? waypoints.first;

          if (route['legs'] is List) {
            for (final leg in route['legs']) {
              if (leg['steps'] is List) {
                for (final s in leg['steps']) {
                  final maneuver = s['maneuver'] ?? {};
                  final mType = (maneuver['type'] ?? 'continue').toString();
                  final mModifier = maneuver['modifier']?.toString();
                  final mLoc = maneuver['location'] is List
                      ? LatLng((maneuver['location'][1] as num).toDouble(), (maneuver['location'][0] as num).toDouble())
                      : defaultLocation;
                  final sName = (s['name'] ?? '').toString().trim();
                  final sDist = (s['distance'] as num?)?.toDouble() ?? 0.0;
                  final sDur = (s['duration'] as num?)?.toDouble() ?? 0.0;

                  String instructionText;
                  if (mType == 'depart') {
                    instructionText = sName.isNotEmpty ? 'Head on $sName' : 'Start trip from Origin';
                  } else if (mType == 'arrive') {
                    instructionText = 'Arrive at destination';
                  } else if (sName.isNotEmpty) {
                    final direction = mModifier != null ? 'Turn $mModifier' : 'Continue';
                    instructionText = '$direction onto $sName';
                  } else {
                    final direction = mModifier != null ? 'Turn $mModifier' : 'Continue straight';
                    instructionText = direction;
                  }

                  steps.add(RouteStep(
                    instruction: instructionText,
                    streetName: sName.isNotEmpty ? sName : 'Road Segment',
                    distanceMeters: sDist,
                    durationSecs: sDur,
                    maneuverType: mType,
                    modifier: mModifier,
                    location: mLoc,
                  ));
                }
              }
            }
          }

          return RouteResult(
            points: fullCoords.isNotEmpty ? fullCoords : waypoints,
            steps: steps,
            distanceMeters: distanceMeters,
            durationSecs: durationSecs,
          );
        }
      }
    } catch (e) {
      debugPrint('[RoutingService] Error fetching OSRM road steps: $e');
    }
    return null;
  }
}
