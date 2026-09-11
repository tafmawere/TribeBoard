-- Adds explicit approval lifecycle constraint for household memberships.
do $$
begin
    if not exists (
        select 1
        from pg_constraint
        where conname = 'household_memberships_status_check'
    ) then
        alter table public.household_memberships
            add constraint household_memberships_status_check
            check (
                status is null
                or status in ('pending', 'active', 'declined', 'revoked')
            );
    end if;
end
$$;
