-- T0.2 (P0 schema): only the enums P0 tables/functions actually use.
-- Deferred: recipe_status, recipe_role (created in T1.1 with the recipe tables);
-- job_status (created with agent_jobs, first needed in P2 — see 20260919120500_usage_ledger.sql).
create type storage_location     as enum ('fridge','freezer','pantry');
create type unit_kind            as enum ('g','kg','ml','l','piece','pack','bottle','bunch','stalk','can','box','bag','slice');
create type item_status          as enum ('active','used_up','discarded');
create type expiry_source        as enum ('default','manual','package');
create type ingredient_status    as enum ('seed','auto','verified','merged','rejected');
create type inventory_event_type as enum ('added','edited','consumed_partial','used_up','discarded','restored');
create type household_role       as enum ('owner','member');
