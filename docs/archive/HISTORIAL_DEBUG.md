# 🐛 Debugging: Historial de Mezclas

## Problema Reportado
Las visitas se registran en Supabase pero no aparecen en el historial.

---

## ✅ Cambios Realizados

### 1. Corregido JOIN en la consulta SQL
**Archivo**: `lib/features/history/data/history_repository.dart`

**Antes**: Usaba `mixes!inner(...)` 
**Ahora**: Usa `mixes(...)` (LEFT JOIN)

**Razón**: Si una mezcla fue eliminada, el INNER JOIN excluía esa entrada del historial.

### 2. Mejorado manejo de errores
**Archivo**: `lib/features/history/domain/visit_entry.dart`

- ✅ Manejo de mezclas eliminadas
- ✅ Logging detallado para debugging
- ✅ Try-catch con stack trace

### 3. Añadido logging extensivo
**Archivo**: `lib/features/history/data/history_repository.dart`

- ✅ Log del usuario actual
- ✅ Log de la fecha límite
- ✅ Log de la respuesta raw de Supabase
- ✅ Log del número de registros
- ✅ Log de cada entrada procesada

### 4. Widget de Debug
**Archivo**: `lib/widgets/history_debug_widget.dart`

Widget especial para debugging en tiempo real.

---

## 🔍 Cómo Debuggear

### Opción 1: Ver Logs en Consola

1. **Ejecuta la app en debug mode**:
   ```bash
   flutter run
   ```

2. **Visita algunas mezclas**:
   - Ve a Community
   - Abre 2-3 mezclas diferentes
   - Cierra y vuelve a abrir

3. **Ve al historial**:
   - Perfil → Historial

4. **Revisa la consola** y busca logs que empiezan con:
   - 🔍 (información de debugging)
   - ✅ (éxito)
   - ⚠️ (advertencia)
   - ❌ (error)

**Logs esperados**:
```
🔍 Cargando historial para usuario: abc-123-xyz
🔍 Fecha límite: 2025-10-28T10:30:00.000Z
🔍 Respuesta raw de Supabase: [{...}, {...}]
🔍 Tipo de respuesta: List<dynamic>
🔍 Número de registros: 3
🔍 Procesando entrada: {id: ..., mix_id: ..., viewed_at: ...}
🔍 VisitEntry.fromMap recibió: {id: ..., mixes: {...}}
✅ VisitEntry creada: Mezcla de Menta
✅ Historial cargado: 3 entradas
```

### Opción 2: Usar Widget de Debug

1. **Añade ruta temporal** en tu app:

```dart
// En algún lugar de tu código de navegación (temporal)
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => HistoryDebugWidget(),
  ),
);
```

2. **Navega al widget de debug**

3. **Verás información detallada**:
   - Estado del provider
   - Todas las entradas cargadas
   - Agrupación por día

---

## 🔧 Verificaciones en Supabase

### 1. Verificar que hay datos en mix_views

**Dashboard de Supabase → Table Editor → mix_views**

Deberías ver registros como:
```
id                | user_id         | mix_id          | viewed_at
uuid              | uuid            | uuid            | timestamp
------------------------------------------------------------------
abc-123...        | user-id...      | mix-id-1...     | 2025-10-30 15:30:00
def-456...        | user-id...      | mix-id-2...     | 2025-10-30 14:20:00
```

### 2. Verificar que las mezclas existen

**Dashboard de Supabase → SQL Editor**

```sql
-- Ver visitas con información de mezclas
SELECT 
  mv.id,
  mv.user_id,
  mv.mix_id,
  mv.viewed_at,
  m.name as mix_name,
  m.rating,
  m.reviews
FROM mix_views mv
LEFT JOIN mixes m ON mv.mix_id = m.id
WHERE mv.viewed_at >= NOW() - INTERVAL '2 days'
ORDER BY mv.viewed_at DESC
LIMIT 20;
```

**Resultado esperado**: Deberías ver todas las visitas con los nombres de las mezclas.

**Si `mix_name` es NULL**: La mezcla fue eliminada (esto está OK, ahora lo manejamos).

### 3. Verificar políticas RLS

**Dashboard de Supabase → Authentication → Policies → mix_views**

Deberías ver 3 políticas:
- ✅ Users can view own history (SELECT)
- ✅ Users can insert own history (INSERT)
- ✅ Users can delete own history (DELETE)

**Probar política SELECT**:
```sql
-- Ejecuta como usuario autenticado
SELECT * FROM mix_views 
WHERE user_id = auth.uid()
ORDER BY viewed_at DESC
LIMIT 10;
```

---

## 🐞 Problemas Comunes y Soluciones

### Problema 1: "No hay entradas en el historial"

**Causas posibles**:
1. Las visitas son más antiguas de 2 días
2. El user_id no coincide
3. Las políticas RLS bloquean la consulta

**Solución**:
```sql
-- Ver TODAS las visitas del usuario (ignora fecha)
SELECT * FROM mix_views 
WHERE user_id = 'TU-USER-ID-AQUI'
ORDER BY viewed_at DESC;
```

### Problema 2: "Error al cargar historial"

**Ver el error exacto** en los logs de la consola.

**Errores comunes**:
- `relation "mix_views" does not exist` → No ejecutaste el SQL
- `permission denied` → Falta política RLS
- `JWT expired` → Token de autenticación vencido

### Problema 3: Las visitas no se registran

**Verificar** que `MixDetailPage` llama a `_recordVisit()`:

```dart
@override
void initState() {
  super.initState();
  _currentMix = widget.mix;
  _loadMixDetails();
  _loadRelatedMixes();
  _loadReviews();
  _checkOwnership();
  _recordVisit(); // ← Debe estar aquí
}
```

**Ver logs** cuando abres una mezcla:
```
No se pudo registrar visita en historial: ...
```

---

## 📝 Checklist de Debugging

- [ ] Ejecuté los scripts SQL en Supabase
- [ ] Verifiqué que hay datos en `mix_views`
- [ ] Las políticas RLS están activas
- [ ] Ejecuté `flutter run` y vi los logs
- [ ] Visité al menos 3 mezclas diferentes
- [ ] Esperé unos segundos después de visitar
- [ ] Fui a Perfil → Historial
- [ ] Revisé los logs en la consola
- [ ] Probé el widget de debug (opcional)

---

## 📧 Información para Reportar

Si el problema persiste, copia y pega:

1. **Logs de la consola** (todo lo que empieza con 🔍, ✅, ⚠️, ❌)

2. **Resultado de esta consulta SQL**:
```sql
SELECT 
  mv.id,
  mv.user_id,
  mv.mix_id,
  mv.viewed_at,
  m.name as mix_name
FROM mix_views mv
LEFT JOIN mixes m ON mv.mix_id = m.id
WHERE mv.viewed_at >= NOW() - INTERVAL '2 days'
ORDER BY mv.viewed_at DESC
LIMIT 10;
```

3. **Estado del provider** (desde el widget de debug)

---

## 🚀 Próximos Pasos

1. **Ejecuta la app** con las correcciones
2. **Revisa los logs** en la consola
3. **Comparte los logs** para análisis más profundo

---

**Cambios aplicados**: 30 de octubre de 2025
