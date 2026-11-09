import 'package:flutter_test/flutter_test.dart';
import 'package:hookahub/core/models/review.dart';
import 'package:hookahub/features/catalog/data/tobacco_reviews_repository.dart';
import 'package:hookahub/features/catalog/presentation/providers/tobacco_reviews_provider.dart';

class FakeTobaccoReviewsRepository implements TobaccoReviewsRepository {
  FakeTobaccoReviewsRepository({this.shouldThrow = false});

  bool shouldThrow;
  final List<Review> mockReviews = [
    Review(
      id: 'rev-1',
      author: 'User1',
      authorId: 'user-1',
      rating: 4.5,
      comment: 'Muy buen sabor a menta fresca e intensa',
      createdAt: DateTime(2026, 1, 1),
    ),
    Review(
      id: 'rev-2',
      author: 'User2',
      authorId: 'user-2',
      rating: 3.5,
      comment: 'Sabor aceptable pero dura poco tiempo',
      createdAt: DateTime(2026, 1, 2),
    ),
  ];

  @override
  Future<List<Review>> fetchReviews(String tobaccoId, {int limit = 50}) async {
    if (shouldThrow) {
      throw Exception('Database query timeout');
    }
    return List<Review>.of(mockReviews);
  }

  @override
  Future<void> addReview({
    required String tobaccoId,
    required String userId,
    required double rating,
    required String comment,
  }) async {
    if (shouldThrow) {
      throw Exception('Database write error');
    }
    mockReviews.insert(
      0,
      Review(
        id: 'rev-new',
        author: 'Me',
        authorId: userId,
        rating: rating,
        comment: comment,
        createdAt: DateTime(2026, 1, 3),
      ),
    );
  }

  @override
  Future<bool> updateReview({
    required String reviewId,
    required String tobaccoId,
    required double rating,
    required String comment,
  }) async {
    if (shouldThrow) return false;
    final idx = mockReviews.indexWhere((r) => r.id == reviewId);
    if (idx == -1) return false;
    mockReviews[idx] = mockReviews[idx].copyWith(
      rating: rating,
      comment: comment,
    );
    return true;
  }

  @override
  Future<bool> deleteReview({
    required String reviewId,
    required String tobaccoId,
  }) async {
    if (shouldThrow) return false;
    mockReviews.removeWhere((r) => r.id == reviewId);
    return true;
  }
}

void main() {
  group('TobaccoReviewsProvider Sealed State Transitions', () {
    test('Inicia en TobaccoReviewsInitial con estado consistente', () {
      final fakeRepo = FakeTobaccoReviewsRepository();
      final provider = TobaccoReviewsProvider(fakeRepo);

      expect(provider.state, isA<TobaccoReviewsInitial>());
      expect(provider.isLoading, isFalse);
      expect(provider.error, isNull);
      expect(provider.reviews, isEmpty);
      expect(provider.reviewCount, equals(0));
      expect(provider.averageRating, equals(0.0));
    });

    test('loadReviews transita a Loading y luego a Loaded con datos correctos', () async {
      final fakeRepo = FakeTobaccoReviewsRepository();
      final provider = TobaccoReviewsProvider(fakeRepo);

      final future = provider.loadReviews('tobacco-123');

      expect(provider.state, isA<TobaccoReviewsLoading>());
      expect(provider.isLoading, isTrue);

      await future;

      expect(provider.state, isA<TobaccoReviewsLoaded>());
      expect(provider.isLoading, isFalse);
      expect(provider.error, isNull);
      expect(provider.reviews.length, equals(2));
      expect(provider.reviewCount, equals(2));
      expect(provider.averageRating, equals(4.0));
    });

    test('loadReviews con error transita a TobaccoReviewsError', () async {
      final fakeRepo = FakeTobaccoReviewsRepository(shouldThrow: true);
      final provider = TobaccoReviewsProvider(fakeRepo);

      await provider.loadReviews('tobacco-123');

      expect(provider.state, isA<TobaccoReviewsError>());
      expect(provider.isLoading, isFalse);
      expect(provider.error, isNotNull);
      expect(provider.reviews, isEmpty);
    });

    test('addReview añade reseña y recarga lista', () async {
      final fakeRepo = FakeTobaccoReviewsRepository();
      final provider = TobaccoReviewsProvider(fakeRepo);

      await provider.loadReviews('tobacco-123');
      expect(provider.reviews.length, equals(2));

      await provider.addReview(
        userId: 'user-xyz',
        rating: 5.0,
        comment: 'Excelente sabor con humo muy denso',
      );

      expect(provider.state, isA<TobaccoReviewsLoaded>());
      expect(provider.reviews.length, equals(3));
      expect(provider.reviewCount, equals(3));
      expect(provider.hasUserReviewed, isTrue);
      expect(provider.reviews.first.authorId, equals('user-xyz'));
    });

    test('fija la reseña del usuario actual en primera posición aunque sea más antigua', () async {
      final fakeRepo = FakeTobaccoReviewsRepository();
      final provider = TobaccoReviewsProvider(
        fakeRepo,
        currentUserId: 'user-1',
      );

      await provider.loadReviews('tobacco-123');

      expect(provider.hasUserReviewed, isTrue);
      expect(provider.userReview?.id, equals('rev-1'));
      expect(provider.reviews.first.id, equals('rev-1'));
      expect(provider.reviews.last.id, equals('rev-2'));
    });

    test('updateReview y deleteReview actualizan estado y recalculan estadísticas', () async {
      final fakeRepo = FakeTobaccoReviewsRepository();
      final provider = TobaccoReviewsProvider(
        fakeRepo,
        currentUserId: 'user-1',
      );

      await provider.loadReviews('tobacco-123');
      expect(provider.hasUserReviewed, isTrue);

      final updated = await provider.updateReview(
        reviewId: 'rev-1',
        rating: 2.5,
        comment: 'Cambio mi opinión tras varias cazoletas',
      );
      expect(updated, isTrue);
      expect(provider.userReview?.rating, equals(2.5));
      expect(provider.averageRating, equals(3.0));

      final deleted = await provider.deleteReview('rev-1');
      expect(deleted, isTrue);
      expect(provider.hasUserReviewed, isFalse);
      expect(provider.reviewCount, equals(1));
    });
  });
}
