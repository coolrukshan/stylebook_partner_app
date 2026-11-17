import 'package:go_router/go_router.dart';

import 'features/today/presentation/today_screen.dart';

/// Today is the home screen on every device (P-02). Adaptive shell comes next.
final appRouter = GoRouter(routes: [
  GoRoute(path: '/', builder: (_, _) => const TodayScreen()),
]);
