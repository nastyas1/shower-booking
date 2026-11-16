import 'package:dio/dio.dart';

import 'access_token_source.dart';
import 'jwt_interceptor.dart';

class ApiClient {
  ApiClient({
    required AccessTokenSource tokenSource,
    String baseUrl = const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://10.0.2.2:8000/api/',
    ),
  }) : dio = Dio(
          BaseOptions(
            baseUrl: baseUrl,
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 15),
            sendTimeout: const Duration(seconds: 15),
            contentType: Headers.jsonContentType,
            headers: const {'Accept': Headers.jsonContentType},
          ),
        ) {
    dio.interceptors.add(JwtInterceptor(tokenSource));
  }

  final Dio dio;
}
