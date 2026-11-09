import 'package:flutter_test/flutter_test.dart';
import 'package:hookahub/core/models/review.dart';
import 'package:hookahub/core/utils/review_validator.dart';

void main() {
  group('ReviewValidator - Validación de calidad y longitud', () {
    test('rechaza comentarios vacíos o sin puntuación', () {
      expect(
        ReviewValidator.validate(rating: 0, comment: ''),
        equals('Añade una puntuación y un comentario'),
      );
      expect(
        ReviewValidator.validate(
          rating: 0,
          comment: 'Sabor muy rico e intenso a menta',
        ),
        equals('Indica una puntuación para continuar'),
      );
      expect(
        ReviewValidator.validate(rating: 4, comment: '   '),
        equals('Escribe un comentario sobre tu experiencia'),
      );
    });

    test('rechaza textos triviales como puntos, signos o palabras sueltas', () {
      expect(ReviewValidator.validate(rating: 5, comment: '.'), isNotNull);
      expect(ReviewValidator.validate(rating: 5, comment: 'ok'), isNotNull);
      expect(
        ReviewValidator.validate(rating: 5, comment: '. . . . . . . . . .'),
        isNotNull,
      );
      expect(
        ReviewValidator.validate(
          rating: 5,
          comment: 'a b c d e f g h i j k l m n o p',
        ),
        isNotNull,
      );
    });

    test('rechaza reseñas con 5 palabras de 2 letras pero menos de 15 caracteres útiles', () {
      // 5 palabras válidas ("es", "un", "te", "de", "fe") = 10 caracteres alfanuméricos (< 15)
      final error = ReviewValidator.validate(
        rating: 4,
        comment: 'es un te de fe',
      );
      expect(error, isNotNull);
      expect(error, contains('15 caracteres útiles'));
    });

    test('acepta reseñas con al menos 5 palabras válidas y >= 15 caracteres útiles', () {
      final error = ReviewValidator.validate(
        rating: 4.5,
        comment: 'Muy buen sabor con humo denso',
      );
      expect(error, isNull);
    });

    test('evaluateProgress devuelve texto de ayuda dinámico en tiempo real', () {
      final p0 = ReviewValidator.evaluateProgress('');
      expect(p0.isValid, isFalse);
      expect(p0.helperText, equals('Mínimo 5 palabras (llevas 0)'));

      final p2 = ReviewValidator.evaluateProgress('Muy buen');
      expect(p2.isValid, isFalse);
      expect(p2.helperText, equals('Mínimo 5 palabras (llevas 2)'));

      final pValid = ReviewValidator.evaluateProgress(
        'Excelente tabaco con toque cítrico fresco',
      );
      expect(pValid.isValid, isTrue);
      expect(pValid.helperText, equals('Comentario válido (6 palabras)'));
    });

    test('sortWithUserReviewFirst fija la reseña del usuario en índice 0 y ordena el resto por fecha desc', () {
      final reviews = [
        Review(
          id: 'r-old-other',
          author: 'Ana',
          authorId: 'u-ana',
          rating: 4,
          comment: 'Comentario antiguo de otro usuario',
          createdAt: DateTime(2026, 1, 1),
        ),
        Review(
          id: 'r-mine-oldest',
          author: 'Yo',
          authorId: 'u-me',
          rating: 5,
          comment: 'Mi reseña publicada hace mucho tiempo',
          createdAt: DateTime(2025, 12, 1),
        ),
        Review(
          id: 'r-new-other',
          author: 'Luis',
          authorId: 'u-luis',
          rating: 3,
          comment: 'Comentario más reciente de otro usuario',
          createdAt: DateTime(2026, 2, 1),
        ),
      ];

      final sorted = ReviewValidator.sortWithUserReviewFirst(
        reviews,
        currentUserId: 'u-me',
      );

      expect(sorted.map((r) => r.id).toList(), [
        'r-mine-oldest',
        'r-new-other',
        'r-old-other',
      ]);
    });
  });
}

