import 'package:hookahub/core/utils/app_logger.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/models/review.dart';
import '../../../../core/utils/review_validator.dart';
import '../../data/tobacco_reviews_repository.dart';

// ---------------------------------------------------------------------------
// Estados UI (sealed class — sin booleanos fragmentados)
// ---------------------------------------------------------------------------

sealed class TobaccoReviewsState {
  const TobaccoReviewsState();
}

/// Estado inicial previo a la carga.
class TobaccoReviewsInitial extends TobaccoReviewsState {
  const TobaccoReviewsInitial();
}

/// Carga de reseñas en progreso.
class TobaccoReviewsLoading extends TobaccoReviewsState {
  const TobaccoReviewsLoading();
}

/// Reseñas cargadas con éxito.
class TobaccoReviewsLoaded extends TobaccoReviewsState {
  const TobaccoReviewsLoaded(this.reviews);
  final List<Review> reviews;
}

/// Error al cargar o enviar reseñas.
class TobaccoReviewsError extends TobaccoReviewsState {
  const TobaccoReviewsError(this.message);
  final String message;
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

class TobaccoReviewsProvider extends ChangeNotifier {
  TobaccoReviewsProvider(this._repository, {String? currentUserId})
    : _currentUserId = currentUserId;

  final TobaccoReviewsRepository _repository;

  TobaccoReviewsState _state = const TobaccoReviewsInitial();
  List<Review> _cachedReviews = const [];

  // Cache the tobacco ID to allow refreshing seamlessly
  String? _tobaccoId;
  String? _currentUserId;

  String? get currentUserId {
    if (_currentUserId != null) return _currentUserId;
    try {
      return Supabase.instance.client.auth.currentUser?.id;
    } catch (_) {
      return null;
    }
  }

  TobaccoReviewsState get state => _state;

  List<Review> get reviews => switch (_state) {
        TobaccoReviewsLoaded(:final reviews) => reviews,
        _ => _cachedReviews,
      };

  /// Reseña perteneciente al usuario autenticado actual, o `null` si aún no ha opinado.
  Review? get userReview => ReviewValidator.findUserReview(
        reviews,
        currentUserId: currentUserId,
      );

  /// Indica si el usuario autenticado ya tiene una reseña publicada en este tabaco.
  bool get hasUserReviewed => userReview != null;

  bool get isLoading => _state is TobaccoReviewsLoading;

  String? get error => switch (_state) {
        TobaccoReviewsError(:final message) => message,
        _ => null,
      };

  double get averageRating {
    final list = reviews;
    if (list.isEmpty) return 0.0;
    final total = list.fold(0.0, (sum, r) => sum + r.rating);
    return total / list.length;
  }

  int get reviewCount => reviews.length;

  Future<void> loadReviews(String tobaccoId, {String? currentUserId}) async {
    _tobaccoId = tobaccoId;
    if (currentUserId != null) {
      _currentUserId = currentUserId;
    }
    _state = const TobaccoReviewsLoading();
    notifyListeners();

    try {
      final fetched = await _repository.fetchReviews(tobaccoId);
      final sorted = ReviewValidator.sortWithUserReviewFirst(
        fetched,
        currentUserId: this.currentUserId,
      );
      _cachedReviews = sorted;
      _state = TobaccoReviewsLoaded(sorted);
    } catch (e, stackTrace) {
      _state = const TobaccoReviewsError('Error al cargar las reseñas');
      AppLogger.error(
        'Error loading tobacco reviews',
        error: e,
        stackTrace: stackTrace,
      );
    } finally {
      notifyListeners();
    }
  }

  Future<void> addReview({
    required String userId,
    required double rating,
    required String comment,
  }) async {
    if (_tobaccoId == null) return;
    _currentUserId = userId;

    if (hasUserReviewed) {
      throw StateError('Ya has publicado una reseña para este tabaco.');
    }

    try {
      await _repository.addReview(
        tobaccoId: _tobaccoId!,
        userId: userId,
        rating: rating,
        comment: comment,
      );
      // Reload to get the updated list and server-side timestamp
      await loadReviews(_tobaccoId!, currentUserId: userId);
    } catch (e, stackTrace) {
      AppLogger.error('Error adding review', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<bool> updateReview({
    required String reviewId,
    required double rating,
    required String comment,
  }) async {
    if (_tobaccoId == null) return false;

    try {
      final success = await _repository.updateReview(
        reviewId: reviewId,
        tobaccoId: _tobaccoId!,
        rating: rating,
        comment: comment,
      );
      if (success) {
        await loadReviews(_tobaccoId!, currentUserId: _currentUserId);
      }
      return success;
    } catch (e, stackTrace) {
      AppLogger.error(
        'Error updating tobacco review',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  Future<bool> deleteReview(String reviewId) async {
    if (_tobaccoId == null) return false;

    try {
      final success = await _repository.deleteReview(
        reviewId: reviewId,
        tobaccoId: _tobaccoId!,
      );
      if (success) {
        await loadReviews(_tobaccoId!, currentUserId: _currentUserId);
      }
      return success;
    } catch (e, stackTrace) {
      AppLogger.error(
        'Error deleting tobacco review',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }
}
