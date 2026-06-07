import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/email_auth_screen.dart';
import '../screens/main_navigation_screen.dart';
import '../screens/mentor/mentor_chat_screen.dart';
import '../screens/onboarding/onboarding_screen.dart';
import '../screens/splash/splash_screen.dart';
import 'route_paths.dart';

import '../providers/app_state.dart';

GoRouter createAppRouter(AppState appState) {
  return GoRouter(
    initialLocation: RoutePaths.splash,
    refreshListenable: appState,
    redirect: (context, state) {
      // 1. Wait for preferences to be loaded from storage
      if (!appState.isPreferencesLoaded) {
        return null; // Stay where we are until preferences load
      }

      final isLoggedIn = appState.token != null && appState.token!.isNotEmpty;
      final matchedLocation = state.matchedLocation;

      // 2. Redirect logic
      if (isLoggedIn) {
        // Logged in user cannot access onboarding, splash, login, or email auth pages.
        if (matchedLocation == RoutePaths.splash ||
            matchedLocation == RoutePaths.onboarding ||
            matchedLocation == RoutePaths.login ||
            matchedLocation == RoutePaths.emailAuth) {
          return RoutePaths.app; // Redirect to home dashboard
        }
      } else {
        // Non-logged in user cannot access dashboard or AI mentor pages.
        if (matchedLocation == RoutePaths.app || matchedLocation == RoutePaths.mentor) {
          return RoutePaths.onboarding; // Redirect to onboarding
        }
      }

      return null; // No redirect
    },
    routes: [
      GoRoute(
        path: RoutePaths.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: RoutePaths.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: RoutePaths.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: RoutePaths.emailAuth,
        builder: (context, state) => const EmailAuthScreen(),
      ),
      GoRoute(
        path: RoutePaths.app,
        builder: (context, state) {
          final tabName = state.uri.queryParameters['tab'];
          final tabIndex = RoutePaths.tabIndexFromName(tabName);
          return MainNavigationScreen(key: const ValueKey('main_nav'), initialTabIndex: tabIndex);
        },
      ),
      GoRoute(
        path: RoutePaths.mentor,
        builder: (context, state) => const MentorChatScreen(),
      ),
    ],
  );
}

