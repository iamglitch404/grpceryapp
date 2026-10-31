import 'package:latlong2/latlong.dart';
import 'package:app/core/services/location_service.dart';

typedef AdminLocationResult = LocationResult;

/// Administrative wrapper over shared [LocationService].
class LiveLocationService {
  static Future<AdminLocationResult> getLiveLocation() => LocationService.getLiveLocation();
  static LatLng get defaultPoint => LocationService.defaultPoint;
  static String get defaultAddress => LocationService.defaultAddress;
}

// Retain alias for backward compatibility
typedef AdminLiveLocationService = LiveLocationService;
