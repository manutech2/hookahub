# 🔄 Actualización: Evitar Duplicados en Historial

## 📋 Problema Resuelto
Las mezclas aparecían repetidas cada vez que se visitaban. Ahora solo aparece una vez con la última fecha de visita.

---

## ✅ Solución Implementada

### Enfoque: UPSERT (Insert or Update)

Cuando visitas una mezcla:
- **Primera vez**: Se crea un nuevo registro
- **Visitas siguientes**: Se actualiza la fecha/hora del registro existente

**Resultado**: Una mezcla = Un registro por usuario

---

## 🔧 Cambios Realizados

### 1. **Base de Datos** (Supabase)

#### a) Constraint UNIQUE
**Archivo**: `supabase_mix_views.sql`

Añadida restricción única:
```sql
CONSTRAINT unique_user_mix UNIQUE (user_id, mix_id)
```

Esto garantiza que un usuario solo puede tener un registro por mezcla.

#### b) Política RLS UPDATE
**Archivo**: `supabase_mix_views_rls.sql`

Nueva política para permitir actualizaciones:
```sql
create policy "Users can update own history"
  on mix_views for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
```

### 2. **Código Dart**

#### a) Método UPSERT
**Archivo**: `lib/features/history/data/history_repository.dart`

```dart
// ANTES (INSERT - creaba duplicados)
await _supabase.client.from('mix_views').insert({...});

// AHORA (UPSERT - inserta o actualiza)
await _supabase.client.from('mix_views').upsert(
  {...},
  onConflict: 'user_id,mix_id',
);
```

#### b) Conteo Simplificado
Ya no necesitamos filtrar duplicados en el código porque la DB lo hace automáticamente.

#### c) Eliminado método `uniqueEntries`
Ya no es necesario porque todos los registros son únicos.

---

## 🚀 Cómo Aplicar los Cambios

### Paso 1: Ejecutar Script de Migración en Supabase

**Archivo**: `supabase_mix_views_migration.sql`

Este script:
1. ✅ Elimina duplicados existentes (mantiene solo la visita más reciente)
2. ✅ Añade la constraint UNIQUE
3. ✅ Verifica que no queden duplicados

**Dashboard de Supabase → SQL Editor → Pegar y ejecutar**

### Paso 2: Actualizar Políticas RLS

**Archivo**: `supabase_mix_views_rls.sql`

Ejecutar la nueva política UPDATE:
```sql
create policy "Users can update own history"
  on mix_views for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
```

### Paso 3: Código Ya Actualizado ✅

El código Dart ya está listo. Solo necesitas:
```bash
flutter run
```

---

## 📊 Verificación

### Antes de la migración:
```sql
-- Ver duplicados
SELECT user_id, mix_id, COUNT(*) as count
FROM mix_views
GROUP BY user_id, mix_id
HAVING COUNT(*) > 1;
```

Si tienes duplicados, verás algo como:
```
user_id          | mix_id          | count
abc-123...       | mix-xyz...      | 3
```

### Después de la migración:
```sql
-- Esta consulta debe retornar 0 filas
SELECT user_id, mix_id, COUNT(*) as count
FROM mix_views
GROUP BY user_id, mix_id
HAVING COUNT(*) > 1;
```

Resultado esperado: **0 filas** (sin duplicados)

---

## 🧪 Cómo Probar

1. **Ejecuta los scripts SQL** en Supabase
2. **Ejecuta la app**:
   ```bash
   flutter run
   ```
3. **Visita una mezcla** (Comunidad → Abre una mezcla)
4. **Ve al historial** (Perfil → Historial)
5. **Visita la MISMA mezcla de nuevo**
6. **Ve al historial otra vez**
7. **Resultado esperado**: 
   - Solo aparece UNA VEZ
   - La hora es la de la ÚLTIMA visita

---

## 📈 Antes vs Después

### ANTES:
```
Historial
---------
Hoy
  - Mezcla Tropical (15:30)  ← Primera visita
  - Mezcla Menta (15:00)
  - Mezcla Tropical (14:00)  ← Segunda visita (DUPLICADO)

Resultado: 3 entradas, pero solo 2 mezclas únicas
```

### DESPUÉS:
```
Historial
---------
Hoy
  - Mezcla Tropical (15:30)  ← Solo la última visita
  - Mezcla Menta (15:00)

Resultado: 2 entradas = 2 mezclas únicas (sin duplicados)
```

---

## 🔍 Consultas SQL Útiles

### Ver historial completo:
```sql
SELECT 
  mv.viewed_at,
  m.name as mix_name,
  p.username as author
FROM mix_views mv
LEFT JOIN mixes m ON mv.mix_id = m.id
LEFT JOIN profiles p ON m.author_id = p.id
WHERE mv.user_id = 'TU-USER-ID'
ORDER BY mv.viewed_at DESC;
```

### Contar visitas por mezcla:
```sql
SELECT 
  m.name as mix_name,
  COUNT(*) as total_usuarios_visitaron
FROM mix_views mv
JOIN mixes m ON mv.mix_id = m.id
GROUP BY m.id, m.name
ORDER BY total_usuarios_visitaron DESC;
```

---

## ⚠️ Notas Importantes

1. **Los datos históricos se preservan**: El script de migración mantiene la visita más reciente de cada mezcla.

2. **No hay pérdida de datos**: Solo se eliminan los duplicados antiguos.

3. **Automático desde ahora**: Una vez aplicada la constraint, es imposible crear duplicados.

4. **Compatible con versión anterior**: Si no ejecutas el script de migración, el código nuevo seguirá funcionando (solo que con duplicados en la DB hasta que migres).

---

## 🎯 Beneficios

✅ Base de datos más limpia
✅ Consultas más rápidas
✅ Menos almacenamiento usado
✅ Comportamiento esperado por el usuario
✅ Consistente con otros historiales (Chrome, YouTube, etc.)

---

## 📝 Archivos Modificados

### SQL:
- ✅ `supabase_mix_views.sql` - Constraint UNIQUE añadida
- ✅ `supabase_mix_views_rls.sql` - Política UPDATE añadida
- ✅ `supabase_mix_views_migration.sql` - Nuevo script de migración

### Dart:
- ✅ `lib/features/history/data/history_repository.dart` - UPSERT implementado
- ✅ `lib/features/history/presentation/history_provider.dart` - Simplificado

---

**Última actualización**: 30 de octubre de 2025
**Estado**: ✅ Listo para producción
