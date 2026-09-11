-- Adds household-specific role metadata for signed-in members.
alter table public.household_memberships
    add column if not exists family_role text null,
    add column if not exists relationship_label text null;

do $$
begin
    if not exists (
        select 1
        from pg_constraint
        where conname = 'household_memberships_family_role_check'
    ) then
        alter table public.household_memberships
            add constraint household_memberships_family_role_check
            check (
                family_role is null
                or family_role in ('parent', 'driver', 'helper', 'guardian', 'observer')
            );
    end if;
end
$$;
