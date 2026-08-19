import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/api/api_client.dart';
import 'core/auth/auth_repository.dart';
import 'core/auth/token_storage.dart';
import 'core/location/location_service.dart';
import 'core/notifications/device_token_registrar.dart';
import 'core/notifications/device_token_repository.dart';
import 'core/notifications/nudge_messaging_coordinator.dart';
import 'core/notifications/nudge_notification_service.dart';
import 'core/places/nominatim_places_repository.dart';
import 'core/places/places_repository.dart';
import 'core/router/app_router.dart' show rootNavigatorKey;
import 'features/auth/auth_controller.dart';
import 'features/meetups/data/http_meetup_repository.dart';
import 'features/meetups/data/meetup_repository.dart';
import 'features/meetups/meetups_controller.dart';
import 'features/profile/data/mock_badges_repository.dart';
import 'features/saved_locations/data/saved_locations_repository.dart';
import 'firebase_options.dart';

/// Runs in a separate background isolate when a data-only FCM message
/// arrives while the app is backgrounded or fully killed - it has no access
/// to any state created in `main()` below (no DI/provider tree), so it
/// re-initializes exactly what it needs from scratch. Must stay a top-level
/// function annotated `@pragma('vm:entry-point')` and must be registered via
/// `FirebaseMessaging.onBackgroundMessage` before `runApp` - both are
/// required by the firebase_messaging plugin's background-isolate contract.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    // Expected until a real Firebase project is wired up - see the
    // matching try/catch around Firebase.initializeApp() in main() below.
    debugPrint('[nudge][bg isolate] Firebase.initializeApp failed: $e');
  }

  final fromDisplayName = message.data['fromDisplayName'] as String? ?? 'เพื่อนของคุณ';

  try {
    final notificationService = NudgeNotificationService();
    await notificationService.initialize();
    switch (message.data['type']) {
      case 'nudge':
        await notificationService.showFullScreenNudgeAlert(fromDisplayName: fromDisplayName);
      case 'checkin_request':
        await notificationService.showFullScreenCheckInAlert(fromDisplayName: fromDisplayName);
    }
  } catch (e) {
    debugPrint('[nudge][bg isolate] failed to show full-screen alert: $e');
  }
}

void main() async {
  // Required before any platform-channel call (e.g. secure storage) made
  // ahead of runApp(), such as AuthController.bootstrap() below.
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');

  // lib/firebase_options.dart is only real for Android so far (transcribed
  // from a human-provided google-services.json) - iOS/web/desktop are still
  // obvious placeholders pending `flutterfire configure`, so this can still
  // fail depending on platform/target. Catch it here so the whole app never
  // crashes on startup regardless; everything downstream (notification
  // service, messaging coordinator, device token registrar) is itself
  // defensive about Firebase not really being available, so the app just
  // continues in a "notifications disabled" state on failure.
  var firebaseAvailable = true;
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    firebaseAvailable = false;
    debugPrint(
      '[nudge] Firebase.initializeApp failed - continuing with notifications '
      'disabled. This is expected until a real Firebase project is wired up '
      '(see lib/firebase_options.dart). Error: $e',
    );
  }
  if (firebaseAvailable) {
    // Must be registered before runApp() per the firebase_messaging plugin's
    // contract for the app-killed case.
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  final tokenStorage = TokenStorage();
  final apiClient = ApiClient(tokenStorage: tokenStorage);
  final authRepository = AuthRepository(apiClient);
  final authController = AuthController(
    apiClient: apiClient,
    authRepository: authRepository,
    tokenStorage: tokenStorage,
  )..bootstrap();

  final MeetupRepository meetupRepository = HttpMeetupRepository(
    apiClient: apiClient,
    locationService: LocationService(),
  );
  final PlacesRepository placesRepository = NominatimPlacesRepository();
  final locationService = LocationService();
  final savedLocationsRepository = SavedLocationsRepository(apiClient);

  // Everything below is best-effort and gated on `firebaseAvailable`: with
  // only placeholder Firebase config in place (see lib/firebase_options.dart),
  // FCM itself can't work, so there's nothing meaningful for the notification
  // service/coordinator/token registrar to do - the app simply runs with
  // notifications disabled until a real Firebase project is wired up.
  final nudgeNotificationService = NudgeNotificationService();
  final nudgeMessagingCoordinator = NudgeMessagingCoordinator(
    notificationService: nudgeNotificationService,
    navigatorKey: rootNavigatorKey,
  );
  if (firebaseAvailable) {
    // Local-notifications init (Android channel + permission prompts) is
    // requested here at startup rather than lazily on first nudge, unlike
    // e.g. LocationService's lazy on-first-use location permission request -
    // a nudge can arrive at any time from any other party member, so there's
    // no single "first use" screen to hang the prompt off of.
    await nudgeNotificationService.initialize();
    nudgeMessagingCoordinator.initialize();
    // Device token registration itself is hooked to auth state - see
    // DeviceTokenRegistrar - so it effectively fires lazily, right when a
    // signed-in user first exists to register a token for.
    DeviceTokenRegistrar(
      deviceTokenRepository: DeviceTokenRepository(apiClient: apiClient),
      authController: authController,
    );
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authController),
        ChangeNotifierProvider(
          create: (_) => MeetupsController(
            repository: meetupRepository,
            authController: authController,
          ),
        ),
        Provider.value(value: MockBadgesRepository()),
        Provider.value(value: placesRepository),
        Provider.value(value: locationService),
        Provider.value(value: savedLocationsRepository),
      ],
      child: const App(),
    ),
  );

  if (firebaseAvailable) {
    // Covers the terminated -> cold-start-by-tapping-a-nudge-notification
    // case, for both this app's own full-screen local notification and a
    // raw FCM notification tap. Deferred to after the first frame so
    // `rootNavigatorKey` is actually attached to a Navigator by then.
    //
    // NOTE: Android's *automatic* (non-tapped) full-screen-intent wake while
    // fully killed is best-effort and can't be verified without a real
    // device + real Firebase project - see NudgeMessagingCoordinator.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      nudgeMessagingCoordinator.checkForInitialNudge();
    });
  }
}
