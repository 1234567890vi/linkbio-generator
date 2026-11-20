/**
 * BioCraft Platform — Supabase Client Configuration
 * ضع هنا رابط مشروعك ومفتاح anon من لوحة تحكم Supabase (Project Settings -> API)
 * في حال ترك المفاتيح فارغة أو غير معرّفة، ستعمل المنصة تلقائياً بنظام LZ-String الاحتياطي.
 */
const SUPABASE_CONFIG = {
  url: "https://YOUR_SUPABASE_PROJECT_ID.supabase.co",
  anonKey: "YOUR_SUPABASE_ANON_KEY",
};

/**
 * فحص ما إذا كانت مفاتيح Supabase مُدخلة وجاهزة
 */
function isSupabaseConfigured() {
  return (
    typeof SUPABASE_CONFIG !== "undefined" &&
    SUPABASE_CONFIG.url &&
    SUPABASE_CONFIG.anonKey &&
    !SUPABASE_CONFIG.url.includes("YOUR_SUPABASE_PROJECT_ID") &&
    !SUPABASE_CONFIG.anonKey.includes("YOUR_SUPABASE_ANON_KEY")
  );
}

/**
 * كائن عميل Supabase المشترك
 */
let supabaseClient = null;
function getSupabaseClient() {
  if (supabaseClient) return supabaseClient;
  if (typeof supabase !== "undefined" && isSupabaseConfigured()) {
    try {
      supabaseClient = supabase.createClient(SUPABASE_CONFIG.url, SUPABASE_CONFIG.anonKey);
      return supabaseClient;
    } catch (err) {
      console.warn("[BioCraft] Supabase initialization notice:", err);
    }
  }
  return null;
}
