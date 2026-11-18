-- Hookahub: Estructura completa de base de datos para Supabase
-- Incluye soporte para autenticación social (Google, Facebook) vía Supabase Auth
-- Última actualización: 8 de octubre de 2025

-- Tabla de perfiles extendidos (los usuarios se crean en auth.users)
create table if not exists profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text unique not null,
  email text unique not null,
  display_name text,
  avatar_url text,
  bio text,
  birthdate date,
  is_public boolean default true,
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now()
);

-- Tabla de mezclas de la comunidad
create table if not exists mixes (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text,
  author_id uuid references profiles(id) on delete set null,
  rating float default 0,
  reviews integer default 0,
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now()
);

-- Componentes de una mezcla (ingredientes)
create table if not exists mix_components (
  id serial primary key,
  mix_id uuid references mixes(id) on delete cascade,
  tobacco_name text not null,
  brand text not null,
  percentage float not null,
  color text -- hex o nombre
);

-- Favoritos de usuario (muchos a muchos)
create table if not exists favorites (
  user_id uuid references profiles(id) on delete cascade,
  mix_id uuid references mixes(id) on delete cascade,
  is_top5 boolean default false,
  created_at timestamp with time zone default now(),
  primary key (user_id, mix_id)
);

-- Comentarios y reseñas de mezclas
create table if not exists reviews (
  id uuid primary key default gen_random_uuid(),
  mix_id uuid references mixes(id) on delete cascade,
  author_id uuid references profiles(id) on delete set null,
  rating float not null,
  comment text,
  created_at timestamp with time zone default now()
);

-- Notificaciones push/email
create table if not exists notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references profiles(id) on delete cascade,
  type text not null, -- 'mix_new', 'review', 'favorite', etc.
  data jsonb,         -- datos adicionales (ej: id de mezcla)
  is_read boolean default false,
  created_at timestamp with time zone default now()
);

-- Configuración de usuario (preferencias)
create table if not exists user_settings (
  user_id uuid primary key references profiles(id) on delete cascade,
  theme text default 'system', -- 'light', 'dark', 'system'
  push_notifications boolean default true,
  email_notifications boolean default false,
  analytics_opt_in boolean default false,
  updated_at timestamp with time zone default now()
);

-- Catálogo de tabacos (opcional, si gestionas catálogo propio)
create table if not exists tobaccos (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  brand text not null,
  description text,
  image_url text,
  created_at timestamp with time zone default now()
);

-- Historial de actividad (opcional)
create table if not exists activity_log (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references profiles(id) on delete cascade,
  action text not null,
  data jsonb,
  created_at timestamp with time zone default now()
);

-- Índices y restricciones adicionales
create index if not exists idx_mixes_author on mixes(author_id);
create index if not exists idx_favorites_user on favorites(user_id);
create index if not exists idx_favorites_mix on favorites(mix_id);
create index if not exists idx_reviews_mix on reviews(mix_id);
create index if not exists idx_reviews_author on reviews(author_id);

-- Notas:
-- La autenticación social (Google, Facebook) se configura desde el panel de Supabase Auth.
-- Los usuarios creados por cualquier proveedor (email, Google, Facebook) tendrán su id en auth.users y deben tener un perfil en 'profiles'.
-- Puedes ampliar la tabla 'profiles' con campos para provider, metadata, etc. si lo necesitas.
