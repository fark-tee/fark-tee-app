import '../widgets/map/lat_lng.dart';
import 'place_result.dart';

/// Place search/geocoding. `NominatimPlacesRepository` is the only
/// implementation - swapping providers (Google Places, Mapbox, ...) later
/// means a new implementation of this interface, not screen changes.
abstract class PlacesRepository {
  /// Free-text search, e.g. "Nobu Downtown" - empty list on no matches or
  /// network failure (callers shouldn't crash the wizard over a flaky
  /// third-party geocoder).
  Future<List<PlaceResult>> search(String query);

  /// Looks up the place at a tapped map point. Null if nothing resolves.
  Future<PlaceResult?> reverseGeocode(LatLng point);
}
