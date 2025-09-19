# TribeBoard Database Testing Framework

## Overview

This comprehensive testing framework validates the TribeBoard database system, including SwiftData models, CloudKit synchronization, data validation, performance, and integration scenarios. The framework provides thorough coverage while maintaining reliability and clear debugging feedback.

## Quick Start

### Running All Tests

```bash
# Run all database tests
xcodebuild test -scheme TribeBoard -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:TribeBoardTests/Database

# Run specific test categories
xcodebuild test -scheme TribeBoard -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:TribeBoardTests/Database/ModelValidationTests
```

### Running Tests in Xcode

1. Open `TribeBoard.xcodeproj`
2. Navigate to the Test Navigator (⌘6)
3. Expand `TribeBoardTests` → `Database`
4. Right-click on any test class or method and select "Run"

## Test Structure

### Core Test Categories

| Category | Purpose | Location |
|----------|---------|----------|
| **Model Validation** | Test data model validation and business rules | `ModelValidationTests.swift` |
| **Container Configuration** | Test ModelContainer setup and schema | `ContainerConfigurationTests.swift`, `SchemaValidationTests.swift` |
| **Data Service CRUD** | Test database operations | `DataServiceCRUDTests.swift`, `DataServiceValidationTests.swift`, `DataServiceConstraintTests.swift`, `DataServiceAdvancedTests.swift` |
| **CloudKit Sync** | Test CloudKit synchronization | `CloudKitSyncTests.swift`, `CloudKitConflictResolutionTests.swift`, `CloudKitErrorHandlingTests.swift` |
| **Relationships** | Test model relationships and constraints | `RelationshipTests.swift`, `ConstraintTests.swift` |
| **Performance** | Test performance and scalability | `DatabasePerformanceTests.swift`, `LoadTests.swift`, `MemoryTests.swift` |
| **Integration** | Test end-to-end workflows | `EndToEndWorkflowTests.swift`, `CrossServiceIntegrationTests.swift`, `AppLaunchIntegrationTests.swift` |
| **Schema Migration** | Test database migrations | `SchemaMigrationTests.swift`, `CloudKitSchemaMigrationTests.swift` |

### Test Utilities

| Utility | Purpose | Location |
|---------|---------|----------|
| **DatabaseTestBase** | Base class with common setup/teardown | `Utilities/DatabaseTestBase.swift` |
| **TestDataFactory** | Standardized test data creation | `Utilities/TestDataFactory.swift` |
| **MockCloudKitService** | Controllable CloudKit mock | `Utilities/MockCloudKitService.swift` |
| **PerformanceTestUtilities** | Performance measurement tools | `Utilities/PerformanceTestUtilities.swift` |

## Test Execution Guide

### Individual Test Categories

#### Model Validation Tests
```bash
# Test all model validation
xcodebuild test -scheme TribeBoard -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:TribeBoardTests/ModelValidationTests

# Test specific model validation
xcodebuild test -scheme TribeBoard -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:TribeBoardTests/ModelValidationTests/testFamilyValidation
```

#### Performance Tests
```bash
# Run performance tests (may take longer)
xcodebuild test -scheme TribeBoard -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:TribeBoardTests/Database/DatabasePerformanceTests

# Run load tests
xcodebuild test -scheme TribeBoard -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:TribeBoardTests/Database/LoadTests
```

#### Integration Tests
```bash
# Run end-to-end workflow tests
xcodebuild test -scheme TribeBoard -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:TribeBoardTests/Database/EndToEndWorkflowTests
```

### Test Results Interpretation

#### Success Indicators
- ✅ All assertions pass
- ✅ Performance benchmarks met
- ✅ Memory usage within limits
- ✅ No test data leakage between tests

#### Common Test Output Patterns

**Successful Test:**
```
Test Case '-[TribeBoardTests.ModelValidationTests testFamilyValidation]' started.
✅ Family validation passed for valid data
✅ Family validation correctly rejected invalid name
✅ Family validation correctly rejected invalid code
Test Case '-[TribeBoardTests.ModelValidationTests testFamilyValidation]' passed (0.023 seconds).
```

**Performance Test:**
```
Test Case '-[TribeBoardTests.DatabasePerformanceTests testFamilyCreationPerformance]' started.
⏱️ Family creation took 0.008s (benchmark: 0.010s) ✅
📊 Memory usage: 0.5MB (limit: 1.0MB) ✅
Test Case '-[TribeBoardTests.DatabasePerformanceTests testFamilyCreationPerformance]' passed (0.012 seconds).
```

## Performance Benchmarks

### Current Performance Targets

| Operation | Target Duration | Memory Limit | Test Method |
|-----------|----------------|--------------|-------------|
| Create Family | < 10ms | < 1MB | `testFamilyCreationPerformance` |
| Fetch Family by Code | < 5ms | < 500KB | `testFamilyFetchPerformance` |
| Create Membership | < 15ms | < 1MB | `testMembershipCreationPerformance` |
| Batch Create (100 records) | < 500ms | < 10MB | `testBatchOperationPerformance` |
| CloudKit Sync (single record) | < 2s | < 2MB | `testCloudKitSyncPerformance` |
| Full Database Query | < 100ms | < 5MB | `testFullDatabaseQueryPerformance` |

### Updating Performance Benchmarks

When performance characteristics change, update benchmarks in:

1. **Test Files**: Update the benchmark constants in performance test classes
2. **Documentation**: Update this README with new targets
3. **CI Configuration**: Update any CI performance validation thresholds

Example benchmark update in `DatabasePerformanceTests.swift`:
```swift
private let familyCreationBenchmark: TimeInterval = 0.010 // 10ms
private let familyCreationMemoryLimit: Int = 1_000_000 // 1MB
```

## Adding New Tests

### 1. Choose the Right Test Category

- **Unit Tests**: Test individual components in isolation
- **Integration Tests**: Test component interactions
- **Performance Tests**: Measure and validate performance
- **End-to-End Tests**: Test complete user workflows

### 2. Follow Naming Conventions

```swift
// Test class naming
class NewFeatureValidationTests: DatabaseTestBase { }

// Test method naming
func testNewFeatureValidation_WithValidData_ShouldSucceed() { }
func testNewFeatureValidation_WithInvalidData_ShouldFail() { }
func testNewFeaturePerformance_ShouldMeetBenchmark() { }
```

### 3. Use Test Utilities

```swift
class NewFeatureTests: DatabaseTestBase {
    func testNewFeature() async throws {
        // Use TestDataFactory for consistent test data
        let family = TestDataFactory.createValidFamily()
        let user = TestDataFactory.createValidUserProfile()
        
        // Use dataService from DatabaseTestBase
        let createdFamily = try await dataService.createFamily(family)
        
        // Use assertion helpers
        XCTAssertEqual(createdFamily.name, family.name)
        XCTAssertTrue(createdFamily.isFullyValid)
    }
}
```

### 4. Add Performance Tests

```swift
func testNewFeaturePerformance() async throws {
    let benchmark: TimeInterval = 0.050 // 50ms
    let memoryLimit: Int = 2_000_000 // 2MB
    
    let result = try await PerformanceTestUtilities.measureAsyncDatabaseOperation(
        operation: {
            return try await dataService.performNewFeature()
        },
        expectedMaxDuration: benchmark,
        description: "New feature operation"
    )
    
    XCTAssertNotNil(result)
}
```

### 5. Test File Template

```swift
import XCTest
@testable import TribeBoard

@MainActor
final class NewFeatureTests: DatabaseTestBase {
    
    override func setUp() async throws {
        try await super.setUp()
        // Additional setup if needed
    }
    
    override func tearDown() async throws {
        // Additional cleanup if needed
        try await super.tearDown()
    }
    
    // MARK: - Validation Tests
    
    func testNewFeature_WithValidData_ShouldSucceed() async throws {
        // Test implementation
    }
    
    func testNewFeature_WithInvalidData_ShouldFail() async throws {
        // Test implementation
    }
    
    // MARK: - Performance Tests
    
    func testNewFeaturePerformance_ShouldMeetBenchmark() async throws {
        // Performance test implementation
    }
    
    // MARK: - Integration Tests
    
    func testNewFeatureIntegration_ShouldWorkWithOtherComponents() async throws {
        // Integration test implementation
    }
}
```

## Test Environment Setup

### Prerequisites

- Xcode 15.0 or later
- iOS 17.0 Simulator
- Swift 5.9 or later

### Test Configuration

Tests use in-memory databases that don't persist between test runs:

```swift
// Automatic setup in DatabaseTestBase
let container = try ModelContainer(
    for: Family.self, UserProfile.self, Membership.self,
    configurations: ModelConfiguration(isStoredInMemoryOnly: true)
)
```

### Mock Services

CloudKit operations use `MockCloudKitService` for controllable testing:

```swift
// Configure mock behavior
mockCloudKitService.shouldFailOperations = true
mockCloudKitService.networkDelay = 1.0
mockCloudKitService.conflictScenario = .localNewer
```

## Continuous Integration

### GitHub Actions Configuration

Add to `.github/workflows/tests.yml`:

```yaml
name: Database Tests
on: [push, pull_request]

jobs:
  database-tests:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3
      - name: Run Database Tests
        run: |
          xcodebuild test \
            -scheme TribeBoard \
            -destination 'platform=iOS Simulator,name=iPhone 15' \
            -only-testing:TribeBoardTests/Database \
            -resultBundlePath TestResults
      - name: Upload Test Results
        uses: actions/upload-artifact@v3
        with:
          name: test-results
          path: TestResults
```

### Local CI Simulation

```bash
# Run the same tests that CI runs
./scripts/run-database-tests.sh
```

## Next Steps

1. **Review Test Coverage**: Use Xcode's code coverage tools to identify gaps
2. **Monitor Performance**: Track performance trends over time
3. **Update Documentation**: Keep this guide current as tests evolve
4. **Expand Test Scenarios**: Add tests for new features and edge cases

For questions or issues with the testing framework, refer to the troubleshooting guide below.