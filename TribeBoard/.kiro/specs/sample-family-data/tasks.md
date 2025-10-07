# Implementation Plan

- [x] 1. Create sample family data structures and generator utility
  - Create SampleFamilyData and SampleMemberData structures to define family compositions
  - Implement SampleFamilyDataGenerator class with core generation logic
  - Add predefined data for 5 realistic families with proper member roles
  - _Requirements: 1.1, 1.2, 2.1, 2.2_

- [x] 2. Implement family creation logic with validation
  - [x] 2.1 Add family creation method that uses existing DataService patterns
    - Implement createSampleFamily method with proper error handling
    - Use FamilyCodeGenerator for unique code generation
    - Validate family data before database insertion
    - _Requirements: 1.1, 1.3, 4.1_

  - [x] 2.2 Add user profile creation for sample members
    - Implement createSampleUsers method to generate UserProfile instances
    - Generate realistic Apple ID hashes for testing purposes
    - Validate user data meets existing model requirements
    - _Requirements: 2.1, 2.2, 2.4_

  - [x] 2.3 Add membership creation and role assignment
    - Implement createMemberships method to link users to families
    - Ensure proper role assignment including parent_admin constraints
    - Use existing DataService membership creation patterns
    - _Requirements: 2.1, 2.2, 2.3_

- [x] 3. Implement idempotency and conflict resolution
  - [x] 3.1 Add existing family detection logic
    - Implement checkExistingFamilies method to detect sample families
    - Query families by name patterns to identify existing sample data
    - Return list of existing family codes for reference
    - _Requirements: 4.1, 4.2, 4.4_

  - [x] 3.2 Add family code conflict handling
    - Implement code regeneration logic when conflicts occur
    - Ensure generated codes are unique across all families
    - Add retry mechanism for code generation failures
    - _Requirements: 1.4, 4.1_

- [x] 4. Add console output and user feedback system
  - [x] 4.1 Implement family code output formatting
    - Create outputFamilyCodes method with clear console formatting
    - Display family names, codes, and member counts
    - Include usage instructions for testing join family functionality
    - _Requirements: 3.1, 3.2, 3.3, 3.4_

  - [x] 4.2 Add operation status reporting
    - Implement feedback for creation vs. skipped operations
    - Report successful family creation with details
    - Provide clear messaging for idempotent behavior
    - _Requirements: 4.3, 4.4_

- [x] 5. Integrate with existing app infrastructure
  - [x] 5.1 Add demo menu integration
    - Create demo menu option to trigger sample data generation
    - Integrate with existing DemoControlPanel or similar component
    - Add proper async/await handling for UI integration
    - _Requirements: 3.4_

  - [x] 5.2 Add error handling integration
    - Use existing ErrorHandlingUtilities for consistent error reporting
    - Implement SampleDataError enum with proper LocalizedError conformance
    - Add logging integration for debugging and monitoring
    - _Requirements: 1.5, 4.3_

- [x] 6. Add comprehensive testing coverage
  - [x]* 6.1 Create unit tests for data generation logic
    - Write tests for SampleFamilyDataGenerator core methods
    - Test family data validation and structure
    - Verify proper role assignment and member creation
    - _Requirements: 1.1, 2.1, 2.2_

  - [x]* 6.2 Add integration tests with DataService
    - Test complete family generation workflow with real database
    - Verify idempotency behavior with existing data
    - Test error scenarios and recovery mechanisms
    - _Requirements: 4.1, 4.2, 1.5_

  - [x]* 6.3 Create manual testing utilities
    - Add console commands for testing family code generation
    - Create test helpers for verifying join family functionality
    - Document testing procedures for QA validation
    - _Requirements: 3.1, 3.2, 3.3_