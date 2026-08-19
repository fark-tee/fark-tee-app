import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../../features/auth/auth_controller.dart';
import '../../features/auth/auth_state.dart';
import '../../features/auth/screens/create_profile_screen.dart';
import '../../features/auth/screens/sign_in_screen.dart';
import '../../features/groups/screens/groups_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/meetups/screens/create_meetup/create_meetup_screen.dart';
import '../../features/meetups/screens/going_home_screen.dart';
import '../../features/meetups/screens/live_meetup_screen.dart';
import '../../features/meetups/screens/review_screen.dart';
import '../../features/meetups/screens/meetup_detail_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/saved_locations/screens/add_saved_location_screen.dart';
import '../../features/saved_locations/screens/saved_locations_screen.dart';
import 'app_shell.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

/// Route-level replacement for the old `_AuthGate` switch widget: the
/// [redirect] callback below reproduces the same state machine
/// (checking/unauthenticated/needsProfile/authenticated), but as routing
/// rules instead of a widget swap, since a real 3-tab bottom nav plus
/// full-screen flows on top of it need actual routes.
GoRouter buildAppRouter(AuthController authController) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: authController,
    redirect: (context, state) {
      final status = authController.status;
      final location = state.matchedLocation;
      final onAuthRoute = location == '/sign-in' || location == '/create-profile';

      switch (status) {
        case AuthStatus.checking:
          return location == '/splash' ? null : '/splash';
        case AuthStatus.unauthenticated:
          return location == '/sign-in' ? null : '/sign-in';
        case AuthStatus.needsProfile:
          return location == '/create-profile' ? null : '/create-profile';
        case AuthStatus.authenticated:
          return (location == '/splash' || onAuthRoute) ? '/home' : null;
      }
    },
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const _SplashScreen()),
      GoRoute(
        path: '/sign-in',
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        path: '/create-profile',
        builder: (context, state) => const CreateProfileScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: '/home', builder: (c, s) => const HomeScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/groups', builder: (c, s) => const GroupsScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/profile', builder: (c, s) => const ProfileScreen())],
          ),
        ],
      ),
      GoRoute(
        path: '/create-meetup',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const CreateMeetupScreen(),
      ),
      GoRoute(
        path: '/saved-locations',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const SavedLocationsScreen(),
      ),
      GoRoute(
        path: '/saved-locations/add',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const AddSavedLocationScreen(),
      ),
      GoRoute(
        path: '/meetup/:id',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            MeetupDetailScreen(meetupId: state.pathParameters['id']!),
        routes: [
          GoRoute(
            path: 'live',
            parentNavigatorKey: rootNavigatorKey,
            builder: (context, state) =>
                LiveMeetupScreen(meetupId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: 'going-home',
            parentNavigatorKey: rootNavigatorKey,
            builder: (context, state) =>
                GoingHomeScreen(meetupId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: 'review',
            parentNavigatorKey: rootNavigatorKey,
            builder: (context, state) =>
                ReviewScreen(meetupId: state.pathParameters['id']!),
          ),
        ],
      ),
    ],
  );
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/images/logo.png', width: 120, height: 120),
            const SizedBox(height: AppSpacing.lg),
            Text('สักที', style: AppTextStyles.displayLg),
            const SizedBox(height: AppSpacing.xxl),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
