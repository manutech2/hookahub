# 🔧 Fix: Autor aparece como "Anónimo" o "Cargando..." en tarjetas de mezclas

## 📋 Problema

En las tarjetas de mezclas (tanto en la vista de comunidad como en la vista de detalles), el autor de la mezcla siempre aparece como **"Anónimo"** (o en algunos casos como "Cargando...") en lugar del username real del autor.

## 🔍 Diagnóstico

El problema está en las **políticas RLS (Row Level Security)** de Supabase para la tabla `profiles`.

### Política actual (restrictiva):
```sql
create policy "Solo el usuario puede ver su perfil" on profiles
  for select using (auth.uid() = id);
```

Esta política solo permite que cada usuario vea **su propio perfil**, lo que significa que cuando la aplicación intenta obtener el `username` de otros usuarios (los autores de las mezclas) mediante un JOIN, Supabase **bloquea el acceso** y devuelve `null` para el objeto `profiles`.

### Flujo del problema:

1. La app hace una query a Supabase:
   ```dart
   .select('''
     id,
     name,
     ...
     profiles!mixes_author_id_fkey(username, display_name),
     ...
   ''')
   ```

2. Supabase intenta hacer el JOIN con la tabla `profiles`

3. La política RLS bloquea el acceso porque `auth.uid()` != `profiles.id` del autor

4. El campo `profiles` en la respuesta es `null`

5. El código Dart maneja esto:
   ```dart
   final profile = mixData['profiles']; // null
   final authorName = profile != null 
       ? (profile['username'] as String? ?? 'Anónimo')
       : 'Anónimo';
   ```

6. Como `profile` es `null`, el autor se establece como **'Anónimo'**

7. El widget `MixCard` renderiza el autor como "Anónimo" (o en algunos casos "Cargando..." si hay un estado intermedio)

## ✅ Solución

Necesitas ejecutar el siguiente SQL en tu base de datos de Supabase para actualizar la política RLS:

### Opción 1: Permitir ver perfiles públicos (Recomendada)

```sql
-- Eliminar la política restrictiva anterior
drop policy if exists "Solo el usuario puede ver su perfil" on profiles;

-- Crear nueva política que permite ver perfiles públicos
create policy "Los usuarios pueden ver perfiles públicos" on profiles
  for select using (
    auth.uid() = id         -- Puede ver su propio perfil
    OR 
    is_public = true        -- Puede ver perfiles públicos de otros
  );
```

### Opción 2: Permitir ver todos los perfiles (Alternativa simple)

```sql
-- Eliminar la política restrictiva anterior
drop policy if exists "Solo el usuario puede ver su perfil" on profiles;

-- Permitir que usuarios autenticados vean todos los perfiles
create policy "Usuarios autenticados pueden ver todos los perfiles" on profiles
  for select using (auth.role() = 'authenticated');
```

## 🚀 Pasos para aplicar el fix

1. Abre tu proyecto en [Supabase Dashboard](https://app.supabase.com)

2. Ve a la sección **SQL Editor**

3. Ejecuta el script `supabase_fix_profiles_rls.sql` que se encuentra en la raíz del proyecto

4. Verifica que la política se haya aplicado correctamente en la sección **Authentication** > **Policies**

5. Reinicia la aplicación Flutter

6. Los autores ahora deberían mostrarse correctamente

## 🔒 Consideraciones de seguridad

- **Opción 1** es más segura porque respeta la configuración de privacidad del usuario (`is_public`)
- **Opción 2** expone los perfiles de todos los usuarios pero solo los campos que solicitas en la query (username, display_name)
- En ambos casos, los usuarios solo pueden **ver** los perfiles, no modificarlos (las políticas de UPDATE/DELETE siguen siendo restrictivas)

## 📝 Archivos afectados

- `lib/features/community/data/community_repository.dart`
- `lib/features/mixes/data/user_mixes_repository.dart`
- `lib/features/history/data/history_repository.dart`
- `lib/widgets/mix_card.dart`

Todos estos archivos hacen queries con JOINs a la tabla `profiles` para obtener información de los autores.

## ✨ Resultado esperado

Después de aplicar el fix, las tarjetas de mezclas mostrarán:

- ✅ El username real del autor (ej: `por manuel`)
- ✅ El avatar con la inicial correcta del username
- ✅ No más "Anónimo" o "Cargando..." incorrectos

---

**Fecha del fix**: 7 de noviembre de 2025  
**Prioridad**: Alta 🔥  
**Impacto**: Toda la funcionalidad de comunidad y mezclas
