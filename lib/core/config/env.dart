/// Configuración de variables de entorno inyectadas en tiempo de compilación.
///
/// Se utiliza `--dart-define-from-file=.env` durante la ejecución o compilación.
/// De esta forma se evita empaquetar archivos de texto plano dentro de los
/// assets de la aplicación y se elimina el coste de lectura asíncrona en el arranque.
abstract final class Env {
  /// URL del proyecto de Supabase.
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  /// Clave pública anónima (anon key) de Supabase.
  static const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Client ID web de Google para Google Sign-In (OAuth).
  static const String googleWebClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');

  /// Client ID iOS de Google para Google Sign-In (OAuth).
  static const String googleIosClientId = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');

  /// Ad Unit ID de Banner de AdMob para Android (producción).
  static const String admobBannerAndroidId = String.fromEnvironment('ADMOB_BANNER_ANDROID_ID');

  /// Ad Unit ID de Banner de AdMob para iOS (producción).
  static const String admobBannerIosId = String.fromEnvironment('ADMOB_BANNER_IOS_ID');

  /// Ad Unit ID de Intersticial de AdMob para Android (producción).
  static const String admobInterstitialAndroidId = String.fromEnvironment('ADMOB_INTERSTITIAL_ANDROID_ID');

  /// Ad Unit ID de Intersticial de AdMob para iOS (producción).
  static const String admobInterstitialIosId = String.fromEnvironment('ADMOB_INTERSTITIAL_IOS_ID');

  /// Identificador numérico de la app en Apple App Store (ej. para reseñas).
  static const String appleAppStoreId = String.fromEnvironment('APPLE_APP_STORE_ID');

  /// Nombre de versión de la aplicación inyectado automáticamente por Flutter
  /// a partir del campo `version` de `pubspec.yaml` (ej. "1.1.0").
  static const String appVersion = String.fromEnvironment(
    'FLUTTER_BUILD_NAME',
    defaultValue: '1.1.0',
  );

  /// Número de compilación (build number) inyectado automáticamente por Flutter
  /// a partir del campo `version` de `pubspec.yaml` (ej. "2").
  static const String appBuildNumber = String.fromEnvironment(
    'FLUTTER_BUILD_NUMBER',
    defaultValue: '2',
  );

  /// Comprueba si las variables mínimas esenciales de Supabase están definidas.
  static bool get isSupabaseConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
