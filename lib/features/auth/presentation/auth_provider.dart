import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants.dart';
import '../../../core/data/supabase_service.dart';
import '../../../core/providers/database_health_provider.dart';
import '../../../core/utils/app_error_mapper.dart';
import '../../../core/utils/app_logger.dart';
import 'reset_password_page.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider(this._svc, {GlobalKey<NavigatorState>? navigatorKey})
      : _navigatorKey = navigatorKey ?? rootNavigatorKey {
    _sub = _svc.client.auth.onAuthStateChange.listen((event) async {
      _session = event.session;
      final ev = event.event;
      if (ev == AuthChangeEvent.passwordRecovery) {
        _isPasswordRecovery = true;
        _notifyPasswordRecovery();
        _openResetPasswordPage();
      } else if (_session != null &&
          (ev == AuthChangeEvent.signedIn ||
              ev == AuthChangeEvent.userUpdated)) {
        if (ev == AuthChangeEvent.userUpdated && _isPasswordRecovery) {
          _isPasswordRecovery = false;
        }
        // Solo crear perfil básico si no se creó durante el registro
        final user = _session!.user;
        final metadata = user.userMetadata;

        try {
          await _svc.ensureProfile(
            username: metadata?['username']?.toString(),
            displayName:
                metadata != null &&
                    metadata['first_name'] != null &&
                    metadata['last_name'] != null
                ? '${metadata['first_name']} ${metadata['last_name']}'
                : metadata?['first_name']?.toString() ??
                      metadata?['last_name']?.toString(),
            firstName: metadata?['first_name']?.toString(),
            lastName: metadata?['last_name']?.toString(),
            birthdate: metadata?['birthdate'] != null
                ? DateTime.tryParse(metadata!['birthdate'].toString())
                : null,
            bio: metadata?['bio']?.toString(),
          );
        } catch (e, stack) {
          AppLogger.warning(
            'No se pudo sincronizar ensureProfile durante cambio de estado de sesión: $e',
            error: e,
            stackTrace: stack,
          );
        }

        if (ev == AuthChangeEvent.signedIn && !_isPasswordRecovery) {
          _notifySignIn();
        }
      } else if (ev == AuthChangeEvent.signedOut || _session == null) {
        _isPasswordRecovery = false;
        _notifySignOut();
      }
      notifyListeners();
    });
    _session = _svc.client.auth.currentSession;
  }

  final SupabaseService _svc;
  final GlobalKey<NavigatorState> _navigatorKey;
  Session? _session;
  StreamSubscription<AuthState>? _sub;
  bool _isPasswordRecovery = false;
  bool _isResetRouteOpen = false;

  final List<VoidCallback> _signInListeners = [];
  final List<VoidCallback> _signOutListeners = [];
  final List<VoidCallback> _passwordRecoveryListeners = [];

  Session? get session => _session;
  User? get user => _session?.user;
  bool get isPasswordRecovery => _isPasswordRecovery;
  bool get isAuthenticated => user != null && !_isPasswordRecovery;

  /// Limpia el modo de recuperación de contraseña tras completarse o cancelarse.
  void clearPasswordRecovery() {
    if (_isPasswordRecovery) {
      _isPasswordRecovery = false;
      notifyListeners();
    }
  }

  /// Registra un listener que se ejecutará cuando el usuario inicie sesión
  void addSignInListener(VoidCallback listener) {
    _signInListeners.add(listener);
  }

  /// Desregistra un listener de inicio de sesión
  void removeSignInListener(VoidCallback listener) {
    _signInListeners.remove(listener);
  }

  /// Registra un listener que se ejecutará cuando el usuario cierre sesión
  void addSignOutListener(VoidCallback listener) {
    _signOutListeners.add(listener);
  }

  /// Desregistra un listener de cierre de sesión
  void removeSignOutListener(VoidCallback listener) {
    _signOutListeners.remove(listener);
  }

  /// Registra un listener para el evento de recuperación de contraseña
  void addPasswordRecoveryListener(VoidCallback listener) {
    _passwordRecoveryListeners.add(listener);
  }

  /// Desregistra un listener de recuperación de contraseña
  void removePasswordRecoveryListener(VoidCallback listener) {
    _passwordRecoveryListeners.remove(listener);
  }

  void _notifySignIn() {
    for (final listener in List<VoidCallback>.of(_signInListeners)) {
      try {
        listener();
      } catch (e, stack) {
        AppLogger.error('Error en listener de inicio de sesión', error: e, stackTrace: stack);
      }
    }
  }

  void _notifySignOut() {
    for (final listener in List<VoidCallback>.of(_signOutListeners)) {
      try {
        listener();
      } catch (e, stack) {
        AppLogger.error('Error en listener de cierre de sesión', error: e, stackTrace: stack);
      }
    }
  }

  void _notifyPasswordRecovery() {
    for (final listener in List<VoidCallback>.of(_passwordRecoveryListeners)) {
      try {
        listener();
      } catch (e, stack) {
        AppLogger.error(
          'Error en listener de recuperación de contraseña',
          error: e,
          stackTrace: stack,
        );
      }
    }
  }

  void _openResetPasswordPage() {
    if (_isResetRouteOpen) return;
    final nav = _navigatorKey.currentState;
    if (nav != null && nav.mounted) {
      _isResetRouteOpen = true;
      nav
          .push(
            MaterialPageRoute<void>(
              builder: (_) => const ResetPasswordPage(),
            ),
          )
          .whenComplete(() {
            _isResetRouteOpen = false;
          });
    }
  }

  Future<String?> signInEmail(String email, String password) async {
    try {
      await _svc
          .signInWithEmail(email: email, password: password)
          .timeout(supabaseReadTimeout);
      return null;
    } on AuthException catch (e) {
      return AppErrorMapper.toSpanish(e);
    } catch (e) {
      DatabaseHealthProvider.reportFailure(e);
      return AppErrorMapper.toSpanish(e);
    }
  }

  Future<String?> registerEmail(
    String email,
    String password, {
    String? username,
    String? firstName,
    String? lastName,
    DateTime? birthdate,
    String? bio,
  }) async {
    try {
      final response = await _svc
          .signUpWithEmail(
            email: email,
            password: password,
            data: {
              'username': username,
              'first_name': firstName,
              'last_name': lastName,
              'birthdate': birthdate?.toIso8601String(),
              'bio': bio,
            }..removeWhere((key, value) => value == null),
          )
          .timeout(supabaseReadTimeout);

      final registeredUser = response.user;
      if (registeredUser != null) {
        final identities = registeredUser.identities;
        if (identities == null || identities.isEmpty) {
          AppLogger.warning(
            'Intento de registro con correo ya existente (identities vacío).',
          );
          return AppErrorMapper.toSpanish(
            const AuthException(
              'User already registered',
              code: 'user_already_exists',
            ),
          );
        }

        // Si el usuario se crea inmediatamente (sin confirmación de email o con identidades válidas)
        await _svc
            .ensureProfile(
              username: username,
              displayName: firstName != null && lastName != null
                  ? '$firstName $lastName'
                  : firstName ?? lastName,
              firstName: firstName,
              lastName: lastName,
              birthdate: birthdate,
              bio: bio,
            )
            .timeout(supabaseReadTimeout);
      }

      return null;
    } on AuthException catch (e) {
      return AppErrorMapper.toSpanish(e);
    } catch (e) {
      DatabaseHealthProvider.reportFailure(e);
      return AppErrorMapper.toSpanish(e);
    }
  }

  Future<String?> signInGoogle() async {
    try {
      await _svc.signInWithGoogle();
      return null;
    } on AuthException catch (e) {
      return AppErrorMapper.toSpanish(e);
    } catch (e) {
      DatabaseHealthProvider.reportFailure(e);
      return AppErrorMapper.toSpanish(e);
    }
  }

  Future<String?> sendPasswordResetEmail(String email) async {
    try {
      await _svc
          .sendPasswordResetEmail(email.trim())
          .timeout(supabaseReadTimeout);
      return null;
    } on AuthException catch (e) {
      return AppErrorMapper.toSpanish(e);
    } catch (e) {
      DatabaseHealthProvider.reportFailure(e);
      return AppErrorMapper.toSpanish(e);
    }
  }

  Future<String?> updatePassword(String newPassword) async {
    try {
      await _svc
          .updatePassword(newPassword)
          .timeout(supabaseWriteTimeout);
      _isPasswordRecovery = false;
      notifyListeners();
      return null;
    } on AuthException catch (e) {
      return AppErrorMapper.toSpanish(e);
    } catch (e, stackTrace) {
      AppLogger.error(
        'Error al actualizar contraseña en recuperación',
        error: e,
        stackTrace: stackTrace,
      );
      DatabaseHealthProvider.reportFailure(e);
      return AppErrorMapper.toSpanish(e);
    }
  }

  Future<void> signOut() async {
    try {
      await _svc.signOut().timeout(supabaseReadTimeout);
    } catch (e) {
      DatabaseHealthProvider.reportFailure(e);
      // Ignorar error de signOut, ya que el token local se borrará de todos modos
    } finally {
      _session = null;
      _isPasswordRecovery = false;
      _notifySignOut();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _signInListeners.clear();
    _signOutListeners.clear();
    _passwordRecoveryListeners.clear();
    super.dispose();
  }
}
