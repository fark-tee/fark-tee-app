import '../../../core/api/api_client.dart';
import '../models/saved_location.dart';

/// Talks to the backend's /v1/saved-locations endpoints
/// (docs/openapi.yaml: SavedLocationResponse / SavedLocationsResponse).
class SavedLocationsRepository {
  SavedLocationsRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<SavedLocation>> list() async {
    final response = await _apiClient.dio.get<Map<String, dynamic>>(
      '/v1/saved-locations',
    );
    final locations = (response.data!['savedLocations'] as List<dynamic>?) ?? [];
    return locations.cast<Map<String, dynamic>>().map(SavedLocation.fromJson).toList();
  }

  Future<SavedLocation> get(String id) async {
    final response = await _apiClient.dio.get<Map<String, dynamic>>(
      '/v1/saved-locations/$id',
    );
    return SavedLocation.fromJson(response.data!);
  }

  Future<SavedLocation> create({
    required String name,
    required double lat,
    required double lng,
  }) async {
    final response = await _apiClient.dio.post<Map<String, dynamic>>(
      '/v1/saved-locations',
      data: {'name': name, 'lat': lat, 'lng': lng},
    );
    return SavedLocation.fromJson(response.data!);
  }
}
