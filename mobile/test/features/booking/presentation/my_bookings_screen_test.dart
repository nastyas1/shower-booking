import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as timezone;

import 'package:shower_booking/core/router/app_router.dart';
import 'package:shower_booking/features/booking/data/booking_repository.dart';
import 'package:shower_booking/main.dart';

class _FakeBookingRepository extends BookingRepository {
  _FakeBookingRepository(this.bookings) : super(Dio());

  final List<BookingSummary> bookings;
  final List<int> cancelledBookingIds = [];

  @override
  Future<List<BookingSummary>> getMyBookings() async => bookings;

  @override
  Future<void> cancelBooking(int bookingId) async {
    cancelledBookingIds.add(bookingId);
    bookings.removeWhere((booking) => booking.id == bookingId);
  }
}

void main() {
  setUpAll(tz.initializeTimeZones);

  testWidgets('loads bookings and cancels one after a swipe confirmation', (
    tester,
  ) async {
    final location = timezone.getLocation('Europe/Moscow');
    final bookingRepository = _FakeBookingRepository([
      BookingSummary(
        id: 1,
        cabinNumber: 'A-07',
        startsAt: timezone.TZDateTime(location, 2026, 3, 10, 8),
        endsAt: timezone.TZDateTime(location, 2026, 3, 10, 8, 30),
      ),
    ]);
    final container = ProviderContainer(
      overrides: [
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
    container.read(appRouterProvider).go('/bookings');
    await tester.pumpAndSettle();

    expect(find.text('Кабинка A-07'), findsOneWidget);
    expect(find.text('2026-03-10, 08:00 – 2026-03-10, 08:30'), findsOneWidget);

    await tester.drag(
      find.byKey(const ValueKey('booking-1')),
      const Offset(-500, 0),
    );
    await tester.pumpAndSettle();
    expect(find.text('Отменить бронь?'), findsOneWidget);
    await tester.tap(find.text('Отменить бронь'));
    await tester.pumpAndSettle();

    expect(bookingRepository.cancelledBookingIds, [1]);
    expect(find.text('У вас пока нет броней'), findsOneWidget);
    expect(find.text('Бронь отменена'), findsOneWidget);
  });
}
