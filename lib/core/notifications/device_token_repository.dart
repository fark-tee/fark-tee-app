import 'dart:io' show Platform;

import '../api/api_client.dart';

/// Registers this device's FCM token with the backend, mirroring the plain
/// dio-based repository style used elsewhere in `core`/`features` (no
/// retrofit/codegen).
class DeviceTokenRepository {
  DeviceTokenRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<void> registerToken(String token) async {
    await _apiClient.dio.post<void>(
      '/v1/device-tokens',
      data: {'token': token, 'platform': Platform.isAndroid ? 'ANDROID' : 'IOS'},
    );
  }
}
