# 🔔 Plan de Implementación: Sistema de Notificaciones en Tiempo Real

## 📋 Análisis de la Aplicación

### Estado Actual
- ✅ Tabla `notifications` ya existe en el esquema de base de datos
- ✅ Políticas RLS configuradas para notificaciones
- ✅ Icono de campanita en la barra superior (`main_navigation.dart`)
- ✅ Bottom sheet temporal con notificaciones de prueba
- ✅ Sistema de autenticación y perfiles funcionando
- ✅ Sistema de mezclas, reseñas y favoritos implementado
- ✅ Supabase Realtime disponible

### Funcionalidades Principales de la App
1. **Comunidad**: Crear, ver, editar mezclas
2. **Reseñas**: Comentar y valorar mezclas
3. **Favoritos**: Marcar mezclas favoritas
4. **Catálogo**: Navegación de tabacos
5. **Perfil**: Gestión de usuario y configuración
6. **Historial**: Registro de mezclas visitadas

---

## 🎯 Objetivos del Sistema de Notificaciones

### 1. Tipos de Notificaciones a Implementar

#### 🔴 **Alta Prioridad** (Fase 1)
| Tipo | Descripción | Trigger |
|------|-------------|---------|
| `review_on_my_mix` | Alguien comentó en mi mezcla | Nueva reseña en mezcla del usuario |
| `new_tobacco` | Nuevo tabaco agregado al catálogo | Inserción en tabla `tobaccos` |
| `mix_trending` | Una mezcla tuya está siendo muy valorada | Rating > 4.5 y reviews >= 5 |

#### 🟡 **Media Prioridad** (Fase 2)
| Tipo | Descripción | Trigger |
|------|-------------|---------|
| `favorite_my_mix` | Alguien marcó mi mezcla como favorita | Nueva entrada en `favorites` |
| `follow_new_mix` | Usuario seguido creó nueva mezcla | Nueva mezcla de usuario seguido* |
| `review_reply` | Respuesta a mi reseña | Sistema de respuestas* |

#### 🟢 **Baja Prioridad** (Fase 3)
| Tipo | Descripción | Trigger |
|------|-------------|---------|
| `weekly_digest` | Resumen semanal de actividad | Cron job |
| `achievement` | Logro desbloqueado | Sistema de logros* |
| `recommended_mix` | Mezcla recomendada basada en gustos | ML/Algoritmo* |

*_Requiere funcionalidad adicional no implementada aún_

---

## 🏗️ Arquitectura del Sistema

### Componentes Principales

```
┌─────────────────────────────────────────────────────────────────┐
│                      FLUTTER APP                                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌──────────────────┐    ┌──────────────────┐                  │
│  │ NotificationIcon │◄───┤ Realtime Stream  │                  │
│  │   (Badge Count)  │    │   (WebSocket)    │                  │
│  └────────┬─────────┘    └──────────────────┘                  │
│           │                                                       │
│           ▼                                                       │
│  ┌─────────────────────────────────────┐                        │
│  │  NotificationsProvider              │                        │
│  │  - Lista de notificaciones          │                        │
│  │  - Contador no leídas              │                        │
│  │  - Métodos CRUD                     │                        │
│  └─────────────┬───────────────────────┘                        │
│                │                                                  │
│                ▼                                                  │
│  ┌─────────────────────────────────────┐                        │
│  │  NotificationsRepository            │                        │
│  │  - fetchNotifications()             │                        │
│  │  - markAsRead()                     │                        │
│  │  - deleteNotification()             │                        │
│  │  - subscribeToNotifications()       │                        │
│  └─────────────┬───────────────────────┘                        │
│                │                                                  │
└────────────────┼──────────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────────────┐
│                      SUPABASE                                    │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌──────────────────────────────────────────────┐               │
│  │  notifications TABLE                         │               │
│  │  - id, user_id, type, data                   │               │
│  │  - is_read, created_at                       │               │
│  └──────────────┬───────────────────────────────┘               │
│                 │                                                 │
│                 │                                                 │
│  ┌──────────────▼────────────────────────────────┐              │
│  │  DATABASE TRIGGERS                            │              │
│  │  - trigger_review_notification()              │              │
│  │  - trigger_tobacco_notification()             │              │
│  │  - trigger_favorite_notification()            │              │
│  │  - trigger_trending_mix_notification()        │              │
│  └───────────────────────────────────────────────┘              │
│                                                                   │
│  ┌───────────────────────────────────────────────┐              │
│  │  REALTIME (WebSocket)                         │              │
│  │  - Broadcast INSERT en notifications          │              │
│  │  - Escucha por user_id                        │              │
│  └───────────────────────────────────────────────┘              │
│                                                                   │
│  ┌───────────────────────────────────────────────┐              │
│  │  RLS POLICIES                                 │              │
│  │  - Solo el usuario ve sus notificaciones      │              │
│  └───────────────────────────────────────────────┘              │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

---

## 📝 Plan de Implementación Paso a Paso

### **FASE 0: Preparación del Entorno** ⚙️

#### Step 0.1: Instalar Dependencias
```yaml
# Agregar a pubspec.yaml
dependencies:
  # Ya existentes...
  timeago: ^3.6.1  # Para "hace 2 horas"
```

#### Step 0.2: Verificar Configuración de Supabase Realtime
- Ir al Dashboard de Supabase → Database → Replication
- Asegurarse de que la tabla `notifications` tiene Realtime habilitado
- Verificar que las políticas RLS permiten escuchar cambios

---

### **FASE 1: Base de Datos** 🗄️

#### Step 1.1: Actualizar Esquema de Notificaciones
**Archivo**: `supabase_notifications_schema.sql` (NUEVO)

```sql
-- Asegurar que la tabla notifications existe con los campos necesarios
-- Ya existe en supabase_schema.sql, pero vamos a añadir mejoras

-- Índices adicionales para optimización
CREATE INDEX IF NOT EXISTS idx_notifications_user_created 
  ON notifications(user_id, created_at DESC);
  
CREATE INDEX IF NOT EXISTS idx_notifications_user_unread 
  ON notifications(user_id, is_read) 
  WHERE is_read = false;

-- Tipos de notificación permitidos (enum-like constraint)
ALTER TABLE notifications 
  DROP CONSTRAINT IF EXISTS notifications_type_check;

ALTER TABLE notifications
  ADD CONSTRAINT notifications_type_check 
  CHECK (type IN (
    'review_on_my_mix',
    'new_tobacco',
    'mix_trending',
    'favorite_my_mix',
    'follow_new_mix',
    'review_reply',
    'weekly_digest',
    'achievement',
    'recommended_mix'
  ));

-- Comentarios para documentación
COMMENT ON COLUMN notifications.type IS 'Tipo de notificación. Ver NOTIFICATIONS_IMPLEMENTATION_PLAN.md para lista completa';
COMMENT ON COLUMN notifications.data IS 'JSON con datos específicos: {mix_id, mix_name, author_name, tobacco_id, tobacco_name, etc}';
```

#### Step 1.2: Crear Funciones Helper
**Archivo**: `supabase_notifications_functions.sql` (NUEVO)

```sql
-- Función helper para crear notificaciones
CREATE OR REPLACE FUNCTION create_notification(
  p_user_id UUID,
  p_type TEXT,
  p_data JSONB
)
RETURNS UUID AS $$
DECLARE
  v_notification_id UUID;
BEGIN
  INSERT INTO notifications (user_id, type, data, is_read, created_at)
  VALUES (p_user_id, p_type, p_data, false, NOW())
  RETURNING id INTO v_notification_id;
  
  RETURN v_notification_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Función para limpiar notificaciones antiguas (opcional)
CREATE OR REPLACE FUNCTION clean_old_notifications(days_to_keep INTEGER DEFAULT 30)
RETURNS INTEGER AS $$
DECLARE
  deleted_count INTEGER;
BEGIN
  DELETE FROM notifications 
  WHERE created_at < NOW() - (days_to_keep || ' days')::INTERVAL
    AND is_read = true;
  
  GET DIAGNOSTICS deleted_count = ROW_COUNT;
  RETURN deleted_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Función para obtener contador de no leídas
CREATE OR REPLACE FUNCTION get_unread_count(p_user_id UUID)
RETURNS INTEGER AS $$
BEGIN
  RETURN (
    SELECT COUNT(*)::INTEGER
    FROM notifications
    WHERE user_id = p_user_id AND is_read = false
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

#### Step 1.3: Crear Triggers para Notificaciones Automáticas
**Archivo**: `supabase_notifications_triggers.sql` (NUEVO)

```sql
-- =====================================================
-- TRIGGER 1: Notificación cuando alguien reseña mi mezcla
-- =====================================================
CREATE OR REPLACE FUNCTION notify_review_on_mix()
RETURNS TRIGGER AS $$
DECLARE
  v_mix_author_id UUID;
  v_mix_name TEXT;
  v_reviewer_name TEXT;
BEGIN
  -- Obtener el autor de la mezcla
  SELECT author_id, name INTO v_mix_author_id, v_mix_name
  FROM mixes
  WHERE id = NEW.mix_id;
  
  -- Solo notificar si el autor de la reseña NO es el autor de la mezcla
  IF v_mix_author_id IS NOT NULL AND v_mix_author_id != NEW.author_id THEN
    -- Obtener nombre del reviewer
    SELECT username INTO v_reviewer_name
    FROM profiles
    WHERE id = NEW.author_id;
    
    -- Crear notificación
    PERFORM create_notification(
      v_mix_author_id,
      'review_on_my_mix',
      jsonb_build_object(
        'mix_id', NEW.mix_id,
        'mix_name', v_mix_name,
        'review_id', NEW.id,
        'reviewer_name', COALESCE(v_reviewer_name, 'Anónimo'),
        'rating', NEW.rating,
        'comment', SUBSTRING(NEW.comment, 1, 100)
      )
    );
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_review_notification ON reviews;
CREATE TRIGGER trigger_review_notification
  AFTER INSERT ON reviews
  FOR EACH ROW
  EXECUTE FUNCTION notify_review_on_mix();

-- =====================================================
-- TRIGGER 2: Notificación cuando se añade nuevo tabaco
-- =====================================================
CREATE OR REPLACE FUNCTION notify_new_tobacco()
RETURNS TRIGGER AS $$
BEGIN
  -- Notificar a TODOS los usuarios activos (o implementar lógica de preferencias)
  -- Por ahora, solo a usuarios con push_notifications = true
  INSERT INTO notifications (user_id, type, data, is_read)
  SELECT 
    us.user_id,
    'new_tobacco',
    jsonb_build_object(
      'tobacco_id', NEW.id,
      'tobacco_name', NEW.name,
      'tobacco_brand', NEW.brand,
      'tobacco_description', SUBSTRING(NEW.description, 1, 100)
    ),
    false
  FROM user_settings us
  WHERE us.push_notifications = true;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_tobacco_notification ON tobaccos;
CREATE TRIGGER trigger_tobacco_notification
  AFTER INSERT ON tobaccos
  FOR EACH ROW
  EXECUTE FUNCTION notify_new_tobacco();

-- =====================================================
-- TRIGGER 3: Notificación cuando alguien marca favorito
-- =====================================================
CREATE OR REPLACE FUNCTION notify_favorite_on_mix()
RETURNS TRIGGER AS $$
DECLARE
  v_mix_author_id UUID;
  v_mix_name TEXT;
  v_favoriter_name TEXT;
BEGIN
  -- Obtener el autor de la mezcla
  SELECT author_id, name INTO v_mix_author_id, v_mix_name
  FROM mixes
  WHERE id = NEW.mix_id;
  
  -- Solo notificar si el que marca favorito NO es el autor
  IF v_mix_author_id IS NOT NULL AND v_mix_author_id != NEW.user_id THEN
    -- Obtener nombre de quien marcó favorito
    SELECT username INTO v_favoriter_name
    FROM profiles
    WHERE id = NEW.user_id;
    
    -- Crear notificación
    PERFORM create_notification(
      v_mix_author_id,
      'favorite_my_mix',
      jsonb_build_object(
        'mix_id', NEW.mix_id,
        'mix_name', v_mix_name,
        'favoriter_name', COALESCE(v_favoriter_name, 'Anónimo')
      )
    );
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_favorite_notification ON favorites;
CREATE TRIGGER trigger_favorite_notification
  AFTER INSERT ON favorites
  FOR EACH ROW
  EXECUTE FUNCTION notify_favorite_on_mix();

-- =====================================================
-- TRIGGER 4: Notificación de mezcla trending (rating alto)
-- =====================================================
-- Este se ejecutará cuando se actualice el rating de una mezcla
-- Solo notifica UNA VEZ cuando alcanza el umbral
CREATE OR REPLACE FUNCTION notify_trending_mix()
RETURNS TRIGGER AS $$
DECLARE
  v_author_id UUID;
  v_notification_exists BOOLEAN;
BEGIN
  -- Verificar si la mezcla alcanzó el umbral de trending
  IF NEW.rating >= 4.5 AND NEW.reviews >= 5 THEN
    -- Verificar si ya notificamos antes por trending
    SELECT EXISTS(
      SELECT 1 FROM notifications
      WHERE type = 'mix_trending' 
        AND (data->>'mix_id')::UUID = NEW.id
    ) INTO v_notification_exists;
    
    -- Si no existe notificación previa, crear una
    IF NOT v_notification_exists THEN
      SELECT author_id INTO v_author_id FROM mixes WHERE id = NEW.id;
      
      IF v_author_id IS NOT NULL THEN
        PERFORM create_notification(
          v_author_id,
          'mix_trending',
          jsonb_build_object(
            'mix_id', NEW.id,
            'mix_name', NEW.name,
            'rating', NEW.rating,
            'reviews', NEW.reviews
          )
        );
      END IF;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_trending_notification ON mixes;
CREATE TRIGGER trigger_trending_notification
  AFTER UPDATE OF rating, reviews ON mixes
  FOR EACH ROW
  WHEN (NEW.rating IS DISTINCT FROM OLD.rating OR NEW.reviews IS DISTINCT FROM OLD.reviews)
  EXECUTE FUNCTION notify_trending_mix();
```

#### Step 1.4: Habilitar Realtime en la Tabla
**Acción manual en Supabase Dashboard**:
1. Database → Replication
2. Buscar tabla `notifications`
3. Activar Realtime (toggle)
4. Guardar cambios

---

### **FASE 2: Modelos de Dominio** 📦

#### Step 2.1: Modelo de Notificación
**Archivo**: `lib/core/models/notification.dart` (NUEVO)

```dart
import 'package:flutter/material.dart';

/// Modelo de dominio para una notificación
class AppNotification {
  final String id;
  final String userId;
  final NotificationType type;
  final Map<String, dynamic> data;
  final bool isRead;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.data,
    required this.isRead,
    required this.createdAt,
  });

  /// Factory desde JSON de Supabase
  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      type: NotificationTypeExtension.fromString(json['type'] as String),
      data: (json['data'] as Map<String, dynamic>?) ?? {},
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// Título de la notificación según el tipo
  String get title {
    switch (type) {
      case NotificationType.reviewOnMyMix:
        return 'Nueva reseña';
      case NotificationType.newTobacco:
        return 'Nuevo tabaco';
      case NotificationType.mixTrending:
        return '🔥 Mezcla trending';
      case NotificationType.favoriteMyMix:
        return 'Nuevo favorito';
      case NotificationType.followNewMix:
        return 'Nueva mezcla';
      case NotificationType.reviewReply:
        return 'Respuesta a tu reseña';
      case NotificationType.weeklyDigest:
        return 'Resumen semanal';
      case NotificationType.achievement:
        return '🏆 Logro desbloqueado';
      case NotificationType.recommendedMix:
        return 'Recomendación para ti';
    }
  }

  /// Mensaje de la notificación según el tipo
  String get message {
    switch (type) {
      case NotificationType.reviewOnMyMix:
        final reviewerName = data['reviewer_name'] as String? ?? 'Alguien';
        final mixName = data['mix_name'] as String? ?? 'tu mezcla';
        return '$reviewerName comentó en "$mixName"';
        
      case NotificationType.newTobacco:
        final tobaccoName = data['tobacco_name'] as String? ?? 'Un nuevo tabaco';
        final brand = data['tobacco_brand'] as String? ?? '';
        return '$tobaccoName $brand se agregó al catálogo';
        
      case NotificationType.mixTrending:
        final mixName = data['mix_name'] as String? ?? 'Tu mezcla';
        final rating = (data['rating'] as num?)?.toStringAsFixed(1) ?? '5.0';
        return '$mixName está siendo muy bien valorada ($rating⭐)';
        
      case NotificationType.favoriteMyMix:
        final favoriterName = data['favoriter_name'] as String? ?? 'Alguien';
        final mixName = data['mix_name'] as String? ?? 'tu mezcla';
        return '$favoriterName marcó "$mixName" como favorita';
        
      case NotificationType.followNewMix:
        final authorName = data['author_name'] as String? ?? 'Un usuario';
        final mixName = data['mix_name'] as String? ?? '';
        return '$authorName creó una nueva mezcla: $mixName';
        
      case NotificationType.reviewReply:
        final replierName = data['replier_name'] as String? ?? 'Alguien';
        return '$replierName respondió a tu reseña';
        
      case NotificationType.weeklyDigest:
        return 'Revisa tu actividad de esta semana';
        
      case NotificationType.achievement:
        final achievementName = data['achievement_name'] as String? ?? 'Nuevo logro';
        return 'Has desbloqueado: $achievementName';
        
      case NotificationType.recommendedMix:
        final mixName = data['mix_name'] as String? ?? 'Una mezcla';
        return 'Creemos que te gustará: $mixName';
    }
  }

  /// Icono para el tipo de notificación
  IconData get icon {
    switch (type) {
      case NotificationType.reviewOnMyMix:
        return Icons.rate_review;
      case NotificationType.newTobacco:
        return Icons.inventory_2;
      case NotificationType.mixTrending:
        return Icons.trending_up;
      case NotificationType.favoriteMyMix:
        return Icons.favorite;
      case NotificationType.followNewMix:
        return Icons.person_add;
      case NotificationType.reviewReply:
        return Icons.reply;
      case NotificationType.weeklyDigest:
        return Icons.calendar_today;
      case NotificationType.achievement:
        return Icons.emoji_events;
      case NotificationType.recommendedMix:
        return Icons.lightbulb;
    }
  }

  /// Color del icono
  Color get color {
    switch (type) {
      case NotificationType.reviewOnMyMix:
        return Colors.blue;
      case NotificationType.newTobacco:
        return Colors.green;
      case NotificationType.mixTrending:
        return Colors.orange;
      case NotificationType.favoriteMyMix:
        return Colors.red;
      case NotificationType.followNewMix:
        return Colors.purple;
      case NotificationType.reviewReply:
        return Colors.teal;
      case NotificationType.weeklyDigest:
        return Colors.indigo;
      case NotificationType.achievement:
        return Colors.amber;
      case NotificationType.recommendedMix:
        return Colors.cyan;
    }
  }

  /// Copia con cambios
  AppNotification copyWith({
    String? id,
    String? userId,
    NotificationType? type,
    Map<String, dynamic>? data,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return AppNotification(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      data: data ?? this.data,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// Enum para tipos de notificaciones
enum NotificationType {
  reviewOnMyMix,
  newTobacco,
  mixTrending,
  favoriteMyMix,
  followNewMix,
  reviewReply,
  weeklyDigest,
  achievement,
  recommendedMix,
}

/// Extension para convertir string a enum
extension NotificationTypeExtension on NotificationType {
  static NotificationType fromString(String type) {
    switch (type) {
      case 'review_on_my_mix':
        return NotificationType.reviewOnMyMix;
      case 'new_tobacco':
        return NotificationType.newTobacco;
      case 'mix_trending':
        return NotificationType.mixTrending;
      case 'favorite_my_mix':
        return NotificationType.favoriteMyMix;
      case 'follow_new_mix':
        return NotificationType.followNewMix;
      case 'review_reply':
        return NotificationType.reviewReply;
      case 'weekly_digest':
        return NotificationType.weeklyDigest;
      case 'achievement':
        return NotificationType.achievement;
      case 'recommended_mix':
        return NotificationType.recommendedMix;
      default:
        return NotificationType.reviewOnMyMix; // fallback
    }
  }

  String toJson() {
    switch (this) {
      case NotificationType.reviewOnMyMix:
        return 'review_on_my_mix';
      case NotificationType.newTobacco:
        return 'new_tobacco';
      case NotificationType.mixTrending:
        return 'mix_trending';
      case NotificationType.favoriteMyMix:
        return 'favorite_my_mix';
      case NotificationType.followNewMix:
        return 'follow_new_mix';
      case NotificationType.reviewReply:
        return 'review_reply';
      case NotificationType.weeklyDigest:
        return 'weekly_digest';
      case NotificationType.achievement:
        return 'achievement';
      case NotificationType.recommendedMix:
        return 'recommended_mix';
    }
  }
}
```

---

### **FASE 3: Capa de Datos** 🔌

#### Step 3.1: Repositorio de Notificaciones
**Archivo**: `lib/features/notifications/data/notifications_repository.dart` (NUEVO)

```dart
import 'package:flutter/foundation.dart';
import '../../../core/data/supabase_service.dart';
import '../../../core/models/notification.dart';

/// Repositorio para gestionar notificaciones desde Supabase
class NotificationsRepository {
  NotificationsRepository(this._supabase);

  final SupabaseService _supabase;

  /// Obtiene las notificaciones del usuario autenticado
  /// [limit] cantidad de notificaciones a obtener
  /// [offset] desde qué posición empezar (para paginación)
  Future<List<AppNotification>> fetchNotifications({
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final user = _supabase.client.auth.currentUser;
      if (user == null) {
        debugPrint('Usuario no autenticado');
        return [];
      }

      final response = await _supabase.client
          .from('notifications')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return (response as List)
          .map((json) => AppNotification.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Error al obtener notificaciones: $e');
      return [];
    }
  }

  /// Obtiene el contador de notificaciones no leídas
  Future<int> getUnreadCount() async {
    try {
      final user = _supabase.client.auth.currentUser;
      if (user == null) return 0;

      final response = await _supabase.client
          .from('notifications')
          .select('id', const FetchOptions(count: CountOption.exact))
          .eq('user_id', user.id)
          .eq('is_read', false);

      return response.count ?? 0;
    } catch (e) {
      debugPrint('Error al obtener contador de no leídas: $e');
      return 0;
    }
  }

  /// Marca una notificación como leída
  Future<bool> markAsRead(String notificationId) async {
    try {
      await _supabase.client
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId);
      return true;
    } catch (e) {
      debugPrint('Error al marcar como leída: $e');
      return false;
    }
  }

  /// Marca todas las notificaciones del usuario como leídas
  Future<bool> markAllAsRead() async {
    try {
      final user = _supabase.client.auth.currentUser;
      if (user == null) return false;

      await _supabase.client
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', user.id)
          .eq('is_read', false);
      
      return true;
    } catch (e) {
      debugPrint('Error al marcar todas como leídas: $e');
      return false;
    }
  }

  /// Elimina una notificación
  Future<bool> deleteNotification(String notificationId) async {
    try {
      await _supabase.client
          .from('notifications')
          .delete()
          .eq('id', notificationId);
      return true;
    } catch (e) {
      debugPrint('Error al eliminar notificación: $e');
      return false;
    }
  }

  /// Elimina todas las notificaciones leídas del usuario
  Future<bool> deleteAllRead() async {
    try {
      final user = _supabase.client.auth.currentUser;
      if (user == null) return false;

      await _supabase.client
          .from('notifications')
          .delete()
          .eq('user_id', user.id)
          .eq('is_read', true);
      
      return true;
    } catch (e) {
      debugPrint('Error al eliminar notificaciones leídas: $e');
      return false;
    }
  }

  /// Suscripción a notificaciones en tiempo real
  /// Retorna un Stream que emite nuevas notificaciones
  Stream<AppNotification> subscribeToNotifications() {
    final user = _supabase.client.auth.currentUser;
    if (user == null) {
      debugPrint('Usuario no autenticado para suscripción');
      return const Stream.empty();
    }

    return _supabase.client
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', user.id)
        .order('created_at', ascending: false)
        .map((data) {
          if (data.isEmpty) return [];
          return data.map((json) => AppNotification.fromJson(json)).toList();
        })
        .expand((notifications) => notifications);
  }
}
```

---

### **FASE 4: Lógica de Negocio (Provider)** 🧠

#### Step 4.1: Provider de Notificaciones
**Archivo**: `lib/features/notifications/presentation/notifications_provider.dart` (NUEVO)

```dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../core/models/notification.dart';
import '../data/notifications_repository.dart';

/// Provider para gestionar el estado de las notificaciones
class NotificationsProvider extends ChangeNotifier {
  NotificationsProvider(this._repository) {
    _init();
  }

  final NotificationsRepository _repository;
  
  List<AppNotification> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMoreData = true;
  String? _error;
  
  StreamSubscription<AppNotification>? _realtimeSubscription;
  
  static const int _pageSize = 50;
  int _currentOffset = 0;

  // Getters
  List<AppNotification> get notifications => List.unmodifiable(_notifications);
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMoreData => _hasMoreData;
  String? get error => _error;
  bool get hasNotifications => _notifications.isNotEmpty;

  /// Inicialización: cargar notificaciones y suscribirse a Realtime
  Future<void> _init() async {
    await loadNotifications();
    _subscribeToRealtime();
  }

  /// Cargar notificaciones (primera carga o refresh)
  Future<void> loadNotifications({bool refresh = false}) async {
    if (refresh) {
      _currentOffset = 0;
      _hasMoreData = true;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final notifications = await _repository.fetchNotifications(
        limit: _pageSize,
        offset: 0,
      );

      _notifications = notifications;
      _hasMoreData = notifications.length >= _pageSize;
      _currentOffset = notifications.length;

      // Actualizar contador de no leídas
      await _updateUnreadCount();
    } catch (e) {
      _error = 'Error al cargar notificaciones';
      debugPrint('Error en loadNotifications: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Cargar más notificaciones (paginación)
  Future<void> loadMore() async {
    if (_isLoadingMore || !_hasMoreData) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      final moreNotifications = await _repository.fetchNotifications(
        limit: _pageSize,
        offset: _currentOffset,
      );

      if (moreNotifications.isEmpty) {
        _hasMoreData = false;
      } else {
        _notifications.addAll(moreNotifications);
        _currentOffset += moreNotifications.length;
        _hasMoreData = moreNotifications.length >= _pageSize;
      }
    } catch (e) {
      debugPrint('Error en loadMore: $e');
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  /// Actualizar contador de notificaciones no leídas
  Future<void> _updateUnreadCount() async {
    try {
      _unreadCount = await _repository.getUnreadCount();
      notifyListeners();
    } catch (e) {
      debugPrint('Error al actualizar contador: $e');
    }
  }

  /// Marcar notificación como leída
  Future<void> markAsRead(String notificationId) async {
    try {
      final success = await _repository.markAsRead(notificationId);
      if (success) {
        // Actualizar localmente
        final index = _notifications.indexWhere((n) => n.id == notificationId);
        if (index != -1 && !_notifications[index].isRead) {
          _notifications[index] = _notifications[index].copyWith(isRead: true);
          _unreadCount = (_unreadCount - 1).clamp(0, double.infinity).toInt();
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Error al marcar como leída: $e');
    }
  }

  /// Marcar todas como leídas
  Future<void> markAllAsRead() async {
    try {
      final success = await _repository.markAllAsRead();
      if (success) {
        // Actualizar localmente
        _notifications = _notifications
            .map((n) => n.copyWith(isRead: true))
            .toList();
        _unreadCount = 0;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error al marcar todas como leídas: $e');
    }
  }

  /// Eliminar notificación
  Future<void> deleteNotification(String notificationId) async {
    try {
      final success = await _repository.deleteNotification(notificationId);
      if (success) {
        // Actualizar localmente
        final index = _notifications.indexWhere((n) => n.id == notificationId);
        if (index != -1) {
          if (!_notifications[index].isRead) {
            _unreadCount = (_unreadCount - 1).clamp(0, double.infinity).toInt();
          }
          _notifications.removeAt(index);
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Error al eliminar notificación: $e');
    }
  }

  /// Eliminar todas las notificaciones leídas
  Future<void> deleteAllRead() async {
    try {
      final success = await _repository.deleteAllRead();
      if (success) {
        _notifications.removeWhere((n) => n.isRead);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error al eliminar notificaciones leídas: $e');
    }
  }

  /// Suscribirse a notificaciones en tiempo real
  void _subscribeToRealtime() {
    _realtimeSubscription?.cancel();
    
    _realtimeSubscription = _repository
        .subscribeToNotifications()
        .listen(
          _onNewNotification,
          onError: (error) {
            debugPrint('Error en suscripción Realtime: $error');
          },
        );
  }

  /// Callback cuando llega una nueva notificación
  void _onNewNotification(AppNotification notification) {
    // Verificar si ya existe (evitar duplicados)
    final exists = _notifications.any((n) => n.id == notification.id);
    
    if (!exists) {
      // Insertar al inicio de la lista
      _notifications.insert(0, notification);
      
      // Incrementar contador si no está leída
      if (!notification.isRead) {
        _unreadCount++;
      }
      
      notifyListeners();
      
      // Aquí podrías mostrar un snackbar o notificación local
      debugPrint('Nueva notificación recibida: ${notification.title}');
    }
  }

  @override
  void dispose() {
    _realtimeSubscription?.cancel();
    super.dispose();
  }
}
```

---

### **FASE 5: Interfaz de Usuario** 🎨

#### Step 5.1: Página de Notificaciones
**Archivo**: `lib/features/notifications/presentation/notifications_page.dart` (NUEVO)

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'notifications_provider.dart';
import '../../../core/models/notification.dart';

/// Página completa de notificaciones
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    
    // Configurar locale para timeago
    timeago.setLocaleMessages('es', timeago.EsMessages());
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.9) {
      // Cargar más cuando llegue al 90% del scroll
      context.read<NotificationsProvider>().loadMore();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaciones'),
        actions: [
          // Marcar todas como leídas
          Consumer<NotificationsProvider>(
            builder: (context, provider, _) {
              if (provider.unreadCount == 0) return const SizedBox.shrink();
              
              return IconButton(
                icon: const Icon(Icons.done_all),
                tooltip: 'Marcar todas como leídas',
                onPressed: () async {
                  await provider.markAllAsRead();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Todas las notificaciones marcadas como leídas'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                },
              );
            },
          ),
          
          // Eliminar todas las leídas
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'delete_read') {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Eliminar notificaciones'),
                    content: const Text(
                      '¿Eliminar todas las notificaciones leídas?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancelar'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Eliminar'),
                      ),
                    ],
                  ),
                );

                if (confirmed == true && mounted) {
                  await context.read<NotificationsProvider>().deleteAllRead();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Notificaciones eliminadas'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                }
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'delete_read',
                child: Row(
                  children: [
                    Icon(Icons.delete_sweep, size: 20),
                    SizedBox(width: 8),
                    Text('Eliminar leídas'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Consumer<NotificationsProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(provider.error!),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => provider.loadNotifications(refresh: true),
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            );
          }

          if (!provider.hasNotifications) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 80,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No tienes notificaciones',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Te notificaremos cuando haya actividad',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey.shade500,
                        ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => provider.loadNotifications(refresh: true),
            child: ListView.separated(
              controller: _scrollController,
              itemCount: provider.notifications.length + (provider.isLoadingMore ? 1 : 0),
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                if (index == provider.notifications.length) {
                  // Loading indicator al final
                  return const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final notification = provider.notifications[index];
                return NotificationTile(
                  notification: notification,
                  onTap: () => _handleNotificationTap(context, notification),
                  onDismiss: () => provider.deleteNotification(notification.id),
                );
              },
            ),
          );
        },
      ),
    );
  }

  /// Manejar tap en notificación
  void _handleNotificationTap(BuildContext context, AppNotification notification) {
    // Marcar como leída
    if (!notification.isRead) {
      context.read<NotificationsProvider>().markAsRead(notification.id);
    }

    // Navegar según el tipo
    _navigateToNotificationTarget(context, notification);
  }

  /// Navegar al destino de la notificación
  void _navigateToNotificationTarget(
    BuildContext context,
    AppNotification notification,
  ) {
    // TODO: Implementar navegación según tipo
    // Por ejemplo:
    // - review_on_my_mix → ir a MixDetailPage
    // - new_tobacco → ir a TobaccoDetailPage
    // - etc.
    
    debugPrint('Navegar a: ${notification.type} con data: ${notification.data}');
    
    // Placeholder
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Navegación a ${notification.type.toJson()} (por implementar)'),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

/// Widget para cada notificación individual
class NotificationTile extends StatelessWidget {
  const NotificationTile({
    super.key,
    required this.notification,
    required this.onTap,
    required this.onDismiss,
  });

  final AppNotification notification;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => onDismiss(),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: notification.color.withOpacity(0.2),
          child: Icon(
            notification.icon,
            color: notification.color,
            size: 20,
          ),
        ),
        title: Text(
          notification.title,
          style: TextStyle(
            fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              notification.message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              timeago.format(notification.createdAt, locale: 'es'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                  ),
            ),
          ],
        ),
        trailing: !notification.isRead
            ? Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  shape: BoxShape.circle,
                ),
              )
            : null,
      ),
    );
  }
}
```

#### Step 5.2: Icono de Notificaciones con Badge
**Archivo**: `lib/widgets/notification_icon.dart` (NUEVO)

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../features/notifications/presentation/notifications_provider.dart';
import '../features/notifications/presentation/notifications_page.dart';

/// Icono de notificaciones con badge de contador
class NotificationIcon extends StatelessWidget {
  const NotificationIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationsProvider>(
      builder: (context, provider, _) {
        return Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const NotificationsPage(),
                  ),
                );
              },
            ),
            if (provider.unreadCount > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    provider.unreadCount > 99 ? '99+' : provider.unreadCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
```

---

### **FASE 6: Integración** 🔗

#### Step 6.1: Registrar Provider en la App
**Archivo**: `lib/app.dart` (MODIFICAR)

```dart
// Añadir imports
import 'features/notifications/data/notifications_repository.dart';
import 'features/notifications/presentation/notifications_provider.dart';

// En MultiProvider, añadir:
ChangeNotifierProvider(
  create: (_) => NotificationsProvider(
    NotificationsRepository(SupabaseService()),
  ),
),
```

#### Step 6.2: Reemplazar el Icono en Main Navigation
**Archivo**: `lib/widgets/main_navigation.dart` (MODIFICAR)

Sustituir el IconButton actual de notificaciones por:
```dart
import 'notification_icon.dart';

// Donde antes estaba:
// IconButton(
//   icon: Icon(Icons.notifications_outlined),
//   ...
// )

// Ahora:
const NotificationIcon(),
```

#### Step 6.3: Añadir Dependencia timeago
**Archivo**: `pubspec.yaml` (MODIFICAR)

```yaml
dependencies:
  # ... existentes
  timeago: ^3.6.1
```

---

### **FASE 7: Scripts SQL en Supabase** 📊

#### Ejecutar en el siguiente orden:

1. **supabase_notifications_schema.sql** - Índices y constraints
2. **supabase_notifications_functions.sql** - Funciones helper
3. **supabase_notifications_triggers.sql** - Triggers automáticos

#### Habilitar Realtime (Manual)
- Database → Replication → `notifications` → Toggle ON

---

### **FASE 8: Testing & Validación** ✅

#### Checklist de Pruebas

**Base de Datos**:
- [ ] Tabla notifications existe y tiene RLS
- [ ] Funciones helper creadas correctamente
- [ ] Triggers funcionan al insertar reviews
- [ ] Triggers funcionan al insertar favoritos
- [ ] Trigger de trending funciona
- [ ] Realtime está habilitado

**Frontend**:
- [ ] Provider se inicializa correctamente
- [ ] Notificaciones se cargan al abrir la app
- [ ] Badge muestra contador correcto
- [ ] Notificaciones en tiempo real llegan
- [ ] Marcar como leída funciona
- [ ] Eliminar notificación funciona
- [ ] Scroll infinito funciona
- [ ] Navegación desde notificación (cuando se implemente)

**Casos de Prueba**:
1. Usuario A crea una mezcla
2. Usuario B añade reseña → Usuario A debe recibir notificación
3. Usuario C marca favorito → Usuario A debe recibir notificación
4. Admin añade tabaco → Todos los usuarios deben recibir notificación
5. Mezcla alcanza 4.5★ y 5 reviews → Usuario A debe recibir notificación trending

---

## 🚀 Orden de Ejecución Recomendado

### Día 1: Base de Datos
1. ✅ Ejecutar `supabase_notifications_schema.sql`
2. ✅ Ejecutar `supabase_notifications_functions.sql`
3. ✅ Ejecutar `supabase_notifications_triggers.sql`
4. ✅ Habilitar Realtime en tabla notifications
5. ✅ Probar triggers manualmente en SQL Editor

### Día 2: Modelos y Repositorio
6. ✅ Crear `lib/core/models/notification.dart`
7. ✅ Crear `lib/features/notifications/data/notifications_repository.dart`
8. ✅ Probar repositorio con datos de prueba

### Día 3: Provider y UI
9. ✅ Crear `lib/features/notifications/presentation/notifications_provider.dart`
10. ✅ Crear `lib/features/notifications/presentation/notifications_page.dart`
11. ✅ Crear `lib/widgets/notification_icon.dart`

### Día 4: Integración
12. ✅ Modificar `lib/app.dart` para registrar provider
13. ✅ Modificar `lib/widgets/main_navigation.dart` para usar NotificationIcon
14. ✅ Añadir dependencia `timeago` a `pubspec.yaml`
15. ✅ Ejecutar `flutter pub get`

### Día 5: Testing
16. ✅ Pruebas de triggers en Supabase
17. ✅ Pruebas de UI en la app
18. ✅ Pruebas de Realtime
19. ✅ Ajustes y correcciones

---

## 🎨 Mejoras Futuras (Fase 2 y 3)

### Navegación Contextual
- Implementar navegación a mix detail desde notificación `review_on_my_mix`
- Implementar navegación a tobacco detail desde `new_tobacco`
- Implementar deep linking para notificaciones push

### Notificaciones Push
- Integrar Firebase Cloud Messaging (FCM)
- Configurar Supabase Edge Functions para enviar push
- Gestionar tokens de dispositivos

### Filtros y Configuración
- Permitir al usuario elegir qué notificaciones recibir
- Filtrar notificaciones por tipo en la UI
- Configuración de notificaciones en Settings

### Analytics
- Registrar cuándo se abren notificaciones
- Métricas de engagement
- A/B testing de tipos de notificaciones

---

## 📚 Recursos y Referencias

- [Supabase Realtime Docs](https://supabase.com/docs/guides/realtime)
- [Supabase Database Triggers](https://supabase.com/docs/guides/database/postgres/triggers)
- [Flutter Provider Pattern](https://pub.dev/packages/provider)
- [TimeAgo Package](https://pub.dev/packages/timeago)

---

## ⚠️ Consideraciones Importantes

### Seguridad
- ✅ RLS habilitado en tabla notifications
- ✅ Solo el usuario puede ver sus propias notificaciones
- ✅ Triggers usan SECURITY DEFINER para bypass de RLS
- ✅ Validación de tipos de notificación con constraint

### Performance
- ✅ Índices en user_id y created_at
- ✅ Paginación implementada (50 por página)
- ✅ Scroll infinito para mejor UX
- ⚠️ Considerar limpieza automática de notificaciones antiguas

### Escalabilidad
- ⚠️ Trigger de `new_tobacco` notifica a TODOS los usuarios
  - Para apps grandes, usar queue jobs en lugar de trigger directo
- ✅ Stream de Realtime es eficiente (WebSocket)
- ✅ Queries optimizadas con índices

---

## 🎉 Resumen

Este plan implementa un **sistema completo de notificaciones en tiempo real** con:

✅ **9 tipos de notificaciones** diferentes
✅ **Triggers automáticos** en base de datos
✅ **Realtime WebSocket** para actualizaciones instantáneas
✅ **UI moderna** con badges y animaciones
✅ **Paginación** y scroll infinito
✅ **Gestión completa** (marcar leída, eliminar, etc)
✅ **Seguridad RLS** completa
✅ **Arquitectura limpia** y escalable

**Tiempo estimado de implementación**: 3-5 días
**Complejidad**: Media-Alta
**Impacto en UX**: ⭐⭐⭐⭐⭐

---

**¿Listo para comenzar? ¡Manos a la obra!** 🚀
