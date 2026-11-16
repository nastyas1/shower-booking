import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shower_booking/features/maintenance/data/maintenance_repository.dart';

class _ResponseAdapter implements HttpClientAdapter {
  RequestOptions? requestOptions;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requestOptions = options;
    return ResponseBody.fromString(
      '{"id":12}',
      201,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('posts the cabin and description to the maintenance endpoint', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/'));
    final adapter = _ResponseAdapter();
    dio.httpClientAdapter = adapter;
    final repository = MaintenanceRepository(dio);

    await repository.createReport(cabinId: 7, description: 'Low water flow');

    expect(adapter.requestOptions!.method, 'POST');
    expect(adapter.requestOptions!.uri.path, '/api/maintenance');
    expect(adapter.requestOptions!.data, {
      'cabin_id': 7,
      'description': 'Low water flow',
    });
  });
}
