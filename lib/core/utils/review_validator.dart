import '../models/review.dart';

/// Resultado detallado de la evaluación en tiempo real del comentario de una reseña.
class ReviewCommentProgress {
  const ReviewCommentProgress({
    required this.validWords,
    required this.usefulChars,
    required this.minWords,
    required this.minChars,
  });

  final int validWords;
  final int usefulChars;
  final int minWords;
  final int minChars;

  bool get hasEnoughWords => validWords >= minWords;
  bool get hasEnoughChars => usefulChars >= minChars;
  bool get isValid => hasEnoughWords && hasEnoughChars;

  /// Texto de ayuda dinámico para mostrar en tiempo real bajo el campo de comentario.
  String get helperText {
    if (!hasEnoughWords) {
      return 'Mínimo $minWords palabras (llevas $validWords)';
    }
    if (!hasEnoughChars) {
      return 'Mínimo $minChars caracteres útiles (llevas $usefulChars)';
    }
    return 'Comentario válido ($validWords palabras)';
  }
}

/// Validador centralizado de calidad, longitud y ordenación de reseñas
/// para Tabacos (`tobacco_reviews`) y Mezclas (`reviews`).
class ReviewValidator {
  const ReviewValidator._();

  /// Número mínimo de palabras válidas requeridas en una reseña.
  static const int minValidWords = 5;

  /// Número mínimo de caracteres alfanuméricos requeridos por palabra para ser válida.
  static const int minCharsPerWord = 2;

  /// Número mínimo de caracteres útiles (alfanuméricos) en el total del comentario.
  static const int minUsefulChars = 15;

  static final RegExp _alphanumericRegex = RegExp(
    r'[\p{L}\p{N}]',
    unicode: true,
  );

  static final RegExp _whitespaceSplitRegex = RegExp(r'\s+');

  /// Cuenta cuántas palabras válidas (con al menos [minCharsPerWord] caracteres
  /// alfanuméricos) contiene el texto.
  static int countValidWords(String comment) {
    final trimmed = comment.trim();
    if (trimmed.isEmpty) return 0;

    final tokens = trimmed.split(_whitespaceSplitRegex);
    var count = 0;
    for (final token in tokens) {
      final alphaCount = _alphanumericRegex.allMatches(token).length;
      if (alphaCount >= minCharsPerWord) {
        count++;
      }
    }
    return count;
  }

  /// Cuenta el total de caracteres útiles (alfanuméricos) ignorando espacios,
  /// signos de puntuación repetidos o caracteres triviales.
  static int countUsefulChars(String comment) {
    final trimmed = comment.trim();
    if (trimmed.isEmpty) return 0;
    return _alphanumericRegex.allMatches(trimmed).length;
  }

  /// Evalúa el progreso actual del comentario para alimentar la UI en tiempo real.
  static ReviewCommentProgress evaluateProgress(String comment) {
    return ReviewCommentProgress(
      validWords: countValidWords(comment),
      usefulChars: countUsefulChars(comment),
      minWords: minValidWords,
      minChars: minUsefulChars,
    );
  }

  /// Valida la puntuación y el comentario de una reseña antes de enviarla.
  /// Devuelve un mensaje de error en español si no cumple las reglas, o `null` si es válida.
  static String? validate({
    required double rating,
    required String comment,
  }) {
    final trimmed = comment.trim();
    final hasRating = rating > 0;
    final hasComment = trimmed.isNotEmpty;

    if (!hasRating && !hasComment) {
      return 'Añade una puntuación y un comentario';
    }
    if (!hasRating) {
      return 'Indica una puntuación para continuar';
    }
    if (!hasComment) {
      return 'Escribe un comentario sobre tu experiencia';
    }

    final progress = evaluateProgress(trimmed);
    if (!progress.hasEnoughWords) {
      return 'La reseña debe tener al menos $minValidWords palabras (llevas ${progress.validWords})';
    }
    if (!progress.hasEnoughChars) {
      return 'La reseña es demasiado corta (mínimo $minUsefulChars caracteres útiles)';
    }

    return null;
  }

  /// Ordena la lista de reseñas fijando en primera posición (índice 0) la reseña
  /// del usuario autenticado ([currentUserId]) y el resto por fecha descendente.
  static List<Review> sortWithUserReviewFirst(
    Iterable<Review> reviews, {
    required String? currentUserId,
  }) {
    final list = List<Review>.of(reviews);
    list.sort((a, b) {
      if (currentUserId != null && currentUserId.isNotEmpty) {
        final aIsMine = a.authorId != null && a.authorId == currentUserId;
        final bIsMine = b.authorId != null && b.authorId == currentUserId;
        if (aIsMine && !bIsMine) return -1;
        if (!aIsMine && bIsMine) return 1;
      }
      return b.createdAt.compareTo(a.createdAt);
    });
    return list;
  }

  /// Obtiene la reseña perteneciente a [currentUserId] si existe en la colección.
  static Review? findUserReview(
    Iterable<Review> reviews, {
    required String? currentUserId,
  }) {
    if (currentUserId == null || currentUserId.isEmpty) return null;
    for (final review in reviews) {
      if (review.authorId != null && review.authorId == currentUserId) {
        return review;
      }
    }
    return null;
  }
}

