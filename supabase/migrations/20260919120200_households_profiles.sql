-- T0.2 (P0 schema): users/households (SCHEMA.sql §2) + new-user / account-deletion
-- household maintenance (SCHEMA.sql §7). MVP: every user auto-gets a personal
-- household, no sharing UI (D03).
create table public.profiles (
  user_id           uuid primary key references auth.users(id) on delete cascade,
  display_name      text,
  locale            text not null default 'zh-Hans',
  region            text,
  unit_system       text not null default 'metric' check (unit_system in ('metric','imperial')),
  digest_hour       smallint not null default 8 check (digest_hour between 0 and 23),
  digest_lead_days  smallint not null default 2 check (digest_lead_days between 0 and 7),
  created_at        timestamptz not null default now()
);

create table public.households (
  id          uuid primary key default gen_random_uuid(),
  name        text not null default '我的厨房',
  created_at  timestamptz not null default now()
);

create table public.household_members (
  household_id uuid not null references public.households(id) on delete cascade,
  user_id      uuid not null references auth.users(id) on delete cascade,
  role         household_role not null default 'member',
  created_at   timestamptz not null default now(),
  primary key (household_id, user_id)
);
create index household_members_user_idx on public.household_members(user_id);

-- 判断当前用户是否是某 household 成员。security definer 以避免 RLS 递归。
create or replace function public.is_household_member(hid uuid)
returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.household_members m
    where m.household_id = hid and m.user_id = auth.uid()
  );
$$;

create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
declare hid uuid;
begin
  insert into profiles(user_id) values (new.id);
  insert into households default values returning id into hid;
  insert into household_members(household_id, user_id, role) values (hid, new.id, 'owner');
  return new;
end $$;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- 最后一个成员离开（含账号删除）时清理空 household，级联删除其库存
create or replace function public.cleanup_empty_household() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from household_members where household_id = old.household_id) then
    delete from households where id = old.household_id;
  end if;
  return old;
end $$;
create trigger household_members_cleanup
  after delete on public.household_members
  for each row execute function public.cleanup_empty_household();

-- RLS + grants live with the tables they protect (not in a later, separate
-- migration) so there's never a point where these tables exist without them.
alter table public.profiles          enable row level security;
alter table public.households        enable row level security;
alter table public.household_members enable row level security;

-- 用 (select auth.uid()) 包一层，让 planner 只算一次（Supabase 官方性能建议）
create policy profiles_select_own on public.profiles for select to authenticated using (user_id = (select auth.uid()));
create policy profiles_update_own on public.profiles for update to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

create policy households_select on public.households for select to authenticated using (public.is_household_member(id));
create policy households_update on public.households for update to authenticated
  using (public.is_household_member(id)) with check (public.is_household_member(id));

create policy members_select on public.household_members for select to authenticated using (public.is_household_member(household_id));

-- Supabase 默认会给 anon/authenticated 大量权限，这里显式收紧到刚建好的这几张表。
revoke all on public.profiles, public.households, public.household_members from anon, authenticated;

grant usage on schema public to authenticated;
grant select, update on public.profiles, public.households to authenticated;
grant select on public.household_members to authenticated;
grant execute on function public.is_household_member(uuid) to authenticated;
