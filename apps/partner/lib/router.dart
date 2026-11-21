import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sb_core/sb_core.dart';
import 'package:sb_ui/sb_ui.dart';

import 'features/auth/application/providers.dart';
import 'features/auth/application/session_controller.dart';
import 'features/auth/presentation/change_password_screen.dart';
import 'features/auth/presentation/session_loading_screen.dart';
import 'features/auth/presentation/sign_in_screen.dart';
import 'features/auth/presentation/verify_code_screen.dart';
import 'features/today/presentation/today_screen.dart';
import 'l10n/app_localizations.dart';
import 'shell/routes.dart';

export 'shell/routes.dart' show safeFromTarget;

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

/// The link to come back to after the sign-in flow: the current location if it is a real
/// screen, otherwise the `from` the flow was already carrying.
String? _linkToKeep(GoRouterState state) {
  final loc = state.matchedLocation;
  if (kAuthPaths.contains(loc)) return safeFromTarget(state.uri.queryParameters['from']);
  return loc == kHomePath ? null : safeFromTarget(state.uri.toString());
}

/// Redirect rules, driven only by the session:
/// loading -> /loading; signed out -> /sign-in; limited -> /verify;
/// full + must change password -> /change-password; full -> app (role table applies).
String? _redirect(Ref ref, GoRouterState state) {
  final session = ref.read(sessionControllerProvider);
  final loc = state.matchedLocation;
  final keep = _linkToKeep(state);

  if (session.isLoading && !session.hasValue) {
    return loc == kLoadingPath ? null : withFrom(kLoadingPath, keep);
  }

  final auth = session.value;
  switch (auth) {
    case null || Unauthenticated():
      return loc == kSignInPath ? null : withFrom(kSignInPath, keep);
    case Limited():
      return loc == kVerifyPath ? null : withFrom(kVerifyPath, keep);
    case Full(:final mustChangePassword) when mustChangePassword:
      return loc == kChangePasswordPath ? null : withFrom(kChangePasswordPath, keep);
    case Full():
      break;
  }

  if (loc == kSignInPath || loc == kVerifyPath || loc == kLoadingPath) {
    return keep ?? kHomePath;
  }

  final allowedRoles = kRouteAllowedRoles[loc];
  if (allowedRoles != null && !allowedRoles.contains(auth.user.role)) {
    return kHomePath;
  }
  return null;
}

/// GoRouter provider with session guard and role enforcement.
final routerProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = ref.watch(routerRefreshNotifierProvider);

  return GoRouter(
    initialLocation: kHomePath,
    refreshListenable: refreshNotifier,
    redirect: (context, state) => _redirect(ref, state),
    routes: [
      GoRoute(path: kLoadingPath, builder: (context, state) => const SessionLoadingScreen()),
      GoRoute(path: kSignInPath, builder: (context, state) => const SignInScreen()),
      GoRoute(path: kVerifyPath, builder: (context, state) => const VerifyCodeScreen()),
      GoRoute(path: kChangePasswordPath, builder: (context, state) => const ChangePasswordScreen()),
      GoRoute(path: kHomePath, builder: (context, state) => const TodayScreen()),
      // Placeholder until P-09; exercises the role table.
      GoRoute(
        path: '/staff',
        builder: (context, state) => Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(SbTokens.screenPadding),
              child: Text(AppLocalizations.of(context).staffListPlaceholder),
            ),
          ),
        ),
      ),
    ],
  );
});
