# 🔧 Activar Filtros de Rating/Reviews - Guía de Migración

## ⚠️ Estado Actual

Los filtros "Populares" y "Mejor valorados" están **temporalmente deshabilitados** porque faltan las columnas `rating` y `reviews` en la tabla `tobaccos` de Supabase.

**Comportamiento temporal:**
- Los filtros funcionan pero ordenan por fecha (`created_at`) en lugar de por rating/reviews
- No se muestran errores al usuario
- La UI está completamente implementada y lista

---

## 🚀 Pasos para Activar las Funcionalidades Completas

### Paso 1: Ejecutar Migración SQL en Supabase

1. Abre tu proyecto en [Supabase Dashboard](https://app.supabase.com)
2. Ve a **SQL Editor** en el menú lateral
3. Crea una nueva consulta
4. Copia y pega el siguiente código SQL:

```sql
-- Añadir columnas de rating y reviews a tobaccos
ALTER TABLE tobaccos 
  ADD COLUMN IF NOT EXISTS rating FLOAT DEFAULT 0,
  ADD COLUMN IF NOT EXISTS reviews INTEGER DEFAULT 0;

-- Crear índices para mejorar el rendimiento
CREATE INDEX IF NOT EXISTS idx_tobaccos_rating ON tobaccos(rating DESC);
CREATE INDEX IF NOT EXISTS idx_tobaccos_reviews ON tobaccos(reviews DESC);
CREATE INDEX IF NOT EXISTS idx_tobaccos_rating_reviews ON tobaccos(rating DESC, reviews DESC);

-- Comentarios para documentación
COMMENT ON COLUMN tobaccos.rating IS 'Calificación promedio del tabaco (0-5 estrellas)';
COMMENT ON COLUMN tobaccos.reviews IS 'Número total de reseñas del tabaco';
```

5. Haz clic en **Run** o presiona `Ctrl+Enter`
6. Verifica que la consulta se ejecutó exitosamente

### Paso 2: Actualizar el Código de Flutter

Una vez ejecutada la migración SQL, debes descomentar el código en estos archivos:

#### 📄 `lib/features/catalog/data/tobacco_repository.dart`

**Línea ~19:** Añadir campos a la consulta SELECT
```dart
// ANTES (temporal):
.select('id, name, brand, description, image_url, created_at')

// DESPUÉS:
.select('id, name, brand, description, image_url, rating, reviews, created_at')
```

**Línea ~48:** Mapear campos de rating/reviews
```dart
// ANTES (temporal):
rating: 0.0, // (map['rating'] as num?)?.toDouble() ?? 0.0,
reviews: 0, // (map['reviews'] as int?) ?? 0,

// DESPUÉS:
rating: (map['rating'] as num?)?.toDouble() ?? 0.0,
reviews: (map['reviews'] as int?) ?? 0,
```

**Línea ~37-62:** Descomentar ordenamiento por rating/reviews
```dart
// Descomentar todas las líneas que empiezan con:
// request = request.order('reviews', ascending: false);
// request = request.order('rating', ascending: false);
```

**Línea ~67:** Actualizar método findByNameAndBrand
```dart
// ANTES (temporal):
.select('id, name, brand, description, image_url, created_at')

// DESPUÉS:
.select('id, name, brand, description, image_url, rating, reviews, created_at')
```

**Línea ~77:** Mapear campos en findByNameAndBrand
```dart
// ANTES (temporal):
rating: 0.0, // (map['rating'] as num?)?.toDouble() ?? 0.0,
reviews: 0, // (map['reviews'] as int?) ?? 0,

// DESPUÉS:
rating: (map['rating'] as num?)?.toDouble() ?? 0.0,
reviews: (map['reviews'] as int?) ?? 0,
```

### Paso 3: Verificar y Probar

1. Guarda todos los archivos
2. Ejecuta `flutter analyze` para verificar que no hay errores:
   ```bash
   flutter analyze lib/features/catalog/
   ```

3. Ejecuta la aplicación:
   ```bash
   flutter run
   ```

4. Prueba los filtros:
   - Selecciona "Populares" → Debería ordenar por reviews
   - Selecciona "Mejor valorados" → Debería ordenar por rating
   - Usa el dropdown y selecciona "Populares" o "Mejor valorados"

---

## 📊 Actualización de Datos de Rating/Reviews

Los campos se crean con valores por defecto de `0`, pero deberías implementar una de estas opciones:

### Opción 1: Trigger Automático (Recomendado)

Crea un trigger que actualice rating/reviews cuando se añadan reseñas:

```sql
-- Función para actualizar rating y reviews de un tabaco
CREATE OR REPLACE FUNCTION update_tobacco_rating()
RETURNS TRIGGER AS $$
BEGIN
  -- Calcular rating promedio y total de reviews
  UPDATE tobaccos
  SET 
    rating = (
      SELECT COALESCE(AVG(rating), 0)
      FROM reviews r
      JOIN mixes m ON r.mix_id = m.id
      JOIN mix_components mc ON mc.mix_id = m.id
      WHERE mc.tobacco_name = tobaccos.name 
        AND mc.brand = tobaccos.brand
    ),
    reviews = (
      SELECT COUNT(*)
      FROM reviews r
      JOIN mixes m ON r.mix_id = m.id
      JOIN mix_components mc ON mc.mix_id = m.id
      WHERE mc.tobacco_name = tobaccos.name 
        AND mc.brand = tobaccos.brand
    )
  WHERE id = NEW.id;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Crear trigger
CREATE TRIGGER trigger_update_tobacco_rating
AFTER INSERT OR UPDATE OR DELETE ON reviews
FOR EACH ROW
EXECUTE FUNCTION update_tobacco_rating();
```

### Opción 2: Script Manual

Ejecuta periódicamente para actualizar los valores:

```sql
-- Actualizar rating y reviews de todos los tabacos
UPDATE tobaccos t
SET 
  rating = COALESCE((
    SELECT AVG(r.rating)
    FROM reviews r
    JOIN mixes m ON r.mix_id = m.id
    JOIN mix_components mc ON mc.mix_id = m.id
    WHERE mc.tobacco_name = t.name 
      AND mc.brand = t.brand
  ), 0),
  reviews = COALESCE((
    SELECT COUNT(*)
    FROM reviews r
    JOIN mixes m ON r.mix_id = m.id
    JOIN mix_components mc ON mc.mix_id = m.id
    WHERE mc.tobacco_name = t.name 
      AND mc.brand = t.brand
  ), 0);
```

### Opción 3: Valores de Prueba

Para testing rápido, inserta valores aleatorios:

```sql
-- Actualizar con valores aleatorios para testing
UPDATE tobaccos
SET 
  rating = ROUND((RANDOM() * 5)::numeric, 1),
  reviews = FLOOR(RANDOM() * 100)::INTEGER;
```

---

## ✅ Checklist de Activación

- [ ] Ejecutar migración SQL en Supabase Dashboard
- [ ] Verificar que las columnas se crearon correctamente
- [ ] Descomentar línea ~19: SELECT con rating/reviews
- [ ] Descomentar línea ~48: Mapeo de rating/reviews
- [ ] Descomentar líneas ~37-62: Ordenamiento por rating/reviews
- [ ] Descomentar línea ~67: SELECT en findByNameAndBrand
- [ ] Descomentar línea ~77: Mapeo en findByNameAndBrand
- [ ] Ejecutar `flutter analyze`
- [ ] Probar en la app los filtros "Populares" y "Mejor valorados"
- [ ] (Opcional) Implementar trigger para actualización automática
- [ ] (Opcional) Insertar datos de prueba o calcular ratings existentes

---

## 🐛 Troubleshooting

### Error: "column tobaccos.rating does not exist"
- **Causa**: No se ejecutó la migración SQL
- **Solución**: Ejecutar el Paso 1

### Los filtros no muestran diferencias
- **Causa**: Todos los tabacos tienen rating=0 y reviews=0
- **Solución**: Ejecutar alguna de las opciones de actualización de datos

### Error de compilación después de descomentar
- **Causa**: Sintaxis incorrecta al descomentar
- **Solución**: Verificar que se eliminaron correctamente los `//` y `/**/`

---

**Archivo original con TODOs**: `lib/features/catalog/data/tobacco_repository.dart`  
**Script SQL completo**: `supabase_add_tobacco_ratings.sql`  
**Documentación completa**: `CATALOG_FILTERS_IMPLEMENTATION.md`
