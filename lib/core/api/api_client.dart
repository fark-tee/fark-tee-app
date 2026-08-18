import 'package:dio/dio.dart';

import '../auth/auth_models.dart';
import '../auth/token_storage.dart';
import '../config/app_config.dart';

/// Wraps a Dio instance that automatically attaches the stored access token
/// to every request and, on a 401, silently redeems the refresh token once
/// and retries before giving up.
class ApiClient {
  ApiClient({TokenStorage? tokenStorage})
    : _tokenStorage = tokenStorage ?? TokenStorage(),
      _plainDio = Dio(BaseOptions(baseUrl: AppConfig.apiBaseUrl)),
      dio = Dio(BaseOptions(baseUrl: AppConfig.apiBaseUrl)) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final accessToken = await _tokenStorage.readAccessToken();
          if (accessToken != null) {
            options.headers['Authorization'] = 'Bearer $accessToken';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          final alreadyRetried = error.requestOptions.extra['retried'] == true;
          if (error.response?.statusCode != 401 || alreadyRetried) {
            handler.next(error);
            return;
          }

          try {
            final refreshed = await _refresh();
            await _tokenStorage.save(refreshed);

            final retryOptions = error.requestOptions
              ..headers['Authorization'] = 'Bearer ${refreshed.accessToken}'
              ..extra['retried'] = true;

            handler.resolve(await dio.fetch(retryOptions));
          } catch (_) {
            await _tokenStorage.clear();
            onSessionExpired?.call();
            handler.next(error);
          }
        },
      ),
    );
  }

  late final Dio dio;

  /// Unauthenticated client used only for /v1/auth/refresh, to avoid
  /// recursing back into the interceptor above.
  final Dio _plainDio;
  final TokenStorage _tokenStorage;

  /// Invoked when the stored refresh token itself is rejected by the
  /// backend, so the app can fall back to the sign-in screen.
  void Function()? onSessionExpired;

  Future<TokenPair> _refresh() async {
    final refreshToken = await _tokenStorage.readRefreshToken();
    if (refreshToken == null) {
      throw StateError('no refresh token available');
    }

    final response = await _plainDio.post<Map<String, dynamic>>(
      '/v1/auth/refresh',
      data: {'refreshToken': refreshToken},
    );

    final body = response.data!;
    return TokenPair(
      accessToken: body['accessToken'] as String,
      refreshToken: body['refreshToken'] as String,
    );
  }
}
