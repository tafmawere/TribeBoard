# Implementation Plan

- [x] 1. Update ModelContainer configuration with correct CloudKit identifier
  - Modify ModelContainerConfiguration.create() to use correct CloudKit container identifier
  - Change from "iCloud.com.tribeboard.TribeBoard" to "iCloud.net.dataenvy.TribeBoard"
  - _Requirements: 2.1_

- [x] 2. Implement fallback ModelContainer creation method
  - Create ModelContainerConfiguration.createWithFallback() method that tries CloudKit first, then local storage
  - Add private helper methods for CloudKit and local container creation
  - Implement proper error handling and logging for each creation attempt
  - _Requirements: 1.3, 3.2_

- [x] 3. Add robust error handling to ModelContainer creation
  - Create separate methods for CloudKit container and local-only container creation
  - Implement try-catch logic that gracefully handles CloudKit failures
  - Add detailed error logging for troubleshooting
  - _Requirements: 1.1, 3.1, 3.3_

- [x] 4. Update TribeBoardApp initialization to use fallback method
  - Replace the current init() method to use createWithFallback() instead of create()
  - Remove the fatalError that causes app crashes
  - Add proper error logging when ModelContainer creation encounters issues
  - _Requirements: 1.1, 1.2_

- [x] 5. Add unit tests for ModelContainer creation scenarios
  - Write tests for successful CloudKit container creation
  - Write tests for CloudKit failure fallback to local storage
  - Write tests for complete failure scenarios
  - _Requirements: 3.1, 3.2, 3.3_

- [x] 6. Test app launch in different environments
  - Verify app launches successfully in iOS Simulator (CloudKit limited)
  - Test app launch behavior when CloudKit is available vs unavailable
  - Ensure no crashes occur during ModelContainer initialization
  - _Requirements: 1.1, 1.3, 2.3_

- [x] 7. Validate and fix SwiftData model definitions
  - Review all @Model classes (Family, UserProfile, Membership) for proper SwiftData annotations
  - Ensure all models have valid initializers that don't conflict with SwiftData requirements
  - Verify @Relationship annotations have correct inverse relationships
  - Remove any duplicate or conflicting model declarations
  - _Requirements: 4.1, 4.2, 4.3, 4.4_

- [x] 8. Add SwiftData schema validation to ModelContainer creation
  - Add schema compilation checks before ModelContainer creation
  - Implement specific error handling for SwiftData model validation failures
  - Add logging for schema-related errors with actionable error messages
  - _Requirements: 3.4, 4.2_

- [x] 9. Fix SwiftData models to be CloudKit-compatible
  - Remove @Attribute(.unique) constraints from all models (id, code, appleUserIdHash)
  - Make all non-essential properties optional with default values
  - Make all relationships optional
  - Update model initializers to handle optional properties
  - Ensure models work with both CloudKit and local storage
  - _Requirements: 4.1, 4.2, 4.3, 4.4_

- [x] 10. Fix SwiftData fetch operations causing EXC_BREAKPOINT crashes
  - Investigate and fix the EXC_BREAKPOINT error occurring at line 61 in DataService.swift
  - Add error handling around fetch operations to prevent crashes
  - Implement safer fetch descriptor patterns that work with CloudKit-compatible models
  - Add validation to ensure ModelContext is in a valid state before fetch operations
  - Test fetch operations with both CloudKit and local storage configurations
  - _Requirements: 1.1, 3.1, 4.2_