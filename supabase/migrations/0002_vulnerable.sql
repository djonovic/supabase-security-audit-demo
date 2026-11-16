-- INTENTIONALLY VULNERABLE policies. Do not copy into a real app.
-- Finding 1: invoice_notes has no ENABLE ROW LEVEL SECURITY (default is off).
-- Finding 2: invoices has RLS on, but the policy is USING (true).

BEGIN;

ALTER TABLE public.invoices ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS invoices_all_access ON public.invoices;
CREATE POLICY invoices_all_access ON public.invoices
  FOR ALL
  TO anon, authenticated
  USING (true)
  WITH CHECK (true);

-- invoice_notes: deliberately left without RLS.

COMMIT;
