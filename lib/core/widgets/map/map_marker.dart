import 'lat_lng.dart';

enum MapMarkerType { venue, member, destination }

/// A pin on a [MapWidget]. `label` is the venue name for [MapMarkerType.venue]
/// pins, the member's initials for [MapMarkerType.member] pins, or the saved
/// location's name for [MapMarkerType.destination] pins (a member's "heading
/// home" target).
class MapMarker {
  const MapMarker({
    required this.id,
    required this.position,
    required this.type,
    required this.label,
    this.isCurrentUser = false,
    this.caption,
    this.profileImageUrl,
  });

  final String id;
  final LatLng position;
  final MapMarkerType type;
  final String label;

  /// Draws a red ring around the marker (the current user's own position).
  final bool isCurrentUser;

  /// Small text shown under a member marker, e.g. "8 min".
  final String? caption;

  /// The member's profile photo, shown as the pin itself instead of
  /// [label]/a colored default pin when set.
  final String? profileImageUrl;
}
