import 'package:hookahub/core/utils/app_logger.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants.dart';
import '../../../core/data/supabase_service.dart';
import '../../../core/models/mix.dart';

/// Repositorio para gestionar las mezclas de la comunidad desde Supabase.
class CommunityRepository {
  CommunityRepository(this._supabase);

  final SupabaseService _supabase;

  /// Obtiene una mezcla específica por su ID con todos sus detalles.
  /// Útil cuando se navega desde notificaciones o enlaces directos.
  Future<Mix?> fetchMixById(String mixId) async {
    try {
      final response = await _supabase.client
          .from('mixes')
          .select('''
            id,
            name,
            description,
            rating,
            reviews,
            reviews_real:reviews(count),
            created_at,
            profiles!mixes_author_id_fkey(username, display_name, avatar_url),
            mix_components(tobacco_name, brand, percentage, color)
          ''')
          .eq('id', mixId)
          .single()
          .timeout(supabaseReadTimeout);

      // Extraer componentes/ingredientes
      final components = response['mix_components'] as List? ?? [];
      final ingredients = components
          .map((c) => c['tobacco_name'] as String)
          .toList();

      // Usar el primer color de los componentes o un color por defecto
      Color mixColor = const Color(0xFF72C8C1);
      if (components.isNotEmpty && components[0]['color'] != null) {
        final colorStr = components[0]['color'] as String;
        if (colorStr.startsWith('#') && colorStr.length == 7) {
          mixColor = Color(
            int.parse(colorStr.substring(1), radix: 16) + 0xFF000000,
          );
        }
      }

      // Extraer autor
      final profile = response['profiles'];
      final authorName = profile != null
          ? (profile['username'] as String? ?? 'Anónimo')
          : 'Anónimo';
      final authorAvatarUrl = profile != null
          ? profile['avatar_url'] as String?
          : null;

      return Mix(
        id: response['id'] as String,
        name: response['name'] as String,
        author: authorName,
        rating: (response['rating'] as num?)?.toDouble() ?? 0.0,

        reviews:
            (response['reviews_real'] as List?)?.firstOrNull?['count']
                as int? ??
            (response['reviews'] as num?)?.toInt() ??
            0,
        ingredients: ingredients,
        color: mixColor,
        authorAvatarUrl: authorAvatarUrl,
      );
    } catch (e, stackTrace) {
      AppLogger.error('Error al obtener mezcla por ID', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// Obtiene las mezclas de la comunidad con filtros opcionales.
  ///
  /// [orderBy] puede ser:
  /// - 'popular': ordenar por rating descendente
  /// - 'recent': ordenar por fecha de creación descendente
  /// - 'top_rated': ordenar por rating y número de reviews
  ///
  /// [limit] cantidad de mezclas a obtener
  /// [offset] desde qué posición empezar (para paginación)
  /// [query] búsqueda por texto en nombre, descripción o componentes (tabaco)
  Future<List<Mix>> fetchMixes({
    String orderBy = 'recent',
    int limit = 20,
    int offset = 0,
    String? tobaccoName,
    String? tobaccoBrand,
    String? query,
  }) async {
    try {
      final bool filterByTobacco =
          (tobaccoName != null && tobaccoName.isNotEmpty);
      final bool hasQuery = (query != null && query.trim().isNotEmpty);

      List<dynamic> response;
      List<String> targetIds = [];

      if (hasQuery) {
        final q = query.trim();
        // 1. Resolver IDs en paralelo por nombre/descripción de mezcla y por componente (acotado para evitar URI Too Long)
        final idResults = await Future.wait([
          _supabase.client
              .from('mixes')
              .select('id')
              .or('name.ilike.%$q%,description.ilike.%$q%')
              .limit(200)
              .timeout(supabaseReadTimeout),
          _supabase.client
              .from('mix_components')
              .select('mix_id')
              .ilike('tobacco_name', '%$q%')
              .limit(200)
              .timeout(supabaseReadTimeout),
        ]);

        final mixIdsFromMixes =
            (idResults[0] as List).map((r) => r['id'] as String);
        final mixIdsFromComponents =
            (idResults[1] as List).map((r) => r['mix_id'] as String);

        Set<String> targetIdSet = {...mixIdsFromMixes, ...mixIdsFromComponents};

        // Si adicionalmente hay filtro específico por tabaco
        if (filterByTobacco) {
          dynamic idQuery = _supabase.client
              .from('mixes')
              .select('id, mix_components!inner(tobacco_name, brand)');

          idQuery = idQuery.eq('mix_components.tobacco_name', tobaccoName);
          if (tobaccoBrand != null && tobaccoBrand.isNotEmpty) {
            idQuery = idQuery.eq('mix_components.brand', tobaccoBrand);
          }
          final tobaccoFilterResults =
              await idQuery.timeout(supabaseReadTimeout);
          final tobaccoMixIds = (tobaccoFilterResults as List)
              .map((row) => (row as Map<String, dynamic>)['id'] as String)
              .toSet();
          targetIdSet = targetIdSet.intersection(tobaccoMixIds);
        }

        if (targetIdSet.isEmpty) {
          return [];
        }

        // 2. Traer los mixes completos con TODOS sus componentes intactos
        dynamic request = _supabase.client.from('mixes').select('''
              id,
              name,
              description,
              rating,
              reviews,
              created_at,
              profiles!mixes_author_id_fkey(username, display_name, avatar_url),
              reviews_real:reviews(count),
              mix_components(tobacco_name, brand, percentage, color)
            ''').inFilter('id', targetIdSet.toList());

        switch (orderBy) {
          case 'recent':
            request = request.order('created_at', ascending: false);
            break;
          case 'recent_asc':
            request = request.order('created_at', ascending: true);
            break;
          case 'name_asc':
            request = request.order('name', ascending: true);
            break;
          case 'name_desc':
            request = request.order('name', ascending: false);
            break;
          case 'popular':
          case 'top_rated':
            request = request
                .order('rating', ascending: false)
                .order('reviews', ascending: false);
            break;
          default:
            request = request.order('created_at', ascending: false);
        }

        response = await request
            .range(offset, offset + limit - 1)
            .timeout(supabaseReadTimeout);
      } else if (filterByTobacco) {
        dynamic idQuery = _supabase.client
            .from('mixes')
            .select('id, mix_components!inner(tobacco_name, brand)');

        idQuery = idQuery.eq('mix_components.tobacco_name', tobaccoName);
        if (tobaccoBrand != null && tobaccoBrand.isNotEmpty) {
          idQuery = idQuery.eq('mix_components.brand', tobaccoBrand);
        }

        // Aplicar el mismo orden a la consulta de IDs
        switch (orderBy) {
          case 'recent':
            idQuery = idQuery.order('created_at', ascending: false);
            break;
          case 'recent_asc':
            idQuery = idQuery.order('created_at', ascending: true);
            break;
          case 'name_asc':
            idQuery = idQuery.order('name', ascending: true);
            break;
          case 'name_desc':
            idQuery = idQuery.order('name', ascending: false);
            break;
          case 'popular':
          case 'top_rated':
            idQuery = idQuery
                .order('rating', ascending: false)
                .order('reviews', ascending: false);
            break;
          default:
            idQuery = idQuery.order('created_at', ascending: false);
        }

        final List dataIds = await idQuery
            .range(offset, offset + limit - 1)
            .timeout(supabaseReadTimeout);
        targetIds = dataIds
            .map((row) => (row as Map<String, dynamic>)['id'] as String)
            .toList();
        if (targetIds.isEmpty) {
          return [];
        }

        // Segunda consulta: traer mixes completos con todos los componentes
        dynamic request = _supabase.client
            .from('mixes')
            .select('''
              id,
              name,
              description,
              rating,
              reviews,
              reviews_real:reviews(count),
              created_at,
              profiles!mixes_author_id_fkey(username, display_name, avatar_url),
              mix_components(tobacco_name, brand, percentage, color)
            ''')
            .inFilter('id', targetIds);

        // Reaplicar orden para consistencia
        switch (orderBy) {
          case 'recent':
            request = request.order('created_at', ascending: false);
            break;
          case 'recent_asc':
            request = request.order('created_at', ascending: true);
            break;
          case 'name_asc':
            request = request.order('name', ascending: true);
            break;
          case 'name_desc':
            request = request.order('name', ascending: false);
            break;
          case 'popular':
          case 'top_rated':
            request = request
                .order('rating', ascending: false)
                .order('reviews', ascending: false);
            break;
          default:
            request = request.order('created_at', ascending: false);
        }

        response = await request.timeout(supabaseReadTimeout);
      } else {
        // Sin filtro por tabaco: consulta directa con todos los componentes
        dynamic request = _supabase.client.from('mixes').select('''
              id,
              name,
              description,
              rating,
              reviews,
              created_at,
              profiles!mixes_author_id_fkey(username, display_name, avatar_url),
              reviews_real:reviews(count),
              mix_components(tobacco_name, brand, percentage, color)
            ''');

        switch (orderBy) {
          case 'recent':
            request = request.order('created_at', ascending: false);
            break;
          case 'recent_asc':
            request = request.order('created_at', ascending: true);
            break;
          case 'name_asc':
            request = request.order('name', ascending: true);
            break;
          case 'name_desc':
            request = request.order('name', ascending: false);
            break;
          case 'popular':
          case 'top_rated':
            request = request
                .order('rating', ascending: false)
                .order('reviews', ascending: false);
            break;
          default:
            request = request.order('created_at', ascending: false);
        }

        response = await request
            .range(offset, offset + limit - 1)
            .timeout(supabaseReadTimeout);
      }

      return response.map((mixData) {
        // Extraer componentes/ingredientes
        final components = mixData['mix_components'] as List? ?? [];
        final ingredients = components
            .map((c) => c['tobacco_name'] as String)
            .toList();

        // Usar el primer color de los componentes o un color por defecto
        Color mixColor = const Color(0xFF72C8C1); // turquoise por defecto
        if (components.isNotEmpty && components[0]['color'] != null) {
          final colorStr = components[0]['color'] as String;
          // Si es un hex color string (ej: "#RRGGBB"), parsearlo
          if (colorStr.startsWith('#') && colorStr.length == 7) {
            mixColor = Color(
              int.parse(colorStr.substring(1), radix: 16) + 0xFF000000,
            );
          }
        }

        // Extraer autor (usar username en lugar de display_name)
        final profile = mixData['profiles'];
        final authorName = profile != null
            ? (profile['username'] as String? ?? 'Anónimo')
            : 'Anónimo';
        final authorAvatarUrl = profile != null
            ? profile['avatar_url'] as String?
            : null;

        return Mix(
          id: mixData['id'] as String,
          name: mixData['name'] as String,
          author: authorName,
          rating: (mixData['rating'] as num?)?.toDouble() ?? 0.0,
          reviews:
              (mixData['reviews_real'] as List?)?.firstOrNull?['count']
                  as int? ??
              (mixData['reviews'] as num?)?.toInt() ??
              0,
          ingredients: ingredients,
          color: mixColor,
          authorAvatarUrl: authorAvatarUrl,
        );
      }).toList();
    } catch (e, stackTrace) {
      AppLogger.error('Error al obtener mezclas', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Devuelve una lista acotada de tabacos disponibles (name, brand) para el buscador,
  /// filtrando en el servidor para evitar overfetching masivo en memoria.
  Future<List<Map<String, String>>> fetchAvailableTobaccos({
    String? query,
    int? limit,
  }) async {
    final q = query?.trim();
    final client = _supabase.client;
    final result = <Map<String, String>>[];
    final seen = <String>{};
    final effectiveLimit = (limit ?? 50).clamp(1, 100);

    dynamic request = client.from('tobaccos').select('name, brand');

    if (q != null && q.isNotEmpty) {
      request = request.or('name.ilike.%$q%,brand.ilike.%$q%');
    }

    final List data = await request
        .order('brand', ascending: true)
        .order('name', ascending: true)
        .limit(effectiveLimit)
        .timeout(supabaseReadTimeout);

    for (final row in data) {
      final name = (row['name'] as String?) ?? '';
      final brand = (row['brand'] as String?) ?? '';
      final key = '$brand::$name';
      if (name.isEmpty || brand.isEmpty || seen.contains(key)) continue;
      seen.add(key);
      result.add({'name': name, 'brand': brand});
    }

    return result;
  }

  /// Actualiza una mezcla y sustituye sus componentes.
  Future<Mix?> updateMix({
    required String mixId,
    required String name,
    String? description,
    required List<Map<String, dynamic>> components,
  }) async {
    try {
      final user = _supabase.client.auth.currentUser;
      if (user == null) {
        AppLogger.info('Usuario no autenticado');
        return null;
      }

      final normalizedComponents = components
          .map(
            (c) => {
              'tobacco_name': c['tobacco_name'],
              'brand': c['brand'],
              'percentage': c['percentage'],
              'color': c['color'],
            },
          )
          .toList();

      // Actualizar cabecera y componentes de forma atómica vía RPC transaccional
      try {
        await _supabase.client
            .rpc(
              'update_user_mix',
              params: {
                'p_mix_id': mixId,
                'p_name': name,
                'p_description': description,
                'p_components': normalizedComponents,
              },
            )
            .timeout(supabaseWriteTimeout);
      } on PostgrestException catch (e) {
        // Fallback si la migración RPC aún no ha sido aplicada en el entorno
        if (e.code == 'PGRST202' || e.code == '42883') {
          AppLogger.warning(
            'RPC update_user_mix no disponible (${e.code}), usando actualización secuencial',
          );
          await _supabase.client
              .from('mixes')
              .update({
                'name': name,
                'description': description,
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('id', mixId)
              .timeout(supabaseWriteTimeout);

          await _supabase.client
              .from('mix_components')
              .delete()
              .eq('mix_id', mixId)
              .timeout(supabaseWriteTimeout);

          if (normalizedComponents.isNotEmpty) {
            final componentsData = normalizedComponents
                .map((c) => {'mix_id': mixId, ...c})
                .toList();
            await _supabase.client
                .from('mix_components')
                .insert(componentsData)
                .timeout(supabaseWriteTimeout);
          }
        } else {
          rethrow;
        }
      }

      // Obtener username/avatar_url del autor y rating/reviews actuales en paralelo
      final metaResults = await Future.wait([
        _supabase.client
            .from('profiles')
            .select('username, avatar_url')
            .eq('id', user.id)
            .single()
            .timeout(supabaseReadTimeout),
        _supabase.client
            .from('mixes')
            .select('rating, reviews, reviews_real:reviews(count)')
            .eq('id', mixId)
            .single()
            .timeout(supabaseReadTimeout),
      ]);

      final profileResponse = metaResults[0];
      final mixRow = metaResults[1];
      final authorName = profileResponse['username'] as String? ?? 'Anónimo';
      final authorAvatarUrl = profileResponse['avatar_url'] as String?;

      final ingredients = components
          .map((c) => c['tobacco_name'] as String)
          .toList();

      Color mixColor = const Color(0xFF72C8C1);
      if (components.isNotEmpty && components[0]['color'] != null) {
        final colorStr = components[0]['color'] as String;
        if (colorStr.startsWith('#') && colorStr.length == 7) {
          mixColor = Color(
            int.parse(colorStr.substring(1), radix: 16) + 0xFF000000,
          );
        }
      }

      return Mix(
        id: mixId,
        name: name,
        author: authorName,
        rating: (mixRow['rating'] as num?)?.toDouble() ?? 0.0,
        reviews:
            (mixRow['reviews_real'] as List?)?.firstOrNull?['count']
                as int? ??
            (mixRow['reviews'] as num?)?.toInt() ??
            0,
        ingredients: ingredients,
        color: mixColor,
        authorAvatarUrl: authorAvatarUrl,
      );
    } catch (e, stackTrace) {
      AppLogger.error('Error al actualizar mezcla', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// Obtiene las mezclas favoritas del usuario autenticado.
  Future<List<Mix>> fetchFavorites({int limit = 100}) async {
    try {
      final user = _supabase.client.auth.currentUser;
      if (user == null) return [];

      final response = await _supabase.client
          .from('favorites')
          .select('''
            mix_id,
            mixes!inner(
              id,
              name,
              description,
              rating,
              reviews,
              reviews_real:reviews(count),
              created_at,
              profiles!mixes_author_id_fkey(username, display_name, avatar_url),
              mix_components(tobacco_name, brand, percentage, color)
            )
          ''')
          .eq('user_id', user.id)
          .limit(limit)
          .timeout(supabaseReadTimeout);

      return (response as List).map((favData) {
        final mixData = favData['mixes'];
        final components = mixData['mix_components'] as List? ?? [];
        final ingredients = components
            .map((c) => c['tobacco_name'] as String)
            .toList();

        Color mixColor = const Color(0xFF72C8C1);
        if (components.isNotEmpty && components[0]['color'] != null) {
          final colorStr = components[0]['color'] as String;
          if (colorStr.startsWith('#') && colorStr.length == 7) {
            mixColor = Color(
              int.parse(colorStr.substring(1), radix: 16) + 0xFF000000,
            );
          }
        }

        // Extraer autor (usar username en lugar de display_name)
        final profile = mixData['profiles'];
        final authorName = profile != null
            ? (profile['username'] as String? ?? 'Anónimo')
            : 'Anónimo';
        final authorAvatarUrl = profile != null
            ? profile['avatar_url'] as String?
            : null;

        return Mix(
          id: mixData['id'] as String,
          name: mixData['name'] as String,
          author: authorName,
          rating: (mixData['rating'] as num?)?.toDouble() ?? 0.0,
          reviews:
              (mixData['reviews_real'] as List?)?.firstOrNull?['count']
                  as int? ??
              (mixData['reviews'] as num?)?.toInt() ??
              0,
          ingredients: ingredients,
          color: mixColor,
          authorAvatarUrl: authorAvatarUrl,
        );
      }).toList();
    } catch (e, stackTrace) {
      AppLogger.error('Error al obtener favoritas', error: e, stackTrace: stackTrace);
      return [];
    }
  }

  /// Crea una nueva mezcla en la base de datos.
  ///
  /// [components] es una lista de mapas con los campos:
  /// - tobacco_name: String
  /// - brand: String
  /// - percentage: double
  /// - color: String (hex, ej: "#72C8C1")
  Future<Mix?> createMix({
    required String name,
    String? description,
    required List<Map<String, dynamic>> components,
  }) async {
    try {
      final user = _supabase.client.auth.currentUser;
      if (user == null) {
        AppLogger.info('Usuario no autenticado');
        return null;
      }

      // Insertar mezcla
      final mixResponse = await _supabase.client
          .from('mixes')
          .insert({
            'name': name,
            'description': description,
            'author_id': user.id,
            'rating': 0.0,
            'reviews': 0,
          })
          .select()
          .single()
          .timeout(supabaseWriteTimeout);

      final mixId = mixResponse['id'] as String;

      // Insertar componentes
      final componentsData = components
          .map(
            (c) => {
              'mix_id': mixId,
              'tobacco_name': c['tobacco_name'],
              'brand': c['brand'],
              'percentage': c['percentage'],
              'color': c['color'],
            },
          )
          .toList();

      await _supabase.client
          .from('mix_components')
          .insert(componentsData)
          .timeout(supabaseWriteTimeout);

      // Obtener perfil del usuario (usar username y avatar_url)
      final profileResponse = await _supabase.client
          .from('profiles')
          .select('username, avatar_url')
          .eq('id', user.id)
          .single()
          .timeout(supabaseReadTimeout);

      final authorName = profileResponse['username'] as String? ?? 'Anónimo';
      final authorAvatarUrl = profileResponse['avatar_url'] as String?;

      // Construir objeto Mix
      final ingredients = components
          .map((c) => c['tobacco_name'] as String)
          .toList();

      Color mixColor = const Color(0xFF72C8C1);
      if (components.isNotEmpty && components[0]['color'] != null) {
        final colorStr = components[0]['color'] as String;
        if (colorStr.startsWith('#') && colorStr.length == 7) {
          mixColor = Color(
            int.parse(colorStr.substring(1), radix: 16) + 0xFF000000,
          );
        }
      }

      return Mix(
        id: mixId,
        name: name,
        author: authorName,
        rating: 0.0,
        reviews: 0,
        ingredients: ingredients,
        color: mixColor,
        authorAvatarUrl: authorAvatarUrl,
      );
    } catch (e, stackTrace) {
      AppLogger.error('Error al crear mezcla', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// Obtiene los detalles completos de una mezcla específica por ID.
  /// Incluye descripción y componentes (ingredientes con porcentajes).
  Future<Map<String, dynamic>?> fetchMixDetails(String mixId) async {
    try {
      final response = await _supabase.client
          .from('mixes')
          .select('''
            id,
            name,
            description,
            rating,
            reviews,
            created_at,
            profiles!mixes_author_id_fkey(username, display_name),
            mix_components(tobacco_name, brand, percentage, color)
          ''')
          .eq('id', mixId)
          .single()
          .timeout(supabaseReadTimeout);

      // Extraer componentes
      final List<Map<String, dynamic>> components = [];
      for (final c in (response['mix_components'] as List? ?? [])) {
        Color color = const Color(0xFF72C8C1); // color por defecto
        final colorVal = c['color'];
        if (colorVal is String &&
            colorVal.startsWith('#') &&
            colorVal.length == 7) {
          color = Color(
            int.parse(colorVal.substring(1), radix: 16) + 0xFF000000,
          );
        }
        components.add({
          'tobacco_name': c['tobacco_name'] as String,
          'brand': c['brand'] as String,
          'percentage': (c['percentage'] as num).toDouble(),
          'color': color,
        });
      }

      // Enriquecer todos los componentes en una única consulta por lote (evita N+1 secuencial)
      if (components.isNotEmpty) {
        try {
          final uniqueNames = components
              .map((c) => c['tobacco_name'] as String)
              .toSet()
              .toList();
          final List catalogRows = await _supabase.client
              .from('tobaccos')
              .select(
                'id, name, brand, description, image_url, rating, reviews',
              )
              .inFilter('name', uniqueNames)
              .timeout(supabaseReadTimeout);

          for (final comp in components) {
            final compName = (comp['tobacco_name'] as String).toLowerCase();
            final compBrand = (comp['brand'] as String).toLowerCase();
            for (final raw in catalogRows) {
              final row = raw as Map<String, dynamic>;
              final rowName = ((row['name'] as String?) ?? '').toLowerCase();
              final rowBrand = ((row['brand'] as String?) ?? '').toLowerCase();
              if (rowName == compName && rowBrand == compBrand) {
                comp['description'] = row['description'];
                comp['catalog_item'] = row;
                break;
              }
            }
          }
        } catch (_) {
          // Ignorar errores de enriquecimiento de catálogo opcional
        }
      }

      return {
        'description':
            response['description'] as String? ?? 'Sin descripción disponible.',
        'components': components,
      };
    } catch (e, stackTrace) {
      AppLogger.error('Error al obtener detalles de mezcla', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// Obtiene mezclas relacionadas que comparten al menos un tabaco con la mezcla dada.
  /// Excluye la mezcla actual de los resultados.
  Future<List<Mix>> fetchRelatedMixes({
    required String currentMixId,
    required List<String> tobaccoNames,
    int limit = 5,
  }) async {
    if (tobaccoNames.isEmpty) return [];

    try {
      // Buscar mezclas que contengan al menos uno de los tabacos
      final response = await _supabase.client
          .from('mix_components')
          .select('''
            mix_id,
            mixes!inner(
              id,
              name,
              description,
              rating,
              reviews,
              reviews_real:reviews(count),
              created_at,
              profiles!mixes_author_id_fkey(username, display_name, avatar_url),
              mix_components(tobacco_name, brand, percentage, color)
            )
          ''')
          .inFilter('tobacco_name', tobaccoNames)
          .neq('mix_id', currentMixId)
          .limit(limit * 3)
          .timeout(supabaseReadTimeout); // Obtener más para filtrar duplicados

      // Agrupar por mix_id para evitar duplicados
      final Map<String, dynamic> uniqueMixes = {};
      for (final item in response as List) {
        final mixData = item['mixes'];
        final mixId = mixData['id'] as String;
        if (!uniqueMixes.containsKey(mixId)) {
          uniqueMixes[mixId] = mixData;
        }
      }

      // Convertir a objetos Mix
      final mixes = uniqueMixes.values.take(limit).map((mixData) {
        final components = mixData['mix_components'] as List? ?? [];
        final ingredients = components
            .map((c) => c['tobacco_name'] as String)
            .toList();

        Color mixColor = const Color(0xFF72C8C1);
        if (components.isNotEmpty && components[0]['color'] != null) {
          final colorStr = components[0]['color'] as String;
          if (colorStr.startsWith('#') && colorStr.length == 7) {
            mixColor = Color(
              int.parse(colorStr.substring(1), radix: 16) + 0xFF000000,
            );
          }
        }

        final profile = mixData['profiles'];
        final authorName = profile != null
            ? (profile['username'] as String? ?? 'Anónimo')
            : 'Anónimo';
        final authorAvatarUrl = profile != null
            ? profile['avatar_url'] as String?
            : null;

        return Mix(
          id: mixData['id'] as String,
          name: mixData['name'] as String,
          author: authorName,
          rating: (mixData['rating'] as num?)?.toDouble() ?? 0.0,
          reviews:
              (mixData['reviews_real'] as List?)?.firstOrNull?['count']
                  as int? ??
              (mixData['reviews'] as num?)?.toInt() ??
              0,
          ingredients: ingredients,
          color: mixColor,
          authorAvatarUrl: authorAvatarUrl,
        );
      }).toList();

      return mixes;
    } catch (e, stackTrace) {
      AppLogger.error('Error al obtener mezclas relacionadas', error: e, stackTrace: stackTrace);
      return [];
    }
  }

  /// Obtiene las reseñas de una mezcla específica.
  Future<List<Map<String, dynamic>>> fetchReviews(String mixId) async {
    try {
      final response = await _supabase.client
          .from('reviews')
          .select('''
            id,
            rating,
            comment,
            created_at,
            author_id,
            profiles!reviews_author_id_fkey(username, display_name, avatar_url)
          ''')
          .eq('mix_id', mixId)
          .order('created_at', ascending: false)
          .limit(100)
          .timeout(supabaseReadTimeout);

      return (response as List).map((reviewData) {
        final profile = reviewData['profiles'];
        return {
          'id': reviewData['id'] as String,
          'author': profile != null
              ? (profile['username'] as String? ?? 'Anónimo')
              : 'Anónimo',
          'author_id': reviewData['author_id'] as String?,
          'author_avatar_url': profile != null
              ? profile['avatar_url'] as String?
              : null,
          'rating': (reviewData['rating'] as num).toDouble(),
          'comment': reviewData['comment'] as String? ?? '',
          'created_at': DateTime.parse(reviewData['created_at'] as String),
        };
      }).toList();
    } catch (e, stackTrace) {
      AppLogger.error('Error al obtener reseñas', error: e, stackTrace: stackTrace);
      return [];
    }
  }

  /// Crea una nueva reseña para una mezcla.
  Future<bool> createReview({
    required String mixId,
    required double rating,
    required String comment,
  }) async {
    try {
      final user = _supabase.client.auth.currentUser;
      if (user == null) {
        AppLogger.info('Usuario no autenticado');
        return false;
      }

      final existingCount = await _supabase.client
          .from('reviews')
          .count(CountOption.exact)
          .eq('mix_id', mixId)
          .eq('author_id', user.id)
          .timeout(supabaseReadTimeout);

      if (existingCount > 0) {
        AppLogger.warning(
          'Intento de crear reseña duplicada para la mezcla: $mixId',
        );
        return false;
      }

      await _supabase.client
          .from('reviews')
          .insert({
            'mix_id': mixId,
            'author_id': user.id,
            'rating': rating,
            'comment': comment,
          })
          .timeout(supabaseWriteTimeout);

      // El rating promedio y el conteo de reviews en `mixes` se actualizan
      // automáticamente en PostgreSQL mediante el trigger SECURITY DEFINER.
      return true;
    } catch (e, stackTrace) {
      AppLogger.error('Error al crear reseña', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// Elimina una reseña por su ID.
  Future<bool> deleteReview(String reviewId, String mixId) async {
    try {
      await _supabase.client
          .from('reviews')
          .delete()
          .eq('id', reviewId)
          .timeout(supabaseWriteTimeout);

      return true;
    } catch (e, stackTrace) {
      AppLogger.error('Error al eliminar reseña', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// Actualiza una reseña existente.
  Future<bool> updateReview({
    required String reviewId,
    required String mixId,
    required double rating,
    required String comment,
  }) async {
    try {
      await _supabase.client
          .from('reviews')
          .update({'rating': rating, 'comment': comment})
          .eq('id', reviewId)
          .timeout(supabaseWriteTimeout);

      return true;
    } catch (e, stackTrace) {
      AppLogger.error('Error al actualizar reseña', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// Verifica si la mezcla pertenece al usuario autenticado.
  Future<bool> isMyMix(String mixId) async {
    try {
      final user = _supabase.client.auth.currentUser;
      if (user == null) return false;

      final res = await _supabase.client
          .from('mixes')
          .select('author_id')
          .eq('id', mixId)
          .single()
          .timeout(supabaseReadTimeout);

      final authorId = res['author_id'] as String?;
      return authorId != null && authorId == user.id;
    } catch (e, stackTrace) {
      AppLogger.error('Error al comprobar propiedad de mezcla', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// Elimina una mezcla por ID. Requiere permisos RLS adecuados en Supabase.
  Future<bool> deleteMix(String mixId) async {
    try {
      // Intentar borrar directamente la mezcla. Si hay FKs con CASCADE,
      // eliminará componentes/reseñas asociadas automáticamente.
      await _supabase.client
          .from('mixes')
          .delete()
          .eq('id', mixId)
          .timeout(supabaseWriteTimeout);
      return true;
    } catch (e, stackTrace) {
      AppLogger.error('Error al eliminar mezcla', error: e, stackTrace: stackTrace);
      return false;
    }
  }
}
