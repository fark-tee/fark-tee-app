import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Payload string stamped on every notification this service shows, so
/// tap-detection code (foreground callback, cold-start launch details) can
/// tell a nudge alert apart from any other local/remote notification without
/// having to round-trip through FCM data again.
const String nudgeNotificationPayload = 'nudge_alert';

/// Same idea as [nudgeNotificationPayload], for a "friend heading home wants
/// to know you're okay" check-in request.
const String checkInNotificationPayload = 'checkin_alert';

/// Same idea as [nudgeNotificationPayload], for a "friend answered not okay"
/// emergency broadcast.
const String checkInEmergencyNotificationPayload = 'checkin_emergency_alert';

/// Same idea as [nudgeNotificationPayload], for a "you've been invited to a
/// meetup" notification.
const String partyInviteNotificationPayload = 'party_invite_alert';

/// Runs when a notification this app posted is tapped while the Dart VM
/// backing the plugin call is a background isolate (i.e. the app process
/// wasn't already running in the foreground). There is no live widget tree
/// to navigate with from here, so this is intentionally just a log line -
/// actual navigation for that case is handled once the app's normal Flutter
/// engine spins back up, via
/// `NudgeNotificationService.getLaunchNudgePayload()` /
/// `getNotificationAppLaunchDetails()` called from app startup.
///
/// Must stay a top-level (or static) function annotated `@pragma('vm:entry-
/// point')`, per flutter_local_notifications' background-isolate contract.
@pragma('vm:entry-point')
void nudgeNotificationBackgroundTapHandler(NotificationResponse response) {
  debugPrint('[nudge] background notification tap: payload=${response.payload}');
}

/// Wraps [FlutterLocalNotificationsPlugin] for the one thing this app uses
/// local notifications for: a max-priority, full-screen-intent "your friend
/// nudged you" alert. Deliberately has no app-wide singleton/DI dependency
/// beyond the plugin itself, so a fresh instance can safely be constructed
/// inside the FCM background-message isolate (see
/// `_firebaseMessagingBackgroundHandler` in `main.dart`), which cannot reach
/// this app's normal `provider` tree.
class NudgeNotificationService {
  NudgeNotificationService() : plugin = FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin plugin;

  static const String channelId = 'nudge_channel';
  static const String channelName = 'แจ้งเตือนเร่งเพื่อน';
  static const String channelDescription =
      'แจ้งเตือนเต็มจอเมื่อเพื่อนเร่งให้คุณรีบมาที่นัด';

  static const AndroidNotificationChannel _androidChannel = AndroidNotificationChannel(
    channelId,
    channelName,
    description: channelDescription,
    importance: Importance.max,
  );

  static const String checkInChannelId = 'checkin_channel';
  static const String checkInChannelName = 'แจ้งเตือนเช็คอิน';
  static const String checkInChannelDescription =
      'แจ้งเตือนเต็มจอเมื่อเพื่อนถามว่าคุณโอเคไหม';

  static const AndroidNotificationChannel _checkInAndroidChannel = AndroidNotificationChannel(
    checkInChannelId,
    checkInChannelName,
    description: checkInChannelDescription,
    importance: Importance.max,
  );

  static const String emergencyChannelId = 'checkin_emergency_channel';
  static const String emergencyChannelName = 'แจ้งเตือนฉุกเฉิน';
  static const String emergencyChannelDescription =
      'แจ้งเตือนเต็มจอเมื่อเพื่อนตอบว่าไม่โอเคระหว่างเช็คอิน';

  static const AndroidNotificationChannel _emergencyAndroidChannel = AndroidNotificationChannel(
    emergencyChannelId,
    emergencyChannelName,
    description: emergencyChannelDescription,
    importance: Importance.max,
  );

  static const String inviteChannelId = 'party_invite_channel';
  static const String inviteChannelName = 'แจ้งเตือนคำเชิญตี้';
  static const String inviteChannelDescription = 'แจ้งเตือนเมื่อมีคนเชิญคุณเข้าร่วมตี้';

  static const AndroidNotificationChannel _inviteAndroidChannel = AndroidNotificationChannel(
    inviteChannelId,
    inviteChannelName,
    description: inviteChannelDescription,
    importance: Importance.high,
  );

  bool _initialized = false;

  /// Sets up the plugin, creates the Android notification channel, and
  /// requests runtime notification permission. Safe to call multiple times
  /// (e.g. once from `main()` and again defensively elsewhere) - only the
  /// first call does any work. Never throws: any failure here (most likely
  /// because Firebase/notifications aren't really configured yet) is logged
  /// and swallowed so it can't block app startup.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(android: androidInit, iOS: iosInit);

    try {
      await plugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (response) {
          debugPrint('[nudge] foreground notification tap: payload=${response.payload}');
        },
        onDidReceiveBackgroundNotificationResponse: nudgeNotificationBackgroundTapHandler,
      );

      final androidPlugin = plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(_androidChannel);
      await androidPlugin?.createNotificationChannel(_checkInAndroidChannel);
      await androidPlugin?.createNotificationChannel(_emergencyAndroidChannel);
      await androidPlugin?.createNotificationChannel(_inviteAndroidChannel);
      // Android 13+ (API 33) requires this explicit runtime request for
      // POST_NOTIFICATIONS - a no-op on older Android versions.
      await androidPlugin?.requestNotificationsPermission();
      // Android 14+ (API 34) gates fullScreenIntent notifications behind
      // this special-access toggle - without it granted, the notification
      // silently degrades to a normal heads-up banner instead of waking a
      // locked screen like an incoming call. There's no runtime dialog for
      // this like POST_NOTIFICATIONS; the plugin opens system Settings for
      // the user to grant it manually.
      await androidPlugin?.requestFullScreenIntentPermission();

      final iosPlugin = plugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      await iosPlugin?.requestPermissions(alert: true, badge: true, sound: true);
    } catch (e, st) {
      debugPrint('[nudge] NudgeNotificationService.initialize failed: $e\n$st');
    }
  }

  /// Shows the "hurry up, your friend nudged you" alert as a max-priority,
  /// full-screen-intent Android notification (call-style - wakes/lights up
  /// the screen even when locked or the app is killed) with a plain
  /// notification+sound fallback on iOS, since Apple does not allow true
  /// full-screen wake for a regular push when the app is terminated. That is
  /// an accepted platform limitation, not something worked around here.
  Future<void> showFullScreenNudgeAlert({required String fromDisplayName}) async {
    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.max,
      priority: Priority.max,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.call,
      visibility: NotificationVisibility.public,
      ongoing: false,
      autoCancel: true,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'default',
      interruptionLevel: InterruptionLevel.timeSensitive,
    );
    final details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    try {
      await plugin.show(
        // Second-granularity id is fine here: this is a fire-and-forget
        // alert, never updated/cancelled by id later.
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'รีบมาได้แล้ว!',
        '$fromDisplayName บอกให้คุณรีบมา - รีบมาได้แล้วเพื่อนตามแล้ว!!',
        details,
        payload: nudgeNotificationPayload,
      );
    } catch (e, st) {
      // A missing/misconfigured notification channel (e.g. never actually
      // granted permission) shouldn't crash the caller - this is best-effort
      // just like every other notification path in this feature.
      debugPrint('[nudge] showFullScreenNudgeAlert failed: $e\n$st');
    }
  }

  /// Same shape as [showFullScreenNudgeAlert], for a "your friend heading
  /// home wants to know you're okay" check-in request.
  Future<void> showFullScreenCheckInAlert({required String fromDisplayName}) async {
    final androidDetails = AndroidNotificationDetails(
      checkInChannelId,
      checkInChannelName,
      channelDescription: checkInChannelDescription,
      importance: Importance.max,
      priority: Priority.max,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.call,
      visibility: NotificationVisibility.public,
      ongoing: false,
      autoCancel: true,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'default',
      interruptionLevel: InterruptionLevel.timeSensitive,
    );
    final details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    try {
      await plugin.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'โอเคนะคะ?',
        '$fromDisplayName อยากรู้ว่าคุณโอเคไหม',
        details,
        payload: checkInNotificationPayload,
      );
    } catch (e, st) {
      debugPrint('[checkin] showFullScreenCheckInAlert failed: $e\n$st');
    }
  }

  /// Same shape as [showFullScreenNudgeAlert], for a "your friend answered
  /// not okay" emergency broadcast.
  Future<void> showFullScreenCheckInEmergencyAlert({required String fromDisplayName}) async {
    final androidDetails = AndroidNotificationDetails(
      emergencyChannelId,
      emergencyChannelName,
      channelDescription: emergencyChannelDescription,
      importance: Importance.max,
      priority: Priority.max,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.call,
      visibility: NotificationVisibility.public,
      ongoing: false,
      autoCancel: true,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'default',
      interruptionLevel: InterruptionLevel.timeSensitive,
    );
    final details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    try {
      await plugin.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        '$fromDisplayName ตอบว่าไม่โอเค!',
        'แตะเพื่อดูเบอร์ติดต่อฉุกเฉิน',
        details,
        payload: checkInEmergencyNotificationPayload,
      );
    } catch (e, st) {
      debugPrint('[emergency] showFullScreenCheckInEmergencyAlert failed: $e\n$st');
    }
  }

  /// Shows a "you've been invited to a meetup" notification. Unlike
  /// [showFullScreenNudgeAlert] and its siblings, an invite isn't
  /// time-critical, so this is a normal heads-up notification (no
  /// full-screen intent, no forced wake) that the user can act on whenever
  /// they get to it.
  Future<void> showPartyInviteNotification({
    required String fromDisplayName,
    required String meetupName,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      inviteChannelId,
      inviteChannelName,
      channelDescription: inviteChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'default',
    );
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    try {
      await plugin.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'คำเชิญตี้ใหม่!',
        '$fromDisplayName เชิญคุณไปที่ $meetupName',
        details,
        payload: partyInviteNotificationPayload,
      );
    } catch (e, st) {
      debugPrint('[invite] showPartyInviteNotification failed: $e\n$st');
    }
  }

  /// If the app was cold-started by the user tapping this service's own
  /// local notification (as opposed to a raw FCM tap, see
  /// `FirebaseMessaging.instance.getInitialMessage()`), returns the payload
  /// so the caller can decide whether to jump straight to the nudge alert
  /// screen. Returns null on any failure or if the app wasn't launched this
  /// way.
  Future<String?> getLaunchNudgePayload() async {
    try {
      final details = await plugin.getNotificationAppLaunchDetails();
      if (details?.didNotificationLaunchApp != true) return null;
      return details?.notificationResponse?.payload;
    } catch (e) {
      debugPrint('[nudge] getLaunchNudgePayload failed: $e');
      return null;
    }
  }
}
