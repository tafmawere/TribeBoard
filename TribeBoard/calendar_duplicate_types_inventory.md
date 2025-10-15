# Calendar Module Duplicate Types Inventory

## Executive Summary

This document catalogs all duplicate type definitions found across the TribeBoard calendar modules in Services, Utilities, and Views directories. The audit identified 7 major categories of duplication that need consolidation.

## Duplicate Type Categories

### 1. SyncOperation Types

**Total Duplicates Found:** 4 definitions across 4 files

#### Locations and Variations:

1. **CalendarService.swift** (Lines 1568-1572)
   - Type: `enum SyncOperation: String`
   - Cases: create, update, delete
   - **Assessment:** Simple enum, missing comprehensive functionality

2. **CalendarBackgroundSyncProcessor.swift** (Lines 406-408)
   - Type: `struct SyncOperation`
   - Properties: id, type, event, userId, createdAt, retryCount
   - **Assessment:** Most comprehensive struct implementation with full metadata

3. **CalendarSyncManager.swift** (Lines 736-756)
   - Type: `class SyncOperation: Codable, Identifiable`
   - Properties: id, eventId, operationType, userId, createdAt, retryCount, lastAttempt, priority, maxRetries
   - **Assessment:** Most feature-complete with Codable conformance and retry logic

4. **SyncHistoryView.swift** (Lines 452-454)
   - Type: `enum SyncOperation: String, CaseIterable`
   - Cases: fullSync, incrementalSync, eventCreate, eventUpdate, eventDelete, conflictResolution
   - **Assessment:** UI-specific enum for display purposes

**Recommended Canonical Version:** CalendarSyncManager.swift - Most complete with Codable conformance and comprehensive properties

### 2. SyncOperationType Enums

**Total Duplicates Found:** 2 definitions

#### Locations and Variations:

1. **CalendarBackgroundSyncProcessor.swift** (Lines 416-420)
   - Type: `enum SyncOperationType: String, CaseIterable`
   - Cases: create, update, delete
   - **Assessment:** Basic implementation

2. **CalendarSyncManager.swift** (Lines 759-762)
   - Type: `enum SyncOperationType: String, Codable, CaseIterable`
   - Cases: create, update, delete
   - Additional: displayName computed property
   - **Assessment:** More complete with Codable conformance and display functionality

**Recommended Canonical Version:** CalendarSyncManager.swift - Has Codable conformance and display functionality

### 3. ValidationResult Types

**Total Duplicates Found:** 4 definitions across 4 files

#### Locations and Variations:

1. **PrototypeUtilities.swift** (Lines 169-172)
   - Properties: isValid, message, suggestion
   - **Assessment:** Basic implementation with suggestion field

2. **AccessibleEventCreationView.swift** (Lines 603-605)
   - Properties: isValid, message
   - **Assessment:** Minimal implementation with initializer

3. **Validation.swift** (Lines 236-240)
   - Properties: isValid, message, errorCode, timestamp
   - **Assessment:** Most comprehensive with error codes and timestamps

4. **CalendarEventValidationService.swift** (Lines 656-659)
   - Properties: errors, warnings arrays, computed isValid
   - **Assessment:** Calendar-specific with error/warning categorization

**Recommended Canonical Version:** CalendarEventValidationService.swift - Most appropriate for calendar context with error categorization

### 4. ValidationIssue Types

**Total Duplicates Found:** 2 definitions

#### Locations and Variations:

1. **CalendarBusinessRulesService.swift** (Lines 473-476)
   - Properties: id, rule, severity, message, suggestion, timestamp
   - **Assessment:** Calendar-specific with business rule context

2. **BrandConsistencyValidator.swift** (Lines 145-148)
   - Properties: type, severity, description, recommendation
   - **Assessment:** Brand-specific validation, not calendar-related

**Recommended Canonical Version:** CalendarBusinessRulesService.swift - Calendar-specific and more comprehensive

### 5. CalendarErrorRecoveryPriority Enums

**Total Duplicates Found:** 2 definitions

#### Locations and Variations:

1. **CalendarErrorLogger.swift** (Lines 488-492)
   - Type: `enum CalendarErrorRecoveryPriority`
   - Cases: low, medium, high, critical
   - **Assessment:** Basic enum without raw values

2. **CalendarErrorRecoveryService.swift** (Lines 509-513)
   - Type: `enum CalendarErrorRecoveryPriority: Int, CaseIterable`
   - Cases: low=1, medium=2, high=3, critical=4
   - Additional: displayName computed property
   - **Assessment:** More complete with Int raw values and display functionality

**Recommended Canonical Version:** CalendarErrorRecoveryService.swift - More complete with raw values and display functionality

### 6. SyncStatusInfo Structs

**Total Duplicates Found:** 2 definitions

#### Locations and Variations:

1. **CalendarService.swift** (Lines 1593-1596)
   - Properties: isOnline, isSyncing, syncProgress, lastSyncDate, pendingOperations, offlineStatistics, syncError
   - Additional: statusDescription computed property
   - **Assessment:** Calendar-specific with comprehensive status information

2. **SyncManager.swift** (Lines 622-625)
   - Properties: isOffline, isNetworkAvailable, isCloudKitAvailable, syncStatus, pendingCount, lastSyncDate, progress
   - Additional: statusMessage computed property
   - **Assessment:** More general sync manager focused

**Recommended Canonical Version:** CalendarService.swift - More comprehensive and calendar-specific

### 7. Utility Function Duplications

#### chunked(into:) Method

**Total Duplicates Found:** 2 identical implementations

**Locations:**
1. **CalendarBackgroundSyncProcessor.swift** (Lines 503-507)
2. **OfflineEventManager.swift** (Lines 708-712)

**Assessment:** Identical implementations, should be consolidated into a shared extension

#### networkStatusChanged Notification

**Total Duplicates Found:** 2 definitions

**Locations:**
1. **CalendarBackgroundSyncProcessor.swift** (Line 511)
2. **SyncManager.swift** (Line 649) - Part of larger notification extension

**Recommended Canonical Version:** SyncManager.swift - Part of comprehensive notification extension

## Consolidation Strategy

### Phase 1: Primary Type Consolidation
1. **SyncOperation** → Consolidate to CalendarSyncManager.swift version
2. **SyncOperationType** → Consolidate to CalendarSyncManager.swift version
3. **ValidationResult** → Consolidate to CalendarEventValidationService.swift version
4. **ValidationIssue** → Consolidate to CalendarBusinessRulesService.swift version
5. **CalendarErrorRecoveryPriority** → Consolidate to CalendarErrorRecoveryService.swift version
6. **SyncStatusInfo** → Consolidate to CalendarService.swift version

### Phase 2: Utility Function Consolidation
1. **chunked(into:)** → Create shared Array extension in CalendarUtilities.swift
2. **networkStatusChanged** → Use SyncManager.swift version, remove duplicate

### Phase 3: Reference Updates
- Update all references to point to canonical versions
- Add explicit namespacing where needed for disambiguation
- Remove obsolete type definitions

## Impact Assessment

### Files Requiring Updates (Reference Changes):
- CalendarService.swift
- CalendarBackgroundSyncProcessor.swift
- SyncHistoryView.swift
- PrototypeUtilities.swift
- AccessibleEventCreationView.swift
- Validation.swift
- CalendarErrorLogger.swift
- OfflineEventManager.swift

### Files Requiring Type Removal:
- CalendarService.swift (SyncOperation enum)
- CalendarBackgroundSyncProcessor.swift (SyncOperation struct, SyncOperationType enum, chunked method, networkStatusChanged)
- SyncHistoryView.swift (SyncOperation enum)
- PrototypeUtilities.swift (ValidationResult struct)
- AccessibleEventCreationView.swift (ValidationResult struct)
- Validation.swift (ValidationResult struct)
- CalendarErrorLogger.swift (CalendarErrorRecoveryPriority enum)
- OfflineEventManager.swift (chunked method)

### Compilation Risk Assessment:
- **High Risk:** SyncOperation type changes (multiple references across services)
- **Medium Risk:** ValidationResult changes (used in validation logic)
- **Low Risk:** Utility function consolidation (straightforward replacements)

## Next Steps

1. Begin with utility function consolidation (lowest risk)
2. Proceed with enum consolidations (medium risk)
3. Complete with struct consolidations (highest risk)
4. Perform incremental compilation validation after each major change
5. Execute comprehensive functional testing after consolidation