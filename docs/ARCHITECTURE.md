# Tribeboard Architecture — Deep Dive

For the compact directory map and layer diagram, see `01_ARCHITECTURE.md`. This document covers the underlying mechanics.

## Design Philosophy

Tribeboard follows a **local-first architecture**.

Local state is always the source of truth for the UI.
Remote synchronization happens asynchronously and never blocks user actions.

This ensures the app works reliably even without connectivity.

## Data Flow

Two complementary paths:

**Local-first path (offline-capable domain data)**

SwiftUI Views
↓
DataSources (RunDataSource, ScheduleDataSource, DriverDataSource, HouseholdDataSource)
↓
Repositories (protocols in `Domain/Repositories`, implementations in `Infrastructure/`)
↓
Stores (JSON persistence: RunStore, ScheduleStore, DriverStore, HouseholdStore)

**Backend context path (Supabase-backed reads/writes)**

SwiftUI Views
↓
Backend contexts (BackendRunsContext, BackendChildrenContext, …)
↓
Backend services (`Services/Backend/*BackendService`)
↓
Supabase REST/RPC via `SupabaseClientProvider` (hand-rolled URLSession client, no SDK)

Views never access persistence directly.

## Stores

JSON files persist data locally:

runs.json
schedules.json
drivers.json
households.json
sync_queue.json
sync_audit.json
processed_sync_changes.json

Stores include corruption recovery. If corruption is detected the file is renamed:

filename.corrupt-timestamp.json

## Run System

Runs represent real-world trips.

`RunStateMachine` (Domain/Run) manages lifecycle states:

scheduled
assigned
inProgress
completed
cancelled

Per-stop states while in progress: pending → enRoute → arrived → completed / skipped.
Guards: terminal states are final; a stop cannot be departed without arriving;
a run cannot complete while stops remain unfinished.

## Run Adjustment Engine

`RunAdjustmentService` allows route changes during execution:
- insert stop
- remove stop
- defer stop
- reorder stops

Integrity rules prevent modifying completed or active stops.

## ETA System

`ETAEngine` estimates arrival times using:
- current location
- stop coordinates
- speed estimation (rolling window of recent samples — `SpeedEstimationService`)
- dwell time

`ETASmoothingService` prevents jitter; `ETAConfidence` scores stability.

## Live Tracking

Drivers publish GPS samples to `run_driver_positions` while a run is in progress
(`RunLocationPublishService`). Observers subscribe via `RealtimeService` and
`RunLocationObserverStore`.

## Multi-Household Support

All core records contain a `householdId`.
Household switching reloads scoped data sources and contexts.

## Sync Architecture

Offline-first sync using an outbox queue.

Components:

SyncQueueStore
SyncCoordinator (Services/)
RemoteSyncDriver (Domain/Sync contract; mock implementation in Infrastructure/Sync)

Push and pull operations synchronize local data with remote mirrors (`RemoteMirrorStore`).

## Conflict Handling

`SyncMergeService` detects:
- stale updates
- duplicate changes (ProcessedChangeStore dedupe)
- delete conflicts

Resolution model: last-change-wins.

Conflicts are logged (SyncAuditStore) but do not block the app.
See `Domain/Sync/ConflictResolution.md` for details.
