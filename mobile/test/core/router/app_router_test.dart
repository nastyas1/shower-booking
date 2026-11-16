import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shower_booking/core/router/app_router.dart';
import 'package:shower_booking/main.dart';

void main() {
  testWidgets('starts on the login route and supports schedule navigation', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const ShowerBookingApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sign in'), findsNWidgets(2));

    container.read(appRouterProvider).go('/schedule');
    await tester.pumpAndSettle();

    expect(find.text('Schedule'), findsNWidgets(2));
  });
}
