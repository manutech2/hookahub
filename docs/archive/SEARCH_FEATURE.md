# Funcionalidad de Búsqueda Global

## 📋 Descripción

Se ha implementado una funcionalidad de búsqueda global que permite buscar tanto **tabacos del catálogo** como **mezclas de la comunidad** desde la barra de navegación superior.

## ✨ Características

### 🔍 Búsqueda Inline Animada
- El campo de búsqueda se abre **directamente en la barra superior** con una animación suave
- Al tocar la lupa, el título se reemplaza por un campo de texto animado
- El icono de la lupa se transforma en un icono de cerrar con rotación y fade
- Los botones laterales (crear mezcla y notificaciones) se ocultan durante la búsqueda para dar espacio

### 🎯 Búsqueda Inteligente
La búsqueda funciona en:

**Tabacos:**
- Nombre del tabaco
- Marca
- Descripción

**Mezclas:**
- Nombre de la mezcla
- Ingredientes/tabacos que contiene
- Autor de la mezcla

### 📱 Página de Resultados

La `SearchResultsPage` presenta los resultados de forma atractiva:

- **Contador de resultados** en la parte superior
- **Secciones separadas** para Tabacos y Mezclas con iconos distintivos
- **Contador de resultados por categoría** (badges con el número)
- **Tarjetas interactivas** con toda la información relevante:
  - Para tabacos: nombre, marca, descripción/sabores
  - Para mezclas: nombre, autor, ingredientes, rating
- **Estado vacío elegante** cuando no hay resultados
- **Navegación a detalles** al tocar cualquier resultado
- **Gestión de favoritos** directamente desde los resultados de mezclas

## 🏗️ Arquitectura

### Nuevos Archivos

```
lib/features/search/
├── search_provider.dart          # Provider con lógica de búsqueda
└── search_results_page.dart      # UI de resultados
```

### Provider Pattern

Se creó un `SearchProvider` que:
- Centraliza la lógica de búsqueda
- Realiza búsquedas paralelas en ambos repositorios
- Gestiona estados de carga
- Expone resultados de forma reactiva

### Integración

1. **app.dart**: Se registró `SearchProvider` en el árbol de Providers
2. **main_navigation.dart**: Se conectó el campo de búsqueda inline
3. Se reutilizaron widgets existentes: `TobaccoCard` y `MixCard`

## 🎨 Diseño

- **Modo claro/oscuro**: Totalmente soportado
- **Gradientes coherentes**: Igual que la AppBar principal
- **Colores del tema**: Respeta los colores primarios de la app
- **Animaciones suaves**:
  - AnimatedSwitcher para transición título ↔ campo
  - FadeTransition + SlideTransition
  - Rotación del icono lupa ↔ cerrar
- **Estados visuales claros**: Resultados, vacío, cargando

## 🔧 Uso

### Para el Usuario

1. Tocar el icono de la **lupa** en la barra superior
2. Escribir el término de búsqueda
3. Presionar **Enter** o el botón de búsqueda del teclado
4. Ver los resultados agrupados por categoría
5. Tocar cualquier resultado para ver detalles

### Código

```dart
// El SearchProvider ya está disponible en todo el árbol de widgets
final searchProvider = context.read<SearchProvider>();

// Realizar una búsqueda
await searchProvider.search('término');

// Acceder a resultados
final tabacos = searchProvider.tobaccoResults;
final mezclas = searchProvider.mixResults;
final total = searchProvider.totalResults;

// Limpiar búsqueda
searchProvider.clear();
```

## 🚀 Mejoras Futuras (Opcionales)

### Backend
- [ ] Agregar búsqueda por query SQL en `CommunityRepository` (actualmente filtra en cliente)
- [ ] Índices de texto completo en Supabase para mejorar rendimiento
- [ ] Paginación de resultados si hay muchos

### Frontend
- [ ] Debounce en búsqueda mientras se escribe
- [ ] Historial de búsquedas recientes
- [ ] Sugerencias autocomplete
- [ ] Filtros adicionales (por rating, fecha, etc.)
- [ ] Búsqueda por voz
- [ ] Compartir búsqueda/resultados

### UX
- [ ] Indicador de carga mientras se busca
- [ ] Ordenación de resultados (relevancia, alfabético, rating)
- [ ] Resaltado del término buscado en los resultados
- [ ] "Búsquedas populares" o "Trending"

## 📊 Rendimiento

- **Búsquedas paralelas**: Tabacos y mezclas se buscan simultáneamente
- **Límites razonables**: 50 tabacos, 100 mezclas (ajustable)
- **Reutilización de widgets**: Se usan `TobaccoCard` y `MixCard` existentes
- **Lazy loading**: Los resultados se cargan solo cuando se navega

## 🧪 Testing

### Casos de Prueba Sugeridos

1. **Búsqueda vacía**: No debe navegar
2. **Búsqueda con resultados**: Muestra ambas categorías
3. **Solo tabacos**: Oculta sección de mezclas
4. **Solo mezclas**: Oculta sección de tabacos
5. **Sin resultados**: Muestra estado vacío elegante
6. **Favoritos**: Puede agregar/quitar desde resultados
7. **Navegación**: Ir a detalles funciona correctamente
8. **Tema**: Funciona en modo claro y oscuro

## 📝 Notas Técnicas

- La búsqueda en **tabacos** usa el método nativo del repositorio (query SQL con ILIKE)
- La búsqueda en **mezclas** filtra localmente (ideal: mover al backend)
- Se respeta el patrón de arquitectura limpia del proyecto
- Compatible con localización (todos los textos en español actualmente)
- No rompe funcionalidad existente

---

**Fecha de implementación**: 5 de noviembre de 2025
**Archivos modificados**: 3
**Archivos creados**: 2
**Análisis estático**: ✅ Sin errores
