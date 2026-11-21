/// Route paths and deep-link helpers shared by the router and screens.
const kLoadingPath = '/loading';
const kSignInPath = '/sign-in';
const kVerifyPath = '/verify';
const kChangePasswordPath = '/change-password';
const kHomePath = '/';

/// Paths that belong to the sign-in flow. They are never saved as a deep link.
const kAuthPaths = {kLoadingPath, kSignInPath, kVerifyPath, kChangePasswordPath};

/// Returns [from] only if it is a safe in-app link (no scheme or host, not an auth path).
String? safeFromTarget(String? from) {
  if (from == null || !from.startsWith('/') || from.startsWith('//')) return null;
  final uri = Uri.tryParse(from);
  if (uri == null || uri.hasScheme || uri.hasAuthority) return null;
  if (kAuthPaths.contains(uri.path)) return null;
  return from;
}

/// Builds `path?from=<link>` (or just `path` when there is no link to keep).
String withFrom(String path, String? from) {
  final safe = safeFromTarget(from);
  return safe == null ? path : Uri(path: path, queryParameters: {'from': safe}).toString();
}
