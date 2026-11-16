import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shower_booking/features/auth/data/auth_repository.dart';
import 'package:shower_booking/features/auth/data/token_store.dart';
import 'package:shower_booking/main.dart';

class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository({this.loginError}) : super(Dio(), _FakeTokenStore());

  final DioException? loginError;
  var loginCalls = 0;

  @override
  Future<AuthTokens> login({
    required String username,
    required String password,
  }) async {
    loginCalls++;
    if (loginError != null) throw loginError!;
    return const AuthTokens(access: 'access', refresh: 'refresh');
  }
}

class _FakeTokenStore implements TokenStore {
  @override
  Future<void> clearTokens() async {}

  @override
  Future<String?> readAccessToken() async => null;

  @override
  Future<String?> readRefreshToken() async => null;

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {}
}

void main() {
  testWidgets('validates required login fields before calling the API', (
    tester,
  ) async {
    final repository = _FakeAuthRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(repository)],
        child: const ShowerBookingApp(),
      ),
    );

    await tester.tap(find.byKey(const Key('auth-submit')));
    await tester.pumpAndSettle();

    expect(find.text('Введите логин'), findsOneWidget);
    expect(find.text('Введите пароль'), findsOneWidget);
    expect(repository.loginCalls, 0);
  });

  testWidgets('shows an error when the server rejects credentials', (
    tester,
  ) async {
    final repository = _FakeAuthRepository(
      loginError: DioException(
        requestOptions: RequestOptions(path: 'auth/token/'),
        response: Response(
          requestOptions: RequestOptions(path: 'auth/token/'),
          statusCode: 401,
        ),
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(repository)],
        child: const ShowerBookingApp(),
      ),
    );
    await tester.enterText(
      find.byKey(const Key('auth-username')),
      'test-user',
    );
    await tester.enterText(
      find.byKey(const Key('auth-password')),
      'test-password',
    );

    await tester.tap(find.byKey(const Key('auth-submit')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('auth-error')), findsOneWidget);
    expect(find.text('Проверьте логин и пароль и попробуйте ещё раз.'), findsOneWidget);
    expect(repository.loginCalls, 1);
  });

  testWidgets('navigates to the schedule after successful login', (
    tester,
  ) async {
    final repository = _FakeAuthRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(repository)],
        child: const ShowerBookingApp(),
      ),
    );
    await tester.enterText(
      find.byKey(const Key('auth-username')),
      'test-user',
    );
    await tester.enterText(
      find.byKey(const Key('auth-password')),
      'test-password',
    );

    await tester.tap(find.byKey(const Key('auth-submit')));
    await tester.pumpAndSettle();

    expect(find.text('Schedule'), findsNWidgets(2));
    expect(repository.loginCalls, 1);
  });

  testWidgets('registration mode validates email and password length', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: ShowerBookingApp()));
    await tester.tap(find.text('Нет аккаунта? Зарегистрироваться'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('auth-email')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('auth-username')), 'new-user');
    await tester.enterText(find.byKey(const Key('auth-email')), 'invalid-email');
    await tester.enterText(find.byKey(const Key('auth-password')), 'short');
    await tester.tap(find.byKey(const Key('auth-submit')));
    await tester.pumpAndSettle();

    expect(find.text('Введите корректный адрес электронной почты'), findsOneWidget);
    expect(find.text('Пароль должен содержать не менее 8 символов'), findsOneWidget);
  });
}
