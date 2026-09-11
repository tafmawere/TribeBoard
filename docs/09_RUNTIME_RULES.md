# Runtime Rules

1. Active household required for operations.
2. Local cache mirrors backend state; it is never authoritative.
3. Demo data cannot seed authenticated flows (demo flow is DEBUG-only).
4. Schedules must reference a valid child + household.
5. Runs must reference a valid schedule (or pass manual-creation validation).
6. Sync queue order: schedules → runs → assignments.
7. Sign-out clears user-scoped data.
8. Driver position publishing only while a run is in progress.
9. Backend writes require an authenticated session token (no anon writes).
