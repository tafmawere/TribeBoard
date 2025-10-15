# Design Document

## Overview

This design outlines the refactoring approach for the TribeBoard Calendar module to eliminate code duplication, resolve type ambiguity, fix missing imports, and establish a clean, maintainable architecture. The refactoring will preserve all existing functionality while creating a single source of truth for calendar-related types and operations.

## Architecture

### Current State Analysis

The calendar module currently suffers from several architectural issues:

1. **Type Duplication**: Multiple definitions of core types like `SyncOperation`, `ValidationResult`, and `SyncOperationType` across different files
2. **Import Inconsistencies**: Missing UIKit and SwiftData imports in files that reference their symbols
3. **Misplaced SwiftUI Attributes**: Service and utility classes containing view-specific property wrappers
4. **Scattered Logic**: Calendar functionality spread across multiple services without clear ownership

### Target Architecture

The refactored architecture will follow a clear hierarchy:

```
TribeBoard/
├── Models/
│   └── Calendar*.swift (Core data models)
├── Services/
│   ├── CalendarService.swift (Primary calendar operations)
│   ├── CalendarBackgroundSyncProcessor.swift (Background processing)
│   └── Supporting services (specialized functionality)
├── Utilities/
│   └── Calendar*.swift (Helper functions and utilities)
└── Views/
    └── Components/Calendar*.swift (UI components)
```

## Components and Interfaces

### Core Type Consolidation

#### Primary Type Definitions Location
All core calendar types will be consolidated into `CalendarService.swift` as the single source of truth:

```swift
// CalendarService.swift - Canonical type definitions
enum SyncOperationType: String, Codable, CaseIterable {
    case create = "create"
    case update = "update"
    case delete = "delete"
    case sync = "sync"
}

struct SyncOperation: Codable {
    let id: UUID
    let type: SyncOperationType
    let eventId: UUID?
    let timestamp: Date
    let userId: UUID
    let retryCount: Int
    let status: SyncStatus
}

struct ValidationResult {
    let isValid: Bool
    let errors: [CalendarError]
    let warnings: [CalendarError]
    let message: String?
}

struct ValidationIssue {
    let type: ValidationIssueType
    let message: String
    let field: String?
    let severity: ValidationSeverity
}

enum CalendarErrorRecoveryPriority: Int, CaseIterable {
    case low = 1
    case medium = 2
    case high = 3
    case critical = 4
}

struct SyncStatusInfo {
    let isActive: Bool
    let lastSync: Date?
    let nextSync: Date?
    let pendingOperations: Int
    let errorCount: Int
    let status: SyncStatus
}
```

#### Type Migration Strategy
1. **Identify Canonical Version**: Choose the most complete and well-designed version of each duplicated type
2. **Update References**: Replace all other definitions with imports/references to the canonical version
3. **Namespace Resolution**: Use explicit namespacing (`TribeBoard.SyncOperation`) where needed to resolve ambiguity

### Service Layer Refactoring

#### CalendarService.swift - Primary Service
- **Responsibility**: Core CRUD operations, sync coordination, family permissions
- **Dependencies**: EventKitManager, ModelContext, CloudKitService
- **Key Methods**: 
  - Event management (create, update, delete, fetch)
  - Sync operations (enable/disable, trigger sync)
  - Permission management
  - Family event coordination

#### CalendarBackgroundSyncProcessor.swift - Background Processing
- **Responsibility**: Background sync operations, queue management, retry logic
- **Dependencies**: CalendarService, NetworkMonitor, CalendarEventCacheService
- **Key Methods**:
  - Background task registration and execution
  - Sync queue processing
  - Retry mechanism with exponential backoff

#### Supporting Services - Specialized Functionality
Each supporting service will have a single, focused responsibility:
- `CalendarErrorLogger.swift`: Error logging and analytics
- `CalendarPermissionManager.swift`: Permission handling
- `CalendarEventCacheService.swift`: Caching and performance
- `CalendarDataIntegrityService.swift`: Data validation and cleanup

### Utility Layer Organization

#### Shared Utilities Consolidation
Common utility functions will be consolidated to prevent duplication:

```swift
// CalendarUtilities.swift - Shared utility functions
extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

extension NetworkMonitor {
    func networkStatusChanged() -> AsyncStream<NetworkStatus> {
        // Single implementation for network status monitoring
    }
}
```

## Data Models

### Import Statement Standardization

Each file will have standardized imports based on its dependencies:

```swift
// Service files using UIKit
import Foundation
import UIKit
import SwiftData
import EventKit

// Service files using SwiftData only
import Foundation
import SwiftData
import EventKit

// View files
import SwiftUI
import Foundation

// Utility files
import Foundation
// Additional imports as needed per file
```

### SwiftUI Attribute Cleanup

Property wrapper usage will be strictly enforced:

- **Views and ViewModels**: May contain `@State`, `@StateObject`, `@ObservedObject`
- **Services**: Only `@Published` for ObservableObject conformance
- **Utilities**: No SwiftUI property wrappers
- **Models**: Only SwiftData attributes (`@Model`, `@Attribute`, etc.)

## Error Handling

### Protocol Conformance Resolution

#### Codable Conformance Strategy
For types that need Codable conformance but have issues:

```swift
struct SyncOperation: Codable {
    let id: UUID
    let type: SyncOperationType
    let eventId: UUID?
    let timestamp: Date
    
    // Explicit CodingKeys for complex cases
    enum CodingKeys: String, CodingKey {
        case id
        case type
        case eventId = "event_id"
        case timestamp
    }
}
```

#### EventKitManager Protocol Conformance
Ensure EventKitManager properly implements EventKitManagerProtocol:

```swift
class EventKitManager: EventKitManagerProtocol {
    // All protocol methods must be implemented
    func requestAccess() async throws -> Bool
    func createCalendar(name: String) async throws -> EKCalendar
    // ... other required methods
}
```

### Type Ambiguity Resolution Process

1. **Identify Conflicts**: Scan for multiple definitions of the same type name
2. **Choose Canonical**: Select the most complete and appropriate definition
3. **Update References**: Replace all other definitions with references to canonical version
4. **Add Namespacing**: Use explicit module namespacing where needed
5. **Validate Resolution**: Ensure all references compile correctly

## Testing Strategy

### Compilation Validation Process

1. **Incremental Building**: Build after each major change to catch issues early
2. **Full Clean Build**: Perform complete rebuild to ensure no cached compilation artifacts
3. **Import Validation**: Verify all imports resolve correctly
4. **Type Resolution**: Confirm no ambiguous type errors remain
5. **Protocol Conformance**: Validate all protocol implementations are complete

### Functional Preservation Testing

1. **Unit Test Execution**: Run existing unit tests to ensure functionality preservation
2. **Integration Testing**: Verify calendar sync operations continue working
3. **UI Testing**: Confirm calendar views render and function correctly
4. **Apple Calendar Integration**: Test EventKit integration remains functional

### Refactoring Validation Checklist

- [ ] All duplicate types removed or consolidated
- [ ] All missing imports added
- [ ] All SwiftUI attributes removed from non-view files
- [ ] All type ambiguities resolved
- [ ] All protocol conformance issues fixed
- [ ] Full project builds without errors
- [ ] All existing functionality preserved
- [ ] Apple Calendar integration functional

## Implementation Phases

### Phase 1: Type Consolidation
- Identify and catalog all duplicate types
- Choose canonical versions for each type
- Create consolidated type definitions in CalendarService.swift

### Phase 2: Import Standardization
- Audit all calendar files for missing imports
- Add required UIKit, SwiftData, and SwiftUI imports
- Standardize import statements across all files

### Phase 3: Attribute Cleanup
- Remove SwiftUI property wrappers from service and utility files
- Ensure proper ObservableObject conformance where needed
- Validate view files retain necessary property wrappers

### Phase 4: Reference Updates
- Update all type references to use canonical definitions
- Add explicit namespacing where needed for disambiguation
- Remove obsolete type definitions

### Phase 5: Protocol Conformance
- Fix all Codable conformance issues
- Ensure EventKitManager protocol implementation
- Resolve any remaining protocol conformance errors

### Phase 6: Validation and Testing
- Perform full compilation validation
- Run comprehensive test suite
- Verify Apple Calendar integration functionality
- Conduct final architectural review