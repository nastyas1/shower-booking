import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../features/booking/presentation/my_bookings_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/schedule/presentation/schedule_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(path: '/', redirect: (context, state) => '/login'),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/schedule',
        builder: (context, state) => const ScheduleScreen(),
      ),
      GoRoute(
        path: '/bookings',
        builder: (context, state) => const MyBookingsScreen(),
      ),
      GoRoute(
        path: '/booking/new',
        builder: (context, state) =>
            const _RoutePlaceholder(title: 'Бронирование'),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const _RoutePlaceholder(title: 'Profile'),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

class _RoutePlaceholder extends StatelessWidget {
  const _RoutePlaceholder({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(child: Text(title)),
    );
  }
}
