import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart' as gsi;
import '../config/env.dart';
import '../constants.dart';
import '../utils/app_logger.dart';

class SupabaseService {
  // Singleton — todas las llamadas a SupabaseService() devuelven la misma instancia.
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  SupabaseClient get client => Supabase.instance.client;

  // Auth API

  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) {
    return client.auth.signInWithPassword(email: email, password: password);
  }

  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    Map<String, dynamic>? data,
  }) {
    return client.auth.signUp(
      email: email,
      password: password,
      data: data,
      emailRedirectTo:
          'io.supabase.flutter://login-callback/', // Deep link para confirmación
    );
  }

  Future<void> sendPasswordResetEmail(String email) {
    return client.auth.resetPasswordForEmail(
      email.trim(),
      redirectTo: 'io.supabase.flutter://login-callback/',
    );
  }

  Future<UserResponse> updatePassword(String newPassword) {
    return client.auth.updateUser(
      UserAttributes(password: newPassword),
    );
  }

  Future<void> signOut() async {
    // Sign out del proveedor nativo de Google si fue utilizado
    try {
      await gsi.GoogleSignIn.instance.signOut();
    } catch (e) {
      AppLogger.debug('GoogleSignIn.signOut no requirió acción o falló: $e');
    }
    return client.auth.signOut();
  }

  /// Asegura que exista un perfil para el usuario recién autenticado
  Future<void> ensureProfile({
    String? username,
    String? displayName,
    String? firstName,
    String? lastName,
    DateTime? birthdate,
    String? bio,
  }) async {
    final user = client.auth.currentUser;
    if (user == null) return;
    final uid = user.id;
    final email = user.email;
    // Construir datos de perfil
    final hasExplicitProfileFields =
        username != null ||
        displayName != null ||
        firstName != null ||
        lastName != null ||
        birthdate != null ||
        bio != null;

    final profileData = <String, dynamic>{
      'id': uid,
      'username':
          username ??
          (email?.split('@').first ?? 'user_${uid.substring(0, 6)}'),
      'email': email,
      'display_name':
          displayName ?? firstName ?? email?.split('@').first ?? 'Usuario',
      'bio': bio,
      'birthdate': birthdate?.toIso8601String(),
      if (!hasExplicitProfileFields) 'is_public': true,
    }..removeWhere((key, value) => value == null);

    // Crear perfil si no existe; solo actualizar si se pasaron campos explícitos (ej. registro).
    await client
        .from('profiles')
        .upsert(
          profileData,
          onConflict: 'id',
          ignoreDuplicates: !hasExplicitProfileFields,
        )
        .timeout(supabaseWriteTimeout);

    // Crear configuración por defecto solo si no existe fila previa para el usuario
    await client
        .from('user_settings')
        .upsert(
          {
            'user_id': uid,
            'theme': 'system',
            'push_notifications': true,
            'email_notifications': false,
            'analytics_opt_in': false,
          },
          onConflict: 'user_id',
          ignoreDuplicates: true,
        )
        .timeout(supabaseWriteTimeout);
  }

  // OAuth Google Nativo
  Future<void> signInWithGoogle() async {
    final webClientId = Env.googleWebClientId;
    final iosClientId = Env.googleIosClientId;

    if (webClientId.isEmpty) {
      throw const AuthException(
        'Falta GOOGLE_WEB_CLIENT_ID en las variables de entorno. Por favor, configúralo en .env.',
      );
    }

    final signInInstance = gsi.GoogleSignIn.instance;
    await signInInstance.initialize(
      serverClientId: webClientId,
      clientId: iosClientId.isNotEmpty ? iosClientId : null,
    );

    gsi.GoogleSignInAccount googleUser;
    try {
      googleUser = await signInInstance.authenticate();
    } on gsi.GoogleSignInException catch (e) {
      if (e.code == gsi.GoogleSignInExceptionCode.canceled) {
        throw const AuthException('El inicio de sesión fue cancelado.');
      }
      throw AuthException(
        'Error al iniciar sesión con Google: ${e.toString()}',
      );
    }

    final googleAuth = googleUser.authentication;
    final idToken = googleAuth.idToken;

    if (idToken == null) {
      throw const AuthException('No se pudo obtener el ID Token de Google.');
    }

    // El accessToken opcional se solicita obteniendo la autorización del cliente
    String? accessToken;
    try {
      final authClient = await googleUser.authorizationClient.authorizeScopes(
        [],
      );
      accessToken = authClient.accessToken;
    } catch (e) {
      // Ignorar de forma segura si no podemos obtener accessToken opcional
      AppLogger.debug('AccessToken opcional de Google no concedido: $e');
    }

    await client.auth
        .signInWithIdToken(
          provider: OAuthProvider.google,
          idToken: idToken,
          accessToken: accessToken,
        )
        .timeout(supabaseWriteTimeout);
  }
}
