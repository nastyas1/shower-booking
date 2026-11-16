import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as timezone;

import 'package:shower_booking/core/router/app_router.dart';
import 'package:shower_booking/features/booking/data/booking_repository.dart';
import 'package:shower_booking/features/schedule/data/availability_repository.dart';
import 'package:shower_booking/main.dart';

class _FakeAvailabilityRepository extends AvailabilityRepository {
  _FakeAvailabilityRepository(this.date, this.slot) : super(Dio());

  final DateTime date;
  final DateTime slot;

  @override
  Future<List<CabinAvailability>> getAvailableCabins(DateTime date) async => [
    CabinAvailability(id: 7, number: 'A-07', slots: [slot]),
  ];
}

class _FakeBookingRepository extends BookingRepository {
  _FakeBookingRepository({this.statusCode}) : super(Dio());

  final int? statusCode;

  int? cabinId;
  DateTime? startsAt;
  int? durationMinutes;

  @override
  Future<void> createBooking({
    required int cabinId,
    required DateTime startsAt,
    required int durationMinutes,
  }) async {
    if (statusCode != null) {
      final requestOptions = RequestOptions(path: 'bookings');
      throw DioException(
        requestOptions: requestOptions,
        response: Response(
          requestOptions: requestOptions,
          statusCode: statusCode,
        ),
      );
    }
    this.cabinId = cabinId;
    this.startsAt = startsAt;
    this.durationMinutes = durationMinutes;
  }
}

void main() {
  setUpAll(tz.initializeTimeZones);

  testWidgets('selects duration and submits a booking', (tester) async {
    final today = DateTime.now();
    final location = timezone.getLocation('Europe/Moscow');
    final slot = timezone.TZDateTime(
      location,
      today.year,
      today.month,
      today.day,
      8,
    );
    final bookingRepository = _FakeBookingRepository();
    final container = ProviderContainer(
      overrides: [
        availabilityRepositoryProvider.overrideWithValue(
          _FakeAvailabilityRepository(today, slot),
        ),
        bookingRepositoryProvider.overrideWithValue(bookingRepository),
      ],
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
    await tester.tap(find.text('08:00'));
    await tester.pumpAndSettle();

    expect(find.text('Новая бронь'), findsOneWidget);
    expect(find.text('Кабинка A-07 · 08:00'), findsOneWidget);
    await tester.tap(find.byKey(const Key('duration-30')));
    await tester.tap(find.byKey(const Key('booking-submit')));
    await tester.pumpAndSettle();

    expect(bookingRepository.cabinId, 7);
    expect(bookingRepository.startsAt, slot);
    expect(bookingRepository.durationMinutes, 30);
    expect(find.text('Бронь успешно создана'), findsOneWidget);
  });

  testWidgets('shows a message when the selected slot is no longer available', (
    tester,
  ) async {
    final today = DateTime.now();
    final location = timezone.getLocation('Europe/Moscow');
    final slot = timezone.TZDateTime(
      location,
      today.year,
      today.month,
      today.day,
      8,
    );
    final container = ProviderContainer(
      overrides: [
        availabilityRepositoryProvider.overrideWithValue(
          _FakeAvailabilityRepository(today, slot),
        ),
        bookingRepositoryProvider.overrideWithValue(
          _FakeBookingRepository(statusCode: 409),
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
    container.read(appRouterProvider).go('/schedule');
    await tester.pumpAndSettle();
    await tester.tap(find.text('08:00'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('booking-submit')));
    await tester.pumpAndSettle();

    expect(
      find.text('Это время только что заняли. Обновите расписание.'),
      findsOneWidget,
    );
    expect(find.text('Бронь успешно создана'), findsNothing);
  });
}
