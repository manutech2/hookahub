# Copilot & AI Instructions for Hookahub

## 🧩 Project Context

- **App**: Hookahub (`v1.1.0+2`) — Social mobile app for discovering shisha tobaccos, creating and rating community mixes, managing Top 5 favorites, history, and real-time notifications.
- **Framework**: Flutter (Dart SDK `^3.9.2`), Material 3.
- **Target Platforms**: Android & iOS only.
- **Architecture**: Clean Architecture separated by feature (`data/`, `domain/`, `presentation/`).
- **Backend / BaaS**: Supabase (`supabase_flutter ^2.10.3`) via `SupabaseService` singleton (`lib/core/data/supabase_service.dart`), PostgREST, PostgreSQL RPCs & Triggers, Storage (`avatars`), and Supabase Realtime.
- **State Management**: `Provider` (`^6.1.2`) + `ChangeNotifier` registered in root `MultiProvider` (`lib/app.dart`) using **sealed UI state classes (`sealed class`)** — never fragmented loading/error booleans.
- **Knowledge Base**: Always consult [`README.md`](../README.md) for product overview/architecture and [`GEMINI.md`](../GEMINI.md) for hardened rules and resolved pitfalls before proposing or writing code.

---

## 📁 Real Project Structure

```text
lib/
├── main.dart                     # Entry point: Env check, Supabase.initialize, MobileAds, DeepLinkService
├── app.dart                      # Root MultiProvider, AppTheme, ToastificationWrapper, DatabaseConnectionBanner, l10n
├── core/                         # Cross-cutting infrastructure
│   ├── config/env.dart           # Compile-time Env via String.fromEnvironment (--dart-define-from-file=.env)
│   ├── constants.dart            # Color palette, timeouts (4s read / 8s write), rootNavigatorKey, appAvatarIcons
│   ├── storage.dart              # Theme persistence via SharedPreferences
│   ├── theme.dart                # Light & Dark Material 3 themes
│   ├── theme_provider.dart       # ThemeMode state via ChangeNotifier
│   ├── data/supabase_service.dart
│   ├── models/                   # Shared models: mix.dart, tobacco.dart, review.dart, notification.dart
│   ├── providers/                # database_health_provider.dart
│   ├── services/                 # database_health_service.dart, deep_link_service.dart, interstitial_ad_manager.dart
│   └── utils/                    # app_logger.dart, app_error_mapper.dart, app_toast.dart, review_validator.dart
├── features/                     # 12 feature modules (strictly data / domain / presentation)
│   ├── auth/                     # Email & Google Sign-In v7, registration, password recovery, AuthGate
│   ├── catalog/                  # Paginated tobaccos, brand RPC filter, tobacco reviews, tobacco requests
│   ├── community/                # Community feed, MixPercentageCalculator (100%), atomic mix edit RPC, mix detail
│   ├── favorites/                # Favorites & Top 5 ordered list
│   ├── feedback/                 # Contact & bug/suggestion form (user_feedback)
│   ├── history/                  # Deduplicated recent mix views (mix_views)
│   ├── home/                     # Home dashboard & Realtime global stats (app_statistics)
│   ├── mixes/                    # Current user's created mixes & optimistic counter sync
│   ├── notifications/            # Supabase Realtime notifications & contextual navigation
│   ├── onboarding/               # 3-step onboarding flow persisted locally
│   ├── profile/                  # Profile view/edit, avatar compression + cache-busting, settings, delete_user_account RPC
│   └── search/                   # Unified search (tobaccos & mixes), L1 suggestions cache, local search history
├── widgets/                      # Shared widgets (MainNavigationPage, UserAvatar, TobaccoImage, MixCard, TobaccoCard, AdBanner*)
└── l10n/                         # Localization .arb files (app_es.arb, app_en.arb)
```

---

## ⚙️ Core Dependencies (`pubspec.yaml`)

| Category | Package | Version | Purpose |
| :--- | :--- | :--- | :--- |
| Core | `flutter` / `flutter_localizations` | SDK (`^3.9.2`) | UI framework & localization delegates |
| Backend | `supabase_flutter` | `^2.10.3` | Auth, PostgREST, RPC, Realtime, Storage |
| Auth | `google_sign_in` | `^7.2.0` | Native Google Sign-In (`GoogleSignIn.instance` singleton) |
| State Management | `provider` | `^6.1.2` | `MultiProvider`, `ChangeNotifier`, `Consumer` / `Selector` |
| Persistence | `shared_preferences` | `^2.2.3` | Theme, onboarding flag, local search history |
| Images & Media | `cached_network_image`, `image_picker`, `file_picker`, `image_cropper`, `flutter_image_compress` | Latest in `pubspec.yaml` | Cropped/compressed uploads & RAM-bounded decoding |
| Connectivity & Links | `connectivity_plus`, `app_links`, `share_plus`, `url_launcher` | Latest in `pubspec.yaml` | Healthchecks, deep links (`hookahub://`), sharing |
| Observability & UX | `logger`, `toastification`, `timeago` | Latest in `pubspec.yaml` | `AppLogger` (remote `app_logs`), `AppToast`, relative timestamps |
| Ads | `google_mobile_ads` | `^9.1.0` | AdMob adaptive banners & preloaded interstitials |
| Linting & Testing | `flutter_lints` (`^6.0.0`), `flutter_test` | SDK | Static analysis & unit/widget tests (`test/`) |

> **Important:** Do NOT introduce `Dio`, `GoRouter`, `Freezed`, or `get_it` unless explicitly requested by the user — the project intentionally uses `SupabaseService`, standard `Navigator` (with per-tab `Navigator` keys in `MainNavigationPage` + `rootNavigatorKey`), hand-written immutable models, and `MultiProvider`.

---

## 🧠 Mandatory Architecture & Coding Rules

1. **Feature Layering**: Every module under `lib/features/<name>/` must keep `data/`, `domain/`, and `presentation/` separated. Never place pages or providers in a feature's root folder.
2. **Sealed UI States**: Use `sealed class <Feature>State` (`Initial`, `Loading`, `Loaded`, `Error`) instead of fragmented boolean flags (`isLoading`, `hasError`).
3. **Logging (`AppLogger`)**: NEVER use `print()` or `debugPrint()`. Use `AppLogger.debug/info/warning` for diagnostics and `AppLogger.error/fatal` (with `error:` and `stackTrace:`) for unexpected failures. Never log transient Realtime disconnects or network `TimeoutException`/`SocketException` healthchecks as `AppLogger.error`.
4. **Error Mapping & Timeouts**: Map user-facing exceptions with `AppErrorMapper.toSpanish(error)` and display feedback via `AppToast` / `ScaffoldMessenger`. Apply `supabaseReadTimeout` (`4s`) and `supabaseWriteTimeout` (`8s`) from `lib/core/constants.dart` to Supabase calls.
5. **No Hardcoded Form/Screen Colors**: Always use color tokens from `lib/core/constants.dart` (`turquoise`, `turquoiseDark`, `fieldLight`, `navy`, `darkBg`, `darkTurquoise`, `darkNavy`, `fieldDark`, `warningRed`, etc.) instead of inline `Color(0xFF...)`.
6. **Environment Variables**: Never bundle `.env` into `pubspec.yaml` `assets:`. Read secrets strictly through `Env` (`lib/core/config/env.dart`) injected via `--dart-define-from-file=.env`.
7. **Supabase & SQL Security**:
   - Always wrap auth checks in RLS policies with `(select auth.uid())` / `(select auth.role())` to avoid `auth_rls_initplan`.
   - Always set `SET search_path = public` on `SECURITY DEFINER` functions.
   - Use `.count(CountOption.exact)` for counts instead of `.select('id')` + `.length`.
   - Keep `avatars` public without a broad `SELECT` policy on `storage.objects` (prevents directory listing).
8. **Image Memory Safety**: Use `UserAvatar` and `TobaccoImage` (bounded RAM cache via `LayoutBuilder` and `memCacheWidth` only to preserve aspect ratio).

---

## 🔄 Documentación Viva (Actualización Automática de `README.md` y `GEMINI.md`)

To keep the repository continuously understandable for developers and external tools (such as **Jira AI / Atlassian Rovo**, GitHub Copilot, and code auditors):

- **Whenever a task adds or modifies any of the following**, you MUST update [`README.md`](../README.md) (and [`GEMINI.md`](../GEMINI.md) if a new technical rule or pitfall was solved) **in the same change before finishing**:
  1. New features, screens, providers, or repositories inside `lib/features/` or `lib/core/`.
  2. New or altered Supabase tables, RPC functions, triggers, or RLS migrations under `supabase/migrations/`.
  3. Dependency changes in `pubspec.yaml` or new environment variables in `.env.example` / `lib/core/config/env.dart`.
  4. Completion of any item listed in Section 7.B (*Oportunidades de Evolución y Épicas Sugeridas*) of `README.md`: move completed items out of the open backlog and reflect them in Section 4 (*Matriz de Funcionalidades*) and/or Section 7.A (*Puntos Ya Blindados*).
  5. **Cross-Repo Impact (`WebAdmin_Hookahub`)**: Whenever changes affect shared Supabase tables (`user_feedback`, `tobacco_requests`, `tobaccos`, `mixes`, `reviews`, `tobacco_reviews`, `notifications`, `app_logs`, `app_statistics`), status enums, or admin-managed flows, update Section 8 of `README.md` and flag/create the corresponding `web-admin` task in Jira (`SCRUM`).
- Keep `README.md` concise, factual, and strictly aligned with the actual codebase.

---

## 🧪 Verification & Commands

- Run app: `flutter run --dart-define-from-file=.env`
- Static analysis: `flutter analyze`
- Run tests: `flutter test`
- Conventional Commits: `feat(scope): ...`, `fix(scope): ...`, `docs(scope): ...`, `refactor(scope): ...`
