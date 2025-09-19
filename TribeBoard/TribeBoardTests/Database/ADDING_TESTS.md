# Adding New Tests to the Database Testing Framework

## Overview

This guide provides step-by-step instructions for adding new tests to the TribeBoard database testing framework. Follow these guidelines to ensure consistency, maintainability, and comprehensive coverage.

## Test Categories and When to Use Them

### 1. Model Validation Tests
**When to use:** Testing data model validation, business rules, computed properties

**Example scenarios:**
- New model properties with validation rules
- New computed properties
- New business logic in models
- Edge cases in existing validation

### 2. Data Service Tests
**When to use:** Testing database operations, CRUD functionality, constraints

**Example scenarios:**
- New database operations
- New business constraints
- New query methods
- Complex data manipulation

### 3. CloudKit Integration Tests
**When to use:** Testing synchronization, conflict resolution, CloudKit-specific functionality

**Example scenarios:**
- New CloudKit record types
- New sync strategies
- New conflict resolution scenarios
- CloudKit error handling

### 4. Performance Tests
**When to use:** Testing operation speed, memory usage, scalability

**Example scenarios:**
- New operations that might be slow
- Bulk operations
- Complex queries
- Memory-intensive operations

### 5. Integration Tests
**When to use:** Testing complete workflows, cross-service interactions

**Example scenarios:**
- New user workflows
- New feature end-to-end testing
- Service integration points
- Complex business processes

## Step-by-Step Guide

### Step 1: Determine Test Category

Ask yourself:
- What component am I testing?
- Is this a unit test (single component) or integration test (multiple components)?
- Does this involve performance considerations?
- Does this test CloudKit functionality?

### Step 2: Choose the Right Test File

| Test Type | File Pattern | Example |
|-----------|--------------|---------|
| Model Validation | `ModelValidationTests.swift` | Testing Family.isValid |
| Data Service CRUD | `DataService*Tests.swift` | Testing createFamily() |
| CloudKit Sync | `CloudKit*Tests.swift` | Testing record conversion |
| Performance | `*PerformanceTests.swift` | Testing operation speed |
| Integration | `*IntegrationTests.swift` | Testing complete workflows |
| Relationships | `RelationshipTests.swift` | Testing model relationships |
| Constraints | `ConstraintTests.swift` | Testing business constraints |

### Step 3: Create New Test File (if needed)

If no existing file fits your test, create a new one:

```swift
import XCTest
@testable import TribeBoard

@MainActor
final class NewFeatureTests: DatabaseTestBase {
    
    // MARK: - Setup and Teardown
    
    override func setUp() async throws {
        try await super.setUp()
        // Additional setup specific to this test class
    }
    
    override func tearDown() async throws {
        // Additional cleanup specific to this test class
        try await super.tearDown()
    }
    
    // MARK: - Test Methods
    
    func testNewFeature_WithValidInput_ShouldSucceed() async throws {
        // Test implementation
    }
    
    func testNewFeature_WithInvalidInput_ShouldFail() async throws {
        // Test implementation
    }
    
    // MARK: - Performance Tests
    
    func testNewFeaturePerformance_ShouldMeetBenchmark() async throws {
        // Performance test implementation
    }
}
```

### Step 4: Follow Naming Conventions

#### Test Class Names
```swift
// Pattern: [Feature][TestType]Tests
class FamilyValidationTests: DatabaseTestBase { }
class DataServiceCRUDTests: DatabaseTestBase { }
class CloudKitSyncTests: DatabaseTestBase { }
class DatabasePerformanceTests: DatabaseTestBase { }
```

#### Test Method Names
```swift
// Pattern: test[Feature]_[Scenario]_[ExpectedResult]
func testFamilyCreation_WithValidData_ShouldSucceed() { }
func testFamilyCreation_WithInvalidName_ShouldFail() { }
func testFamilyCreation_WithDuplicateCode_ShouldThrowConstraintError() { }
```

#### Test Organization
```swift
class ExampleTests: DatabaseTestBase {
    
    // MARK: - Setup and Teardown
    override func setUp() async throws { }
    override func tearDown() async throws { }
    
    // MARK: - Validation Tests
    func testValidation_Scenario1() { }
    func testValidation_Scenario2() { }
    
    // MARK: - Error Handling Tests
    func testErrorHandling_Scenario1() { }
    func testErrorHandling_Scenario2() { }
    
    // MARK: - Performance Tests
    func testPerformance_Scenario1() { }
    
    // MARK: - Integration Tests
    func testIntegration_Scenario1() { }
}
```

### Step 5: Use Test Utilities Effectively

#### DatabaseTestBase
Always extend `DatabaseTestBase` for database tests:

```swift
class YourTests: DatabaseTestBase {
    func testExample() async throws {
        // Access to:
        // - modelContainer: ModelContainer
        // - dataService: DataService
        // - testContext: ModelContext
        // - Automatic setup/teardown
    }
}
```

#### TestDataFactory
Use `TestDataFactory` for consistent test data:

```swift
func testWithTestData() async throws {
    // Create valid test data
    let family = TestDataFactory.createValidFamily()
    let user = TestDataFactory.createValidUserProfile()
    
    // Create invalid test data for error testing
    let invalidFamily = TestDataFactory.createInvalidFamily(invalidField: .name)
    
    // Create bulk data for performance testing
    let families = TestDataFactory.createBulkFamilies(count: 100)
    
    // Create related data
    let (family, users, memberships) = TestDataFactory.createFamilyWithMembers(memberCount: 5)
}
```

#### MockCloudKitService
Use mock services for CloudKit testing:

```swift
func testCloudKitOperation() async throws {
    let mockService = dataService.cloudKitService as! MockCloudKitService
    
    // Configure mock behavior
    mockService.shouldFailOperations = false
    mockService.networkDelay = 0.1
    mockService.conflictScenario = .localNewer
    
    // Reset between tests
    mockService.reset()
}
```

### Step 6: Write Comprehensive Test Cases

#### Test Valid Scenarios
```swift
func testFeature_WithValidInput_ShouldSucceed() async throws {
    // Arrange
    let validInput = TestDataFactory.createValidFamily()
    
    // Act
    let result = try await dataService.createFamily(validInput)
    
    // Assert
    XCTAssertNotNil(result)
    XCTAssertEqual(result.name, validInput.name)
    XCTAssertEqual(result.code, validInput.code)
    XCTAssertTrue(result.isFullyValid)
}
```

#### Test Invalid Scenarios
```swift
func testFeature_WithInvalidInput_ShouldFail() async throws {
    // Arrange
    let invalidInput = TestDataFactory.createInvalidFamily(invalidField: .name)
    
    // Act & Assert
    do {
        let result = try await dataService.createFamily(invalidInput)
        XCTFail("Should have thrown validation error")
    } catch DataServiceError.validationError(let message) {
        XCTAssertTrue(message.contains("name"), "Error should mention name field")
    }
}
```

#### Test Edge Cases
```swift
func testFeature_WithEdgeCase_ShouldHandleCorrectly() async throws {
    // Test boundary values
    let familyWithMinName = Family(name: "AB", code: "ABC123", createdByUserId: "user1") // 2 chars (minimum)
    let familyWithMaxName = Family(name: String(repeating: "A", count: 50), code: "ABC123", createdByUserId: "user1") // 50 chars (maximum)
    
    // Both should be valid
    XCTAssertTrue(familyWithMinName.isFullyValid)
    XCTAssertTrue(familyWithMaxName.isFullyValid)
    
    // Test just outside boundaries
    let familyWithTooShortName = Family(name: "A", code: "ABC123", createdByUserId: "user1") // 1 char (too short)
    let familyWithTooLongName = Family(name: String(repeating: "A", count: 51), code: "ABC123", createdByUserId: "user1") // 51 chars (too long)
    
    // Both should be invalid
    XCTAssertFalse(familyWithTooShortName.isFullyValid)
    XCTAssertFalse(familyWithTooLongName.isFullyValid)
}
```

### Step 7: Add Performance Tests

#### Basic Performance Test
```swift
func testFeaturePerformance_ShouldMeetBenchmark() async throws {
    let benchmark: TimeInterval = 0.050 // 50ms
    let memoryLimit: Int = 2_000_000 // 2MB
    
    let result = try await PerformanceTestUtilities.measureAsyncDatabaseOperation(
        operation: {
            let family = TestDataFactory.createValidFamily()
            return try await dataService.createFamily(family)
        },
        expectedMaxDuration: benchmark,
        description: "Family creation"
    )
    
    XCTAssertNotNil(result)
}
```

#### Bulk Performance Test
```swift
func testBulkOperationPerformance_ShouldMeetBenchmark() async throws {
    let familyCount = 100
    let benchmark: TimeInterval = 1.0 // 1 second for 100 operations
    
    let families = TestDataFactory.createBulkFamilies(count: familyCount)
    
    let duration = try await PerformanceTestUtilities.measureAsyncDatabaseOperation(
        operation: {
            for family in families {
                _ = try await dataService.createFamily(family)
            }
        },
        expectedMaxDuration: benchmark,
        description: "Bulk family creation (\(familyCount) families)"
    )
    
    // Verify all families were created
    let createdFamilies = try testContext.fetch(FetchDescriptor<Family>())
    XCTAssertEqual(createdFamilies.count, familyCount)
}
```

### Step 8: Add Integration Tests

#### End-to-End Workflow Test
```swift
func testCompleteWorkflow_ShouldSucceedEndToEnd() async throws {
    // Step 1: Create user profile
    let userProfile = TestDataFactory.createValidUserProfile()
    let createdUser = try await dataService.createUserProfile(userProfile)
    
    // Step 2: Create family
    let family = TestDataFactory.createValidFamily()
    family.createdByUserId = createdUser.id
    let createdFamily = try await dataService.createFamily(family)
    
    // Step 3: Create membership
    let membership = try await dataService.createMembership(
        familyId: createdFamily.id,
        userId: createdUser.id,
        role: .parentAdmin
    )
    
    // Step 4: Verify complete workflow
    XCTAssertNotNil(createdUser)
    XCTAssertNotNil(createdFamily)
    XCTAssertNotNil(membership)
    
    // Verify relationships
    XCTAssertEqual(membership.family?.id, createdFamily.id)
    XCTAssertEqual(membership.user?.id, createdUser.id)
    XCTAssertEqual(createdFamily.memberships.count, 1)
    XCTAssertEqual(createdUser.memberships.count, 1)
}
```

### Step 9: Add Proper Error Testing

#### Test Specific Error Types
```swift
func testFeature_WithConstraintViolation_ShouldThrowSpecificError() async throws {
    // Setup: Create family with parent admin
    let family = try await dataService.createFamily(TestDataFactory.createValidFamily())
    let user1 = try await dataService.createUserProfile(TestDataFactory.createValidUserProfile())
    let user2 = try await dataService.createUserProfile(TestDataFactory.createValidUserProfile())
    
    // Create first parent admin
    _ = try await dataService.createMembership(
        familyId: family.id,
        userId: user1.id,
        role: .parentAdmin
    )
    
    // Attempt to create second parent admin should fail with specific error
    do {
        _ = try await dataService.createMembership(
            familyId: family.id,
            userId: user2.id,
            role: .parentAdmin
        )
        XCTFail("Should have thrown constraint violation error")
    } catch DataServiceError.constraintViolation(let message) {
        XCTAssertTrue(message.contains("parent admin"), "Error should mention parent admin constraint")
    } catch {
        XCTFail("Should have thrown DataServiceError.constraintViolation, got \(error)")
    }
}
```

### Step 10: Document Your Tests

#### Add Test Documentation
```swift
/// Tests the family creation functionality with various input scenarios
/// 
/// This test suite covers:
/// - Valid family creation with all required fields
/// - Invalid input validation and error handling
/// - Constraint enforcement (unique codes)
/// - Performance benchmarks for creation operations
/// - Integration with CloudKit synchronization
class FamilyCreationTests: DatabaseTestBase {
    
    /// Tests that valid family data creates a family successfully
    /// 
    /// Validates:
    /// - Family is created with correct properties
    /// - Family passes validation checks
    /// - Family is persisted to database
    /// - Operation completes within performance benchmark
    func testFamilyCreation_WithValidData_ShouldSucceed() async throws {
        // Test implementation
    }
}
```

#### Update Performance Benchmarks Documentation
When adding performance tests, update the benchmarks in `README.md`:

```markdown
### New Performance Targets

| Operation | Target Duration | Memory Limit | Test Method |
|-----------|----------------|--------------|-------------|
| New Feature Operation | < 25ms | < 1.5MB | `testNewFeaturePerformance` |
```

## Best Practices

### 1. Test Independence
- Each test should be independent and not rely on other tests
- Use `DatabaseTestBase` for automatic cleanup
- Don't share state between tests

### 2. Clear Test Intent
- Use descriptive test names that explain the scenario and expected outcome
- Add comments for complex test logic
- Group related tests with MARK comments

### 3. Comprehensive Coverage
- Test happy path (valid scenarios)
- Test error paths (invalid scenarios)
- Test edge cases and boundary conditions
- Test performance characteristics

### 4. Maintainable Tests
- Use test utilities for common operations
- Keep tests focused and not too long
- Use consistent patterns across similar tests

### 5. Reliable Tests
- Avoid flaky tests that pass/fail randomly
- Use deterministic test data
- Handle async operations properly
- Clean up resources properly

## Common Patterns

### Testing Validation Logic
```swift
func testValidation() {
    let validCases = [
        ("Valid Name", "ABC123", true),
        ("Another Valid", "XYZ789", true)
    ]
    
    let invalidCases = [
        ("", "ABC123", false), // Empty name
        ("A", "ABC123", false), // Too short
        ("Valid Name", "", false), // Empty code
        ("Valid Name", "AB", false) // Code too short
    ]
    
    for (name, code, shouldBeValid) in validCases + invalidCases {
        let family = Family(name: name, code: code, createdByUserId: "user1")
        XCTAssertEqual(family.isFullyValid, shouldBeValid, 
                      "Family with name '\(name)' and code '\(code)' should be \(shouldBeValid ? "valid" : "invalid")")
    }
}
```

### Testing Async Operations
```swift
func testAsyncOperation() async throws {
    let expectation = XCTestExpectation(description: "Operation completes")
    var result: Family?
    var error: Error?
    
    Task {
        do {
            result = try await dataService.createFamily(TestDataFactory.createValidFamily())
        } catch let e {
            error = e
        }
        expectation.fulfill()
    }
    
    await fulfillment(of: [expectation], timeout: 5.0)
    
    XCTAssertNil(error, "Operation should not throw error")
    XCTAssertNotNil(result, "Operation should return result")
}
```

### Testing Error Scenarios
```swift
func testErrorScenarios() async throws {
    let errorScenarios: [(description: String, family: Family, expectedError: DataServiceError)] = [
        ("Empty name", Family(name: "", code: "ABC123", createdByUserId: "user1"), .validationError("Name cannot be empty")),
        ("Invalid code", Family(name: "Valid", code: "AB", createdByUserId: "user1"), .validationError("Code must be 6-8 characters"))
    ]
    
    for (description, family, expectedError) in errorScenarios {
        do {
            _ = try await dataService.createFamily(family)
            XCTFail("Should have thrown error for: \(description)")
        } catch let actualError as DataServiceError {
            XCTAssertEqual(actualError, expectedError, "Wrong error for: \(description)")
        } catch {
            XCTFail("Wrong error type for: \(description), got \(error)")
        }
    }
}
```

## Checklist for New Tests

Before submitting your new tests, verify:

- [ ] Test class extends `DatabaseTestBase`
- [ ] Test methods follow naming conventions
- [ ] Tests are properly organized with MARK comments
- [ ] Tests use `TestDataFactory` for test data creation
- [ ] Tests include both positive and negative scenarios
- [ ] Performance tests include appropriate benchmarks
- [ ] Error tests verify specific error types and messages
- [ ] Tests are independent and don't rely on each other
- [ ] Tests clean up properly (handled by `DatabaseTestBase`)
- [ ] Tests are documented with clear descriptions
- [ ] Performance benchmarks are updated in documentation if needed
- [ ] Tests run successfully in isolation and as part of the full suite

## Getting Help

If you need help adding tests:

1. **Review existing tests** in the same category for patterns
2. **Check the troubleshooting guide** for common issues
3. **Run similar tests** to understand expected behavior
4. **Use Xcode's test navigator** to explore the test structure
5. **Ask for code review** to ensure tests follow best practices

Remember: Good tests are an investment in code quality and maintainability. Take time to write clear, comprehensive tests that will help catch issues early and make the codebase more reliable.