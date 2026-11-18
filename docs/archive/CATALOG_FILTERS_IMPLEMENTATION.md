# Sistema de Filtros del Catálogo de Tabacos

## 📋 Resumen

Se ha implementado un sistema completo de filtros para el catálogo de tabacos con tres tipos de filtrado:

1. **Filtros rápidos** (Quick Filters): Todos, Populares, Mejor valorados
2. **Filtros por marca** (Brand Filters): Marcas dinámicas cargadas desde BD
3. **Ordenamiento** (Sort Options): Dropdown con múltiples opciones

---

## 🎯 Filtros Rápidos

### Ubicación
A la derecha del dropdown de ordenamiento, antes del separador de marcas.

### Opciones disponibles:
- **📋 Todos**: Muestra todos los tabacos (sin filtro especial)
- **📈 Populares**: Muestra los tabacos con más reseñas primero
- **⭐ Mejor valorados**: Muestra los tabacos con mayor rating primero

### Comportamiento:
- Los filtros rápidos son **mutuamente exclusivos** con los filtros de marca
- Al seleccionar un filtro rápido, se deseleccionan automáticamente las marcas
- Al seleccionar una marca, el filtro rápido vuelve a "Todos"
- Tienen iconos distintivos para mejor identificación visual

---

## 🏷️ Filtros por Marca

### Ubicación
Después del separador visual (línea vertical), a la derecha de los filtros rápidos.

### Características:
- **Dinámicos**: Se cargan desde la base de datos
- **Únicos**: No hay marcas duplicadas
- **Ordenados**: Alfabéticamente
- Se desactivan cuando hay un filtro rápido activo

---

## 🔽 Dropdown de Ordenamiento

### Ubicación
Primera posición a la izquierda de todos los filtros.

### Diseño:
- Botón con gradiente sutil del color primario
- Icono de ordenamiento (`sort_rounded`)
- Texto del filtro actual visible
- Flecha dropdown animada
- Sombra suave

### Opciones disponibles:

#### Ordenamiento General:
1. **⏱️ Más recientes** (por defecto)
2. **📜 Más antiguos**
3. **⬆️ Alfabético A-Z**
4. **⬇️ Alfabético Z-A**
5. **🏢 Marca A-Z**

#### Ordenamiento por Popularidad:
6. **📈 Populares** - Ordenado por número de reseñas (desc) → rating (desc)
7. **⭐ Mejor valorados** - Ordenado por rating (desc) → reseñas (desc)

### Características visuales:
- **Header** con título "Ordenar por"
- **Separador** visual entre header y opciones
- **Checkmark animado** en la opción seleccionada
- **Fondo destacado** en opción activa con animación suave (200ms)
- **Iconos descriptivos** para cada opción
- **Animación de apertura/cierre** suave

---

## 🗄️ Cambios en la Base de Datos

### Migración SQL requerida

Se debe ejecutar el archivo `supabase_add_tobacco_ratings.sql`:

```sql
ALTER TABLE tobaccos 
  ADD COLUMN IF NOT EXISTS rating FLOAT DEFAULT 0,
  ADD COLUMN IF NOT EXISTS reviews INTEGER DEFAULT 0;

CREATE INDEX IF NOT EXISTS idx_tobaccos_rating ON tobaccos(rating DESC);
CREATE INDEX IF NOT EXISTS idx_tobaccos_reviews ON tobaccos(reviews DESC);
CREATE INDEX IF NOT EXISTS idx_tobaccos_rating_reviews ON tobaccos(rating DESC, reviews DESC);
```

### Nuevos campos:
- `rating` (FLOAT): Calificación promedio 0-5 estrellas
- `reviews` (INTEGER): Número total de reseñas

### Índices creados:
- `idx_tobaccos_rating`: Para ordenamiento por rating
- `idx_tobaccos_reviews`: Para ordenamiento por reviews
- `idx_tobaccos_rating_reviews`: Para ordenamiento combinado

---

## 📁 Archivos Modificados/Creados

### Nuevos archivos:
1. `lib/features/catalog/domain/catalog_filters.dart`
   - Enum `SortOption` (7 opciones)
   - Enum `QuickFilter` (3 opciones)
   - Class `CatalogFilter`

2. `supabase_add_tobacco_ratings.sql`
   - Migración para añadir campos de rating/reviews

### Archivos modificados:
1. `lib/features/catalog/data/tobacco_repository.dart`
   - Método `fetchTobaccos()`: Soporte para filtros y ordenamiento
   - Método `findByNameAndBrand()`: Lectura de rating/reviews
   - Nuevo método `fetchAvailableBrands()`: Obtiene marcas únicas

2. `lib/features/catalog/presentation/providers/catalog_provider.dart`
   - Nuevo estado `CatalogFilter`
   - Métodos `setQuickFilter()`, `setFilterByBrand()`, `setSortOption()`
   - Carga automática de marcas disponibles

3. `lib/features/catalog/catalog_page.dart`
   - Nuevo método `_buildSortDropdown()`: Dropdown atractivo
   - Nuevo método `_buildQuickFilterChip()`: Chips con iconos
   - Método `_getSortIcon()`: Iconos para cada opción de ordenamiento
   - UI actualizada con todos los filtros

---

## 🎨 Características de la UI

### Responsive
- Se adapta al `scaleFactor` del texto
- Alturas y tamaños ajustables según accesibilidad

### Animaciones
- Transición suave de 200ms con `Curves.easeInOut`
- `AnimatedContainer` en selección de opciones
- Efecto visual al abrir/cerrar dropdown

### Colores
- Usa el `primaryColor` del tema
- Opacidades y gradientes sutiles
- Bordes y sombras consistentes con el diseño

### Accesibilidad
- Iconos descriptivos
- Labels claros
- Tooltips informativos
- Estados visuales distintivos

---

## 🔄 Flujo de Interacción

1. Usuario abre el catálogo → Se cargan marcas disponibles
2. Usuario selecciona filtro rápido "Populares" → Lista se reordena por reviews
3. Usuario cambia a marca específica → Filtro rápido vuelve a "Todos"
4. Usuario usa dropdown de ordenamiento → Se aplica nuevo orden
5. Pull-to-refresh → Recarga con filtros actuales

### Prioridad de Filtros:
1. **Filtro rápido** (si != "Todos") → Ignora ordenamiento del dropdown
2. **Ordenamiento dropdown** (si filtro rápido == "Todos")
3. **Filtro de marca** (se aplica siempre, combinado con lo anterior)

---

## ⚠️ Notas Importantes

1. **Datos de prueba**: Actualmente, si no hay datos de rating/reviews en la BD, los filtros "Populares" y "Mejor valorados" no mostrarán diferencias notables.

2. **Migración requerida**: Se debe ejecutar `supabase_add_tobacco_ratings.sql` en la base de datos de producción.

3. **Actualización de datos**: Se recomienda implementar un trigger o función que calcule automáticamente el rating promedio cuando se añadan reseñas.

4. **Performance**: Los índices creados mejoran significativamente el rendimiento de queries ordenadas por rating/reviews.

---

## 🚀 Próximos Pasos Sugeridos

1. Implementar sistema de reseñas para tabacos
2. Crear trigger que actualice rating/reviews automáticamente
3. Añadir más filtros (por sabores, categorías, etc.)
4. Implementar búsqueda por texto en el catálogo
5. Añadir filtro por rango de precio (cuando esté disponible)

---

**Fecha de implementación**: 10 de noviembre de 2025  
**Autor**: Senior Flutter Developer
