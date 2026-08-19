import 'lat_lng.dart';

/// A line drawn between two or more points on a [GoogleMapWidget], e.g. the
/// straight path from a returning member's live position to their chosen
/// "heading home" destination.
class MapRoute {
  const MapRoute({required this.id, required this.points});

  final String id;
  final List<LatLng> points;
}
