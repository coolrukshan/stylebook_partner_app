import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sb_core/sb_core.dart';

import 'features/auth/application/providers.dart';
import 'features/auth/application/session_controller.dart';
import 'features/auth/presentation/sign_in_screen.dart';
import 'features/today/presentation/today_screen.dart';

/// Table of routes and their permitted roles.
/// Paths missing from this table default to allowing all authenticated roles.
final Map<String, Set<Role>> kRouteAllowedRoles = {
  '/staff': {Role.owner, Role.manager},
  '/staff/add': {Role.owner},
  '/earnings/detail': {Role.owner},
  '/settings': {Role.owner, Role.manager},
};

/// Listenable that notifies GoRouter to re-evaluate redirects on session changes.
class RouterRefreshNotifier extends ChangeNotifier {
  RouterRefreshNotifier(Ref ref) {
    ref.listen(sessionControllerProvider, (_, _) {
      notifyListeners();
    });
  }
}

final routerRefreshNotifierProvider = Provider<RouterRefreshNotifier>((ref) {
  return RouterRefreshNotifier(ref);
});

/// GoRouter provider with session guard and role enforcement.
final routerProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = ref.watch(routerRefreshNotifierProvider);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final authState = ref.read(sessionControllerProvider).value;
      final isAuthenticated = authState is Authenticated;
      final isSignInLocation = state.matchedLocation == '/sign-in';

      // 1. Guard against unauthenticated users
      if (!isAuthenticated) {
        return isSignInLocation ? null : '/sign-in';
      }

      // 2. Prevent authenticated users from staying on /sign-in
      if (isSignInLocation) {
        return '/';
      }

      // 3. Role-based routing table guard
      final userRole = authState.user.role;
      final allowedRoles = kRouteAllowedRoles[state.matchedLocation];
      if (allowedRoles != null && !allowedRoles.contains(userRole)) {
        return '/';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/sign-in',
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const TodayScreen(),
      ),
      // Route for testing role-based redirects
      GoRoute(
        path: '/staff',
        builder: (context, state) => const Scaffold(body: Text('Staff List')),
      ),
    ],
  );
});
