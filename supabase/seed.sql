-- Fictional seed data for the Ledgerline demo. Not a real company.

BEGIN;

INSERT INTO auth.users (id, email) VALUES
  ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', 'alice@apex-studio.demo'),
  ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2', 'bob@northwind-labs.demo');

INSERT INTO public.teams (id, name, slug) VALUES
  ('11111111-1111-4111-8111-111111111111', 'Apex Studio', 'apex-studio'),
  ('22222222-2222-4222-8222-222222222222', 'Northwind Labs', 'northwind-labs');

INSERT INTO public.profiles (id, team_id, display_name, role) VALUES
  (
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',
    '11111111-1111-4111-8111-111111111111',
    'Alice Nguyen',
    'owner'
  ),
  (
    'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2',
    '22222222-2222-4222-8222-222222222222',
    'Bob Okonkwo',
    'owner'
  );

INSERT INTO public.invoices
  (id, team_id, invoice_number, client_name, memo, amount_cents, status, issued_on)
VALUES
  (
    'a1001000-0001-4000-8000-000000000001',
    '11111111-1111-4111-8111-111111111111',
    'INV-A-1001',
    'Acme Retail',
    'Brand refresh, milestone 1',
    125000,
    'paid',
    '2026-10-03'
  ),
  (
    'a1002000-0002-4000-8000-000000000002',
    '11111111-1111-4111-8111-111111111111',
    'INV-A-1002',
    'Harbor Bakery',
    'Packaging system',
    48000,
    'sent',
    '2026-10-21'
  ),
  (
    'b2001000-0001-4000-8000-000000000001',
    '22222222-2222-4222-8222-222222222222',
    'INV-B-2001',
    'Discreet Q4 retainer',
    'CONFIDENTIAL — Q4 retainer for acquisition target',
    1890000,
    'sent',
    '2026-10-15'
  ),
  (
    'b2002000-0002-4000-8000-000000000002',
    '22222222-2222-4222-8222-222222222222',
    'INV-B-2002',
    'Stealth Launch Co.',
    'CONFIDENTIAL — stealth product launch',
    745000,
    'draft',
    '2026-11-01'
  );

-- Fix the accidental leading space in client_name if I left one... I'll correct in a follow-up if needed.

INSERT INTO public.invoice_notes (id, team_id, invoice_id, body, created_by) VALUES
  (
    'a1e1e001-0001-4000-8000-000000000001',
    '11111111-1111-4111-8111-111111111111',
    'a1001000-0001-4000-8000-000000000001',
    'Client asked for a revised due date on milestone 2.',
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1'
  ),
  (
    'a1e1e002-0002-4000-8000-000000000002',
    '11111111-1111-4111-8111-111111111111',
    'a1002000-0002-4000-8000-000000000002',
    'Harbor Bakery approved the second draft of the wraps.',
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1'
  ),
  (
    'b2e2e001-0001-4000-8000-000000000001',
    '22222222-2222-4222-8222-222222222222',
    'b2001000-0001-4000-8000-000000000001',
    'INTERNAL — do not share: target is evaluating a sale in Q1.',
    'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2'
  ),
  (
    'b2e2e002-0002-4000-8000-000000000002',
    '22222222-2222-4222-8222-222222222222',
    'b2002000-0002-4000-8000-000000000002',
    'INTERNAL — code name ORCHID. Not public.',
    'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2'
  );

COMMIT;
