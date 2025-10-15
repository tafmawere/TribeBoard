# Implementation Plan

- [x] 1. Audit and catalog duplicate types across calendar modules
  - Scan all calendar-related files in Services, Utilities, and Views directories
  - Create comprehensive inventory of duplicate type definitions (SyncOperation, ValidationResult, etc.)
  - Document current locations and variations of each duplicated type
  - Identify the most complete and appropriate canonical version for each type
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8, 4.1, 4.2, 4.3_

- [x] 2. Consolidate core calendar types in CalendarService.swift
  - [x] 2.1 Create canonical SyncOperation and SyncOperationType definitions
    - Remove duplicate SyncOperation definitions from CalendarBackgroundSyncProcessor.swift and SyncHistoryView.swift
    - Remove duplicate SyncOperationType definitions from CalendarSyncManager.swift
    - Implement single, comprehensive SyncOperation struct in CalendarService.swift
    - Update all references to use the canonical CalendarService.SyncOperation type
    - _Requirements: 1.1, 1.2, 4.4, 4.5, 4.6_

  - [x] 2.2 Consolidate ValidationResult and ValidationIssue types
    - Remove ValidationResult duplicates from PrototypeUtilities.swift, Validation.swift, and AccessibleEventCreationView.swift
    - Remove ValidationIssue duplicates from CalendarEventValidationService.swift
    - Create single ValidationResult and ValidationIssue definitions in CalendarService.swift
    - Update all validation logic to use consolidated types
    - _Requirements: 1.3, 1.4, 4.4, 4.5_

  - [x] 2.3 Consolidate CalendarErrorRecoveryPriority and SyncStatusInfo
    - Identify and remove duplicate CalendarErrorRecoveryPriority definitions
    - Create canonical SyncStatusInfo struct with proper closing braces and complete property definitions
    - Update all error handling and sync status logic to use consolidated types
    - _Requirements: 1.5, 1.6, 4.4, 4.5_

- [x] 3. Standardize import statements across all calendar files
  - [x] 3.1 Add missing UIKit imports to files using UIKit symbols
    - Add `import UIKit` to CalendarBackgroundSyncProcessor.swift for UIBackgroundTaskIdentifier usage
    - Add `import UIKit` to CalendarHapticManager.swift for UIKit haptic feedback classes
    - Add `import UIKit` to any other files referencing UIApplication or UIKit symbols
    - _Requirements: 2.1, 2.2, 2.7_

  - [x] 3.2 Add missing SwiftData imports to files using SwiftData symbols
    - Add `import SwiftData` to files referencing ModelContext, ModelConfiguration, or ModelContainer
    - Verify SwiftData imports in all calendar service files that interact with data persistence
    - Add SwiftData imports to calendar utility files that work with data models
    - _Requirements: 2.3, 2.4, 2.5_

  - [x] 3.3 Ensure SwiftUI imports in all view files
    - Verify `import SwiftUI` exists in all calendar view component files
    - Add missing SwiftUI imports to any calendar view files that lack them
    - Standardize import order (SwiftUI, Foundation, other frameworks)
    - _Requirements: 2.6_

- [x] 4. Remove misplaced SwiftUI property wrappers from service and utility classes
  - [x] 4.1 Clean up calendar service files
    - Remove @State, @StateObject, and @ObservedObject attributes from CalendarService.swift
    - Remove SwiftUI property wrappers from CalendarErrorLogger.swift and other service files
    - Ensure only @Published attributes remain for ObservableObject conformance where appropriate
    - _Requirements: 3.1, 3.2, 3.3, 3.7_

  - [x] 4.2 Clean up calendar utility files
    - Remove @State, @StateObject, and @ObservedObject attributes from CalendarTestingFramework.swift
    - Remove SwiftUI property wrappers from CalendarHapticManager.swift and other utility files
    - Ensure utility classes maintain clean, non-UI-dependent interfaces
    - _Requirements: 3.4, 3.5, 3.6, 3.7_

- [x] 5. Resolve type ambiguity and update all references
  - [x] 5.1 Update SyncOperation references throughout codebase
    - Replace all SyncOperation references to point to CalendarService.SyncOperation
    - Add explicit namespacing (TribeBoard.SyncOperation) where compiler disambiguation is needed
    - Update method signatures and variable declarations to use canonical type
    - _Requirements: 4.1, 4.2, 4.3, 4.7_

  - [x] 5.2 Update ValidationResult references throughout codebase
    - Replace all ValidationResult references to point to CalendarService.ValidationResult
    - Update validation method return types and parameter types
    - Ensure consistent validation error handling across all calendar components
    - _Requirements: 4.5, 4.6, 4.7_

  - [x] 5.3 Remove obsolete type definitions and clean up imports
    - Delete removed type definitions from their original locations
    - Clean up any unused imports that were only needed for deleted types
    - Update file-level documentation to reflect type consolidation changes
    - _Requirements: 1.9, 4.4, 4.5_

- [x] 6. Fix protocol conformance issues
  - [x] 6.1 Resolve Codable conformance problems
    - Add explicit CodingKeys enums to structs with Codable conformance issues
    - Ensure all properties in Codable structs are themselves Codable
    - Fix any custom encoding/decoding implementations that are incomplete
    - _Requirements: 5.1, 5.2, 5.3_

  - [x] 6.2 Ensure EventKitManager protocol conformance
    - Verify EventKitManager class implements all required EventKitManagerProtocol methods
    - Fix any missing method implementations or signature mismatches
    - Update method implementations to match protocol requirements exactly
    - _Requirements: 5.4, 5.5_

- [x] 7. Consolidate shared utility functions
  - [x] 7.1 Create single implementation of chunked(into:) method
    - Identify all implementations of chunked(into:) method across calendar files
    - Create single, optimized implementation in a shared utility extension
    - Remove duplicate implementations and update all references
    - _Requirements: 1.7, 6.6_

  - [x] 7.2 Consolidate networkStatusChanged functionality
    - Identify duplicate network status monitoring implementations
    - Create single networkStatusChanged implementation in NetworkMonitor extension
    - Update all calendar services to use consolidated network monitoring
    - _Requirements: 1.8, 6.6_

- [x] 8. Organize calendar architecture for consistency
  - [x] 8.1 Centralize calendar synchronization logic in CalendarService.swift
    - Move scattered sync logic from other services into CalendarService
    - Ensure CalendarService is the single entry point for all sync operations
    - Update other services to delegate sync operations to CalendarService
    - _Requirements: 6.1, 6.6_

  - [x] 8.2 Organize background processing in CalendarBackgroundSyncProcessor.swift
    - Ensure all background task logic is contained within CalendarBackgroundSyncProcessor
    - Move any scattered background processing code into this dedicated service
    - Update background task coordination to follow single responsibility principle
    - _Requirements: 6.2, 6.6_

  - [x] 8.3 Minimize and deduplicate supporting functionality
    - Ensure backup, validation, and error logging functionality is minimal and non-duplicated
    - Consolidate overlapping functionality between CalendarBackupService, CalendarDataIntegrityService, etc.
    - Update service dependencies to eliminate circular references and duplication
    - _Requirements: 6.3, 6.4, 6.5_

- [x] 9. Perform comprehensive build validation
  - [x] 9.1 Execute incremental compilation validation
    - Build project after each major refactoring step to catch issues early
    - Fix any compilation errors that arise from type consolidation changes
    - Verify that all import statements resolve correctly during compilation
    - _Requirements: 7.1, 7.2, 7.3, 7.4_

  - [x] 9.2 Perform full clean build validation
    - Execute complete clean build to ensure no cached compilation artifacts cause issues
    - Verify that calendar module compiles cleanly without any errors or warnings
    - Confirm that Apple Calendar integration compiles and links correctly
    - _Requirements: 7.5, 7.6, 7.7_

- [x] 10. Validate functional preservation and integration
  - [x] 10.1 Test existing calendar functionality preservation
    - Run existing unit tests to ensure no functionality was broken during refactoring
    - Manually test calendar event creation, editing, and deletion workflows
    - Verify that calendar synchronization with Apple Calendar continues working
    - Test family calendar permissions and sharing functionality
    - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.7_

  - [x] 10.2 Validate Apple Calendar integration functionality
    - Test EventKit permission requests and calendar access
    - Verify calendar event sync operations work correctly with Apple Calendar
    - Test background sync processing and conflict resolution
    - Ensure calendar UI components render and function correctly
    - _Requirements: 8.5, 8.6, 8.7_