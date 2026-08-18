import 'lat_lng.dart';

enum MapMarkerType { venue, member }

/// A pin on a [MapWidget]. `label` is the venue name for [MapMarkerType.venue]
/// pins, or the member's initials for [MapMarkerType.member] pins.
class MapMarker {
  const MapMarker({
    required this.id,
    required this.position,
    required this.type,
    required this.label,
    this.isCurrentUser = false,
    this.caption,
  });

  final String id;
  final LatLng position;
  final MapMarkerType type;
  final String label;

  /// Draws a red ring around the marker (the current user's own position).
  final bool isCurrentUser;

  /// Small text shown under a member marker, e.g. "8 min".
  final String? caption;
}
