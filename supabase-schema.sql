-- ====================================================================
--   BioCraft Platform — Supabase SQL Schema & RLS Security Policies
--   انسخ هذا الكود بالكامل والصقه في SQL Editor داخل لوحة تحكم Supabase
-- ====================================================================

-- 1. تمكين امتدادات التشفير وتوليد المعرفات الفريدة
create extension if not exists "pgcrypto";

-- 2. إنشاء جدول المواقع والبطاقات الشخصية (profiles)
create table if not exists public.profiles (
  id uuid primary key default gen_random_uuid(),
  slug text unique not null,
  site_title text,
  display_name text not null,
  bio text,
  avatar_data text,
  avatar_zoom numeric default 1.0,
  avatar_pos_y numeric default 20,
  theme text default 'obsidian',
  bg_style text default 'particles',
  verified boolean default false,
  is_active boolean default true,
  links_json jsonb default '[]'::jsonb,
  vcard_json jsonb default '{}'::jsonb,
  views_count bigint default 0,
  edit_secret_hash text,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- فهارس للبحث السريع بواسطة الـ slug
create index if not exists idx_profiles_slug on public.profiles(slug);
create index if not exists idx_profiles_is_active on public.profiles(is_active);

-- 3. إنشاء جدول إعدادات المنصة والإعلانات (platform_settings)
create table if not exists public.platform_settings (
  id int primary key default 1,
  maintenance_mode boolean default false,
  allow_new_sites boolean default true,
  announcement_text text default null,
  default_theme text default 'obsidian',
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null,
  constraint single_row check (id = 1)
);

-- إدراج الإعدادات الافتراضية الأولية
insert into public.platform_settings (id, maintenance_mode, allow_new_sites, announcement_text, default_theme)
values (1, false, true, null, 'obsidian')
on conflict (id) do nothing;

-- 4. دالة RPC لزيادة عداد الزيارات بأمان وسرعة عند تصفح الرابط
create or replace function public.increment_site_views(p_slug text)
returns bigint
language plpgsql
security definer
as $$
declare
  new_views bigint;
begin
  update public.profiles
  set views_count = coalesce(views_count, 0) + 1,
      updated_at = timezone('utc'::text, now())
  where slug = p_slug and is_active = true
  returning views_count into new_views;

  return coalesce(new_views, 0);
end;
$$;

-- 5. دالة لتحديث updated_at تلقائياً عند أي تعديل
create or replace function public.handle_updated_at()
returns trigger as $$
begin
  new.updated_at = timezone('utc'::text, now());
  return new;
end;
$$ language plpgsql;

drop trigger if exists trigger_profiles_updated_at on public.profiles;
create trigger trigger_profiles_updated_at
  before update on public.profiles
  for each row execute function public.handle_updated_at();

-- 6. تفعيل سياسات الأمان على مستوى الصفوف (Row Level Security - RLS)
alter table public.profiles enable row level security;
alter table public.platform_settings enable row level security;

-- سياسات جدول profiles:
-- (أ) قراءة المواقع النشطة متاحة للجميع (Public Read)
drop policy if exists "Public profiles read policy" on public.profiles;
create policy "Public profiles read policy"
  on public.profiles
  for select
  using (is_active = true or auth.role() = 'authenticated');

-- (ب) إنشاء موقع جديد متاح للجميع (Public Insert) بشرط الالتزام بالإعدادات
drop policy if exists "Public profiles insert policy" on public.profiles;
create policy "Public profiles insert policy"
  on public.profiles
  for insert
  with check (
    exists (
      select 1 from public.platform_settings
      where id = 1 and allow_new_sites = true and maintenance_mode = false
    )
    or auth.role() = 'authenticated'
  );

-- (ج) تعديل الموقع: مسموح للأدمن، أو لصاحب الموقع بواسطة كود التعديل السري (edit_secret_hash)
drop policy if exists "Profile update policy" on public.profiles;
create policy "Profile update policy"
  on public.profiles
  for update
  using (
    auth.role() = 'authenticated'
    or (
      edit_secret_hash is not null
      and edit_secret_hash = coalesce(current_setting('request.headers', true)::json->>'x-edit-secret-hash', '')
    )
  );

-- (د) الحذف والإيقاف وتغيير حالة التوثيق: محصور بالأدمن فقط
drop policy if exists "Admin full profile management" on public.profiles;
create policy "Admin full profile management"
  on public.profiles
  for all
  to authenticated
  using (true)
  with check (true);

-- سياسات جدول platform_settings:
-- (أ) القراءة متاحة للجميع لمعرفة حالة الصيانة والإعلانات
drop policy if exists "Public platform settings read" on public.platform_settings;
create policy "Public platform settings read"
  on public.platform_settings
  for select
  using (true);

-- (ب) تعديل إعدادات المنصة محصور بحساب الأدمن المسجل فقط
drop policy if exists "Admin platform settings modify" on public.platform_settings;
create policy "Admin platform settings modify"
  on public.platform_settings
  for all
  to authenticated
  using (true)
  with check (true);
