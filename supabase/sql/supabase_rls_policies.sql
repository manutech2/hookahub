-- Políticas RLS recomendadas para Hookahub (Supabase)
-- Copia y ejecuta cada bloque en la sección SQL de Supabase
-- Activa RLS en cada tabla antes de crear las políticas

-- =====================
-- Tabla: profiles
-- =====================
-- Solo el usuario puede ver y modificar su propio perfil
alter table profiles enable row level security;

create policy "Solo el usuario puede ver su perfil" on profiles
  for select using ((select auth.uid()) = id);

create policy "Solo el usuario puede modificar su perfil" on profiles
  for update using ((select auth.uid()) = id);

create policy "Solo el usuario puede borrar su perfil" on profiles
  for delete using ((select auth.uid()) = id);

create policy "Permitir insertar perfil si coincide con el usuario autenticado" on profiles
  for insert with check ((select auth.uid()) = id);

-- =====================
-- Tabla: mixes
-- =====================
-- Cualquiera autenticado puede ver mezclas
alter table mixes enable row level security;

create policy "Cualquier usuario autenticado puede ver mezclas" on mixes
  for select using ((select auth.role()) = 'authenticated');

-- Solo el autor puede modificar/borrar su mezcla
create policy "Solo el autor puede modificar su mezcla" on mixes
  for update using ((select auth.uid()) = author_id);

create policy "Solo el autor puede borrar su mezcla" on mixes
  for delete using ((select auth.uid()) = author_id);

-- Solo autenticados pueden crear mezclas
create policy "Solo autenticados pueden crear mezclas" on mixes
  for insert with check ((select auth.role()) = 'authenticated');

-- =====================
-- Tabla: mix_components
-- =====================
-- Solo se puede acceder a componentes de mezclas visibles
alter table mix_components enable row level security;

create policy "Ver componentes de mezclas públicas" on mix_components
  for select using (exists (select 1 from mixes where mixes.id = mix_components.mix_id and ((select auth.role()) = 'authenticated')));

-- Solo el autor de la mezcla puede modificar/borrar componentes
create policy "Solo el autor puede modificar componentes" on mix_components
  for update using (exists (select 1 from mixes where mixes.id = mix_components.mix_id and mixes.author_id = (select auth.uid())));

create policy "Solo el autor puede borrar componentes" on mix_components
  for delete using (exists (select 1 from mixes where mixes.id = mix_components.mix_id and mixes.author_id = (select auth.uid())));

-- Solo autenticados pueden crear componentes
create policy "Solo autenticados pueden crear componentes" on mix_components
  for insert with check ((select auth.role()) = 'authenticated');

-- =====================
-- Tabla: favorites
-- =====================
-- Solo el usuario puede ver y modificar sus favoritos
alter table favorites enable row level security;

create policy "Solo el usuario puede ver sus favoritos" on favorites
  for select using ((select auth.uid()) = user_id);

create policy "Solo el usuario puede modificar sus favoritos" on favorites
  for update using ((select auth.uid()) = user_id);

create policy "Solo el usuario puede borrar sus favoritos" on favorites
  for delete using ((select auth.uid()) = user_id);

create policy "Solo el usuario puede añadir favoritos" on favorites
  for insert with check ((select auth.uid()) = user_id);

-- =====================
-- Tabla: reviews
-- =====================
-- Cualquiera autenticado puede ver reseñas
alter table reviews enable row level security;

create policy "Cualquier usuario autenticado puede ver reseñas" on reviews
  for select using ((select auth.role()) = 'authenticated');

-- Solo el autor puede modificar/borrar su reseña
create policy "Solo el autor puede modificar su reseña" on reviews
  for update using ((select auth.uid()) = author_id);

create policy "Solo el autor puede borrar su reseña" on reviews
  for delete using ((select auth.uid()) = author_id);

-- Solo autenticados pueden crear reseñas
create policy "Solo autenticados pueden crear reseñas" on reviews
  for insert with check ((select auth.role()) = 'authenticated');

-- =====================
-- Tabla: notifications
-- =====================
-- Solo el usuario puede ver y modificar sus notificaciones
alter table notifications enable row level security;

create policy "Solo el usuario puede ver sus notificaciones" on notifications
  for select using ((select auth.uid()) = user_id);

create policy "Solo el usuario puede modificar sus notificaciones" on notifications
  for update using ((select auth.uid()) = user_id);

create policy "Solo el usuario puede borrar sus notificaciones" on notifications
  for delete using ((select auth.uid()) = user_id);

create policy "Solo el usuario puede crear notificaciones" on notifications
  for insert with check ((select auth.uid()) = user_id);

-- =====================
-- Tabla: user_settings
-- =====================
-- Solo el usuario puede ver y modificar su configuración
alter table user_settings enable row level security;

create policy "Solo el usuario puede ver su configuración" on user_settings
  for select using ((select auth.uid()) = user_id);

create policy "Solo el usuario puede modificar su configuración" on user_settings
  for update using ((select auth.uid()) = user_id);

create policy "Solo el usuario puede borrar su configuración" on user_settings
  for delete using ((select auth.uid()) = user_id);

create policy "Solo el usuario puede crear configuración" on user_settings
  for insert with check ((select auth.uid()) = user_id);

-- =====================
-- Tabla: tobaccos (catálogo)
-- =====================
-- Cualquiera autenticado puede ver el catálogo
alter table tobaccos enable row level security;

create policy "Cualquier usuario autenticado puede ver tabacos" on tobaccos
  for select using ((select auth.role()) = 'authenticated');

-- Solo administradores pueden modificar el catálogo (opcional)
-- (Puedes crear un rol 'admin' en Supabase y ajustar esta política)

-- =====================
-- Tabla: activity_log
-- =====================
-- Solo el usuario puede ver su propio historial
alter table activity_log enable row level security;

create policy "Solo el usuario puede ver su historial" on activity_log
  for select using ((select auth.uid()) = user_id);

create policy "Solo el usuario puede añadir historial" on activity_log
  for insert with check ((select auth.uid()) = user_id);

-- Fin de políticas recomendadas para Hookahub
