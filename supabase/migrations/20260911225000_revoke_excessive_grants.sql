-- WS-5 / AC-P1-4, G4
-- Gate A: Revoke anon privileges on sensitive tables; revoke TRUNCATE from authenticated;
-- waitlist exception: anon INSERT only.
-- NEVER apply to production project bxiyosyhkbyvnbqgictr — local / non-prod only.
--
-- Rollback (non-prod after review): re-grant only privileges product requires.

BEGIN;

-- Sensitive tables (design list)
DO $$
DECLARE
  t text;
  tables text[] := ARRAY[
    'profiles',
    'households',
    'household_memberships',
    'household_invites',
    'household_people',
    'household_locations',
    'children',
    'child_activities',
    'schedule_templates',
    'schedule_stops',
    'runs',
    'run_stops',
    'emergency_contacts',
    'location_cache'
  ];
BEGIN
  FOREACH t IN ARRAY tables
  LOOP
    IF to_regclass('public.' || t) IS NOT NULL THEN
      EXECUTE format('REVOKE ALL ON TABLE public.%I FROM anon', t);
      EXECUTE format('REVOKE TRUNCATE ON TABLE public.%I FROM authenticated', t);
    END IF;
  END LOOP;
END $$;

-- waitlist: intentional anon INSERT only (marketing / landing signup)
DO $$
BEGIN
  IF to_regclass('public.waitlist') IS NOT NULL THEN
    REVOKE ALL ON TABLE public.waitlist FROM anon;
    GRANT INSERT ON TABLE public.waitlist TO anon;
  END IF;
END $$;

COMMIT;

-- Note: authenticated SELECT/INSERT/UPDATE/DELETE retained where PostgREST needs them;
-- RLS remains the authorization boundary.
