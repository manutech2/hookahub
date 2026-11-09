import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hookahub/core/data/supabase_service.dart';
import 'package:hookahub/core/theme_provider.dart';
import 'package:hookahub/features/auth/presentation/auth_provider.dart';
import 'package:hookahub/features/auth/presentation/forgot_password_page.dart';
import 'package:hookahub/features/auth/presentation/login_page.dart';
import 'package:hookahub/features/auth/presentation/reset_password_page.dart';
import 'package:hookahub/widgets/pastel_textfield.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:toastification/toastification.dart';

class FakeGoTrueClient extends Fake implements GoTrueClient {
  @override
  Stream<AuthState> get onAuthStateChange => const Stream.empty();

  @override
  Session? get currentSession => null;
}

class FakeSupabaseClient extends Fake implements SupabaseClient {
  @override
  GoTrueClient get auth => FakeGoTrueClient();
}

class FakeAuthSupabaseService implements SupabaseService {
  @override
  SupabaseClient get client => FakeSupabaseClient();

  @override
  Future<void> signOut() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockAuthProvider extends AuthProvider {
  MockAuthProvider(super.svc);

  int sendResetCallCount = 0;
  String? lastRequestedEmail;
  String? resetErrorToReturn;
  Completer<String?>? resetEmailCompleter;

  int updatePasswordCallCount = 0;
  String? lastNewPassword;
  Completer<String?>? updatePasswordCompleter;

  @override
  Future<String?> sendPasswordResetEmail(String email) async {
    sendResetCallCount++;
    lastRequestedEmail = email;
    if (resetEmailCompleter != null) {
      return resetEmailCompleter!.future;
    }
    return resetErrorToReturn;
  }

  @override
  Future<String?> updatePassword(String newPassword) async {
    updatePasswordCallCount++;
    lastNewPassword = newPassword;
    if (updatePasswordCompleter != null) {
      return updatePasswordCompleter!.future;
    }
    return null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockAuthProvider mockAuth;
  late ThemeProvider themeProvider;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockAuth = MockAuthProvider(FakeAuthSupabaseService());
    themeProvider = ThemeProvider();
  });

  tearDown(() {
    mockAuth.dispose();
    themeProvider.dispose();
  });

  Widget wrapWithProviders(Widget home) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: mockAuth),
        ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
      ],
      child: ToastificationWrapper(
        child: MaterialApp(
          home: home,
        ),
      ),
    );
  }

  group('Renderizado y Navegación desde LoginPage', () {
    testWidgets(
      'muestra el botón "¿Has olvidado tu contraseña?" y navega a ForgotPasswordPage al pulsarlo',
      (tester) async {
        await tester.pumpWidget(wrapWithProviders(const LoginPage()));
        await tester.pumpAndSettle();

        final forgotPasswordButtonFinder = find.widgetWithText(
          TextButton,
          '¿Has olvidado tu contraseña?',
        );
        expect(forgotPasswordButtonFinder, findsOneWidget);

        await tester.tap(forgotPasswordButtonFinder);
        await tester.pumpAndSettle();

        expect(find.byType(ForgotPasswordPage), findsOneWidget);
        expect(find.text('Recuperar contraseña'), findsOneWidget);
      },
    );
  });

  group('Interacción en ForgotPasswordPage', () {
    testWidgets(
      'no permite enviar si el campo de correo está vacío o mal formateado',
      (tester) async {
        await tester.pumpWidget(wrapWithProviders(const ForgotPasswordPage()));
        await tester.pumpAndSettle();

        final submitButtonFinder = find.widgetWithText(
          ElevatedButton,
          'Enviar instrucciones',
        );
        expect(submitButtonFinder, findsOneWidget);

        // 1. Intento con correo vacío
        await tester.tap(submitButtonFinder);
        await tester.pump();

        expect(mockAuth.sendResetCallCount, equals(0));
        expect(
          find.text('El correo electrónico es obligatorio'),
          findsOneWidget,
        );

        // 2. Intento con correo mal formateado
        final emailFieldFinder = find.byType(PastelTextField);
        await tester.enterText(emailFieldFinder, 'correo-invalido');
        await tester.tap(submitButtonFinder);
        await tester.pump();

        expect(mockAuth.sendResetCallCount, equals(0));
        expect(
          find.text('Introduce un correo electrónico válido'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'simula envío exitoso y transiciona al estado ForgotPasswordSuccess mostrando mensaje informativo',
      (tester) async {
        await tester.pumpWidget(wrapWithProviders(const ForgotPasswordPage()));
        await tester.pumpAndSettle();

        final emailFieldFinder = find.byType(PastelTextField);
        await tester.enterText(emailFieldFinder, 'usuario@hookahub.com');

        final submitButtonFinder = find.widgetWithText(
          ElevatedButton,
          'Enviar instrucciones',
        );
        await tester.tap(submitButtonFinder);
        await tester.pumpAndSettle();

        expect(mockAuth.sendResetCallCount, equals(1));
        expect(mockAuth.lastRequestedEmail, equals('usuario@hookahub.com'));

        // Verificar que la UI muestra la vista de confirmación (ForgotPasswordSuccess)
        expect(find.text('Revisa tu bandeja de entrada'), findsOneWidget);
        expect(
          find.textContaining('usuario@hookahub.com'),
          findsOneWidget,
        );
        expect(find.text('Volver al inicio de sesión'), findsOneWidget);
      },
    );
  });

  group('Interacción en ResetPasswordPage', () {
    testWidgets(
      'muestra error de validación si las dos contraseñas no coinciden',
      (tester) async {
        await tester.pumpWidget(wrapWithProviders(const ResetPasswordPage()));
        await tester.pumpAndSettle();

        final textFields = find.byType(TextFormField);
        expect(textFields, findsNWidgets(2));

        await tester.enterText(textFields.at(0), 'Hookah123');
        await tester.enterText(textFields.at(1), 'Diferente123');

        final submitButton = find.byType(ElevatedButton);
        await tester.tap(submitButton);
        await tester.pump();

        expect(find.text('Las contraseñas no coinciden'), findsOneWidget);
        expect(mockAuth.updatePasswordCallCount, equals(0));
      },
    );

    testWidgets(
      'el botón de envío muestra el indicador de carga cuando está en proceso',
      (tester) async {
        mockAuth.updatePasswordCompleter = Completer<String?>();

        await tester.pumpWidget(wrapWithProviders(const ResetPasswordPage()));
        await tester.pumpAndSettle();

        final textFields = find.byType(TextFormField);
        await tester.enterText(textFields.at(0), 'Hookah123');
        await tester.enterText(textFields.at(1), 'Hookah123');

        final submitButton = find.byType(ElevatedButton);
        await tester.tap(submitButton);
        await tester.pump();

        // Debe mostrar CircularProgressIndicator y deshabilitar el botón mientras está en curso
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        final elevatedButtonWidget = tester.widget<ElevatedButton>(submitButton);
        expect(elevatedButtonWidget.onPressed, isNull);
        expect(mockAuth.updatePasswordCallCount, equals(1));

        // Completar el Completer y limpiar el toast timer
        mockAuth.updatePasswordCompleter!.complete(null);
        await tester.pump();
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
      },
    );
  });
}

