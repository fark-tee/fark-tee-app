import 'lat_lng.dart';

/// A road-following path drawn on a [GoogleMapWidget], decoded from an
/// OSRM-computed polyline (see `decodePolyline`) - e.g. a member's route from
/// their trip's starting position to the meetup venue (depart) or to their
/// chosen destination (return).
class MapRoute {
  const MapRoute({required this.id, required this.points});

  final String id;
  final List<LatLng> points;
}
