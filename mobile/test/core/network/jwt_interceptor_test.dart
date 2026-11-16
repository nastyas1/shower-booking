import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shower_booking/core/network/access_token_source.dart';
import 'package:shower_booking/core/network/api_client.dart';
import 'package:shower_booking/core/network/jwt_interceptor.dart';

class _FakeTokenSource implements AccessTokenSource {
  _FakeTokenSource(this.token);

  final String? token;

  @override
  Future<String?> readAccessToken() async => token;
}

class _RecordingAdapter implements HttpClientAdapter {
  RequestOptions? requestOptions;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requestOptions = options;
    return ResponseBody.fromString(
      '{}',
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
  test('adds a bearer token when one is available', () async {
    final client = ApiClient(tokenSource: _FakeTokenSource('access-token'));
    final adapter = _RecordingAdapter();
    client.dio.httpClientAdapter = adapter;

    await client.dio.get('health');

    expect(
      adapter.requestOptions!.headers[JwtInterceptor.authorizationHeader],
      'Bearer access-token',
    );
  });

  test('does not send an authorization header without a token', () async {
    final client = ApiClient(tokenSource: _FakeTokenSource(null));
    final adapter = _RecordingAdapter();
    client.dio.httpClientAdapter = adapter;

    await client.dio.get('health');

    expect(
      adapter.requestOptions!.headers.containsKey(
        JwtInterceptor.authorizationHeader,
      ),
      isFalse,
    );
  });
}
