-- WS-1 / AC-P0-1.1–1.7, G4, G6
-- Gate A: Revoke EXECUTE on policy-admin helpers from PUBLIC/anon/authenticated, then DROP.
-- NEVER apply to production project bxiyosyhkbyvnbqgictr — local / non-prod only.
--
-- Rollback (non-prod only): recreate bodies from 20260521120000_active_membership_rls.sql
-- with NO grants to PUBLIC, anon, or authenticated (service_role/postgres only).
-- Do NOT restore client-callable EXECUTE.

BEGIN;

REVOKE ALL ON FUNCTION public._tribeboard_drop_all_policies(regclass) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public._tribeboard_apply_household_member_select_policies(regclass) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public._tribeboard_apply_household_organiser_write_policies(regclass) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public._tribeboard_apply_run_operator_write_policies(regclass) FROM PUBLIC, anon, authenticated;

DROP FUNCTION IF EXISTS public._tribeboard_drop_all_policies(regclass);
DROP FUNCTION IF EXISTS public._tribeboard_apply_household_member_select_policies(regclass);
DROP FUNCTION IF EXISTS public._tribeboard_apply_household_organiser_write_policies(regclass);
DROP FUNCTION IF EXISTS public._tribeboard_apply_run_operator_write_policies(regclass);

COMMIT;

-- Residual: operators needing policy rebuild must use migrations / service_role only.
