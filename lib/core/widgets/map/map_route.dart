import 'package:flutter/material.dart';

import 'lat_lng.dart';

/// A road-following path drawn on a [GoogleMapWidget], decoded from an
/// OSRM-computed polyline (see `decodePolyline`) - e.g. a member's route from
/// their trip's starting position to the meetup venue (depart) or to their
/// chosen destination (return).
class MapRoute {
  const MapRoute({required this.id, required this.points, required this.color});

  final String id;
  final List<LatLng> points;

  /// Distinguishes each member's route on the map - callers assign this
  /// per-user (e.g. a hash-based palette pick) so two members' routes are
  /// never confused with each other.
  final Color color;
}
