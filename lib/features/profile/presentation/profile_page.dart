import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/config/env.dart';
import '../../../core/constants.dart';
import '../../../widgets/user_avatar.dart';
import 'settings_page.dart';
import 'edit_profile_page.dart';
import '../../favorites/presentation/favorites_page.dart';
import '../../mixes/presentation/user_mixes_page.dart';
import '../../auth/presentation/auth_provider.dart';
import 'profile_provider.dart';
import '../../favorites/presentation/favorites_provider.dart';
import '../../history/presentation/history_page.dart';
import '../../feedback/presentation/contact_page.dart';
import '../../../widgets/main_navigation.dart';
import '../../../core/utils/app_toast.dart';
import '../../../core/utils/app_logger.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  @override
  void initState() {
    super.initState();
    // Carga diferida: se realizará al entrar en la pestaña Perfil
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final profileProvider = context.watch<ProfileProvider>();
    final favoritesCount = context.select<FavoritesProvider, int>(
      (p) => p.favorites.length,
    );
    final profile = profileProvider.profile;
    final signedUrl = profileProvider.signedAvatarUrl;
    final hasPhoto = signedUrl != null && signedUrl.isNotEmpty;
    final displayName =
        (profile?.displayName != null &&
            profile!.displayName!.trim().isNotEmpty)
        ? profile.displayName!
        : (profile?.username ?? 'Usuario');

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            context.read<ProfileProvider>().load(),
            context.read<FavoritesProvider>().load(),
          ]);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Header del perfil
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [
                            darkTurquoise.withValues(alpha: 0.2),
                            darkNavy.withValues(alpha: 0.1),
                          ]
                        : [
                            turquoise.withValues(alpha: 0.1),
                            turquoiseDark.withValues(alpha: 0.05),
                          ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? darkTurquoise.withValues(alpha: 0.3)
                        : turquoise.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  children: [
                    // Avatar optimizado con control de memoria y resolución nativa
                    UserAvatar(
                      username: displayName,
                      avatarUrl: hasPhoto ? signedUrl : profile?.avatarUrl,
                      radius: 50,
                      backgroundColor: isDark ? darkTurquoise : turquoise,
                      fontSize: 36,
                    ),
                    const SizedBox(height: 16),
                    // Nombre del usuario
                    Text(
                      displayName,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: isDark ? darkNavy : navy,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      profileProvider.isLoading
                          ? 'Cargando perfil...'
                          : (profile != null ? '@${profile.username}' : ''),
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark
                            ? darkNavy.withValues(alpha: 0.7)
                            : navy.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Estadísticas del usuario
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      profileProvider.mixesCount.toString(),
                      'Mezclas',
                      Theme.of(context).primaryColor,
                      onTap: () {
                        final nav = MainNavigationPage.of(context);
                        nav?.pushInCurrentTab(
                          'Mis mezclas',
                          const UserMixesPage(),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      favoritesCount.toString(),
                      'Favoritas',
                      Theme.of(context).primaryColor,
                      onTap: () {
                        final nav = MainNavigationPage.of(context);
                        nav?.pushInCurrentTab('Favoritas', const FavoritesPage());
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Opciones del perfil
              _buildOptionsList(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String number,
    String label,
    Color color, {
    VoidCallback? onTap,
  }) {
    return Builder(
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;

        final textScaler = MediaQuery.textScalerOf(context);
        final scaleFactor = textScaler.scale(1.0);

        final card = Container(
          height: scaleFactor > 1.1 ? (scaleFactor > 1.4 ? 110 : 90) : 80,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                number,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? darkNavy : navy,
                ),
              ),
              const SizedBox(height: 4),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? darkNavy.withValues(alpha: 0.8)
                        : navy.withValues(alpha: 0.7),
                    height: 1.2,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );

        if (onTap == null) return card;

        return Semantics(
          button: true,
          label: '$label: $number',
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onTap,
              child: card,
            ),
          ),
        );
      },
    );
  }

  Widget _buildOptionsList(BuildContext context) {
    return Column(
      children: [
        _buildOptionTile(
          icon: Icons.person_outline,
          title: 'Editar Perfil',
          subtitle: 'Cambiar foto y datos personales',
          onTap: () {
            final nav = MainNavigationPage.of(context);
            nav?.pushInCurrentTab('Editar perfil', const EditProfilePage());
          },
        ),
        const SizedBox(height: 12),
        _buildOptionTile(
          icon: Icons.settings_outlined,
          title: 'Configuración',
          subtitle: 'Tema, notificaciones y privacidad',
          onTap: () {
            final nav = MainNavigationPage.of(context);
            nav?.pushInCurrentTab('Configuración', const SettingsPage());
          },
        ),
        const SizedBox(height: 12),
        _buildOptionTile(
          icon: Icons.history,
          title: 'Historial',
          subtitle: 'Tu actividad reciente',
          onTap: () {
            final nav = MainNavigationPage.of(context);
            nav?.pushInCurrentTab('Historial', const HistoryPage());
          },
        ),
        const SizedBox(height: 12),
        _buildOptionTile(
          icon: Icons.star_outline,
          title: 'Calificar la app',
          subtitle: 'Comparte tu experiencia',
          onTap: () => _rateApp(context),
        ),
        const SizedBox(height: 12),
        _buildOptionTile(
          icon: Icons.contact_mail_outlined,
          title: 'Contáctanos',
          subtitle: 'Envía sugerencias, dudas o reporta un error',
          onTap: () => _contactUs(context),
        ),
        const SizedBox(height: 12),

        Container(
          margin: const EdgeInsets.symmetric(vertical: 16.0),
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.transparent,
                Theme.of(context).dividerColor.withValues(alpha: 0.5),
                Colors.transparent,
              ],
            ),
          ),
        ),

        _buildAppFooter(context),
        const SizedBox(height: 16),

        Builder(
          builder: (context) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return Center(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [
                            Theme.of(
                              context,
                            ).scaffoldBackgroundColor.withValues(alpha: 0.95),
                            Theme.of(
                              context,
                            ).scaffoldBackgroundColor.withValues(alpha: 0.95),
                          ]
                        : [
                            Theme.of(context).primaryColor,
                            Theme.of(context).colorScheme.secondary,
                          ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: isDark
                      ? Border.all(
                          color: Theme.of(
                            context,
                          ).primaryColor.withValues(alpha: 0.3),
                          width: 1,
                        )
                      : null,
                  boxShadow: isDark
                      ? null
                      : [
                          BoxShadow(
                            color: Theme.of(
                              context,
                            ).primaryColor.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () async {
                      final auth = context.read<AuthProvider>();
                      try {
                        await auth.signOut();
                      } catch (e, stack) {
                        AppLogger.error('Error al cerrar sesión', error: e, stackTrace: stack);
                        if (context.mounted) {
                          AppToast.showInfo(context, 'Error al cerrar sesión');
                        }
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24.0,
                        vertical: 12.0,
                      ),
                      child: Text(
                        'Cerrar Sesión',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                          color: isDark
                              ? Theme.of(context).primaryColor
                              : Colors.white,
                          shadows: null,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return Builder(
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;

        // Colores pastel para el botón destructivo
        final Color destructiveIconColor = isDark
            ? const Color(0xFFFF9999) // Rojo pastel más claro para modo oscuro
            : const Color(0xFFE57373); // Rojo pastel para modo claro

        final Color destructiveTextColor = isDark
            ? const Color(0xFFFFB3B3) // Rojo pastel muy claro para modo oscuro
            : const Color(0xFFE57373); // Rojo pastel para modo claro

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: isDestructive
                ? Colors
                      .transparent // Sin fondo para el botón destructivo
                : (isDark
                      ? darkBg.withValues(alpha: 0.3)
                      : Colors.grey.withValues(alpha: 0.05)),
            borderRadius: BorderRadius.circular(12),
            border: isDestructive
                ? null // Sin borde para el botón destructivo
                : Border.all(
                    color: isDark
                        ? darkTurquoise.withValues(alpha: 0.2)
                        : Colors.grey.withValues(alpha: 0.2),
                  ),
          ),
          child: ListTile(
            leading: Icon(
              icon,
              color: isDestructive
                  ? destructiveIconColor
                  : (isDark ? darkTurquoise : turquoise),
            ),
            title: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isDestructive
                    ? destructiveTextColor
                    : (isDark ? darkNavy : navy),
              ),
            ),
            subtitle: Text(
              subtitle,
              style: TextStyle(
                color: isDark
                    ? darkNavy.withValues(alpha: 0.7)
                    : navy.withValues(alpha: 0.6),
                fontSize: 12,
              ),
            ),
            trailing: isDestructive
                ? null // Sin flecha para el botón destructivo
                : Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: isDark ? darkNavy.withValues(alpha: 0.6) : Colors.grey,
                  ),
            onTap: onTap,
          ),
        );
      },
    );
  }

  Widget _buildAppFooter(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subtleColor = isDark
        ? darkNavy.withValues(alpha: 0.6)
        : navy.withValues(alpha: 0.6);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Versión ${Env.appVersion}',
          style: TextStyle(
            fontSize: 12,
            color: subtleColor,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Text(
            '•',
            style: TextStyle(
              fontSize: 12,
              color: subtleColor,
            ),
          ),
        ),
        InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: () => _showLicenses(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
            child: Text(
              'Licencias de código abierto',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: subtleColor,
                decoration: TextDecoration.underline,
                decorationColor: subtleColor,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showLicenses(BuildContext context) {
    showLicensePage(
      context: context,
      applicationName: 'Hookahub',
      applicationVersion: Env.appVersion,
      applicationIcon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.local_fire_department,
          color: Colors.white,
          size: 32,
        ),
      ),
    );
  }

  Future<void> _rateApp(BuildContext context) async {
    const String androidPackageName = 'com.manutech.hookahub';
    const String iosAppId = Env.appleAppStoreId;

    Uri? storeUrl;

    if (Platform.isAndroid) {
      storeUrl = Uri.parse('market://details?id=$androidPackageName');

      if (!await canLaunchUrl(storeUrl)) {
        storeUrl = Uri.parse(
          'https://play.google.com/store/apps/details?id=$androidPackageName',
        );
      }
    } else if (Platform.isIOS) {
      if (iosAppId.isEmpty) {
        if (context.mounted) {
          AppToast.showInfo(
            context,
            'La valoración en App Store estará disponible próximamente',
          );
        }
        return;
      }
      storeUrl = Uri.parse(
        'https://apps.apple.com/app/id$iosAppId?action=write-review',
      );
    }

    if (storeUrl != null) {
      try {
        final canLaunch = await canLaunchUrl(storeUrl);
        if (canLaunch) {
          await launchUrl(storeUrl, mode: LaunchMode.externalApplication);
        } else {
          if (context.mounted) {
            AppToast.showInfo(context, 'No se pudo abrir la tienda de aplicaciones');
          }
        }
      } catch (e, stackTrace) {
        AppLogger.error('Error al abrir la tienda de aplicaciones', error: e, stackTrace: stackTrace);
        if (context.mounted) {
          AppToast.showError(context, 'Error al abrir la tienda: $e');
        }
      }
    } else {
      if (context.mounted) {
        AppToast.showInfo(context, 'Plataforma no soportada');
      }
    }
  }

  void _contactUs(BuildContext context) {
    final nav = MainNavigationPage.of(context);
    if (nav != null) {
      nav.pushInCurrentTab('Contáctanos', const ContactPage());
    } else {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const ContactPage(),
        ),
      );
    }
  }
}
