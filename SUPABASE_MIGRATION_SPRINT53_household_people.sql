-- Sprint 53: Backend Household People / Drivers Persistence
-- Adds a backend-backed model for non-user household adults.
--
-- NOTE: RLS policies in this file are superseded by
-- supabase/migrations/20260521120000_active_membership_rls.sql
-- (active-membership-only access). Prefer applying that migration on Supabase.

create table if not exists public.household_people (
    id uuid primary key default gen_random_uuid(),
    household_id uuid not null references public.households(id) on delete cascade,
    name text not null,
    relationship text null,
    role text not null,
    phone text null,
    is_driver boolean not null default false,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    constraint household_people_role_check
        check (role in ('parent', 'driver', 'helper', 'guardian', 'relative', 'other'))
);

create index if not exists idx_household_people_household_id
    on public.household_people(household_id);

alter table public.household_people enable row level security;

drop policy if exists household_people_select_policy on public.household_people;
create policy household_people_select_policy
    on public.household_people
    for select
    to authenticated
    using (
        exists (
            select 1
            from public.household_memberships hm
            where hm.household_id = household_people.household_id
              and hm.user_id = auth.uid()
        )
    );

drop policy if exists household_people_insert_policy on public.household_people;
create policy household_people_insert_policy
    on public.household_people
    for insert
    to authenticated
    with check (
        exists (
            select 1
            from public.household_memberships hm
            where hm.household_id = household_people.household_id
              and hm.user_id = auth.uid()
        )
    );

drop policy if exists household_people_update_policy on public.household_people;
create policy household_people_update_policy
    on public.household_people
    for update
    to authenticated
    using (
        exists (
            select 1
            from public.household_memberships hm
            where hm.household_id = household_people.household_id
              and hm.user_id = auth.uid()
        )
    )
    with check (
        exists (
            select 1
            from public.household_memberships hm
            where hm.household_id = household_people.household_id
              and hm.user_id = auth.uid()
        )
    );

drop policy if exists household_people_delete_policy on public.household_people;
create policy household_people_delete_policy
    on public.household_people
    for delete
    to authenticated
    using (
        exists (
            select 1
            from public.household_memberships hm
            where hm.household_id = household_people.household_id
              and hm.user_id = auth.uid()
        )
    );
