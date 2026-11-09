import 'package:flutter/material.dart';
import '../../../core/constants.dart';
import '../../../widgets/pastel_textfield.dart';
import 'package:provider/provider.dart';
import 'auth_provider.dart';
import 'forgot_password_page.dart';
import '../../../core/utils/app_toast.dart';

class PastelPasswordField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final bool obscureText;
  final VoidCallback onToggleVisibility;
  final Color? fillColor;
  final Color? iconColor;
  final Color? textColor;

  const PastelPasswordField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.obscureText,
    required this.onToggleVisibility,
    this.fillColor,
    this.iconColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      style: TextStyle(color: textColor ?? Colors.black),
      decoration: InputDecoration(
        prefixIcon: Icon(Icons.lock_outline, color: iconColor ?? turquoiseDark),
        hintText: hintText,
        hintStyle: TextStyle(
          color: (textColor ?? Colors.black).withValues(alpha: 0.5),
        ),
        filled: true,
        fillColor: fillColor ?? Colors.white,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: turquoiseDark, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: turquoiseDark, width: 2.2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.red, width: 2.2),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: turquoiseDark, width: 1.5),
        ),
        suffixIcon: IconButton(
          icon: Icon(
            obscureText ? Icons.visibility_off : Icons.visibility,
            color: iconColor ?? turquoiseDark,
          ),
          onPressed: onToggleVisibility,
        ),
      ),
    );
  }
}

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  static final RegExp _usernameRegex = RegExp(r'^[a-zA-Z0-9_]+$');
  static final RegExp _emailRegex = RegExp(
    r'^[\w\.-]+@([\w-]+\.)+[a-zA-Z]{2,63}$',
  );
  static final RegExp _upperCaseRegex = RegExp(r'[A-Z]');
  static final RegExp _lowerCaseRegex = RegExp(r'[a-z]');
  static final RegExp _digitRegex = RegExp(r'[0-9]');
  static final RegExp _specialCharRegex = RegExp(r'[!@#\$&*~_\-]');

  final _usernameFocus = FocusNode();
  final _firstNameFocus = FocusNode();
  final _lastNameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmPasswordFocus = FocusNode();
  bool _usernameError = false;
  bool _firstNameError = false;
  bool _lastNameError = false;
  bool _emailError = false;
  String? _emailServerError;
  String? _failedRegisteredEmail;
  bool _passwordError = false;
  bool _confirmPasswordError = false;
  bool _showErrors = false;
  bool _triedRegister = false;
  bool _showAgeError = false;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_onEmailChanged);
  }

  void _onEmailChanged() {
    if (_emailServerError != null &&
        _emailController.text.trim() != _failedRegisteredEmail) {
      setState(() {
        _emailServerError = null;
        _failedRegisteredEmail = null;
        final value = _emailController.text;
        _emailError = value.isNotEmpty && !_emailRegex.hasMatch(value);
      });
    }
  }

  bool _isOlderThan18(DateTime birthDate) {
    final now = DateTime.now();
    final eighteenYearsAgo = DateTime(now.year - 18, now.month, now.day);
    return birthDate.isBefore(eighteenYearsAgo) ||
        birthDate.isAtSameMomentAs(eighteenYearsAgo);
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'La contraseña es obligatoria';
    if (value.length < 8) return 'Debe tener al menos 8 caracteres';
    if (!_upperCaseRegex.hasMatch(value)) {
      return 'Debe contener al menos una mayúscula';
    }
    if (!_lowerCaseRegex.hasMatch(value)) {
      return 'Debe contener al menos una minúscula';
    }
    if (!_digitRegex.hasMatch(value)) {
      return 'Debe contener al menos un número';
    }
    if (!_specialCharRegex.hasMatch(value)) {
      return 'Debe contener un carácter especial (!@#\$&*~_- )';
    }
    return null;
  }

  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _birthDateController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  DateTime? _selectedBirthDate;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _emailController.removeListener(_onEmailChanged);
    _usernameFocus.dispose();
    _firstNameFocus.dispose();
    _lastNameFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _confirmPasswordFocus.dispose();
    _usernameController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _birthDateController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _selectBirthDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedBirthDate ?? DateTime(2000, 1, 1),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      locale: const Locale('es', 'ES'),
    );
    if (picked != null) {
      setState(() {
        _selectedBirthDate = picked;
        _birthDateController.text =
            '${picked.day}/${picked.month}/${picked.year}';
        // Validar inmediatamente la mayoría de edad
        _showAgeError = !_isOlderThan18(picked);
        _showErrors =
            true; // Activar la visualización de errores para este campo
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registro'),
        backgroundColor: isDark ? darkBg : Colors.white,
        foregroundColor: isDark ? darkNavy : navy,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Nombre de usuario',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? darkNavy : navy,
                ),
              ),
              const SizedBox(height: 8),
              Focus(
                focusNode: _usernameFocus,
                onFocusChange: (hasFocus) {
                  if (!hasFocus && _triedRegister) {
                    final value = _usernameController.text;
                    setState(() {
                      _usernameError =
                          value.isEmpty ||
                          value.length < 3 ||
                          !_usernameRegex.hasMatch(value);
                    });
                  }
                },
                child: PastelTextField(
                  controller: _usernameController,
                  hintText: 'Introduce tu nombre de usuario',
                  icon: Icons.person_outline,
                  fillColor: isDark ? fieldDark : fieldLight,
                  iconColor: isDark ? darkTurquoise : turquoise,
                  textColor:
                      Theme.of(context).textTheme.bodyLarge?.color ??
                      Colors.black,
                ),
              ),
              if (_showErrors && _usernameError) ...[
                Padding(
                  padding: const EdgeInsets.only(left: 8, top: 4),
                  child: Text(
                    _usernameController.text.isEmpty
                        ? 'El nombre de usuario es obligatorio'
                        : _usernameController.text.length < 3
                        ? 'Debe tener al menos 3 caracteres'
                        : 'Solo letras, números y guiones bajos',
                    style: const TextStyle(color: Colors.red, fontSize: 13),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                'Nombre',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? darkNavy : navy,
                ),
              ),
              const SizedBox(height: 8),
              Focus(
                focusNode: _firstNameFocus,
                onFocusChange: (hasFocus) {
                  if (!hasFocus && _triedRegister) {
                    final value = _firstNameController.text;
                    setState(() {
                      _firstNameError = value.isEmpty || value.length < 2;
                    });
                  }
                },
                child: PastelTextField(
                  controller: _firstNameController,
                  hintText: 'Introduce tu nombre',
                  icon: Icons.badge_outlined,
                  fillColor: isDark ? fieldDark : fieldLight,
                  iconColor: isDark ? darkTurquoise : turquoise,
                  textColor:
                      Theme.of(context).textTheme.bodyLarge?.color ??
                      Colors.black,
                ),
              ),
              if (_showErrors && _firstNameError) ...[
                Padding(
                  padding: const EdgeInsets.only(left: 8, top: 4),
                  child: Text(
                    _firstNameController.text.isEmpty
                        ? 'El nombre es obligatorio'
                        : 'Debe tener al menos 2 caracteres',
                    style: const TextStyle(color: Colors.red, fontSize: 13),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                'Apellidos',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? darkNavy : navy,
                ),
              ),
              const SizedBox(height: 8),
              Focus(
                focusNode: _lastNameFocus,
                onFocusChange: (hasFocus) {
                  if (!hasFocus && _triedRegister) {
                    final value = _lastNameController.text;
                    setState(() {
                      _lastNameError = value.isEmpty || value.length < 2;
                    });
                  }
                },
                child: PastelTextField(
                  controller: _lastNameController,
                  hintText: 'Introduce tus apellidos',
                  icon: Icons.family_restroom_outlined,
                  fillColor: isDark ? fieldDark : fieldLight,
                  iconColor: isDark ? darkTurquoise : turquoise,
                  textColor:
                      Theme.of(context).textTheme.bodyLarge?.color ??
                      Colors.black,
                ),
              ),
              if (_showErrors && _lastNameError) ...[
                Padding(
                  padding: const EdgeInsets.only(left: 8, top: 4),
                  child: Text(
                    _lastNameController.text.isEmpty
                        ? 'Los apellidos son obligatorios'
                        : 'Debe tener al menos 2 caracteres',
                    style: const TextStyle(color: Colors.red, fontSize: 13),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                'Fecha de nacimiento',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? darkNavy : navy,
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _selectBirthDate,
                child: AbsorbPointer(
                  child: PastelTextField(
                    controller: _birthDateController,
                    hintText: 'Selecciona tu fecha de nacimiento',
                    icon: Icons.calendar_today_outlined,
                    fillColor: isDark ? fieldDark : fieldLight,
                    iconColor: isDark ? darkTurquoise : turquoise,
                    textColor:
                        Theme.of(context).textTheme.bodyLarge?.color ??
                        Colors.black,
                    obscureText: false,
                  ),
                ),
              ),
              if (_showErrors && _showAgeError)
                Padding(
                  padding: const EdgeInsets.only(left: 8, top: 4),
                  child: Text(
                    'Debes ser mayor de 18 años',
                    style: const TextStyle(color: Colors.red, fontSize: 13),
                  ),
                ),
              const SizedBox(height: 16),
              Text(
                'Correo electrónico',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? darkNavy : navy,
                ),
              ),
              const SizedBox(height: 8),
              Focus(
                focusNode: _emailFocus,
                onFocusChange: (hasFocus) {
                  if (!hasFocus) {
                    final value = _emailController.text;
                    final hasFormatError =
                        value.isNotEmpty && !_emailRegex.hasMatch(value);
                    setState(() {
                      _emailError =
                          hasFormatError || _emailServerError != null;
                      if (hasFormatError) _showErrors = true;
                    });
                  }
                },
                child: PastelTextField(
                  controller: _emailController,
                  hintText: 'Introduce tu correo electrónico',
                  icon: Icons.email_outlined,
                  fillColor: isDark ? fieldDark : fieldLight,
                  iconColor: isDark ? darkTurquoise : turquoise,
                  textColor:
                      Theme.of(context).textTheme.bodyLarge?.color ??
                      Colors.black,
                ),
              ),
              if (_showErrors && _emailError) ...[
                Padding(
                  padding: const EdgeInsets.only(left: 8, top: 4),
                  child: Semantics(
                    container: true,
                    liveRegion: true,
                    child: Text(
                      _emailServerError ??
                          (_emailController.text.isEmpty
                              ? 'El correo electrónico es obligatorio'
                              : 'Introduce un correo electrónico válido'),
                      style: const TextStyle(color: warningRed, fontSize: 13),
                    ),
                  ),
                ),
                if (_emailServerError != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, top: 4),
                    child: Wrap(
                      spacing: 8,
                      children: [
                        TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: isDark ? darkNavy : navy,
                            minimumSize: const Size(48, 48),
                            tapTargetSize: MaterialTapTargetSize.padded,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                          onPressed: _isLoading
                              ? null
                              : () => Navigator.pop(context),
                          child: Semantics(
                            label: 'Iniciar sesión con tu cuenta existente',
                            child: const ExcludeSemantics(
                              child: Text('Iniciar sesión'),
                            ),
                          ),
                        ),
                        TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: isDark ? darkNavy : navy,
                            minimumSize: const Size(48, 48),
                            tapTargetSize: MaterialTapTargetSize.padded,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                          onPressed: _isLoading
                              ? null
                              : () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute<void>(
                                      builder: (_) =>
                                          const ForgotPasswordPage(),
                                    ),
                                  );
                                },
                          child: const Text('¿Olvidaste tu contraseña?'),
                        ),
                      ],
                    ),
                  ),
              ],
              const SizedBox(height: 16),
              Text(
                'Contraseña',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? darkNavy : navy,
                ),
              ),
              const SizedBox(height: 8),
              Focus(
                focusNode: _passwordFocus,
                onFocusChange: (hasFocus) {
                  if (!hasFocus) {
                    final value = _passwordController.text;
                    final hasError =
                        value.isNotEmpty && _validatePassword(value) != null;
                    setState(() {
                      _passwordError = hasError;
                      if (hasError) _showErrors = true;
                    });
                  }
                },
                child: PastelPasswordField(
                  controller: _passwordController,
                  hintText: 'Introduce tu contraseña',
                  obscureText: _obscurePassword,
                  onToggleVisibility: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                  fillColor: isDark ? fieldDark : fieldLight,
                  iconColor: isDark ? darkTurquoise : turquoise,
                  textColor:
                      Theme.of(context).textTheme.bodyLarge?.color ??
                      Colors.black,
                ),
              ),
              if (_showErrors && _passwordError) ...[
                Padding(
                  padding: const EdgeInsets.only(left: 8, top: 4),
                  child: Text(
                    _validatePassword(_passwordController.text) ?? '',
                    style: const TextStyle(color: Colors.red, fontSize: 13),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                'Repetir contraseña',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? darkNavy : navy,
                ),
              ),
              const SizedBox(height: 8),
              Focus(
                focusNode: _confirmPasswordFocus,
                onFocusChange: (hasFocus) {
                  if (!hasFocus) {
                    final value = _confirmPasswordController.text;
                    final hasError =
                        value.isNotEmpty && value != _passwordController.text;
                    setState(() {
                      _confirmPasswordError = hasError;
                      if (hasError) _showErrors = true;
                    });
                  }
                },
                child: PastelPasswordField(
                  controller: _confirmPasswordController,
                  hintText: 'Repite tu contraseña',
                  obscureText: _obscureConfirmPassword,
                  onToggleVisibility: () {
                    setState(() {
                      _obscureConfirmPassword = !_obscureConfirmPassword;
                    });
                  },
                  fillColor: isDark ? fieldDark : fieldLight,
                  iconColor: isDark ? darkTurquoise : turquoise,
                  textColor:
                      Theme.of(context).textTheme.bodyLarge?.color ??
                      Colors.black,
                ),
              ),
              if (_showErrors && _confirmPasswordError) ...[
                Padding(
                  padding: const EdgeInsets.only(left: 8, top: 4),
                  child: Text(
                    _confirmPasswordController.text.isEmpty
                        ? 'Repite la contraseña'
                        : 'Las contraseñas no coinciden',
                    style: const TextStyle(color: Colors.red, fontSize: 13),
                  ),
                ),
              ],
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : () async {
                          final birthDate = _selectedBirthDate;
                          // Validación manual de campos (siempre mostrar todos los errores en un único setState)
                          final username = _usernameController.text;
                          final firstName = _firstNameController.text;
                          final lastName = _lastNameController.text;
                          final email = _emailController.text;
                          final password = _passwordController.text;
                          final confirmPassword =
                              _confirmPasswordController.text;
                          setState(() {
                            _showErrors = true;
                            _triedRegister = true;
                            _emailServerError = null;
                            _failedRegisteredEmail = null;
                            _usernameError =
                                username.isEmpty ||
                                username.length < 3 ||
                                !_usernameRegex.hasMatch(username);
                            _firstNameError =
                                firstName.isEmpty || firstName.length < 2;
                            _lastNameError =
                                lastName.isEmpty || lastName.length < 2;
                            _emailError =
                                email.isEmpty || !_emailRegex.hasMatch(email);
                            _passwordError =
                                _validatePassword(password) != null;
                            _confirmPasswordError =
                                confirmPassword.isEmpty ||
                                confirmPassword != password;
                            _showAgeError =
                                birthDate == null || !_isOlderThan18(birthDate);
                          });
                          if (_usernameError ||
                              _firstNameError ||
                              _lastNameError ||
                              _emailError ||
                              _passwordError ||
                              _confirmPasswordError ||
                              _showAgeError) {
                            return;
                          }
                          setState(() => _isLoading = true);
                          final auth = context.read<AuthProvider>();
                          final error = await auth.registerEmail(
                            _emailController.text.trim(),
                            _passwordController.text,
                            username: _usernameController.text.trim(),
                            firstName: _firstNameController.text.trim(),
                            lastName: _lastNameController.text.trim(),
                            birthdate: _selectedBirthDate,
                          );
                          if (!mounted || !context.mounted) return;
                          if (error != null) {
                            final isEmailRelatedError =
                                error.toLowerCase().contains(
                                      'correo electrónico',
                                    ) ||
                                    error.toLowerCase().contains('ya existe');
                            setState(() {
                              _isLoading = false;
                              if (isEmailRelatedError) {
                                _showErrors = true;
                                _emailError = true;
                                _emailServerError = error;
                                _failedRegisteredEmail =
                                    _emailController.text.trim();
                              }
                            });
                            AppToast.showError(context, error);
                            return;
                          }
                          // ensureProfile también se ejecutará al recibir la sesión
                          setState(() {
                            _isLoading = false;
                            _showErrors = false;
                            _triedRegister = false;
                          });
                          AppToast.showInfo(
                            context,
                            'Registro exitoso. Revisa tu correo si se requiere verificación.',
                          );
                          Navigator.pop(context);
                        },
                  child: _isLoading
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
                      : const Text('Registrarse'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
