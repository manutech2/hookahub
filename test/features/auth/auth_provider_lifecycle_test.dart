import 'package:flutter_test/flutter_test.dart';
import 'package:hookahub/core/data/supabase_service.dart';
import 'package:hookahub/features/auth/presentation/auth_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FakeGoTrueClient extends Fake implements GoTrueClient {
  @override
  Stream<AuthState> get onAuthStateChange => const Stream.empty();

  @override
  Session? get currentSession => null;
}

class FakeSupabaseClient extends Fake implements SupabaseClient {
  @override
  GoTrueClient get auth => FakeGoTrueClient();
}

class FakeUserIdentity extends Fake implements UserIdentity {}

class FakeAuthSupabaseService implements SupabaseService {
  bool signOutCalled = false;
  bool ensureProfileCalled = false;
  AuthResponse? signUpResponseToReturn;
  Object? signUpErrorToThrow;

  @override
  SupabaseClient get client => FakeSupabaseClient();

  @override
  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    Map<String, dynamic>? data,
  }) async {
    if (signUpErrorToThrow != null) {
      throw signUpErrorToThrow!;
    }
    return signUpResponseToReturn ?? AuthResponse();
  }

  @override
  Future<void> ensureProfile({
    String? username,
    String? displayName,
    String? firstName,
    String? lastName,
    DateTime? birthdate,
    String? bio,
  }) async {
    ensureProfileCalled = true;
  }

  @override
  Future<void> signOut() async {
    signOutCalled = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthProvider Lifecycle Listeners', () {
    test('addSignOutListener se ejecuta cuando se llama a signOut()', () async {
      final fakeSvc = FakeAuthSupabaseService();
      final authProvider = AuthProvider(fakeSvc);

      bool signOutListenerCalled = false;
      authProvider.addSignOutListener(() {
        signOutListenerCalled = true;
      });

      await authProvider.signOut();

      expect(fakeSvc.signOutCalled, isTrue);
      expect(signOutListenerCalled, isTrue);

      authProvider.dispose();
    });

    test('removeSignOutListener desregistra el callback correctamente', () async {
      final fakeSvc = FakeAuthSupabaseService();
      final authProvider = AuthProvider(fakeSvc);

      int callCount = 0;
      void listener() {
        callCount++;
      }

      authProvider.addSignOutListener(listener);
      authProvider.removeSignOutListener(listener);

      await authProvider.signOut();

      expect(callCount, 0);

      authProvider.dispose();
    });
  });

  group('AuthProvider registerEmail — Detección de usuario duplicado (GoTrue)', () {
    test(
      'retorna mensaje de usuario ya existente y NO llama a ensureProfile cuando User.identities está vacío []',
      () async {
        final fakeSvc = FakeAuthSupabaseService()
          ..signUpResponseToReturn = AuthResponse(
            user: const User(
              id: 'existing-user-id',
              appMetadata: {},
              userMetadata: {},
              aud: 'authenticated',
              createdAt: '2026-01-01T00:00:00.000Z',
              identities: [],
            ),
          );
        final authProvider = AuthProvider(fakeSvc);

        final error = await authProvider.registerEmail(
          'duplicado@hookahub.com',
          'Hookah123!',
          username: 'hookah_user',
          firstName: 'Juan',
          lastName: 'Pérez',
        );

        expect(
          error,
          equals('Ya existe una cuenta registrada con este correo electrónico.'),
        );
        expect(fakeSvc.ensureProfileCalled, isFalse);

        authProvider.dispose();
      },
    );

    test(
      'retorna null y ejecuta ensureProfile cuando User.identities contiene un elemento válido',
      () async {
        final fakeSvc = FakeAuthSupabaseService()
          ..signUpResponseToReturn = AuthResponse(
            user: User(
              id: 'new-user-id',
              appMetadata: const {},
              userMetadata: const {},
              aud: 'authenticated',
              createdAt: '2026-01-01T00:00:00.000Z',
              identities: [FakeUserIdentity()],
            ),
          );
        final authProvider = AuthProvider(fakeSvc);

        final error = await authProvider.registerEmail(
          'nuevo@hookahub.com',
          'Hookah123!',
          username: 'nuevo_user',
          firstName: 'Ana',
          lastName: 'García',
        );

        expect(error, isNull);
        expect(fakeSvc.ensureProfileCalled, isTrue);

        authProvider.dispose();
      },
    );

    test(
      'captura AuthException directa (user_already_exists) cuando la protección contra enumeración está desactivada',
      () async {
        final fakeSvc = FakeAuthSupabaseService()
          ..signUpErrorToThrow = const AuthException(
            'User already registered',
            code: 'user_already_exists',
          );
        final authProvider = AuthProvider(fakeSvc);

        final error = await authProvider.registerEmail(
          'duplicado@hookahub.com',
          'Hookah123!',
        );

        expect(
          error,
          equals('Ya existe una cuenta registrada con este correo electrónico.'),
        );
        expect(fakeSvc.ensureProfileCalled, isFalse);

        authProvider.dispose();
      },
    );
  });
}
