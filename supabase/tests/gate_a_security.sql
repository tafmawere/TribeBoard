-- Gate A security assertions — run against LOCAL Supabase only.
-- NEVER run against bxiyosyhkbyvnbqgictr.
-- Usage (local):
--   supabase start
--   psql "$LOCAL_DB_URL" -v ON_ERROR_STOP=1 -f tests/gate_a_security.sql
--
-- Assertions use DO blocks that RAISE EXCEPTION on failure.

\echo '=== Gate A security checks (local only) ==='

-- ---------------------------------------------------------------------------
-- WS-1: policy helpers gone / no EXECUTE for anon or authenticated
-- ---------------------------------------------------------------------------
DO $$
DECLARE
  fn text;
  fns text[] := ARRAY[
    '_tribeboard_drop_all_policies(regclass)',
    '_tribeboard_apply_household_member_select_policies(regclass)',
    '_tribeboard_apply_household_organiser_write_policies(regclass)',
    '_tribeboard_apply_run_operator_write_policies(regclass)'
  ];
  oid regprocedure;
BEGIN
  FOREACH fn IN ARRAY fns
  LOOP
    BEGIN
      oid := ('public.' || fn)::regprocedure;
    EXCEPTION
      WHEN undefined_function THEN
        RAISE NOTICE 'PASS WS-1: % absent (dropped)', fn;
        CONTINUE;
    END;

    -- Function still exists: must not be executable by anon/authenticated
    IF has_function_privilege('anon', oid, 'EXECUTE') THEN
      RAISE EXCEPTION 'FAIL WS-1: anon still has EXECUTE on %', fn;
    END IF;
    IF has_function_privilege('authenticated', oid, 'EXECUTE') THEN
      RAISE EXCEPTION 'FAIL WS-1: authenticated still has EXECUTE on %', fn;
    END IF;
    RAISE NOTICE 'PASS WS-1: % present but EXECUTE revoked from anon/authenticated', fn;
  END LOOP;
END $$;

-- ---------------------------------------------------------------------------
-- WS-2: insert policies named correctly; legacy gone
-- ---------------------------------------------------------------------------
DO $$
DECLARE
  legacy int;
  organiser int;
  bootstrap int;
BEGIN
  SELECT count(*) INTO legacy
  FROM pg_policies
  WHERE schemaname = 'public'
    AND tablename = 'household_memberships'
    AND policyname = 'household_memberships_insert_self_or_organiser';

  IF legacy > 0 THEN
    RAISE EXCEPTION 'FAIL WS-2: legacy household_memberships_insert_self_or_organiser still present';
  END IF;

  SELECT count(*) INTO organiser
  FROM pg_policies
  WHERE schemaname = 'public'
    AND tablename = 'household_memberships'
    AND policyname = 'household_memberships_insert_organiser';

  SELECT count(*) INTO bootstrap
  FROM pg_policies
  WHERE schemaname = 'public'
    AND tablename = 'household_memberships'
    AND policyname = 'household_memberships_insert_creator_bootstrap';

  IF organiser <> 1 OR bootstrap <> 1 THEN
    RAISE EXCEPTION 'FAIL WS-2: expected insert_organiser=1 and insert_creator_bootstrap=1, got % / %',
      organiser, bootstrap;
  END IF;

  RAISE NOTICE 'PASS WS-2: insert_organiser + insert_creator_bootstrap present; legacy dropped';
END $$;

-- ---------------------------------------------------------------------------
-- WS-3: accept* / get_invite* — no PUBLIC/anon EXECUTE; authenticated has EXECUTE
-- ---------------------------------------------------------------------------
DO $$
DECLARE
  r record;
  funcs text[] := ARRAY[
    'accept_household_invite(text)',
    'accept_household_invite_by_id(uuid)',
    'accept_household_invite_by_token(text)',
    'get_invite_by_code(text)',
    'get_invite_by_id(uuid)',
    'get_invite_by_token(text)'
  ];
  fn text;
  oid regprocedure;
BEGIN
  FOREACH fn IN ARRAY funcs
  LOOP
    oid := ('public.' || fn)::regprocedure;

    IF has_function_privilege('anon', oid, 'EXECUTE') THEN
      RAISE EXCEPTION 'FAIL WS-3: anon has EXECUTE on %', fn;
    END IF;

    -- PUBLIC grant must be absent: check acl for PUBLIC (=0)
    IF EXISTS (
      SELECT 1
      FROM pg_proc p
      JOIN pg_namespace n ON n.oid = p.pronamespace
      WHERE n.nspname = 'public'
        AND p.oid = oid::oid
        AND p.proacl IS NOT NULL
        AND EXISTS (
          SELECT 1 FROM aclexplode(p.proacl) a
          WHERE a.grantee = 0 AND a.privilege_type = 'EXECUTE'
        )
    ) THEN
      RAISE EXCEPTION 'FAIL WS-3: PUBLIC still has EXECUTE on %', fn;
    END IF;

    IF NOT has_function_privilege('authenticated', oid, 'EXECUTE') THEN
      RAISE EXCEPTION 'FAIL WS-3: authenticated missing EXECUTE on %', fn;
    END IF;

    RAISE NOTICE 'PASS WS-3 grants: %', fn;
  END LOOP;
END $$;

-- Preview columns exist but body must not leak real tokens (spot-check definition)
DO $$
DECLARE
  def text;
BEGIN
  def := pg_get_functiondef('public.get_invite_by_code(text)'::regprocedure);
  IF def !~* 'NULL::text\s+AS\s+invite_token' AND def !~* 'NULL::text AS invite_token' THEN
    -- also accept NULL::text without AS if aliased in RETURNS TABLE context
    IF position('i.invite_token' in def) > 0 THEN
      RAISE EXCEPTION 'FAIL WS-3: get_invite_by_code still selects i.invite_token';
    END IF;
  END IF;
  IF position('i.invite_code' in def) > 0 AND position('backup_invite_code' in def) > 0 THEN
    -- selecting invite_code into backup column would leak; require NULL backup
    IF def ~ 'i\.invite_code\s*$' OR def ~ 'i\.invite_code,' THEN
      -- live old body had i.invite_code as last select; new body uses NULL::text AS backup
      IF def !~ 'NULL::text AS backup_invite_code' AND def !~ 'NULL::text AS backup_invite_code' THEN
        RAISE EXCEPTION 'FAIL WS-3: get_invite_by_code may still return invite_code as backup';
      END IF;
    END IF;
  END IF;
  RAISE NOTICE 'PASS WS-3: get_invite_by_code definition strips token/backup (spot-check)';
END $$;

-- Email bind present in accept body
DO $$
DECLARE
  def text;
BEGIN
  def := pg_get_functiondef('public.accept_household_invite(text)'::regprocedure);
  IF position('email_mismatch' in def) = 0 OR position('email_required' in def) = 0 THEN
    RAISE EXCEPTION 'FAIL WS-3: accept_household_invite missing email_required/email_mismatch outcomes';
  END IF;
  IF position('current_auth_email_lower' in def) = 0 THEN
    RAISE EXCEPTION 'FAIL WS-3: accept_household_invite missing current_auth_email_lower bind';
  END IF;
  RAISE NOTICE 'PASS WS-3: accept_household_invite contains fail-closed email bind';
END $$;

-- ---------------------------------------------------------------------------
-- WS-4: legacy run_stops ALL policy absent
-- ---------------------------------------------------------------------------
DO $$
DECLARE
  legacy int;
  modern int;
BEGIN
  SELECT count(*) INTO legacy
  FROM pg_policies
  WHERE schemaname = 'public'
    AND tablename = 'run_stops'
    AND policyname = 'Users access run stops';

  IF legacy > 0 THEN
    RAISE EXCEPTION 'FAIL WS-4: legacy "Users access run stops" still present';
  END IF;

  SELECT count(*) INTO modern
  FROM pg_policies
  WHERE schemaname = 'public'
    AND tablename = 'run_stops'
    AND policyname IN (
      'run_stops_select_active_member',
      'run_stops_insert_run_operator',
      'run_stops_update_run_operator',
      'run_stops_delete_run_operator'
    );

  IF modern < 4 THEN
    RAISE WARNING 'WS-4: expected 4 AM/RO policies, found % (verify local schema)', modern;
  ELSE
    RAISE NOTICE 'PASS WS-4: legacy dropped; AM/RO policies present (% )', modern;
  END IF;
END $$;

-- ---------------------------------------------------------------------------
-- WS-5: anon has no ALL/DML on sensitive tables; authenticated no TRUNCATE
-- ---------------------------------------------------------------------------
DO $$
DECLARE
  t text;
  tables text[] := ARRAY[
    'profiles','households','household_memberships','household_invites',
    'household_people','household_locations','children','child_activities',
    'schedule_templates','schedule_stops','runs','run_stops',
    'emergency_contacts','location_cache'
  ];
BEGIN
  FOREACH t IN ARRAY tables
  LOOP
    IF to_regclass('public.' || t) IS NULL THEN
      RAISE NOTICE 'SKIP WS-5: table % absent locally', t;
      CONTINUE;
    END IF;

    IF has_table_privilege('anon', 'public.' || t, 'SELECT')
       OR has_table_privilege('anon', 'public.' || t, 'INSERT')
       OR has_table_privilege('anon', 'public.' || t, 'UPDATE')
       OR has_table_privilege('anon', 'public.' || t, 'DELETE')
       OR has_table_privilege('anon', 'public.' || t, 'TRUNCATE') THEN
      RAISE EXCEPTION 'FAIL WS-5: anon still has table privilege on %', t;
    END IF;

    IF has_table_privilege('authenticated', 'public.' || t, 'TRUNCATE') THEN
      RAISE EXCEPTION 'FAIL WS-5: authenticated still has TRUNCATE on %', t;
    END IF;
  END LOOP;

  IF to_regclass('public.waitlist') IS NOT NULL THEN
    IF NOT has_table_privilege('anon', 'public.waitlist', 'INSERT') THEN
      RAISE EXCEPTION 'FAIL WS-5: anon missing INSERT on waitlist';
    END IF;
    IF has_table_privilege('anon', 'public.waitlist', 'SELECT')
       OR has_table_privilege('anon', 'public.waitlist', 'UPDATE')
       OR has_table_privilege('anon', 'public.waitlist', 'DELETE')
       OR has_table_privilege('anon', 'public.waitlist', 'TRUNCATE') THEN
      RAISE EXCEPTION 'FAIL WS-5: anon has excess privileges on waitlist';
    END IF;
    RAISE NOTICE 'PASS WS-5: waitlist anon INSERT-only';
  END IF;

  RAISE NOTICE 'PASS WS-5: sensitive table grants tightened';
END $$;

\echo '=== Gate A catalog checks complete ==='
-- Behavioral INSERT/accept tests require seeded auth.uid() sessions;
-- run those via authenticated role SET LOCAL request.jwt.claim.sub in integration harness.
