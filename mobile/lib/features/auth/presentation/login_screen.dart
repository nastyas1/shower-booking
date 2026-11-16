import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../theme/app_theme.dart';
import '../data/auth_repository.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isRegistering = false;
  bool _isSubmitting = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final repository = ref.read(authRepositoryProvider);
      if (_isRegistering) {
        await repository.register(
          username: _usernameController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      } else {
        await repository.login(
          username: _usernameController.text.trim(),
          password: _passwordController.text,
        );
      }
      if (mounted) context.go('/schedule');
    } on DioException catch (error) {
      setState(() {
        _errorMessage = switch (error.response?.statusCode) {
          400 || 401 => 'Проверьте логин и пароль и попробуйте ещё раз.',
          404 => 'Сервис авторизации пока недоступен.',
          _ => 'Не удалось связаться с сервером. Проверьте подключение.',
        };
      });
    } on FormatException {
      setState(() {
        _errorMessage = 'Сервер вернул некорректный ответ.';
      });
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  String? _validateUsername(String? value) {
    final username = value?.trim() ?? '';
    if (username.isEmpty) return 'Введите логин';
    if (username.length < 3) return 'Логин должен содержать не менее 3 символов';
    return null;
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Введите электронную почту';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return 'Введите корректный адрес электронной почты';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Введите пароль';
    if (_isRegistering && value.length < 8) {
      return 'Пароль должен содержать не менее 8 символов';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final title = _isRegistering ? 'Создать аккаунт' : 'С возвращением';

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.water_drop_rounded,
                      size: 52,
                      color: AppColors.primary,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isRegistering
                          ? 'Зарегистрируйтесь, чтобы бронировать душевые'
                          : 'Войдите, чтобы управлять своими бронированиями',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: AppColors.mutedInk,
                          ),
                    ),
                    const SizedBox(height: 32),
                    TextFormField(
                      key: const Key('auth-username'),
                      controller: _usernameController,
                      autofillHints: const [AutofillHints.username],
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Логин',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: _validateUsername,
                    ),
                    if (_isRegistering) ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        key: const Key('auth-email'),
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Электронная почта',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        validator: _validateEmail,
                      ),
                    ],
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const Key('auth-password'),
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      autofillHints: [
                        _isRegistering
                            ? AutofillHints.newPassword
                            : AutofillHints.password,
                      ],
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: 'Пароль',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          tooltip: _obscurePassword
                              ? 'Показать пароль'
                              : 'Скрыть пароль',
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: _validatePassword,
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          _errorMessage!,
                          key: const Key('auth-error'),
                          style: TextStyle(color: Theme.of(context).colorScheme.error),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      key: const Key('auth-submit'),
                      onPressed: _isSubmitting ? null : _submit,
                      child: _isSubmitting
                          ? const SizedBox.square(
                              dimension: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_isRegistering ? 'Зарегистрироваться' : 'Войти'),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _isSubmitting
                          ? null
                          : () => setState(() {
                                _isRegistering = !_isRegistering;
                                _errorMessage = null;
                                _formKey.currentState?.reset();
                              }),
                      child: Text(
                        _isRegistering
                            ? 'Уже есть аккаунт? Войти'
                            : 'Нет аккаунта? Зарегистрироваться',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
