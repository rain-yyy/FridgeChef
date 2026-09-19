-- T0.2 (P0 schema): global, read-only-to-client ingredient dictionary (SCHEMA.sql §3).
-- Writes only via service_role / Edge Functions. Seed data (~300 ingredients) is T0.4,
-- not this migration — this just creates the tables + version-bump machinery.
create table public.ingredient_categories (
  id                   smallint primary key,
  slug                 text unique not null,
  name_zh              text not null,
  name_en              text not null,
  default_storage      storage_location not null,
  shelf_fridge_days    int,
  shelf_freezer_days   int,
  shelf_pantry_days    int,
  sort_order           smallint not null default 0
);

create table public.ingredients (
  id                   uuid primary key default gen_random_uuid(),
  slug                 text unique not null,
  name_zh              text not null,
  name_en              text,
  category_id          smallint not null references public.ingredient_categories(id),
  default_storage      storage_location,
  shelf_fridge_days    int,
  shelf_freezer_days   int,
  shelf_pantry_days    int,
  default_unit         unit_kind not null default 'piece',
  default_quantity     numeric(10,3) not null default 1,
  is_staple_default    boolean not null default false,
  status               ingredient_status not null default 'seed',
  merged_into          uuid references public.ingredients(id),
  created_by           uuid references auth.users(id) on delete set null,
  created_at           timestamptz not null default now(),
  reviewed_at          timestamptz,
  check ((status = 'merged') = (merged_into is not null))
);

create table public.ingredient_aliases (
  id            bigint generated always as identity primary key,
  ingredient_id uuid not null references public.ingredients(id) on delete cascade,
  alias         text not null,
  alias_norm    text generated always as (lower(btrim(alias))) stored,
  language      text not null check (language in ('zh','en','de','fr','es','it','nl','other')),
  region        text,
  source        text not null default 'seed' check (source in ('seed','llm','user','pipeline')),
  created_at    timestamptz not null default now(),
  unique (ingredient_id, alias_norm)
);
create index ingredient_aliases_norm_trgm on public.ingredient_aliases using gin (alias_norm gin_trgm_ops);
create index ingredient_aliases_ing_idx   on public.ingredient_aliases(ingredient_id);

-- 不变量：标准名本身一定是别名，seed 时不用重复写。
create or replace function public.ingredients_add_canonical_aliases() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into ingredient_aliases(ingredient_id, alias, language, source)
  values (new.id, new.name_zh, 'zh', 'seed')
  on conflict do nothing;
  if new.name_en is not null then
    insert into ingredient_aliases(ingredient_id, alias, language, source)
    values (new.id, new.name_en, 'en', 'seed')
    on conflict do nothing;
  end if;
  return new;
end $$;
create trigger ingredients_canonical_aliases
  after insert on public.ingredients
  for each row execute function public.ingredients_add_canonical_aliases();

-- 字典版本号：客户端把整本字典缓存到本地，启动时比较 version，变了才整本重拉。
create table public.dictionary_meta (
  id      boolean primary key default true check (id),
  version bigint not null default 1
);
insert into public.dictionary_meta default values;

create or replace function public.bump_dictionary_version() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  update dictionary_meta set version = version + 1 where id;
  return null;
end $$;
create trigger ingredients_bump_version
  after insert or update or delete on public.ingredients
  for each statement execute function public.bump_dictionary_version();
create trigger aliases_bump_version
  after insert or update or delete on public.ingredient_aliases
  for each statement execute function public.bump_dictionary_version();

-- RLS + grants live with the tables they protect — see households_profiles.sql.
alter table public.ingredient_categories enable row level security;
alter table public.ingredients           enable row level security;
alter table public.ingredient_aliases    enable row level security;
alter table public.dictionary_meta       enable row level security;

create policy categories_read  on public.ingredient_categories for select to authenticated using (true);
create policy ingredients_read on public.ingredients          for select to authenticated using (status <> 'rejected');
create policy aliases_read     on public.ingredient_aliases   for select to authenticated using (true);
create policy dict_meta_read   on public.dictionary_meta      for select to authenticated using (true);

revoke all on public.ingredient_categories, public.ingredients, public.ingredient_aliases, public.dictionary_meta from anon, authenticated;
grant select on public.ingredient_categories, public.ingredients, public.ingredient_aliases, public.dictionary_meta to authenticated;
