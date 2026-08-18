import 'package:flutter/widgets.dart';

import 'lat_lng.dart';
import 'map_marker.dart';

/// Provider-agnostic map abstraction. Screens depend only on this - swapping
/// the mock implementation for a real SDK (Google Maps/Mapbox) later means
/// writing one new subclass, not touching any screen.
abstract class MapWidget extends StatelessWidget {
  const MapWidget({
    super.key,
    required this.center,
    this.markers = const [],
    this.onTap,
  });

  final LatLng center;
  final List<MapMarker> markers;
  final ValueChanged<LatLng>? onTap;
}
