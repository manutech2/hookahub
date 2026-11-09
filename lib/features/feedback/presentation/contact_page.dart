import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/config/env.dart';
import '../../../core/constants.dart';
import '../../../core/data/supabase_service.dart';
import '../../../core/utils/app_toast.dart';
import '../data/feedback_repository.dart';
import '../domain/feedback_category.dart';
import 'providers/feedback_provider.dart';

class ContactPage extends StatelessWidget {
  const ContactPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => FeedbackProvider(
        FeedbackRepository(SupabaseService()),
      ),
      child: const _ContactView(),
    );
  }
}

class _ContactView extends StatefulWidget {
  const _ContactView();

  @override
  State<_ContactView> createState() => _ContactViewState();
}

class _ContactViewState extends State<_ContactView> {
  final _formKey = GlobalKey<FormState>();
  final _subjectCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();

  FeedbackCategory _selectedCategory = FeedbackCategory.bug;

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  String _getPlatform() {
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return 'other';
  }

  String _getMessageHint() {
    switch (_selectedCategory) {
      case FeedbackCategory.bug:
        return '¿Qué estabas haciendo cuando ocurrió el error? Explica los pasos para reproducirlo...';
      case FeedbackCategory.suggestion:
        return 'Cuéntanos tu sugerencia o idea de mejora para Hookahub...';
      case FeedbackCategory.other:
        return 'Escribe tu consulta o duda y te responderemos lo antes posible...';
    }
  }

  Future<void> _handleSubmit(BuildContext context) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final provider = context.read<FeedbackProvider>();
    final success = await provider.submit(
      category: _selectedCategory,
      subject: _subjectCtrl.text,
      message: _messageCtrl.text,
      platform: _getPlatform(),
      appVersion: Env.appVersion,
    );

    if (!context.mounted) return;

    if (success) {
      AppToast.showSuccess(
        context,
        '¡Mensaje recibido! Gracias por ayudarnos a mejorar Hookahub.',
      );
      await Future.delayed(const Duration(milliseconds: 800));
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    } else {
      final state = provider.state;
      final errorMessage = state is FeedbackError
          ? state.message
          : 'No se pudo enviar el mensaje. Inténtalo de nuevo.';
      AppToast.showError(context, errorMessage);
      provider.reset();
    }
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
    int? maxLength,
    String? Function(String?)? validator,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fillColor = isDark ? fieldDark : fieldLight;
    final borderColor = isDark ? darkTurquoise : turquoiseDark;
    final labelColor = isDark
        ? (theme.textTheme.bodyLarge?.color ?? Colors.white)
        : navy;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: labelColor,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          maxLength: maxLength,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: theme.textTheme.bodyLarge?.color?.withValues(alpha: 0.45),
            ),
            filled: true,
            fillColor: fillColor,
            counterStyle: TextStyle(
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: borderColor.withValues(alpha: 0.6),
                width: 1.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: borderColor, width: 2.2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: warningRed, width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: warningRed, width: 2.2),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isLoading = context.select<FeedbackProvider, bool>(
      (p) => p.state is FeedbackLoading,
    );

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      // AppBar removida: el título y navegación atrás se muestran en la barra superior global
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Tarjeta introductoria
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? fieldDark : fieldLight,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: (isDark ? darkTurquoise : turquoiseDark)
                          .withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.mark_email_read_outlined,
                        color: isDark ? darkTurquoise : turquoiseDark,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Tu opinión nos importa. Cuéntanos si has detectado algún problema o si tienes ideas para mejorar la app.',
                          style: TextStyle(
                            fontSize: 14,
                            color: theme.textTheme.bodyMedium?.color
                                ?.withValues(alpha: 0.85),
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Selector de categoría
                Text(
                  'Tipo de mensaje',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? (theme.textTheme.bodyLarge?.color ?? Colors.white)
                        : navy,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<FeedbackCategory>(
                    showSelectedIcon: false,
                    selected: {_selectedCategory},
                    onSelectionChanged: (newSelection) {
                      setState(() {
                        _selectedCategory = newSelection.first;
                      });
                    },
                    segments: const [
                      ButtonSegment<FeedbackCategory>(
                        value: FeedbackCategory.bug,
                        icon: Icon(Icons.bug_report_outlined, size: 18),
                        label: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Error',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      ButtonSegment<FeedbackCategory>(
                        value: FeedbackCategory.suggestion,
                        icon: Icon(Icons.lightbulb_outline, size: 18),
                        label: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Sugerencia',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      ButtonSegment<FeedbackCategory>(
                        value: FeedbackCategory.other,
                        icon: Icon(Icons.chat_bubble_outline, size: 18),
                        label: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Otro',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Campo Asunto
                _buildField(
                  controller: _subjectCtrl,
                  label: 'Asunto',
                  hint: _selectedCategory == FeedbackCategory.bug
                      ? 'Ej: Error al subir imagen de mezcla'
                      : 'Ej: Sugerencia de nueva función',
                  maxLength: 80,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Por favor indica un asunto';
                    }
                    if (v.trim().length < 4) {
                      return 'El asunto debe tener al menos 4 caracteres';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Campo Mensaje / Descripción
                _buildField(
                  controller: _messageCtrl,
                  label: 'Descripción detallada',
                  hint: _getMessageHint(),
                  maxLines: 5,
                  maxLength: 1500,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Por favor escribe tu mensaje';
                    }
                    if (v.trim().length < 10) {
                      return 'El mensaje debe tener al menos 10 caracteres';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),

                // Microtexto de metadatos del dispositivo
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 15,
                      color: theme.textTheme.bodySmall?.color
                          ?.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Se adjuntarán automáticamente datos técnicos básicos (sistema operativo y versión de la app) para facilitar la resolución de incidencias.',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.textTheme.bodySmall?.color
                              ?.withValues(alpha: 0.65),
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Botón de envío
                FilledButton(
                  onPressed: isLoading ? null : () => _handleSubmit(context),
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        isDark ? darkTurquoise : turquoiseDark,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Enviar mensaje',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
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
