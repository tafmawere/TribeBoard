# Tribeboard — Project Overview

## Product Vision
Tribeboard is a family logistics coordination platform that helps households coordinate children's schedules, school transport runs, and family responsibilities across devices.

## Core Capabilities
- Multi-user households ("tribes") with invites and join codes
- Child profiles with schools and activities
- Schedule templates → Run generation
- Driver assignment (member drivers and non-user household people)
- Run execution with live driver GPS, ETAs, and observer tracking
- Offline-first sync engine with retry, dedupe, and audit logging
- Realtime updates across devices
- Emergency contacts and household locations

## Current System Status
Stable Supabase-backed system with:
- Auth: Sign in with Apple, Google Sign-In, email OTP
- Local-first data model (JSON stores + outbox sync queue)
- Realtime sync (runs, children, activities, memberships, driver positions)
- Cross-device family support

## Active Branch
`ROL_MOD` — the main development line (far ahead of `main`).

## Related Docs
- `01_ARCHITECTURE.md` — layers and directory map
- `02_DOMAIN_MODELS.md` — entities and roles
- `08_BACKEND_SCHEMA.md` — table list
- `GUARDRAILS.md` — rules that protect the architecture
