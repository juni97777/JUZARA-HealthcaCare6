-- JUZARA Health: jalankan seluruh SQL ini di Supabase > SQL Editor.
-- Script ini aman dijalankan ulang untuk memperbaiki profil yang belum terbentuk.

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  name text not null default '',
  identity_number text,
  birth text,
  gender text,
  address text,
  phone text,
  role text not null default 'patient' check (role in ('patient','doctor')),
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

-- Buat profil otomatis setiap kali akun Auth baru dibuat.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, name, identity_number, birth, gender, address, phone, role)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', split_part(new.email, '@', 1), 'Pasien'),
    new.raw_user_meta_data->>'identity_number',
    new.raw_user_meta_data->>'birth_date',
    new.raw_user_meta_data->>'gender',
    new.raw_user_meta_data->>'address',
    new.raw_user_meta_data->>'phone',
    'patient'
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created_juzara on auth.users;
create trigger on_auth_user_created_juzara
after insert on auth.users
for each row execute procedure public.handle_new_user();

-- Lengkapi profil untuk akun yang sudah terdaftar sebelum trigger diperbaiki.
insert into public.profiles (id, name, identity_number, birth, gender, address, phone, role)
select
  u.id,
  coalesce(u.raw_user_meta_data->>'full_name', split_part(u.email, '@', 1), 'Pasien'),
  u.raw_user_meta_data->>'identity_number',
  u.raw_user_meta_data->>'birth_date',
  u.raw_user_meta_data->>'gender',
  u.raw_user_meta_data->>'address',
  u.raw_user_meta_data->>'phone',
  'patient'
from auth.users u
left join public.profiles p on p.id = u.id
where p.id is null
on conflict (id) do nothing;

-- Pengguna hanya dapat membaca profilnya sendiri.
drop policy if exists "profile_select_own" on public.profiles;
create policy "profile_select_own" on public.profiles
for select to authenticated using (auth.uid() = id);

-- Cadangan: pasien dapat membuat profil miliknya sendiri jika trigger belum sempat membuatnya.
-- Policy ini tidak mengizinkan pasien membuat akun dokter.
drop policy if exists "profile_insert_own_patient" on public.profiles;
create policy "profile_insert_own_patient" on public.profiles
for insert to authenticated
with check (auth.uid() = id and role = 'patient');

-- Pengguna hanya dapat mengubah profil miliknya sendiri.
drop policy if exists "profile_update_own" on public.profiles;
create policy "profile_update_own" on public.profiles
for update to authenticated
using (auth.uid() = id)
with check (auth.uid() = id);

-- Cegah pasien mengubah role sendiri menjadi dokter.
create or replace function public.prevent_role_change()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.role is distinct from old.role and current_user <> 'postgres' then
    raise exception 'Role hanya dapat diubah administrator.';
  end if;
  return new;
end;
$$;

drop trigger if exists protect_profile_role on public.profiles;
create trigger protect_profile_role
before update on public.profiles
for each row execute procedure public.prevent_role_change();

-- Jangan membuat policy publik untuk membaca seluruh profil.
