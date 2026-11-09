import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hookahub/core/data/supabase_service.dart';
import 'package:hookahub/core/utils/app_error_mapper.dart';
import 'package:hookahub/features/auth/presentation/auth_provider.dart';
import 'package:hookahub/features/auth/presentation/forgot_password_page.dart';
import 'package:hookahub/features/auth/presentation/reset_password_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FakeGoTrueClient extends Fake implements GoTrueClient {
  FakeGoTrueClient({Stream<AuthState>? authStateStream})
      : _authStateStream = authStateStream ?? const Stream.empty();

  final Stream<AuthState> _authStateStream;

  @override
  Stream<AuthState> get onAuthStateChange => _authStateStream;

  @override
  Session? get currentSession => null;
}

class FakeSupabaseClient extends Fake implements SupabaseClient {
  FakeSupabaseClient({GoTrueClient? authClient})
      : _auth = authClient ?? FakeGoTrueClient();

  final GoTrueClient _auth;

  @override
  GoTrueClient get auth => _auth;
}

class FakeAuthSupabaseService implements SupabaseService {
  FakeAuthSupabaseService({SupabaseClient? client})
      : _client = client ?? FakeSupabaseClient();

  final SupabaseClient _client;
  String? lastResetEmail;
  String? lastUpdatedPassword;
  Object? errorToThrow;

  @override
  SupabaseClient get client => _client;

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    lastResetEmail = email;
    if (errorToThrow != null) {
      throw errorToThrow!;
    }
  }

  @override
  Future<UserResponse> updatePassword(String newPassword) async {
    lastUpdatedPassword = newPassword;
    if (errorToThrow != null) {
      throw errorToThrow!;
    }
    return FakeUserResponse();
  }

  @override
  Future<void> ensureProfile({
    String? username,
    String? displayName,
    String? firstName,
    String? lastName,
    DateTime? birthdate,
    String? bio,
  }) async {}

  @override
  Future<void> signOut() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeUserResponse extends Fake implements UserResponse {}

Session _createFakeSession() {
  return Session(
    accessToken: 'fake-access-token',
    tokenType: 'bearer',
    user: const User(
      id: 'user-123',
      appMetadata: {},
      userMetadata: {},
      aud: 'authenticated',
      createdAt: '2026-01-01T00:00:00.000Z',
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Validaciones de Contraseña y Email', () {
    test('rechaza contraseñas menores de 8 caracteres', () {
      expect(ResetPasswordPage.validatePassword(''), isNotNull);
      expect(ResetPasswordPage.validatePassword(null), isNotNull);
      expect(
        ResetPasswordPage.validatePassword('Ab1'),
        equals('La contraseña debe tener al menos 8 caracteres'),
      );
      expect(
        ResetPasswordPage.validatePassword('Abcdef1'),
        equals('La contraseña debe tener al menos 8 caracteres'),
      );
    });

    test('rechaza contraseñas sin mayúsculas, sin minúsculas o sin números', () {
      // Sin mayúsculas
      expect(
        ResetPasswordPage.validatePassword('abcdefg1'),
        equals(
          'La contraseña debe contener al menos una mayúscula, una minúscula y un número',
        ),
      );
      expect(ResetPasswordPage.passwordStrengthRegex.hasMatch('abcdefg1'), isFalse);

      // Sin minúsculas
      expect(
        ResetPasswordPage.validatePassword('ABCDEFG1'),
        equals(
          'La contraseña debe contener al menos una mayúscula, una minúscula y un número',
        ),
      );
      expect(ResetPasswordPage.passwordStrengthRegex.hasMatch('ABCDEFG1'), isFalse);

      // Sin números
      expect(
        ResetPasswordPage.validatePassword('Abcdefgh'),
        equals(
          'La contraseña debe contener al menos una mayúscula, una minúscula y un número',
        ),
      );
      expect(ResetPasswordPage.passwordStrengthRegex.hasMatch('Abcdefgh'), isFalse);
    });

    test('acepta contraseñas válidas con >= 8 caracteres, mayúscula, minúscula y número', () {
      expect(ResetPasswordPage.validatePassword('Hookah123'), isNull);
      expect(ResetPasswordPage.validatePassword('Segura2026!'), isNull);
      expect(ResetPasswordPage.passwordStrengthRegex.hasMatch('Hookah123'), isTrue);
    });

    test('validador de email rechaza formatos inválidos y acepta correos válidos', () {
      // Inválidos
      expect(ForgotPasswordPage.validateEmail(null), isNotNull);
      expect(ForgotPasswordPage.validateEmail(''), isNotNull);
      expect(ForgotPasswordPage.validateEmail('   '), isNotNull);
      expect(ForgotPasswordPage.validateEmail('usuario'), isNotNull);
      expect(ForgotPasswordPage.validateEmail('usuario@'), isNotNull);
      expect(ForgotPasswordPage.validateEmail('usuario@dominio'), isNotNull);
      expect(ForgotPasswordPage.validateEmail('@dominio.com'), isNotNull);

      // Válidos
      expect(ForgotPasswordPage.validateEmail('user@hookahub.com'), isNull);
      expect(ForgotPasswordPage.validateEmail('nombre.apellido@sub.dominio.es'), isNull);
      expect(ForgotPasswordPage.validateEmail('  user_123@gmail.com  '), isNull);
    });
  });

  group('Lógica de Estado de AuthProvider — Recuperación de Contraseña', () {
    test('sendPasswordResetEmail devuelve null cuando el envío es exitoso', () async {
      final fakeSvc = FakeAuthSupabaseService();
      final authProvider = AuthProvider(fakeSvc);

      final result = await authProvider.sendPasswordResetEmail('  test@hookahub.com  ');

      expect(result, isNull);
      expect(fakeSvc.lastResetEmail, equals('test@hookahub.com'));

      authProvider.dispose();
    });

    test('sendPasswordResetEmail traduce AuthException, rate limit y errores de red con AppErrorMapper.toSpanish()', () async {
      final fakeSvc = FakeAuthSupabaseService();
      final authProvider = AuthProvider(fakeSvc);

      // 1. Rate limit AuthException
      const rateLimitError = AuthException(
        'For security purposes, you can only request this once every 60 seconds',
        code: 'over_email_send_rate_limit',
      );
      fakeSvc.errorToThrow = rateLimitError;
      final rateLimitMsg = await authProvider.sendPasswordResetEmail('test@hookahub.com');
      expect(rateLimitMsg, equals(AppErrorMapper.toSpanish(rateLimitError)));
      expect(rateLimitMsg, contains('Has superado el límite de intentos'));

      // 2. Formato de correo inválido AuthException
      const invalidEmailError = AuthException(
        'Unable to validate email address: invalid format',
        code: 'invalid_email',
      );
      fakeSvc.errorToThrow = invalidEmailError;
      final invalidEmailMsg = await authProvider.sendPasswordResetEmail('bad@email.com');
      expect(invalidEmailMsg, equals(AppErrorMapper.toSpanish(invalidEmailError)));
      expect(invalidEmailMsg, contains('El formato del correo electrónico no es válido'));

      // 3. Error de red (SocketException)
      const networkError = SocketException('Failed host lookup');
      fakeSvc.errorToThrow = networkError;
      final networkMsg = await authProvider.sendPasswordResetEmail('test@hookahub.com');
      expect(networkMsg, equals(AppErrorMapper.toSpanish(networkError)));
      expect(networkMsg, equals('Sin conexión a internet. Revisa tu red.'));

      authProvider.dispose();
    });

    test('AuthChangeEvent.passwordRecovery activa isPasswordRecovery, notifica listeners y evita autenticar prematuramente', () async {
      final streamController = StreamController<AuthState>.broadcast();
      final fakeGoTrue = FakeGoTrueClient(authStateStream: streamController.stream);
      final fakeClient = FakeSupabaseClient(authClient: fakeGoTrue);
      final fakeSvc = FakeAuthSupabaseService(client: fakeClient);
      final authProvider = AuthProvider(fakeSvc);

      bool recoveryListenerTriggered = false;
      authProvider.addPasswordRecoveryListener(() {
        recoveryListenerTriggered = true;
      });

      expect(authProvider.isPasswordRecovery, isFalse);
      expect(authProvider.isAuthenticated, isFalse);

      // Emitir evento passwordRecovery con sesión temporal
      streamController.add(
        AuthState(AuthChangeEvent.passwordRecovery, _createFakeSession()),
      );
      await Future<void>.delayed(Duration.zero);

      expect(authProvider.isPasswordRecovery, isTrue);
      expect(recoveryListenerTriggered, isTrue);
      // Aunque exista sesión temporal, isAuthenticated debe ser false para que AuthGate no redirija a MainNavigationPage
      expect(authProvider.user, isNotNull);
      expect(authProvider.isAuthenticated, isFalse);

      // Al actualizar la contraseña, se limpia el modo de recuperación
      final updateError = await authProvider.updatePassword('NuevaClave123');
      expect(updateError, isNull);
      expect(fakeSvc.lastUpdatedPassword, equals('NuevaClave123'));
      expect(authProvider.isPasswordRecovery, isFalse);
      expect(authProvider.isAuthenticated, isTrue);

      await streamController.close();
      authProvider.dispose();
    });
  });
}

