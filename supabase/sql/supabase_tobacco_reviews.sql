-- Create tobacco_reviews table
-- Add columns to tobaccos table if they don't exist
alter table tobaccos 
  add column if not exists rating float default 0,
  add column if not exists reviews integer default 0;

create table if not exists tobacco_reviews (
  id uuid primary key default gen_random_uuid(),
  tobacco_id uuid references tobaccos(id) on delete cascade,
  author_id uuid references profiles(id) on delete set null,
  rating float not null check (rating >= 0 and rating <= 5),
  comment text,
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now()
);

-- Add indexes (IF NOT EXISTS is implied for create index in some versions, but better safe)
create index if not exists idx_tobacco_reviews_tobacco on tobacco_reviews(tobacco_id);
create index if not exists idx_tobacco_reviews_author on tobacco_reviews(author_id);
create index if not exists idx_tobacco_reviews_rating on tobacco_reviews(rating);

-- Enable RLS
alter table tobacco_reviews enable row level security;

-- Policies
-- Drop existing policies to allow clean re-creation
drop policy if exists "Reviews are viewable by everyone" on tobacco_reviews;
drop policy if exists "Authenticated users can create reviews" on tobacco_reviews;
drop policy if exists "Users can update own reviews" on tobacco_reviews;
drop policy if exists "Users can delete own reviews" on tobacco_reviews;

-- Everyone can read reviews
create policy "Reviews are viewable by everyone"
  on tobacco_reviews for select
  using ( true );

-- Authenticated users can insert reviews
create policy "Authenticated users can create reviews"
  on tobacco_reviews for insert
  with check ( (select auth.uid()) = author_id );

-- Users can can update their own reviews
create policy "Users can update own reviews"
  on tobacco_reviews for update
  using ( (select auth.uid()) = author_id );

-- Users can delete their own reviews
create policy "Users can delete own reviews"
  on tobacco_reviews for delete
  using ( (select auth.uid()) = author_id );

-- Function to calculate average rating and review count
create or replace function update_tobacco_rating()
returns trigger 
security definer
as $$
begin
  update tobaccos
  set 
    rating = (select coalesce(avg(rating), 0) from tobacco_reviews where tobacco_id = new.tobacco_id),
    reviews = (select count(*) from tobacco_reviews where tobacco_id = new.tobacco_id)
  where id = new.tobacco_id;
  return new;
end;
$$ language plpgsql;

-- Trigger to update rating/reviews on insert/update
drop trigger if exists on_review_created_or_updated on tobacco_reviews;
create trigger on_review_created_or_updated
  after insert or update on tobacco_reviews
  for each row
  execute function update_tobacco_rating();

-- Handle delete case (needs OLD reference)
create or replace function update_tobacco_rating_on_delete()
returns trigger 
security definer
as $$
begin
  update tobaccos
  set 
    rating = (select coalesce(avg(rating), 0) from tobacco_reviews where tobacco_id = old.tobacco_id),
    reviews = (select count(*) from tobacco_reviews where tobacco_id = old.tobacco_id)
  where id = old.tobacco_id;
  return old;
end;
$$ language plpgsql;

-- Trigger to update rating/reviews on delete
drop trigger if exists on_review_deleted on tobacco_reviews;
create trigger on_review_deleted
  after delete on tobacco_reviews
  for each row
  execute function update_tobacco_rating_on_delete();

-- Recalculate stats for all tobaccos (Fix existing data)
update tobaccos t
set 
  rating = coalesce((select avg(rating) from tobacco_reviews tr where tr.tobacco_id = t.id), 0),
  reviews = coalesce((select count(*) from tobacco_reviews tr where tr.tobacco_id = t.id), 0);
