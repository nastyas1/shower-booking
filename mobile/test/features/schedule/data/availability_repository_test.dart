import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz;

import 'package:shower_booking/features/schedule/data/availability_repository.dart';

class _ResponseAdapter implements HttpClientAdapter {
  _ResponseAdapter(this.responseBody);

  final String responseBody;
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
      200,
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

  test(
    'requests the selected date and parses slots in server timezone',
    () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/'));
      final adapter = _ResponseAdapter('''
      {
        "date": "2026-11-15",
        "timezone": "Europe/Moscow",
        "cabins": [
          {
            "id": 4,
            "number": "A-04",
            "available_intervals": [
              {
                "starts_at": "2026-11-15T06:02:00+03:00",
                "ends_at": "2026-11-15T06:45:00+03:00"
              }
            ]
          }
        ]
      }
    ''');
      dio.httpClientAdapter = adapter;
      final repository = AvailabilityRepository(dio);

      final cabins = await repository.getAvailableCabins(
        DateTime(2026, 11, 15),
      );

      expect(adapter.requestOptions!.queryParameters['date'], '2026-11-15');
      expect(cabins, hasLength(1));
      expect(cabins.single.number, 'A-04');
      expect(cabins.single.slots, hasLength(2));
      expect(cabins.single.slots.first.hour, 6);
      expect(cabins.single.slots.first.minute, 15);
      expect(
        cabins.single.slots.first.timeZoneOffset,
        const Duration(hours: 3),
      );
    },
  );

  test('rejects malformed response payloads', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/'));
    dio.httpClientAdapter = _ResponseAdapter('{"timezone":"Europe/Moscow"}');
    final repository = AvailabilityRepository(dio);

    await expectLater(
      repository.getAvailableCabins(DateTime(2026, 11, 15)),
      throwsA(isA<FormatException>()),
    );
  });
}
