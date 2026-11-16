import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shower_booking/core/router/app_router.dart';
import 'package:shower_booking/features/schedule/data/availability_repository.dart';
import 'package:shower_booking/main.dart';

void main() {
  testWidgets('starts on the login route and supports schedule navigation', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        availabilityRepositoryProvider.overrideWithValue(
          _FakeAvailabilityRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const ShowerBookingApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('auth-username')), findsOneWidget);

    container.read(appRouterProvider).go('/schedule');
    await tester.pumpAndSettle();

    expect(find.text('Расписание'), findsOneWidget);
  });
}

class _FakeAvailabilityRepository extends AvailabilityRepository {
  _FakeAvailabilityRepository() : super(Dio());

  @override
  Future<List<CabinAvailability>> getAvailableCabins(DateTime date) async => [];
}
