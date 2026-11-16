# Supabase security audit — sample report (demo app, fictional data)

[![audit-tests](https://github.com/djonovic/supabase-security-audit-demo/actions/workflows/ci.yml/badge.svg)](https://github.com/djonovic/supabase-security-audit-demo/actions/workflows/ci.yml)
**Live report:** https://djonovic.github.io/supabase-security-audit-demo/ · **Need this on your app?** [Hire me on Upwork](https://www.upwork.com/freelancers/paskodjonovic)

> **In 10 seconds:** a common Supabase Row Level Security mistake lets a
> logged-in user read **another team's invoices**. This repo plants that
> hole (and three others), fixes them, and proves the fix with real
> PostgreSQL 16 RLS tests that run in GitHub Actions on every push.

![Walkthrough: before the fix Alice sees 2 of Bob's invoices, after the fix 0](screenshots/audit-walkthrough.gif)

## The problem

Supabase exposes your Postgres tables straight to the browser through the
anon / authenticated keys. The only thing standing between one user and
everyone else's data is **Row Level Security**. Typical holes in apps built
fast (including Lovable / Bolt / Cursor-generated apps):

- RLS never enabled on a table (Postgres default is *off*).
- A policy like `USING (true)` — RLS shows "enabled" in the dashboard, but every row is readable.
- The `service_role` key shipped to client-side code, which bypasses RLS entirely.
- An API route that trusts a `teamId` from the request instead of the session.

## Before / after

| Before the fix — Alice (Apex Studio) queries `invoices` | After the fix — same query, same role |
| --- | --- |
| ![Before: 2 leaked rows](screenshots/before-leak.png) | ![After: 0 leaked rows](screenshots/after-fixed.png) |

## Findings and fixes

| ID | Severity | Finding | Fix | Proof (tests/run.sh) |
| --- | --- | --- | --- | --- |
| F-01 | Critical | RLS disabled on `invoice_notes` | `ENABLE` + `FORCE ROW LEVEL SECURITY`, team-scoped policy | leaked notes 2 → 0 |
| F-02 | Critical | `USING (true)` policy on `invoices` | team-scoped `USING` / `WITH CHECK` via `auth.uid()` | leaked invoices 2 → 0 |
| F-03 | Critical | Service-role key used in browser code | key moved server-only; browser uses anon key + RLS | service role still sees all rows → must stay server-side |
| F-04 | High | API route with no auth check, trusts `teamId` | session required, team derived from profile | 401 no session · 403 other team · 2 own rows |

Each finding on the [live report](https://djonovic.github.io/supabase-security-audit-demo/)
has the impact, a SQL repro, the fix as a diff, and the test result.
Screenshots of every finding: `screenshots/finding-01.png` … `finding-04.png`.

## Details

This repo plants four common Supabase / Next.js holes, then proves the
fixes. The RLS fixes are proven on real PostgreSQL 16 in CI; the service-role key fix is a code change, and the API-route fix is checked by a simulated route in the same script:

1. **RLS disabled** on `invoice_notes` (Postgres default is off).
2. A **`USING (true)`** policy on `invoices` that lets team A read team B's rows.
3. A **service-role key in client-side code** (fake keys only).
4. A **missing auth check** in a Next.js App Router handler.

The test script logs in as Alice, then as Bob. **Before** the fix, Alice
sees Northwind Labs' confidential invoices and notes (2 leaked rows per
table). **After** the fix, she sees **0** of Bob's rows. The same script
runs in GitHub Actions against official `postgres:16`.

## What's in the tree

| Path | What it is |
| --- | --- |
| `supabase/migrations/0001_schema.sql` | Schema + `auth.uid()` helper (Supabase-style, on plain Postgres) |
| `supabase/migrations/0002_vulnerable.sql` | Planted RLS holes |
| `supabase/migrations/0003_fixed.sql` | Team-scoped policies + `FORCE ROW LEVEL SECURITY` |
| `supabase/seed.sql` | Fictional Alice / Bob invoices and notes |
| `src/vulnerable/` | Next.js App Router code with findings 3 and 4 |
| `src/fixed/` | The same handlers and clients, corrected |
| `tests/run.sh` | Before/after proof (psql, as `authenticated` and `service_role`) |
| `docs/` | Public audit report (GitHub Pages) |

## Run the tests

You need PostgreSQL 14+ and `psql`. No hosted Supabase project is required.

```bash
# example: local or CI server
createdb ledgerline
export DATABASE_URL=postgres://postgres:postgres@localhost:5432/ledgerline
bash tests/run.sh
```

The script applies the vulnerable migration, asserts the leaks, applies
the fix, and asserts **0 leaked rows**. It also simulates the vulnerable
API route (service role + attacker-supplied `teamId`) and the fixed
route (401 / 403 / own-team only).

## Line-1 hook (proposals)

> Live demo: the same Supabase query leaks another team's invoices with a
> common RLS mistake and returns 0 rows with correct policies:
> https://djonovic.github.io/supabase-security-audit-demo/. I'd check
> your tables the same way.

Built by [Pasko Djonovic](https://www.upwork.com/freelancers/paskodjonovic)
— full-stack React/Next.js and Supabase developer.
