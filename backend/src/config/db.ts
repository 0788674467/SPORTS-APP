import { createClient, SupabaseClient } from '@supabase/supabase-js';
import { env } from './env';

/**
 * Anon / public client — use for operations that respect Row Level Security.
 * Safe to use when acting on behalf of a logged-in user.
 */
export const supabase: SupabaseClient = createClient(
    env.supabaseUrl,
    env.supabasePublishableKey
);

/**
 * Service-role client — BYPASSES Row Level Security.
 * Use ONLY in trusted server-side code (admin actions, background jobs, seeds).
 * Never expose this client to the frontend!
 */
export const supabaseAdmin: SupabaseClient = createClient(
    env.supabaseUrl,
    env.supabaseServiceRoleKey
);
