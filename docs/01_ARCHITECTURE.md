# System Architecture

Tribeboard follows a layered, local-first architecture.

SwiftUI Views
↓
Contexts / DataSources / Stores
↓
Repositories (Domain) / Backend Services
↓
SyncCoordinator + RealtimeService + NetworkMonitor
↓
Supabase (REST + Auth + Realtime)

## Directory Map

- `Tribeboard/TribeboardApp.swift` — `@main`; bootstraps Google Maps/Sign-In, `AppFlowState`, `AuthSessionContext`, `BackendProfileContext`
- `Tribeboard/Views/Shell/` — `RootFlowView` (splash → auth → onboarding-or-main routing, invite deep links), `NavigationRouter`, `MainMenuView`, `AppConfig` (demo flow is DEBUG-only)
- `Tribeboard/Domain/` — pure business logic:
  - `Run/` — `RunStateMachine`, `ETAEngine`, `RunAdjustmentService`, `AttentionEngine`, `DispatchBucketer`, run creation/route validators, `RunStore`
  - `Schedule/` — `ScheduleTemplate`, `RunGeneratorService`, `Stop`, `ScheduleStore`
  - `Tenant/` — `Household`, `HouseholdMembership`, `HouseholdStore`
  - `Sync/` — `SyncQueueStore`, `SyncMergeService`, `SyncChange`, conflict types, `NetworkMonitor`
  - `Driver/`, `Location/`, `Repositories/` (repository protocols)
- `Tribeboard/Services/` — `SyncCoordinator`, notifications, routing, run location publishing
  - `Backend/` — one service per aggregate: Profile, Household, HouseholdPeople, HouseholdLocation, Child, Schedule, Run, Driver, EmergencyContacts, RunLocation; plus `RealtimeService` and `SupabaseClientProvider`
  - `Auth/` — `AuthService` (Supabase), `AppleSignInService`, `GoogleSignInService`, email OTP support
- `Tribeboard/Infrastructure/` — concrete repository implementations
  - `Sync/` — `LocalSyncQueueRepository`, `LocalSyncAuditRepository`, `LocalProcessedChangeRepository`, `RemoteMirrorStore`, `MockRemoteSyncDriver`
- `Tribeboard/Features/Onboarding/` — `OnboardingFlowCoordinator`, drafts, step routes, invite handling
- `Tribeboard/Views/` — feature-organized SwiftUI (Tribe, Family, Home, Runs, Calendar, Settings, Profile, …)
- `Tribeboard/UIRunModule/`, `Tribeboard/UICalendarModule/` — self-contained UI modules (driver mode, observer tracking, active-run map; calendar/schedule editing)
- `Tribeboard/Config/` — `BackendConfig` (reads Supabase URL/anon key from Info.plist via gitignored `Secrets.xcconfig`), sign-in configs, defaults

## Core Contexts (environment-injected ObservableObjects)
- AuthSessionContext
- BackendProfileContext
- BackendHouseholdContext + ActiveHouseholdContext
- BackendChildrenContext
- BackendSchedulesContext
- BackendRunsContext
- BackendDriversContext
- BackendHouseholdPeopleContext
- BackendEmergencyContactsContext
- BackendHouseholdLocationsContext

## Backend Client
Supabase is accessed through a hand-rolled URLSession client (`SupabaseClientProvider` → `auth/v1`, `rest/v1`, `rpc/…`). There is **no Supabase SDK dependency**. SPM packages: Google Maps, Google Places, Google Sign-In only.

## Infrastructure Components
- SyncCoordinator — drains the offline outbox queue
- SyncQueueStore / SyncAuditStore / ProcessedChangeStore — JSON persistence with corruption recovery
- NetworkMonitor — connectivity awareness
- RealtimeService — Supabase realtime subscriptions: `runs`, `children`, `child_activities`, `household_memberships`, `run_driver_positions`
