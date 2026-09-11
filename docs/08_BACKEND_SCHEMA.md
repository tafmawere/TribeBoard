# Backend Schema

Tables (Supabase / Postgres, RLS-scoped by household membership):

profiles
households
household_memberships
household_invites
household_people
household_locations
children
child_activities
schedule_templates
schedule_stops
runs
run_stops
run_assignments
run_driver_positions
emergency_contacts

RPCs:
resolve_household_by_join_code

Notes:
- Schedules are persisted as `schedule_templates` + `schedule_stops` (not a `schedules` table).
- Membership roles: admin / parent / driver / observer (check constraint).
- Household people roles: parent / driver / helper / guardian / relative / other.
- Full SQL: `docs/supabase_schema.md` and the root `SUPABASE_MIGRATION_*.sql` files.
