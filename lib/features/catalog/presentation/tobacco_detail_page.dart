import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/models/tobacco.dart';
import '../../../core/models/mix.dart';
import '../../../core/models/review.dart';
import '../../favorites/presentation/favorites_provider.dart';
import '../../../widgets/mix_card.dart';
import '../../../widgets/app_segmented_control.dart';
import '../../../widgets/tobacco_image.dart';
import '../../../widgets/user_avatar.dart';
import '../../community/presentation/community_provider.dart'; // Import provider
import 'providers/tobacco_mixes_provider.dart';
import '../../community/presentation/mix_detail_page.dart';
import '../data/tobacco_reviews_repository.dart';
import 'providers/tobacco_reviews_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/deep_link_service.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/app_toast.dart';
import '../../../core/utils/review_validator.dart';

class TobaccoDetailPage extends StatelessWidget {
  const TobaccoDetailPage({super.key, required this.tobacco});

  final Tobacco tobacco;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => TobaccoMixesProvider(
            context.read<CommunityProvider>().repository,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => TobaccoReviewsProvider(
            TobaccoReviewsRepository(Supabase.instance.client),
          ),
        ),
      ],
      child: _TobaccoDetailView(tobacco: tobacco),
    );
  }
}

class _TobaccoDetailView extends StatefulWidget {
  const _TobaccoDetailView({required this.tobacco});

  final Tobacco tobacco;

  @override
  State<_TobaccoDetailView> createState() => _TobaccoDetailViewState();
}

class _TobaccoDetailViewState extends State<_TobaccoDetailView> {
  // 0 => Mezclas, 1 => Reseñas
  int _segment = 0;

  // Datos de ejemplo para reseñas (se mantienen hardcoded por ahora según plan,
  // el foco es arreglar mixes)

  // Controladores
  final _reviewController = TextEditingController();
  final _scrollController = ScrollController();
  double _newRating = 0;

  // Formatea la descripción: todo en minúsculas excepto la primera letra.
  String _prettyDescription(String? text) {
    if (text == null) return 'Sin descripción';
    final trimmed = text.trim();
    if (trimmed.isEmpty) return 'Sin descripción';
    final lower = trimmed.toLowerCase();
    return lower[0].toUpperCase() + lower.substring(1);
  }

  @override
  void initState() {
    super.initState();
    // Cargar mezclas reales
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TobaccoMixesProvider>().loadMixes(
        tobaccoName: widget.tobacco.name,
        tobaccoBrand: widget.tobacco.brand,
      );
    });

    // Listener para paginación
    _scrollController.addListener(_onScroll);

    // Cargar reseñas reales
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TobaccoReviewsProvider>().loadReviews(widget.tobacco.id);
    });

    // Sincronizar favoritos si aún no han cargado
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final fav = context.read<FavoritesProvider>();
      if (!fav.isLoaded && !fav.isLoading) {
        fav.load();
      }
    });
  }

  void _onScroll() {
    if (_segment != 0) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context.read<TobaccoMixesProvider>().loadMore();
    }
  }

  @override
  void dispose() {
    _reviewController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final headerHeight = media.size.height / 3; // tercio de pantalla

    return Scaffold(
      // Sin AppBar: elimina completamente la barra de navegación superior
      extendBodyBehindAppBar: true,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverToBoxAdapter(
            child: _Header(
              tobacco: widget.tobacco,
              height: headerHeight,
              onBack: () => Navigator.of(context).pop(),
              onShare: _handleShare,
            ),
          ),
          // Descripción (sección "Sabores")
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  // Igual que MixCard: fondo tintado y borde con el color base (corazón)
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.05),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).primaryColor.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Acento superior sutil para un acabado elegante
                    Container(
                      width: 40,
                      height: 3,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        gradient: LinearGradient(
                          // Degradado partiendo del color del "corazón" (mismo que MixCard)
                          colors: [
                            Theme.of(context).primaryColor,
                            Theme.of(
                              context,
                            ).primaryColor.withValues(alpha: 0.5),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Sabores',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _prettyDescription(widget.tobacco.description),
                      style: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.copyWith(height: 1.5),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Segmento Mezclas/Reseñas
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: AppSegmentedControl(
                segments: const ['Mezclas', 'Reseñas'],
                currentIndex: _segment,
                onChanged: (i) => setState(() => _segment = i),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
          if (_segment == 0)
            _buildMixesSliver(context)
          else
            _buildReviewsSliver(context),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  // Mezclas de la comunidad que usan este tabaco (Reales)
  Widget _buildMixesSliver(BuildContext context) {
    return Consumer<TobaccoMixesProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading && provider.mixes.isEmpty) {
          return const SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: CircularProgressIndicator(),
              ),
            ),
          );
        }

        if (provider.error != null && provider.mixes.isEmpty) {
          return SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Text(
                  'Error al cargar mezclas',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ),
          );
        }

        if (provider.mixes.isEmpty) {
          return SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  children: [
                    Icon(
                      Icons.science_outlined,
                      size: 48,
                      color: Theme.of(context).disabledColor,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No hay mezclas con este tabaco aún',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).disabledColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList.separated(
            itemCount: provider.mixes.length + (provider.hasMoreData ? 1 : 0),
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              if (index >= provider.mixes.length) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 16.0),
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                  ),
                );
              }

              final m = provider.mixes[index];
              return _TobaccoMixCard(mix: m);
            },
          ),
        );
      },
    );
  }

  // Reseñas: estadísticas, formulario y lista
  Widget _buildReviewsSliver(BuildContext context) {
    return Consumer<TobaccoReviewsProvider>(
      builder: (context, provider, child) {
        final reviews = provider.reviews;
        final hasUserReviewed = provider.hasUserReviewed;
        final currentUserId = provider.currentUserId;

        if (provider.isLoading && reviews.isEmpty) {
          return const SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: CircularProgressIndicator(),
              ),
            ),
          );
        }

        // Si no hay reviews y no está cargando
        if (reviews.isEmpty && !provider.isLoading) {
          return SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _ReviewStats(average: 0, total: 0),
                const SizedBox(height: 16),
                _ReviewForm(
                  controller: _reviewController,
                  rating: _newRating,
                  onRatingChanged: (v) => setState(() => _newRating = v),
                  onSubmit: _handleSubmitReview,
                ),
                const SizedBox(height: 32),
                Center(
                  child: Text(
                    'Sé el primero en valorar este tabaco',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).disabledColor,
                    ),
                  ),
                ),
              ]),
            ),
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverMainAxisGroup(
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ReviewStats(
                      average: provider.averageRating,
                      total: provider.reviewCount,
                    ),
                    const SizedBox(height: 16),
                    if (!hasUserReviewed) ...[
                      _ReviewForm(
                        controller: _reviewController,
                        rating: _newRating,
                        onRatingChanged: (v) => setState(() => _newRating = v),
                        onSubmit: _handleSubmitReview,
                      ),
                      const SizedBox(height: 16),
                    ],
                  ],
                ),
              ),
              SliverList.builder(
                itemCount: reviews.length,
                itemBuilder: (context, index) {
                  final r = reviews[index];
                  return _ReviewTile(
                    key: ValueKey(r.id),
                    review: r,
                    isMyReview:
                        currentUserId != null && currentUserId == r.authorId,
                    onEdit: () => _handleEditReview(r),
                    onDelete: () => _handleDeleteReview(r.id),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _handleShare() {
    final t = widget.tobacco;
    final text =
        '¡Echa un vistazo a ${t.brand} - ${t.name} en Hookahub!\n${DeepLinkService.buildTobaccoShareUrl(t.id)}';
    SharePlus.instance.share(ShareParams(text: text));
  }

  void _handleSubmitReview() async {
    final provider = context.read<TobaccoReviewsProvider>();
    if (provider.hasUserReviewed) {
      AppToast.showWarning(
        context,
        'Ya has publicado una reseña para este tabaco',
      );
      return;
    }

    final validationError = ReviewValidator.validate(
      rating: _newRating,
      comment: _reviewController.text,
    );
    if (validationError != null) {
      AppToast.showWarning(context, validationError);
      return;
    }

    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) {
      AppToast.showInfo(context, 'Debes iniciar sesión para reseñar');
      return;
    }

    try {
      await provider.addReview(
        userId: user.id,
        rating: _newRating,
        comment: _reviewController.text.trim(),
      );

      // Limpiar formulario
      setState(() {
        _reviewController.clear();
        _newRating = 0;
      });

      if (mounted) {
        FocusScope.of(context).unfocus();
        AppToast.showSuccess(context, 'Reseña publicada');
      }
    } catch (e, stackTrace) {
      AppLogger.error(
        'Error al publicar reseña en TobaccoDetailPage',
        error: e,
        stackTrace: stackTrace,
      );
      if (mounted) {
        AppToast.showError(context, 'Error al publicar reseña');
      }
    }
  }

  void _handleEditReview(Review review) {
    final provider = context.read<TobaccoReviewsProvider>();
    showDialog<bool>(
      context: context,
      builder: (dialogContext) => _EditReviewDialog(
        initialRating: review.rating,
        initialComment: review.comment,
        onSave: (rating, comment) async {
          final success = await provider.updateReview(
            reviewId: review.id,
            rating: rating,
            comment: comment,
          );
          if (!mounted || !context.mounted) return false;

          if (success) {
            AppToast.showSuccess(context, 'Reseña actualizada');
            return true;
          } else {
            AppToast.showError(context, 'Error al actualizar reseña');
            return false;
          }
        },
      ),
    );
  }

  Future<void> _handleDeleteReview(String reviewId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar reseña'),
        content: const Text(
          '¿Estás seguro de que quieres eliminar esta reseña?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      if (!mounted) return;
      final provider = context.read<TobaccoReviewsProvider>();
      final success = await provider.deleteReview(reviewId);
      if (!mounted || !context.mounted) return;

      if (success) {
        AppToast.showSuccess(context, 'Reseña eliminada');
      } else {
        AppToast.showError(context, 'Error al eliminar reseña');
      }
    } catch (e, stackTrace) {
      AppLogger.error(
        'Error al eliminar reseña de tabaco',
        error: e,
        stackTrace: stackTrace,
      );
      if (mounted && context.mounted) {
        AppToast.showError(context, 'Error al eliminar reseña');
      }
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.tobacco,
    required this.height,
    required this.onBack,
    required this.onShare,
  });

  final Tobacco tobacco;
  final double height;
  final VoidCallback onBack;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final brandStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: Colors.white.withValues(alpha: 0.9),
      letterSpacing: 0.5,
    );
    final nameStyle = Theme.of(context).textTheme.headlineSmall?.copyWith(
      color: Colors.white,
      fontWeight: FontWeight.bold,
      shadows: const [Shadow(color: Colors.black26, blurRadius: 6)],
    );

    return Stack(
      children: [
        // Imagen de fondo con caché optimizado
        TobaccoImage(
          imageUrl: tobacco.imageUrl,
          width: double.infinity,
          height: height,
          borderRadius: 0,
          placeholderColor:
              tobacco.placeholderColor ?? Theme.of(context).primaryColor,
          fit: BoxFit.cover,
        ),
        // Gradiente para legibilidad
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.35),
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.45),
                ],
              ),
            ),
          ),
        ),
        // Flecha atrás (arriba izquierda)
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _CircleButton(icon: Icons.arrow_back, onTap: onBack),
                _CircleButton(icon: Icons.share, onTap: onShare),
              ],
            ),
          ),
        ),
        // Marca y nombre (abajo izquierda)
        Positioned(
          left: 16,
          bottom: 16,
          right: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tobacco.brand, style: brandStyle),
              const SizedBox(height: 4),
              Text(
                tobacco.name,
                style: nameStyle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.35),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24),
        ),
        child: Icon(icon, color: Colors.white),
      ),
    );
  }
}

// Reemplazado _Segmented por AppSegmentedControl reutilizable.

class _ReviewStats extends StatelessWidget {
  const _ReviewStats({required this.average, required this.total});
  final double average;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).primaryColor.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.star, color: Theme.of(context).primaryColor),
          const SizedBox(width: 8),
          Text(
            average.toStringAsFixed(1),
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          Text(
            '($total reseñas)',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(
                context,
              ).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewForm extends StatelessWidget {
  const _ReviewForm({
    required this.controller,
    required this.rating,
    required this.onRatingChanged,
    required this.onSubmit,
  });
  final TextEditingController controller;
  final double rating;
  final ValueChanged<double> onRatingChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Escribe una reseña',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          _StarInput(value: rating, onChanged: onRatingChanged),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Comparte tu experiencia... ',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 8),
          _ReviewWordCounter(controller: controller),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: onSubmit,
              icon: const Icon(Icons.send),
              label: const Text('Publicar'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewWordCounter extends StatelessWidget {
  const _ReviewWordCounter({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final progress = ReviewValidator.evaluateProgress(value.text);
        final isValid = progress.isValid;
        final color = isValid
            ? Theme.of(context).primaryColor
            : Theme.of(
                context,
              ).textTheme.bodySmall?.color?.withValues(alpha: 0.7);

        return Row(
          children: [
            Icon(
              isValid ? Icons.check_circle_outline : Icons.info_outline,
              size: 16,
              color: color,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                progress.helperText,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: isValid ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StarInput extends StatelessWidget {
  const _StarInput({required this.value, required this.onChanged});
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(5, (i) {
        final filled = i < value.round();
        return IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          icon: Icon(
            filled ? Icons.star : Icons.star_border,
            color: Theme.of(context).primaryColor,
          ),
          onPressed: () => onChanged((i + 1).toDouble()),
        );
      }),
    );
  }
}

class _EditReviewDialog extends StatefulWidget {
  const _EditReviewDialog({
    required this.initialRating,
    required this.initialComment,
    required this.onSave,
  });

  final double initialRating;
  final String initialComment;
  final Future<bool> Function(double rating, String comment) onSave;

  @override
  State<_EditReviewDialog> createState() => _EditReviewDialogState();
}

class _EditReviewDialogState extends State<_EditReviewDialog> {
  late double _rating;
  late final TextEditingController _controller;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _rating = widget.initialRating;
    _controller = TextEditingController(text: widget.initialComment);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar reseña'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StarInput(
              value: _rating,
              onChanged: (v) {
                if (_isSaving) return;
                setState(() => _rating = v);
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              enabled: !_isSaving,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Comparte tu experiencia...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 8),
            _ReviewWordCounter(controller: _controller),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: _isSaving
              ? null
              : () async {
                  final text = _controller.text.trim();
                  final validationError = ReviewValidator.validate(
                    rating: _rating,
                    comment: text,
                  );
                  if (validationError != null) {
                    AppToast.showWarning(context, validationError);
                    return;
                  }

                  setState(() => _isSaving = true);
                  final success = await widget.onSave(_rating, text);

                  if (!context.mounted) return;
                  if (success) {
                    Navigator.of(context).pop(true);
                  } else {
                    setState(() => _isSaving = false);
                  }
                },
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Guardar'),
        ),
      ],
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({
    super.key,
    required this.review,
    required this.isMyReview,
    required this.onEdit,
    required this.onDelete,
  });

  final Review review;
  final bool isMyReview;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: isMyReview ? 0.09 : 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: primaryColor.withValues(alpha: isMyReview ? 0.45 : 0.12),
          width: isMyReview ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              UserAvatar(
                username: review.author,
                avatarUrl: review.authorAvatarUrl,
                radius: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            review.author,
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isMyReview) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: primaryColor.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.push_pin_rounded,
                                  size: 12,
                                  color: primaryColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Tu reseña',
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color: primaryColor,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    Row(
                      children: List.generate(
                        5,
                        (i) => Icon(
                          i < review.rating.round()
                              ? Icons.star
                              : Icons.star_border,
                          size: 16,
                          color: primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                _timeAgo(review.createdAt),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(
                    context,
                  ).textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(review.comment),
          if (isMyReview) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Editar'),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: onDelete,
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text('Eliminar'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays >= 1) return '${diff.inDays}d';
    if (diff.inHours >= 1) return '${diff.inHours}h';
    if (diff.inMinutes >= 1) return '${diff.inMinutes}m';
    return 'ahora';
  }
}

class _TobaccoMixCard extends StatelessWidget {
  const _TobaccoMixCard({required this.mix});

  final Mix mix;

  @override
  Widget build(BuildContext context) {
    final isFavorite = context.select<FavoritesProvider, bool>(
      (fav) => fav.favorites.any((m) => m.id == mix.id),
    );

    return MixCard(
      mix: mix,
      isFavorite: isFavorite,
      onFavoriteTap: () async {
        final fav = context.read<FavoritesProvider>();
        if (isFavorite) {
          await fav.removeFavorite(mix.id);
        } else {
          await fav.addFavorite(mix);
        }
      },
      onShare: () => SharePlus.instance.share(
        ShareParams(
          text:
              '¡Descubre la mezcla "${mix.name}" por ${mix.author} en Hookahub!\n${DeepLinkService.buildMixShareUrl(mix.id)}',
        ),
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => MixDetailPage(mix: mix)),
        );
      },
    );
  }
}
