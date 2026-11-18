-- Migración: Añadir campos de rating y reviews a la tabla tobaccos
-- Fecha: 2025-11-10

-- Añadir columnas de rating y reviews a tobaccos
ALTER TABLE tobaccos 
  ADD COLUMN IF NOT EXISTS rating FLOAT DEFAULT 0,
  ADD COLUMN IF NOT EXISTS reviews INTEGER DEFAULT 0;

-- Crear índices para mejorar el rendimiento de consultas ordenadas por rating/reviews
CREATE INDEX IF NOT EXISTS idx_tobaccos_rating ON tobaccos(rating DESC);
CREATE INDEX IF NOT EXISTS idx_tobaccos_reviews ON tobaccos(reviews DESC);
CREATE INDEX IF NOT EXISTS idx_tobaccos_rating_reviews ON tobaccos(rating DESC, reviews DESC);

-- Comentarios para documentación
COMMENT ON COLUMN tobaccos.rating IS 'Calificación promedio del tabaco (0-5 estrellas)';
COMMENT ON COLUMN tobaccos.reviews IS 'Número total de reseñas del tabaco';

-- Nota: Los valores por defecto son 0, pero deberían actualizarse mediante
-- un trigger o función que calcule el promedio de las reseñas existentes.
