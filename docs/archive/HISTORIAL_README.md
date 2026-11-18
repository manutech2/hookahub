# Historial de Mezclas Visitadas - Documentación

## 📋 Descripción

Funcionalidad que registra y muestra todas las mezclas que el usuario ha visitado en los últimos 2 días. El historial se almacena en Supabase y está disponible en todos los dispositivos del usuario.

---

## 🗄️ Estructura de Base de Datos

### Tabla: `mix_views`

```sql
create table if not exists mix_views (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles(id) on delete cascade,
  mix_id uuid not null references mixes(id) on delete cascade,
  viewed_at timestamp with time zone default now() not null
);
```

**Índices creados:**
- `idx_mix_views_user_id` - Búsquedas por usuario
- `idx_mix_views_mix_id` - Búsquedas por mezcla
- `idx_mix_views_viewed_at` - Ordenamiento por fecha
- `idx_mix_views_user_viewed` - Combinado para consultas optimizadas

**Función SQL disponible:**
- `clean_old_mix_views(days_to_keep)` - Limpia vistas antiguas (útil para mantenimiento)

---

## 📁 Arquitectura (Clean Architecture)

```
lib/features/history/
├── domain/
│   └── visit_entry.dart          # Modelo de entrada de historial
├── data/
│   └── history_repository.dart   # Lógica de datos con Supabase
├── presentation/
│   └── history_provider.dart     # Estado con Provider
└── history_page.dart              # Interfaz de usuario
```

---

## 🎯 Características Implementadas

### ✅ Registro Automático
- Cada vez que se abre `MixDetailPage`, se registra la visita automáticamente
- El registro es silencioso (no interfiere con la UI)
- No requiere acción del usuario

### ✅ Visualización del Historial
- **Agrupación por días**: "Hoy", "Ayer", "Hace 2 días"
- **Ordenamiento**: Más recientes primero
- **Estadísticas**: Muestra cuántas mezclas únicas se visitaron
- **Diseño consistente**: Usa `MixCard` como en otras secciones

### ✅ Gestión de Datos
- **Limpiar todo**: Borra todo el historial del usuario
- **Limpiar antiguos**: Elimina vistas de hace más de 7 días
- **Refresh**: Pull-to-refresh para actualizar

### ✅ Navegación
- Desde el botón "Historial" en `ProfilePage`
- Al tocar una mezcla, navega a `MixDetailPage`
- Integración con favoritos (corazón en cada tarjeta)

---

## 🔧 Configuración Requerida

### 1. Ejecutar Script SQL en Supabase

**Importante**: Debes ejecutar el archivo `supabase_mix_views.sql` en tu proyecto de Supabase:

```bash
# Opción 1: Desde el dashboard de Supabase
# - Ve a SQL Editor
# - Copia y pega el contenido de supabase_mix_views.sql
# - Ejecuta

# Opción 2: Usando CLI de Supabase (si la tienes instalada)
supabase db push
```

### 2. Políticas RLS (Row Level Security)

Asegúrate de crear las políticas de seguridad en Supabase:

```sql
-- Política: Los usuarios solo pueden ver su propio historial
create policy "Users can view own history"
  on mix_views for select
  using (auth.uid() = user_id);

-- Política: Los usuarios pueden insertar en su propio historial
create policy "Users can insert own history"
  on mix_views for insert
  with check (auth.uid() = user_id);

-- Política: Los usuarios pueden eliminar su propio historial
create policy "Users can delete own history"
  on mix_views for delete
  using (auth.uid() = user_id);
```

---

## 🚀 Uso

### Código ya integrado:

1. **Provider registrado** en `app.dart`:
```dart
ChangeNotifierProvider(
  create: (_) => HistoryProvider(HistoryRepository(SupabaseService())),
),
```

2. **Registro automático** en `MixDetailPage`:
```dart
void _recordVisit() {
  // Se ejecuta automáticamente al abrir una mezcla
  context.read<HistoryProvider>().recordView(widget.mix.id, silent: true);
}
```

3. **Navegación** desde `ProfilePage`:
```dart
Navigator.push(
  context,
  MaterialPageRoute(builder: (_) => const HistoryPage()),
);
```

---

## 📊 API del HistoryProvider

### Métodos principales:

```dart
// Cargar historial (últimos 2 días)
await historyProvider.load();

// Registrar visita
await historyProvider.recordView(mixId, silent: true);

// Limpiar todo
await historyProvider.clearAll();

// Limpiar antiguos (más de 7 días)
await historyProvider.clearOld(days: 7);

// Refrescar
await historyProvider.refresh();
```

### Propiedades:

```dart
historyProvider.entries          // Lista de VisitEntry
historyProvider.uniqueCount      // Mezclas únicas visitadas
historyProvider.groupedByDay     // Entradas agrupadas por día
historyProvider.uniqueEntries    // Solo la visita más reciente de cada mezcla
historyProvider.isLoading        // Estado de carga
historyProvider.error            // Error si existe
```

---

## 🎨 UI/UX

### Estados manejados:
- ✅ Cargando (spinner)
- ✅ Vacío (ilustración con mensaje)
- ✅ Error (mensaje + botón reintentar)
- ✅ Contenido (lista agrupada)

### Acciones disponibles:
- **Pull-to-refresh**: Actualizar historial
- **Menú superior**:
  - Limpiar antiguos (>7 días)
  - Borrar todo (con confirmación)
- **Tap en mezcla**: Navega a detalle
- **Tap en corazón**: Añadir/quitar favoritos

---

## ⚙️ Personalización

### Cambiar el período de historial:

En `history_repository.dart`, modifica el parámetro `days`:

```dart
Future<List<VisitEntry>> fetchRecentHistory({
  int days = 2,  // Cambia esto a 7, 14, 30, etc.
  int limit = 100,
})
```

### Cambiar días para limpieza automática:

```dart
await historyProvider.clearOld(days: 30); // Cambiar 7 por el valor deseado
```

---

## 🐛 Troubleshooting

### Error: "No se pudo registrar visita en historial"
**Causa**: La tabla `mix_views` no existe en Supabase.  
**Solución**: Ejecuta el script SQL `supabase_mix_views.sql`.

### Error: "new row violates row-level security policy"
**Causa**: Faltan políticas RLS en la tabla.  
**Solución**: Crea las políticas de seguridad mencionadas arriba.

### No aparecen mezclas en el historial
**Verificar**:
1. ¿Se visitaron mezclas en los últimos 2 días?
2. ¿El usuario está autenticado?
3. ¿Las políticas RLS permiten SELECT para el usuario?

---

## 📈 Métricas y Analytics (Opcional)

Puedes añadir funcionalidad para:
- Ver la mezcla más visitada
- Tiempo promedio de visualización
- Patrones de navegación
- Exportar historial

---

## 🔐 Seguridad

- ✅ Row Level Security habilitado
- ✅ Solo el usuario ve su propio historial
- ✅ Cascada de eliminación al borrar usuario
- ✅ Validación de autenticación en todas las operaciones

---

## 📝 Notas Técnicas

- **Rendimiento**: Índices optimizados para consultas rápidas
- **Escalabilidad**: Diseñado para manejar miles de visitas por usuario
- **Privacidad**: Los datos son privados por usuario
- **Mantenimiento**: Función SQL incluida para limpiar datos antiguos

---

## 🎯 Próximas Mejoras Sugeridas

1. **Cache local** con SharedPreferences para acceso offline
2. **Analytics** de mezclas más visitadas
3. **Filtros** por rango de fechas personalizado
4. **Exportar** historial a PDF/CSV
5. **Sugerencias** basadas en historial de visitas
6. **Notificaciones** cuando una mezcla visitada recibe actualizaciones

---

**Desarrollado con Clean Architecture + Provider**  
**Última actualización**: 30 de octubre de 2025
