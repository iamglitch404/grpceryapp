import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

/// Representation of a real turn-by-turn routing step from OSRM.
class RouteStep {
  final String instruction;
  final String streetName;
  final double distanceMeters;
  final double durationSecs;
  final String maneuverType;
  final String? modifier;
  final LatLng location;

  RouteStep({
    required this.instruction,
    required this.streetName,
    required this.distanceMeters,
    required this.durationSecs,
    required this.maneuverType,
    this.modifier,
    required this.location,
  });

  IconData get icon {
    switch (maneuverType) {
      case 'depart':
        return Icons.navigation_rounded;
      case 'arrive':
        return Icons.flag_rounded;
      case 'roundabout':
      case 'rotary':
        return Icons.roundabout_right_rounded;
      case 'end of road':
      case 'turn':
        if (modifier == 'right' || modifier == 'sharp right') return Icons.turn_right_rounded;
        if (modifier == 'left' || modifier == 'sharp left') return Icons.turn_left_rounded;
        if (modifier == 'slight right') return Icons.fork_right_rounded;
        if (modifier == 'slight left') return Icons.fork_left_rounded;
        if (modifier == 'uturn') return Icons.u_turn_left_rounded;
        return Icons.turn_right_rounded;
      case 'fork':
        return modifier == 'left' ? Icons.fork_left_rounded : Icons.fork_right_rounded;
      default:
        if (modifier == 'right') return Icons.turn_right_rounded;
        if (modifier == 'left') return Icons.turn_left_rounded;
        return Icons.straight_rounded;
    }
  }

  String get formattedDistance {
    if (distanceMeters < 1000) {
      return '${distanceMeters.round()} m';
    }
    return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
  }
}
