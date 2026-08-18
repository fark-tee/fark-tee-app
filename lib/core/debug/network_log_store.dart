import 'package:flutter/foundation.dart';

import 'network_log_entry.dart';

/// In-memory history of API calls for the in-app network inspector. A
/// process-wide singleton (rather than something threaded through
/// `MultiProvider`) since debug tooling like this needs to be reachable from
/// both the Dio interceptor deep in `ApiClient` and the floating debug button
/// overlaid above the whole app, with no natural shared ancestor between them.
class NetworkLogStore extends ChangeNotifier {
  NetworkLogStore._();

  static final NetworkLogStore instance = NetworkLogStore._();

  /// Caps memory use - old calls fall off once a debugging session has been
  /// running a while.
  static const _maxEntries = 200;

  final List<NetworkLogEntry> _entries = [];

  List<NetworkLogEntry> get entries => List.unmodifiable(_entries);

  void addRequest(NetworkLogEntry entry) {
    _entries.insert(0, entry);
    if (_entries.length > _maxEntries) _entries.removeLast();
    notifyListeners();
  }

  void complete(
    String id, {
    int? statusCode,
    Object? responseBody,
    String? errorMessage,
    Duration? duration,
  }) {
    final index = _entries.indexWhere((e) => e.id == id);
    if (index == -1) return;
    final entry = _entries[index];
    entry.statusCode = statusCode;
    entry.responseBody = responseBody;
    entry.errorMessage = errorMessage;
    entry.duration = duration;
    notifyListeners();
  }

  void clear() {
    _entries.clear();
    notifyListeners();
  }
}
