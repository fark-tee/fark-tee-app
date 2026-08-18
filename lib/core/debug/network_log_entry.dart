/// One recorded HTTP call, from request fired to response/error settled.
/// Mutable fields are filled in once the call completes - mirrors the app's
/// existing convention for models updated in place (e.g. `MeetupMember`).
class NetworkLogEntry {
  NetworkLogEntry({
    required this.id,
    required this.method,
    required this.url,
    required this.requestHeaders,
    required this.startedAt,
    this.requestBody,
  });

  final String id;
  final String method;
  final String url;
  final Map<String, dynamic> requestHeaders;
  final Object? requestBody;
  final DateTime startedAt;

  int? statusCode;
  Object? responseBody;
  String? errorMessage;
  Duration? duration;

  bool get isPending => statusCode == null && errorMessage == null;
  bool get isError => errorMessage != null || (statusCode ?? 0) >= 400;
}
