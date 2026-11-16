'use client';

import { createClient } from '@supabase/supabase-js';
import { DEMO_SUPABASE_URL, DEMO_SERVICE_ROLE_KEY } from './keys';

/**
 * FINDING 3 — CRITICAL.
 * The service-role key bypasses Row Level Security. Putting it in a
 * client bundle (or any NEXT_PUBLIC_* env var) means anyone can
 * download it and read every tenant's rows, even after RLS is fixed.
 *
 * This file is the planted vulnerability. Keys below are FAKE.
 */
export const supabase = createClient(DEMO_SUPABASE_URL, DEMO_SERVICE_ROLE_KEY);
