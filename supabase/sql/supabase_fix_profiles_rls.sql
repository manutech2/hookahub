-- =====================================================
-- FIX: Permitir leer perfiles públicos de otros usuarios
-- =====================================================
-- Problema: Los autores de las mezclas aparecen como "Anónimo"
-- Causa: La política RLS de profiles solo permite ver el propio perfil,
--        por lo que las queries con JOIN a profiles devuelven null
-- Solución: Añadir política para ver perfiles públicos de otros usuarios
-- =====================================================

-- Eliminar la política restrictiva anterior (si existe)
drop policy if exists "Solo el usuario puede ver su perfil" on profiles;

-- Crear nueva política que permita ver perfiles públicos
create policy "Los usuarios pueden ver perfiles públicos" on profiles
  for select using (
    (select auth.uid()) = id  -- Puede ver su propio perfil
    OR 
    is_public = true -- Puede ver perfiles públicos de otros
  );

-- Alternativamente, si quieres que todos los perfiles sean visibles para usuarios autenticados:
-- (Descomenta la siguiente política y comenta la anterior)
/*
create policy "Usuarios autenticados pueden ver todos los perfiles" on profiles
  for select using ((select auth.role()) = 'authenticated');
*/

-- Nota: Esta política permite ver los perfiles que tienen is_public = true
-- Para mezclas de la comunidad, es necesario ver el username de los autores
-- Por seguridad, solo expone los campos que seleccionas en la query (username, display_name)
