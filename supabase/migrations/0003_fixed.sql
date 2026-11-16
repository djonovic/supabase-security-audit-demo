-- Fixes for findings 1 and 2. Findings 3 and 4 are code changes
-- under src/fixed/. After this migration, a member of team A must
-- see 0 of team B's invoices and notes.

BEGIN;

-- Table owners bypass RLS unless it is FORCEd. We FORCE both tables
-- so local / CI connections that happen to own the table still get
-- policies applied once they SET ROLE authenticated.
ALTER TABLE public.invoices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.invoices FORCE ROW LEVEL SECURITY;
ALTER TABLE public.invoice_notes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.invoice_notes FORCE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS invoices_all_access ON public.invoices;
DROP POLICY IF EXISTS invoices_same_team ON public.invoices;
DROP POLICY IF EXISTS invoice_notes_same_team ON public.invoice_notes;

CREATE POLICY invoices_same_team ON public.invoices
  FOR ALL
  TO authenticated
  USING (
    team_id = (SELECT p.team_id FROM public.profiles p WHERE p.id = auth.uid())
  )
  WITH CHECK (
    team_id = (SELECT p.team_id FROM public.profiles p WHERE p.id = auth.uid())
  );

CREATE POLICY invoice_notes_same_team ON public.invoice_notes
  FOR ALL
  TO authenticated
  USING (
    team_id = (SELECT p.team_id FROM public.profiles p WHERE p.id = auth.uid())
  )
  WITH CHECK (
    team_id = (SELECT p.team_id FROM public.profiles p WHERE p.id = auth.uid())
  );

-- anon has no policies, so it reads 0 rows once RLS is on.

COMMIT;
