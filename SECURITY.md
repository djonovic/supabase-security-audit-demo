# Security

This repository is a **sample audit of a demo app with fictional data**.
It contains **intentionally vulnerable** SQL and Next.js code under
`supabase/migrations/0002_vulnerable.sql` and `src/vulnerable/`.

Do not deploy the vulnerable tree, and do not reuse the fake keys as if
they were real. The keys in `src/**/lib/keys.ts` are inert placeholders
whose payload says `FAKE DEMO KEY - NOT REAL`.

If you find an issue in the *fixed* examples or in the test harness,
open a GitHub issue on this repository.
