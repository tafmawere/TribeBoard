# Tribeboard Guardrails

These rules protect the architecture.

## Core Principles

1. Local-first architecture — local writes first, sync never blocks the UI
2. Runs represent real-world trips
3. Schedules represent recurring plans
4. Children are the central context (Child → School → Activities → Calendar → Schedule → Run)
5. Household scoping is absolute — only active-household data renders

## Do Not Change Without Explicit Decision

- RunStateMachine (Domain/Run)
- SyncCoordinator and the offline-first sync model
- Repository/store structure
- Household scoping / RLS assumptions
- `SupabaseClientProvider` request/auth conventions

## Data Access Rules

Views must never access persistence or the network directly.

Correct flows:

View → DataSource → Repository → Store            (local-first domain data)
View → Backend context → Backend service → Supabase  (backend reads/writes)

## Sync Rules

Local writes always occur first.
Remote sync must never block user actions.
Sync queue ordering: schedules → runs → assignments.
Conflicts must not crash the app (last-change-wins, logged to sync audit).

## Naming Rules

Do NOT rename:
- Schedule
- Run

These terms are core vocabulary.

## Roles

Membership roles are `admin` / `parent` / `driver` / `observer` (DB check constraint).
`household_people.role` allows `parent` / `driver` / `helper` / `guardian` / `relative` / `other`.
Do not invent new role vocabularies; the DB constraints win.

## Child Privacy

Children may have:
- legal name
- display name

Drivers may only see display names.

## Secrets

Never commit `Secrets.xcconfig`; use `Secrets.xcconfig.example` as the template.
Backend keys are read from Info.plist via `BackendConfig` — no hardcoded keys in Swift.

## Demo Mode

`AppConfig.isDemoFlowEnabled` is DEBUG-only. Demo seed data must never reach
authenticated flows.

## Testing Rules

Changes must not break:

- run creation and the run state machine (TribeboardTests cover these)
- schedule creation
- household switching
- sync push/pull
- ETA calculations
