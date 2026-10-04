import { createClient, SupabaseClient } from '@supabase/supabase-js';

// Browser-safe Supabase configuration. These values are intentionally provided
// through Vite environment variables so deployments can target the existing ACCF
// Supabase project without hardcoding project configuration into source control.
const supabaseUrl = import.meta.env.VITE_SUPABASE_URL?.trim();
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY?.trim();

// The createClient function requires strings. If the env vars are missing,
// we initialize supabase as null and the app will show a degraded state.
export const supabase: SupabaseClient | null = (supabaseUrl && supabaseAnonKey)
    ? createClient(supabaseUrl, supabaseAnonKey)
    : null;

if (!supabase) {
    console.error("Supabase URL and/or anon key are missing (VITE_SUPABASE_URL, VITE_SUPABASE_ANON_KEY). The application will not be able to connect to Supabase and will be in a read-only/mocked state.");
}
