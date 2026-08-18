import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/api/api_client.dart';
import 'core/auth/auth_repository.dart';
import 'core/auth/token_storage.dart';
import 'core/location/location_service.dart';
import 'core/places/nominatim_places_repository.dart';
import 'core/places/places_repository.dart';
import 'features/auth/auth_controller.dart';
import 'features/meetups/data/http_meetup_repository.dart';
import 'features/meetups/data/meetup_repository.dart';
import 'features/meetups/meetups_controller.dart';
import 'features/notifications/data/mock_notifications_repository.dart';
import 'features/notifications/data/notifications_repository.dart';
import 'features/notifications/notifications_controller.dart';
import 'features/profile/data/mock_badges_repository.dart';

void main() async {
  // Required before any platform-channel call (e.g. secure storage) made
  // ahead of runApp(), such as AuthController.bootstrap() below.
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');

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
  final NotificationsRepository notificationsRepository =
      MockNotificationsRepository();
  final PlacesRepository placesRepository = NominatimPlacesRepository();
  final locationService = LocationService();

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
        ChangeNotifierProvider(
          create: (_) =>
              NotificationsController(repository: notificationsRepository),
        ),
        Provider.value(value: MockBadgesRepository()),
        Provider.value(value: placesRepository),
        Provider.value(value: locationService),
      ],
      child: const App(),
    ),
  );
}
