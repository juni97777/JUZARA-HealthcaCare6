-- JUZARA Health: jalankan seluruh SQL ini di Supabase > SQL Editor.
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

-- Akun yang mendaftar sendiri selalu dibuat sebagai pasien.
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
    coalesce(new.raw_user_meta_data->>'full_name',''),
    new.raw_user_meta_data->>'identity_number',
    new.raw_user_meta_data->>'birth_date',
    new.raw_user_meta_data->>'gender',
    new.raw_user_meta_data->>'address',
    new.raw_user_meta_data->>'phone',
    'patient'
  );
  return new;
end;
$$;

drop trigger if exists on_auth_user_created_juzara on auth.users;
create trigger on_auth_user_created_juzara
after insert on auth.users
for each row execute procedure public.handle_new_user();

-- Pengguna hanya dapat membaca dan mengubah profilnya sendiri.
create policy "profile_select_own" on public.profiles
for select to authenticated using (auth.uid() = id);

create policy "profile_update_own" on public.profiles
for update to authenticated using (auth.uid() = id) with check (auth.uid() = id);

-- Cegah pasien mengubah role sendiri menjadi dokter.
create or replace function public.prevent_role_change()
returns trigger language plpgsql as $$
begin
  if new.role is distinct from old.role and current_user <> 'postgres' then
    raise exception 'Role hanya dapat diubah administrator.';
  end if;
  return new;
end;
$$;
drop trigger if exists protect_profile_role on public.profiles;
create trigger protect_profile_role before update on public.profiles
for each row execute procedure public.prevent_role_change();

-- Jangan pernah aktifkan policy publik untuk membaca seluruh profil.
