# Security Remediation Implementation Notes — Gate A (WS-1…WS-5)

**Author:** Forge  
**Date:** 2026-09-11  
**Branch:** `security/rls-p0-remediation` (from `ROL_MOD`)  
**Design ACK:** Sentinel DESIGN ACK on `DESIGN_NOTE_WS1_WS5.md` (B1–B3 cleared)  
**Production project:** `bxiyosyhkbyvnbqgictr` — **NEVER apply / never `db push` / never `db remote commit`**

---

## Files delivered

| Path | WS |
|---|---|
| `migrations/20260911221000_revoke_tribeboard_policy_helpers.sql` | WS-1 |
| `migrations/20260911222000_household_memberships_insert_lockdown.sql` | WS-2 |
| `migrations/20260911223000_invite_preview_and_accept_bind.sql` | WS-3 |
| `migrations/20260911224000_drop_legacy_run_stops_all_policy.sql` | WS-4 |
| `migrations/20260911225000_revoke_excessive_grants.sql` | WS-5 |
| `tests/gate_a_security.sql` | catalog assertions |
| `docs/SECURITY_REMEDIATION_IMPLEMENTATION_NOTES.md` | this file |

Box mirror: `/workspace/forge-backend-audit/remediation/`  
Repo target: `/Users/tafmawere/Projects Kiro/TribeBoard/Tribeboard/{supabase/migrations,tests,docs}/`

---

## How to apply (LOCAL ONLY)

```bash
cd "/Users/tafmawere/Projects Kiro/TribeBoard/Tribeboard"

# Ensure NOT linked to bxiyosyhkbyvnbqgictr for push
# Prefer fresh local stack:
supabase init   # only if no config.toml yet
# OR copy migrations into sibling /Users/tafmawere/Projects\ Kiro/TribeBoard/supabase/migrations/

supabase start
# Apply via local reset (runs all migrations including Gate A):
supabase db reset
# OR apply only new files against local DB URL (never remote):
psql "$(supabase status -o env | sed -n 's/^DB_URL=//p')" -v ON_ERROR_STOP=1 \
  -f supabase/migrations/20260911221000_revoke_tribeboard_policy_helpers.sql \
  -f supabase/migrations/20260911222000_household_memberships_insert_lockdown.sql \
  -f supabase/migrations/20260911223000_invite_preview_and_accept_bind.sql \
  -f supabase/migrations/20260911224000_drop_legacy_run_stops_all_policy.sql \
  -f supabase/migrations/20260911225000_revoke_excessive_grants.sql

psql "$(supabase status -o env | sed -n 's/^DB_URL=//p')" -v ON_ERROR_STOP=1 \
  -f tests/gate_a_security.sql
```

**Hard guards**
- If `.supabase` / `project-id` / linked ref is `bxiyosyhkbyvnbqgictr`, do **not** run `supabase db push` or `supabase db remote commit`.
- Use local database URL only (`127.0.0.1` / Docker Postgres from `supabase start`).
- MCP `apply_migration` / `execute_sql` writes against live TribeBoard are forbidden for this gate.

---

## Change summary

### WS-1 — Policy helpers
- `REVOKE ALL … FROM PUBLIC, anon, authenticated` on `_tribeboard_drop_all_policies(regclass)` and three `_tribeboard_apply_*`.
- `DROP FUNCTION` all four.
- Residual: rebuild policies via migrations / service_role only.

### WS-2 — Membership INSERT lockdown
- Dropped `household_memberships_insert_self_or_organiser`.
- Added `household_memberships_insert_organiser` (`is_active_household_organiser`).
- Added `household_memberships_insert_creator_bootstrap` with **mandatory first-member** `NOT EXISTS` any membership for `household_id` **plus** per-user `NOT EXISTS` (B1 / AC-P0-2.7).
- Rejoin: invite-accept after email bind, or organiser INSERT only.

### WS-3 — Invite accept bind + preview strip
- `accept_household_invite`: after status/expiry checks, before membership mutations — fail-closed email bind:
  - null/blank/whitespace invite email → `email_required` (no membership writes)
  - require non-empty invite email AND non-empty `current_auth_email_lower()` AND equality → else `email_mismatch`
- `accept_household_invite_by_id` / `_by_token`: duplicate bind and/or funnel through paths that bind (empty `invite_code` path binds inline in `_by_token`).
- `get_invite_by_*`: same RETURN columns; `invite_token` and `backup_invite_code` always `NULL::text`.
- B3: `REVOKE ALL … FROM PUBLIC, anon` + `GRANT EXECUTE TO authenticated` on all six RPCs.

### WS-4 — run_stops
- `DROP POLICY IF EXISTS "Users access run stops" ON run_stops`.
- Keep AM/RO policies.

### WS-5 — Grants
- Sensitive tables: `REVOKE ALL FROM anon`; `REVOKE TRUNCATE FROM authenticated`.
- `waitlist`: `REVOKE ALL FROM anon` then `GRANT INSERT TO anon` only.

---

## AC mapping

| AC | Covered by |
|---|---|
| AC-P0-1.1–1.7 | WS-1 |
| AC-P0-2.1–2.7 | WS-2 |
| AC-P0-3.1–3.5 | WS-4 |
| AC-P0-4.1–4.9 | WS-3 accept* |
| AC-P1-5 | WS-3 get_invite_* |
| AC-P1-4 | WS-5 |
| G1/G2/G4/G6 | as in design note |

WS-6 (Gate B): deferred — `auth_check_email`, profiles peer SELECT, `resolve_household_by_join_code`, Edge `sendInviteEmail`.

---

## Rollback

| WS | Rollback (non-prod only) |
|---|---|
| WS-1 | Recreate helpers from `20260521120000_active_membership_rls.sql` with **no** PUBLIC/anon/authenticated EXECUTE |
| WS-2 | Prior policy text in migration comments — must **not** restore unbounded self-insert on any future prod path |
| WS-3 | Prior defs from 2026-09-11 live dump; do not re-grant anon/PUBLIC EXECUTE |
| WS-4 | Do **not** recreate ALL policy; rebuild AM/RO from `20260624120000` if needed |
| WS-5 | Re-grant only product-required privileges after review |

---

## Verify status (Forge)

- Box files written under `/workspace/forge-backend-audit/remediation/`.
- Mac: branch `security/rls-p0-remediation` from `ROL_MOD`, commit migrations + tests + notes.
- Local `supabase start` + `gate_a_security.sql`: see implementation report from Mac session.
- **Sentinel re-tests independently; does not trust Forge PASS.**
- **No production apply authorized.**

---

## Residual risk

- Empty household reclaim by original `created_by` via bootstrap if all membership rows deleted — accepted.
- Email typo locks invitee until re-invite.
- Preview still returns non-secret UI fields to any authenticated caller with code/id/token knowledge; secrets stripped and anon EXECUTE revoked (AC-P1-5 satisfied for tokens). Further bind-on-preview is optional hardening.
- WS-6 P1 items remain open until Gate B.


## Residual (documented — not Gate A blockers)

1. **get_invite_by_*** still returns household_id/name/role/status to any authenticated caller who knows a code (tokens NULL). Bind-on-preview remains optional hardening.
2. **accept rejoin after revoke:** fixed in WS-3 — non-active existing membership rows are UPDATE'd to active + invite access_role (AC-P0-4.4).
