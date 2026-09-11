# Sprint History

## Architecture Phase
0–6
Concept, architecture, domain design.

## Local App Phase
7–15
SwiftUI shell, calendar, run engine.

## Backend Integration
16–25
Supabase auth, households, children sync.

## Realtime Integration
26–35
Realtime updates and lifecycle management.

## Stability and UX
36 — Data Integrity & Initialization
37 — UX Corrections
38 — Member Invitation System
39 — School Location Search
40 — Schedule Engine Stability

## Backend Logistics
41 — Backend Schedule Sync
42 — Run Generation Sync
43 — Driver Assignment Sync

## Infrastructure
44 — Offline Sync Engine
45 — TestFlight Stabilization

## Auth & People
46 — Sign in with Apple (shipped)
53 — Backend household people / drivers persistence (`household_people`)

## ROL_MOD Era (current)
The `ROL_MOD` branch became the main development line. Work since Sprint 46 includes:
- Google Sign-In and email OTP
- Onboarding rework (`Features/Onboarding` coordinator flow)
- Household invites with join codes and deep links
- Live driver positions (`run_driver_positions`) and observer tracking
- Emergency contacts and household locations
- Run creation/route validation and active-run experience
- Family summary / FamilyStore (household member management)
