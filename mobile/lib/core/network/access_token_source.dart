abstract interface class AccessTokenSource {
  Future<String?> readAccessToken();
}
