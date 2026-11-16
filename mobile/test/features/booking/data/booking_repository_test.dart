import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz;

import 'package:shower_booking/features/booking/data/booking_repository.dart';

class _ResponseAdapter implements HttpClientAdapter {
  _ResponseAdapter(this.responseBody, {this.statusCode = 200});

  final String responseBody;
  final int statusCode;
  RequestOptions? requestOptions;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requestOptions = options;
    return ResponseBody.fromString(
      responseBody,
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  setUpAll(tz.initializeTimeZones);

  test('loads the current user bookings in the Moscow timezone', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/'));
    final adapter = _ResponseAdapter('''
      {
        "bookings": [
          {
            "id": 8,
            "cabin_number": "A-08",
            "starts_at": "2026-03-10T08:00:00+03:00",
            "ends_at": "2026-03-10T08:30:00+03:00"
          }
        ]
      }
    ''');
    dio.httpClientAdapter = adapter;
    final repository = BookingRepository(dio);

    final bookings = await repository.getMyBookings();

    expect(adapter.requestOptions!.method, 'GET');
    expect(adapter.requestOptions!.uri.path, '/api/bookings');
    expect(bookings, hasLength(1));
    expect(bookings.single.cabinNumber, 'A-08');
    expect(bookings.single.startsAt.hour, 8);
    expect(bookings.single.startsAt.timeZoneOffset, const Duration(hours: 3));
  });

  test('cancels a booking by its id', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/'));
    final adapter = _ResponseAdapter('', statusCode: 204);
    dio.httpClientAdapter = adapter;
    final repository = BookingRepository(dio);

    await repository.cancelBooking(19);

    expect(adapter.requestOptions!.method, 'DELETE');
    expect(adapter.requestOptions!.uri.path, '/api/bookings/19');
  });
}
