-- WS-4 / AC-P0-3.1–3.5
-- Gate A: Drop legacy ALL policy on run_stops that grants access via any membership (not active-gated).
-- NEVER apply to production project bxiyosyhkbyvnbqgictr — local / non-prod only.
--
-- Remaining policies (expected):
--   run_stops_select_active_member
--   run_stops_insert_run_operator
--   run_stops_update_run_operator
--   run_stops_delete_run_operator
--
-- Rollback: Do NOT recreate the ALL policy. If emergency AM/RO rebuild needed,
-- recreate only from 20260624120000_run_stops_backend_first.sql.

BEGIN;

DROP POLICY IF EXISTS "Users access run stops" ON public.run_stops;

COMMIT;
