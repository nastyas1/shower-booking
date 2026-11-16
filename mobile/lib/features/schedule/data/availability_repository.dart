import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../auth/data/auth_repository.dart';

final availabilityRepositoryProvider = Provider<AvailabilityRepository>(
  (ref) => AvailabilityRepository(ref.watch(apiClientProvider).dio),
);

final availableCabinsProvider =
    FutureProvider.family<List<CabinAvailability>, DateTime>((ref, date) {
      return ref.watch(availabilityRepositoryProvider).getAvailableCabins(date);
    });

class CabinAvailability {
  const CabinAvailability({
    required this.id,
    required this.number,
    required this.slots,
  });

  final int id;
  final String number;
  final List<DateTime> slots;

  factory CabinAvailability.fromJson(
    Map<String, dynamic> json, {
    required tz.Location location,
  }) {
    final id = json['id'];
    final number = json['number'];
    final rawIntervals = json['available_intervals'];
    if (id is! int || number is! String || rawIntervals is! List) {
      throw const FormatException(
        'The cabin availability response is invalid.',
      );
    }

    final slots = <DateTime>[];
    for (final rawInterval in rawIntervals) {
      if (rawInterval is! Map<String, dynamic>) {
        throw const FormatException(
          'The cabin availability interval is invalid.',
        );
      }
      final start = rawInterval['starts_at'];
      final end = rawInterval['ends_at'];
      if (start is! String || end is! String) {
        throw const FormatException(
          'The cabin availability interval is invalid.',
        );
      }
      final startsAt = tz.TZDateTime.from(DateTime.parse(start), location);
      final endsAt = tz.TZDateTime.from(DateTime.parse(end), location);
      var slotStart = _firstQuarterHourAtOrAfter(startsAt);
      while (!slotStart.add(const Duration(minutes: 15)).isAfter(endsAt)) {
        slots.add(slotStart);
        slotStart = slotStart.add(const Duration(minutes: 15));
      }
    }

    return CabinAvailability(id: id, number: number, slots: slots);
  }
}

class AvailabilityRepository {
  const AvailabilityRepository(this._dio);

  final Dio _dio;

  Future<List<CabinAvailability>> getAvailableCabins(DateTime date) async {
    final response = await _dio.get<Map<String, dynamic>>(
      'cabins/available',
      queryParameters: {'date': _dateOnly(date)},
    );
    final cabins = response.data?['cabins'];
    final timezoneName = response.data?['timezone'];
    if (cabins is! List || timezoneName is! String) {
      throw const FormatException('The availability response is invalid.');
    }
    final tz.Location location;
    try {
      location = tz.getLocation(timezoneName);
    } on Exception {
      throw const FormatException('The availability timezone is invalid.');
    }
    return cabins
        .map((cabin) {
          if (cabin is! Map<String, dynamic>) {
            throw const FormatException(
              'The availability response is invalid.',
            );
          }
          return CabinAvailability.fromJson(cabin, location: location);
        })
        .toList(growable: false);
  }

  static String _dateOnly(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}

DateTime _firstQuarterHourAtOrAfter(tz.TZDateTime value) {
  final minutes = value.hour * 60 + value.minute;
  final hasRemainder = value.second != 0 || value.millisecond != 0;
  final roundedMinutes = ((minutes + (hasRemainder ? 15 : 14)) ~/ 15) * 15;
  return tz.TZDateTime(
    value.location,
    value.year,
    value.month,
    value.day,
  ).add(Duration(minutes: roundedMinutes));
}
