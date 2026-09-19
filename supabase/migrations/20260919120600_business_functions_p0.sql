-- T0.2 (P0 schema): suggest_expiry (SCHEMA.sql §8.1), search_ingredients (§8.2),
-- and a trimmed merge_ingredients (§8.4). match_recipes (§8.3) is deferred to
-- T1.12 — it's defined entirely over recipes/recipe_ingredients, which don't
-- exist until T1.1.

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
grant execute on function public.suggest_expiry(uuid, storage_location, date) to authenticated;

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
grant execute on function public.search_ingredients(text, int) to authenticated;

-- 8.4，P0 子集：只合并字典别名/库存/常备品引用。SCHEMA.sql 里完整版还会合并
-- recipe_ingredients 行，但那张表 T1.1 才建；T1.1 落地时会用
-- create or replace function 把那段补回来（不是"改已应用的 migration"，
-- 是新增一个 migration 替换函数体，允许这么做）。这样 T0.4 校对字典、
-- 合并重复条目时不用等到 P1。
create or replace function public.merge_ingredients(p_from uuid, p_to uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  if p_from = p_to then raise exception 'cannot merge an ingredient into itself'; end if;

  update inventory_items set ingredient_id = p_to where ingredient_id = p_from;
  delete from household_staples f using household_staples t
   where f.ingredient_id = p_from and t.ingredient_id = p_to and t.household_id = f.household_id;
  update household_staples set ingredient_id = p_to where ingredient_id = p_from;

  insert into ingredient_aliases(ingredient_id, alias, language, region, source)
    select p_to, alias, language, region, source from ingredient_aliases where ingredient_id = p_from
  on conflict do nothing;
  delete from ingredient_aliases where ingredient_id = p_from;

  update ingredients set status = 'merged', merged_into = p_to where id = p_from;
end $$;
revoke all on function public.merge_ingredients(uuid, uuid) from public, anon, authenticated;
