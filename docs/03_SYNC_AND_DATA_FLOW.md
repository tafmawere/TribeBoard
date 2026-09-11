# Sync and Data Flow

Tribeboard uses a local-first architecture.

## Write Flow
User action
→ Local repository update
→ SyncOperation created
→ Operation queued
→ Immediate sync attempt
→ Backend update
→ Operation removed

## Offline Mode
If offline:
- operation stays queued
- UI still updates locally

When network returns:
- SyncCoordinator processes queue
- backend updates applied
- contexts refresh

## Realtime Flow
Backend change
→ Realtime event
→ Context refresh
→ UI update