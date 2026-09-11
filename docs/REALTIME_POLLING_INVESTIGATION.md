# Realtime polling investigation

**Status:** documentation only for websocket migration. This sprint does **not** replace REST polling with Supabase Realtime channels.

`SupabaseRealtimeService` implements the `RealtimeService` protocol but does **not** open a websocket. It REST-polls household-scoped tables every ~2 seconds and synthesizes insert/update/delete events by comparing ID sets and timestamp markers.

Source of truth for intervals, table list, JWT cache, and markers: `Tribeboard/Services/Backend/RealtimePollingConfiguration.swift`.

## Current implementation

| Item | Value |
| --- | --- |
| Transport | `URLSession` GET against PostgREST (`SupabaseClientProvider.restURL`) |
| Auth | Cached access token for the loop; `restoreSession()` only when the cache is missing/expired (30s leeway) or after HTTP 401 |
| Happy-path interval | **2.0s** (`pollIntervalNanoseconds`) |
| Waiting-for-auth interval | **2.0s** (`waitingAuthIntervalNanoseconds`) |
| Error backoff | **4.0s** (`errorBackoffNanoseconds`) — only when **every** table in the tick fails |
| Per-table isolation | One table 404/5xx does not abort the rest of the tick |
| Debounce (children / household UI) | 500ms after an event before context refresh |
| Run refresh | Serialized in `DemoShellView` (`isRealtimeRunRefreshInFlight`) |

### Tables polled each cycle

1. `children` (`updated_at`)
2. `child_activities` (`updated_at`)
3. `household_memberships` (`updated_at`) — pending → active membership updates emit `.updated`
4. `runs` (`updated_at`)
5. `run_driver_positions` (`updated_at`)

`run_assignments` exists on the protocol (`RealtimeEntityType.runAssignment`) but is **not** polled. Driver assignment changes are inferred from `runs` row updates. That table uses `assigned_at` if it is ever added to the loop.

Each request is:

```
GET /rest/v1/{table}?select=id,{marker}&household_id=eq.{householdId}
```

Change detection:

- More IDs than last snapshot → `.inserted` (first new ID)
- Fewer IDs → `.deleted` (first missing ID)
- Same IDs, different max marker → `.updated` (arbitrary first ID)
- First successful fetch only stores a baseline (no events)

## Lifecycle

1. `DemoShellView` assigns `realtimeService.onEvent` during `.task`.
2. After household bootstrap, `subscribeToHousehold` / `reconnectForHousehold` starts a single `Task` loop.
3. `unsubscribe()` cancels the task, clears snapshots, and sets `subscriptionState = disconnected`.
4. Called on sign-out, household clear, and view disappear.
5. If `restoreSession()` returns nil (and there is no still-valid cached JWT), the loop sleeps 2s in `waiting_auth` and does not hit the network.
6. Table failures are isolated. `subscriptionState` stays `subscribed` on a partial tick; `lastError` records the failed tables. Whole-tick `error` + 4s backoff only if every table fails.
7. HTTP 401 drops the cached JWT so the next cycle calls `restoreSession()`.

There is no app-lifecycle pause on this 2s household poll: it continues while the view exists, including when the scene is inactive, until `onDisappear` or unsubscribe.

A **separate** observer, `RunLocationObserverStore`, polls `run_driver_positions` every ~7s with `select=*`. That loop is gated to in-progress runs and paused when `scenePhase != .active`. It is not a Realtime protocol change.

## Battery and network cost

Per subscribed household, every 2 seconds:

- Up to 5 authenticated REST calls (a missing/404 table no longer skips the others)
- Full ID+marker payload for every matching row (not a cursor / `updated_at=gt.` filter)
- Session restore (`UserDefaults` + `/auth/v1/user`) only when the cached JWT is missing, within 30s of expiry, or after 401

Rough lower bound on a household with modest data: **~150 requests/minute**, plus JSON decode on the main actor. Driver-position polling at 2s remains the loudest radio cost during an in-progress run; the dedicated 7s observer now stays dark unless a run is in progress and the scene is active.

Implications:

- Cellular radios stay warm; doze / Low Power Mode will still schedule the sleeps but cannot coalesce these short timers.
- Backend rate limits and PostgREST CPU scale with household size, not with change rate.
- Multi-device families amplify writes: each client independently polls the same five tables.

## What a Realtime migration needs

Do **not** flip this on without:

1. **Channel model** — one household channel (or one channel per table) with `postgres_changes` filters `household_id=eq.{id}`. Confirm RLS allows the authenticated role to receive those events.
2. **Auth refresh** — reconnect on token refresh / 401. The poll loop now caches JWT and restores after 401; a websocket client needs the same.
3. **Replay / catch-up** — websocket gaps need a REST catch-up (`updated_at > lastMarker`) on subscribe and on reconnect. Today the first poll is silent; a migration must not drop the catch-up or the UI will miss changes that happened while disconnected.
4. **`run_assignments`** — either subscribe explicitly or keep deriving assignment from `runs`.
5. **Event identity** — current synthesizer emits one event per table per cycle and an arbitrary `recordId`. Realtime payloads include the full row; consumers (`BackendChildrenContext`, `BackendHouseholdContext`, run refresh) should take a household-scoped refresh (already the pattern) rather than assuming a single ID.
6. **Background policy** — pause channels in `.background`, resume on `.active`, matching `DemoShellView` scene-phase pull. The 7s location observer already follows this; the 2s household poll does not.
7. **Feature flag** — ship polling and websocket behind a DEBUG/remote flag until two-device family tests pass (invite accept, child add, start/arrive/depart, driver position).
8. **Do not change** invite/membership authorization, RLS, or Edge Functions as part of a client-only Realtime swap.

## Residual risks (polling)

- First snapshot swallows changes that occur between subscribe and the first successful fetch.
- Marker-only updates cannot distinguish *which* row changed when IDs are unchanged.
- Deletes of one row and inserts of another in the same 2s window can be misclassified (count-based).
- The 2s household poll still has no `scenePhase` pause (battery follow-up; not a protocol rewrite).
