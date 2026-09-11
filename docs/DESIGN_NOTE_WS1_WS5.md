# Forge Design Note — WS-1..5 Security Remediation

**Author:** Forge  
**Date:** 2026-09-11  
**Status:** Awaiting Sentinel DESIGN ACK — Sentinel REQUEST CHANGES addressed (B1–B3 delta below); do not implement until ACK  
**Branch (planned):** `security/rls-p0-remediation` from `ROL_MOD`  
**DB:** local Supabase CLI and/or dedicated non-prod only — **never** `bxiyosyhkbyvnbqgictr`  
**Plan:** `/workspace/tribeboard-baseline/TRIBEBOARD_SECURITY_REMEDIATION_PLAN.md`  
**ACs:** `/workspace/sentinel-verification/report/TRIBEBOARD_SECURITY_ACCEPTANCE_CRITERIA.md`

> **DELTA B3 (2026-09-11 final):** `REVOKE ALL … FROM PUBLIC, anon` on every `accept_household_invite*` and `get_invite_by_*`, then `GRANT EXECUTE TO authenticated` only. PUBLIC grant must be absent.


---

## Hard FAIL guards (will not ship)

1. `REVOKE … FROM PUBLIC` alone — insufficient. Always also revoke `anon` and `authenticated`.
2. Any `household_memberships` INSERT `WITH CHECK` that allows unbounded `user_id = auth.uid()` for arbitrary `household_id`.

---

## Migration sequence

| # | File (timestamp TBD at implement) | WS |
|---|---|---|
| 1 | `*_revoke_tribeboard_policy_helpers.sql` | WS-1 |
| 2 | `*_household_memberships_insert_lockdown.sql` | WS-2 |
| 3 | `*_invite_preview_and_accept_bind.sql` | WS-3 |
| 4 | `*_drop_legacy_run_stops_all_policy.sql` | WS-4 |
| 5 | `*_revoke_excessive_grants.sql` | WS-5 |
| 6 | optional P1 on same branch | WS-6 |

---

## WS-1 — Policy-admin helpers

**Change:**
1. `REVOKE ALL ON FUNCTION public._tribeboard_drop_all_policies(regclass) FROM PUBLIC, anon, authenticated;`
2. Same for `_tribeboard_apply_household_member_select_policies`, `_tribeboard_apply_household_organiser_write_policies`, `_tribeboard_apply_run_operator_write_policies`.
3. After confirm iOS/client never calls them: `DROP FUNCTION` all four (preferred per AC-P0-1.7). If drop deferred, grants remain service_role/postgres only.

**ACs:** AC-P0-1.1–1.7, G4, G6  

**Rollback:** Recreate function bodies from `20260521120000_active_membership_rls.sql` with **no** grants to PUBLIC/anon/authenticated.

**Residual:** Operators needing policy rebuild use migration/service_role only.

---

## WS-2 — Membership INSERT lockdown

**Change:**
1. `DROP POLICY IF EXISTS household_memberships_insert_self_or_organiser ON public.household_memberships;`
2. `CREATE POLICY household_memberships_insert_organiser … FOR INSERT TO authenticated WITH CHECK (public.is_active_household_organiser(household_id));`
3. **Chosen AC-P0-2.7 rule: first-member-only bootstrap** (not merely “no row for this user”).

   `CREATE POLICY household_memberships_insert_creator_bootstrap … FOR INSERT TO authenticated WITH CHECK (
     user_id = auth.uid()
     AND EXISTS (
       SELECT 1 FROM public.households h
       WHERE h.id = household_id AND h.created_by = auth.uid()
     )
     AND coalesce(lower(trim(status)), 'active') IN ('active', 'pending')
     -- B1 / AC-P0-2.7 MANDATORY first-member
     AND NOT EXISTS (
       SELECT 1 FROM public.household_memberships hm
       WHERE hm.household_id = household_memberships.household_id
     )
     -- B1 also: soft-revoked self-row cannot re-INSERT if somehow present alone
     AND NOT EXISTS (
       SELECT 1 FROM public.household_memberships hm2
       WHERE hm2.household_id = household_memberships.household_id
         AND hm2.user_id = auth.uid()
     )
   );`

   Meaning (MANDATORY, not optional): client self-INSERT only when the household has **zero** membership rows (initial create bootstrap). First-member constraint is required. The per-user NOT EXISTS is belt-and-suspenders for soft-revoked rows. Once any membership exists, bootstrap INSERT is denied.

4. **Rejoin after revoke (documented):** creator or any former member must use (a) invite-accept SECURITY DEFINER after email/claim bind (WS-3), or (b) active organiser INSERT of that user. No client self-insert rejoin path.

5. Joiners’ first join: membership rows created **only** inside invite-accept SECURITY DEFINER after bind (WS-3). No client self-insert for foreign households.

**ACs:** AC-P0-2.1–2.7, G1, G2  

**Rollback:** Document prior policy text in migration comment; reverse migration on non-prod only (must not restore unbounded self-insert on any future prod path).

**Residual:** If every membership row is deleted and household is empty, original `created_by` could bootstrap again — acceptable reclaim; still cannot join *foreign* households. Revoked creator with any remaining membership rows (including their own revoked row, or peers) cannot self-rejoin via INSERT.

---

## WS-3 — Invite accept bind + preview strip

**Accept RPCs** (`accept_household_invite`, `_by_id`, `_by_token`):
1. Keep/require `auth.uid()` non-null → else `not_authenticated`.
2. **B2 fail-closed email:** After loading invite, if `invite.email` is NULL / blank / whitespace-only → DENY immediately (no membership writes). Empty invite email must **not** match empty caller email (`'' = ''` is forbidden).
3. Require `length(trim(invite.email)) > 0` AND `length(public.current_auth_email_lower()) > 0` AND `lower(trim(invite.email)) = public.current_auth_email_lower()`; else DENY with no membership writes.
4. Then existing expiry/cancelled/claimed/activate logic.
5. **B3 (MANDATORY) — explicit SQL for each accept overload:**
   ```sql
   REVOKE ALL ON FUNCTION public.accept_household_invite(text) FROM PUBLIC, anon;
   REVOKE ALL ON FUNCTION public.accept_household_invite_by_id(uuid) FROM PUBLIC, anon;
   REVOKE ALL ON FUNCTION public.accept_household_invite_by_token(text) FROM PUBLIC, anon;
   GRANT EXECUTE ON FUNCTION public.accept_household_invite(text) TO authenticated;
   GRANT EXECUTE ON FUNCTION public.accept_household_invite_by_id(uuid) TO authenticated;
   GRANT EXECUTE ON FUNCTION public.accept_household_invite_by_token(text) TO authenticated;
   -- Verify: has_function_privilege('public', …) / PUBLIC grant ABSENT
   ```

**Preview RPCs** (`get_invite_by_code`, `_by_id`, `_by_token`):
1. Replace return shape / SELECT list to **exclude** `invite_token` (and any backup code columns).
2. Prefer: authenticated only + (email match OR organiser of household OR row appears in pending-for-current-user semantics).
3. **B3 (MANDATORY) — explicit SQL for each preview overload:**
   ```sql
   REVOKE ALL ON FUNCTION public.get_invite_by_code(text) FROM PUBLIC, anon;
   REVOKE ALL ON FUNCTION public.get_invite_by_id(uuid) FROM PUBLIC, anon;
   REVOKE ALL ON FUNCTION public.get_invite_by_token(text) FROM PUBLIC, anon;
   GRANT EXECUTE ON FUNCTION public.get_invite_by_code(text) TO authenticated;
   GRANT EXECUTE ON FUNCTION public.get_invite_by_id(uuid) TO authenticated;
   GRANT EXECUTE ON FUNCTION public.get_invite_by_token(text) TO authenticated;
   -- Verify: PUBLIC grant ABSENT on all three
   ```

**ACs:** AC-P0-4.1–4.9, AC-P1-5, G1, G2, G6  

**AC-P0-4.2/4.9:** Claim-token bind is acceptable only because preview strips `invite_token` / backup codes and EXECUTE is revoked from **PUBLIC and anon** on get_invite_* (authenticated only) — tokens must not be obtainable from unbound preview.  

**iOS:** Deep-link accept must use authenticated session; UI must not require raw token from preview. Server is SoT — Swift follow-up after migrations land.

**Rollback:** Prior function definitions in migration down section / comments.

**Residual:** Email typo locks invitee until re-invite; case/normalization handled via lower(trim).

---

## WS-4 — Legacy run_stops policy

**Change:** `DROP POLICY IF EXISTS "Users access run stops" ON public.run_stops;`  
Verify remaining: `run_stops_select_active_member`, `run_stops_insert/update/delete_run_operator` only.

**ACs:** AC-P0-3.1–3.5  

**Rollback:** Do not recreate ALL policy; if emergency, recreate only AM/RO set from `20260624120000_run_stops_backend_first.sql`.

---

## WS-5 — Grant hygiene

**Change:**
1. For sensitive tables (`profiles`, `households`, `household_memberships`, `household_invites`, `household_people`, `household_locations`, `children`, `child_activities`, `schedule_templates`, `schedule_stops`, `runs`, `run_stops`, `emergency_contacts`, `location_cache`):  
   `REVOKE ALL ON TABLE … FROM anon;`  
   `REVOKE TRUNCATE ON TABLE … FROM authenticated;`  
   Keep authenticated SELECT/INSERT/UPDATE/DELETE as PostgREST needs (RLS still enforces).
2. Exception: `waitlist` — `GRANT INSERT ON waitlist TO anon` only (document); revoke other anon privileges on waitlist if present.

**ACs:** AC-P1-4, G4  

**Rollback:** Re-grant only what product requires on non-prod after review.

---

## WS-6 (capacity / same branch if time)

- `auth_check_email`: REVOKE anon EXECUTE (AC-P1-1)
- profiles peer SELECT: replace with active co-membership + `TO authenticated` (AC-P1-2)
- `resolve_household_by_join_code`: REVOKE anon EXECUTE (AC-P1-3)
- Edge `sendInviteEmail`: organiser check — separate if Edge deploy needed on non-prod

P0 gate for Sentinel attack = WS-1..5.

---

## Automated tests (Forge)

- SQL assertions: `has_function_privilege` false for anon/authenticated on helpers (or functions absent).
- Stranger INSERT membership → fail; creator bootstrap → success.
- Wrong-email accept → fail; matching email → success.
- Preview result columns exclude invite_token.
- Revoked member cannot SELECT run_stops.
- Catalog: anon has no TRUNCATE/DML on sensitive tables.
- Run existing TribeboardTests after any Swift stub updates.

---

## Non-prod verification Forge will run

Local `supabase db reset` / migrate up; run SQL test file; note results in implementation report. **Sentinel re-tests independently and does not trust Forge PASS.**

---

**Request:** Sentinel design review ACK (or requested changes). Forge will not write migration files until ACK.

---

## DELTA — Sentinel design review REQUEST CHANGES (B1–B3)

Responding to `/workspace/sentinel-verification/report/TRIBEBOARD_FORGE_DESIGN_REVIEW.md`.

| ID | Change in this note |
|---|---|
| **B1** | Bootstrap WITH CHECK is **mandatory first-member**: `NOT EXISTS` any membership for `household_id`, **plus** `NOT EXISTS` membership for `(household_id, auth.uid())`. No lifelong `created_by` rejoin; rejoin = invite-accept or organiser INSERT only. |
| **B2** | Accept* DENY if invite.email null/blank/whitespace; require non-empty invite email AND non-empty caller email AND equal normalized; empty≠empty. |
| **B3** | **CLOSED in note:** WS-3 now has verbatim `REVOKE ALL … FROM PUBLIC, anon` + `GRANT EXECUTE TO authenticated` for all accept* and get_invite_by_* overloads. PUBLIC grant must not remain. |

WS-1 / WS-4 / WS-5 unchanged from prior endorsement.

**Still not implementing** until Sentinel DESIGN ACK.



## DELTA — Sentinel accept rejoin fix (AC-P0-4.4)

In `accept_household_invite` and `accept_household_invite_by_token`: if a membership row exists with non-active status (pending/revoked/removed/inactive/declined/…), **UPDATE** to `status=active` and invite `access_role` (then claim invite → `joined`). Do **not** fall through to INSERT → unique_violation → `already_member`. `already_member` only when existing status is already `active`.
