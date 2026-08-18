import 'package:dio/dio.dart';

import '../widgets/map/lat_lng.dart';
import 'place_result.dart';
import 'places_repository.dart';

/// Free OSM geocoding via the public Nominatim API. Nominatim's usage policy
/// (https://operations.osmfoundation.org/policies/nominatim/) requires a
/// descriptive User-Agent and asks for no more than ~1 request/second - the
/// call site is expected to debounce keystrokes rather than search on every
/// change. For any real production volume this should point at a
/// self-hosted Nominatim instance instead of the public one.
class NominatimPlacesRepository implements PlacesRepository {
  NominatimPlacesRepository({Dio? dio})
    : _dio = dio ??
          Dio(
            BaseOptions(
              baseUrl: 'https://nominatim.openstreetmap.org',
              headers: {'User-Agent': 'fark-tee-app (Flutter meetup scheduler)'},
            ),
          );

  final Dio _dio;

  @override
  Future<List<PlaceResult>> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    try {
      final response = await _dio.get<List<dynamic>>(
        '/search',
        queryParameters: {
          'q': trimmed,
          'format': 'jsonv2',
          'limit': 8,
          'addressdetails': 1,
        },
      );
      return (response.data ?? [])
          .map((json) => _toPlaceResult(json as Map<String, dynamic>))
          .toList();
    } catch (_) {
      // A flaky/unreachable geocoder shouldn't crash the wizard - just
      // surface no results, same as a genuine no-match search.
      return [];
    }
  }

  @override
  Future<PlaceResult?> reverseGeocode(LatLng point) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/reverse',
        queryParameters: {
          'lat': point.latitude,
          'lon': point.longitude,
          'format': 'jsonv2',
        },
      );
      final data = response.data;
      if (data == null || data['error'] != null) return null;
      return _toPlaceResult(data);
    } catch (_) {
      return null;
    }
  }

  PlaceResult _toPlaceResult(Map<String, dynamic> json) {
    final displayName = json['display_name'] as String? ?? 'ไม่ทราบชื่อสถานที่';
    final shortName = (json['name'] as String?)?.trim();
    final name = (shortName != null && shortName.isNotEmpty)
        ? shortName
        : displayName.split(',').first.trim();

    return PlaceResult(
      name: name,
      address: displayName,
      position: LatLng(
        double.parse(json['lat'] as String),
        double.parse(json['lon'] as String),
      ),
    );
  }
}
