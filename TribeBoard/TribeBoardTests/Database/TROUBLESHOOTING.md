# Database Testing Troubleshooting Guide

## Common Test Failures and Solutions

### 1. Test Data Persistence Issues

#### Problem: Tests fail because data persists between test runs

**Symptoms:**
```
XCTAssertEqual failed: ("2") is not equal to ("1") - Expected 1 family, found 2
```

**Cause:** Test data not properly cleaned up between tests

**Solutions:**
1. **Verify DatabaseTestBase Usage:**
   ```swift
   // Ensure your test class extends DatabaseTestBase
   class YourTestClass: DatabaseTestBase {
       // Tests automatically get clean in-memory database
   }
   ```

2. **Check Manual Cleanup:**
   ```swift
   override func tearDown() async throws {
       // Add any additional cleanup
       try await super.tearDown() // This is crucial
   }
   ```

3. **Verify In-Memory Configuration:**
   ```swift
   // In DatabaseTestBase.setUp()
   let config = ModelConfiguration(isStoredInMemoryOnly: true)
   XCTAssertTrue(config.isStoredInMemoryOnly, "Database must be in-memory for tests")
   ```

### 2. Performance Test Failures

#### Problem: Performance tests fail intermittently

**Symptoms:**
```
Performance threshold exceeded: expected 0.010s, actual 0.025s
```

**Causes and Solutions:**

1. **System Load:**
   - Run tests on dedicated CI machines
   - Close unnecessary applications during local testing
   - Use consistent hardware for benchmarking

2. **Debug vs Release Builds:**
   ```swift
   #if DEBUG
   private let familyCreationBenchmark: TimeInterval = 0.020 // More lenient for debug
   #else
   private let familyCreationBenchmark: TimeInterval = 0.010 // Strict for release
   #endif
   ```

3. **Simulator Performance:**
   - Use consistent simulator models (iPhone 15)
   - Reset simulator between test runs if needed
   - Avoid running multiple simulators simultaneously

4. **Benchmark Adjustment:**
   ```swift
   // Update benchmarks based on actual performance data
   private let familyCreationBenchmark: TimeInterval = 0.015 // Adjusted from 0.010
   ```

### 3. CloudKit Mock Service Issues

#### Problem: CloudKit tests behave unexpectedly

**Symptoms:**
```
Mock CloudKit service not configured properly
Unexpected network behavior in tests
```

**Solutions:**

1. **Verify Mock Injection:**
   ```swift
   override func setUp() async throws {
       try await super.setUp()
       
       // Ensure mock is properly injected
       let mockService = MockCloudKitService()
       dataService.cloudKitService = mockService
       
       // Verify injection worked
       XCTAssertTrue(dataService.cloudKitService is MockCloudKitService)
   }
   ```

2. **Reset Mock State:**
   ```swift
   func testCloudKitOperation() async throws {
       let mockService = dataService.cloudKitService as! MockCloudKitService
       mockService.reset() // Clear any previous state
       
       // Configure for this test
       mockService.shouldFailOperations = false
       mockService.networkDelay = 0
   }
   ```

3. **Check Mock Configuration:**
   ```swift
   // Verify mock is configured as expected
   XCTAssertFalse(mockService.shouldFailOperations)
   XCTAssertEqual(mockService.networkDelay, 0)
   XCTAssertEqual(mockService.conflictScenario, .none)
   ```

### 4. Async/Await Test Issues

#### Problem: Async tests hang or fail unexpectedly

**Symptoms:**
```
Test hangs indefinitely
Async operation never completes
```

**Solutions:**

1. **Proper Async Test Setup:**
   ```swift
   func testAsyncOperation() async throws {
       // Use async throws for async tests
       let result = try await dataService.createFamily(family)
       XCTAssertNotNil(result)
   }
   ```

2. **Timeout Handling:**
   ```swift
   func testAsyncOperationWithTimeout() async throws {
       let expectation = XCTestExpectation(description: "Operation completes")
       
       Task {
           do {
               let result = try await dataService.createFamily(family)
               XCTAssertNotNil(result)
               expectation.fulfill()
           } catch {
               XCTFail("Operation failed: \(error)")
           }
       }
       
       await fulfillment(of: [expectation], timeout: 5.0)
   }
   ```

3. **MainActor Context:**
   ```swift
   @MainActor
   func testMainActorOperation() async throws {
       // Ensure test runs on MainActor when needed
       let result = try await dataService.createFamily(family)
       XCTAssertNotNil(result)
   }
   ```

### 5. Memory Test Failures

#### Problem: Memory tests detect leaks or excessive usage

**Symptoms:**
```
Memory leak detected: 5000000 bytes increase
Memory usage exceeded limit: 15MB > 10MB
```

**Solutions:**

1. **Check for Retain Cycles:**
   ```swift
   // Use weak references in closures
   dataService.onComplete = { [weak self] result in
       self?.handleResult(result)
   }
   ```

2. **Proper Resource Cleanup:**
   ```swift
   override func tearDown() async throws {
       // Clean up any retained resources
       dataService.cleanup()
       mockCloudKitService.reset()
       
       try await super.tearDown()
   }
   ```

3. **Monitor Memory During Tests:**
   ```swift
   func testMemoryUsage() throws {
       let initialMemory = MemoryTestUtilities.getCurrentMemoryUsage()
       
       // Perform operations
       for _ in 0..<100 {
           let family = TestDataFactory.createValidFamily()
           // Use family
       }
       
       let finalMemory = MemoryTestUtilities.getCurrentMemoryUsage()
       let increase = finalMemory - initialMemory
       
       XCTAssertLessThan(increase, 10_000_000, "Memory increase too large: \(increase) bytes")
   }
   ```

### 6. Relationship and Constraint Test Issues

#### Problem: Relationship tests fail due to constraint violations

**Symptoms:**
```
Constraint violation: Parent admin already exists
Relationship not properly established
```

**Solutions:**

1. **Proper Test Data Setup:**
   ```swift
   func testParentAdminConstraint() async throws {
       let family = TestDataFactory.createValidFamily()
       let user1 = TestDataFactory.createValidUserProfile()
       let user2 = TestDataFactory.createValidUserProfile()
       
       // Create first parent admin
       let membership1 = try await dataService.createMembership(
           familyId: family.id,
           userId: user1.id,
           role: .parentAdmin
       )
       
       // Attempt to create second parent admin should fail
       do {
           let membership2 = try await dataService.createMembership(
               familyId: family.id,
               userId: user2.id,
               role: .parentAdmin
           )
           XCTFail("Should not allow second parent admin")
       } catch DataServiceError.constraintViolation {
           // Expected behavior
       }
   }
   ```

2. **Verify Relationship Setup:**
   ```swift
   func testRelationshipSetup() async throws {
       let (family, users, memberships) = TestDataFactory.createFamilyWithMembers(memberCount: 3)
       
       // Verify relationships are properly established
       XCTAssertEqual(family.memberships.count, 3)
       XCTAssertEqual(users[0].memberships.count, 1)
       XCTAssertEqual(memberships[0].family?.id, family.id)
       XCTAssertEqual(memberships[0].user?.id, users[0].id)
   }
   ```

### 7. Schema Migration Test Issues

#### Problem: Migration tests fail due to schema changes

**Symptoms:**
```
Schema migration failed
Model version mismatch
```

**Solutions:**

1. **Test Migration Scenarios:**
   ```swift
   func testSchemaMigration() throws {
       // Create data with old schema
       let oldContainer = createOldSchemaContainer()
       let oldContext = oldContainer.mainContext
       
       // Add test data
       let family = OldFamily(name: "Test Family", code: "ABC123")
       oldContext.insert(family)
       try oldContext.save()
       
       // Migrate to new schema
       let newContainer = createNewSchemaContainer()
       let newContext = newContainer.mainContext
       
       // Verify data preserved
       let migratedFamilies = try newContext.fetch(FetchDescriptor<Family>())
       XCTAssertEqual(migratedFamilies.count, 1)
       XCTAssertEqual(migratedFamilies[0].name, "Test Family")
   }
   ```

2. **Handle Schema Validation:**
   ```swift
   func testSchemaValidation() throws {
       let schema = Schema([Family.self, UserProfile.self, Membership.self])
       
       // Verify all expected entities exist
       XCTAssertTrue(schema.entities.contains { $0.name == "Family" })
       XCTAssertTrue(schema.entities.contains { $0.name == "UserProfile" })
       XCTAssertTrue(schema.entities.contains { $0.name == "Membership" })
       
       // Verify relationships
       let familyEntity = schema.entities.first { $0.name == "Family" }!
       let membershipsRelationship = familyEntity.relationships.first { $0.name == "memberships" }
       XCTAssertNotNil(membershipsRelationship)
   }
   ```

## Debugging Strategies

### 1. Enable Detailed Logging

```swift
// Add to test setup
override func setUp() async throws {
    try await super.setUp()
    
    // Enable detailed logging for debugging
    dataService.enableDebugLogging = true
    mockCloudKitService.enableDebugLogging = true
}
```

### 2. Use Breakpoints Effectively

```swift
func testComplexScenario() async throws {
    let family = TestDataFactory.createValidFamily()
    
    // Set breakpoint here to inspect test data
    debugPrint("Family created: \(family)")
    
    let result = try await dataService.createFamily(family)
    
    // Set breakpoint here to inspect result
    debugPrint("Result: \(result)")
    
    XCTAssertNotNil(result)
}
```

### 3. Add Diagnostic Assertions

```swift
func testWithDiagnostics() async throws {
    // Add diagnostic checks
    XCTAssertTrue(modelContainer.mainContext.hasChanges == false, "Context should be clean at start")
    
    let family = TestDataFactory.createValidFamily()
    XCTAssertTrue(family.isFullyValid, "Test family should be valid")
    
    let result = try await dataService.createFamily(family)
    XCTAssertNotNil(result, "Create operation should return result")
    XCTAssertEqual(result.name, family.name, "Names should match")
}
```

### 4. Test Isolation Verification

```swift
func testIsolationVerification() throws {
    // Verify clean state
    let familyCount = try testContext.fetchCount(FetchDescriptor<Family>())
    XCTAssertEqual(familyCount, 0, "Database should be empty at test start")
    
    let userCount = try testContext.fetchCount(FetchDescriptor<UserProfile>())
    XCTAssertEqual(userCount, 0, "Database should be empty at test start")
    
    let membershipCount = try testContext.fetchCount(FetchDescriptor<Membership>())
    XCTAssertEqual(membershipCount, 0, "Database should be empty at test start")
}
```

## Performance Debugging

### 1. Profile Slow Tests

```swift
func testWithProfiling() async throws {
    let startTime = CFAbsoluteTimeGetCurrent()
    let startMemory = MemoryTestUtilities.getCurrentMemoryUsage()
    
    // Perform operation
    let result = try await dataService.performComplexOperation()
    
    let endTime = CFAbsoluteTimeGetCurrent()
    let endMemory = MemoryTestUtilities.getCurrentMemoryUsage()
    
    let duration = endTime - startTime
    let memoryIncrease = endMemory - startMemory
    
    print("Operation took \(duration)s, used \(memoryIncrease) bytes")
    
    // Add assertions based on profiling results
    XCTAssertLessThan(duration, 0.100, "Operation too slow")
    XCTAssertLessThan(memoryIncrease, 5_000_000, "Memory usage too high")
}
```

### 2. Identify Performance Bottlenecks

```swift
func testPerformanceBottlenecks() async throws {
    // Test individual components
    let createTime = try await measureTime {
        return try await dataService.createFamily(TestDataFactory.createValidFamily())
    }
    
    let fetchTime = try await measureTime {
        return try await dataService.fetchFamily(byCode: "ABC123")
    }
    
    let syncTime = try await measureTime {
        return try await cloudKitService.syncFamily(family)
    }
    
    print("Create: \(createTime)s, Fetch: \(fetchTime)s, Sync: \(syncTime)s")
}
```

## Getting Help

### 1. Check Test Logs

Look for detailed error messages in Xcode's test logs:
- Open Report Navigator (⌘9)
- Select the test run
- Expand failed tests to see detailed logs

### 2. Review Test Coverage

Use Xcode's code coverage to identify untested code paths:
1. Enable code coverage in scheme settings
2. Run tests
3. View coverage report in Report Navigator

### 3. Common Resources

- **Apple Documentation**: SwiftData and CloudKit testing guides
- **WWDC Sessions**: Testing best practices videos
- **Community Forums**: Swift forums and Stack Overflow

### 4. Creating Minimal Reproduction Cases

When reporting issues, create minimal test cases:

```swift
func testMinimalReproduction() async throws {
    // Minimal setup
    let family = Family(name: "Test", code: "ABC123", createdByUserId: "user1")
    
    // Minimal operation that demonstrates the issue
    let result = try await dataService.createFamily(family)
    
    // Minimal assertion that fails
    XCTAssertNotNil(result)
}
```

This helps isolate the problem and makes it easier to debug and fix.