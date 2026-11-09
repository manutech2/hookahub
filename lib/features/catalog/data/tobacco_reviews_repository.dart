import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants.dart';
import '../../../../core/models/review.dart';
import '../../../../core/utils/app_logger.dart';

class TobaccoReviewsRepository {
  TobaccoReviewsRepository(this._supabase);

  final SupabaseClient _supabase;

  /// Fetch reviews for a specific tobacco with limit and timeout
  Future<List<Review>> fetchReviews(String tobaccoId, {int limit = 50}) async {
    try {
      final List<dynamic> response = await _supabase
          .from('tobacco_reviews')
          .select('*, profiles:author_id(username, display_name, avatar_url)')
          .eq('tobacco_id', tobaccoId)
          .order('created_at', ascending: false)
          .limit(limit)
          .timeout(supabaseReadTimeout);

      return response.map((data) {
        final profile = data['profiles'] as Map<String, dynamic>?;
        final authorName = profile != null
            ? (profile['username'] ?? profile['display_name'] ?? 'Unknown')
            : 'Unknown';
        final authorAvatarUrl = profile != null
            ? profile['avatar_url'] as String?
            : null;

        return Review(
          id: data['id'] as String,
          author: authorName as String,
          authorId: data['author_id'] as String?,
          authorAvatarUrl: authorAvatarUrl,
          rating: (data['rating'] as num).toDouble(),
          comment: data['comment'] as String? ?? '',
          createdAt: DateTime.parse(data['created_at'] as String),
        );
      }).toList();
    } catch (e, stackTrace) {
      AppLogger.error(
        'Error al obtener reseñas de tabaco: $tobaccoId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Add a new review with timeout, uniqueness verification and error logging
  Future<void> addReview({
    required String tobaccoId,
    required String userId,
    required double rating,
    required String comment,
  }) async {
    try {
      final existingCount = await _supabase
          .from('tobacco_reviews')
          .count(CountOption.exact)
          .eq('tobacco_id', tobaccoId)
          .eq('author_id', userId)
          .timeout(supabaseReadTimeout);

      if (existingCount > 0) {
        throw StateError('Ya has publicado una reseña para este tabaco.');
      }

      await _supabase.from('tobacco_reviews').insert({
        'tobacco_id': tobaccoId,
        'author_id': userId,
        'rating': rating,
        'comment': comment,
      }).timeout(supabaseWriteTimeout);
    } catch (e, stackTrace) {
      AppLogger.error(
        'Error al publicar reseña de tabaco: $tobaccoId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Update an existing tobacco review with timeout and error logging
  Future<bool> updateReview({
    required String reviewId,
    required String tobaccoId,
    required double rating,
    required String comment,
  }) async {
    try {
      await _supabase
          .from('tobacco_reviews')
          .update({
            'rating': rating,
            'comment': comment,
          })
          .eq('id', reviewId)
          .timeout(supabaseWriteTimeout);
      return true;
    } catch (e, stackTrace) {
      AppLogger.error(
        'Error al actualizar reseña de tabaco: $reviewId (tabaco: $tobaccoId)',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// Delete a tobacco review by ID with timeout and error logging
  Future<bool> deleteReview({
    required String reviewId,
    required String tobaccoId,
  }) async {
    try {
      await _supabase
          .from('tobacco_reviews')
          .delete()
          .eq('id', reviewId)
          .timeout(supabaseWriteTimeout);
      return true;
    } catch (e, stackTrace) {
      AppLogger.error(
        'Error al eliminar reseña de tabaco: $reviewId (tabaco: $tobaccoId)',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }
}
