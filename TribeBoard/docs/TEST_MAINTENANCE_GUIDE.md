# TribeBoard Test Maintenance Guide

This guide provides comprehensive instructions for maintaining and extending the TribeBoard test suite.

## Table of Contents

1. [Overview](#overview)
2. [Test Suite Structure](#test-suite-structure)
3. [Running Tests](#running-tests)
4. [Debugging Tests](#debugging-tests)
5. [Adding New Tests](#adding-new-tests)
6. [Maintaining Existing Tests](#maintaining-existing-tests)
7. [Mock Services](#mock-services)
8. [Test Utilities](#test-utilities)
9. [Performance Testing](#performance-testing)
10. [Accessibility Testing](#accessibility-testing)
11. [Continuous Integration](#continuous-integration)
12. [Troubleshooting](#troubleshooting)

## Overview

The TribeBoard test suite is organized into three main categories:

- **Unit Tests** (`TribeBoardTests/`): Test individual components in isolation
- **Integration Tests** (`TribeBoardTests/Integration/`): Test component interactions
- **UI Tests** (`TribeBoardUITests/`): Test complete user workflows

### Key Principles

1. **Test Isolation**: Each test should run independently
2. **Mock Dependencies**: Use mock services for external dependencies
3. **Clear Naming**: Test names should clearly describe what is being tested
4. **Comprehensive Coverage**: Aim for high code coverage with meaningful tests
5. **Fast Execution**: Keep tests fast to enable frequent execution

## Test Suite Structure

```
TribeBoardTests/
├── Unit/
│   ├── Authentication/          # Authentication logic tests
│   ├── UI/                     # UI component tests
│   └── Utilities/              # Utility function tests
├── Integration/                # End-to-end workflow tests
└── Utilities/                  # Test helpers and mock services

TribeBoardUITests/
├── Authentication/             # Authentication UI flow tests
├── Core/                      # Main app UI tests
├── Accessibility/             # Accessibility compliance tests
└── Utilities/                 # UI test helpers
```

## Running Tests

### Command Line Scripts

The project includes several scripts for running tests:

#### Run All Tests
```bash
./scripts/run-all-tests.sh
```

#### Run Specific Test Categories
```bash
# Unit tests only
./scripts/run-unit-tests.sh

# Integration tests only
./scripts/run-integration-tests.sh

# UI tests only
./scripts/run-ui-tests.sh
```

#### Run with Coverage
```bash
./scripts/run-all-tests.sh --coverage
```

#### Run Specific Tests
```bash
# Run specific test class
./scripts/run-unit-tests.sh --test AuthServiceTests

# Run specific test method
./scripts/run-unit-tests.sh --test AuthServiceTests/testSignInSuccess
```

### Xcode

1. Open the TribeBoard project in Xcode
2. Select the test target (TribeBoardTests or TribeBoardUITests)
3. Use Cmd+U to run all tests or Cmd+Ctrl+U for the current test

### Test Configuration Options

- `--verbose`: Enable detailed output
- `--coverage`: Generate code coverage reports
- `--screenshots`: Capture screenshots on UI test failures
- `--parallel`: Run tests in parallel (where supported)
- `--continue-on-fail`: Continue running other test suites if one fails

## Debugging Tests

### Common Debugging Techniques

#### 1. Enable Verbose Logging
```bash
./scripts/run-unit-tests.sh --verbose
```

#### 2. Run Single Test
```bash
./scripts/run-unit-tests.sh --test SpecificTestClass/specificTestMethod
```

#### 3. Use Xcode Debugger
- Set breakpoints in test methods
- Use `po` command to inspect variables
- Step through test execution

#### 4. Check Mock Service State
```swift
func testExample() {
    // Debug mock service state
    TestUtilities.debugTestEnvironment(testEnvironment)
    
    // Your test code here
    
    // Check final state
    let validation = TestUtilities.validateTestEnvironment(testEnvironment)
    XCTAssertTrue(validation.isValid, "Environment validation failed: \(validation.issues)")
}
```

#### 5. Capture Test State
```swift
func testExample() {
    let checkpoint = TestUtilities.createTestCheckpoint(testEnvironment)
    
    // Test operations that might fail
    
    // Restore to checkpoint if needed
    TestUtilities.restoreToCheckpoint(testEnvironment, checkpoint: checkpoint)
}
```

### UI Test Debugging

#### 1. Enable Screenshots
```bash
./scripts/run-ui-tests.sh --screenshots
```

#### 2. Use UI Test Debugging
```swift
func testUIFlow() {
    // Take screenshot at specific points
    takeScreenshot(name: "before-action")
    
    // Perform action
    app.buttons["Sign In"].tap()
    
    takeScreenshot(name: "after-action")
}
```

#### 3. Check Element Accessibility
```swift
func testElementAccessibility() {
    let button = app.buttons["Sign In"]
    
    // Debug element properties
    print("Button exists: \(button.exists)")
    print("Button is hittable: \(button.isHittable)")
    print("Button label: \(button.label)")
    print("Button identifier: \(button.identifier)")
}
```

## Adding New Tests

### Unit Tests

#### 1. Create Test Class
```swift
import XCTest
@testable import TribeBoard

class NewFeatureTests: TestBase {
    
    var featureUnderTest: NewFeature!
    
    override func setUp() {
        super.setUp()
        featureUnderTest = NewFeature(
            authService: mockAuthService,
            dataService: mockDataService
        )
    }
    
    override func tearDown() {
        featureUnderTest = nil
        super.tearDown()
    }
    
    func testFeatureBehavior() {
        // Arrange
        let expectedResult = "expected"
        
        // Act
        let result = featureUnderTest.performAction()
        
        // Assert
        XCTAssertEqual(result, expectedResult)
    }
}
```

#### 2. Follow Naming Conventions
- Test class: `[FeatureName]Tests`
- Test methods: `test[WhatIsBeingTested]`
- Use descriptive names that explain the scenario

#### 3. Use Test Data Factory
```swift
func testWithTestData() {
    // Use factory for consistent test data
    let testUser = TestDataFactory.createTestUserProfile()
    let testFamily = TestDataFactory.createTestFamily()
    
    // Configure mock services
    mockDataService.prePopulateUser(testUser, withHash: testUser.appleUserIdHash)
    mockDataService.prePopulateFamily(testFamily)
    
    // Run test
}
```

### Integration Tests

#### 1. Create Integration Test
```swift
class NewFeatureIntegrationTests: TestBase {
    
    func testCompleteWorkflow() async {
        // Set up complete test environment
        let environment = TestEnvironmentSetup.setupIntegrationTestEnvironment()
        defer { TestEnvironmentSetup.teardownIntegrationTestEnvironment(environment) }
        
        // Test complete workflow
        // 1. Authentication
        // 2. Data operations
        // 3. UI state updates
        
        // Verify end-to-end behavior
    }
}
```

### UI Tests

#### 1. Create UI Test Class
```swift
class NewFeatureUITests: UITestBase {
    
    func testNewFeatureFlow() {
        // Arrange - set up initial state
        performMockSignIn()
        
        // Act - perform user actions
        navigateToTab("New Feature")
        app.buttons["Action Button"].tap()
        
        // Assert - verify results
        XCTAssertTrue(app.staticTexts["Success Message"].waitForExistence(timeout: defaultTimeout))
    }
}
```

#### 2. Use Page Object Pattern
```swift
struct NewFeaturePage {
    let app: XCUIApplication
    
    var actionButton: XCUIElement { app.buttons["Action Button"] }
    var successMessage: XCUIElement { app.staticTexts["Success Message"] }
    
    func performAction() {
        actionButton.tap()
    }
    
    func waitForSuccess() -> Bool {
        return successMessage.waitForExistence(timeout: 10.0)
    }
}
```

## Maintaining Existing Tests

### When to Update Tests

1. **Feature Changes**: Update tests when feature behavior changes
2. **API Changes**: Update tests when service interfaces change
3. **UI Changes**: Update UI tests when interface elements change
4. **Bug Fixes**: Add tests to prevent regression

### Test Maintenance Checklist

- [ ] Update test data when model changes
- [ ] Update mock service behavior for new scenarios
- [ ] Verify test names still accurately describe behavior
- [ ] Check that assertions are still valid
- [ ] Update accessibility identifiers if UI changed
- [ ] Review test performance and optimize if needed

### Refactoring Tests

#### 1. Extract Common Setup
```swift
// Before
class FeatureTests: TestBase {
    func testScenario1() {
        let user = TestDataFactory.createTestUserProfile()
        mockAuthService.setMockUserProfile(user)
        // test code
    }
    
    func testScenario2() {
        let user = TestDataFactory.createTestUserProfile()
        mockAuthService.setMockUserProfile(user)
        // test code
    }
}

// After
class FeatureTests: TestBase {
    var testUser: UserProfile!
    
    override func setUp() {
        super.setUp()
        testUser = TestDataFactory.createTestUserProfile()
        mockAuthService.setMockUserProfile(testUser)
    }
    
    func testScenario1() {
        // test code
    }
    
    func testScenario2() {
        // test code
    }
}
```

#### 2. Use Helper Methods
```swift
extension FeatureTests {
    func setupAuthenticatedUser() {
        let user = TestDataFactory.createTestUserProfile()
        mockAuthService.setMockUserProfile(user)
        mockAuthService.setAuthenticationState(.authenticated)
    }
    
    func setupFamilyEnvironment() {
        let scenario = TestDataFactory.createCompleteFamilyScenario()
        TestDataFactory.configureMockDataService(mockDataService, with: scenario)
    }
}
```

## Mock Services

### Available Mock Services

1. **MockAuthService**: Simulates authentication operations
2. **MockDataService**: Provides in-memory data operations
3. **MockKeychainService**: Simulates secure storage

### Configuring Mock Services

#### Authentication Scenarios
```swift
// Success scenario
mockAuthService.setAuthenticationState(.authenticated)
mockAuthService.setMockUserProfile(testUser)

// Failure scenario
mockAuthService.setMockError(.authorizationFailed)
mockAuthService.setAuthenticationState(.error(.authorizationFailed))

// Network unavailable
mockAuthService.setNetworkUnavailable(true)
```

#### Data Service Scenarios
```swift
// Pre-populate with test data
mockDataService.prePopulateUser(testUser, withHash: testUser.appleUserIdHash)
mockDataService.prePopulateFamily(testFamily)

// Simulate errors
mockDataService.setMockError(.invalidData("Test error"))

// Simulate slow responses
mockDataService.setResponseDelay(2.0)
```

#### Keychain Scenarios
```swift
// Pre-populate keychain
mockKeychainService.prePopulate(data: testData, for: "test_key")

// Simulate keychain errors
mockKeychainService.setMockError(.itemNotFound)
```

### State Management

#### Save and Restore State
```swift
func testWithStateManagement() {
    let stateManager = MockServiceStateManager()
    
    // Save initial state
    stateManager.saveState(identifier: "initial", mockServices: mockServices)
    
    // Modify state for test
    mockAuthService.setAuthenticationState(.authenticated)
    
    // Restore if needed
    stateManager.restoreState(identifier: "initial", mockServices: mockServices)
}
```

## Test Utilities

### TestUtilities Class

Provides comprehensive utilities for test setup and management:

```swift
// Set up complete test environment
let environment = TestUtilities.setupCompleteTestEnvironment()

// Configure mock services
TestUtilities.configureDefaultMockServices(environment.mockServices)

// Generate test data
let dataset = TestUtilities.generateCompleteTestDataset()

// Validate environment
let validation = TestUtilities.validateTestEnvironment(environment)
```

### TestEnvironmentSetup Class

Provides specialized environment setup:

```swift
// Unit test environment
let unitEnv = TestEnvironmentSetup.setupUnitTestEnvironment()

// Integration test environment
let integrationEnv = TestEnvironmentSetup.setupIntegrationTestEnvironment()

// Performance test environment
let perfEnv = TestEnvironmentSetup.setupPerformanceTestEnvironment()
```

### TestDataFactory Class

Provides consistent test data generation:

```swift
// Create test entities
let user = TestDataFactory.createTestUserProfile()
let family = TestDataFactory.createTestFamily()

// Create complete scenarios
let authScenario = TestDataFactory.createCompleteAuthScenario()
let familyScenario = TestDataFactory.createCompleteFamilyScenario()
```

## Performance Testing

### Measuring Performance

#### Unit Test Performance
```swift
func testPerformance() {
    measure {
        // Code to measure
        featureUnderTest.performExpensiveOperation()
    }
}
```

#### Custom Performance Measurement
```swift
func testCustomPerformance() {
    let (result, executionTime) = TestUtilities.measureExecutionTime {
        return featureUnderTest.performOperation()
    }
    
    XCTAssertLessThan(executionTime, 1.0, "Operation should complete within 1 second")
}
```

#### Async Performance Measurement
```swift
func testAsyncPerformance() async {
    let (result, executionTime) = await TestUtilities.measureAsyncExecutionTime {
        return await featureUnderTest.performAsyncOperation()
    }
    
    XCTAssertLessThan(executionTime, 2.0, "Async operation should complete within 2 seconds")
}
```

### Performance Benchmarks

```swift
func testPerformanceBenchmark() {
    let benchmark = TestUtilities.createPerformanceBenchmark(name: "Feature Operation", iterations: 100)
    
    for _ in 0..<benchmark.iterations {
        let (_, time) = TestUtilities.measureExecutionTime {
            featureUnderTest.performOperation()
        }
        benchmark.recordExecution(time: time)
    }
    
    XCTAssertLessThan(benchmark.averageTime, 0.1, "Average execution time should be under 100ms")
}
```

## Accessibility Testing

### Using AccessibilityTestHelpers

```swift
func testAccessibility() {
    let button = app.buttons["Sign In"]
    
    // Verify accessibility compliance
    AccessibilityTestHelpers.verifyVoiceOverCompatibility(button)
    AccessibilityTestHelpers.verifyDynamicTypeSupport(button)
    AccessibilityTestHelpers.verifyColorContrastCompliance(button)
    AccessibilityTestHelpers.verifyTouchTargetSize(button)
}
```

### Accessibility Test Patterns

```swift
func testScreenAccessibility() {
    // Navigate to screen
    navigateToTab("Settings")
    
    // Verify all interactive elements are accessible
    let interactiveElements = app.buttons.allElementsBoundByIndex + 
                             app.textFields.allElementsBoundByIndex
    
    for element in interactiveElements {
        XCTAssertFalse(element.label.isEmpty, "Element should have accessibility label")
        XCTAssertTrue(element.isHittable, "Element should be hittable")
    }
}
```

## Continuous Integration

### CI Configuration

The test suite is designed to run in CI environments. Key considerations:

1. **Deterministic Tests**: All tests should produce consistent results
2. **Fast Execution**: Tests should complete quickly
3. **Clear Reporting**: Generate comprehensive test reports
4. **Coverage Reporting**: Track code coverage metrics

### CI Scripts

```bash
# Run all tests with coverage and reporting
./scripts/run-all-tests.sh --coverage --continue-on-fail

# Generate coverage report
./scripts/generate-coverage-report.sh --threshold 80

# Format results for CI
./scripts/format-test-results.sh -i test-results -f junit
```

### Environment Variables

Set these environment variables in CI:

- `UI_TESTING=1`: Enable UI testing mode
- `MOCK_AUTH_SERVICE=1`: Use mock authentication
- `MOCK_DATA_SERVICE=1`: Use mock data service
- `DISABLE_NETWORK_CALLS=1`: Disable real network calls

## Troubleshooting

### Common Issues and Solutions

#### 1. Test Timeouts

**Problem**: Tests fail due to timeouts
**Solutions**:
- Increase timeout values for slow operations
- Check for deadlocks in async code
- Verify mock services are responding
- Use `waitForExpectations` with appropriate timeouts

```swift
// Increase timeout for slow operations
let expectation = XCTestExpectation(description: "Slow operation")
// ... perform operation
wait(for: [expectation], timeout: 30.0) // Increased from default 5.0
```

#### 2. Flaky UI Tests

**Problem**: UI tests pass sometimes and fail other times
**Solutions**:
- Add explicit waits for elements
- Check element existence before interaction
- Use accessibility identifiers instead of text
- Disable animations in test environment

```swift
// Wait for element before interaction
let button = app.buttons["Action"]
XCTAssertTrue(button.waitForExistence(timeout: 10.0))
XCTAssertTrue(button.isHittable)
button.tap()
```

#### 3. Mock Service Issues

**Problem**: Mock services not behaving as expected
**Solutions**:
- Verify mock service configuration
- Check service state using debug utilities
- Reset services between tests
- Use state management for complex scenarios

```swift
override func setUp() {
    super.setUp()
    // Ensure clean state
    mockAuthService.reset()
    mockDataService.reset()
    mockKeychainService.reset()
}
```

#### 4. Memory Leaks in Tests

**Problem**: Tests consume excessive memory
**Solutions**:
- Properly clean up test objects
- Use weak references where appropriate
- Reset mock services after each test
- Monitor memory usage during test runs

```swift
override func tearDown() {
    // Clean up test objects
    featureUnderTest = nil
    testData = nil
    super.tearDown()
}
```

#### 5. Coverage Issues

**Problem**: Code coverage is lower than expected
**Solutions**:
- Review uncovered code paths
- Add tests for error scenarios
- Test edge cases and boundary conditions
- Use coverage reports to identify gaps

```bash
# Generate detailed coverage report
./scripts/generate-coverage-report.sh --format html --threshold 80
```

### Debug Utilities

#### Environment Debugging
```swift
// Debug test environment
TestUtilities.debugTestEnvironment(testEnvironment)

// Validate environment setup
let validation = TestUtilities.validateTestEnvironment(testEnvironment)
if !validation.isValid {
    print("Environment issues: \(validation.issues)")
}
```

#### Test Data Debugging
```swift
// Debug test data
let dataset = TestUtilities.generateCompleteTestDataset()
TestUtilities.debugTestData(dataset)

// Validate test data
let dataValidation = TestUtilities.validateTestData(dataset)
if !dataValidation.isValid {
    print("Data issues: \(dataValidation.issues)")
}
```

#### Mock Service Debugging
```swift
// Debug mock service state
let stateManager = MockServiceStateManager()
let validation = stateManager.validateState(mockServices, expectedState: .authenticated)
if !validation.isValid {
    print("State issues: \(validation.issues)")
}
```

### Getting Help

1. **Check Documentation**: Review this guide and inline code documentation
2. **Run Diagnostics**: Use debug utilities to understand test state
3. **Isolate Issues**: Run single tests to isolate problems
4. **Check Logs**: Review test output and error messages
5. **Use Debugger**: Step through test execution in Xcode

### Best Practices Summary

1. **Keep Tests Simple**: Each test should verify one specific behavior
2. **Use Descriptive Names**: Test names should clearly explain what is being tested
3. **Maintain Test Independence**: Tests should not depend on each other
4. **Mock External Dependencies**: Use mock services for all external dependencies
5. **Test Edge Cases**: Include tests for error conditions and boundary cases
6. **Keep Tests Fast**: Optimize test execution time for frequent running
7. **Regular Maintenance**: Review and update tests as code evolves
8. **Document Complex Tests**: Add comments for complex test scenarios
9. **Use Test Utilities**: Leverage provided utilities for consistency
10. **Monitor Coverage**: Maintain high code coverage with meaningful tests

This guide should be updated as the test suite evolves and new patterns emerge.