import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants.dart';
import '../../../core/utils/app_toast.dart';
import '../../../widgets/pastel_textfield.dart';
import 'auth_provider.dart';

// ---------------------------------------------------------------------------
// Estados UI (sealed class — sin booleanos fragmentados)
// ---------------------------------------------------------------------------

sealed class ForgotPasswordState {
  const ForgotPasswordState();
}

class ForgotPasswordIdle extends ForgotPasswordState {
  const ForgotPasswordIdle();
}

class ForgotPasswordLoading extends ForgotPasswordState {
  const ForgotPasswordLoading();
}

class ForgotPasswordSuccess extends ForgotPasswordState {
  final String email;
  const ForgotPasswordSuccess(this.email);
}

class ForgotPasswordError extends ForgotPasswordState {
  final String message;
  const ForgotPasswordError(this.message);
}

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({
    super.key,
    this.resendCooldownSeconds = 60,
  });

  final int resendCooldownSeconds;

  static final RegExp emailRegex = RegExp(
    r'^[\w\.-]+@([\w-]+\.)+[a-zA-Z]{2,63}$',
  );

  /// Valida el formato del correo electrónico.
  static String? validateEmail(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'El correo electrónico es obligatorio';
    }
    if (!emailRegex.hasMatch(trimmed)) {
      return 'Introduce un correo electrónico válido';
    }
    return null;
  }

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final TextEditingController _emailController = TextEditingController();
  ForgotPasswordState _state = const ForgotPasswordIdle();
  Timer? _resendTimer;
  int _remainingSeconds = 0;

  ForgotPasswordState get state => _state;

  @override
  void dispose() {
    _resendTimer?.cancel();
    _emailController.dispose();
    super.dispose();
  }

  void _startResendCooldown() {
    _resendTimer?.cancel();
    if (widget.resendCooldownSeconds <= 0) return;

    setState(() {
      _remainingSeconds = widget.resendCooldownSeconds;
    });

    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_remainingSeconds <= 1) {
        timer.cancel();
        setState(() {
          _remainingSeconds = 0;
        });
      } else {
        setState(() {
          _remainingSeconds--;
        });
      }
    });
  }

  Future<void> _handleSubmit() async {
    if (_state is ForgotPasswordLoading) return;

    final email = _emailController.text.trim();
    final validationError = ForgotPasswordPage.validateEmail(email);
    if (validationError != null) {
      setState(() {
        _state = ForgotPasswordError(validationError);
      });
      return;
    }

    setState(() {
      _state = const ForgotPasswordLoading();
    });

    final auth = context.read<AuthProvider>();
    final error = await auth.sendPasswordResetEmail(email);

    if (!mounted) return;

    if (error != null) {
      setState(() {
        _state = ForgotPasswordError(error);
      });
      AppToast.showError(context, error);
      return;
    }

    setState(() {
      _state = ForgotPasswordSuccess(email);
    });
  }

  Future<void> _handleResend(String email) async {
    if (_remainingSeconds > 0 || _state is ForgotPasswordLoading) return;

    final auth = context.read<AuthProvider>();
    final error = await auth.sendPasswordResetEmail(email);

    if (!mounted) return;

    if (error != null) {
      AppToast.showError(context, error);
      return;
    }

    _startResendCooldown();
    AppToast.showInfo(
      context,
      'Hemos vuelto a enviar las instrucciones a $email',
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLoading = _state is ForgotPasswordLoading;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Recuperar contraseña'),
        backgroundColor: Colors.transparent,
        foregroundColor: isDark ? darkNavy : navy,
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
          child: switch (_state) {
            ForgotPasswordSuccess(:final email) => _buildSuccessView(
                context,
                email: email,
                isDark: isDark,
              ),
            _ => _buildFormView(
                context,
                isDark: isDark,
                isLoading: isLoading,
              ),
          },
        ),
      ),
    );
  }

  Widget _buildFormView(
    BuildContext context, {
    required bool isDark,
    required bool isLoading,
  }) {
    final accentColor = isDark ? darkTurquoise : turquoise;
    final labelColor = isDark ? darkNavy : navy;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accentColor.withValues(alpha: 0.14),
            ),
            child: Icon(
              Icons.lock_reset_rounded,
              size: 38,
              color: accentColor,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: Text(
            '¿Olvidaste tu contraseña?',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: labelColor,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            'Introduce el correo electrónico asociado a tu cuenta y te enviaremos un enlace para restablecer tu contraseña.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: labelColor.withValues(alpha: 0.75),
            ),
          ),
        ),
        const SizedBox(height: 32),
        Text(
          'Correo electrónico',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: labelColor,
          ),
        ),
        const SizedBox(height: 8),
        PastelTextField(
          controller: _emailController,
          hintText: 'Correo electrónico',
          icon: Icons.email_outlined,
          readOnly: isLoading,
          fillColor: isDark ? fieldDark : fieldLight,
          iconColor: Theme.of(context).primaryColor,
          textColor: labelColor,
        ),
        if (_state case ForgotPasswordError(:final message)) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: Text(
              message,
              style: const TextStyle(
                color: warningRed,
                fontSize: 13,
              ),
            ),
          ),
        ],
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: isLoading ? null : _handleSubmit,
            child: isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text('Enviar instrucciones'),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessView(
    BuildContext context, {
    required String email,
    required bool isDark,
  }) {
    final accentColor = isDark ? darkTurquoise : turquoise;
    final labelColor = isDark ? darkNavy : navy;

    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: isDark ? fieldDark : fieldLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: turquoiseDark,
          width: 1.5,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accentColor.withValues(alpha: 0.16),
            ),
            child: Icon(
              Icons.mark_email_read_outlined,
              size: 36,
              color: accentColor,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Revisa tu bandeja de entrada',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: labelColor,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Hemos enviado las instrucciones para restablecer tu contraseña a $email. Si no lo encuentras, revisa tu carpeta de spam o correo no deseado.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: labelColor.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 24),
          TextButton.icon(
            onPressed: _remainingSeconds > 0 ? null : () => _handleResend(email),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: Text(
              _remainingSeconds > 0
                  ? 'Reenviar en ${_remainingSeconds}s'
                  : 'Reenviar instrucciones',
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Volver al inicio de sesión'),
            ),
          ),
        ],
      ),
    );
  }
}

