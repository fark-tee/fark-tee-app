import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import '../../features/meetups/screens/checkin_alert_screen.dart';
import '../../features/meetups/screens/emergency_alert_screen.dart';
import '../../features/meetups/screens/nudge_alert_screen.dart';
import 'nudge_notification_service.dart';

const String _nudgeDataType = 'nudge';
const String _checkInDataType = 'checkin_request';
const String _checkInEmergencyDataType = 'checkin_emergency';
const String _defaultNudgerName = 'เพื่อนของคุณ';

/// Wires the full FCM nudge lifecycle to the full-screen alert screen:
///
/// - foreground data messages (which never auto-display a system
///   notification) navigate straight there;
/// - a background/killed app resumed by tapping the tray notification
///   navigates there via `onMessageOpenedApp` or `getInitialMessage`;
/// - a fully killed app cold-started via tapping this app's own full-screen
///   local notification is caught by [checkForInitialNudge], via
///   `NudgeNotificationService.getLaunchNudgePayload()`.
///
/// Navigates imperatively on the app's root [Navigator] rather than through
/// a declared go_router route, since this needs to work from contexts (raw
/// FCM callbacks, app-launch checks) that have no `BuildContext` of their
/// own and shouldn't need one.
class NudgeMessagingCoordinator {
  NudgeMessagingCoordinator({
    required NudgeNotificationService notificationService,
    required GlobalKey<NavigatorState> navigatorKey,
  }) : _notificationService = notificationService,
       _navigatorKey = navigatorKey;

  final NudgeNotificationService _notificationService;
  final GlobalKey<NavigatorState> _navigatorKey;

  /// Registers the foreground/background-tap FCM listeners. Call once,
  /// early (e.g. right after `runApp`).
  void initialize() {
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);
  }

  /// Checks both possible "app was launched by tapping a nudge" cold-start
  /// paths - this service's own full-screen local notification, and a raw
  /// FCM notification tap - and navigates to the alert screen if either
  /// applies. Call once, after the first frame (so [_navigatorKey] is
  /// attached).
  ///
  /// NOTE: Android's *automatic* full-screen-intent wake (i.e. the alert
  /// popping up on its own over the lock screen while the app is fully
  /// killed, without the user tapping anything) is best-effort and cannot be
  /// verified in this environment - there is no real Firebase project wired
  /// up yet. Verify on a real device once one exists.
  Future<void> checkForInitialNudge() async {
    try {
      final launchPayload = await _notificationService.getLaunchNudgePayload();
      if (launchPayload == nudgeNotificationPayload) {
        _navigateToNudgeAlert(fromDisplayName: _defaultNudgerName);
        return;
      }
      if (launchPayload == checkInNotificationPayload ||
          launchPayload == checkInEmergencyNotificationPayload) {
        // Neither the meetupId nor the emergency contact fields are carried
        // by the local notification payload (only by the FCM data message
        // below) - if the app was cold started by tapping this local
        // notification specifically, fall through to checking FCM's own
        // initial message for them instead of guessing.
        final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
        if (initialMessage != null) _dispatch(initialMessage.data);
        return;
      }
    } catch (e) {
      debugPrint('[nudge] checkForInitialNudge (local notification) failed: $e');
    }

    try {
      final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) _dispatch(initialMessage.data);
    } catch (e) {
      debugPrint('[nudge] checkForInitialNudge (FCM initial message) failed: $e');
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    // Foreground data-only messages never auto-display a system
    // notification, so jump straight to the full-screen alert - it starts
    // the looping sound itself as soon as it mounts.
    _dispatch(message.data);
  }

  void _handleMessageOpenedApp(RemoteMessage message) {
    _dispatch(message.data);
  }

  void _dispatch(Map<String, dynamic> data) {
    final fromDisplayName = data['fromDisplayName'] as String? ?? _defaultNudgerName;
    switch (data['type']) {
      case _nudgeDataType:
        _navigateToNudgeAlert(fromDisplayName: fromDisplayName);
      case _checkInDataType:
        _navigateToCheckInAlert(
          meetupId: data['meetupId'] as String?,
          fromDisplayName: fromDisplayName,
        );
      case _checkInEmergencyDataType:
        _navigateToEmergencyAlert(
          fromDisplayName: fromDisplayName,
          emergencyContactName: data['emergencyContactName'] as String? ?? '',
          emergencyContactPhone: data['emergencyContactPhone'] as String? ?? '',
        );
    }
  }

  void _navigateToNudgeAlert({required String fromDisplayName}) {
    final navigator = _navigatorKey.currentState;
    if (navigator == null) {
      debugPrint('[nudge] root navigator not attached yet - dropping nudge alert nav');
      return;
    }
    navigator.push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => NudgeAlertScreen(fromDisplayName: fromDisplayName),
      ),
    );
  }

  void _navigateToCheckInAlert({required String? meetupId, required String fromDisplayName}) {
    if (meetupId == null) {
      debugPrint('[checkin] check-in message missing meetupId - dropping alert nav');
      return;
    }
    final navigator = _navigatorKey.currentState;
    if (navigator == null) {
      debugPrint('[checkin] root navigator not attached yet - dropping check-in alert nav');
      return;
    }
    navigator.push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => CheckInAlertScreen(meetupId: meetupId, fromDisplayName: fromDisplayName),
      ),
    );
  }

  void _navigateToEmergencyAlert({
    required String fromDisplayName,
    required String emergencyContactName,
    required String emergencyContactPhone,
  }) {
    final navigator = _navigatorKey.currentState;
    if (navigator == null) {
      debugPrint('[emergency] root navigator not attached yet - dropping emergency alert nav');
      return;
    }
    navigator.push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => EmergencyAlertScreen(
          fromDisplayName: fromDisplayName,
          emergencyContactName: emergencyContactName,
          emergencyContactPhone: emergencyContactPhone,
        ),
      ),
    );
  }
}
