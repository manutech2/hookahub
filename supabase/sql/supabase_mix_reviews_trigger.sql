-- Trigger y función para calcular automáticamente el rating promedio y número de reviews en mezclas (mixes)
-- Evita depender de actualizaciones del cliente que chocan con la política RLS del autor de la mezcla.

-- 1. Función para calcular rating promedio y conteo al insertar/actualizar reseña
create or replace function update_mix_rating()
returns trigger 
security definer
set search_path = public
as $$
begin
  update mixes
  set 
    rating = coalesce((select avg(rating) from reviews where mix_id = new.mix_id), 0),
    reviews = (select count(*) from reviews where mix_id = new.mix_id)
  where id = new.mix_id;
  return new;
end;
$$ language plpgsql;

-- 2. Trigger para creación o actualización de reseñas
drop trigger if exists on_mix_review_created_or_updated on reviews;
create trigger on_mix_review_created_or_updated
  after insert or update on reviews
  for each row
  execute function update_mix_rating();

-- 3. Función para recalcular al eliminar una reseña
create or replace function update_mix_rating_on_delete()
returns trigger 
security definer
set search_path = public
as $$
begin
  update mixes
  set 
    rating = coalesce((select avg(rating) from reviews where mix_id = old.mix_id), 0),
    reviews = (select count(*) from reviews where mix_id = old.mix_id)
  where id = old.mix_id;
  return old;
end;
$$ language plpgsql;

-- 4. Trigger al eliminar una reseña
drop trigger if exists on_mix_review_deleted on reviews;
create trigger on_mix_review_deleted
  after delete on reviews
  for each row
  execute function update_mix_rating_on_delete();

-- 5. Recalcular las estadísticas de todas las mezclas existentes
update mixes m
set 
  rating = coalesce((select avg(rating) from reviews r where r.mix_id = m.id), 0),
  reviews = coalesce((select count(*) from reviews r where r.mix_id = m.id), 0);
