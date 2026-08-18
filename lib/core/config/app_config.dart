import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart' show dotenv;

/// Central app configuration: backend base URL and the deeplink scheme
/// registered natively (see AndroidManifest.xml's CallbackActivity) that the
/// backend's Google OAuth callback redirects back to.
class AppConfig {
  AppConfig._();

  /// Override at build time with:
  /// flutter run --dart-define=API_BASE_URL=https://api.example.com
  ///
  /// Takes priority over the .env value below, which itself defaults to an
  /// ngrok tunnel to the local backend, since Google rejects OAuth redirects
  /// to loopback addresses (localhost/10.0.2.2) - the callback the emulator's
  /// browser lands on must be publicly reachable. Update .env (or pass
  /// --dart-define) whenever the tunnel URL changes.
  static const _apiBaseUrlOverride = String.fromEnvironment('API_BASE_URL');

  /// Backend base URL. Falls back to a per-platform loopback address if
  /// neither the dart-define override nor .env's API_BASE_URL is set -
  /// "localhost" does not mean the host machine on every target:
  /// - Android emulator aliases the host's loopback as 10.0.2.2, not
  ///   localhost (localhost is the emulated device itself).
  /// - iOS simulator and desktop share the host's network, so localhost
  ///   works there.
  static String get apiBaseUrl {
    if (_apiBaseUrlOverride.isNotEmpty) return _apiBaseUrlOverride;
    final envValue = dotenv.maybeGet('API_BASE_URL');
    if (envValue != null && envValue.isNotEmpty) return envValue;
    if (!kIsWeb && Platform.isAndroid) return 'http://10.0.2.2:8080';
    return 'http://localhost:8080';
  }

  /// Must match a prefix in the backend's ALLOWED_REDIRECT_PREFIXES env var.
  static const deeplinkScheme = 'farktee';
  static const callbackUri = '$deeplinkScheme://auth/callback';
}
