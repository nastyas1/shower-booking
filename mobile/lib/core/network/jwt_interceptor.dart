import 'package:dio/dio.dart';

import 'access_token_source.dart';

class JwtInterceptor extends Interceptor {
  static const authorizationHeader = 'Authorization';

  JwtInterceptor(this._tokenSource);

  final AccessTokenSource _tokenSource;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _tokenSource.readAccessToken();
    if (token != null && token.trim().isNotEmpty) {
      options.headers[authorizationHeader] = 'Bearer $token';
    }
    handler.next(options);
  }
}
