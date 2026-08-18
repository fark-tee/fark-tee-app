import '../widgets/map/lat_lng.dart';

/// A single place-search or reverse-geocode result. Provider-agnostic, same
/// spirit as `MapWidget` - screens depend on this, not on Nominatim's
/// response shape directly.
class PlaceResult {
  const PlaceResult({
    required this.name,
    required this.address,
    required this.position,
  });

  final String name;
  final String address;
  final LatLng position;
}
