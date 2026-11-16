import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:timezone/data/latest.dart' as tz;

import 'core/router/app_router.dart';
import 'theme/app_theme.dart';

void main() {
  tz.initializeTimeZones();
  runApp(const ProviderScope(child: ShowerBookingApp()));
}

class ShowerBookingApp extends ConsumerWidget {
  const ShowerBookingApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Shower Booking',
      theme: AppTheme.light,
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}
