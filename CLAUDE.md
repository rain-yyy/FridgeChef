# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project status: planning stage, no code yet

This repo currently contains **only planning documents** — there is no `ios/`, `supabase/`, or `pipeline/` directory, no Xcode project, no migrations, and no CI. It is not yet a git repository. Everything under "Architecture" below describes the *target* design recorded in the docs, not code that exists.

Before doing any implementation work, read, in this order:

1. **`AGENTS.md`** — binding rules for coding agents (guardrails, workflow, what requires explicit sign-off). This is the operating contract for this repo; it is stricter than default behavior and takes precedence.
2. **`PLAN.md`** — the product/architecture design doc. **§2 (Decision Log)** is the authoritative source of "what to build" — decisions marked ✅ are final, 🟡 are defaults awaiting confirmation, 🔴 are unresolved blockers. Do not make a product/architecture call that isn't in §2; ask instead.
3. **`SCHEMA.sql`** — the single-source-of-truth draft schema (not yet split into `supabase/migrations/*.sql`). It has been smoke-tested against bare PostgreSQL 16 with a simulated `auth` schema, but **never validated on a real Supabase project**.
4. **`TICKETS.md`** — the P0/P1 ticket backlog (P2–P4 are epics only). Ticket IDs (`T0.x`, `T1.x`) map to `PLAN.md` sections and decision IDs (`Dxx`).

Per `AGENTS.md` §0 and `PLAN.md` §17: every ticket starts with the agent restating its understanding, listing open questions, and posting an implementation plan (files, migrations, interfaces, tests, risks) — code only after that plan is confirmed.

## Commands

No build/lint/test tooling exists yet (that's part of ticket `T0.1`). The one thing that *is* runnable today is the schema smoke test, directly against a local PostgreSQL 16 (run from the repo root, since it does a relative `\i SCHEMA.sql`):

```bash
createdb t && psql -d t -v ON_ERROR_STOP=1 -f SCHEMA_SMOKE_TEST.sql
```

This simulates Supabase's `anon`/`authenticated`/`service_role` roles and `auth.users`/`auth.uid()`, loads `SCHEMA.sql`, builds fixtures, and asserts RLS, inventory event triggers, dictionary search, `suggest_expiry`, `match_recipes` ranking rules, `merge_ingredients`, and account-deletion cascades. When the schema lands as real `supabase/migrations/*.sql` (ticket `T0.2`), these assertions must be ported to pgTAP under `supabase/tests/` — don't drop the fixtures, they're the executable spec for the matching algorithm.

Planned commands (from `PLAN.md` §4.4/§12.3, once scaffolded): `supabase start` + migrations + pgTAP (DB), `deno lint` / `deno test` (Edge Functions & pipeline, in `supabase/functions/` and `pipeline/`), SwiftLint + `xcodebuild build test` (iOS, in `ios/<App>/`). CI must never call real LLM/third-party APIs — use recorded fixtures.

## Architecture (target design — see `PLAN.md` §4 for full detail)

**Stack**: iOS 17+ SwiftUI app ↔ Supabase (Auth, Postgres+RLS, Storage, Edge Functions, pg_cron) ↔ third-party LLM / Spoonacular, called only from the server side. A separate offline Deno pipeline (`pipeline/`) batch-populates recipes and shares code with `supabase/functions/_shared/` (same TypeScript modules run both offline and on-demand in an Edge Function).

**iOS layering**: `View → ViewModel (@MainActor @Observable) → Repository (protocol) → supabase-swift`. Every Repository has an in-memory Fake for previews/tests. Loading state is `Loadable<T>`; errors are `AppError`. Calendar dates ("purchased on", "expires on") are a custom `LocalDate` (not `Date`+timezone), sourced from an injectable `Clock` — this is the most common bug class flagged in the docs (`PLAN.md` §8.5, §17.5).

**Data model layers** (`PLAN.md` §5.1):
- Global read-only (client reads, only `service_role`/Edge Functions write): `ingredient_categories`, `ingredients`, `ingredient_aliases`, `dictionary_meta`, `recipes`, `recipe_ingredients`, `recipe_aliases`.
- Household-private (RLS: must be a member via `is_household_member()`): `inventory_items`, `inventory_events`, `household_staples`, `cooked_log`.
- User-private: `profiles`, `recipe_reports`, `recipe_requests`, `agent_jobs`.
- Server-only, no policies at all: `usage_ledger`.

**Inventory model**: batches, not aggregate quantities — one row per purchase in `inventory_items`; the UI aggregates by ingredient and consumes earliest-expiry-first (FEFO). A trigger (`log_inventory_event`) derives `inventory_events` rows from inserts/updates automatically — don't write events manually.

**Recipe matching** (`match_recipes` RPC, spec in `PLAN.md` §6, reference implementation in `SCHEMA.sql` §8.3): two sections, `ready` (0 missing) and `almost` (≤ `p_max_missing`). Only `main`/`aux` ingredient roles count toward "missing"; `seasoning`/`optional` never do. A recipe only qualifies if at least one `main`/`aux` ingredient is genuinely in stock (staples alone can't make a recipe "ready"). Expired batches never count as available. Ranking: `ready` first, then an expiry-weighted score (soonest-expiring stock scores higher), then fewer missing, then shorter `time_minutes`. Changing the scoring weights requires re-running the matching eval fixtures (`PLAN.md` §12.2) before/after — never tune on vibes.

**Recipe ingredient roles** (`main`/`aux`/`seasoning`/`optional`) come from an LLM-assisted pipeline but are always 100% human-reviewed before a recipe is `verified` — this is the single highest-leverage correctness gate for the whole matching feature (`PLAN.md` §7.4, §7.7).

**LLM usage boundary**: LLM calls happen only server-side (Edge Functions or the local pipeline), only produce structured JSON validated against a schema, and never hold write access directly — validated, deterministic code performs the actual writes. All external text (web pages, receipts, user input) is treated as untrusted data, wrapped in delimiters, with the system prompt explicitly told to ignore embedded instructions. One retry on structured-output parse failure, then hard error — never write partial results.

**Async jobs**: long-running work (on-demand recipe lookup, receipt parsing) goes through `agent_jobs` — a function inserts a `pending` row and returns immediately (202), a background task (`EdgeRuntime.waitUntil`) updates `progress`/`status`, and the client watches via Realtime with a polling fallback. `agent_jobs` is the deliberate abstraction boundary so the execution runtime (Edge Functions vs. a separate worker) can change later without client changes (`PLAN.md` §4.5).

**Dates and units**: DB stores calendar dates as `date` (not `timestamptz`) and always receives them explicitly from the client's local `Clock` — never trust a server-side default for "today". Units are stored only as g/kg/ml/L/count; imperial units are converted at the input/display boundary only.
