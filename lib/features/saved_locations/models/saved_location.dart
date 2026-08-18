import '../../../core/widgets/map/lat_lng.dart';

/// Mirrors the backend's `SavedLocationResponse` schema (docs/openapi.yaml).
class SavedLocation {
  const SavedLocation({
    required this.id,
    required this.userId,
    required this.name,
    required this.position,
  });

  factory SavedLocation.fromJson(Map<String, dynamic> json) {
    return SavedLocation(
      id: json['id'] as String,
      userId: json['userId'] as String,
      name: json['name'] as String,
      position: LatLng(
        (json['lat'] as num).toDouble(),
        (json['lng'] as num).toDouble(),
      ),
    );
  }

  final String id;
  final String userId;
  final String name;
  final LatLng position;
}
