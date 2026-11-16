import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import 'secure_token_store.dart';
import 'token_store.dart';

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(tokenSource: ref.watch(secureTokenStoreProvider)),
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(
    ref.watch(apiClientProvider).dio,
    ref.watch(secureTokenStoreProvider),
  ),
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
  const AuthRepository(this._dio, this._tokenStore);

  final Dio _dio;
  final TokenStore _tokenStore;

  Future<AuthTokens> login({
    required String username,
    required String password,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      'auth/token/',
      data: {'username': username, 'password': password},
    );
    final tokens = AuthTokens.fromJson(response.data ?? const {});
    await _tokenStore.saveTokens(
      accessToken: tokens.access,
      refreshToken: tokens.refresh,
    );
    return tokens;
  }

  Future<AuthTokens> register({
    required String username,
    required String email,
    required String password,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      'auth/register/',
      data: {'username': username, 'email': email, 'password': password},
    );
    final tokens = AuthTokens.fromJson(response.data ?? const {});
    await _tokenStore.saveTokens(
      accessToken: tokens.access,
      refreshToken: tokens.refresh,
    );
    return tokens;
  }
}
