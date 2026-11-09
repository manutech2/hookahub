import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants.dart';
import '../../../core/theme_provider.dart';
import '../../../widgets/pastel_textfield.dart';
import '../../../widgets/social_login_button.dart';
import 'auth_provider.dart';
import 'forgot_password_page.dart';
import 'register_page.dart';
import '../../../core/utils/app_toast.dart';

// ---------------------------------------------------------------------------
// Estados UI (sealed class — sin booleanos fragmentados)
// ---------------------------------------------------------------------------

sealed class LoginState {
  const LoginState();
}

/// Estado inicial en reposo, listo para interactuar.
class LoginIdle extends LoginState {
  const LoginIdle();
}

/// Autenticación por correo y contraseña en curso.
class LoginEmailLoading extends LoginState {
  const LoginEmailLoading();
}

/// Autenticación por Google en curso.
class LoginGoogleLoading extends LoginState {
  const LoginGoogleLoading();
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  LoginState _loginState = const LoginIdle();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleEmailLogin() async {
    if (_loginState is! LoginIdle) return;

    setState(() => _loginState = const LoginEmailLoading());
    try {
      final auth = context.read<AuthProvider>();
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      final error = await auth.signInEmail(email, password);

      if (!mounted) return;
      if (error != null) {
        AppToast.showError(context, error);
      }
    } finally {
      if (mounted) {
        setState(() => _loginState = const LoginIdle());
      }
    }
  }

  Future<void> _handleGoogleLogin() async {
    if (_loginState is! LoginIdle) return;

    setState(() => _loginState = const LoginGoogleLoading());
    try {
      final auth = context.read<AuthProvider>();
      final error = await auth.signInGoogle();

      if (!mounted) return;
      if (error != null) {
        AppToast.showError(context, error);
      }
    } finally {
      if (mounted) {
        setState(() => _loginState = const LoginIdle());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isSubmitting = _loginState is! LoginIdle;
    final bool isEmailLoading = _loginState is LoginEmailLoading;
    final bool isGoogleLoading = _loginState is LoginGoogleLoading;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Consumer<ThemeProvider>(
              builder: (context, themeProvider, _) {
                return IconButton(
                  tooltip: 'Cambiar tema',
                  icon: Icon(
                    switch (themeProvider.themeMode) {
                      ThemeMode.light => Icons.light_mode,
                      ThemeMode.dark => Icons.dark_mode,
                      ThemeMode.system => Icons.brightness_auto,
                    },
                    color: Theme.of(context).primaryColor,
                  ),
                  onPressed: isSubmitting
                      ? null
                      : () {
                          final nextMode = switch (themeProvider.themeMode) {
                            ThemeMode.system => ThemeMode.light,
                            ThemeMode.light => ThemeMode.dark,
                            ThemeMode.dark => ThemeMode.system,
                          };
                          themeProvider.setThemeMode(nextMode);
                        },
                );
              },
            ),
          ),
        ],
        automaticallyImplyLeading: false,
      ),
          body: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 20),
                    Text(
                      'Hookahub',
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                        letterSpacing: 2,
                        shadows: [
                          Shadow(
                            color: Theme.of(
                              context,
                            ).primaryColor.withValues(alpha: 0.18),
                            blurRadius: 6,
                            offset: const Offset(2, 2),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Tu comunidad de mezclas de tabaco',
                      style: TextStyle(
                        fontSize: 18,
                        color: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 40),
                    PastelTextField(
                      controller: _emailController,
                      hintText: 'Correo electrónico',
                      icon: Icons.email_outlined,
                      readOnly: isSubmitting,
                      fillColor: isDark ? fieldDark : fieldLight,
                      iconColor: Theme.of(context).primaryColor,
                      textColor:
                          Theme.of(context).textTheme.bodyLarge?.color ??
                          Colors.black,
                    ),
                    const SizedBox(height: 20),
                    PastelTextField(
                      controller: _passwordController,
                      hintText: 'Contraseña',
                      icon: Icons.lock_outline,
                      obscureText: _obscurePassword,
                      readOnly: isSubmitting,
                      fillColor: isDark ? fieldDark : fieldLight,
                      iconColor: Theme.of(context).primaryColor,
                      textColor:
                          Theme.of(context).textTheme.bodyLarge?.color ??
                          Colors.black,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: Theme.of(context).primaryColor,
                        ),
                        onPressed: isSubmitting
                            ? null
                            : () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                      ),
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: isDark ? darkNavy : navy,
                          minimumSize: const Size(48, 40),
                        ),
                        onPressed: isSubmitting
                            ? null
                            : () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const ForgotPasswordPage(),
                                  ),
                                );
                              },
                        child: const Text('¿Has olvidado tu contraseña?'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: isSubmitting ? null : _handleEmailLogin,
                        child: isEmailLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Text('Iniciar sesión'),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // ── Divider "o continúa con" ──────────────────────────
                    Row(
                      children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'o continúa con',
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.color
                                  ?.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SocialLoginButton(
                      provider: SocialProvider.google,
                      isLoading: isGoogleLoading,
                      onPressed: isSubmitting ? null : _handleGoogleLogin,
                    ),

                    const SizedBox(height: 8),
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                      onPressed: isSubmitting
                          ? null
                          : () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const RegisterPage(),
                                ),
                              );
                            },
                      child: const Text('¿No tienes cuenta? Regístrate'),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        );
  }
}
