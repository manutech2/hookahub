# Hookahub - Estructura de Navegación

## Arquitectura de la Aplicación

La aplicación ahora cuenta con una estructura de navegación moderna y consistente que incluye:

### 🏠 Página Principal (Home)
- **Ubicación**: `lib/features/home/home_page.dart`
- **Características**:
  - Mensaje de bienvenida personalizado
  - Accesos rápidos a funciones principales
  - Estadísticas generales de la plataforma
  - Tarjetas interactivas para navegación rápida

### 🔥 Catálogo de Tabacos
- **Ubicación**: `lib/features/catalog/catalog_page.dart`
- **Características**:
  - Filtros por categorías (chips horizontales)
  - Grid de tabacos con información detallada
  - Ratings y número de reseñas
  - Cards visualmente atractivas con colores temáticos

### 👥 Comunidad de Mezclas
- **Ubicación**: `lib/features/community/presentation/community_page.dart`
- **Características**:
  - Botón para crear nuevas mezclas
  - Filtros por popularidad y calificaciones
  - Cards de mezclas con ingredientes
  - Sistema de likes, comentarios y compartir

### 👤 Perfil de Usuario
- **Ubicación**: `lib/features/profile/profile_page.dart`
- **Características**:
  - Avatar y información del usuario
  - Estadísticas personales (mezclas, reseñas, favoritos)
  - Opciones de configuración y cuenta
  - Diseño limpio y funcional

## 🎨 Componentes de Navegación

### Header Superior Personalizado
- **Ubicación**: `lib/widgets/main_navigation.dart`
- **Características**:
  - Gradiente turquesa con sombra
  - Título dinámico según la página activa
  - Botón de búsqueda con diálogo modal
  - Campanita de notificaciones con badge
  - Bottom sheet para mostrar notificaciones

### Barra de Navegación Inferior
- **Características**:
  - 4 pestañas principales: Home, Catálogo, Comunidad, Perfil
  - Iconos que cambian según el estado activo/inactivo
  - Transiciones suaves entre páginas
  - Indicadores visuales del estado activo

## 🎯 Flujo de Navegación

1. **Login** → `MainNavigationPage` (página principal)
2. **MainNavigationPage** usa `IndexedStack` para mantener el estado de todas las páginas
3. El header y footer se mantienen consistentes en toda la aplicación
4. Cada página es independiente pero comparte el mismo diseño base

## 🎨 Paleta de Colores

La aplicación utiliza una paleta de colores coherente definida en `lib/core/constants.dart`:

- **Turquesa**: Color principal de la aplicación
- **Colores pastel**: Para categorizar y diferenciar elementos
- **Navy**: Para textos principales
- **Grises**: Para textos secundarios y bordes

## 📱 Responsive Design

- Uso de `SingleChildScrollView` para contenido desplazable
- `GridView` y `ListView` para mostrar colecciones de elementos
- Padding y spacing consistentes en toda la aplicación
- Componentes que se adaptan al contenido

## 🔧 Características Técnicas

- **Estado**: Gestión de estado local con `StatefulWidget`
- **Navegación**: `IndexedStack` para navegación sin pérdida de estado
- **Widgets**: Componentes reutilizables y modulares
- **Escalabilidad**: Estructura fácil de extender y mantener

## 🚀 Próximas Mejoras

- Implementar la funcionalidad de búsqueda
- Conectar con backend para datos reales
- Agregar animaciones de transición
- Implementar sistema de notificaciones push
- Añadir funcionalidad offline con cache

---

*Desarrollado con Flutter siguiendo las mejores prácticas de desarrollo móvil*