import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/auth_repository.dart';

final bookingRepositoryProvider = Provider<BookingRepository>(
  (ref) => BookingRepository(ref.watch(apiClientProvider).dio),
);

class BookingRepository {
  const BookingRepository(this._dio);

  final Dio _dio;

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
