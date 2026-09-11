# iOS overnight tech debt

Notes from the 2026-09-12 iOS sprint. Items here were **not** deleted or rewritten because confidence was not high enough, or because they sit next to the security freeze.

## Left in place on purpose

| Item | Why it stays |
| --- | --- |
| `DemoShellView` name / `DemoSheet` | The authenticated main shell. Renaming is a wide UI churn with no behaviour win. |
| `LaunchRootView` | Unused by `TribeboardApp` (entry is `RootFlowView`). Preview-only. Safe to delete later after confirming no storyboard/deep-link reference. |
| `FamilyMemberDisplay.from` | Unused in production UI. Parent detection no longer uses demo IDs; the type itself is leftover demo chrome. |
| `DemoSeedDataService` | DEBUG-only constants, currently unreferenced. Keep as a DEBUG seed hook. |
| `SystemBootstrap.debugSeedAndGenerate` | Callable in Release but does not seed demo templates (`seedDemoSchedules` is a no-op). Wide call-graph. |
| `RemoteSyncDebuggable` + `SyncCoordinator` seed helpers | No-op in Release because `remoteDriver` is `nil` and `MockRemoteSyncDriver` is DEBUG-only. System Tools already hides the buttons. |
| `FamilyRootView.FamilySeed` | Private demo members, unused by the authenticated path. |
| Invite accept / membership INSERT / Gate A | Security freeze. Client still calls existing `acceptPendingInvitesForSignedInUser` / RPC paths unchanged. `InviteAcceptCredentialResolver` is parsing/routing only (id → token → code). |
| Realtime → websocket | See `REALTIME_POLLING_INVESTIGATION.md`. REST polling only this sprint (JWT cache + per-table isolation shipped; no channels). |
| `AuthService.checkEmailExists` dependency on `auth-check` | Hardened to fail open to a **choice** UI (sign in *or* create account). Deploying the function is a backend task. |

## Follow-ups (client, non-security)

1. Rename `DemoShellView` → `AppShellView` once there is a dedicated UI rename PR.
2. Delete `LaunchRootView` after a reference sweep (Xcode project + previews).
3. Pause the **2s household** realtime poll in `scenePhase != .active` (battery); requires product sign-off on stale-data window. The separate 7s `RunLocationObserverStore` is already gated to in-progress runs and paused off-screen.
4. Surface `BackendRunsContext.lastSyncFailed` on Runs empty states the same way household/locations now distinguish error vs empty.
5. `BackendSchedulesContext` still assigns `error.localizedDescription` in a few paths; migrate remaining call sites to `BackendUserFacingErrorMapper`.
6. `HouseholdSwitcherView` still lists a separate local-cache section; confirm whether local household rows should be hidden when backend households exist.
7. `RootFlowView.applyDebugSkipOnboardingIfNeeded` remains DEBUG-only (`DebugFlags.skipOnboarding`). Do not lift that flag.

## Optional helpers extracted (test-only surface)

- `HouseholdBootstrapSequencer` — membership-refresh → create-flow / load-failed / continue. No membership INSERT.
- `HouseholdCreateName` / `HouseholdCreateRowPayload` — name trim + `households` row JSON. Membership create body unchanged.
- `InviteDeepLinkIngest` — parse + persist; signed-out path keeps the pending snapshot and returns `.savedForSignIn`.

## Verification gap

Mac verified **119/119** `TribeboardTests` PASS @ `d4d9780`. This Linux VM cannot run `xcodebuild`. Optional sequencer / create-payload / signed-out ingest tests landed after that SHA. **Mac re-run required** for the post-`d4d9780` commits before merge.
