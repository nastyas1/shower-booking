import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:shower_booking/features/auth/data/secure_token_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FlutterSecureStorage storage;
  late SecureTokenStore tokenStore;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    storage = const FlutterSecureStorage();
    tokenStore = SecureTokenStore(storage);
  });

  test('stores access and refresh tokens separately', () async {
    await tokenStore.saveTokens(
      accessToken: 'access-value',
      refreshToken: 'refresh-value',
    );

    expect(await tokenStore.readAccessToken(), 'access-value');
    expect(await tokenStore.readRefreshToken(), 'refresh-value');
  });

  test('clears both tokens on logout', () async {
    await tokenStore.saveTokens(
      accessToken: 'access-value',
      refreshToken: 'refresh-value',
    );

    await tokenStore.clearTokens();

    expect(await tokenStore.readAccessToken(), isNull);
    expect(await tokenStore.readRefreshToken(), isNull);
  });

  test('returns null when no access token is stored', () async {
    expect(await tokenStore.readAccessToken(), isNull);
  });
}
