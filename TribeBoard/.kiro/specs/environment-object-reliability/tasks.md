# Implementation Plan

- [x] 1. Fix immediate crash in ScheduledRunsListView
  - Identify where ScheduledRunsListView is instantiated without AppState environment object
  - Add proper environment object injection at all usage points
  - Test that the crash is resolved
  - _Requirements: 1.1, 1.2, 1.3_

- [x] 2. Create SafeEnvironmentObject property wrapper
  - Implement SafeEnvironmentObject property wrapper with fallback mechanism
  - Add validation logic to detect missing environment objects
  - Create fallback AppState factory methods
  - Write unit tests for SafeEnvironmentObject behavior
  - _Requirements: 2.1, 2.2, 4.1, 4.2_

- [x] 3. Implement environment object validation utilities
  - Create EnvironmentValidator struct with validation methods
  - Add logging for environment object issues
  - Implement fallback AppState creation with safe defaults
  - Add error reporting for missing dependencies
  - _Requirements: 2.2, 4.1, 4.3, 4.4_

- [x] 4. Update ScheduledRunsListView with safe environment access
  - Replace @EnvironmentObject with SafeEnvironmentObject wrapper
  - Add fallback navigation handling when AppState is missing
  - Implement graceful error handling for navigation failures
  - Test view behavior with and without environment objects
  - _Requirements: 1.1, 1.2, 3.1, 3.2_

- [x] 5. Create preview environment setup utilities
  - Implement PreviewEnvironmentModifier for consistent preview setup
  - Add extension methods for easy preview environment injection
  - Update all SwiftUI previews to use consistent environment setup
  - Test that all previews work without crashes
  - _Requirements: 1.4, 2.1, 2.4_

- [x] 6. Add navigation safety mechanisms
  - Implement safe navigation methods in AppState extension
  - Add navigation error handling and recovery
  - Create NavigationStateManager for robust navigation state management
  - Test navigation behavior under error conditions
  - _Requirements: 3.1, 3.2, 3.3, 3.4_

- [x] 7. Update all school run views with safe environment access
  - Apply SafeEnvironmentObject pattern to SchoolRunDashboardView
  - Update RunDetailView and RunExecutionView with safe environment access
  - Ensure consistent environment object handling across all school run views
  - Test all views for environment object reliability
  - _Requirements: 1.1, 2.1, 3.1, 3.3_

- [x] 8. Create comprehensive unit tests for environment object handling
  - Write tests for SafeEnvironmentObject property wrapper
  - Add tests for environment object validation and fallback behavior
  - Create tests for navigation safety mechanisms
  - Test error handling and recovery scenarios
  - _Requirements: 2.3, 4.1, 4.2, 4.3_

- [x] 9. Add error handling UI components
  - Create user-friendly error messages for environment object issues
  - Implement recovery action buttons for common environment problems
  - Add non-intrusive error notifications
  - Test error UI behavior and user experience
  - _Requirements: 3.2, 4.2, 4.3_

- [x] 10. Validate and test complete solution
  - Run comprehensive testing of all environment object scenarios
  - Verify crash is completely resolved
  - Test app behavior under various error conditions
  - Validate that all requirements are met
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 2.1, 2.2, 2.3, 2.4, 3.1, 3.2, 3.3, 3.4, 4.1, 4.2, 4.3, 4.4_