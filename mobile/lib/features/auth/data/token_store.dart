import '../../../core/network/access_token_source.dart';

abstract interface class TokenStore implements AccessTokenSource {
  Future<String?> readRefreshToken();

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  });

  Future<void> clearTokens();
}
