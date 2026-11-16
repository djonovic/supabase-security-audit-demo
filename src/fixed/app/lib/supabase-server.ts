import { createClient } from '@supabase/supabase-js';
import { DEMO_SUPABASE_URL, DEMO_SERVICE_ROLE_KEY } from './keys';

/**
 * Service-role client — server-only (Route Handlers, Server Actions,
 * cron jobs). Never import this file from a Client Component.
 *
 * Even here, prefer the user's JWT + RLS when the query is on behalf
 * of a user. Use this client for admin tasks, not for "just fetch
 * this team's invoices."
 *
 * Keys below are FAKE demo values.
 */
export function createServiceClient() {
  if (typeof window !== 'undefined') {
    throw new Error('service-role client must not be used in the browser');
  }
  return createClient(DEMO_SUPABASE_URL, DEMO_SERVICE_ROLE_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}
