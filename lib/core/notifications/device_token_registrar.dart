import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../features/auth/auth_controller.dart';
import '../../features/auth/auth_state.dart';
import 'device_token_repository.dart';

/// Registers this device's FCM token with the backend once the user is
/// authenticated (mirroring how `LocationService` only asks for its
/// permission lazily, at the point a feature actually needs it, rather than
/// unconditionally at raw app startup - here that point is "we have a
/// signed-in user to register a push token for"), and keeps it fresh on
/// token rotation via [FirebaseMessaging.onTokenRefresh].
///
/// Every failure here is caught and logged, never rethrown: Firebase may
/// still be running on placeholder config (no real project wired up yet),
/// and a push-token registration failure must never block sign-in or crash
/// the app.
class DeviceTokenRegistrar {
  DeviceTokenRegistrar({
    required DeviceTokenRepository deviceTokenRepository,
    required AuthController authController,
  }) : _repository = deviceTokenRepository,
       _authController = authController {
    _authController.addListener(_onAuthChanged);
    FirebaseMessaging.instance.onTokenRefresh.listen(
      _postToken,
      onError: (Object e) => debugPrint('[nudge] onTokenRefresh stream error: $e'),
    );
    // Covers the case where bootstrap() resolves to `authenticated` before
    // this registrar is constructed (e.g. a fast local-storage read on
    // startup finishing ahead of main()'s next line).
    if (_authController.status == AuthStatus.authenticated) {
      _registeredForThisSession = true;
      _registerCurrentToken();
    }
  }

  final DeviceTokenRepository _repository;
  final AuthController _authController;

  /// Guards against re-registering on every unrelated `notifyListeners()`
  /// call while already authenticated, while still re-registering after a
  /// sign-out/sign-in cycle.
  bool _registeredForThisSession = false;

  void _onAuthChanged() {
    if (_authController.status == AuthStatus.authenticated) {
      if (_registeredForThisSession) return;
      _registeredForThisSession = true;
      _registerCurrentToken();
    } else if (_authController.status == AuthStatus.unauthenticated) {
      _registeredForThisSession = false;
    }
  }

  Future<void> _registerCurrentToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      await _postToken(token);
    } catch (e) {
      debugPrint('[nudge] failed to get/register FCM token: $e');
    }
  }

  Future<void> _postToken(String token) async {
    try {
      await _repository.registerToken(token);
    } catch (e) {
      debugPrint('[nudge] failed to POST device token: $e');
    }
  }
}
