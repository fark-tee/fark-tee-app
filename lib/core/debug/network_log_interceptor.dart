import 'package:dio/dio.dart';

import 'network_log_entry.dart';
import 'network_log_store.dart';

/// Records every request/response/error a [Dio] instance makes into
/// [NetworkLogStore], for the in-app network inspector. Debug-only - see
/// where this is attached in `ApiClient`.
class NetworkLogInterceptor extends Interceptor {
  NetworkLogInterceptor(this._store);

  final NetworkLogStore _store;

  static const _idKey = '_networkLogId';
  static const _startKey = '_networkLogStart';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final start = DateTime.now();
    final id = '${start.microsecondsSinceEpoch}-${identityHashCode(options)}';
    options.extra[_idKey] = id;
    options.extra[_startKey] = start;

    _store.addRequest(
      NetworkLogEntry(
        id: id,
        method: options.method,
        url: options.uri.toString(),
        requestHeaders: options.headers,
        requestBody: options.data,
        startedAt: start,
      ),
    );
    handler.next(options);
  }

  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    _complete(response.requestOptions, statusCode: response.statusCode, body: response.data);
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _complete(
      err.requestOptions,
      statusCode: err.response?.statusCode,
      body: err.response?.data,
      errorMessage: err.message ?? err.type.name,
    );
    handler.next(err);
  }

  void _complete(
    RequestOptions options, {
    int? statusCode,
    Object? body,
    String? errorMessage,
  }) {
    final id = options.extra[_idKey] as String?;
    if (id == null) return;

    final start = options.extra[_startKey] as DateTime?;
    _store.complete(
      id,
      statusCode: statusCode,
      responseBody: body,
      errorMessage: errorMessage,
      duration: start == null ? null : DateTime.now().difference(start),
    );
  }
}
