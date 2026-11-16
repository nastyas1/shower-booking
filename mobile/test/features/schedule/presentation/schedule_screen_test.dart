import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as timezone;

import 'package:shower_booking/features/schedule/data/availability_repository.dart';
import 'package:shower_booking/core/router/app_router.dart';
import 'package:shower_booking/main.dart';

class _FakeAvailabilityRepository extends AvailabilityRepository {
  _FakeAvailabilityRepository(this.cabins) : super(Dio());

  final List<CabinAvailability> cabins;

  @override
  Future<List<CabinAvailability>> getAvailableCabins(DateTime date) async {
    return cabins;
  }
}

void main() {
  setUpAll(tz.initializeTimeZones);

  testWidgets('shows cabins and available slots from the API', (tester) async {
    final location = timezone.getLocation('Europe/Moscow');
    final start = timezone.TZDateTime(location, 2026, 11, 15, 8);
    final repository = _FakeAvailabilityRepository([
      CabinAvailability(id: 8, number: 'B-08', slots: [start]),
    ]);
    final container = ProviderContainer(
      overrides: [availabilityRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const ShowerBookingApp(),
      ),
    );
    container.read(appRouterProvider).go('/schedule');
    await tester.pumpAndSettle();

    expect(find.text('Свободные кабинки'), findsOneWidget);
    expect(find.text('Кабинка B-08'), findsOneWidget);
    expect(find.text('08:00'), findsOneWidget);
  });

  testWidgets('shows an empty state when no cabins are available', (
    tester,
  ) async {
    final repository = _FakeAvailabilityRepository([]);
    final container = ProviderContainer(
      overrides: [availabilityRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const ShowerBookingApp(),
      ),
    );
    container.read(appRouterProvider).go('/schedule');
    await tester.pumpAndSettle();

    expect(find.text('На этот день свободных кабинок нет'), findsOneWidget);
  });
}
