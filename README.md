# Sample security audit — Ledgerline (demo app)

**Sample audit of a demo app (fictional data).** Ledgerline is a made-up
multi-team invoicing app. Apex Studio (Alice) and Northwind Labs (Bob)
are not real companies. Nothing here is a production system.

Live report: https://djonovic.github.io/supabase-security-audit-demo/

This repo plants four common Supabase / Next.js holes, then proves the
fixes with real PostgreSQL Row Level Security (not mocks):

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
