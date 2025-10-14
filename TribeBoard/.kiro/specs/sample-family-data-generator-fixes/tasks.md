# Implementation Plan

- [x] 1. Fix error type conversion issues
  - Add error conversion extension to SampleDataError
  - Replace SampleDataError throws with FamilyCreationError where required
  - Maintain error context and information during conversion
  - _Requirements: 1.1, 1.2, 4.1, 4.3_

- [x] 2. Resolve main actor isolation violations
  - Mark methods calling DataService as async where needed
  - Add await keywords for main actor isolated method calls
  - Ensure proper async context propagation
  - _Requirements: 2.1, 2.2, 2.3_

- [x] 3. Complete switch statement coverage
  - Add missing enum cases to switch statements
  - Ensure exhaustive coverage for all error categorization
  - Add appropriate default cases where needed
  - _Requirements: 3.1, 3.2, 3.3_

- [x] 4. Add unit tests for error conversion
  - Test SampleDataError to FamilyCreationError conversion
  - Verify error context preservation
  - Test all conversion mapping scenarios
  - _Requirements: 4.2_

- [x] 5. Add integration tests for async behavior
  - Test async method execution with DataService
  - Verify main actor isolation compliance
  - Test error propagation in async contexts
  - _Requirements: 2.1, 2.2_