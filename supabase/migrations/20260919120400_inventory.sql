-- T0.2 (P0 schema): batch-model inventory (SCHEMA.sql §4). One row per purchase;
-- UI aggregates by ingredient and consumes earliest-expiry-first (FEFO).
-- inventory_events rows are derived automatically by the trigger below —
-- application code must never insert into inventory_events directly.
create table public.inventory_items (
  id                uuid primary key default gen_random_uuid(),
  household_id      uuid not null references public.households(id) on delete cascade,
  ingredient_id     uuid references public.ingredients(id),
  custom_name       text,
  quantity          numeric(10,3) not null check (quantity >= 0),
  initial_quantity  numeric(10,3) not null check (initial_quantity >= 0),
  unit              unit_kind not null,
  storage           storage_location not null,
  purchased_on      date not null,
  expires_on        date,
  expiry_source     expiry_source not null default 'default',
  status            item_status not null default 'active',
  source            text not null default 'manual' check (source in ('manual','receipt')),
  receipt_id        uuid,
  note              text,
  created_by        uuid references auth.users(id) on delete set null,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  check (ingredient_id is not null or custom_name is not null)
);
create index inventory_active_idx     on public.inventory_items(household_id, status, expires_on);
create index inventory_ingredient_idx on public.inventory_items(household_id, ingredient_id) where status = 'active';

create table public.inventory_events (
  id           bigint generated always as identity primary key,
  household_id uuid not null references public.households(id) on delete cascade,
  item_id      uuid not null references public.inventory_items(id) on delete cascade,
  event_type   inventory_event_type not null,
  delta        numeric(10,3),
  before       jsonb,
  after        jsonb,
  actor        uuid references auth.users(id) on delete set null,
  created_at   timestamptz not null default now()
);
create index inventory_events_item_idx on public.inventory_events(item_id, created_at);

-- 用户级"常备"覆盖：coalesce(is_staple, ingredients.is_staple_default)
create table public.household_staples (
  household_id  uuid not null references public.households(id) on delete cascade,
  ingredient_id uuid not null references public.ingredients(id),
  is_staple     boolean not null,
  primary key (household_id, ingredient_id)
);

create or replace function public.set_updated_at() returns trigger
language plpgsql as $$
begin new.updated_at := now(); return new; end $$;

create trigger inventory_items_updated_at
  before update on public.inventory_items
  for each row execute function public.set_updated_at();

create or replace function public.log_inventory_event() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  v_type  inventory_event_type;
  v_delta numeric;
begin
  if tg_op = 'INSERT' then
    insert into inventory_events(household_id, item_id, event_type, delta, after, actor)
    values (new.household_id, new.id, 'added', new.quantity, to_jsonb(new), auth.uid());
    return new;
  end if;

  if new.status is distinct from old.status then
    v_type := (case new.status when 'used_up' then 'used_up'
                               when 'discarded' then 'discarded'
                               else 'restored' end)::inventory_event_type;
  elsif new.quantity < old.quantity then
    v_type := 'consumed_partial';
    v_delta := new.quantity - old.quantity;
  elsif (to_jsonb(new) - 'updated_at') is distinct from (to_jsonb(old) - 'updated_at') then
    v_type := 'edited';
  else
    return new;
  end if;

  insert into inventory_events(household_id, item_id, event_type, delta, before, after, actor)
  values (new.household_id, new.id, v_type, v_delta, to_jsonb(old), to_jsonb(new), auth.uid());
  return new;
end $$;
create trigger inventory_items_log
  after insert or update on public.inventory_items
  for each row execute function public.log_inventory_event();

-- RLS + grants live with the tables they protect — see households_profiles.sql.
alter table public.inventory_items   enable row level security;
alter table public.inventory_events  enable row level security;
alter table public.household_staples enable row level security;

create policy inv_select on public.inventory_items for select to authenticated using (public.is_household_member(household_id));
create policy inv_insert on public.inventory_items for insert to authenticated with check (public.is_household_member(household_id));
create policy inv_update on public.inventory_items for update to authenticated
  using (public.is_household_member(household_id)) with check (public.is_household_member(household_id));
create policy inv_delete on public.inventory_items for delete to authenticated using (public.is_household_member(household_id));

create policy inv_events_select on public.inventory_events for select to authenticated using (public.is_household_member(household_id));

create policy staples_all on public.household_staples for all to authenticated
  using (public.is_household_member(household_id)) with check (public.is_household_member(household_id));

revoke all on public.inventory_items, public.inventory_events, public.household_staples from anon, authenticated;
grant select, insert, update, delete on public.inventory_items, public.household_staples to authenticated;
grant select on public.inventory_events to authenticated;
