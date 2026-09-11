# Current State

Branch: `ROL_MOD` (main development line; `main` is well behind)

## Implemented
- Backend authentication: Apple Sign-In, Google Sign-In, email OTP
- Households, memberships, invites (join codes, deep links)
- Household people (non-user adults/drivers) and household locations
- Children + activities sync
- Schedule templates + stops sync
- Run generation, manual run creation with validation
- Run execution: state machine, ETAs, live driver positions, observer tracking
- Driver assignment
- Emergency contacts
- Offline sync queue with audit + dedupe
- Realtime updates
- Onboarding coordinator flow

## In Flight
Large working set on `ROL_MOD`: onboarding rework, run creation validation,
location services, invite polish. Check `git status` — the working tree often
carries significant uncommitted work.

## Validation
Two-device family testing via TestFlight.
