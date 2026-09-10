// Supabase project credentials.
//
// The anon key is SAFE to ship inside a mobile/web app — it's designed to be
// public. Every table it can touch is protected by the Row Level Security
// policies in schema.sql, so the key alone can't read or write anything it
// shouldn't. Never put your service_role key in the app; that one bypasses
// RLS entirely and must stay server-side only.

const supabaseUrl = 'https://varqzhbpdalqjcufyhwq.supabase.co';
const supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZhcnF6aGJwZGFscWpjdWZ5aHdxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODc0Nzk3ODUsImV4cCI6MjEwMzA1NTc4NX0.a3zTiWLIRIyfhc-FG-QdSYeVLmnnHD52DFUs6Uuo0GQ';