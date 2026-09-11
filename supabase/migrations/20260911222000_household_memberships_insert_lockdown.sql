-- WS-2 / AC-P0-2.1–2.7, G1, G2
-- Gate A: Replace unbounded self-or-organiser INSERT with organiser INSERT + first-member bootstrap.
-- NEVER apply to production project bxiyosyhkbyvnbqgictr — local / non-prod only.
--
-- Prior policy (rollback reference — DO NOT restore unbounded self-insert on any future prod path):
--   household_memberships_insert_self_or_organiser
--   FOR INSERT TO authenticated
--   WITH CHECK (user_id = auth.uid() OR is_active_household_organiser(household_id));
--
-- Rejoin after revoke: invite-accept SECURITY DEFINER after email bind (WS-3),
-- or active organiser INSERT of that user. No client self-insert rejoin path.

BEGIN;

DROP POLICY IF EXISTS household_memberships_insert_self_or_organiser ON public.household_memberships;

CREATE POLICY household_memberships_insert_organiser
  ON public.household_memberships
  FOR INSERT
  TO authenticated
  WITH CHECK (public.is_active_household_organiser(household_id));

-- AC-P0-2.7 / B1: first-member-only bootstrap (NOT lifelong created_by rejoin).
CREATE POLICY household_memberships_insert_creator_bootstrap
  ON public.household_memberships
  FOR INSERT
  TO authenticated
  WITH CHECK (
    user_id = auth.uid()
    AND EXISTS (
      SELECT 1
      FROM public.households h
      WHERE h.id = household_id
        AND h.created_by = auth.uid()
    )
    AND coalesce(lower(trim(status)), 'active') IN ('active', 'pending')
    -- Mandatory first-member: household has zero membership rows
    AND NOT EXISTS (
      SELECT 1
      FROM public.household_memberships hm
      WHERE hm.household_id = household_memberships.household_id
    )
    -- Belt-and-suspenders: no self-row for (household_id, auth.uid()) either
    AND NOT EXISTS (
      SELECT 1
      FROM public.household_memberships hm2
      WHERE hm2.household_id = household_memberships.household_id
        AND hm2.user_id = auth.uid()
    )
  );

COMMENT ON POLICY household_memberships_insert_creator_bootstrap ON public.household_memberships IS
  'First-member bootstrap only: created_by may self-INSERT when household has zero membership rows. Rejoin after revoke requires invite-accept (email bind) or organiser INSERT — never client self-insert.';

COMMENT ON POLICY household_memberships_insert_organiser ON public.household_memberships IS
  'Active organisers may INSERT memberships for their household (including re-adding revoked users).';

COMMIT;
