import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/access_token_source.dart';
import '../../../core/network/api_client.dart';

final accessTokenSourceProvider = Provider<AccessTokenSource>(
  (ref) => _EmptyAccessTokenSource(),
);

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(tokenSource: ref.watch(accessTokenSourceProvider)),
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(apiClientProvider).dio),
);

class AuthTokens {
  const AuthTokens({required this.access, required this.refresh});

  final String access;
  final String refresh;

  factory AuthTokens.fromJson(Map<String, dynamic> json) {
    final access = json['access'];
    final refresh = json['refresh'];
    if (access is! String || access.isEmpty || refresh is! String) {
      throw const FormatException('The authentication response is invalid.');
    }
    return AuthTokens(access: access, refresh: refresh);
  }
}

class AuthRepository {
  const AuthRepository(this._dio);

  final Dio _dio;

  Future<AuthTokens> login({
    required String username,
    required String password,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      'auth/token/',
      data: {'username': username, 'password': password},
    );
    return AuthTokens.fromJson(response.data ?? const {});
  }

  Future<AuthTokens> register({
    required String username,
    required String email,
    required String password,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      'auth/register/',
      data: {
        'username': username,
        'email': email,
        'password': password,
      },
    );
    return AuthTokens.fromJson(response.data ?? const {});
  }
}

class _EmptyAccessTokenSource implements AccessTokenSource {
  @override
  Future<String?> readAccessToken() async => null;
}
