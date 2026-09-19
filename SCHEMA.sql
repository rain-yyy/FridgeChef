-- =====================================================================
-- SCHEMA.sql  —  草稿 v0.1（P0 + P1 核心表，含 RLS / 关键函数 / 参考数据）
-- 用途：给 coding agent 作为"数据模型的单一事实来源"起点。
-- 注意：落地时必须拆成 supabase/migrations/*.sql，且已应用的 migration 不得修改。
-- 已在本地 PostgreSQL 16 + 模拟 auth schema 下跑通（见 SCHEMA_SMOKE_TEST.sql）；
-- 尚未在真实 Supabase 项目上验证（尤其 auth.users 触发器、扩展、grants 行为）。
-- =====================================================================

create extension if not exists pg_trgm;

-- ---------------------------------------------------------------------
-- 1. 枚举
-- ---------------------------------------------------------------------
create type storage_location   as enum ('fridge','freezer','pantry');
create type unit_kind          as enum ('g','kg','ml','l','piece','pack','bottle','bunch','stalk','can','box','bag','slice');
create type item_status        as enum ('active','used_up','discarded');
create type expiry_source      as enum ('default','manual','package');
create type ingredient_status  as enum ('seed','auto','verified','merged','rejected');
create type recipe_status      as enum ('unverified','verified','hidden');
-- 注意：枚举定义顺序 = 重要性顺序（main 最重要）。merge_ingredients 用 least() 依赖这个顺序。
create type recipe_role        as enum ('main','aux','seasoning','optional');
create type job_status         as enum ('pending','running','succeeded','failed','cancelled');
create type inventory_event_type as enum ('added','edited','consumed_partial','used_up','discarded','restored');
create type household_role     as enum ('owner','member');

-- ---------------------------------------------------------------------
-- 2. 用户 / 家庭（MVP：每个用户自动拥有一个个人 household，不做共享 UI）
-- ---------------------------------------------------------------------
create table public.profiles (
  user_id           uuid primary key references auth.users(id) on delete cascade,
  display_name      text,
  locale            text not null default 'zh-Hans',
  region            text,                                   -- 'US','CA','GB','DE'... 影响小票/别名偏好
  unit_system       text not null default 'metric' check (unit_system in ('metric','imperial')),  -- 仅影响显示
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

-- ---------------------------------------------------------------------
-- 3. 食材字典（全局，只读给客户端；写入只走 service_role / Edge Function）
-- ---------------------------------------------------------------------
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
  slug                 text unique not null,                 -- 'tomato'
  name_zh              text not null,
  name_en              text,
  category_id          smallint not null references public.ingredient_categories(id),
  default_storage      storage_location,                     -- null → 用类别默认
  shelf_fridge_days    int,                                  -- null → 用类别默认
  shelf_freezer_days   int,
  shelf_pantry_days    int,
  default_unit         unit_kind not null default 'piece',   -- 添加时预填，降低录入摩擦
  default_quantity     numeric(10,3) not null default 1,
  is_staple_default    boolean not null default false,       -- 常备调味料等；用户可在 household_staples 覆盖
  status               ingredient_status not null default 'seed',
  merged_into          uuid references public.ingredients(id),
  created_by           uuid references auth.users(id) on delete set null,       -- LLM/用户触发新增时记录
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
  region        text,                                        -- 'US' / 'UK' / null（cilantro vs coriander 等）
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

-- 字典版本号：客户端把整本字典（约 1k 食材 + 数千别名，几百 KB）缓存到本地，
-- 启动时比较 version，变了才整本重拉（别名会被 merge 删除，增量同步处理不了删除，所以用整本同步）。
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

-- ---------------------------------------------------------------------
-- 4. 库存（批次模型：每次购买一条；展示时按食材聚合；优先消耗最早到期）
-- ---------------------------------------------------------------------
create table public.inventory_items (
  id                uuid primary key default gen_random_uuid(),
  household_id      uuid not null references public.households(id) on delete cascade,
  ingredient_id     uuid references public.ingredients(id),
  custom_name       text,                                     -- 字典里没有且未通过审核时的自定义食材，不参与菜谱匹配
  quantity          numeric(10,3) not null check (quantity >= 0),
  initial_quantity  numeric(10,3) not null check (initial_quantity >= 0),
  unit              unit_kind not null,                       -- 存公制/计数单位；oz/lb 在输入时换算为 g，仅显示时换回
  storage           storage_location not null,
  purchased_on      date not null,                            -- 客户端必须显式传本地日期，不要依赖服务器默认值
  expires_on        date,                                     -- null = 不追踪保质期（如盐）
  expiry_source     expiry_source not null default 'default',
  status            item_status not null default 'active',
  source            text not null default 'manual' check (source in ('manual','receipt')),
  receipt_id        uuid,                                     -- P2：FK 到 receipts
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

-- ---------------------------------------------------------------------
-- 5. 菜谱（全局；写入只走 service_role / pipeline / Edge Function）
-- ---------------------------------------------------------------------
create table public.recipes (
  id            uuid primary key default gen_random_uuid(),
  slug          text unique not null,
  title_zh      text not null,
  title_en      text,
  cuisine       text,                                          -- 'chinese','western','japanese'...
  category      text,                                          -- '炒菜','汤','凉菜','主食'...
  description   text,
  servings      smallint,
  time_minutes  smallint,
  difficulty    smallint check (difficulty between 1 and 5),
  steps         jsonb not null,                                -- [{"idx":1,"text":"...","timer_seconds":300}]
  tags          text[] not null default '{}',
  flags         text[] not null default '{}',                  -- 'raw_or_undercooked','ai_generated_no_source'
  status        recipe_status not null default 'unverified',
  origin        text not null check (origin in ('seed_pipeline','agent_ondemand','llm_fallback','manual')),
  source_url    text,                                          -- 内部溯源；App 内展示为"参考来源"并链回原页
  source_site   text,
  content_hash  text,
  report_count  int not null default 0,
  created_by    uuid references auth.users(id) on delete set null,
  verified_by   text,
  verified_at   timestamptz,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);
create index recipes_status_idx     on public.recipes(status);
create index recipes_tags_idx       on public.recipes using gin(tags);
create index recipes_title_trgm     on public.recipes using gin (title_zh gin_trgm_ops);
create trigger recipes_updated_at before update on public.recipes
  for each row execute function public.set_updated_at();

-- 同一菜谱里同一食材只保留一行：pipeline 负责合并重复项
-- （role 取最重要者，单位相同则数量相加，否则保留第一条并在 note 里说明）。
create table public.recipe_ingredients (
  recipe_id     uuid not null references public.recipes(id) on delete cascade,
  ingredient_id uuid not null references public.ingredients(id),
  role          recipe_role not null,
  amount        numeric(10,3),
  unit          unit_kind,
  to_taste      boolean not null default false,               -- "少许/适量"
  note          text,                                         -- 自己重写的短说明，如"切片"，不是原文
  sort_order    smallint not null default 0,
  primary key (recipe_id, ingredient_id)
);
create index recipe_ingredients_ing_idx on public.recipe_ingredients(ingredient_id);

create table public.recipe_aliases (
  id          bigint generated always as identity primary key,
  recipe_id   uuid not null references public.recipes(id) on delete cascade,
  alias       text not null,
  alias_norm  text generated always as (lower(btrim(alias))) stored,
  unique (recipe_id, alias_norm)
);
create index recipe_aliases_trgm on public.recipe_aliases using gin (alias_norm gin_trgm_ops);

create table public.recipe_reports (
  id         bigint generated always as identity primary key,
  recipe_id  uuid not null references public.recipes(id) on delete cascade,
  user_id    uuid not null references auth.users(id) on delete cascade,
  reason     text not null check (reason in ('wrong_ingredient','wrong_role','wrong_steps','unsafe','duplicate','other')),
  detail     text,
  resolved   boolean not null default false,
  created_at timestamptz not null default now()
);

create table public.cooked_log (
  id           uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  recipe_id    uuid references public.recipes(id),
  external_ref text,                                          -- P3: 'spoonacular:12345'
  cooked_on    date not null,
  servings     smallint,
  photo_path   text,
  created_by   uuid references auth.users(id) on delete set null,
  created_at   timestamptz not null default now()
);

-- 用户搜菜名但库里没有 → 记录，用于 Gate C 判断是否需要 P3（现场 agent）
create table public.recipe_requests (
  id                bigint generated always as identity primary key,
  user_id           uuid not null references auth.users(id) on delete cascade,
  query             text not null,
  matched_recipe_id uuid references public.recipes(id),
  created_at        timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- 6. 异步任务 / 用量（P2/P3 使用；先建表，客户端只读自己的任务）
-- ---------------------------------------------------------------------
create table public.agent_jobs (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  kind        text not null check (kind in ('recipe_lookup','receipt_parse')),
  input       jsonb not null,
  status      job_status not null default 'pending',
  progress    text,
  result      jsonb,
  error       text,
  attempts    smallint not null default 0,
  cost_usd    numeric(10,5),
  created_at  timestamptz not null default now(),
  started_at  timestamptz,
  finished_at timestamptz
);
create index agent_jobs_user_idx   on public.agent_jobs(user_id, created_at desc);
create index agent_jobs_status_idx on public.agent_jobs(status, created_at) where status in ('pending','running');

create table public.usage_ledger (
  id            bigint generated always as identity primary key,
  user_id       uuid references auth.users(id) on delete set null,   -- 删账号后保留成本数据但去标识
  feature       text not null check (feature in ('resolve_ingredient','receipt_parse','recipe_lookup','translate','spoonacular','pipeline')),
  provider      text,
  model         text,
  units         integer not null default 1,
  input_tokens  integer,
  output_tokens integer,
  cost_usd      numeric(10,5),
  created_at    timestamptz not null default now()
);
create index usage_ledger_user_feature_idx on public.usage_ledger(user_id, feature, created_at);

-- ---------------------------------------------------------------------
-- 7. 新用户 / 删除用户 时的家庭维护
-- ---------------------------------------------------------------------
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

-- ---------------------------------------------------------------------
-- 8. 业务函数
-- ---------------------------------------------------------------------

-- 8.1 保质期建议：食材自身值优先，否则用类别默认。仅为"估计"，不是食品安全建议。
create or replace function public.suggest_expiry(
  p_ingredient   uuid,
  p_storage      storage_location,
  p_purchased_on date
) returns date
language sql stable set search_path = public as $$
  select p_purchased_on + s.days
  from (
    select case p_storage
             when 'fridge'  then coalesce(i.shelf_fridge_days,  c.shelf_fridge_days)
             when 'freezer' then coalesce(i.shelf_freezer_days, c.shelf_freezer_days)
             when 'pantry'  then coalesce(i.shelf_pantry_days,  c.shelf_pantry_days)
           end as days
    from ingredients i
    join ingredient_categories c on c.id = i.category_id
    where i.id = p_ingredient
  ) s
  where s.days is not null;
$$;

-- 8.2 食材搜索（服务端兜底；客户端应优先在本地缓存的整本字典里搜）
-- 注意：pg_trgm 对中文是否生效取决于数据库 lc_ctype（C.UTF-8/en_US.UTF-8 有效；纯 'C' 会失效）。
create or replace function public.search_ingredients(q text, lim int default 8)
returns table (ingredient_id uuid, name_zh text, name_en text, matched_alias text, score real)
language sql stable set search_path = public as $$
  with qn as (select lower(btrim(q)) as q),
  hits as (
    select a.ingredient_id, a.alias,
           (case
              when a.alias_norm = qn.q                                   then 1.0::real
              when left(a.alias_norm, length(qn.q)) = qn.q               then 0.9::real
              when strpos(a.alias_norm, qn.q) > 0                        then 0.7::real
              else similarity(a.alias_norm, qn.q)
            end) as score
    from ingredient_aliases a, qn
    where length(qn.q) > 0
      and (strpos(a.alias_norm, qn.q) > 0 or a.alias_norm % qn.q)
  ),
  best as (
    select distinct on (t.id)
           t.id as ingredient_id, t.name_zh, t.name_en, h.alias as matched_alias, h.score
    from hits h
    join ingredients i on i.id = h.ingredient_id
    join ingredients t on t.id = coalesce(i.merged_into, i.id)
    where t.status not in ('rejected','merged')
    order by t.id, h.score desc
  )
  select b.ingredient_id, b.name_zh, b.name_en, b.matched_alias, b.score
  from best b
  order by b.score desc, b.name_zh
  limit lim;
$$;

-- 8.3 "能做什么"匹配。规则见 PLAN.md §6。
--   可用库存 = active 且 (无到期日 或 未过期)；过期批次不参与匹配。
--   缺料 = 角色为 main/aux 且 不在可用库存 且 不是该 household 的常备品；seasoning/optional 永不计缺料。
--   至少要有 1 个 main/aux 食材真实在库存里（不能只靠常备品凑出"能做"）。
--   两段：ready(缺 0) 优先；段内按 expiring_score 降序、缺料升序、时长升序。
create or replace function public.match_recipes(
  p_household   uuid,
  p_today       date default current_date,     -- 客户端传本地日期，避免 UTC 边界误差
  p_max_missing int  default 2,
  p_limit       int  default 60
) returns table (
  recipe_id      uuid,
  title_zh       text,
  time_minutes   smallint,
  status         recipe_status,
  flags          text[],
  section        text,
  missing_count  int,
  missing_ids    uuid[],
  used_ids       uuid[],
  expiring_score int
)
language sql stable security invoker set search_path = public as $$
  with avail as (
    select i.ingredient_id, min(i.expires_on) as soonest_expiry
    from inventory_items i
    where i.household_id = p_household
      and i.status = 'active'
      and i.ingredient_id is not null
      and (i.expires_on is null or i.expires_on >= p_today)
    group by i.ingredient_id
  ),
  staples as (
    select ing.id as ingredient_id
    from ingredients ing
    left join household_staples hs
      on hs.household_id = p_household and hs.ingredient_id = ing.id
    where coalesce(hs.is_staple, ing.is_staple_default)
  ),
  ri as (
    select x.recipe_id, x.ingredient_id, x.role,
           (a.ingredient_id is not null) as in_stock,
           (s.ingredient_id is not null) as is_staple,
           a.soonest_expiry
    from recipe_ingredients x
    join recipes r on r.id = x.recipe_id and r.status <> 'hidden'
    left join avail a   on a.ingredient_id = x.ingredient_id
    left join staples s on s.ingredient_id = x.ingredient_id
  ),
  scored as (
    select recipe_id,
      count(*) filter (where role in ('main','aux') and not in_stock and not is_staple)::int as missing_count,
      coalesce(array_agg(ingredient_id) filter (where role in ('main','aux') and not in_stock and not is_staple), '{}') as missing_ids,
      coalesce(array_agg(ingredient_id) filter (where in_stock), '{}') as used_ids,
      count(*) filter (where role in ('main','aux') and in_stock)::int as used_core,
      coalesce(sum(case
        when in_stock and role in ('main','aux') and soonest_expiry is not null then
          case when soonest_expiry - p_today <= 1 then 3
               when soonest_expiry - p_today <= 3 then 2
               when soonest_expiry - p_today <= 7 then 1
               else 0 end
        else 0 end), 0)::int as expiring_score
    from ri
    group by recipe_id
  )
  select r.id, r.title_zh, r.time_minutes, r.status, r.flags,
         (case when s.missing_count = 0 then 'ready' else 'almost' end)::text as section,
         s.missing_count, s.missing_ids, s.used_ids, s.expiring_score
  from scored s
  join recipes r on r.id = s.recipe_id
  where s.used_core >= 1
    and s.missing_count <= p_max_missing
  order by (s.missing_count = 0) desc,
           s.expiring_score desc,
           s.missing_count asc,
           r.time_minutes asc nulls last,
           r.title_zh
  limit p_limit;
$$;

-- 8.4 合并重复食材（仅 service_role）。把 p_from 的一切引用迁到 p_to，p_from 标记 merged。
create or replace function public.merge_ingredients(p_from uuid, p_to uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  if p_from = p_to then raise exception 'cannot merge an ingredient into itself'; end if;

  -- 菜谱：两者都出现时，保留更重要的角色，删掉 from 行
  update recipe_ingredients t set role = least(t.role, f.role)
    from recipe_ingredients f
   where f.ingredient_id = p_from and t.ingredient_id = p_to and t.recipe_id = f.recipe_id;
  delete from recipe_ingredients f using recipe_ingredients t
   where f.ingredient_id = p_from and t.ingredient_id = p_to and t.recipe_id = f.recipe_id;
  update recipe_ingredients set ingredient_id = p_to where ingredient_id = p_from;

  -- 库存、常备覆盖
  update inventory_items set ingredient_id = p_to where ingredient_id = p_from;
  delete from household_staples f using household_staples t
   where f.ingredient_id = p_from and t.ingredient_id = p_to and t.household_id = f.household_id;
  update household_staples set ingredient_id = p_to where ingredient_id = p_from;

  -- 别名：迁移；并把被合并者的标准名也记为别名
  insert into ingredient_aliases(ingredient_id, alias, language, region, source)
    select p_to, alias, language, region, source from ingredient_aliases where ingredient_id = p_from
  on conflict do nothing;
  delete from ingredient_aliases where ingredient_id = p_from;

  update ingredients set status = 'merged', merged_into = p_to where id = p_from;
end $$;
revoke all on function public.merge_ingredients(uuid, uuid) from public, anon, authenticated;

-- ---------------------------------------------------------------------
-- 9. RLS（每张 public 表都必须启用；无策略 = 对客户端全拒绝）
-- ---------------------------------------------------------------------
alter table public.profiles              enable row level security;
alter table public.households            enable row level security;
alter table public.household_members     enable row level security;
alter table public.ingredient_categories enable row level security;
alter table public.ingredients           enable row level security;
alter table public.ingredient_aliases    enable row level security;
alter table public.inventory_items       enable row level security;
alter table public.inventory_events      enable row level security;
alter table public.household_staples     enable row level security;
alter table public.recipes               enable row level security;
alter table public.recipe_ingredients    enable row level security;
alter table public.recipe_aliases        enable row level security;
alter table public.recipe_reports        enable row level security;
alter table public.cooked_log            enable row level security;
alter table public.recipe_requests       enable row level security;
alter table public.agent_jobs            enable row level security;
alter table public.usage_ledger          enable row level security;   -- 无策略：仅 service_role 可读写
alter table public.dictionary_meta       enable row level security;

-- 用 (select auth.uid()) 包一层，让 planner 只算一次（Supabase 官方性能建议）
create policy profiles_select_own on public.profiles for select to authenticated using (user_id = (select auth.uid()));
create policy profiles_update_own on public.profiles for update to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

create policy households_select on public.households for select to authenticated using (public.is_household_member(id));
create policy households_update on public.households for update to authenticated
  using (public.is_household_member(id)) with check (public.is_household_member(id));

create policy members_select on public.household_members for select to authenticated using (public.is_household_member(household_id));

create policy categories_read  on public.ingredient_categories for select to authenticated using (true);
create policy ingredients_read on public.ingredients          for select to authenticated using (status <> 'rejected');
create policy aliases_read     on public.ingredient_aliases   for select to authenticated using (true);
create policy dict_meta_read   on public.dictionary_meta      for select to authenticated using (true);

create policy inv_select on public.inventory_items for select to authenticated using (public.is_household_member(household_id));
create policy inv_insert on public.inventory_items for insert to authenticated with check (public.is_household_member(household_id));
create policy inv_update on public.inventory_items for update to authenticated
  using (public.is_household_member(household_id)) with check (public.is_household_member(household_id));
create policy inv_delete on public.inventory_items for delete to authenticated using (public.is_household_member(household_id));

create policy inv_events_select on public.inventory_events for select to authenticated using (public.is_household_member(household_id));

create policy staples_all on public.household_staples for all to authenticated
  using (public.is_household_member(household_id)) with check (public.is_household_member(household_id));

create policy recipes_read     on public.recipes            for select to authenticated using (status <> 'hidden');
create policy recipe_ing_read  on public.recipe_ingredients for select to authenticated using (true);
create policy recipe_alias_read on public.recipe_aliases    for select to authenticated using (true);

create policy reports_insert on public.recipe_reports for insert to authenticated with check (user_id = (select auth.uid()));
create policy reports_select on public.recipe_reports for select to authenticated using (user_id = (select auth.uid()));

create policy cooked_all on public.cooked_log for all to authenticated
  using (public.is_household_member(household_id)) with check (public.is_household_member(household_id));

create policy requests_insert on public.recipe_requests for insert to authenticated with check (user_id = (select auth.uid()));
create policy requests_select on public.recipe_requests for select to authenticated using (user_id = (select auth.uid()));

create policy jobs_select on public.agent_jobs for select to authenticated using (user_id = (select auth.uid()));

-- ---------------------------------------------------------------------
-- 10. Grants（Supabase 默认会给 anon/authenticated 大量权限，这里显式收紧）
-- ---------------------------------------------------------------------
revoke all on all tables in schema public from anon;
revoke all on all tables in schema public from authenticated;

grant usage on schema public to authenticated;
grant select on public.ingredient_categories, public.ingredients, public.ingredient_aliases, public.dictionary_meta,
                public.recipes, public.recipe_ingredients, public.recipe_aliases,
                public.household_members, public.inventory_events, public.agent_jobs to authenticated;
grant select, update on public.profiles, public.households to authenticated;
grant select, insert, update, delete on public.inventory_items, public.household_staples, public.cooked_log to authenticated;
grant select, insert on public.recipe_reports, public.recipe_requests to authenticated;
grant execute on function public.is_household_member(uuid),
                          public.suggest_expiry(uuid, storage_location, date),
                          public.search_ingredients(text, int),
                          public.match_recipes(uuid, date, int, int) to authenticated;

-- ---------------------------------------------------------------------
-- 11. 参考数据：类别与默认保质期（天）。
-- ⚠ 这些是"起始估计值"，需要你校对；它们不是食品安全建议，UI 必须提示以包装日期和实际状态为准。
-- ---------------------------------------------------------------------
insert into public.ingredient_categories (id, slug, name_zh, name_en, default_storage, shelf_fridge_days, shelf_freezer_days, shelf_pantry_days, sort_order) values
 (1,  'leafy',      '叶菜类',     'Leafy greens',        'fridge',  7,    null, null, 10),
 (2,  'root',       '根茎类',     'Root vegetables',     'pantry',  21,   null, 14,   20),
 (3,  'fruit_veg',  '瓜果茄类',   'Fruiting vegetables', 'fridge',  7,    null, 3,    30),
 (4,  'allium',     '葱姜蒜类',   'Alliums & aromatics', 'fridge',  14,   null, 14,   40),
 (5,  'mushroom',   '菌菇类',     'Mushrooms',           'fridge',  5,    null, null, 50),
 (6,  'meat',       '猪牛羊肉',   'Raw meat',            'fridge',  2,    90,   null, 60),
 (7,  'poultry',    '禽肉',       'Raw poultry',         'fridge',  2,    90,   null, 70),
 (8,  'seafood',    '水产',       'Seafood',             'fridge',  1,    60,   null, 80),
 (9,  'egg',        '蛋类',       'Eggs',                'fridge',  28,   null, 7,    90),
 (10, 'dairy',      '乳制品',     'Dairy',               'fridge',  7,    60,   null, 100),
 (11, 'tofu_soy',   '豆制品',     'Tofu & soy products', 'fridge',  5,    60,   null, 110),
 (12, 'grain',      '米面主食',   'Grains & noodles',    'pantry',  null, 180,  180,  120),
 (13, 'bread',      '面包烘焙',   'Bread & bakery',      'pantry',  7,    90,   4,    130),
 (14, 'fruit',      '水果',       'Fruit',               'fridge',  7,    null, 5,    140),
 (15, 'seasoning',  '调味料',     'Seasonings & sauces', 'pantry',  180,  null, 365,  150),
 (16, 'dried',      '干货',       'Dried goods',         'pantry',  null, null, 365,  160),
 (17, 'canned',     '罐头即食',   'Canned & packaged',   'pantry',  5,    null, 365,  170),
 (18, 'cooked',     '熟食剩菜',   'Cooked & leftovers',  'fridge',  3,    90,   null, 180),
 (19, 'other',      '其他',       'Other',               'pantry',  7,    null, 30,   190);
