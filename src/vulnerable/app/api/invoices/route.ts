import { NextRequest, NextResponse } from 'next/server';
import { createClient } from '@supabase/supabase-js';
import {
  DEMO_SUPABASE_URL,
  DEMO_SERVICE_ROLE_KEY,
} from '../../lib/keys';

/**
 * FINDING 4 — HIGH (CRITICAL if the service role is used, which it is).
 *
 * This App Router handler never authenticates the caller. It trusts a
 * client-supplied `teamId` query parameter and reads through the
 * service-role key, which bypasses RLS. Anyone who can hit
 * /api/invoices?teamId=<victim> gets that team's invoices.
 *
 * Keys below are FAKE.
 */
const supabase = createClient(DEMO_SUPABASE_URL, DEMO_SERVICE_ROLE_KEY, {
  auth: { persistSession: false, autoRefreshToken: false },
});

export async function GET(req: NextRequest) {
  const teamId = req.nextUrl.searchParams.get('teamId');
  const { data, error } = await supabase
    .from('invoices')
    .select('*')
    .eq('team_id', teamId);

  if (error) {
    return NextResponse.json({ error: error.message }, { status: 500 });
  }
  return NextResponse.json({ invoices: data });
}
