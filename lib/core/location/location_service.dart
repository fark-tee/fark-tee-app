import 'package:geolocator/geolocator.dart';

import '../widgets/map/lat_lng.dart';

/// Thin wrapper around `geolocator` so repositories depend on this app's own
/// [LatLng] rather than leaking a location-plugin type into the data layer.
class LocationService {
  /// Requests permission if needed and returns the device's current
  /// position. Throws a [LocationServiceException] if location services are
  /// disabled or permission is denied, so callers can show a clear message
  /// instead of a raw platform error.
  Future<LatLng> getCurrentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationServiceException(
        'Location services are turned off. Enable them to share your position.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw const LocationServiceException(
        'Location permission is required to share your position.',
      );
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
    return LatLng(position.latitude, position.longitude);
  }
}

class LocationServiceException implements Exception {
  const LocationServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}
