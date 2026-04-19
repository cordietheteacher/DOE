-- Coverage Manager - Cloud Edition
-- Run this in the Supabase SQL editor.

create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text unique,
  full_name text,
  role text not null default 'principal' check (role in ('principal','ap','secretary','dean','viewer')),
  created_at timestamptz not null default now()
);

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, email, full_name, role)
  values (new.id, new.email, coalesce(new.raw_user_meta_data->>'full_name', split_part(new.email,'@',1)), 'principal')
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

create table if not exists public.coverage_days (
  id uuid primary key default gen_random_uuid(),
  coverage_date date not null unique,
  status text not null default 'draft' check (status in ('draft','finalized')),
  office_memo text,
  created_by uuid references public.profiles(id),
  updated_by uuid references public.profiles(id),
  finalized_by uuid references public.profiles(id),
  finalized_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.coverage_day_lists (
  id bigint generated always as identity primary key,
  coverage_day_id uuid not null references public.coverage_days(id) on delete cascade,
  list_type text not null check (list_type in ('absence','exemption')),
  teacher_name text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.coverage_assignments (
  id bigint generated always as identity primary key,
  coverage_day_id uuid not null references public.coverage_days(id) on delete cascade,
  period text not null,
  absent_teacher text not null,
  absent_department text,
  room text,
  sub_assigned text,
  substitute_department text,
  coverage_type text,
  escalation_stage text,
  status text,
  office_notes text,
  locked boolean not null default false,
  created_by uuid references public.profiles(id),
  updated_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.audit_log (
  id bigint generated always as identity primary key,
  coverage_day_id uuid references public.coverage_days(id) on delete cascade,
  assignment_id bigint,
  action_type text not null,
  before_json jsonb,
  after_json jsonb,
  changed_by uuid references public.profiles(id),
  changed_at timestamptz not null default now()
);

create table if not exists public.payroll_exports (
  id bigint generated always as identity primary key,
  coverage_day_id uuid not null references public.coverage_days(id) on delete cascade,
  export_type text not null,
  exported_by uuid references public.profiles(id),
  exported_at timestamptz not null default now(),
  finalized_snapshot_json jsonb
);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_coverage_days_updated_at on public.coverage_days;
create trigger trg_coverage_days_updated_at
before update on public.coverage_days
for each row execute procedure public.set_updated_at();

drop trigger if exists trg_coverage_assignments_updated_at on public.coverage_assignments;
create trigger trg_coverage_assignments_updated_at
before update on public.coverage_assignments
for each row execute procedure public.set_updated_at();

alter table public.profiles enable row level security;
alter table public.coverage_days enable row level security;
alter table public.coverage_day_lists enable row level security;
alter table public.coverage_assignments enable row level security;
alter table public.audit_log enable row level security;
alter table public.payroll_exports enable row level security;

-- Profiles
create policy "profiles read own or shared"
on public.profiles for select
using (auth.role() = 'authenticated');

create policy "profiles insert own"
on public.profiles for insert
with check (auth.uid() = id);

create policy "profiles update own"
on public.profiles for update
using (auth.uid() = id)
with check (auth.uid() = id);

-- Operational tables: any authenticated user can read.
create policy "coverage days read"
on public.coverage_days for select
using (auth.role() = 'authenticated');

create policy "coverage lists read"
on public.coverage_day_lists for select
using (auth.role() = 'authenticated');

create policy "coverage assignments read"
on public.coverage_assignments for select
using (auth.role() = 'authenticated');

create policy "audit read"
on public.audit_log for select
using (auth.role() = 'authenticated');

create policy "payroll exports read"
on public.payroll_exports for select
using (auth.role() = 'authenticated');

-- Editors: principal / ap / secretary / dean
create policy "coverage days write"
on public.coverage_days for all
using (
  exists (
    select 1 from public.profiles p
    where p.id = auth.uid()
      and p.role in ('principal','ap','secretary','dean')
  )
)
with check (
  exists (
    select 1 from public.profiles p
    where p.id = auth.uid()
      and p.role in ('principal','ap','secretary','dean')
  )
);

create policy "coverage lists write"
on public.coverage_day_lists for all
using (
  exists (
    select 1 from public.profiles p
    where p.id = auth.uid()
      and p.role in ('principal','ap','secretary','dean')
  )
)
with check (
  exists (
    select 1 from public.profiles p
    where p.id = auth.uid()
      and p.role in ('principal','ap','secretary','dean')
  )
);

create policy "coverage assignments write"
on public.coverage_assignments for all
using (
  exists (
    select 1 from public.profiles p
    where p.id = auth.uid()
      and p.role in ('principal','ap','secretary','dean')
  )
)
with check (
  exists (
    select 1 from public.profiles p
    where p.id = auth.uid()
      and p.role in ('principal','ap','secretary','dean')
  )
);

create policy "audit write"
on public.audit_log for insert
with check (
  exists (
    select 1 from public.profiles p
    where p.id = auth.uid()
      and p.role in ('principal','ap','secretary','dean')
  )
);

create policy "payroll exports write"
on public.payroll_exports for all
using (
  exists (
    select 1 from public.profiles p
    where p.id = auth.uid()
      and p.role in ('principal','ap','secretary','dean')
  )
)
with check (
  exists (
    select 1 from public.profiles p
    where p.id = auth.uid()
      and p.role in ('principal','ap','secretary','dean')
  )
);

-- Optional: make finalized assignments harder to edit by database rule.
create or replace function public.prevent_finalized_assignment_changes()
returns trigger
language plpgsql
as $$
declare v_status text;
begin
  select status into v_status from public.coverage_days where id = coalesce(new.coverage_day_id, old.coverage_day_id);
  if v_status = 'finalized' then
    raise exception 'This day is finalized. Reopen it before editing assignments.';
  end if;
  return coalesce(new, old);
end;
$$;

drop trigger if exists trg_block_finalized_assignment_updates on public.coverage_assignments;
create trigger trg_block_finalized_assignment_updates
before insert or update or delete on public.coverage_assignments
for each row execute procedure public.prevent_finalized_assignment_changes();

-- Optional helper to promote users after signup.
-- Example:
-- update public.profiles set role = 'secretary' where email = 'schoolsecretary@school.org';
