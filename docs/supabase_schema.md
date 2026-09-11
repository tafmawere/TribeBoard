
# TribeBoard – Supabase Database Schema

This document defines the core Supabase database schema for TribeBoard.

> **Coverage note:** the SQL below covers the foundational tables only. The full
> production schema (see `docs/08_BACKEND_SCHEMA.md` for the complete list) also
> includes: `household_people`, `household_locations`, `child_activities`,
> `schedule_templates` + `schedule_stops`, `run_stops`, `run_assignments`, and
> `emergency_contacts`, plus the `resolve_household_by_join_code` RPC. Their SQL
> lives in the root `SUPABASE_MIGRATION_*.sql` files and the Supabase project's
> migration history. Schedules are persisted as `schedule_templates` +
> `schedule_stops` — there is no `schedules` table.

The schema supports:
- Authentication
- Multi-user households
- Children
- Activities
- Schedule templates
- Runs
- Drivers (member drivers and non-user household people)
- Household invites (join codes)
- Live driver positions
- Offline-first sync architecture

---

## profiles

```sql
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text unique,
  display_name text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
```

---

## households

```sql
create table public.households (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
```

---

## household_memberships

```sql
create table public.household_memberships (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  role text not null check (role in ('admin','parent','driver','observer')),
  status text not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (household_id, user_id)
);
```

---

## children

```sql
create table public.children (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  legal_name text not null,
  display_name text,
  date_of_birth date,
  school_name text,
  grade_or_class text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
```

---

## runs

```sql
create table public.runs (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  title text not null,
  run_date date not null,
  departure_time time not null,
  status text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
```

---

## household_invites

```sql
create table public.household_invites (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  invite_code text not null unique,
  role text not null,
  created_at timestamptz not null default now()
);
```

---

## run_driver_positions

```sql
create table public.run_driver_positions (
  run_id uuid primary key references public.runs(id) on delete cascade,
  household_id uuid not null references public.households(id) on delete cascade,
  driver_id uuid,
  latitude double precision not null,
  longitude double precision not null,
  speed_mps double precision,
  heading_degrees double precision,
  updated_at timestamptz not null default now()
);
```

See `SUPABASE_MIGRATION_run_driver_positions.sql` for the full migration.
