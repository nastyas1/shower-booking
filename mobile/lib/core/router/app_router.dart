import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(
        path: '/',
        redirect: (context, state) => '/login',
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const _RoutePlaceholder(title: 'Sign in'),
      ),
      GoRoute(
        path: '/schedule',
        builder: (context, state) => const _RoutePlaceholder(title: 'Schedule'),
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
