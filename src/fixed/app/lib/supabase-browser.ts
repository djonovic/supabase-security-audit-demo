'use client';

import { createClient } from '@supabase/supabase-js';
import { DEMO_SUPABASE_URL, DEMO_ANON_KEY } from './keys';

/**
 * FIX for finding 3.
 * The browser only receives the anon key. RLS policies decide what
 * the signed-in user can see. The service-role key stays on the
 * server (see supabase-server.ts) and is never prefixed NEXT_PUBLIC_.
 *
 * Keys below are FAKE demo values.
 */
export const supabase = createClient(DEMO_SUPABASE_URL, DEMO_ANON_KEY);
