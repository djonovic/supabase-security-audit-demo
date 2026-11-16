import { NextRequest, NextResponse } from 'next/server';
import { createServerClient } from '@supabase/ssr';
import { cookies } from 'next/headers';
import { DEMO_SUPABASE_URL, DEMO_ANON_KEY } from '../../lib/keys';

/**
 * FIX for finding 4.
 *
 * 1. Require a real session (getUser, not getSession).
 * 2. Derive the caller's team from `profiles`, never from a
 *    client-supplied teamId.
 * 3. Query with the user's JWT and the anon key so RLS is a second
 *    line of defence. The service-role key is not used here.
 *
 * Keys below are FAKE demo values.
 */
export async function GET(req: NextRequest) {
  const cookieStore = await cookies();
  const userClient = createServerClient(DEMO_SUPABASE_URL, DEMO_ANON_KEY, {
    cookies: {
      getAll: () => cookieStore.getAll(),
      setAll() {
        // no-op in this demo handler
      },
    },
  });

  const {
    data: { user },
  } = await userClient.auth.getUser();
  if (!user) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
  }

  const { data: profile, error: profileError } = await userClient
    .from('profiles')
    .select('team_id')
    .eq('id', user.id)
    .single();

  if (profileError || !profile) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
  }

  const requestedTeamId = req.nextUrl.searchParams.get('teamId');
  if (requestedTeamId && requestedTeamId !== profile.team_id) {
    return NextResponse.json({ error: 'Forbidden' }, { status: 403 });
  }

  const { data, error } = await userClient
    .from('invoices')
    .select('*')
    .eq('team_id', profile.team_id);

  if (error) {
    return NextResponse.json({ error: error.message }, { status: 500 });
  }
  return NextResponse.json({ invoices: data });
}
