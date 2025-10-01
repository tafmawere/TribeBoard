# TribeBoard Test Troubleshooting Guide

This guide provides solutions to common issues encountered when running TribeBoard tests.

## Table of Contents

1. [General Troubleshooting](#general-troubleshooting)
2. [Build and Compilation Issues](#build-and-compilation-issues)
3. [Test Execution Issues](#test-execution-issues)
4. [Mock Service Issues](#mock-service-issues)
5. [UI Test Issues](#ui-test-issues)
6. [Performance Issues](#performance-issues)
7. [Coverage Issues](#coverage-issues)
8. [Environment Issues](#environment-issues)
9. [CI/CD Issues](#cicd-issues)
10. [Debug Techniques](#debug-techniques)

## General Troubleshooting

### First Steps for Any Test Issue

1. **Check System Status**
   ```bash
   # Verify Xcode and tools are working
   xcodebuild -version
   xcrun simctl list devices
   
   # Check available disk space
   df -h
   
   # Check system resources
   top -l 1 | grep "CPU usage"
   ```

2. **Clean Environment**
   ```bash
   # Clean Xcode derived data
   rm -rf ~/Library/Developer/Xcode/DerivedData/TribeBoard-*
   
   # Reset simulators
   xcrun simctl erase all
   
   # Clean test results
   rm -rf test-results/
   ```

3. **Verify Project State**
   ```bash
   # Ensure project builds
   xcodebuild -scheme TribeBoard -destination 'platform=iOS Simulator,name=iPhone 15' build
   
   # Check for uncommitted changes
   git status
   ```

### Quick Diagnostic Commands

```bash
# Run minimal test to verify setup
./scripts/run-unit-tests.sh --test TestBase/testExample

# Check test environment
./scripts/run-unit-tests.sh --verbose --test AuthServiceTests/testSignInSuccess

# Verify mock services
./scripts/run-unit-tests.sh --test MockAuthServiceTests
```

## Build and Compilation Issues

### Issue: "No such module 'TribeBoard'"

**Symptoms:**
- Tests fail to compile
- Import statements show errors
- Module not found errors

**Solutions:**

1. **Verify Target Membership**
   ```bash
   # Check that test files are in correct target
   # In Xcode: Select test file → File Inspector → Target Membership
   ```

2. **Clean and Rebuild**
   ```bash
   # Clean build folder
   rm -rf ~/Library/Developer/Xcode/DerivedData/TribeBoard-*
   
   # Rebuild project
   xcodebuild -scheme TribeBoard clean build
   ```

3. **Check Import Statements**
   ```swift
   // Correct import for unit tests
   @testable import TribeBoard
   
   // For UI tests (no @testable needed)
   import XCTest
   ```

### Issue: "Undefined symbol" Errors

**Symptoms:**
- Linker errors during test compilation
- Missing symbol references

**Solutions:**

1. **Check Framework Linking**
   - Verify test targets link to main app target
   - Check framework search paths

2. **Verify Access Levels**
   ```swift
   // Make sure functions are accessible to tests
   internal func functionToTest() { } // Accessible with @testable import
   private func privateFunction() { } // Not accessible to tests
   ```

3. **Clean and Rebuild**
   ```bash
   xcodebuild -scheme TribeBoard -destination 'platform=iOS Simulator,name=iPhone 15' clean build
   ```

### Issue: Swift Compilation Errors

**Symptoms:**
- Swift compiler errors in test files
- Type mismatch errors

**Solutions:**

1. **Check Swift Version Compatibility**
   ```bash
   # Verify Swift version
   swift --version
   
   # Check project Swift version settings
   # Project Settings → Build Settings → Swift Language Version
   ```

2. **Update Test Code for Swift Changes**
   ```swift
   // Old syntax that might cause issues
   let expectation = XCTestExpectation(description: "test")
   
   // Ensure proper async/await usage
   func testAsync() async throws {
       let result = try await asyncFunction()
       XCTAssertNotNil(result)
   }
   ```

## Test Execution Issues

### Issue: Tests Timeout

**Symptoms:**
- Tests fail with timeout errors
- Long execution times
- Hanging test execution

**Solutions:**

1. **Increase Timeout Values**
   ```swift
   // In test code
   let expectation = XCTestExpectation(description: "async operation")
   wait(for: [expectation], timeout: 30.0) // Increased from 5.0
   
   // In UI tests
   let element = app.buttons["Sign In"]
   XCTAssertTrue(element.waitForExistence(timeout: 15.0)) // Increased timeout
   ```

2. **Check for Deadlocks**
   ```swift
   // Avoid blocking main queue in tests
   func testAsync() async {
       // Use async/await instead of blocking calls
       let result = await asyncOperation()
       XCTAssertNotNil(result)
   }
   ```

3. **Optimize Mock Services**
   ```swift
   // Reduce mock service delays
   mockAuthService.setResponseDelay(0.1) // Reduced from default
   ```

4. **Use Script Timeouts**
   ```bash
   # Run with extended timeout
   timeout 1800 ./scripts/run-all-tests.sh  # 30 minutes
   ```

### Issue: Tests Fail Intermittently (Flaky Tests)

**Symptoms:**
- Tests pass sometimes, fail other times
- Different results on different runs
- Race conditions

**Solutions:**

1. **Add Proper Waits**
   ```swift
   // UI Tests - wait for elements
   let button = app.buttons["Action"]
   XCTAssertTrue(button.waitForExistence(timeout: 10.0))
   XCTAssertTrue(button.isHittable)
   button.tap()
   
   // Unit Tests - use expectations for async operations
   let expectation = XCTestExpectation(description: "async completion")
   asyncOperation { result in
       XCTAssertNotNil(result)
       expectation.fulfill()
   }
   wait(for: [expectation], timeout: 10.0)
   ```

2. **Fix Race Conditions**
   ```swift
   // Use proper synchronization
   func testConcurrentOperation() async {
       let results = await withTaskGroup(of: String.self) { group in
           group.addTask { await operation1() }
           group.addTask { await operation2() }
           
           var results: [String] = []
           for await result in group {
               results.append(result)
           }
           return results
       }
       
       XCTAssertEqual(results.count, 2)
   }
   ```

3. **Ensure Test Isolation**
   ```swift
   override func setUp() {
       super.setUp()
       // Reset all state
       mockAuthService.reset()
       mockDataService.reset()
       mockKeychainService.reset()
   }
   ```

### Issue: "Test target failed to run"

**Symptoms:**
- Tests don't start execution
- Simulator launch failures
- Target configuration errors

**Solutions:**

1. **Check Simulator Status**
   ```bash
   # List available simulators
   xcrun simctl list devices
   
   # Boot simulator if needed
   xcrun simctl boot "iPhone 15"
   
   # Reset if corrupted
   xcrun simctl erase "iPhone 15"
   ```

2. **Verify Test Target Configuration**
   - Check test target build settings
   - Verify host application is set correctly
   - Ensure test target has proper dependencies

3. **Check Destination**
   ```bash
   # Use correct destination format
   ./scripts/run-unit-tests.sh --destination "platform=iOS Simulator,name=iPhone 15,OS=latest"
   ```

## Mock Service Issues

### Issue: Mock Services Not Working

**Symptoms:**
- Tests fail because real services are called
- Authentication errors in tests
- Network calls in test environment

**Solutions:**

1. **Verify Mock Service Injection**
   ```swift
   class FeatureTests: TestBase {
       override func setUp() {
           super.setUp()
           
           // Ensure mock services are injected
           XCTAssertTrue(mockAuthService.isConfigured)
           XCTAssertTrue(mockDataService.isConfigured)
           XCTAssertTrue(mockKeychainService.isConfigured)
       }
   }
   ```

2. **Check Environment Variables**
   ```bash
   # Set mock service environment variables
   export MOCK_AUTH_SERVICE=1
   export MOCK_DATA_SERVICE=1
   export DISABLE_NETWORK_CALLS=1
   
   ./scripts/run-unit-tests.sh
   ```

3. **Debug Mock Service State**
   ```swift
   func testWithMockDebugging() {
       // Debug mock service configuration
       TestUtilities.debugTestEnvironment(testEnvironment)
       
       // Verify mock service state
       let validation = TestUtilities.validateTestEnvironment(testEnvironment)
       XCTAssertTrue(validation.isValid, "Mock services not properly configured: \(validation.issues)")
   }
   ```

### Issue: Mock Service State Persistence

**Symptoms:**
- Mock services retain state between tests
- Tests affect each other
- Inconsistent test results

**Solutions:**

1. **Reset Mock Services**
   ```swift
   override func setUp() {
       super.setUp()
       
       // Reset all mock services
       mockAuthService.reset()
       mockDataService.reset()
       mockKeychainService.reset()
   }
   
   override func tearDown() {
       // Clean up after test
       TestUtilities.cleanupTestEnvironment(testEnvironment)
       super.tearDown()
   }
   ```

2. **Use State Management**
   ```swift
   func testWithStateManagement() {
       let stateManager = MockServiceStateManager()
       
       // Save clean state
       stateManager.saveState(identifier: "clean", mockServices: mockServices)
       
       // Perform test operations
       // ...
       
       // Restore clean state
       stateManager.restoreState(identifier: "clean", mockServices: mockServices)
   }
   ```

### Issue: Mock Service Configuration Errors

**Symptoms:**
- Mock services throw unexpected errors
- Configuration not applied correctly
- Service behavior doesn't match expectations

**Solutions:**

1. **Verify Configuration**
   ```swift
   func testMockConfiguration() {
       // Configure mock service
       mockAuthService.setAuthenticationState(.authenticated)
       mockAuthService.setMockUserProfile(testUser)
       
       // Verify configuration applied
       XCTAssertEqual(mockAuthService.currentState.authenticationState, .authenticated)
       XCTAssertNotNil(mockAuthService.currentState.userProfile)
   }
   ```

2. **Use Test Data Factory**
   ```swift
   func testWithProperConfiguration() {
       // Use factory for consistent configuration
       let authScenario = TestDataFactory.createCompleteAuthScenario()
       TestDataFactory.configureMockAuthService(mockAuthService, with: authScenario)
       
       // Verify configuration
       XCTAssertTrue(mockAuthService.isInAuthenticationState(true))
   }
   ```

## UI Test Issues

### Issue: UI Elements Not Found

**Symptoms:**
- "Element not found" errors
- UI tests fail to locate buttons, text fields, etc.
- Accessibility identifier issues

**Solutions:**

1. **Use Accessibility Identifiers**
   ```swift
   // In app code - set accessibility identifiers
   button.accessibilityIdentifier = "signInButton"
   
   // In UI tests - use identifiers instead of text
   let signInButton = app.buttons["signInButton"]
   XCTAssertTrue(signInButton.waitForExistence(timeout: 10.0))
   ```

2. **Add Explicit Waits**
   ```swift
   func testUIFlow() {
       // Wait for element to appear
       let button = app.buttons["Sign In"]
       XCTAssertTrue(button.waitForExistence(timeout: 10.0))
       
       // Verify element is interactable
       XCTAssertTrue(button.isHittable)
       
       // Perform action
       button.tap()
   }
   ```

3. **Debug Element Hierarchy**
   ```swift
   func testElementDebugging() {
       // Print element hierarchy
       print(app.debugDescription)
       
       // Check specific element properties
       let button = app.buttons.firstMatch
       print("Button exists: \(button.exists)")
       print("Button label: \(button.label)")
       print("Button identifier: \(button.identifier)")
   }
   ```

### Issue: UI Tests Are Slow

**Symptoms:**
- UI tests take very long to execute
- Timeouts due to slow element interactions
- Poor test performance

**Solutions:**

1. **Disable Animations**
   ```swift
   // In test setup
   app.launchArguments = ["-DisableAnimations"]
   
   // Or in scheme settings
   // Edit Scheme → Test → Arguments → Launch Arguments → Add "-DisableAnimations"
   ```

2. **Use Parallel Execution**
   ```bash
   ./scripts/run-ui-tests.sh --parallel
   ```

3. **Optimize Element Queries**
   ```swift
   // Efficient element queries
   let button = app.buttons["specificIdentifier"] // Fast
   
   // Avoid inefficient queries
   let button = app.descendants(matching: .button).matching(identifier: "id").firstMatch // Slow
   ```

4. **Reduce Wait Times**
   ```swift
   // Use shorter timeouts where appropriate
   XCTAssertTrue(element.waitForExistence(timeout: 3.0)) // Instead of 10.0
   ```

### Issue: Screenshot Capture Failures

**Symptoms:**
- Screenshots not captured on test failure
- Screenshot files not found
- Image corruption

**Solutions:**

1. **Enable Screenshot Capture**
   ```bash
   ./scripts/run-ui-tests.sh --screenshots
   ```

2. **Manual Screenshot Capture**
   ```swift
   func testWithScreenshots() {
       // Take screenshot at specific points
       takeScreenshot(name: "initial-state")
       
       // Perform action
       app.buttons["Action"].tap()
       
       // Take screenshot after action
       takeScreenshot(name: "after-action")
   }
   ```

3. **Check Screenshot Directory**
   ```bash
   # Verify screenshots are saved
   ls -la test-results/screenshots/
   ```

## Performance Issues

### Issue: Tests Run Too Slowly

**Symptoms:**
- Long test execution times
- Timeouts due to performance
- Resource exhaustion

**Solutions:**

1. **Profile Test Performance**
   ```swift
   func testPerformance() {
       measure {
           // Code to measure
           performExpensiveOperation()
       }
   }
   ```

2. **Optimize Mock Services**
   ```swift
   // Reduce mock service delays
   mockAuthService.setResponseDelay(0.01) // Very fast for tests
   mockDataService.setResponseDelay(0.01)
   ```

3. **Use Faster Simulator**
   ```bash
   # Use latest iPhone simulator
   ./scripts/run-ui-tests.sh --destination "platform=iOS Simulator,name=iPhone 15,OS=latest"
   ```

4. **Run Tests in Parallel**
   ```bash
   ./scripts/run-all-tests.sh --parallel
   ```

### Issue: Memory Issues During Testing

**Symptoms:**
- Out of memory errors
- Simulator crashes
- System slowdown

**Solutions:**

1. **Monitor Memory Usage**
   ```bash
   # Check memory usage during tests
   top -pid $(pgrep -f Simulator)
   ```

2. **Clean Up Test Objects**
   ```swift
   override func tearDown() {
       // Explicitly clean up large objects
       largeTestData = nil
       mockServices.resetAll()
       super.tearDown()
   }
   ```

3. **Reset Simulator Between Test Runs**
   ```bash
   # Reset simulator to free memory
   xcrun simctl erase all
   ```

## Coverage Issues

### Issue: Low Code Coverage

**Symptoms:**
- Coverage reports show low percentages
- Missing coverage for important code paths
- Coverage below threshold

**Solutions:**

1. **Identify Uncovered Code**
   ```bash
   # Generate detailed coverage report
   ./scripts/generate-coverage-report.sh --format html
   
   # Open HTML report to see uncovered lines
   open coverage-reports/coverage-*/coverage-report.html
   ```

2. **Add Tests for Uncovered Paths**
   ```swift
   func testErrorPath() {
       // Test error conditions that might be uncovered
       mockAuthService.setMockError(.networkUnavailable)
       
       // Verify error handling
       XCTAssertThrowsError(try authService.signIn()) { error in
           XCTAssertEqual(error as? AuthError, .networkUnavailable)
       }
   }
   ```

3. **Test Edge Cases**
   ```swift
   func testEdgeCases() {
       // Test boundary conditions
       let emptyString = ""
       let veryLongString = String(repeating: "a", count: 10000)
       
       XCTAssertThrowsError(try validator.validate(emptyString))
       XCTAssertThrowsError(try validator.validate(veryLongString))
   }
   ```

### Issue: Coverage Report Generation Fails

**Symptoms:**
- Coverage reports not generated
- xcov command failures
- Missing coverage data

**Solutions:**

1. **Verify Coverage is Enabled**
   ```bash
   # Run tests with coverage explicitly enabled
   ./scripts/run-unit-tests.sh --coverage
   ```

2. **Check xcov Installation**
   ```bash
   # Verify xcov is available
   xcrun xccov version
   
   # If not available, check Xcode installation
   xcode-select --print-path
   ```

3. **Manual Coverage Extraction**
   ```bash
   # Extract coverage manually
   xcrun xccov view --report test-results/*.xcresult
   ```

## Environment Issues

### Issue: Environment Variables Not Set

**Symptoms:**
- Tests use real services instead of mocks
- Unexpected network calls
- Authentication failures

**Solutions:**

1. **Set Environment Variables**
   ```bash
   # Set in shell
   export UI_TESTING=1
   export MOCK_AUTH_SERVICE=1
   export MOCK_DATA_SERVICE=1
   
   # Run tests
   ./scripts/run-unit-tests.sh
   ```

2. **Set in Xcode Scheme**
   - Edit Scheme → Test → Arguments → Environment Variables
   - Add: `UI_TESTING = 1`
   - Add: `MOCK_AUTH_SERVICE = 1`

3. **Verify Environment Variables**
   ```swift
   func testEnvironmentVariables() {
       XCTAssertEqual(ProcessInfo.processInfo.environment["UI_TESTING"], "1")
       XCTAssertEqual(ProcessInfo.processInfo.environment["MOCK_AUTH_SERVICE"], "1")
   }
   ```

### Issue: Simulator Configuration Problems

**Symptoms:**
- Simulator doesn't launch
- Wrong simulator version
- Simulator state issues

**Solutions:**

1. **List Available Simulators**
   ```bash
   xcrun simctl list devices
   ```

2. **Create New Simulator**
   ```bash
   # Create iPhone 15 simulator
   xcrun simctl create "iPhone 15 Test" "iPhone 15" "iOS-17-0"
   ```

3. **Reset Simulator**
   ```bash
   # Reset specific simulator
   xcrun simctl erase "iPhone 15"
   
   # Reset all simulators
   xcrun simctl erase all
   ```

4. **Boot Simulator Manually**
   ```bash
   xcrun simctl boot "iPhone 15"
   ```

## CI/CD Issues

### Issue: Tests Fail Only in CI

**Symptoms:**
- Tests pass locally but fail in CI
- Different behavior in CI environment
- CI-specific errors

**Solutions:**

1. **Simulate CI Environment Locally**
   ```bash
   # Set CI environment variables
   export CI=true
   export GITHUB_ACTIONS=true  # or appropriate CI system
   
   # Run tests as in CI
   ./scripts/run-all-tests.sh --coverage --continue-on-fail
   ```

2. **Check CI Configuration**
   ```yaml
   # Example GitHub Actions configuration
   - name: Run Tests
     run: |
       export UI_TESTING=1
       export MOCK_AUTH_SERVICE=1
       ./scripts/run-all-tests.sh --coverage
   ```

3. **Add CI-Specific Debugging**
   ```bash
   # Add debug output in CI scripts
   if [ "$CI" = "true" ]; then
       echo "Running in CI environment"
       env | grep -E "(UI_TESTING|MOCK_|TEST_)"
   fi
   ```

### Issue: CI Timeout Issues

**Symptoms:**
- CI jobs timeout
- Tests take too long in CI
- Resource limitations

**Solutions:**

1. **Increase CI Timeouts**
   ```yaml
   # GitHub Actions example
   - name: Run Tests
     timeout-minutes: 30  # Increased timeout
     run: ./scripts/run-all-tests.sh
   ```

2. **Optimize for CI**
   ```bash
   # Use CI-optimized test execution
   ./scripts/run-all-tests.sh --parallel --continue-on-fail
   ```

3. **Split Test Execution**
   ```yaml
   # Run test categories separately
   - name: Unit Tests
     run: ./scripts/run-unit-tests.sh
   
   - name: Integration Tests
     run: ./scripts/run-integration-tests.sh
   
   - name: UI Tests
     run: ./scripts/run-ui-tests.sh
   ```

## Debug Techniques

### Enable Verbose Logging

```bash
# Run with verbose output
./scripts/run-unit-tests.sh --verbose

# Enable test-specific logging
export TEST_VERBOSE_LOGGING=1
./scripts/run-unit-tests.sh
```

### Use Xcode Debugger

1. **Set Breakpoints in Tests**
   ```swift
   func testDebugExample() {
       let result = functionUnderTest()
       // Set breakpoint here
       XCTAssertNotNil(result)
   }
   ```

2. **Use LLDB Commands**
   ```
   (lldb) po mockAuthService.currentState
   (lldb) expr mockAuthService.reset()
   (lldb) continue
   ```

### Debug Test Environment

```swift
func testWithEnvironmentDebugging() {
    // Print environment state
    TestUtilities.debugTestEnvironment(testEnvironment)
    
    // Validate environment
    let validation = TestUtilities.validateTestEnvironment(testEnvironment)
    if !validation.isValid {
        print("Environment issues: \(validation.issues)")
    }
    
    // Debug mock service state
    let stateManager = MockServiceStateManager()
    let stateValidation = stateManager.validateState(
        mockServices, 
        expectedState: .authenticated
    )
    if !stateValidation.isValid {
        print("State issues: \(stateValidation.issues)")
    }
}
```

### Capture Test Artifacts

```bash
# Capture comprehensive test artifacts
./scripts/run-all-tests.sh --coverage --screenshots --verbose > test-debug.log 2>&1

# Generate detailed reports
./scripts/format-test-results.sh -i test-results -f html -s -l
```

### System Diagnostics

```bash
# Check system resources
top -l 1 | head -20

# Check disk space
df -h

# Check simulator processes
ps aux | grep Simulator

# Check Xcode processes
ps aux | grep xcodebuild
```

## Getting Additional Help

### Collect Debug Information

When reporting issues, include:

1. **System Information**
   ```bash
   sw_vers
   xcodebuild -version
   xcrun simctl list devices
   ```

2. **Test Output**
   ```bash
   ./scripts/run-unit-tests.sh --verbose > debug-output.log 2>&1
   ```

3. **Environment State**
   ```bash
   env | grep -E "(UI_TESTING|MOCK_|TEST_|CI)"
   ```

4. **Project State**
   ```bash
   git status
   git log --oneline -5
   ```

### Common Debug Commands

```bash
# Quick environment check
./scripts/run-unit-tests.sh --test TestBase/testExample --verbose

# Full diagnostic run
./scripts/run-all-tests.sh --coverage --verbose --continue-on-fail

# Reset everything
xcrun simctl erase all
rm -rf ~/Library/Developer/Xcode/DerivedData/TribeBoard-*
rm -rf test-results/

# Verify setup
xcodebuild -scheme TribeBoard -destination 'platform=iOS Simulator,name=iPhone 15' build
```

This troubleshooting guide should help you resolve most common issues with the TribeBoard test suite. For issues not covered here, refer to the [Test Maintenance Guide](TEST_MAINTENANCE_GUIDE.md) or create a detailed issue report with the debug information outlined above.