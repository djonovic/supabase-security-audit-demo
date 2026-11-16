-- Ledgerline demo schema.
-- Emulates Supabase's auth.uid() helper on plain PostgreSQL so Row Level
-- Security can be tested without a hosted Supabase project.
-- All data is fictional.

BEGIN;

CREATE SCHEMA IF NOT EXISTS auth;

-- Slim stand-in for supabase auth.users
CREATE TABLE auth.users (
  id uuid PRIMARY KEY,
  email text UNIQUE NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Matches the Supabase helper: JWT `sub` from a session GUC, with a
-- fallback to the JSON claims blob used by current Supabase versions.
CREATE OR REPLACE FUNCTION auth.uid()
RETURNS uuid
LANGUAGE sql
STABLE
AS $$
  SELECT (
    CASE
      WHEN current_setting('request.jwt.claim.sub', true) <> ''
        THEN current_setting('request.jwt.claim.sub', true)
      WHEN current_setting('request.jwt.claims', true) <> ''
        THEN current_setting('request.jwt.claims', true)::jsonb ->> 'sub'
      ELSE NULL
    END
  )::uuid
$$;

CREATE TABLE public.teams (
  id uuid PRIMARY KEY,
  name text NOT NULL,
  slug text UNIQUE NOT NULL
);

CREATE TABLE public.profiles (
  id uuid PRIMARY KEY REFERENCES auth.users (id) ON DELETE CASCADE,
  team_id uuid NOT NULL REFERENCES public.teams (id),
  display_name text NOT NULL,
  role text NOT NULL CHECK (role IN ('owner', 'member'))
);

CREATE TABLE public.invoices (
  id uuid PRIMARY KEY,
  team_id uuid NOT NULL REFERENCES public.teams (id),
  invoice_number text NOT NULL,
  client_name text NOT NULL,
  memo text,
  amount_cents integer NOT NULL CHECK (amount_cents >= 0),
  status text NOT NULL CHECK (status IN ('draft', 'sent', 'paid')),
  issued_on date NOT NULL
);

-- Second tenant table, used for the "RLS never enabled" finding.
CREATE TABLE public.invoice_notes (
  id uuid PRIMARY KEY,
  team_id uuid NOT NULL REFERENCES public.teams (id),
  invoice_id uuid NOT NULL REFERENCES public.invoices (id) ON DELETE CASCADE,
  body text NOT NULL,
  created_by uuid REFERENCES auth.users (id)
);

-- Roles that mirror Supabase's PostgREST roles.
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
    CREATE ROLE anon NOLOGIN NOSUPERUSER NOBYPASSRLS;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
    CREATE ROLE authenticated NOLOGIN NOSUPERUSER NOBYPASSRLS;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'service_role') THEN
    CREATE ROLE service_role NOLOGIN NOSUPERUSER BYPASSRLS;
  END IF;
END
$$;

GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;
GRANT USAGE ON SCHEMA auth TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION auth.uid() TO anon, authenticated, service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public
  TO anon, authenticated, service_role;

-- So the CI superuser can SET ROLE into them.
GRANT anon, authenticated, service_role TO CURRENT_USER;

COMMIT;
