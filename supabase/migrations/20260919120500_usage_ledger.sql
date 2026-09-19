-- T0.2 (P0 schema): P0 subset of SCHEMA.sql §6 ("异步任务/用量"). Only usage_ledger
-- is created here — T0.10 (resolve-ingredient Edge Function) writes a row per LLM
-- call ('resolve_ingredient' is a valid `feature` value below), so this table has
-- to exist by P0.
--
-- agent_jobs is intentionally NOT created here: nothing in P0 uses it (its `kind`
-- check only allows 'recipe_lookup'/'receipt_parse', both P2/P3 features). It will
-- be created, with its own migration + RLS + policy + grants, in whichever ticket
-- first needs it (receipt scan, P2).
create table public.usage_ledger (
  id            bigint generated always as identity primary key,
  user_id       uuid references auth.users(id) on delete set null,
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

-- RLS + grants live with the table they protect — see households_profiles.sql.
alter table public.usage_ledger enable row level security;   -- 无策略：仅 service_role 可读写
revoke all on public.usage_ledger from anon, authenticated;   -- no grant: clients get no access at all
