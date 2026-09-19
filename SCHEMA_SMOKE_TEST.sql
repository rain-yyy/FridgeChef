-- =====================================================================
-- SCHEMA_SMOKE_TEST.sql
-- 用法（裸 Postgres 16）：createdb t && psql -d t -v ON_ERROR_STOP=1 -f SCHEMA_SMOKE_TEST.sql
-- 作用：1) 模拟 Supabase 的 auth schema/角色；2) 加载 SCHEMA.sql；3) 造夹具；4) 用断言验证
--       RLS、库存事件触发器、字典搜索、保质期建议、match_recipes 规则、merge_ingredients、账号删除级联。
-- 落地到 Supabase 项目后：删掉 "A. 模拟 Supabase" 一段，把断言移植成 pgTAP（supabase/tests/*.sql）。
-- =====================================================================
\set ON_ERROR_STOP on

-- ---------- A. 模拟 Supabase（仅本地裸 Postgres 需要）----------
do $$ begin
  if not exists (select 1 from pg_roles where rolname='anon')          then create role anon nologin; end if;
  if not exists (select 1 from pg_roles where rolname='authenticated') then create role authenticated nologin; end if;
  if not exists (select 1 from pg_roles where rolname='service_role')  then create role service_role nologin bypassrls; end if;
end $$;
create schema if not exists auth;
create table if not exists auth.users (id uuid primary key default gen_random_uuid(), email text);
create or replace function auth.uid() returns uuid language sql stable as $$
  select coalesce(nullif(current_setting('request.jwt.claim.sub', true), ''),
                  (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub'))::uuid
$$;
grant usage on schema auth to anon, authenticated;
grant execute on function auth.uid() to anon, authenticated;

-- ---------- B. 加载被测 schema ----------
\i SCHEMA.sql

-- ---------- C. 夹具 ----------
insert into auth.users(email) values ('a@test'), ('b@test');
select id as uid_a from auth.users where email='a@test' \gset
select id as uid_b from auth.users where email='b@test' \gset
select household_id as hh_a from household_members where user_id = :'uid_a' \gset
select household_id as hh_b from household_members where user_id = :'uid_b' \gset

do $$ begin
  assert (select count(*) from profiles) = 2, '新用户应自动创建 profile';
  assert (select count(*) from households) = 2, '新用户应自动创建个人 household';
end $$;

-- 食材（category: 1 叶菜 2 根茎 3 瓜果茄 4 葱姜蒜 6 肉 9 蛋 11 豆制品 15 调味料）
insert into ingredients(slug, name_zh, name_en, category_id, is_staple_default, shelf_pantry_days) values
 ('tomato',     '番茄',   'tomato',       3, false, null),
 ('egg',        '鸡蛋',   'egg',          9, false, null),
 ('scallion',   '葱',     'scallion',     4, false, null),
 ('garlic',     '大蒜',   'garlic',       4, false, 30),      -- 食材自身 pantry=30 覆盖类别默认 14
 ('ginger',     '姜',     'ginger',       4, false, null),
 ('potato',     '土豆',   'potato',       2, false, null),
 ('pork_belly', '五花肉', 'pork belly',   6, false, null),
 ('pak_choi',   '上海青', 'bok choy',     1, false, null),
 ('tofu',       '豆腐',   'tofu',        11, false, null),
 ('cilantro',   '香菜',   'cilantro',     1, false, null),
 ('salt',       '盐',     'salt',        15, true,  null),
 ('soy_sauce',  '生抽',   'soy sauce',   15, true,  null),
 ('oil',        '食用油', 'cooking oil', 15, true,  null),
 ('vinegar',    '醋',     'vinegar',     15, true,  null),
 ('doubanjiang','豆瓣酱', 'doubanjiang', 15, false, null);

insert into ingredient_aliases(ingredient_id, alias, language, region)
 select id, '西红柿', 'zh', null from ingredients where slug='tomato' union all
 select id, '青菜',   'zh', null from ingredients where slug='pak_choi' union all
 select id, '小白菜', 'zh', null from ingredients where slug='pak_choi' union all
 select id, 'coriander', 'en', 'UK' from ingredients where slug='cilantro';

-- 菜谱
insert into recipes(slug, title_zh, time_minutes, steps, origin, status) values
 ('tomato-egg',   '番茄炒蛋',   10, '[{"idx":1,"text":"占位"}]', 'seed_pipeline', 'verified'),
 ('pork-belly',   '红烧肉',     90, '[{"idx":1,"text":"占位"}]', 'seed_pipeline', 'verified'),
 ('pak-choi',     '清炒上海青', 8,  '[{"idx":1,"text":"占位"}]', 'seed_pipeline', 'verified'),
 ('mapo-tofu',    '麻婆豆腐',   20, '[{"idx":1,"text":"占位"}]', 'seed_pipeline', 'unverified'),
 ('potato-strips','酸辣土豆丝', 15, '[{"idx":1,"text":"占位"}]', 'seed_pipeline', 'verified'),
 ('hidden-dish',  '被隐藏的菜', 5,  '[{"idx":1,"text":"占位"}]', 'seed_pipeline', 'hidden');

insert into recipe_ingredients(recipe_id, ingredient_id, role)
 select r.id, i.id, v.role::recipe_role
 from (values
   ('tomato-egg','tomato','main'), ('tomato-egg','egg','main'), ('tomato-egg','scallion','optional'),
   ('tomato-egg','salt','seasoning'), ('tomato-egg','oil','seasoning'),
   ('pork-belly','pork_belly','main'), ('pork-belly','ginger','aux'), ('pork-belly','scallion','aux'), ('pork-belly','soy_sauce','seasoning'),
   ('pak-choi','pak_choi','main'), ('pak-choi','garlic','aux'), ('pak-choi','salt','seasoning'),
   ('mapo-tofu','tofu','main'), ('mapo-tofu','scallion','aux'), ('mapo-tofu','doubanjiang','aux'),
   ('potato-strips','potato','main'), ('potato-strips','vinegar','seasoning'),
   ('hidden-dish','egg','main')
 ) as v(rs, isl, role)
 join recipes r on r.slug = v.rs join ingredients i on i.slug = v.isl;

-- A 的库存（今天 = 2026-09-18）
insert into inventory_items(household_id, ingredient_id, quantity, initial_quantity, unit, storage, purchased_on, expires_on)
 select :'hh_a', i.id, 1, 1, 'piece', 'fridge', date '2026-09-15', v.exp::date
 from (values ('tomato','2026-09-19'), ('egg','2026-10-10'), ('potato','2026-09-23'),
              ('tofu','2026-09-17'), ('pak_choi','2026-09-21')) as v(sl, exp)
 join ingredients i on i.slug = v.sl;

-- ---------- D. 断言 ----------
-- D0 字典版本号：夹具里多次插入食材/别名，version 必须递增；客户端可读
do $$ begin
  assert (select version from dictionary_meta) > 1, 'D0 字典版本号应随写入递增';
end $$;
set role authenticated;
do $$ begin
  assert (select count(*) from dictionary_meta) = 1, 'D0 客户端应可读 dictionary_meta';
end $$;
reset role;

-- D1 suggest_expiry：类别默认 / 食材自身覆盖 / 无数据返回 null
do $$
declare g uuid; p uuid; t uuid;
begin
  select id into g from ingredients where slug='garlic';
  select id into p from ingredients where slug='potato';
  select id into t from ingredients where slug='tomato';
  assert suggest_expiry(t, 'fridge', date '2026-09-18') = date '2026-09-25', '番茄冷藏应为 +7 天（类别默认）';
  assert suggest_expiry(p, 'pantry', date '2026-09-18') = date '2026-10-02', '土豆常温应为 +14 天';
  assert suggest_expiry(g, 'pantry', date '2026-09-18') = date '2026-10-18', '大蒜常温应为 +30 天（食材覆盖）';
  assert suggest_expiry(t, 'freezer', date '2026-09-18') is null, '番茄无冷冻默认值应返回 null';
end $$;

-- D2 字典搜索：中文别名 / 英文前缀 / 英式别名 / 子串
do $$
begin
  assert (select ingredient_id from search_ingredients('西红柿') limit 1) = (select id from ingredients where slug='tomato'), '西红柿 → 番茄';
  assert (select ingredient_id from search_ingredients('tomat') limit 1)  = (select id from ingredients where slug='tomato'), 'tomat 前缀 → 番茄';
  assert (select ingredient_id from search_ingredients('青菜') limit 1)   = (select id from ingredients where slug='pak_choi'), '青菜 → 上海青';
  assert (select ingredient_id from search_ingredients('coriander') limit 1) = (select id from ingredients where slug='cilantro'), 'coriander → 香菜';
  assert (select count(*) from search_ingredients('   ')) = 0, '空查询应无结果';
end $$;

-- D3 匹配（未覆盖常备）：期望 ready=[番茄炒蛋(3), 酸辣土豆丝(1)]，almost=[清炒上海青(缺蒜)]
--     麻婆豆腐：豆腐已过期 → 排除；红烧肉：无任何核心食材在库 → 排除；hidden 菜谱不出现
set role authenticated;
select set_config('request.jwt.claim.sub', :'uid_a', false);
do $$
declare r record; got text := '';
begin
  for r in select * from match_recipes(current_setting('request.jwt.claim.sub')::uuid, date '2026-09-18') limit 0 loop end loop;  -- 仅语法预热
end $$;
reset role;

select set_config('app.hh_a', :'hh_a', false);
set role authenticated;
select set_config('request.jwt.claim.sub', :'uid_a', false);
do $$
declare got text;
begin
  select string_agg(title_zh || ':' || section || ':' || missing_count || ':' || expiring_score, ' | ' order by ord)
    into got
  from (select *, row_number() over () as ord
        from match_recipes(current_setting('app.hh_a')::uuid, date '2026-09-18')) m;
  raise notice 'D3 结果 = %', got;
  assert got = '番茄炒蛋:ready:0:3 | 酸辣土豆丝:ready:0:1 | 清炒上海青:almost:1:2', 'D3 匹配/排序不符合预期: ' || coalesce(got,'<null>');
end $$;

-- D4 用户把"大蒜"设为常备 → 清炒上海青变 ready，排序按临期分：番茄炒蛋(3) > 清炒上海青(2) > 酸辣土豆丝(1)
insert into household_staples(household_id, ingredient_id, is_staple)
  select current_setting('app.hh_a')::uuid, id, true from ingredients where slug='garlic';
do $$
declare got text;
begin
  select string_agg(title_zh || ':' || section, ' | ' order by ord) into got
  from (select *, row_number() over () as ord from match_recipes(current_setting('app.hh_a')::uuid, date '2026-09-18')) m;
  assert got = '番茄炒蛋:ready | 清炒上海青:ready | 酸辣土豆丝:ready', 'D4 常备覆盖后排序不符合预期: ' || coalesce(got,'<null>');
end $$;

-- D5 过期边界：把 today 推到 2026-09-20，番茄(到期 09-19) 应不再参与，番茄炒蛋因蛋仍在库存而变 almost(缺番茄)
do $$
declare got text;
begin
  select string_agg(title_zh || ':' || section || ':' || missing_count, ' | ' order by ord) into got
  from (select *, row_number() over () as ord from match_recipes(current_setting('app.hh_a')::uuid, date '2026-09-20')) m;
  raise notice 'D5 结果 = %', got;
  assert got like '%番茄炒蛋:almost:1%', 'D5 番茄过期后番茄炒蛋应为 almost 缺 1: ' || coalesce(got,'<null>');
end $$;

-- D6 库存事件触发器
do $$
declare iid uuid; n int;
begin
  select id into iid from inventory_items where household_id = current_setting('app.hh_a')::uuid
    and ingredient_id = (select id from ingredients where slug='egg');
  update inventory_items set quantity = 0.5 where id = iid;                     -- consumed_partial
  update inventory_items set status = 'used_up' where id = iid;                 -- used_up
  update inventory_items set status = 'active' where id = iid;                  -- restored
  update inventory_items set note = 'x' where id = iid;                         -- edited
  select count(*) into n from inventory_events where item_id = iid;
  assert n = 5, 'D6 事件数应为 5（added+4），实际 ' || n;
  assert (select array_agg(event_type::text order by id) from inventory_events where item_id = iid)
         = array['added','consumed_partial','used_up','restored','edited'], 'D6 事件类型序列不符';
end $$;

-- D7 RLS：B 看不到也写不进 A 的数据；anon 无权限；usage_ledger 对客户端不可见
reset role;
set role authenticated;
select set_config('request.jwt.claim.sub', :'uid_b', false);
do $$
declare blocked boolean := false;
begin
  assert (select count(*) from inventory_items) = 0, 'D7 B 不应看到任何库存';
  assert (select count(*) from households) = 1, 'D7 B 只应看到自己的 household';
  assert (select count(*) from match_recipes(current_setting('app.hh_a')::uuid, date '2026-09-18')) = 0, 'D7 B 用 A 的 household 匹配应为空';
  begin
    insert into inventory_items(household_id, ingredient_id, quantity, initial_quantity, unit, storage, purchased_on)
      values (current_setting('app.hh_a')::uuid, (select id from ingredients limit 1), 1, 1, 'piece', 'fridge', date '2026-09-18');
  exception when insufficient_privilege then blocked := true; end;
  assert blocked, 'D7 B 不应能写入 A 的 household';
  blocked := false;
  begin perform 1 from usage_ledger; exception when insufficient_privilege then blocked := true; end;
  assert blocked, 'D7 客户端不应能读 usage_ledger';
  blocked := false;
  begin perform merge_ingredients((select id from ingredients where slug='egg'), (select id from ingredients where slug='tofu'));
  exception when insufficient_privilege then blocked := true; end;
  assert blocked, 'D7 客户端不应能调用 merge_ingredients';
end $$;
reset role;

set role anon;
do $$
declare blocked boolean := false;
begin
  begin perform 1 from ingredients; exception when insufficient_privilege then blocked := true; end;
  assert blocked, 'D7 anon 不应能读字典';
end $$;
reset role;

-- D8 合并重复食材：'芫荽'(auto) 被用在菜谱和库存里，合并到 香菜 后引用迁移、别名保留、搜索仍能找到
insert into ingredients(slug, name_zh, name_en, category_id, status) values ('yuansui', '芫荽', null, 1, 'auto');
insert into recipe_ingredients(recipe_id, ingredient_id, role)
  select (select id from recipes where slug='tomato-egg'), (select id from ingredients where slug='yuansui'), 'aux';
insert into recipe_ingredients(recipe_id, ingredient_id, role)      -- 同一菜谱里 香菜 已是 optional，合并后应取更重要的 aux
  select (select id from recipes where slug='tomato-egg'), (select id from ingredients where slug='cilantro'), 'optional';
insert into inventory_items(household_id, ingredient_id, quantity, initial_quantity, unit, storage, purchased_on)
  select :'hh_a', id, 1, 1, 'bunch', 'fridge', date '2026-09-18' from ingredients where slug='yuansui';
select merge_ingredients((select id from ingredients where slug='yuansui'), (select id from ingredients where slug='cilantro'));
do $$
begin
  assert (select status from ingredients where slug='yuansui') = 'merged', 'D8 应标记 merged';
  assert (select role from recipe_ingredients where recipe_id=(select id from recipes where slug='tomato-egg')
            and ingredient_id=(select id from ingredients where slug='cilantro')) = 'aux', 'D8 角色应取更重要的 aux';
  assert (select count(*) from recipe_ingredients where ingredient_id=(select id from ingredients where slug='yuansui')) = 0, 'D8 菜谱不应再引用旧 id';
  assert (select count(*) from inventory_items where ingredient_id=(select id from ingredients where slug='cilantro')) = 1, 'D8 库存应迁移';
  assert exists (select 1 from ingredient_aliases where alias='芫荽' and ingredient_id=(select id from ingredients where slug='cilantro')), 'D8 别名应保留';
end $$;

-- D9 账号删除级联：删 A → 个人 household、库存、事件、profile 全部清理
delete from auth.users where id = :'uid_a';
do $$
begin
  assert not exists (select 1 from households where id = current_setting('app.hh_a')::uuid), 'D9 household 应被清理';
  assert (select count(*) from inventory_items where household_id = current_setting('app.hh_a')::uuid) = 0, 'D9 库存应被级联删除';
  assert (select count(*) from profiles) = 1, 'D9 只应剩 B 的 profile';
end $$;

\echo '=== ALL SMOKE TESTS PASSED ==='
