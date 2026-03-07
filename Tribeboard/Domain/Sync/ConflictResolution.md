# Conflict Resolution Strategy (Planned)

This document defines the expected conflict approach for future backend synchronization.

## Runs

- Primary strategy: last-write-wins at the run record level.
- Execution events are prioritized over passive field edits.
- If execution status/progress conflicts with older schedule metadata, execution state wins.

## Schedules

- Merge by stable template `id`.
- Non-overlapping field edits merge directly.
- Competing edits on the same field use last-write-wins.
- Deletions are represented as flags/tombstones so remote peers can converge.

## Drivers

- Stable driver `id` is authoritative.
- Updates merge by `id`; missing records are treated as creates.
- Conflicting scalar fields use last-write-wins unless stricter business rules are introduced later.

## Why Deterministic and Stable IDs Matter

- Backend sync relies on identity continuity across devices and storage layers.
- Deterministic/stable IDs prevent duplicate entities during reconciliation.
- Earlier deterministic run IDs and stable UUID persistence make repository-to-backend mapping safe.
