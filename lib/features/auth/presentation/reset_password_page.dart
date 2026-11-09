import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants.dart';
import '../../../core/data/supabase_service.dart';
import '../../../core/utils/app_error_mapper.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/app_toast.dart';
import 'auth_provider.dart';

// ---------------------------------------------------------------------------
// Estados UI (sealed class — sin booleanos fragmentados)
// ---------------------------------------------------------------------------

sealed class ResetPasswordState {
  const ResetPasswordState();
}

class ResetPasswordIdle extends ResetPasswordState {
  const ResetPasswordIdle();
}

class ResetPasswordLoading extends ResetPasswordState {
  const ResetPasswordLoading();
}

class ResetPasswordSuccess extends ResetPasswordState {
  const ResetPasswordSuccess();
}

class ResetPasswordError extends ResetPasswordState {
  final String message;
  const ResetPasswordError(this.message);
}

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({
    super.key,
    this.supabaseService,
    this.onResetPassword,
  });

  final SupabaseService? supabaseService;
  final Future<String?> Function(String newPassword)? onResetPassword;

  /// Regex de validación de fortaleza: mínimo una minúscula, una mayúscula y un dígito.
  static final RegExp passwordStrengthRegex = RegExp(
    r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)',
  );

  /// Valida la nueva contraseña siguiendo las reglas de Hookahub.
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'La nueva contraseña es obligatoria';
    }
    if (value.length < 8) {
      return 'La contraseña debe tener al menos 8 caracteres';
    }
    if (!passwordStrengthRegex.hasMatch(value)) {
      return 'La contraseña debe contener al menos una mayúscula, una minúscula y un número';
    }
    return null;
  }

  /// Valida que la confirmación coincida con la nueva contraseña.
  static String? validateConfirmPassword(String? value, String newPassword) {
    if (value == null || value.isEmpty) {
      return 'Confirma tu nueva contraseña';
    }
    if (value != newPassword) {
      return 'Las contraseñas no coinciden';
    }
    return null;
  }

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  ResetPasswordState _state = const ResetPasswordIdle();

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleResetPassword() async {
    if (_state is ResetPasswordLoading) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _state = const ResetPasswordLoading();
    });

    final newPassword = _newPasswordController.text;

    try {
      String? errorMessage;

      if (widget.onResetPassword != null) {
        errorMessage = await widget.onResetPassword!(newPassword);
      } else {
        AuthProvider? authProvider;
        try {
          authProvider = context.read<AuthProvider>();
        } catch (_) {
          authProvider = null;
        }

        if (authProvider != null && widget.supabaseService == null) {
          errorMessage = await authProvider.updatePassword(newPassword);
        } else {
          final svc = widget.supabaseService ?? SupabaseService();
          await svc.client.auth
              .updateUser(UserAttributes(password: newPassword))
              .timeout(supabaseWriteTimeout);
          authProvider?.clearPasswordRecovery();
        }
      }

      if (!mounted) return;

      if (errorMessage != null) {
        setState(() {
          _state = ResetPasswordError(errorMessage!);
        });
        AppToast.showError(context, errorMessage);
        return;
      }

      setState(() {
        _state = const ResetPasswordSuccess();
      });
      AppToast.showSuccess(context, 'Contraseña actualizada exitosamente');
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } catch (e, stackTrace) {
      AppLogger.error(
        'Error al restablecer contraseña',
        error: e,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      final mapped = AppErrorMapper.toSpanish(e);
      setState(() {
        _state = ResetPasswordError(mapped);
      });
      AppToast.showError(
        context,
        'Error al cambiar contraseña: $mapped',
      );
    } finally {
      if (mounted && _state is ResetPasswordLoading) {
        setState(() {
          _state = const ResetPasswordIdle();
        });
      }
    }
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String hintText,
    required bool obscureText,
    required VoidCallback onToggleVisibility,
    required String? Function(String?) validator,
    required bool readOnly,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const borderTurquoise = turquoiseDark;

    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      readOnly: readOnly,
      validator: validator,
      style: TextStyle(color: isDark ? darkNavy : navy),
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.lock_outline, color: borderTurquoise),
        suffixIcon: IconButton(
          icon: Icon(
            obscureText ? Icons.visibility_off : Icons.visibility,
            color: isDark
                ? darkNavy.withValues(alpha: 0.6)
                : navy.withValues(alpha: 0.6),
          ),
          onPressed: readOnly ? null : onToggleVisibility,
        ),
        hintText: hintText,
        hintStyle: TextStyle(
          color: isDark
              ? darkNavy.withValues(alpha: 0.6)
              : navy.withValues(alpha: 0.5),
        ),
        filled: true,
        fillColor: isDark ? fieldDark : fieldLight,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: borderTurquoise, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: borderTurquoise, width: 2.2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: warningRed, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: warningRed, width: 2.2),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: borderTurquoise, width: 1.5),
        ),
        contentPadding: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLoading = _state is ResetPasswordLoading;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Restablecer contraseña'),
        backgroundColor: Colors.transparent,
        foregroundColor: isDark ? darkNavy : navy,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: (isDark ? darkTurquoise : turquoise).withValues(
                    alpha: 0.1,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: (isDark ? darkTurquoise : turquoise).withValues(
                      alpha: 0.3,
                    ),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: isDark ? darkTurquoise : turquoise,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Tu nueva contraseña debe tener al menos 8 caracteres y contener mayúsculas, minúsculas y números.',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? darkNavy : navy,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Nueva contraseña',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? darkNavy : navy,
                ),
              ),
              const SizedBox(height: 8),
              _buildPasswordField(
                controller: _newPasswordController,
                hintText: 'Ingresa tu nueva contraseña',
                obscureText: _obscureNewPassword,
                readOnly: isLoading,
                onToggleVisibility: () {
                  setState(() {
                    _obscureNewPassword = !_obscureNewPassword;
                  });
                },
                validator: ResetPasswordPage.validatePassword,
              ),
              const SizedBox(height: 20),
              Text(
                'Confirmar nueva contraseña',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? darkNavy : navy,
                ),
              ),
              const SizedBox(height: 8),
              _buildPasswordField(
                controller: _confirmPasswordController,
                hintText: 'Confirma tu nueva contraseña',
                obscureText: _obscureConfirmPassword,
                readOnly: isLoading,
                onToggleVisibility: () {
                  setState(() {
                    _obscureConfirmPassword = !_obscureConfirmPassword;
                  });
                },
                validator: (value) =>
                    ResetPasswordPage.validateConfirmPassword(
                      value,
                      _newPasswordController.text,
                    ),
              ),
              if (_state case ResetPasswordError(:final message)) ...[
                const SizedBox(height: 12),
                Text(
                  message,
                  style: const TextStyle(
                    color: warningRed,
                    fontSize: 13,
                  ),
                ),
              ],
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _handleResetPassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? darkTurquoise : turquoise,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: isLoading
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
                      : const Text(
                          'Guardar nueva contraseña',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

