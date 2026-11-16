import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../auth/data/auth_repository.dart';

final bookingRepositoryProvider = Provider<BookingRepository>(
  (ref) => BookingRepository(ref.watch(apiClientProvider).dio),
);

final myBookingsProvider = FutureProvider<List<BookingSummary>>(
  (ref) => ref.watch(bookingRepositoryProvider).getMyBookings(),
);

class BookingSummary {
  const BookingSummary({
    required this.id,
    required this.cabinNumber,
    required this.startsAt,
    required this.endsAt,
  });

  final int id;
  final String cabinNumber;
  final DateTime startsAt;
  final DateTime endsAt;

  factory BookingSummary.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final cabinNumber = json['cabin_number'];
    final startsAt = json['starts_at'];
    final endsAt = json['ends_at'];
    if (id is! int ||
        cabinNumber is! String ||
        startsAt is! String ||
        endsAt is! String) {
      throw const FormatException('The booking response is invalid.');
    }

    final location = tz.getLocation('Europe/Moscow');
    return BookingSummary(
      id: id,
      cabinNumber: cabinNumber,
      startsAt: tz.TZDateTime.from(DateTime.parse(startsAt), location),
      endsAt: tz.TZDateTime.from(DateTime.parse(endsAt), location),
    );
  }
}

class BookingRepository {
  const BookingRepository(this._dio);

  final Dio _dio;

  Future<List<BookingSummary>> getMyBookings() async {
    final response = await _dio.get<Map<String, dynamic>>('bookings');
    final bookings = response.data?['bookings'];
    if (bookings is! List) {
      throw const FormatException('The bookings response is invalid.');
    }

    return bookings
        .map((booking) {
          if (booking is! Map<String, dynamic>) {
            throw const FormatException('The booking response is invalid.');
          }
          return BookingSummary.fromJson(booking);
        })
        .toList(growable: false);
  }

  Future<void> cancelBooking(int bookingId) async {
    await _dio.delete<void>('bookings/$bookingId');
  }

  Future<void> createBooking({
    required int cabinId,
    required DateTime startsAt,
    required int durationMinutes,
  }) async {
    await _dio.post<void>(
      'bookings',
      data: {
        'cabin_id': cabinId,
        'starts_at': startsAt.toIso8601String(),
        'ends_at': startsAt
            .add(Duration(minutes: durationMinutes))
            .toIso8601String(),
      },
    );
  }
}
