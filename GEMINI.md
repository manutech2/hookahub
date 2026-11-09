# Hookahub - Mejores Prácticas y Soluciones (GEMINI)

Este documento recopila las soluciones arquitectónicas, problemas resueltos y reglas descubiertas durante el desarrollo de la aplicación, para que sirvan como referencia en futuras implementaciones dictadas a asistentes de inteligencia artificial.

## 🔐 Autenticación y Seguridad

### Integración Nativa de Google SignIn (google_sign_in ^7.0.0+)

Durante la migración a autenticación nativa de Google para iOS y Android junto con Supabase, se descubrieron los siguientes _Breaking Changes_ y configuraciones esenciales:

1. **La API actua como Singleton:**
   - A partir de la versión 7, ya no se debe instanciar `GoogleSignIn()`. En su lugar, se utiliza el patrón `GoogleSignIn.instance`.
2. **Ciclo de inicialización estricto:**
   - Es obligatorio llamar y hacer un _await_ a `GoogleSignIn.instance.initialize(serverClientId: webClientId, clientId: iosClientId)` antes de intentar iniciar sesión.
   - La recuperación del selector de cuentas se hace mediante `GoogleSignIn.instance.authenticate()`, la cual, en caso de que el usuario lo cancele, devuelve una excepción tratable `GoogleSignInException(code: GoogleSignInExceptionCode.canceled)`, en vez de devolver directamente `null`.

### Huellas SHA-1 y Flujo de Desarrollo Activo vs Producción

Para que Google reconozca adecuadamente a la aplicación en Android durante el Login y no cancele automáticamente el intento sin mostrar el selector de cuentas:

- Es imperativo tener registradas en Google Cloud Console **dos Credenciales para Android**:
  1. **Depuración (Debug)**: Generada automáticamente al probar en emulador (clave: `debug.keystore`).
  2. **Producción (Release)**: Vinculada al fichero `upload-keystore.jks` utilizado mediante `key.properties` para construir el Google Play AppBundle (`.aab`).

### Detección de Usuario Ya Registrado en Supabase Auth (identities.isEmpty)

- **Problema**: Cuando un usuario intenta registrarse con un correo electrónico que ya existe en Supabase Auth y el proyecto tiene activada la confirmación de correo junto con la protección contra enumeración de usuarios (*Email Enumeration Protection*), Supabase GoTrue **no lanza una `AuthException`**. En su lugar, responde con HTTP 200 y un objeto `AuthResponse` donde `response.user != null`, pero su propiedad `identities` es una lista vacía (`response.user!.identities == null || response.user!.identities!.isEmpty`). Asumir que la ausencia de excepción equivale a un registro exitoso provoca falsos positivos en la UI ("Registro exitoso"), llamadas innecesarias a `ensureProfile()` y confusión en el usuario al no recibir ningún correo de verificación.
- **Solución Arquitectónica (Regla de Oro)**:
  1. **Inspección obligatoria de `identities`**: En todo flujo de registro por correo (`AuthProvider.registerEmail`), tras invocar `signUp`, es obligatorio verificar si `response.user != null` y comprobar el contenido de `response.user!.identities`:
     ```dart
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
       // Solo sincronizar perfil cuando existen identidades reales
       await _svc.ensureProfile(...);
     }
     ```
  2. **Doble barrera de compatibilidad**: Mantener siempre el bloque `on AuthException catch (e)` delegado en `AppErrorMapper.toSpanish(e)` para cubrir entornos donde la protección contra enumeración esté desactivada y GoTrue arroje directamente el código `user_already_exists`.
  3. **Resiliencia en UI (`RegisterPage`)**: Si `registerEmail` devuelve error, detener el estado de carga (`_isLoading = false`), mantener al usuario en la pantalla sin ejecutar `Navigator.pop(context)`, resaltar el error en el campo de correo electrónico (con `Semantics(liveRegion: true)` para accesibilidad) y ofrecer accesos directos hacia **Iniciar sesión** y **¿Olvidaste tu contraseña?**.

## 📁 Estructura y Seguridad del Repositorio

- Siempre ignorar (`.gitignore`) ficheros como `.env`, `key.properties`, y cualquier `.keystore` o `.jks` que contenga claves criptográficas o IDs críticos en texto plano.

### Prohibición de .env en Assets e Inyección Vía --dart-define-from-file

- **Problema**: Declarar `- .env` bajo `assets:` en `pubspec.yaml` empaqueta el archivo de variables y credenciales en texto plano dentro del bundle compilado (APK/AAB/IPA en `flutter_assets/.env`). Adicionalmente, al estar `.env` en `.gitignore`, los pipelines de CI/CD fallan durante `flutter build` al no existir el archivo físico en el runner. Además, parsear el archivo con `flutter_dotenv` en el `main()` introduce latencia innecesaria de I/O en el arranque.
- **Solución Arquitectónica (Regla de Oro)**:
  1. **Prohibido en `pubspec.yaml`**: Ningún archivo con sufijo `.env` debe incluirse bajo la clave `assets:`, y se prescinde de `flutter_dotenv`.
  2. **Inyección en compilación**: Las variables se pasan en tiempo de build mediante el flag `--dart-define-from-file=.env` (ej. `flutter run --dart-define-from-file=.env` o `flutter build apk --dart-define-from-file=.env`).
  3. **Acceso tipado e inmutable**: Centralizar todas las constantes en `lib/core/config/env.dart` mediante `static const String key = String.fromEnvironment('KEY')`, permitiendo al compilador incrustar los valores directamente en el código máquina AOT sin lecturas de disco en runtime.
  4. **Soporte IDE (VS Code)**: Configurar tanto `.vscode/settings.json` con `"dart.flutterAdditionalArgs": ["--dart-define-from-file=.env"]` (para garantizar la inyección automática en cualquier modo: CodeLens sobre `main()`, barra de estado o F5) como `.vscode/launch.json` con `"args": ["--dart-define-from-file=.env"]` y `"program": "lib/main.dart"`.

### Endurecimiento Nativo y Prevención de Fugas de Sesión en Backups de la Nube

- **Problema**: Por defecto, Android respalda automáticamente el contenido del almacenamiento interno de la app (incluyendo archivos XML de `SharedPreferences` con los tokens JWT de sesión de Supabase) en el Google Drive personal del usuario si `android:allowBackup` no está configurado explícitamente.
- **Solución (Regla de Oro)**: Configurar indefectiblemente `android:allowBackup="false"` dentro de la etiqueta `<application>` en `android/app/src/main/AndroidManifest.xml` para garantizar que las sesiones no se sincronicen fuera del sandbox seguro del dispositivo físico.
- **Protección ProGuard/R8 para Release**: En compilaciones productivas (`buildTypes.release` en `android/app/build.gradle.kts`), se debe vincular un archivo `proguard-rules.pro` que declare explícitamente `-keep` sobre los bindings de Flutter y los paquetes `com.google.android.gms.auth.api.signin.**` para evitar que el compilador R8 descarte o dañe clases requeridas por Google Sign-In durante la ofuscación.

### Compatibilidad de Toolchain Android en Flutter 3.47+ (Gradle, AGP, Kotlin y JDK)

- **Problema**: Tras actualizar a Flutter 3.47+ (o al cambiar de versión de Android Studio), pueden surgir múltiples incompatibilidades en cascada durante `flutter build apk`:
  1. Gradle 8.11.1 inferior al mínimo requerido por Flutter 3.47 (`8.14.0`).
  2. Android Studio incluye un JBR (Java 25) que no es compatible con Gradle 8.x (requiere Gradle 9+).
  3. El Android Gradle Plugin (AGP) 8.9.1 es inferior al mínimo soportado por Flutter (`8.11.1`).
  4. El plugin de Kotlin (`org.jetbrains.kotlin.android`) 2.2.0 es inferior al mínimo soportado (`2.2.20`).
- **Solución y Matriz de Versiones**:
  - **JDK**: Apuntar Flutter a JDK 21 LTS mediante `flutter config --jdk-dir=/Library/Java/JavaVirtualMachines/temurin-21.jdk/Contents/Home` para evitar el JBR experimental de Android Studio.
  - **Gradle Wrapper** (`android/gradle/wrapper/gradle-wrapper.properties`): Fijar `distributionUrl=https\://services.gradle.org/distributions/gradle-8.14-bin.zip`.
  - **AGP y Kotlin** (`android/settings.gradle.kts`):
    - `id("com.android.application") version "8.11.1"`
    - `id("org.jetbrains.kotlin.android") version "2.2.20"`
  - **Flags DSL** (`android/gradle.properties`): Declarar `android.builtInKotlin=false` y `android.newDsl=false` para garantizar compatibilidad con los plugins actuales.


### Estandarización de Capas por Feature (Clean Architecture)

- **Regla Estricta**: Cada módulo dentro de `lib/features/[feature]/` debe seguir estrictamente la separación de responsabilidades:
  ```text
  feature_name/
  ├── data/          # Fuentes de datos, implementaciones de repositorios, mapeadores
  ├── domain/        # Entidades, modelos puros de dominio, interfaces de repositorio
  └── presentation/  # UI (páginas, widgets específicos de la feature) y State Management (providers)
  ```
- **Prohibición de Vistas en la Raíz de la Feature**: Ninguna página, pantalla o widget (`*_page.dart`, `*_screen.dart`, `*_view.dart`) ni clase de gestión de estado (`*_provider.dart`) puede residir en la raíz de `lib/features/[feature]/`. Todas las vistas y providers deben alojarse indefectiblemente bajo la subcarpeta `presentation/` (o subcarpetas de esta, ej. `presentation/providers/`).
- **Features de Orquestación o Agregación (ej. `features/search/`)**: Aunque una feature no cuente con tablas o endpoints exclusivos propios (consumiendo repositorios de otros módulos), sus pantallas y controladores deben estar organizados dentro de `presentation/`, manteniendo una estructura canónica coherente y predecible a lo largo de todo el proyecto.

## 🗄️ Base de Datos y Funciones (Supabase)

### Funciones con "SECURITY DEFINER" (Vulnerabilidad de Search Path)

- Al crear funciones en PostgreSQL (Supabase) que requieran privilegios elevados (`SECURITY DEFINER`), es **obligatorio** fijar el `search_path` para evitar ataques de inyección y manipulación de funciones (ej. `ALTER FUNCTION nombre_funcion() SET search_path = public;`).
- Esto mitiga la advertencia del linter de seguridad de Supabase _"Function Search Path Mutable"_.

### Storage: Vulnerabilidad "Public Bucket Allows Listing"

- **Problema**: Supabase reporta "Public Bucket Allows Listing" (o data scraping) cuando un bucket público tiene una política RLS que permite `SELECT` genérico al rol `public` sobre la tabla `storage.objects`. Esto permite que cualquier atacante consulte el endpoint `/list` de la API de Storage para obtener el árbol completo de tus archivos.
- **Solución**: Dado que los archivos de un bucket marcado como "Público" (`public: true` en `storage.buckets`) ya son accesibles de forma individual por URL (`getPublicUrl()`), **no se requiere ninguna política `SELECT`** para que las imágenes puedan descargarse. La mejor práctica de seguridad es eliminar cualquier política `SELECT` genérica en buckets públicos, bloqueando así el listado de directorios sin romper la visualización de imágenes en la aplicación.

### Avatares de Usuario y Caché de Imágenes (UserAvatar)

- **Problema**: En listados masivos (como la pantalla de Comunidad o Favoritos), intentar generar signed URLs para avatares privados de otros usuarios genera un problema severo de N+1 peticiones de red asíncronas y falla debido a que las políticas RLS restringen la lectura de carpetas ajenas.
- **Solución Arquitectónica (Regla de Oro)**:
  1. **Bucket Público**: El bucket `avatars` se configura como público (`public: true`) sin política `SELECT` genérica sobre `storage.objects` (previniendo enumeración por scraping). Las operaciones de mutación (`INSERT`, `UPDATE`, `DELETE`) permanecen estrictamente restringidas al propietario de la carpeta (`name ~~ (auth.uid() || '/%')`).
  2. **Descarga Directa y Caché**: La URL se resuelve con `getPublicUrl()` y se consume con `CachedNetworkImage` fijando `memCacheWidth` y `memCacheHeight` proporcionales al tamaño del avatar en píxeles físicos del dispositivo, reduciendo el consumo de RAM.
  3. **Soporte Multiformato**: El widget `UserAvatar` gestiona automáticamente:
     - `icon:<index>`: Iconos predefinidos del sistema (`appAvatarIcons` en `constants.dart`).
     - Fotos (`storage path` o URL completa): Renderizado con caché de red y placeholders suaves.
     - Fallback / Error: Inicial del nombre de usuario en mayúscula sobre el color de la tarjeta/tema.
  4. **Versionado de Archivo y Cache Busting**: Guardar fotos con un nombre estático (ej. `avatar_current.jpg`) provoca que `CachedNetworkImage` y la CDN devuelvan indefinidamente la imagen antigua desde la caché local del móvil. Toda nueva imagen de avatar debe nombrarse con un timestamp único (`avatar_${DateTime.now().millisecondsSinceEpoch}.jpg`). La función `_cleanupOldAvatars` elimina los ficheros obsoletos en el bucket del usuario en Supabase Storage tras subir el nuevo, y el provider debe desalojar la URL previa con `CachedNetworkImage.evictFromCache(oldUrl)`.


### Tablas Públicas y Logs: Vulnerabilidad "RLS Policy Always True"

- **Problema**: Supabase reporta la advertencia "RLS Policy Always True" cuando una tabla pública (ej. `app_logs`) tiene una política RLS que permite operaciones `INSERT`, `UPDATE` o `DELETE` con `WITH CHECK (true)`. Esto permite que usuarios maliciosos inyecten datos basura de forma indiscriminada, evadiendo la seguridad a nivel de filas.
- **Solución**: Para las tablas de logs o similares que recogen datos generados por los usuarios desde la app, si solo hay usuarios registrados, se debe asignar la política de `INSERT` estrictamente al rol `authenticated`. Además, es imperativo validar en la cláusula `WITH CHECK` que el identificador del usuario que envía el registro corresponda con su propio token JWT (ej. `WITH CHECK (auth.uid() = user_id)`), garantizando que nadie pueda crear registros a nombre de otro usuario.

### Rendimiento en RLS: Vulnerabilidad "Auth RLS Initialization Plan"

- **Problema**: El linter de rendimiento de Supabase reporta "Auth RLS Initialization Plan" (`auth_rls_initplan`) cuando se usan funciones de autenticación (como `auth.uid()` o `auth.role()`) directamente en políticas RLS (`USING` o `WITH CHECK`). PostgreSQL evalúa la función por cada fila, lo que destruye el rendimiento en tablas grandes.
- **Solución (Regla de Oro)**: Al definir cualquier política RLS (tanto de SELECT, INSERT, UPDATE como DELETE), siempre se debe envolver la función en una subconsulta.
  - ❌ **Incorrecto**: `USING (auth.uid() = user_id)`
  - ✅ **Correcto**: `USING ((select auth.uid()) = user_id)`
  - ❌ **Incorrecto**: `USING (auth.role() = 'authenticated')`
  - ✅ **Correcto**: `USING ((select auth.role()) = 'authenticated')`

### Optimización de Conteo: Antipatrón `select('id').length` vs `count(CountOption.exact)`

- **Problema**: Realizar consultas como `_client.from('tabla').select('id').eq(...)` para luego computar la cantidad de registros en Dart mediante `(res as List).length` provoca **overfetching severo**: PostgREST genera y transmite un JSON con todos los UUIDs a través de la red móvil, y Dart reserva memoria en el heap para deserializar cada fila solo para descartarla tras leer la longitud.
- **Solución (Regla de Oro)**: Utilizar siempre el método nativo `.count(CountOption.exact)` del query builder de Supabase:
  - ✅ **Correcto**:
    ```dart
    final count = await _client
        .from('mixes')
        .count(CountOption.exact)
        .eq('author_id', user.id)
        .timeout(supabaseReadTimeout);
    return count;
    ```
  - **Beneficios**:
    1. **0 bytes en el payload** del cuerpo de la respuesta: Supabase ejecuta una petición HTTP `HEAD` con cabecera `Prefer: count=exact` y devuelve el número directamente en la cabecera `content-range`.
    2. **Cálculo a nivel de motor SQL**: PostgreSQL resuelve `COUNT(*)` optimizado por índices de clave foránea/primaria.
    3. **Resiliencia en UI**: En conteos secundarios o cosméticos, capturar `(e, stackTrace)`, registrar con `AppLogger.warning` y retornar `0` como fallback para evitar saturar la tabla remota `app_logs` ante micro-cortes.

### Sincronización de Ratings y Reseñas en Tablas Principales: Conflicto RLS y Triggers PostgreSQL

- **Problema**: Intentar actualizar columnas agregadas (ej. `mixes.rating` y `mixes.reviews`) desde el cliente Flutter tras crear una reseña (`reviews`) mediante `_updateMixRating()` falla de forma silenciosa debido a las políticas RLS. La tabla `mixes` solo permite `UPDATE` al propio autor (`author_id = (select auth.uid())`). Cuando un tercero reseña una mezcla, la actualización del cliente afecta a 0 filas y las columnas quedan desincronizadas.
- **Solución Arquitectónica (Regla de Oro)**:
  1. **En Base de Datos (Triggers)**: La agregación y sincronización de columnas denormalizadas (`rating`, `reviews`) debe ser responsabilidad exclusiva de **Triggers de PostgreSQL** con `SECURITY DEFINER` y `SET search_path = public` sobre la tabla de eventos (`reviews`), nunca delegarse en llamadas del cliente.
  2. **En Consultas Flutter (PostgREST Embedding)**: En todos los repositorios que consultan mezclas (`UserMixesRepository`, `CommunityRepository`, `FavoritesRepository`), solicitar siempre el conteo real embebido mediante `reviews_real:reviews(count)` en el `.select()` y mapearlo como fallback prioritario:
     ```dart
     reviews: (mixData['reviews_real'] as List?)?.firstOrNull?['count'] as int? ??
              (mixData['reviews'] as num?)?.toInt() ??
              0,
     ```
      Esto garantiza que la interfaz muestre el conteo fidedigno de reseñas en vivo sin depender de columnas estáticas desincronizadas.

### Sincronización Reactiva de Contadores en Perfil (Optimismo + Background Refresh)

- **Problema**: Tras crear o eliminar mezclas (`mixes`), el contador de mezclas en la pantalla de perfil (`ProfilePage`) quedaba desactualizado porque solo se recalculaba al llamar a `load()`, método que transiciona a `ProfileLoading` causando parpadeos de pantalla completa. Además, la navegación por pestañas (`main_navigation.dart`) no refrescaba el perfil si ya estaba cargado (`isLoaded == true`).
- **Solución Arquitectónica (Regla de Oro)**:
  1. **Actualización Optimista Inmediata**: En `ProfileProvider`, proveer `incrementMixesCount()` y `decrementMixesCount()` que actualizan inmutablemente `ProfileLoaded` vía `copyWith(mixesCount: ...)` y notifican inmediatamente a la UI sin emitir `ProfileLoading`.
  2. **Sincronización Silenciosa en Segundo Plano**: Exponer `refreshMixesCount()`, que consulta `countCurrentUserMixes()` de forma asíncrona y sincroniza `ProfileLoaded` solo si el valor difiere, gestionando errores con `AppLogger.warning`.
  3. **Notificación en Puntos de Mutación**: Tras la creación (`create_mix_page.dart`) o eliminación (`user_mixes_page.dart`, `mix_detail_page.dart`, `community_page.dart`, `favorites_page.dart`), ejecutar la actualización optimista, disparar `unawaited(profileProvider.refreshMixesCount())` y refrescar `UserMixesProvider`.
  4. **Navegación y Pull-To-Refresh**: Al seleccionar la pestaña de Perfil en `main_navigation.dart` (`onTap` y `_onTabFirstEnter`), ejecutar `unawaited(profileProvider.refreshMixesCount())`. En `ProfilePage`, envolver el cuerpo en un `RefreshIndicator` (`onRefresh: () => Future.wait([profileProvider.load(), favoritesProvider.load()])`) con `AlwaysScrollableScrollPhysics` para permitir recarga manual completa.

## 📝 Logging Centralizado (AppLogger)

- **Regla Estricta**: Está **PROHIBIDO** el uso directo de `print()` y `debugPrint()` a lo largo de toda la aplicación.
- **Implementación**: Se debe utilizar siempre la clase estática `AppLogger` (ubicada en `lib/core/utils/app_logger.dart`).
- **Niveles de Log**:
  - `AppLogger.info()` / `AppLogger.debug()` / `AppLogger.warning()`: Para seguimiento de flujo y estados. No se imprimen en producción.
  - `AppLogger.error()` / `AppLogger.fatal()`: Para manejar excepciones (`catch (e, stackTrace)`). Requieren de los parámetros nombrados `error` y opcionalmente `stackTrace` (ej. `AppLogger.error("Mensaje", error: e ?? 'Error desconocido', stackTrace: stack)`). Además de imprimirse en desarrollo, envían la información remotamente a la tabla `app_logs` de Supabase.

### Falsos Positivos y Desconexiones de Realtime

- **Problema**: La tabla `app_logs` se satura rápidamente con falsos errores críticos provenientes de desconexiones temporales de **Supabase Realtime** (ej. `RealtimeSubscribeException` por expiración de token al estar la app en segundo plano, o `RealtimeCloseEvent` código 1006 al perder cobertura).
- **Solución (Filtrado)**: Las excepciones transitorias derivadas de la pérdida de socket o expiración de sesión capturadas en bloques `onError` de un `Stream` **nunca** deben enviarse mediante `AppLogger.error()`. Se debe comprobar la naturaleza del error (ej. filtrando por `RealtimeSubscribeException`, `RealtimeCloseEvent` o `InvalidJWTToken`) y, en su lugar, emitir un `AppLogger.warning()`. De esta forma, el SDK de Supabase se encarga de re-conectar automáticamente en silencio sin consumir cuota de base de datos registrando falsos errores en remoto.

### Healthcheck de Red vs Errores Críticos (DatabaseHealthService)

- **Problema**: Registrar fallos de conectividad física (`SocketException`) o tiempos de espera (`TimeoutException`) durante la comprobación periódica de salud como `AppLogger.error()` genera inserciones fallidas o redundantes en la tabla remota `app_logs` de Supabase cuando el dispositivo no dispone de conexión a internet.
- **Solución**: En servicios de diagnóstico y healthcheck de red (como [DatabaseHealthService](file:///Users/manutgrt/Proyectos/hookahub/lib/core/services/database_health_service.dart)), las excepciones de red (`TimeoutException`, `SocketException`) deben registrarse exclusivamente con `AppLogger.warning(...)`. Únicamente los errores genuinos de base de datos (`PostgrestException`), autenticación (`AuthException`) o excepciones inesperadas deben registrarse con `AppLogger.error(..., error: e, stackTrace: stackTrace)`.

## 🎨 UI/UX y Consistencia Visual

### Gestión de Resultados Múltiples (Pestañas Dinámicas)

- **Problema**: Mostrar múltiples tipos de resultados (ej. Tabacos y Mezclas) en una única lista vertical resulta confuso y requiere demasiado espacio (scroll infinito).
- **Solución (Tabs Dinámicos)**: Para pantallas que consolidan búsquedas, se debe utilizar `DefaultTabController` junto con un `TabBar`.
  - Se mostrarán las pestañas **únicamente** si hay resultados en ambas categorías (`showTabs = listaA.isNotEmpty && listaB.isNotEmpty`).
  - Si solo hay resultados de un tipo, se prescinde del `TabBar` para simplificar la interfaz.

### Sistema de Colores Global: Formularios y Pantallas (Regla de Oro)

- **Regla Estricta**: Está **PROHIBIDO** usar colores hexadecimales hardcodeados (`Color(0xFF...)`) para los elementos de formulario o el fondo de pantallas. Siempre se deben usar las constantes centralizadas definidas en `lib/core/constants.dart`.
- **Tabla de constantes obligatorias**:

  | Elemento                       | Constante (dark)                                    | Constante (light)                  |
  | ------------------------------ | --------------------------------------------------- | ---------------------------------- |
  | `fillColor` de campos de texto | `fieldDark` → `Color(0xFF26343A)`                   | `fieldLight` → `Color(0xFFE0F7F4)` |
  | Color de labels/etiquetas      | `darkNavy` → `Color(0xFFB2DFDB)`                    | `navy` → `Color(0xFF23404A)`       |
  | Color de borde de campos       | `turquoiseDark` (siempre, en ambos temas)           | `turquoiseDark`                    |
  | Fondo del `Scaffold`           | `theme.scaffoldBackgroundColor` (siempre explícito) | `theme.scaffoldBackgroundColor`    |

- **Patrón de implementación correcto** para cualquier campo de formulario:
  ```dart
  // ✅ Correcto
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final fillColor = isDark ? fieldDark : fieldLight;
  const borderColor = turquoiseDark;
  // En el label:
  color: isDark ? darkNavy : navy,
  ```
  ```dart
  // ❌ Incorrecto
  final fillColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
  final borderColor = Theme.of(context).primaryColor;
  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF334155),
  ```
- **Import requerido**: Cualquier archivo que use estas constantes debe importar `'../../../core/constants.dart'` (ajustando la ruta relativa según la profundidad del archivo).

### Patrón Completo: Formulario con Envío a Supabase (Solicitud de Tabaco)

Este patrón documenta cómo implementar correctamente una pantalla de formulario que persiste datos en una tabla de Supabase, siguiendo Clean Architecture. Sirve como referencia para cualquier funcionalidad similar (ej. formularios de reporte, solicitudes, feedback).

#### 1. Base de datos (Supabase)

- **Tabla**: `tobacco_requests` con columnas `id (uuid PK)`, `user_id (FK → auth.users)`, `brand`, `name`, `description`, `flavors` (texto plano), `status` (`pending|approved|rejected`), `created_at`.
- **RLS**: solo política `INSERT` para rol `authenticated` con `WITH CHECK ((select auth.uid()) = user_id)`. **Sin política `SELECT`** si el usuario no necesita ver historial.
- Las migraciones SQL se documentan en `supabase/migrations/` con nombre `YYYYMMDD_nombre_migracion.sql`.

#### 2. Repositorio (`data/`)

- Añadir el método al repositorio existente de la feature (ej. `TobaccoRepository`), no crear uno nuevo, salvo que el dominio sea claramente distinto.
- El método debe aceptar parámetros nombrados (`required` para campos obligatorios, opcionales para el resto) y usar `.timeout()` consistente con el resto del repositorio.
- Los campos opcionales que lleguen vacíos se deben filtrar antes del `insert` usando colecciones condicionales `if (campo != null && campo.isNotEmpty) 'col': campo`.

#### 3. Provider con estados sellados (`presentation/providers/`)

- **Regla Estricta**: nunca usar booleanos fragmentados (`isLoading`, `hasError`). Siempre usar una `sealed class` con los estados necesarios:
  ```dart
  sealed class MiFormularioState {}
  class MiFormularioInitial extends MiFormularioState {}
  class MiFormularioLoading extends MiFormularioState {}
  class MiFormularioSuccess extends MiFormularioState {}
  class MiFormularioError extends MiFormularioState {
    MiFormularioError(this.message);
    final String message;
  }
  ```
- El provider obtiene el `user_id` internamente desde `SupabaseService().client.auth.currentUser` y gestiona el caso `null` (usuario no autenticado).
- Los errores se registran siempre con `AppLogger.error('...', error: e, stackTrace: stack)`.
- Exponer un método `reset()` para volver al estado `Initial` tras un error.

#### 4. UI (`presentation/`)

- Usar `ChangeNotifierProvider` creado localmente en la pantalla raíz (patrón igual que `CreateMixPage`), no en el árbol global.
- Separar la pantalla en dos widgets: uno de "shell" que crea el provider (`StatelessWidget`) y uno interno con el formulario (`StatefulWidget`).
- **Estado Loading**: deshabilitar el botón (`onPressed: isLoading ? null : callback`) y mostrar `CircularProgressIndicator` dentro del botón con tamaño fijo (`SizedBox(height: 22, width: 22)`).
- **Estado Success**: mostrar snackbar verde + `Navigator.pop()` con un `await Future.delayed` breve (800ms) para que el usuario vea el mensaje.
- **Estado Error**: mostrar snackbar rojo con el mensaje del estado + llamar a `provider.reset()` para permitir reenvío.
- Usar `context.select<MiProvider, bool>(...)` en vez de `Consumer` completo cuando solo se necesita un único campo del estado (más eficiente).

### Reutilización de Widgets y Grids (Consistencia)

- **Problema**: Las listas de resultados a menudo utilizan `ListView` genéricos con tarjetas simplificadas, rompiendo la experiencia con pantallas dedicadas como "Catálogo" que utilizan `GridView` más visuales.
- **Solución**: Se debe mantener la **estricta consistencia visual**. Si en la aplicación principal (ej. "Catálogo") un elemento (ej. Tabaco) se muestra en un formato de cuadrícula (`GridView` con 2 columnas, priorizando la imagen y usando `SliverGridDelegateWithFixedCrossAxisCount` responsivo al `scaleFactor`), los resultados de la búsqueda de ese mismo elemento deben **clonar esa misma distribución y tarjeta de visualización**. No se debe cambiar drásticamente el layout del elemento dependiendo de la pantalla en la que se encuentre el usuario.

### Sistema de Notificaciones (Toasts)

Se ha migrado del sistema de `ScaffoldMessenger` a un sistema de notificaciones enriquecidas con `toastification`, optimizado para la estética premium de Hookahub.

1. **Implementación de `AppToast` (Custom Widget)**:
   - Se utiliza `toastification.showCustom()` para tener control total sobre el widget renderizado (`_AppToastWidget`).
   - **Regla Estética**: Queda prohibido el uso de sombras (`boxShadow`), bordes con degradados, barras laterales de acento o indicadores de arrastre (puntos). El diseño debe ser plano, limpio y con bordes sólidos.
   - **Identificación por Tipo**: La distinción entre Éxito, Error e Información se realiza mediante:
     - El color del borde sólido (procedente de `constants.dart`).
     - El icono circular tintado.
     - Un "label" de tipo en mayúsculas con el color de acento correspondiente.
2. **Gestión de Colores y Contraste**:
   - Para garantizar la legibilidad en ambos temas, se utiliza `Color.alphaBlend` para mezclar el color de acento con el fondo de superficie (`surfaceDark` o `surfaceLight`), creando un color de fondo opaco y suave que no compromete el contraste del texto.
   - **Modernización**: Se debe preferir el uso de `.withValues(alpha: X)` sobre `.withOpacity(X)` para cumplir con las directrices actuales de Flutter.

### Gestión de Temas (Claro, Oscuro, Sistema), SegmentedButton y Botón Cíclico

- **Problema**: El uso de un `Switch` binario limita la personalización a forzar claro u oscuro, impidiendo que la app se sincronice automáticamente con el brillo del sistema operativo del usuario. Además, en pantallas de Login o espacios reducidos, un selector complejo satura la interfaz, y en pantallas pequeñas o con tamaños de texto aumentados (accesibilidad), componentes horizontales como `SegmentedButton` pueden desbordar (_RenderFlex overflow_).
- **Solución Arquitectónica**:
  1. **ThemeProvider (`ThemeMode`)**: Maneja el enum nativo `ThemeMode` (`system`, `light`, `dark`), persistiendo el valor como `String` en `SharedPreferences` con retrocompatibilidad para booleanos previos.
  2. **Detección Efectiva de Brillo**: Para componentes globales (ej. `AnnotatedRegion<SystemUiOverlayStyle>` en `MaterialApp.builder`) o colores de formularios (`PastelTextField`), la evaluación del brillo debe hacerse mediante `Theme.of(context).brightness == Brightness.dark` en lugar de comparar estrictamente contra `ThemeMode.dark`, asegurando que el modo del sistema refleje el estilo visual y barra de estado correctos.
  3. **SegmentedButton Resistente a Overflows (Pantalla de Ajustes)**:
     - Configurar `showSelectedIcon: false` para evitar que el checkmark desplace o reduzca el espacio horizontal útil.
     - Envolver las etiquetas de texto en `FittedBox(fit: BoxFit.scaleDown)` con `maxLines: 1` y `overflow: TextOverflow.ellipsis` para garantizar escalabilidad limpia bajo cualquier escala de fuente.
  4. **Selector Cíclico Compacto (Pantalla de Login / Auth)**:
     - En pantallas de autenticación o con espacio reducido en el `AppBar`, sustituir switches o botones anchos por un `IconButton` que cicla ordenadamente entre los 3 modos (**Sistema ➔ Claro ➔ Oscuro ➔ Sistema**), mostrando dinámicamente el icono del estado activo (`Icons.brightness_auto`, `Icons.light_mode`, `Icons.dark_mode`).

## 🔄 Arquitectura de Datos y Sincronización

### Estadísticas Globales en Tiempo Real (La "Bala de Plata")

- **Problema**: Realizar operaciones `COUNT(*)` sobre tablas grandes (ej. tabacos, mezclas, usuarios) cada vez que el usuario navega a "Home" o refresca la pantalla destruye el rendimiento de la base de datos y consume excesiva cuota de lectura, pero al mismo tiempo se desea mostrar las métricas completamente actualizadas al milisegundo de toda la comunidad.
- **Solución Arquitectónica**:
  1. **En Supabase (Backend)**: En lugar de contar, se delega la tarea a una tabla central (`app_statistics` con un único registro `id=1`). Se crean **Triggers de PostgreSQL** en cada tabla implicada (`tobaccos`, `mixes`, `profiles`) que, ante cualquier `INSERT` o `DELETE`, suman o restan automáticamente a la cuenta correspondiente en `app_statistics`.
  2. **En Flutter (Frontend)**: En lugar de hacer múltiples peticiones manuales o refrescos (pull-to-refresh forzados), se utiliza **Supabase Realtime** mediante `supabase.from('app_statistics').stream(...)`. El `Provider` (ej. `HomeStatsProvider`) se suscribe a este `Stream` y actualiza la interfaz reactivamente. Esto reduce el coste de red y CPU al mínimo indispensable (1 sola lectura inicial seguida de suscripción websocket a una fila estática), escalando perfectamente a millones de usuarios a la vez que proporciona una experiencia mágica y en vivo.

### Condición de Carrera en Carga de Perfil (Lazy Loading vs Warm-up)

- **Problema**: En la pestaña de Comunidad, las tarjetas de mezclas no mostraban las opciones de edición/borrado porque el `ProfileProvider` cargaba los datos del usuario de forma perezosa (_lazy loading_) solo al entrar a la pestaña de Perfil. Si se visitaba Comunidad primero, el ID de usuario era `null` y la comprobación de autoría fallaba.
- **Solución (Warm-up)**: Los datos que determinan "permisos" o "propiedad" a lo largo de toda la aplicación deben precargarse proactivamente. Se implementó una carga temprana (_warm-up_) en el `initState` del `MainNavigationPage` (usando `WidgetsBinding.instance.addPostFrameCallback`) para forzar la inicialización de `ProfileProvider` y `FavoritesProvider` al montar la navegación, asegurando que el estado sea consistente globalmente sin importar qué pestaña se visite primero.

### Gestión de Suscripciones y Prevención de Fugas de Memoria (Lifecycle & dispose)

- **Problema**: Declarar métodos de ciclo de vida (`dispose`) de forma anidada dentro de métodos o bloques condicionales (en lugar de como método miembro de clase) impide que `ChangeNotifier.dispose()` sea sobrescrito. Si el provider se suscribe a Streams de singletons o servicios globales (ej. `DatabaseHealthProvider.instance.onReconnected`), la suscripción nunca se cancela, reteniendo la instancia del provider en memoria de por vida (Memory Leak) y provocando excepciones de `notifyListeners()` sobre objetos destruidos.
- **Solución (Regla de Oro)**:
  - Todo `ChangeNotifier` o `StatefulWidget` que mantenga suscripciones a `Stream`, controladores o temporizadores (`Timer`) **debe** sobrescribir explícitamente `@override void dispose()` a nivel de clase.
  - Cancelar todas las suscripciones (`_sub?.cancel()`), cerrar controladores y siempre invocar `super.dispose()` al final.

### Resiliencia de WebSockets Realtime ante Suspensión Móvil (AppLifecycleListener)

- **Problema**: Cuando el usuario minimiza la aplicación o el dispositivo entra en modo reposo (Doze Mode en Android / Suspensión de sockets en iOS), el socket TCP de Supabase Realtime se desconecta o congela. Las notificaciones o eventos que ocurran mientras la app está minimizada nunca llegan por el stream, dejando la interfaz desactualizada al regresar.
- **Solución (Regla de Oro)**:
  1. En providers que dependan de WebSockets in-app (como `NotificationsProvider`), registrar un `AppLifecycleListener` escuchando `onResume: () => ...`.
  2. Al reanudarse la app (`AppLifecycleState.resumed`), disparar inmediatamente una consulta REST de sincronización (`loadNotifications(refresh: true)`) y renovar la suscripción al canal si fue cerrada por el sistema operativo.
  3. Desregistrar siempre el listener en el método `dispose()` (`_lifecycleListener?.dispose()`).

### Ciclo de Vida de Controladores en Pantallas de Auth y Listas Dinámicas (Regla de Oro)

- **Problema 1 (Pantallas de Autenticación / Formularios)**: En pantallas como `LoginPage`, los controladores instanciados en el estado (`_emailController`, `_passwordController`) retienen conexiones con el subsistema de texto del framework. Si el usuario inicia sesión y la pantalla es reemplazada (`Navigator.pushReplacement`), no implementar `dispose()` en el `State` deja estos controladores anclados en memoria, fugando recursos en cada flujo de login/logout.
- **Solución**: Todo `StatefulWidget` con `TextEditingController` o `FocusNode` locales **debe** implementar `@override void dispose()` llamando a `.dispose()` en cada instancia antes de `super.dispose()`.
- **Problema 2 (Objetos y Listas Dinámicas con Controladores)**: Cuando una vista administra colecciones dinámicas cuyos elementos encapsulan un `TextEditingController` (ej. `_SelectedIngredient.percentCtrl` en `CreateMixPage`), eliminar elementos con `removeWhere` o vaciar la colección con `clear()` deja los controladores huérfanos sin llamar a `.dispose()`.
- **Solución**:
  1. Las clases auxiliares que encapsulen un controlador deben proveer un método `dispose()` propio (respetando encapsulamiento).
  2. Al eliminar elementos de la lista (`removeWhere`), se debe ejecutar `.dispose()` sobre la instancia coincidente antes de removerla.
  3. Antes de llamar a `list.clear()`, se debe iterar sobre los elementos existentes y llamar a `.dispose()`.
  4. En el `dispose()` del widget padre, delegar la destrucción llamando a `item.dispose()` en cada elemento de la colección.

### Prohibición de ScrollController en Providers Globales (Regla de Oro)

- **Problema**: Instanciar un `ScrollController` dentro de un `ChangeNotifier`/`Provider` global (como `CatalogProvider` registrado en el `MultiProvider` raíz de `app.dart`):
  1. Rompe Clean Architecture al acoplar la capa de estado con componentes de presentación (`flutter/widgets.dart`).
  2. Genera una **fuga de memoria crítica (Memory Leak)**: al ser un provider singleton de raíz, su método `dispose()` nunca se ejecuta, reteniendo indefinidamente `ScrollPosition`, tamaños del viewport y closures.
  3. Lanza la excepción en tiempo de ejecución: `ScrollController attached to multiple scroll views` si la vista es reconstruida o transicionada antes de liberar la posición previa.
- **Solución Arquitectónica**:
  1. **La Vista Posee el Controlador**: El `ScrollController` debe pertenecer **estrictamente** al `State` de un `StatefulWidget` (ej. `_CatalogPageState`), instanciándolo en el estado y liberándolo obligatoriamente en `dispose()`.
  2. **Detección de Paginación en UI**: El listener de scroll (`_onScroll`) debe residir en la vista, invocando los métodos del provider (`context.read<T>().loadMore()`) cuando la posición alcance el umbral de carga.
  3. **Delegación Desacoplada para Acciones Externas (ej. scrollToTop)**: Si un componente externo (como la barra de navegación en `main_navigation.dart`) necesita ordenar un scroll al inicio, el provider **no debe** contener controladores. En su lugar, debe exponer un callback delegado `VoidCallback? onScrollToTopRequested`. La vista lo suscribe en `didChangeDependencies()` y lo limpia a `null` en `dispose()`.
  4. **Protección `_isDisposed` en Providers Asíncronos**: Para evitar la excepción `A <Provider> was used after being disposed` provocada por llamadas asíncronas no esperadas que resuelven tras la destrucción del provider, se debe implementar una bandera `bool _isDisposed = false` y sobrescribir `@override void notifyListeners()` para ignorar notificaciones una vez que `_isDisposed == true`.

### Guarda `if (!mounted) return;` Obligatoria en Listeners de Scroll (Regla de Oro)

- **Problema**: Los métodos `_onScroll` vinculados a un `ScrollController.addListener()` se ejecutan activados por la inercia del motor de renderizado. Si el usuario abandona la pantalla haciendo pop mientras el scroll sigue rodando por inercia, el callback `_onScroll` se dispara después de que el widget haya sido desmontado del árbol. Ejecutar `context.read<T>()` en ese punto lanza la excepción fatal: `FlutterError: Looking up a deactivated widget's ancestor is unsafe`.
- **Solución**: Todo método listener registrado en un `ScrollController` **debe** incluir al inicio de su cuerpo una guarda temprana:
  ```dart
  void _onScroll() {
    if (!mounted) return;
    // ... lectura de controlador y provider seguros
  }
  ```

### Límite en Streams Realtime de Supabase (.limit) para Protección de Memoria (Regla de Oro)

- **Problema**: Invocar `.stream(primaryKey: ['id']).eq(...)` en Supabase Flutter sin limitar la consulta descarga el **snapshot completo** de la tabla para ese usuario. Al encadenar transformadores como `.expand()`, cada nuevo evento retransmite y deserializa la lista histórica completa, colapsando el heap de Dart y saturando el canal WebSocket en usuarios activos con cientos de registros.
- **Solución**: Todo stream de eventos continuos en tiempo real sobre tablas históricas (ej. `notifications`) debe acotarse con `.limit(N)` (ej. `.limit(20)`) o estructurarse mediante canales de difusión específicos (`onPostgresChanges(event: PostgresChangeEvent.insert)`), descargando el historial antiguo de forma paginada y bajo demanda mediante peticiones REST puntuales (`fetch`).

### Cancelación de Suscripciones Realtime y Purga de Estado en Logout/Login (Regla de Oro)

- **Problema**: Los providers registrados en el `MultiProvider` raíz (`app.dart`) son singletons de larga duración que persisten incluso tras el cierre de sesión (`signOut()`). Si un provider mantiene un `StreamSubscription` a canales Realtime de Supabase (ej. `NotificationsProvider` escuchando la tabla `notifications` para el `user_id` del usuario) o datos en memoria (`UserMixesProvider`, `HistoryProvider`, `ProfileProvider`):
  1. La conexión WebSocket Realtime permanece abierta en segundo plano consumiendo ancho de banda, batería y generando reconexiones fallidas con tokens expirados.
  2. Al iniciar sesión otro usuario, se produce fuga de datos cruzada en memoria (_data leak_) hasta que se completen nuevas peticiones.
  3. Si la app arranca sin sesión, el stream retorna vacío y nunca vuelve a re-suscribirse tras el Login.
- **Solución Arquitectónica**:
  1. **AuthProvider como emisor de ciclo de vida**: `AuthProvider` expone `addSignInListener` / `removeSignInListener` y `addSignOutListener` / `removeSignOutListener`, disparándolos ante cambios en `onAuthStateChange` y en `signOut()`.
  2. **Inyección de AuthProvider**: Los providers dependientes reciben `AuthProvider? auth` en su constructor, registrando sus handlers (`auth?.addSignOutListener(clear)` o `cancelSubscriptionsAndClear()`, y `auth?.addSignInListener(onUserAuthenticated)`).
  3. **Métodos `clear()` / `cancelSubscriptionsAndClear()` obligatorios**:
     - Cancelar explícitamente `_realtimeSubscription?.cancel()` y asignarlo a `null`.
     - Purgar todas las colecciones en memoria (`_notifications = []`, `_mixes = []`, `_entries = []`, `_profile = null`).
     - Resetear indicadores (`unreadCount = 0`, `isLoaded = false`, etc.) y notificar a los listeners.
  4. **Protección en Reconexión**: Los listeners de reconexión (`DatabaseHealthProvider.instance.onReconnected`) deben condicionar cualquier `fetch` o re-suscripción a la existencia de un usuario activo (`hasActiveUser`).
  5. **Limpieza en `dispose()`**: Siempre desregistrar los listeners de `AuthProvider` en el `@override void dispose()`.

### Aislamiento Multi-Usuario y Sincronización Nube-Caché en Favoritos (Regla de Oro)

- **Problema**: Guardar colecciones de usuario como favoritos y Top 5 en `SharedPreferences` con claves fijas genéricas (`favorites_mixes` y `top5_mix_ids`) provoca una **fuga de datos cruzada crítica** entre cuentas: si el Usuario A cierra sesión y el Usuario B inicia sesión en el mismo dispositivo, el Usuario B ve y puede modificar los favoritos y el Top 5 del Usuario A. Además, si el provider no escucha los eventos `signOut()` de `AuthProvider`, el estado en memoria nunca se purga.
- **Solución Arquitectónica (Híbrida Nube + Offline-First)**:
  1. **Persistencia Centralizada en Supabase**: Los favoritos y el Top 5 se persisten en la tabla remota `public.favorites` (`user_id`, `mix_id`, `is_top5`) protegida por RLS (`(select auth.uid()) = user_id`).
  2. **Aislamiento Estricto en Caché Local**: `SharedPreferences` se utiliza exclusivamente como capa de caché offline-first con claves parametrizadas por identidad: `favorites_mixes_${userId}` y `top5_mix_ids_${userId}` (usando sufijo `_guest` para sesiones sin autenticar).
  3. **Migración Transparente**: Al iniciar sesión, si la tabla remota no tiene datos pero el dispositivo conserva registros en las claves legacy (`favorites_mixes`), el repositorio migra automáticamente los datos a Supabase y purga la clave legacy para evitar inconsistencias y prevenir la pérdida de datos del usuario existente.
  4. **Reactividad al Ciclo de Vida de Autenticación**: `FavoritesProvider` recibe `AuthProvider? auth`, registra listeners para `addSignOutListener` (que purga `_favorites = []`, `_top5Ids = []`, `_loaded = false` y notifica a la UI) y `addSignInListener` (que recarga los datos del nuevo usuario), y los desregistra obligatoriamente en `dispose()`.

## 🧭 Navegación y Diálogos

### Gestión de Diálogos en Navegadores Anidados (Root Navigator)

- **Problema**: Al mostrar un diálogo de carga global (ej. `showDialog` que por defecto usa el `rootNavigator`) desde una pantalla anidada en un sistema de pestañas (como un `BottomNavigationBar` u otra navegación paralela), al intentar cerrarlo tras finalizar la operación con `Navigator.of(context).pop()`, la aplicación se queda bloqueada con el spinner congelado. Esto ocurre porque Flutter intenta cerrar el diálogo usando el navegador local de la pestaña activa en lugar del navegador raíz que lo originó.
- **Solución**: Siempre que se cierre programáticamente un diálogo o _bottom sheet_ global invocado desde una vista anidada, es **obligatorio** especificar explícitamente el uso del navegador raíz:
  - ❌ **Incorrecto**: `Navigator.of(context).pop();`
  - ✅ **Correcto**: `Navigator.of(context, rootNavigator: true).pop();`

## 🐛 Depuración y Herramientas (Tooling)

### Desconexión Repentina del Debugger de Flutter

- **Problema**: Al lanzar la aplicación en modo debug (ej. usando Antigravity o VS Code con el flag `--machine`), la aplicación arranca y es completamente usable en el dispositivo, pero el debugger se detiene de forma abrupta, deja de mostrar logs y se pierde el Hot Reload.
- **Causa Principal**: El uso de paquetes de logs (como `logger`) configurados con colores (`colors: true`). Los códigos de escape ANSI generados para pintar colores en la terminal interfieren y corrompen el flujo JSON estructurado del protocolo `--machine`. Al fallar el parseo de este JSON, la herramienta de depuración colapsa.
- **Solución (Logging)**: Asegurarse de que el logger centralizado (`AppLogger`) tenga desactivados los colores (`colors: false`) en su `Printer` base.

### Permisos de Red Local para Depuración en iOS Físico

- **Problema**: En iOS 14 y superior, si Flutter no puede conectarse al dispositivo físico mediante mDNS, la aplicación se instalará pero el depurador no podrá acoplarse y eventualmente la conexión caducará (timeout).
- **Solución**: Es mandatorio incluir en el archivo `ios/Runner/Info.plist` las políticas de uso de red local:
  ```xml
  <key>NSBonjourServices</key>
  <array>
      <string>_dartobservatory._tcp</string>
  </array>
  <key>NSLocalNetworkUsageDescription</key>
  <string>Permitir depuración de Flutter en la red local.</string>
  ```

## 📱 Sistema y Status Bar (iOS / Android)

### Visibilidad de la Barra de Estado Oculta en iOS

- **Problema**: En iOS, la barra de estado superior (hora, nivel de batería, wifi, etc.) no aparece en ninguna parte de la aplicación (la pantalla se comporta como si estuviera en modo "pantalla completa" o inmersivo).
- **Causa Principal**: La propiedad `<key>UIStatusBarHidden</key>` está configurada a `<true/>` de forma estática en el archivo `ios/Runner/Info.plist`.
- **Solución (Nativa)**: Asegurarse de que en `ios/Runner/Info.plist` la clave `UIStatusBarHidden` tenga valor `<false/>`. **Cualquier cambio en este archivo requiere detener por completo la app y recompilar desde Xcode o línea de comandos; el Hot Reload no sirve.**

### Consistencia del Color de la Barra de Estado con el Tema Activo

- **Problema**: Incluso si la barra es visible nativamente, cuando la aplicación implementa pantallas que no tienen un `AppBar` clásico (ej. layouts personalizados con `SafeArea`), el texto de la barra de estado puede tomar el color por defecto (ej. negro) y resultar ilegible si el usuario tiene activado el tema oscuro (fondo oscuro).
- **Solución (Arquitectónica Global)**:
  1. **Configuración en Tema**: Incluir siempre el bloque `appBarTheme` en `ThemeData` dentro del archivo de temas (ej. `lib/core/theme.dart`), forzando `systemOverlayStyle: SystemUiOverlayStyle.dark` en el tema claro, y `SystemUiOverlayStyle.light` en el tema oscuro.
  2. **Envoltorio en la Raíz**: Para asegurar que el color de la barra aplique en toda la app reactivamente y sobre pantallas personalizadas, es imperativo envolver el contenido del `builder` del `MaterialApp` (ej. en `lib/app.dart`) dentro de un `AnnotatedRegion<SystemUiOverlayStyle>` dinámico.

## ⚡ Rendimiento de Renderizado y Rebuilds Granulares

### Optimización en Listas y Vistas Complejas (`context.select` vs `context.watch`)

- **Problema**: En vistas complejas con listas (ej. `CommunityPage`, `FavoritesPage`, `UserMixesPage`), el uso de `context.watch<Provider>()` dentro del `itemBuilder` de un `ListView` o `SliverChildBuilderDelegate` suscribe cada elemento individual a la totalidad del estado del provider. Cuando se modifica el estado de un único elemento (ej. pulsar "favorito"), o cuando se produce un cambio en cualquier propiedad ajena del provider, **todas las tarjetas visibles en el viewport se reconstruyen por completo**, generando caída de fotogramas (_jank_) y desperdicio de CPU/GPU. Asimismo, envolver pantallas completas en un único `Consumer<T>` monolítico provoca que cambios menores (como un flag de paginación `isLoadingMore`) invaliden cabeceras y filtros estáticos.
- **Solución Arquitectónica (Regla de Oro)**:
  1. **Selectores Booleanos Granulares**: Dentro de elementos de lista o tarjetas, está **estrictamente prohibido** usar `context.watch<T>()`. Se debe utilizar `context.select<T, bool>((p) => ...)` devolviendo un valor primitivo univariante (ej. booleanos como `isFavorite` o `isOwned`). El motor de Provider solo invalidará el widget si el valor retornado por el selector cambia tras evaluar la igualdad por valor (`==`).
     - ❌ **Incorrecto**:
       ```dart
       final fav = context.watch<FavoritesProvider>();
       final isFav = fav.favorites.any((x) => x.id == mix.id);
       ```
     - ✅ **Correcto**:
       ```dart
       final isFav = context.select<FavoritesProvider, bool>(
         (fav) => fav.favorites.any((x) => x.id == mix.id),
       );
       ```
  2. **Desacoplamiento de Eventos con `context.read<T>`**:
     - Las acciones disparadas por interacción del usuario (`onTap`, `onFavoriteTap`, `onEdit`, `onDelete`) **nunca** deben depender de instancias observadas con `watch`. Se debe utilizar siempre `context.read<T>()` dentro del cuerpo de la función de callback.
  3. **Aislamiento en Widgets Dedicados**:
     - Evitar métodos de construcción imperativos como `_buildMixCard()`. Extraer cada elemento a un `StatelessWidget` dedicado (ej. `_CommunityMixItem`) para que el `BuildContext` del ítem esté estrictamente aislado del contenedor de la lista.
  4. **Descomposición de `Consumer` Monolíticos**:
     - En pantallas con scroll y cabeceras de filtros, no envolver el `Scaffold.body` en un único `Consumer`. Dividir en slivers y widgets independientes que escuchen exclusivamente su subconjunto de datos (ej. un `_CommunityFooter` suscrito únicamente a `isLoadingMore`, y una barra de filtros suscrita solo a `filterState`).
  5. **Uso Seguro de `context.select` en Listas (`widget is! SliverWithKeepAliveWidget`)**:
     - En `ListView.builder`, `ListView.separated`, `SliverList` o `GridView`, el `BuildContext` entregado directamente en `itemBuilder: (context, index)` pertenece al elemento contenedor del sliver (`SliverWithKeepAliveWidget`). Si se llama a `context.select` directamente sobre dicho `context`, Provider lanza la excepción de aserción:
       ```
       _AssertionError: Failed assertion: line 251 pos 12: 'widget is! SliverWithKeepAliveWidget'
       Tried to use context.select inside a SliverList/SliderGridView.
       ```
     - **Regla Estricta**: Para utilizar `context.select` dentro de un `itemBuilder`, es **obligatorio** extraer el contenido del elemento a un `StatelessWidget` dedicado (ej. `_SearchMixItem`, `_CommunityMixItem`, `_UserMixItem`) o envolver el retorno en un `Builder(builder: (context) { ... })` para proveer un `BuildContext` hijo aislado.

## ⚡ Manejo Seguro de Asincronía y Ciclo de Vida (`use_build_context_synchronously`)

### Async Gaps y Guardas con `context.mounted` (Regla de Oro)

- **Problema**: Cuando una operación asíncrona (`await`) se ejecuta (ej. peticiones a Supabase, `Future.delayed`, login, navegación), el hilo cede el control. Si el usuario sale de la pantalla durante ese tiempo y luego el código invoca `context` (en `Navigator`, `AppToast`, o `context.read<T>()`), Flutter lanza la excepción:
  `Unhandled Exception: Looking up a deactivated widget's ancestor is unsafe`.
  Asimismo, en Flutter 3.7+, si una función o closure recibe `BuildContext context` como argumento (o en el método `build`), comprobar únicamente `if (!mounted) return;` genera la advertencia estática `unrelated 'mounted' check`, ya que `this.mounted` pertenece a la clase `State` y no garantiza que el `BuildContext` local específico siga montado.
- **Solución Arquitectónica**:
  1. **Guarda obligatoria con `context.mounted`**: Tras cualquier `await`, siempre se debe verificar el montaje del contexto antes de consumirlo:
     ```dart
     final result = await _repository.fetchData();
     if (!context.mounted) return;
     AppToast.showSuccess(context, 'Operación exitosa');
     ```
  2. **Combinación en `StatefulWidget`**: Si tras el `await` se actualiza el estado local mediante `setState` Y además se utiliza el contexto, la guarda recomendada es:
     ```dart
     if (!mounted || !context.mounted) return;
     setState(() => _isLoading = false);
     Navigator.of(context).pop();
     ```
  3. **Callbacks en `initState` (`Future.microtask`)**: En inicializaciones diferidas, nunca se debe leer el contexto directamente sin proteger la ejecución:
     ```dart
     Future.microtask(() {
       if (!mounted) return;
       final provider = context.read<MyProvider>();
       if (!provider.isLoaded) provider.load();
     });
     ```
  4. **Defensa en Profundidad en Utilidades Globales**: Componentes utilitarios globales que reciben un `BuildContext` (ej. `AppToast._show`) deben incorporar su propia guarda defensiva (`if (!context.mounted) return;`) al inicio, evitando que errores de invocación de terceros crasheen la app.

### Timeouts Obligatorios en Repositorios Supabase y Prevención de Spinners Perpetuos (Regla de Oro)

- **Problema**: En conexiones móviles inestables (conmutación Wi-Fi a 4G/5G, pérdida de paquetes o latencia infinita), el cliente HTTP/PostgREST de Supabase puede dejar el socket abierto indefinidamente si no se configura un tiempo límite de expiración. Cuando un `Provider` inicia una carga (`_isLoading = true`) y espera un `Future` sin timeout, la ejecución nunca completa ni lanza excepción. Como consecuencia, los bloques `catch` y `finally` jamás se ejecutan, dejando la interfaz de usuario bloqueada en un spinner de carga perpetuo. Además, silenciar excepciones en el repositorio devolviendo listas vacías (`catch (e) { return []; }`) enmascara el fallo de red, engaña al provider y bloquea el reporte a `DatabaseHealthProvider`.
- **Solución Arquitectónica (Regla de Oro)**:
  1. **Constantes Centralizadas (Cero Magic Numbers)**:
     - Definir las duraciones en `lib/core/constants.dart`:
       - `supabaseReadTimeout = Duration(seconds: 4)` para todas las operaciones de lectura (`select`, búsquedas, obtención por ID).
       - `supabaseWriteTimeout = Duration(seconds: 8)` para operaciones de mutación (`insert`, `update`, `delete`, subidas a Storage).
  2. **Aplicación Universal en la Capa Data**:
     - Toda consulta a Supabase en repositorios (`CommunityRepository`, `UserMixesRepository`, `ProfileRepository`, `TobaccoRepository`, etc.) debe encadenar `.timeout(supabaseReadTimeout)` o `.timeout(supabaseWriteTimeout)` sobre el `Future` de la petición.
  3. **Propagación Segura de Excepciones**:
     - Los repositorios **nunca** deben silenciar excepciones ni tragarlas con `catch (e) { return []; }`.
     - Si se captura para registrar el error, se debe registrar con `AppLogger.error('...', error: e, stackTrace: stackTrace)` y re-lanzar inmediatamente con `rethrow;`.
  4. **Coordinación con Mapeo de Errores y Salud de Base de Datos**:
     - `TimeoutException` es clasificada automáticamente por `DatabaseHealthProvider.isConnectionError` como un error de transporte (mostrando el banner global de conexión).
     - `AppErrorMapper.toSpanish` traduce `TimeoutException` a `'Tiempo de espera agotado. Revisa tu conexión a internet.'`.
     - El `Provider` ejecuta su bloque `finally { _isLoading = false; notifyListeners(); }`, cerrando el spinner y ofreciendo al usuario la opción de reintentar.

## 🏛️ Estados de Carga y Errores en UI (Sealed Classes vs Booleans Fragmentados)

### Migración a Clases Selladas con Dart 3 (Regla de Oro)

- **Problema**: El manejo de estados mediante múltiples booleanos y variables fragmentadas (`bool _isLoading`, `bool _isLoaded`, `String? _error`) genera espacios de estados imposibles e inconsistencias en memoria:
  1. `_isLoading == true` y `_error != null`: Ambigüedad para la UI (¿mostrar spinner o mensaje de error?).
  2. Hacks de sincronización como `if (isLoading && !isLoaded)` para distinguir primera carga de recargas.
  3. Pérdida silenciosa de excepciones al limpiar listas sin emitir un estado de fallo explícito.
  4. Falta de exhaustividad en tiempo de compilación: `if-else` frágiles no advierten si se agregan nuevos estados (`Reconnecting`, `Empty`, etc.).
- **Solución Arquitectónica (Dart 3 Sealed Classes)**:
  1. **Definición Inmutable**:
     ```dart
     sealed class FeatureState {
       const FeatureState();
     }
     class FeatureInitial extends FeatureState { const FeatureInitial(); }
     class FeatureLoading extends FeatureState { const FeatureLoading(); }
     class FeatureLoaded extends FeatureState {
       const FeatureLoaded({required this.data, this.isRefreshing = false});
       final List<Item> data;
       final bool isRefreshing;
     }
     class FeatureError extends FeatureState {
       const FeatureError(this.message);
       final String message;
     }
     ```
  2. **Única Fuente de Verdad en Provider**:
     - Sustituir los booleanos privados por `FeatureState _state = const FeatureInitial();`.
     - Exponer `FeatureState get state => _state;`.
     - Mantener getters de conveniencia transitorios/delegados (`bool get isLoading => _state is FeatureLoading;`, `bool get isLoaded => _state is FeatureLoaded;`, etc.) para evitar breaking changes en widgets periféricos y pruebas existentes.
  3. **Estandarización de Proveedores Paginados (`UserMixes`, `Catalog`, `Community`)**:
     - En proveedores con paginación (`loadMore`), las banderas de paginación (`isLoadingMore`, `hasMore`/`hasMoreData`) **deben residir dentro de la subclase `FeatureLoaded`**, eliminando banderas ortogonales en el provider:
     ```dart
     class FeatureLoaded extends FeatureState {
       const FeatureLoaded({
         required this.items,
         this.isLoadingMore = false,
         this.hasMore = true,
       });
       final List<Item> items;
       final bool isLoadingMore;
       final bool hasMore;
       FeatureLoaded copyWith({List<Item>? items, bool? isLoadingMore, bool? hasMore}) => ...;
     }
     ```
     - Durante la paginación, el provider permanece en `FeatureLoaded` con `isLoadingMore = true`, evitando que la UI parpadee o desmonte la lista actual.
  4. **Consumo Exhaustivo en UI con Switch Expressions**:
     - Eliminar cadenas `if-else` y evaluar `provider.state` con pattern matching nativo:
     ```dart
     return switch (provider.state) {
       FeatureInitial() || FeatureLoading() => const Center(child: CircularProgressIndicator()),
       FeatureError(:final message) => _buildErrorView(context, message),
       FeatureLoaded(:final items) when items.isEmpty => _buildEmptyView(context),
       FeatureLoaded(:final items) => _buildDataView(context, items),
     };
     ```
  5. **Propagación Segura de Errores**:
     - No silenciar excepciones con `catch(e) { return []; }` dentro de sub-métodos de búsqueda o carga. Permitir que la excepción burbujee hasta el método principal del provider para registrarla en `AppLogger.error()` y transitar limpiamente a `FeatureError`.
  6. **Proveedores Migrados y Validados con Tests de Transición**:
     - Todos los providers de la aplicación (`NotificationsProvider`, `HistoryProvider`, `UserMixesProvider`, `ProfileProvider`, `CatalogProvider`, `CommunityProvider`) implementan estrictamente esta arquitectura sellada, respaldados por sus suites `*_sealed_state_test.dart`.

## 🍏 Compilación en iOS y CocoaPods

### Error de "Target Integrity: The iOS deployment target is set to X, but the range of supported deployment target versions is 15.0 to..."

- **Problema**: Al compilar para un dispositivo físico o simulador en versiones modernas de Xcode (Xcode 16+), el compilador rechaza cualquier target con versión de despliegue inferior a iOS 15.0. Múltiples dependencias de CocoaPods tienen versiones mínimas heredadas (`9.0`, `12.0`, `13.0`, `14.0`), provocando el fallo del build con el error `Target Integrity (Xcode): The iOS deployment target 'IPHONEOS_DEPLOYMENT_TARGET' is set to...`.
- **Solución Arquitectónica (`ios/Podfile`)**:
  1. Fijar `platform :ios, '15.0'` en la parte superior del `Podfile`.
  2. Forzar que todos los pods dependientes eleven su `IPHONEOS_DEPLOYMENT_TARGET` a mínimo `15.0` en el bloque `post_install`:
     ```ruby
     post_install do |installer|
       installer.pods_project.targets.each do |target|
         flutter_additional_ios_build_settings(target)
         target.build_configurations.each do |config|
           if config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'].to_f < 15.0
             config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
           end
         end
       end
     end
     ```
  3. Ejecutar `pod install` dentro del directorio `ios/` para regenerar `Pods.xcodeproj` con los nuevos targets.

### Error PhaseScriptExecution por `CupertinoPageTransitionsBuilder` en Flutter 3.47+

- **Problema**: Tras actualizar a Flutter 3.47+ / Dart 3.13+, Xcode falla durante la fase `Run Script` (`kernel_snapshot_program`) con el error opaco:
  `Command PhaseScriptExecution failed with a nonzero exit code`
  Al inspeccionar la salida detallada de compilación de Dart, se revela el fallo subyacente:
  `Error: The method 'CupertinoPageTransitionsBuilder' isn't defined` / `Error: Not a constant expression`.
- **Causa**: `CupertinoPageTransitionsBuilder` fue refactorizado en Flutter 3.47 para dar soporte a gestos predictivos de retroceso en iOS, perdiendo compatibilidad con llamadas `const` o requiriendo imports específicos si se invoca fuera de las transiciones globales de página. Además, instanciar `pageTransitionsTheme` dentro de `Theme.copyWith()` para envolver componentes individuales (como `PopupMenuButton`) es un antipatrón redundante, pues los popups utilizan `popupMenuTheme` y no rutas de página (`PageRoute`).
- **Solución (Regla de Oro)**:
  1. Eliminar cualquier declaración innecesaria de `pageTransitionsTheme` en `Theme` widgets locales que solo estilizan menús emergentes o diálogos (como ocurría en `CatalogPage` y `CommunityPage`).
  2. Si se configuran transiciones de página a nivel global en `ThemeData` (`lib/core/theme.dart`), asegurarse de no usar `const` en builders que ya no posean constructores constantes en versiones recientes del SDK.

## 🚀 Migración y Resolución de Deprecaciones (Flutter 3.27+ & Dependencias Modernas)

### 1. Inicialización de Supabase (`publishableKey`)

- **Problema**: El parámetro `anonKey:` en `Supabase.initialize()` está marcado como `@Deprecated` en favor de `publishableKey:`.
- **Solución**: En `main.dart`, utilizar `await Supabase.initialize(url: url, publishableKey: anonKey)`. Esto sigue el estándar unificado de Supabase para clientes frontend.

### 2. Compartir Contenido con `share_plus` (v13+)

- **Problema**: La clase utilitaria estática `Share` y su método `Share.share(text)` están obsoletos.
- **Breaking Change en API v13+**: `SharePlus.instance.share` no acepta un `String` posicional simple, sino una instancia del objeto `ShareParams(text: ...)`.
- **Patrón Correcto**:

  ```dart
  // ✅ Correcto
  SharePlus.instance.share(ShareParams(text: 'Texto a compartir'));

  // ❌ Incorrecto (deprecado o error de tipos en v13+)
  Share.share('Texto a compartir');
  SharePlus.instance.share('Texto a compartir'); // Error de tipos: espera ShareParams
  ```

### 3. Serialización de Color en Flutter 3.27+ (`toARGB32`)

- **Problema**: El getter `Color.value` fue deprecado en Flutter 3.27+ para dar soporte a espacios de color Wide Gamut.
- **Solución**: Al serializar un `Color` a formato numérico entero (para base de datos o modelos JSON), utilizar `color.toARGB32()`. Para la deserialización, `Color(map['color'] as int)` sigue siendo completamente funcional y retrocompatible.

## 🏛️ Clean Architecture y Modularización por Features (Regla Estricta)

### Estructura Canónica de Tres Capas

- **Regla Estricta**: Toda funcionalidad dentro de `lib/features/<feature_name>/` debe estructurarse obligatoriamente bajo las tres capas de Clean Architecture:
  ```
  feature_name/
  ├── data/        # Data sources, repositorios de red o persistencia local (ej. SharedPreferences/Supabase)
  ├── domain/      # Contratos/interfaces abstractas (ej. FavoritesRepository), entidades puras y filtros
  └── presentation/# Páginas (UI Widgets), componentes visuales y Providers (ChangeNotifier)
  ```
- **Prohibición de Archivos en la Raíz de la Feature**: Ningún archivo `.dart` debe residir directamente en la raíz de una carpeta feature (ej. `features/favorites/favorites_page.dart` ❌). Las vistas y providers van en `presentation/`, los repositorios concretos en `data/`, y los contratos/modelos en `domain/`.
- **Inversión de Dependencias (DIP)**: Los providers en `presentation/` (ej. `FavoritesProvider`, `UserMixesProvider`) deben depender de la abstracción/interfaz definida en `domain/` (ej. `FavoritesRepository`), permitiendo desacoplamiento total y tests con mocks limpios.

### Prohibición de Archivos Huérfanos y Nombres de Clases Homónimas (Regla de Oro)

- **Problema**: Tras migrar o refactorizar una funcionalidad hacia la capa `presentation/` (ej. `features/community/presentation/community_page.dart`), dejar archivos antiguos en la raíz del módulo (ej. `features/community/community_page.dart`):
  1. Genera código muerto sin mantenimiento que infla el bundle y el coste de análisis estático.
  2. Crea **ambigüedad y colisión de símbolos en el IDE**: si ambos archivos declaran la misma clase (`class CommunityPage`), las herramientas de navegación y sugerencia automática de imports pueden enlazar la versión obsoleta de manera inadvertida, provocando regresiones silenciosas o pérdida de funcionalidades modernas.
  3. Desincroniza la documentación y rompe la consistencia del estándar de Clean Architecture.
- **Solución Arquitectónica (Regla de Oro)**:
  1. **Eliminación Atómica Inmediata**: Al mover o refactorizar cualquier vista o provider a `presentation/`, el archivo original debe eliminarse inmediatamente mediante `git rm`.
  2. **Prohibición de Nombres Duplicados**: Queda estrictamente prohibida la coexistencia de clases públicas con nombres idénticos dentro de una misma feature o módulo funcional.
  3. **Auditoría Documental**: Toda actualización de rutas debe propagarse de forma atómica a la documentación del repositorio (ej. `NAVIGATION_STRUCTURE.md` y guías de accesibilidad/estilo) y verificarse con `dart analyze` y `flutter test`.

## 🧠 Gestión de Memoria y Ciclo de Vida de Widgets (Memory Leaks)

### Prohibición Estricta de Instanciación de Controladores en `build()` (Regla de Oro)

- **Problema**: Instanciar controladores (`TextEditingController`, `ScrollController`, `AnimationController`, `PageController`, etc.) directamente dentro del método `build(BuildContext context)` provoca fugas de memoria críticas (*Memory Leaks*). Cada vez que la vista se reconstruye (por tecleo en cualquier campo, cambios de foco `FocusNode`, validaciones reactivas o cambios de tema), se aloja una nueva instancia en el Heap de Dart sin invocar `dispose()` sobre las anteriores. Esto acumula escuchadores nativos y genera alta presión sobre el Garbage Collector.
- **Regla Estricta**:
  1. **Declaración en el `State`**: Todo controlador debe declararse obligatoriamente como miembro del `State` de un `StatefulWidget` o gestionarse a través de un `ChangeNotifierProvider` si corresponde.
  2. **Liberación en `dispose()`**: Es **mandatorio** invocar `.dispose()` sobre cada controlador dentro del `@override void dispose()` de la clase `State`, antes de llamar a `super.dispose()`.
  3. **Actualización Reactiva de Valores**: Si el valor mostrado en el campo depende de un evento asíncrono o selector externo (como un `showDatePicker`), se debe actualizar la propiedad `.text` del controlador persistente (`_controller.text = ...`) dentro del `setState()` o callback correspondiente, en lugar de recrear el controlador.

### Optimización de Indicadores de Borde en Scroll (Aislamiento de Rebuilds con ValueNotifier)

- **Problema**: Utilizar `_controller.addListener(() => setState(() => _offset = _controller.offset))` para actualizar indicadores visuales periféricos (como degradados laterales/fades, sombras de cabecera o botones flotantes de scroll-to-top) ejecuta `setState()` en cada micro-desplazamiento de píxel a 60/120 fps. Esto fuerza la reconstrucción continua de todo el widget contenedor (`LayoutBuilder`, cálculos de dimensiones geométricas, lista/carrusel y todas las tarjetas hijas), provocando caída masiva de frames (*jank*) y consumo desmedido de CPU/batería para variables que sólo cambian de estado booleano en los límites de desplazamiento.
- **Solución Arquitectónica (Regla de Oro)**:
  1. **Prohibición de `setState()` en listeners de scroll**: No invocar jamás `setState()` dentro de un listener de `ScrollController` para renderizar efectos periféricos que dependan de umbrales discretos.
  2. **Uso de `ValueNotifier<bool>` reactivo atómico**: Utilizar notificadores primitivos (ej. `_showLeft`, `_showRight`) y mutar su valor **estrictamente cuando cambie el booleano**:
     ```dart
     final canScrollLeft = pos.pixels > 2;
     if (_showLeft.value != canScrollLeft) {
       _showLeft.value = canScrollLeft;
     }
     ```
     De este modo, se reducen los rebuilds de miles a solo 1 o 2 durante todo el recorrido del scroll.
  3. **Aislamiento de reconstrucción con `ValueListenableBuilder`**:
     - Mantener el `SingleChildScrollView` / `ListView` y sus hijos estáticos fuera del builder del notificador.
     - Envolver **únicamente** los indicadores visuales periféricos (ej. dentro de un `Positioned`) en `ValueListenableBuilder<bool>`.
     - Reutilizar la instancia gráfica pasando el `Container` o `Decoration` como argumento `child` del `ValueListenableBuilder`, evitando instanciar nuevos objetos gráficos en memoria:
     ```dart
     Positioned(
       left: 0,
       top: 0,
       bottom: 0,
       child: ValueListenableBuilder<bool>(
         valueListenable: _showLeft,
         builder: (context, show, child) {
           if (!show) return const SizedBox.shrink();
           return child!;
         },
         child: IgnorePointer(
           key: const Key('quick_access_fade_left'),
           child: Container(width: 24, decoration: ...),
         ),
       ),
     )
     ```
  4. **Ciclo de vida estricto**: Desregistrar el listener del controlador (`removeListener`) y liberar todos los `ValueNotifier` en `@override void dispose()`.

### Prohibición de `context.watch` en el Árbol Raíz de Pantallas Complejas (Granularización de Rebuilds)

- **Problema**: Declarar `final provider = context.watch<MyProvider>();` en el método `build()` del widget raíz de una pantalla compleja (ej. pantallas de listados, catálogos o dashboards de cientos de líneas):
  1. Suscribe indiscriminadamente todo el `BuildContext` de la pantalla a **cualquier** notificación de cambio (`notifyListeners()`).
  2. Cada evento asíncrono secundario (como carga en background de metadatos, inicio/fin de paginación `loadMore`, cambios en filtros o refresco de un único ítem con `updateItem`) destruye y reconstruye todo el árbol (`Scaffold`, `CustomScrollView`, appbars, selectores horizontales, grids enteros y footers).
  3. Causa caídas de framerate (*jank* o *micro-stuttering*) durante el scroll continuo y genera alta presión sobre el recolector de basura.
- **Solución Arquitectónica (Regla de Oro)**:
  1. **Raíz Estructural Pura**: El método `build()` raíz de una pantalla compleja no debe suscribirse al `Provider` completo. Para callbacks de acción como `RefreshIndicator.onRefresh` o disparadores de eventos, se debe usar `context.read<MyProvider>().action()`.
  2. **Descomposición en Sub-widgets Especializados**: Dividir la pantalla en componentes aislados (ej. `_SortFilterDropdown`, `_BrandFilterDropdown`, `_CatalogGridSliver`, `_EmptyStateSliver`, `_FooterSliver`).
  3. **Suscripción Atómica con `context.select` y `Selector`**:
     - Cada sub-widget debe escuchar únicamente la propiedad mínima necesaria para su renderizado:
       ```dart
       // ✅ Solo se reconstruye si cambia sortOption
       final sortOption = context.select<CatalogProvider, SortOption>((p) => p.filter.sortOption);
       ```
     - Para estados de carga/paginación compuestos, utilizar tuplas/records de Dart 3:
       ```dart
       // ✅ Solo se reconstruye el footer cuando conmuta el estado de paginación
       final (error, isLoading, hasMore) = context.select<CatalogProvider, (String?, bool, bool)>(
         (p) => (p.error, p.isLoading, p.hasMore),
       );
       ```
     - De esta forma, el scroll, los dropdowns y los slivers adyacentes permanecen inmunes y no se re-evalúan innecesariamente.

## 🛡️ Detección de Caídas de Conectividad y Healthcheck (DatabaseHealthProvider)

### Discriminación Estricta de Errores en `isConnectionError` (Regla de Oro)

- **Problema**: Clasificar genéricamente `AuthException` o `PostgrestException` como errores de conectividad (`isConnectionError(Object error)`) causa **falsos positivos críticos** en producción:
  1. Si un usuario introduce una contraseña incorrecta (`400 Bad Request` en GoTrue) o intenta registrarse con un email existente (`422 Unprocessable Entity`), `DatabaseHealthProvider.reportFailure(e)` interpreta la validación como una caída de red o de infraestructura.
  2. Ejecuta inmediatamente `_markDisconnectedImmediate()`, cambiando `_isConnected = false` y mostrando el banner rojo de "Base de datos desconectada" / estado offline ante un simple error de credenciales.
  3. De igual manera, excepciones de cliente en `PostgrestException` como violaciones de unicidad (`23505`), claves foráneas (`23503`), datos inválidos (`22P02`), permisos RLS (`42501`) o consultas vacías con `.single()` (`PGRST116`) desconectaban erróneamente toda la app.
- **Solución Arquitectónica (Regla de Oro)**:
  1. **Exclusión de Errores de Validación y Credenciales (`AuthException`)**:
     - Las respuestas HTTP 4xx de GoTrue (`400`, `401`, `422`, `429`) son respuestas válidas del servidor ante acciones del usuario, **nunca** caídas de infraestructura. Si ocurriera una caída de red en un flujo de autenticación, la capa de transporte lanzaría `SocketException`, `ClientException` o `TimeoutException`.
     - `AuthException` debe retornar siempre `false` en `isConnectionError`.
     - Asimismo, en `AuthProvider`, los bloques `on AuthException catch (e)` no deben invocar `DatabaseHealthProvider.reportFailure(e)`.
  2. **Discriminación SQLSTATE en `PostgrestException`**:
     - **Excluir (Errores de cliente / aplicación / restricciones)**:
       - Clase 23: Violación de restricciones de integridad (`23505`, `23503`, `23502`, `23514`).
       - Clase 22: Formato o tipos de datos de cliente (`22001`, `22P02`).
       - Clase 42: Sintaxis o políticas RLS (`42501`, `42703`, `42P01`).
       - Errores de cliente PostgREST: códigos que inician por `PGRST1` (ej. `PGRST116`) y `PGRST2`.
     - **Incluir (Auténticos fallos de infraestructura de base de datos)**:
       - Clase 08: Connection exceptions de PostgreSQL (`08000`, `08003`, `08006`, etc.).
       - Clase 57: Operator intervention / shutdown de PostgreSQL (`57P01`, `57P02`, `57P03`).
       - `53300`: Pool de conexiones agotado.
       - Mensajes explícitos de fallo de transporte (`connection refused`, `connection closed`, `network`, `timeout`, `socketexception`).
  3. **Reconocimiento de Transporte HTTP**:
     - Reconocer excepciones de transporte de red (`SocketException`, `TimeoutException`, `HttpException`, y `ClientException` de `package:http` o `failed host lookup`).

### Mapeo y Traducción Centralizada de Errores al Español (AppErrorMapper)

- **Problema**: Las excepciones emitidas por Supabase GoTrue (`AuthException`), PostgreSQL/PostgREST (`PostgrestException`) y la capa de transporte HTTP/Sockets devuelven mensajes en inglés en crudo (`Invalid login credentials`, `User already registered`, `duplicate key value violates unique constraint`, etc.). Exponer estas cadenas directamente a la interfaz (vía toasts, snackbars o interpolaciones `${e.toString()}`) degrada severamente la experiencia de usuario y expone detalles técnicos internos.
- **Solución Arquitectónica (Regla de Oro)**:
  1. **Utilidad Pura Centralizada**: Toda excepción de backend o transporte debe pasar obligatoriamente por `AppErrorMapper.toSpanish(error)` antes de presentarse en la UI.
  2. **Traducción Exhaustiva de Autenticación (`AuthException`)**:
     - Credenciales inválidas (`invalid_credentials` / `Invalid login credentials`) ➔ `'El correo o la contraseña son incorrectos.'`
     - Usuario duplicado (`user_already_exists` / `User already registered`) ➔ `'Ya existe una cuenta registrada con este correo electrónico.'`
     - Contraseña débil (`weak_password` / `Password should be at least...`) ➔ `'La contraseña debe tener al menos 6 caracteres.'`
     - Correo no confirmado (`email_not_confirmed`) ➔ `'Tu correo electrónico aún no ha sido confirmado. Revisa tu bandeja de entrada.'`
     - Límite de tasa (`over_request_rate_limit` / `rate limit`) ➔ `'Has superado el límite de intentos. Por favor, espera unos minutos antes de volver a intentarlo.'`
     - Formato inválido (`invalid_email` / `Unable to validate email`) ➔ `'El formato del correo electrónico no es válido.'`
  3. **Traducción Semántica de Base de Datos (`PostgrestException`)**:
     - Unicidad (`23505`) ➔ `'Ya existe un registro con estos datos.'`
     - Claves foráneas (`23503`) ➔ `'La operación no pudo completarse porque hace referencia a un elemento que no existe.'`
     - Campos obligatorios (`23502`) ➔ `'Por favor, completa todos los campos requeridos.'`
     - Reglas de validación (`23514`) ➔ `'Uno o más datos ingresados no cumplen con las reglas requeridas.'`
     - Permisos denegados / RLS (`42501`) ➔ `'No tienes permisos suficientes para realizar esta acción.'`
     - Registros no encontrados (`PGRST116`) ➔ `'No se encontró la información solicitada.'`
  4. **Protección contra Fuga de Trazas Técnicas**:
     - Excepciones no mapeadas nunca deben imprimir `e.toString()`; deben retornar un mensaje de respaldo amigable en español: `'Ha ocurrido un error inesperado. Por favor, inténtalo de nuevo.'`

## 🚪 Ciclo de Vida de Autenticación y Navegación Declarativa (AuthGate)

### Prohibición de `Navigator.pushAndRemoveUntil` en Tabs Anidados (Regla de Oro)

- **Problema**:
  1. En arquitecturas con pestañas y navegadores anidados (`MainNavigationPage` con múltiples `Navigator` en cada tab), invocar llamadas imperativas como `Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginPage()), ...)` desde una pantalla dentro de una pestaña (ej. `ProfilePage` en el tab 3) utiliza por defecto el `NavigatorState` local de ese tab.
  2. Esto anida `LoginPage` dentro del tab de Perfil, conservando en pantalla la barra de navegación superior (Header) y la inferior (BottomNavigationBar), permitiendo al usuario no autenticado seguir navegando a Home, Catálogo y Comunidad.
  3. De igual manera, ejecutar `Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainNavigationPage()))` al iniciar sesión en `LoginPage` rompe el flujo declarativo, montando una segunda instancia duplicada de `MainNavigationPage` en la pila del root navigator sobre `AuthGate`.

- **Solución Arquitectónica (Regla de Oro)**:
  1. **`AuthGate` como Única Fuente de la Verdad Declarativa**:
     - `AuthGate` debe escuchar reactivamente a `AuthProvider` (`Consumer<AuthProvider>`) y conmutar declarativamente entre `LoginPage` y `MainNavigationPage`.
     - El cambio se envuelve en un `AnimatedSwitcher` con claves explícitas (`ValueKey('main_nav')` vs `ValueKey('login_page')`). Al cambiar la clave, Flutter desmonta y destruye por completo el widget saliente y todos sus subárboles de estado/navegación.
  2. **Cierre de Sesión Limpio y Centralizado (`AuthGate` + `rootNavigatorKey`)**:
     - Al cerrar sesión o ante revocación de token/expiración por servidor (`_notifySignOut`), la limpieza de rutas modales, diálogos o pantallas apiladas en el navegador raíz se gestiona de forma centralizada en `AuthGate` (`_AuthSwitcher` escuchando a `AuthProvider.addSignOutListener` y ejecutando `rootNavigatorKey.currentState?.popUntil((r) => r.isFirst)`).
     - La vista (`ProfilePage`) queda completamente desacoplada de la navegación y únicamente ejecuta `await auth.signOut()`.
     - **Queda estrictamente prohibido** importar o instanciar `LoginPage` dentro de `ProfilePage`.
  3. **Inicio de Sesión Limpio (`LoginPage`)**:
     - Al autenticarse correctamente con correo/contraseña o Google, `AuthProvider` actualiza el estado interno a `_isAuthenticated = true` y ejecuta `notifyListeners()`.
     - **Queda estrictamente prohibido** llamar a `Navigator.pushReplacement` hacia `MainNavigationPage` dentro de `LoginPage`. La navegación ocurre de forma automática y reactiva a través de `AuthGate`.

### Estado de Carga y Prevención de Doble Envío / Spam en Formularios de Auth (Regla de Oro)

- **Problema**:
  1. En pantallas de autenticación (`LoginPage`), permitir que los botones de envío ("Iniciar sesión" o "Continuar con Google") permanezcan activos tras el tap sin un estado de carga provoca condiciones de carrera severas (*race conditions*). Si el usuario pulsa repetidas veces rápidamente por impaciencia, se envían múltiples peticiones concurrentes a Supabase Auth o al proveedor OAuth de Google.
  2. La ausencia de un spinner de carga genera incertidumbre en el usuario, incentivando el spam click.
  3. No deshabilitar el botón alternativo (ej. pulsar Google mientras se procesa login por correo) o permitir modificar los campos de texto (`PastelTextField`) y navegar hacia la pantalla de registro mientras la petición asíncrona está en vuelo provoca inconsistencias de estado.

- **Solución Arquitectónica (Regla de Oro)**:
  1. **Sealed Class para el Estado de Vista**: Modelar el estado de la pantalla mediante una clase sellada exhaustiva (`sealed class LoginState` con `LoginIdle`, `LoginEmailLoading`, `LoginGoogleLoading`) sin utilizar booleanos fragmentados.
  2. **Bloqueo Mutuo Global durante el Envío**:
     - Si la pantalla no se encuentra en reposo (`isSubmitting = _loginState is! LoginIdle`), ambos botones deben desactivarse inmediatamente pasando `onPressed: null`.
     - Los campos de texto se marcan como `readOnly: isSubmitting` y el botón de navegación a registro queda bloqueado (`onPressed: null`).
  3. **Feedback Visual Coherente**:
     - El botón de email sustituye su etiqueta de texto por un `CircularProgressIndicator` de tamaño 20x20 con `strokeWidth: 2`.
     - El componente `SocialLoginButton` recibe `isLoading: isGoogleLoading`, mostrando su spinner nativo y bloqueando cualquier gesto en `GestureDetector` (`onTapDown`/`onTapUp`).
  4. **Resiliencia con `try/finally` y comprobación de `mounted`**:
     - El restablecimiento a `LoginIdle` se realiza obligatoriamente en un bloque `finally` con la guarda `if (mounted) setState(...)`, asegurando que cancelaciones de Google o fallos de conexión rehabiliten la interfaz limpiamente sin provocar fugas o errores de ciclo de vida tras ser desmontada por `AuthGate`.

## 🚀 Preparación y Despliegue a Producción (Release Android & iOS)

### Permiso de INTERNET Obligatorio en `src/main/AndroidManifest.xml` (Regla Crítica)

- **Problema**: Flutter incluye por defecto `<uses-permission android:name="android.permission.INTERNET"/>` en las carpetas `android/app/src/debug/AndroidManifest.xml` y `android/app/src/profile/AndroidManifest.xml` para depuración. Sin embargo, al compilar el binario para release (`flutter build apk --release` o `flutter build appbundle`), Gradle **únicamente** toma como manifiesto base `android/app/src/main/AndroidManifest.xml`. Si no se declara explícitamente el permiso de INTERNET en `main`, la compilación final no tendrá acceso a la red y cualquier petición HTTP, WebSocket o consulta a Supabase fallará inmediatamente con `SocketException`.
- **Solución (Regla de Oro)**:
  - Declarar **siempre** `<uses-permission android:name="android.permission.INTERNET" />` como hijo directo de `<manifest>` en `android/app/src/main/AndroidManifest.xml`.

### Limpieza de Entradas de Depuración en `ios/Runner/Info.plist` para App Store

- **Problema**: Declaraciones como `NSBonjourServices` con `_dartobservatory._tcp` o `NSLocalNetworkUsageDescription` ("Permitir depuración de Flutter en la red local") son utilizadas por herramientas de depuración local. Si se envían a la Apple App Store en una compilación de producción, pueden activar alertas de permisos de red local innecesarias a los usuarios en iOS 14+ o provocar rechazos automáticos durante la revisión de Apple.
- **Solución (Regla de Oro)**:
  - Asegurar que `Info.plist` de producción prescinda de `NSBonjourServices` vinculados al `_dartobservatory` y descripciones de red local para depuración.

### Timeouts y Registro de Excepciones Estructuradas en Repositorios (Regla de Oro)

- **Problema**:
  1. Omitir `.timeout(supabaseReadTimeout)` o `.timeout(supabaseWriteTimeout)` en llamadas a Supabase permite que operaciones en segundo plano (ej. historial o notificaciones) cuelguen indefinidamente ante pérdidas de cobertura móvil.
  2. Llamar a `AppLogger.error('Error: $e')` interpolando el error en la cadena de texto deja los argumentos nombrados `error:` y `stackTrace:` en `null`, enviando registros vacíos en las columnas `error_details` y `stack_trace` de la tabla remota `app_logs`.
- **Solución (Regla de Oro)**:
  1. Toda consulta a Supabase **debe** llevar un `.timeout()` explícito.
  2. En bloques `catch (e, stackTrace)`, invocar siempre `AppLogger.error('Mensaje descriptivo', error: e, stackTrace: stackTrace)`.

## ⚖️ Lógica de Mezclas y Balanceo Dinámico de Porcentajes (MixPercentageCalculator)

### Reparto Equitativo al 100% y Preservación de Porcentajes Manuales (Regla de Oro)

- **Problema**:
  1. Al instanciar ingredientes en la pantalla de creación/edición de mezclas (`CreateMixPage`), inicializar el porcentaje con un valor fijo por defecto (ej. `25%`) provocaba que mezclas de 1, 2 o 3 tabacos tuvieran sumas incompletas (25%, 50%, 75%), obligando al usuario a editar manualmente cada campo para alcanzar el 100%.
  2. Al añadir o eliminar tabacos, no existía un mecanismo para redistribuir el porcentaje entre los tabacos existentes.
  3. No se distinguía si un porcentaje provenía de la asignación automática del sistema o había sido fijado explícitamente por el usuario (`isManual`).

- **Solución Arquitectónica (Regla de Oro)**:
  1. **Servicio Puro de Dominio (`MixPercentageCalculator`)**:
     - Desacoplado de widgets y controladores de Flutter mediante el contrato `MixPercentageItem` (`isManual`, `percentage`).
     - Al añadir (`_addIngredient`) o eliminar (`_removeIngredient`) tabacos, se ejecuta `MixPercentageCalculator.rebalance(ingredients)`.
  2. **Reglas del Algoritmo de Balanceo**:
     - **Preservación Estricta**: Si un ingrediente tiene `isManual == true`, su porcentaje permanece intacto y nunca se recalcula.
     - **Cálculo de Remanente**: Se calcula `remaining = 100.0 - suma_manuales`.
     - **Distribución de Restos Enteros (Largest Remainder Method)**: Si `remaining > 0`, se reparte `remaining ~/ count` de forma entera, y el residuo `remaining % count` se distribuye sumando 1% a los primeros elementos de la lista automática, garantizando que la suma total sea rigurosamente 100% sin decimales infinitos.
     - **Tolerancia a Over-allocation**: Si los ingredientes manuales suman 100% o más (`remaining <= 0`), los ingredientes automáticos se asignan a `0.0`, activando la alerta visual y bloqueando la creación hasta que el usuario corrija los valores manuales.
  3. **Activación de `isManual`**:
     - Únicamente se conmuta a `isManual = true` cuando el usuario interactúa directamente con el campo (`onChanged` del `_PercentField`) o cuando la mezcla se carga en modo edición desde la base de datos (`_loadExistingMix`).




### Cabeceras No Modulares en Frameworks iOS (google_mobile_ads y use_frameworks!)

- **Problema**: En iOS, al compilar con Xcode proyectos Flutter que usan `google_mobile_ads` y CocoaPods con `use_frameworks!`, el compilador Clang falla con el error:
  ```text
  Include of non-modular header inside framework module 'google_mobile_ads.FLTAd_Internal': '.../GoogleMobileAds.framework/PrivateHeaders/GoogleMobileAds_Beta.h'
  ```
- **Causa**: Clang impone límites estrictos entre módulos. `FLTAd_Internal.h` y `FLTAdPreloader.h` incluyen cabeceras privadas (`GoogleMobileAds_Beta.h`) de otro framework (`GoogleMobileAds`), lo que Clang prohíbe por defecto en módulos de framework.
- **Solución (Regla de Oro)**:
  1. En `ios/Podfile`, dentro de `post_install`, iterar sobre todos los targets y configurar `CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES = 'YES'`:
     ```ruby
     post_install do |installer|
       installer.pods_project.targets.each do |target|
         flutter_additional_ios_build_settings(target)
         target.build_configurations.each do |config|
           config.build_settings['CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES'] = 'YES'
           if config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'].to_f < 15.0
             config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
           end
         end
       end
     end
     ```
  2. En `ios/Flutter/Debug.xcconfig` y `ios/Flutter/Release.xcconfig`, añadir la línea:
     ```xcconfig
     CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES = YES
     ```
  3. Ejecutar `cd ios && pod install` para propagar los cambios a `Pods.xcodeproj`.

## 🔍 Búsqueda Predictiva y Autocompletado Instantáneo

### Arquitectura de Dos Niveles: Historial Local LIFO + Sugerencias Ligeras con Debounce

- **Problema**: Realizar búsquedas completas contra Supabase en cada pulsación de tecla (`onChanged`) satura el ancho de banda móvil, provoca bloqueos en el UI thread y genera carreras de peticiones (*race conditions*) desordenadas si una respuesta lenta llega después de una nueva consulta. Adicionalmente, el usuario espera recordar sus búsquedas recientes sin conexión y poder reutilizarlas o eliminarlas de forma fluida.
- **Solución Arquitectónica (Regla de Oro)**:
  1. **Desacoplamiento de Búsqueda Completa vs Sugerencias**:
     - `SearchProvider`: Responsable de ejecutar la búsqueda profunda (`fetchTobaccos`, `fetchMixes`) con todos sus metadatos y paginación para la pantalla de resultados `SearchResultsPage`.
     - `SearchSuggestionsProvider`: Responsable de la experiencia instantánea (historial local + autocompletado en vivo).
  2. **Persistencia Local con LIFO y Deduplicación Case-Insensitive**:
     - Implementar `SearchHistoryLocalDataSource` respaldado por `SharedPreferences`.
     - Limitar estrictamente a 8 términos. Al guardar un término, eliminar ocurrencias previas insensibles a mayúsculas/minúsculas y agregarlo al inicio (LIFO).
  3. **Debouncing (280ms) y Prevención de Carreras de Peticiones (`_latestRequestId`)**:
     - Toda consulta predictiva se difiere mediante `Timer(const Duration(milliseconds: 280), ...)`.
     - Cada emisión incrementa un contador secuencial `_latestRequestId`. Al completarse la petición de red, se valida `if (currentRequestId != _latestRequestId) return;`, descartando cualquier respuesta obsoleta generada por mecanografía rápida o retrasos de red.
  4. **Proyecciones Mínimas y Caché L1 en Memoria**:
     - Las sugerencias remotas solo solicitan columnas esenciales (`id, name, brand, image_url, rating` en tabacos; `id, name, rating, profiles, mix_components` en mezclas) limitadas a 4 registros por categoría.
     - `SearchSuggestionsRepository` mantiene un `Map<String, List<SearchSuggestion>>` en memoria (LRU de hasta 40 entradas) para que al retroceder caracteres (backspace) el autocompletado sea instantáneo (0ms).
  5. **Modelado Estricto de Estados (`SearchSuggestionsState`)**:
     - Implementar una `sealed class` con `SearchSuggestionsInitial`, `SearchSuggestionsLoading`, `SearchSuggestionsLoaded` y `SearchSuggestionsError`.
     - **Regla Estricta**: La propiedad `recentSearches: List<String>` debe ser obligatoria en la clase base sellada, garantizando que el historial reciente esté disponible ininterrumpidamente durante estados de carga o error sin parpadeos en pantalla.
  6. **Capa Visual en Stack (`SearchSuggestionsOverlay`) y Manejo de Teclado**:
     - En `MainNavigation`, montar `SearchSuggestionsOverlay` dentro del `body: Stack(...)` condicionado por `_isSearching`.
     - Configurar `CustomScrollView(keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag)` para ocultar el teclado suavemente al hacer scroll.
     - Integrar `PopScope` para que el botón de retroceso colapse el modo de búsqueda antes de cerrar la pantalla.
     - Ocultar `bottomNavigationBar` durante la búsqueda (`bottomNavigationBar: _isSearching ? null : Container(...)`) para maximizar el área visible de sugerencias sobre el teclado virtual.

## ❤️ Consistencia de Estado en Componentes Globales

### Integración Reactiva de Favoritos en Tarjetas de Mezclas (`MixCard`)

- **Problema**: Al mostrar tarjetas `MixCard` en pantallas secundarias o de agregación (ej. detalles de tabaco `TobaccoDetailPage`), dejar `isFavorite: false` con `TODO` o callbacks `onFavoriteTap` vacíos rompe la consistencia del estado de la aplicación, haciendo que el corazón aparezca desmarcado a pesar de que la mezcla esté guardada en la lista de favoritos del usuario.
- **Solución (Regla de Oro)**:
  1. **Vinculación Reactiva**: En cualquier pantalla que renderice listas de mezclas con `MixCard`, se debe vincular `isFavorite` reactivamente con `context.select<FavoritesProvider, bool>((fav) => fav.favorites.any((m) => m.id == mix.id))`.
  2. **Interacción Bidireccional**: En el callback `onFavoriteTap`, consultar `context.read<FavoritesProvider>()` y ejecutar `removeFavorite(mix.id)` o `addFavorite(mix)` según corresponda para reflejar cambios instantáneos y consistentes en toda la app.
  3. **Aislamiento de Rebuilds en Listas/Slivers**: Extraer un widget dedicado (ej. `_TobaccoMixCard` o `_MixItem`) como `StatelessWidget`. Esto aísla el scope de `context.select`, asegurando que al marcar o desmarcar una mezcla solo se reconstruya dicha tarjeta y no el sliver/listado completo.
  4. **Garantía de Inicialización**: Si la pantalla puede ser abierta directamente desde navegación externa o catálogo, asegurar en el `initState` que si `!favProvider.isLoaded && !favProvider.isLoading`, se invoque `favProvider.load()`.

## 🔔 Notificaciones Forward-Compatible y Defensa en Frontera

### Deserialización Defensiva, Adaptador de Presentación y Manejo Desacoplado de Acciones

- **Problema**: La emisión de nuevos tipos de notificación desde Supabase o el panel administrativo (ej. `general_announcement`, `feedback_response`, `system_maintenance`) generaba fallos silenciosos o crashes:
  1. Enums cerrados con fallback ciego a `reviewOnMyMix` que transformaba cualquier anuncio o respuesta en *"Alguien comentó en tu mezcla"*.
  2. Parseo rígido del JSONB `data` que asumía claves específicas de mezclas e ignoraba títulos y mensajes dinámicos enviados por el backend (`title`, `message`, `subject`, `body`).
  3. Violación de Clean Architecture al acoplar colores (`Colors.blue`) e iconos (`IconData`) fijos dentro del modelo de dominio.
  4. Falta de navegación/interacción al pulsar anuncios o respuestas de soporte (solo se mostraba un toast sin posibilidad de leer el contenido extenso).
- **Solución Arquitectónica (Regla de Oro)**:
  1. **Enum Tolerante (`NotificationType`)**:
     - Declarar un caso `unknown` con wireValue `'unknown'`.
     - Implementar `fromString` seguro que compare valores normalizados (`wireValue == normalized`) y garantice fallback a `NotificationType.unknown` sin lanzar jamás una excepción.
  2. **Value Object de Payload (`NotificationPayload`)**:
     - Deserializar el mapa `data` inspeccionando aliases semánticos comunes (`title`/`subject`/`heading` y `message`/`body`/`content`/`description`) con null-safety estricto.
  3. **Entidad Pura de Dominio (`AppNotification`)**:
     - Residir en `lib/features/notifications/domain/entities/app_notification.dart` sin dependencias de Flutter UI.
     - Resolver `title` y `message` de forma dinámica: priorizando el valor explícito en el payload y recurriendo a un fallback semántico basado en el tipo.
  4. **Adaptador de Presentación (`NotificationPresentationAdapter`)**:
     - Mapear la entidad pura hacia `NotificationUiModel` (icono temático, micro-badge de categoría como `SOPORTE`, `ANUNCIO` o `SISTEMA`, y colores reactivos al brillo activo mediante `constants.dart`).
  5. **Manejador Desacoplado de Acciones (`NotificationActionHandler`)**:
     - Centralizar la pulsación: marcar como leída de forma optimista, navegar a rutas específicas si existen `mix_id` o `tobacco_id`, o desplegar un modal inferior accesible (`NotificationDetailSheet`) con diseño plano y scrollable para anuncios y soporte.

## 🚀 Auditoría de Rendimiento, Seguridad y Preparación para Producción

### 1. Hardening Nativo y Minificación R8 en Android (`build.gradle.kts`)
- **Problema**: Declarar `proguardFiles(...)` en `buildTypes.release` sin habilitar `isMinifyEnabled = true` hace que el compilador R8 quede completamente desactivado por defecto en Kotlin DSL (AGP 8.x+). El APK o AAB resultante carece de ofuscación de código y *tree-shaking*, incrementando innecesariamente el tamaño del binario y dejando expuesta la lógica interna.
- **Solución (Regla de Oro)**: En `android/app/build.gradle.kts`, siempre activar conjuntamente:
  ```kotlin
  buildTypes {
      release {
          signingConfig = signingConfigs.getByName("release")
          isMinifyEnabled = true
          isShrinkResources = true
          proguardFiles(
              getDefaultProguardFile("proguard-android-optimize.txt"),
              "proguard-rules.pro"
          )
      }
  }
  ```

### 2. Prohibición de Scroll Anidado con `shrinkWrap: true` y Virtualización con Slivers
- **Problema**: Usar `SingleChildScrollView` + `Column` + `ListView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics())` destruye la virtualización nativa de Flutter. El framework se ve forzado a medir e instanciar en memoria todos los widgets de la lista a la vez, causando sobreconsumo de memoria y caídas severas de fotogramas (Jank a <30 FPS) en listados con decenas o cientos de elementos (ej. Favoritos o Historial).
- **Solución (Regla de Oro)**:
  1. Utilizar siempre `CustomScrollView`.
  2. Alojar secciones estáticas o cabeceras en `SliverToBoxAdapter` o `SliverPadding`.
  3. Renderizar listados con `SliverList(delegate: SliverChildBuilderDelegate(...))` para garantizar que únicamente los elementos visibles en el viewport sean evaluados y pintados por el pipeline de renderizado.
  4. Para listas agrupadas por categoría o fecha (ej. Historial), agrupar slivers mediante `SliverMainAxisGroup(slivers: [SliverToBoxAdapter(...), SliverList(...)])`.
  5. En `ReorderableListView.builder`, utilizar siempre el callback no deprecado `onReorderItem` en lugar de `onReorder` (Flutter 3.41+).

### 3. Blindaje de Red, Timeouts y Límites Defensivos contra Overfetching
- **Problema**: Consultas remotas a Supabase sin `.timeout(...)` quedan suspendidas de por vida ante micro-cortes o pérdida silenciosa de cobertura móvil, congelando loaders en la UI. Adicionalmente, consultar tablas relacionales con componentes embebidos sin `.limit()` descarga cargas masivas de datos innecesarias (*overfetching*).
- **Solución (Regla de Oro)**:
  1. Toda consulta de lectura debe incorporar `.timeout(supabaseReadTimeout)` y una cláusula `.limit(X)` defensiva (ej. `limit: 50` o `limit: 100`).
  2. Toda mutación (`insert`, `update`, `delete`, `upsert`) debe incorporar `.timeout(supabaseWriteTimeout)`.
  3. En `AppLogger._sendErrorToSupabase`, aplicar `.timeout(const Duration(seconds: 4))` en la inserción remota en `app_logs` para evitar que un reporte de fallo de red bloquee el event loop si el dispositivo no tiene salida a internet.

### 4. Dimensionamiento Óptimo de Avatares en RAM y Almacenamiento
- **Problema**: Renderizar fotos de perfil mediante `CircleAvatar(backgroundImage: CachedNetworkImageProvider(url))` sin limitar dimensiones en memoria decodifica la textura completa en la GPU (hasta 48-108 MP si el usuario tomó la foto con una cámara moderna), consumiendo cientos de megabytes de RAM.
- **Solución (Regla de Oro)**:
  1. En UI, consumir siempre el widget centralizado `UserAvatar(radius: X, avatarUrl: Y, username: Z)`, el cual calcula `memCacheWidth` y `memCacheHeight` proporcionales a los píxeles físicos del dispositivo (`size * pixelRatio`).
  2. En subida (`ProfileRepository`), limitar la resolución antes de comprimir mediante `FlutterImageCompress.compressAndGetFile(..., minWidth: 512, minHeight: 512, quality: 82)`.

### 5. Blindaje de Memoria RAM en `TobaccoImage` ante Dimensiones `double.infinity` y Preservación del Aspect Ratio (`BoxFit.cover`)
- **Problema**:
  1. Pasar `width: double.infinity` y `height: double.infinity` a `TobaccoImage` en cuadrículas (`CatalogPage`, `SearchResultsPage`) hacía que la comprobación `!width.isFinite` devolviera `null` para `memCacheWidth`, decodificando todas las fotos del catálogo a resolución completa en el `ImageCache` de Flutter.
  2. Si se pasan **simultáneamente** `memCacheWidth` y `memCacheHeight` a `CachedNetworkImage`, `ResizeImage` decodifica el bitmap forzando exactamente ese ancho y alto (`ResizeImagePolicy.exact`), **destruyendo la relación de aspecto original** de la imagen y haciendo que se vea achatada/estirada sin que `BoxFit.cover` pueda recortarla.
- **Solución (Regla de Oro)**:
  1. Envolver `CachedNetworkImage` dentro de `TobaccoImage` en un `LayoutBuilder`.
  2. Resolver la dimensión física mediante `TobaccoImage.resolveCacheDimension(explicitSize, constraintSize, devicePixelRatio)`, utilizando `constraints.maxWidth` / `constraints.maxHeight` cuando el tamaño explícito sea infinito o nulo y aplicando un tope máximo (`maxDefaultCacheDimension = 512` px físicos).
  3. **Pasar exclusivamente `memCacheWidth: math.max(cacheWidth, cacheHeight)` (dejando `memCacheHeight: null`)**: De este modo, el codec nativo de Flutter escala la imagen en RAM manteniendo intacta su proporción original, y `fit: BoxFit.cover` rellena el contenedor recortando limpiamente el excedente sin achatar ni deformar la foto.

### 6. Eliminación de Overfetching en Filtros de Comunidad, Marcas de Catálogo y Detalles de Mezcla
- **Problema**:
  1. El filtro de tabacos en Comunidad (`_TobaccoFilterDropdown`) descargaba hasta 5.000 registros en un bucle `while` y los renderizaba sin virtualizar en un `SingleChildScrollView` + `Column`.
  2. `TobaccoRepository.fetchAvailableBrands()` descargaba todas las filas de `tobaccos` para deduplicar marcas en Dart (sujeto además al límite de 1.000 filas de PostgREST).
  3. `CommunityRepository.fetchMixDetails()` y `MixDetailPage` ejecutaban bucles N+1 secuenciales y llamadas duplicadas para resolver los tabacos de cada componente.
- **Solución (Regla de Oro)**:
  1. Acotar `fetchAvailableTobaccos` a `limit: 50` con búsqueda delegada en servidor (con *debounce* de 300 ms) y virtualizar el menú con `ListView.builder`.
  2. Obtener marcas únicas mediante la función RPC SQL `get_available_tobacco_brands()` (`SELECT DISTINCT brand FROM public.tobaccos`).
  3. Resolver los componentes de una mezcla en una única consulta por lote (`.inFilter('name', uniqueNames)`) adjuntando `catalog_item` para evitar el doble bucle N+1 en `MixDetailPage`.

### 7. Eliminación Completa de Cuenta de Usuario (App Store Guideline 5.1.1(v) / Google Play Data Safety)
- **Problema**: Un cliente autenticado con la clave `anon` no tiene permisos directos en PostgREST para ejecutar `DELETE FROM auth.users`, por lo que dejar un aviso temporal o borrar únicamente `public.profiles` impide cumplir con las políticas de privacidad de Apple App Store y Google Play o deja la identidad de autenticación huérfana.
- **Solución Arquitectónica (Regla de Oro)**:
  1. **En Base de Datos**: Definir la función RPC `public.delete_user_account()` con `SECURITY DEFINER` y `SET search_path = public` (restringida con `REVOKE ALL FROM PUBLIC, anon` y `GRANT EXECUTE TO authenticated`), la cual obtiene `v_uid := (select auth.uid())`, elimina `public.profiles` (disparando `ON DELETE CASCADE` en datos privados y `ON DELETE SET NULL` en contenido comunitario) y elimina el registro en `auth.users`.
  2. **En Cliente (`ProfileRepository.deleteCurrentUserAccount`)**: Limpiar primero en modo *best-effort* los archivos del usuario en el bucket `avatars` (`<uid>/*`), invocar `_client.rpc('delete_user_account').timeout(supabaseWriteTimeout)` y finalmente cerrar la sesión local mediante `AuthProvider.signOut()`.

### 8. Sincronización de Barra Superior Global por Ruta Activa (`MainNavigationPage`)
- **Problema**: Guardar un único título de sobreescritura por pestaña (`_overrideTitles[_currentIndex]`) hacía que, al abrir una subpágina con `pushInCurrentTab` (ej. `FavoritesPage`, `UserMixesPage`, `HistoryPage`) y luego navegar desde ella hacia una vista con cabecera propia (`MixDetailPage`, `TobaccoDetailPage`, `CreateMixPage`) mediante `Navigator.of(context).push(...)`, `_overrideTitles[_currentIndex]` siguiera siendo no nulo (`'Favoritas'`) y la barra superior global no se ocultase, mostrando **dos flechas de retroceso simultáneas**.
- **Solución Arquitectónica (Regla de Oro)**:
  1. Vincular el título de la barra global directamente a la instancia de `PageRoute` creada en `pushInCurrentTab` mediante un `Expando<String>` (`_routeOverrideTitles[route] = title`).
  2. Hacer que `_TabNavigatorObserver` mantenga la pila de `PageRoute<dynamic>` de cada pestaña (ignorando `PopupRoute` como diálogos o *bottom sheets*) y exponga `topPageRoute`.
  3. En `_updateBackAndTitle()`, evaluar `activeOverrideTitle = _routeOverrideTitles[topPageRoute]`: si `canPop` es `true` y `activeOverrideTitle == null`, activar `_hideTopBar = true` para ocultar la barra global mientras la vista de detalle esté en primer plano, restaurándola automáticamente al hacer `pop`.

### 9. Blindaje de Producción: Idempotencia en `ensureProfile`, Reconciliación Atómica de Realtime y Actualización Transaccional de Mezclas
- **Problema**:
  1. En `SupabaseService.ensureProfile()`, invocar `.upsert()` sin `ignoreDuplicates: true` en cada evento `signedIn` o `userUpdated` sobreescribía el `username`, `display_name`, `is_public` y las preferencias guardadas en `user_settings` con los valores por defecto.
  2. En `NotificationsRepository.subscribeToNotifications()`, encadenar `.stream(primaryKey: ['id']).limit(20)` con `.expand((notifications) => notifications)` emitía hasta 20 eventos individuales síncronos en cada cambio de socket, provocando múltiples `notifyListeners()` e invirtiendo el orden cronológico al llegar lotes nuevos.
  3. En `CommunityRepository.updateMix()`, ejecutar `DELETE FROM mix_components` e `INSERT INTO mix_components` en llamadas HTTP separadas desde el cliente exponía a dejar mezclas con 0 ingredientes si ocurría un corte de red intermedio.
  4. En `MainNavigationPage`, llamar a `setState(() {})` en `TextField.onChanged` para actualizar el `suffixIcon` reconstruía el árbol completo de navegación en cada pulsación de tecla, y `AdBannerCard` mostraba el contenedor `"Patrocinado / ANUNCIO"` vacío cuando el anuncio aún no había cargado o fallaba.
- **Solución Arquitectónica (Regla de Oro)**:
  1. **Idempotencia en `ensureProfile`**: Pasar `ignoreDuplicates: true` siempre en `user_settings.upsert(..., onConflict: 'user_id', ignoreDuplicates: true)`, y usar `ignoreDuplicates: !hasExplicitProfileFields` en `profiles.upsert(...)` para no pisar perfiles existentes en inicios de sesión posteriores.
  2. **Reconciliación por Lote en Realtime**: Mantener `Stream<List<AppNotification>>` sin `.expand()` y reconciliar el lote completo en `NotificationsProvider._onRealtimeSnapshot` con una única llamada a `notifyListeners()`.
  3. **Atomicidad vía RPC (`update_user_mix`)**: Ejecutar la edición de cabecera y sustitución de componentes de una mezcla dentro de la función PostgreSQL `public.update_user_mix(p_mix_id, p_name, p_description, p_components)` en una sola transacción SQL.
  4. **Aislamiento de Rebuilds y Contenedores Publicitarios**: Usar `ValueListenableBuilder<TextEditingValue>` sobre `_searchController` únicamente para el `suffixIcon` del buscador global, y envolver el marco visual de `AdBannerCard` mediante el parámetro `builder` de `AdBannerWidget` para que solo se pinte cuando `_isLoaded && _bannerAd != null`.

### 10. Flujo de Recuperación de Contraseña y Trampa de `AuthChangeEvent.passwordRecovery`
- **Problema**: Al pulsar el enlace de recuperación enviado por correo (`resetPasswordForEmail` con `redirectTo: 'io.supabase.flutter://login-callback/'`), el SDK de Supabase establece una sesión temporal (`currentUser != null`) y emite `AuthChangeEvent.passwordRecovery`. Si `AuthProvider.isAuthenticated` solo evalúa `user != null`, `AuthGate` redirige inmediatamente a `MainNavigationPage` sin permitir al usuario establecer su nueva contraseña.
- **Solución Arquitectónica (Regla de Oro)**:
  1. **Aislamiento de Estado de Recuperación en `AuthProvider`**: Gestionar el flag `_isPasswordRecovery` (`bool get isPasswordRecovery`) y definir `bool get isAuthenticated => user != null && !_isPasswordRecovery;`.
  2. **Navegación Automática en Deep Link**: Al recibir `AuthChangeEvent.passwordRecovery`, activar `_isPasswordRecovery = true`, notificar a los listeners registrados (`addPasswordRecoveryListener`) y abrir `ResetPasswordPage` sobre `rootNavigatorKey`.
  3. **Restablecimiento y Transición Limpia**: En `ResetPasswordPage`, validar con la misma regex de fortaleza (`RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)')` y longitud `>= 8`), actualizar mediante `AuthProvider.updatePassword()` (`client.auth.updateUser(UserAttributes(password: newPassword))`), limpiar `_isPasswordRecovery = false` y mostrar confirmación con `AppToast`.

### 11. Compilación iOS: Error `PhaseScriptExecution` por Atributos Extendidos de macOS (`resource fork, Finder information, or similar detritus not allowed`)
- **Problema**: Al abrir o editar imágenes en `assets/` (ej. `assets/icon/*.png`) con Vista Previa (Preview) o Finder en macOS, el sistema operativo adjunta atributos extendidos (`com.apple.quarantine`, `com.apple.metadata:kMDLabel_*`, `com.apple.FinderInfo`). Durante la fase `Run Script` (`xcode_backend.sh build`), `flutter assemble` copia esos archivos dentro de `App.framework/flutter_assets/` y ejecuta `codesign` sobre `App.framework/App`, el cual falla en compilaciones firmadas para dispositivo físico con:
  `App.framework/App: resource fork, Finder information, or similar detritus not allowed` → `Command PhaseScriptExecution failed with a nonzero exit code`.
- **Solución Arquitectónica (Regla de Oro)**:
  1. **Limpieza Automática en Build Phases de Xcode (`ios/Runner.xcodeproj/project.pbxproj`)**: Preceder la ejecución de `xcode_backend.sh` en las fases `Run Script` y `Thin Binary` con `xattr -cr "${BUILT_PRODUCTS_DIR}" "${TARGET_BUILD_DIR}" "${PROJECT_DIR}/../assets" 2>/dev/null || true`, eliminando cualquier atributo extendido de macOS antes de empaquetar y firmar `App.framework`.
  2. **Limpieza de Caché de Productos en `DerivedData`**: Si un `App.framework` previo en `~/Library/Developer/Xcode/DerivedData/Runner-*/Build/Products/` ya quedó contaminado, ejecutar `xattr -cr` sobre dicho directorio o `flutter clean`.

### 12. Sistema Unificado de Reseñas: Validación de Calidad, Unicidad por Usuario y Pinning en Primera Posición
- **Problema**:
  1. Los formularios de reseñas de tabacos (`TobaccoDetailPage`) y mezclas (`MixDetailPage`) aceptaban textos triviales (`"."`, `"ok"`, `". . . . ."`) y duplicaban la lógica de validación local.
  2. No se restringía la publicación de múltiples reseñas por un mismo usuario sobre el mismo tabaco o mezcla, ni se priorizaba la reseña propia en la lista.
  3. `TobaccoReviewsRepository` y `TobaccoReviewsProvider` carecían de operaciones de edición (`updateReview`) y borrado (`deleteReview`).
- **Solución Arquitectónica (Regla de Oro)**:
  1. **Validador Centralizado (`ReviewValidator` en `lib/core/utils/review_validator.dart`)**:
     - Exigir `rating > 0`, un mínimo de **5 palabras válidas** (`>= 2` caracteres alfanuméricos Unicode `[\p{L}\p{N}]` por palabra) y un mínimo de **15 caracteres útiles** (alfanuméricos) en total.
     - Proveer `ReviewValidator.evaluateProgress(comment)` junto con `ValueListenableBuilder<TextEditingValue>` para mostrar feedback reactivo en tiempo real (`"Mínimo 5 palabras (llevas X)"` → `"Comentario válido (X palabras)"`) sin reconstruir toda la pantalla.
  2. **Unicidad y Adaptación Dinámica de UI**:
     - Verificar en repositorio mediante `.count(CountOption.exact)` que el usuario no posea ya una reseña activa antes de insertar.
     - Exponer `userReview` y `hasUserReviewed`: cuando `hasUserReviewed == true`, ocultar el formulario de creación y reactivarlo inmediatamente tras eliminar la reseña propia.
  3. **Pinning Prioritario y Paridad CRUD**:
     - Ordenar todas las listas de reseñas con `ReviewValidator.sortWithUserReviewFirst(...)`, fijando la reseña del usuario autenticado en el índice `0` con badge `"Tu reseña"`, borde destacado y acciones directas de **Editar** y **Eliminar**, manteniendo el resto ordenado por `created_at DESC`.





