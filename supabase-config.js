/**
 * ====================================================================
 *   BioCraft Platform — Central Configuration & Backend Connector
 * ====================================================================
 * رابط خادم بايثون السحابي المشفر (HTTPS) للتحكم المباشر والمزامنة
 */
const PYTHON_API_URL = "https://virgin-they-hose-musician.trycloudflare.com";
const SUPABASE_URL = "https://YOUR_SUPABASE_PROJECT.supabase.co";
const SUPABASE_ANON_KEY = "YOUR_SUPABASE_ANON_KEY";
const PUBLIC_PLATFORM_URL = "https://1234567890vi.github.io/linkbio-generator";

const SUPABASE_CONFIG = {
  url: SUPABASE_URL,
  anonKey: SUPABASE_ANON_KEY,
};

function isSupabaseConfigured() {
  return (
    Boolean(SUPABASE_URL && SUPABASE_ANON_KEY) &&
    !SUPABASE_URL.includes("YOUR_SUPABASE_PROJECT") &&
    !SUPABASE_ANON_KEY.includes("YOUR_SUPABASE_ANON_KEY")
  );
}

let supabaseClient = null;
function getSupabaseClient() {
  if (supabaseClient) return supabaseClient;
  if (typeof window.supabase !== "undefined" && isSupabaseConfigured()) {
    try {
      supabaseClient = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
        auth: {
          persistSession: true,
          autoRefreshToken: true,
        },
      });
      return supabaseClient;
    } catch (e) {
      console.warn("[BioCraft] Supabase client init error:", e);
    }
  }
  return null;
}
