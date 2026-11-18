-- Tabla para el historial de vistas de mezclas
-- Registra cada vez que un usuario visita una mezcla
-- Solo mantiene la visita más reciente por usuario-mezcla
-- Última actualización: 30 de octubre de 2025

create table if not exists mix_views (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles(id) on delete cascade,
  mix_id uuid not null references mixes(id) on delete cascade,
  viewed_at timestamp with time zone default now() not null,
  -- Constraint único: un usuario solo puede tener un registro por mezcla
  constraint unique_user_mix unique (user_id, mix_id)
);

-- Índices para optimizar consultas
create index if not exists idx_mix_views_user_id on mix_views(user_id);
create index if not exists idx_mix_views_mix_id on mix_views(mix_id);
create index if not exists idx_mix_views_viewed_at on mix_views(viewed_at desc);
create index if not exists idx_mix_views_user_viewed on mix_views(user_id, viewed_at desc);

-- Comentarios para documentación
comment on table mix_views is 'Registra el historial de vistas de mezclas por usuario';
comment on column mix_views.user_id is 'Usuario que visitó la mezcla';
comment on column mix_views.mix_id is 'Mezcla visitada';
comment on column mix_views.viewed_at is 'Fecha y hora de la visita';

-- Función para limpiar historial antiguo (opcional, se puede ejecutar periódicamente)
create or replace function clean_old_mix_views(days_to_keep integer default 7)
returns void as $$
begin
  delete from mix_views 
  where viewed_at < now() - (days_to_keep || ' days')::interval;
end;
$$ language plpgsql security definer;

comment on function clean_old_mix_views is 'Elimina vistas de mezclas más antiguas que X días (por defecto 7)';
