-- Políticas de Row Level Security (RLS) para la tabla mix_views
-- Estas políticas aseguran que cada usuario solo pueda acceder a su propio historial
-- Última actualización: 30 de octubre de 2025

-- Habilitar RLS en la tabla mix_views
alter table mix_views enable row level security;

-- Política: Los usuarios solo pueden ver su propio historial
create policy "Users can view own history"
  on mix_views for select
  using ((select auth.uid()) = user_id);

-- Política: Los usuarios pueden insertar en su propio historial
-- También permite UPDATE (necesario para UPSERT)
create policy "Users can insert own history"
  on mix_views for insert
  with check ((select auth.uid()) = user_id);

-- Política: Los usuarios pueden actualizar su propio historial
-- Necesario para el UPSERT cuando se visita una mezcla múltiples veces
create policy "Users can update own history"
  on mix_views for update
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

-- Política: Los usuarios pueden eliminar su propio historial
create policy "Users can delete own history"
  on mix_views for delete
  using ((select auth.uid()) = user_id);

-- Verificar políticas creadas
select 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
from pg_policies
where tablename = 'mix_views';
