-- Script de migración: Evitar duplicados en mix_views
-- Ejecutar en Supabase SQL Editor
-- Fecha: 30 de octubre de 2025

-- PASO 1: Eliminar duplicados manteniendo solo la visita más reciente
-- Esto crea una tabla temporal con solo las visitas más recientes
WITH ranked_views AS (
  SELECT 
    id,
    user_id,
    mix_id,
    viewed_at,
    ROW_NUMBER() OVER (
      PARTITION BY user_id, mix_id 
      ORDER BY viewed_at DESC
    ) as rn
  FROM mix_views
)
-- Eliminar todas las visitas duplicadas (mantener solo rn = 1)
DELETE FROM mix_views
WHERE id IN (
  SELECT id 
  FROM ranked_views 
  WHERE rn > 1
);

-- PASO 2: Agregar constraint único para evitar futuros duplicados
-- Si la constraint ya existe, esto fallará silenciosamente
DO $$ 
BEGIN
  ALTER TABLE mix_views 
  ADD CONSTRAINT unique_user_mix UNIQUE (user_id, mix_id);
  
  RAISE NOTICE 'Constraint unique_user_mix creada exitosamente';
EXCEPTION 
  WHEN duplicate_object THEN 
    RAISE NOTICE 'Constraint unique_user_mix ya existe';
  WHEN others THEN
    RAISE NOTICE 'Error al crear constraint: %', SQLERRM;
END $$;

-- PASO 3: Verificar resultado
-- Esta consulta debe retornar 0 filas (sin duplicados)
SELECT 
  user_id, 
  mix_id, 
  COUNT(*) as count
FROM mix_views
GROUP BY user_id, mix_id
HAVING COUNT(*) > 1;

-- PASO 4: Ver estadísticas
SELECT 
  COUNT(*) as total_visitas,
  COUNT(DISTINCT user_id) as total_usuarios,
  COUNT(DISTINCT mix_id) as total_mezclas_unicas,
  COUNT(DISTINCT (user_id, mix_id)) as total_combinaciones_unicas
FROM mix_views;

-- Resultado esperado:
-- total_visitas debe ser igual a total_combinaciones_unicas (sin duplicados)
