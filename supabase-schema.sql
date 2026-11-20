-- ====================================================================
--   BioCraft Platform & Central Admin — Supabase Master SQL Schema
--   يشمل: profiles, platform_settings, vip_codes, RPCs, RLS Policies
-- ====================================================================

-- 1. تفعيل امتدادات التشفير والمعرفات
create extension if not exists "pgcrypto";

-- 2. جدول المواقع والبطاقات الشخصية (profiles)
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
  is_vip boolean default false,
  vip_badge text default null,
  is_active boolean default true,
  links_json jsonb default '[]'::jsonb,
  vcard_json jsonb default '{}'::jsonb,
  views_count bigint default 0,
  edit_secret_hash text,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

create index if not exists idx_profiles_slug on public.profiles(slug);
create index if not exists idx_profiles_is_active on public.profiles(is_active);
create index if not exists idx_profiles_is_vip on public.profiles(is_vip);

-- 3. جدول إعدادات المنصة العامة (platform_settings)
create table if not exists public.platform_settings (
  id int primary key default 1,
  maintenance_mode boolean default false,
  allow_new_sites boolean default true,
  announcement_text text default null,
  announcement_type text default 'info',
  default_theme text default 'obsidian',
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null,
  constraint single_row check (id = 1)
);

insert into public.platform_settings (id, maintenance_mode, allow_new_sites, announcement_text, announcement_type, default_theme)
values (1, false, true, null, 'info', 'obsidian')
on conflict (id) do nothing;

-- 4. جدول أكواد الـ VIP الحصرية (vip_codes)
create table if not exists public.vip_codes (
  id uuid primary key default gen_random_uuid(),
  code text unique not null,
  tier text default 'vip_pro',
  is_active boolean default true,
  is_used boolean default false,
  used_by_slug text default null,
  used_at timestamp with time zone default null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

create index if not exists idx_vip_codes_code on public.vip_codes(code);

-- 5. دوال الـ RPC الآمنة (RPC Functions)

-- (أ) زيادة عداد الزيارات
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

-- (ب) تفعيل كود VIP لموقع معين
create or replace function public.redeem_vip_code(p_code text, p_slug text)
returns json
language plpgsql
security definer
as $$
declare
  v_rec record;
begin
  select * into v_rec from public.vip_codes 
  where upper(code) = upper(trim(p_code)) and is_active = true and is_used = false;

  if not found then
    return json_build_object('success', false, 'message', 'كود VIP غير صحيح أو تم استخدامه مسبقاً');
  end if;

  -- تحديث حالة الكود
  update public.vip_codes
  set is_used = true,
      used_by_slug = p_slug,
      used_at = timezone('utc'::text, now())
  where id = v_rec.id;

  -- ترقية الموقع إلى VIP وتوثيقه تلقائياً
  update public.profiles
  set is_vip = true,
      verified = true,
      vip_badge = 'VIP CREATOR',
      updated_at = timezone('utc'::text, now())
  where slug = p_slug;

  return json_build_object('success', true, 'message', 'تم تفعيل كود VIP وشارة التوثيق بنجاح', 'tier', v_rec.tier);
end;
$$;

-- 6. Trigger تحديث updated_at تلقائياً
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

-- 7. تفعيل سياسات الأمان RLS
alter table public.profiles enable row level security;
alter table public.platform_settings enable row level security;
alter table public.vip_codes enable row level security;

-- سياسات profiles
drop policy if exists "Public profiles read" on public.profiles;
create policy "Public profiles read" on public.profiles
  for select using (is_active = true or auth.role() = 'authenticated');

drop policy if exists "Public profiles insert" on public.profiles;
create policy "Public profiles insert" on public.profiles
  for insert with check (
    exists (select 1 from public.platform_settings where id = 1 and allow_new_sites = true and maintenance_mode = false)
    or auth.role() = 'authenticated'
  );

drop policy if exists "Admin full profile management" on public.profiles;
create policy "Admin full profile management" on public.profiles
  for all to authenticated using (true) with check (true);

-- سياسات platform_settings
drop policy if exists "Public platform settings read" on public.platform_settings;
create policy "Public platform settings read" on public.platform_settings
  for select using (true);

drop policy if exists "Admin platform settings modify" on public.platform_settings;
create policy "Admin platform settings modify" on public.platform_settings
  for all to authenticated using (true) with check (true);

-- سياسات vip_codes
drop policy if exists "Public check vip code" on public.vip_codes;
create policy "Public check vip code" on public.vip_codes
  for select using (is_active = true or auth.role() = 'authenticated');

drop policy if exists "Admin full vip management" on public.vip_codes;
create policy "Admin full vip management" on public.vip_codes
  for all to authenticated using (true) with check (true);
