import 'package:geolocator/geolocator.dart';
import '../utils/constants.dart';

class GeofenceResult {
  final bool isInsideOffice;
  final double distanceMeters;
  final Position position;

  GeofenceResult({
    required this.isInsideOffice,
    required this.distanceMeters,
    required this.position,
  });
}

class LocationService {
  /// Requests permission (if needed) and returns the device's current position.
  Future<Position> getCurrentPosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled. Please enable GPS.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permission denied.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'Location permission permanently denied. Enable it in app settings.',
      );
    }

    return Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  /// Checks whether the current position falls within the office geofence.
  Future<GeofenceResult> checkOfficeGeofence() async {
    final position = await getCurrentPosition();

    final distance = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      OfficeConfig.officeLatitude,
      OfficeConfig.officeLongitude,
    );

    return GeofenceResult(
      isInsideOffice: distance <= OfficeConfig.allowedRadiusMeters,
      distanceMeters: distance,
      position: position,
    );
  }
}
