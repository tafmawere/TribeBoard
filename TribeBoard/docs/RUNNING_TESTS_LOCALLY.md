# Running TribeBoard Tests Locally

This guide provides step-by-step instructions for running TribeBoard tests on your local development machine.

## Prerequisites

### Required Software

1. **Xcode 15.0+**
   - Download from the Mac App Store or Apple Developer Portal
   - Ensure Command Line Tools are installed: `xcode-select --install`

2. **iOS Simulator**
   - Included with Xcode
   - Recommended: iPhone 15 with latest iOS version

3. **Command Line Tools** (Optional but recommended)
   - `xcpretty`: For formatted test output
     ```bash
     gem install xcpretty
     ```
   - `Python 3.7+`: For test result analysis scripts
     ```bash
     python3 --version  # Should be 3.7 or higher
     ```

### Project Setup

1. **Clone the Repository**
   ```bash
   git clone <repository-url>
   cd TribeBoard
   ```

2. **Open in Xcode**
   ```bash
   open TribeBoard.xcodeproj
   ```

3. **Verify Project Configuration**
   - Ensure the project builds successfully (Cmd+B)
   - Check that test targets are properly configured
   - Verify simulator is available and running

## Quick Start

### Run All Tests (Recommended for First Time)

```bash
# Run all test categories with basic reporting
./scripts/run-all-tests.sh

# Run all tests with coverage and detailed reporting
./scripts/run-all-tests.sh --coverage --verbose
```

### Run Specific Test Categories

```bash
# Unit tests only (fastest)
./scripts/run-unit-tests.sh

# Integration tests only
./scripts/run-integration-tests.sh

# UI tests only (slowest)
./scripts/run-ui-tests.sh
```

## Detailed Instructions

### 1. Unit Tests

Unit tests are the fastest and should be run frequently during development.

#### Basic Execution
```bash
./scripts/run-unit-tests.sh
```

#### With Coverage
```bash
./scripts/run-unit-tests.sh --coverage
```

#### Specific Test Class
```bash
./scripts/run-unit-tests.sh --test AuthServiceTests
```

#### Specific Test Method
```bash
./scripts/run-unit-tests.sh --test AuthServiceTests/testSignInSuccess
```

#### Expected Output
```
[INFO] Starting unit test execution...
[INFO] Scheme: TribeBoard
[INFO] Destination: platform=iOS Simulator,name=iPhone 15,OS=latest
[INFO] Output Directory: test-results

Test Suite 'AuthServiceTests' started at 2024-01-10 10:30:00.000
Test Case '-[AuthServiceTests testSignInSuccess]' started.
Test Case '-[AuthServiceTests testSignInSuccess]' passed (0.123 seconds).
...

[SUCCESS] Unit tests completed successfully!
[SUCCESS] Test results saved to: test-results/unit-tests-20240110-103000.xcresult
```

### 2. Integration Tests

Integration tests verify that components work together correctly.

#### Basic Execution
```bash
./scripts/run-integration-tests.sh
```

#### With Coverage
```bash
./scripts/run-integration-tests.sh --coverage
```

#### Expected Runtime
- Typical execution time: 2-5 minutes
- Tests complete authentication and data workflows

### 3. UI Tests

UI tests simulate user interactions and verify the complete user experience.

#### Basic Execution
```bash
./scripts/run-ui-tests.sh
```

#### With Screenshots
```bash
./scripts/run-ui-tests.sh --screenshots
```

#### Parallel Execution (Faster)
```bash
./scripts/run-ui-tests.sh --parallel
```

#### Expected Runtime
- Typical execution time: 5-15 minutes
- Tests launch the app and simulate user interactions

### 4. Running Tests in Xcode

#### Using Xcode Interface

1. **Open Test Navigator**
   - Press Cmd+6 or click the test icon in the navigator

2. **Run All Tests**
   - Click the play button next to "TribeBoardTests" or "TribeBoardUITests"
   - Or press Cmd+U to run all tests

3. **Run Specific Tests**
   - Click the play button next to a specific test class or method
   - Or right-click and select "Run [TestName]"

4. **Debug Tests**
   - Set breakpoints in test methods
   - Right-click and select "Debug [TestName]"
   - Use the debugger to step through test execution

#### Xcode Test Configuration

1. **Edit Scheme for Testing**
   - Product → Scheme → Edit Scheme
   - Select "Test" tab
   - Configure test options:
     - Code Coverage: Enable for coverage reports
     - Diagnostics: Enable for memory debugging
     - Arguments: Add test-specific launch arguments

2. **Test Settings**
   - Randomize execution order: Helps identify test dependencies
   - Run tests in parallel: Speeds up execution (use carefully)
   - Code coverage: Essential for coverage analysis

## Test Configuration Options

### Environment Variables

Set these in your test scheme or shell:

```bash
# Enable UI testing mode
export UI_TESTING=1

# Use mock services
export MOCK_AUTH_SERVICE=1
export MOCK_DATA_SERVICE=1

# Disable network calls
export DISABLE_NETWORK_CALLS=1

# Enable verbose logging
export TEST_VERBOSE_LOGGING=1
```

### Launch Arguments

Add these to your test scheme:

- `-UITesting`: Enable UI testing mode
- `-DisableAnimations`: Speed up UI tests
- `-UseMockServices`: Use mock services instead of real ones

### Simulator Configuration

#### Recommended Simulator Settings

1. **Device**: iPhone 15 (or latest available)
2. **iOS Version**: Latest available
3. **Settings to Configure**:
   - Disable auto-lock: Settings → Display & Brightness → Auto-Lock → Never
   - Disable keyboard autocorrect: Settings → General → Keyboard → Auto-Correction → Off
   - Enable accessibility inspector (for accessibility tests)

#### Reset Simulator (If Tests Behave Unexpectedly)

```bash
# Reset all simulators
xcrun simctl erase all

# Reset specific simulator
xcrun simctl erase "iPhone 15"
```

## Understanding Test Output

### Success Output

```
[INFO] Starting unit test execution...
[INFO] Scheme: TribeBoard
[INFO] Destination: platform=iOS Simulator,name=iPhone 15,OS=latest

Test Suite 'All tests' started at 2024-01-10 10:30:00.000
Test Suite 'TribeBoardTests.xctest' started at 2024-01-10 10:30:00.000

Test Suite 'AuthServiceTests' started at 2024-01-10 10:30:00.100
Test Case '-[AuthServiceTests testSignInSuccess]' started.
Test Case '-[AuthServiceTests testSignInSuccess]' passed (0.123 seconds).
Test Case '-[AuthServiceTests testSignInFailure]' started.
Test Case '-[AuthServiceTests testSignInFailure]' passed (0.089 seconds).
Test Suite 'AuthServiceTests' passed at 2024-01-10 10:30:00.500.
     Executed 2 tests, with 0 failures (0 unexpected) in 0.212 (0.400) seconds

[SUCCESS] Unit tests completed successfully!
[SUCCESS] Test results saved to: test-results/unit-tests-20240110-103000.xcresult
[SUCCESS] JUnit report saved to: test-results/unit-tests-report.xml
```

### Failure Output

```
Test Case '-[AuthServiceTests testSignInSuccess]' started.
/path/to/AuthServiceTests.swift:45: error: -[AuthServiceTests testSignInSuccess] : XCTAssertEqual failed: ("actual") is not equal to ("expected")
Test Case '-[AuthServiceTests testSignInSuccess]' failed (0.123 seconds).

[ERROR] Unit tests failed!
```

### Coverage Output (When Enabled)

```
[INFO] Generating coverage report...
[SUCCESS] Coverage report generated at test-results/coverage-report.txt

Coverage Summary:
- Overall Coverage: 85.2%
- TribeBoard Target: 87.1%
- Authentication Module: 92.3%
- Data Service Module: 78.9%
```

## Troubleshooting Common Issues

### 1. Build Failures

**Problem**: Tests fail to build
**Solutions**:
```bash
# Clean build folder
rm -rf ~/Library/Developer/Xcode/DerivedData/TribeBoard-*

# Clean in Xcode
# Product → Clean Build Folder (Cmd+Shift+K)

# Reset package dependencies (if using SPM)
# File → Packages → Reset Package Caches
```

### 2. Simulator Issues

**Problem**: Simulator not responding or tests timing out
**Solutions**:
```bash
# Kill all simulator processes
sudo pkill -f Simulator

# Reset simulator
xcrun simctl erase all

# Restart simulator
open -a Simulator
```

### 3. Test Timeouts

**Problem**: Tests fail with timeout errors
**Solutions**:
- Increase timeout values in test scripts
- Check system performance (close other apps)
- Use faster simulator device
- Run tests with `--verbose` to see where they hang

### 4. Permission Issues

**Problem**: Tests fail due to file permissions
**Solutions**:
```bash
# Fix script permissions
chmod +x scripts/*.sh

# Fix test result directory permissions
chmod -R 755 test-results/
```

### 5. Mock Service Issues

**Problem**: Tests fail due to mock service configuration
**Solutions**:
- Verify mock services are properly initialized
- Check test environment setup
- Use debug utilities to inspect mock state
- Reset mock services between tests

### 6. UI Test Failures

**Problem**: UI tests fail to find elements
**Solutions**:
- Verify accessibility identifiers are set
- Check element timing (add waits)
- Disable animations in test environment
- Use Xcode's UI test recording feature

## Performance Optimization

### Speed Up Test Execution

1. **Run Tests in Parallel**
   ```bash
   ./scripts/run-ui-tests.sh --parallel
   ```

2. **Use Faster Simulator**
   - Use iPhone 15 instead of older models
   - Ensure simulator has sufficient resources

3. **Disable Animations**
   - Add `-DisableAnimations` launch argument
   - Set animation speed to 0 in simulator

4. **Run Specific Tests During Development**
   ```bash
   # Only run tests for feature you're working on
   ./scripts/run-unit-tests.sh --test FeatureTests
   ```

### Monitor Test Performance

```bash
# Generate performance report
./scripts/run-all-tests.sh --coverage --verbose > test-performance.log

# Analyze slow tests
grep "seconds)" test-performance.log | sort -k3 -nr | head -10
```

## Coverage Analysis

### Generate Coverage Report

```bash
# Generate HTML coverage report
./scripts/generate-coverage-report.sh --format html

# Generate with custom threshold
./scripts/generate-coverage-report.sh --threshold 90

# Include test files in analysis
./scripts/generate-coverage-report.sh --include-tests
```

### Understanding Coverage Reports

- **Line Coverage**: Percentage of code lines executed
- **Function Coverage**: Percentage of functions called
- **Branch Coverage**: Percentage of code branches taken

### Coverage Thresholds

- **Excellent**: 90%+ coverage
- **Good**: 80-89% coverage
- **Needs Improvement**: <80% coverage

## Continuous Integration Simulation

### Simulate CI Environment Locally

```bash
# Run tests as they would run in CI
export CI=true
export UI_TESTING=1
export MOCK_AUTH_SERVICE=1
export MOCK_DATA_SERVICE=1

./scripts/run-all-tests.sh --coverage --continue-on-fail
```

### Generate CI Reports

```bash
# Generate JUnit XML for CI systems
./scripts/format-test-results.sh -i test-results -f junit

# Generate JSON for programmatic analysis
./scripts/format-test-results.sh -i test-results -f json
```

## Best Practices for Local Testing

### During Development

1. **Run Unit Tests Frequently**
   ```bash
   # Quick feedback loop
   ./scripts/run-unit-tests.sh --test YourFeatureTests
   ```

2. **Run Integration Tests Before Commits**
   ```bash
   ./scripts/run-integration-tests.sh
   ```

3. **Run Full Test Suite Before Pull Requests**
   ```bash
   ./scripts/run-all-tests.sh --coverage
   ```

### Test-Driven Development

1. **Write Failing Test First**
   ```bash
   ./scripts/run-unit-tests.sh --test NewFeatureTests/testNewBehavior
   ```

2. **Implement Feature**
   - Write minimal code to make test pass

3. **Verify Test Passes**
   ```bash
   ./scripts/run-unit-tests.sh --test NewFeatureTests/testNewBehavior
   ```

4. **Refactor and Re-test**
   ```bash
   ./scripts/run-unit-tests.sh --test NewFeatureTests
   ```

### Before Committing Code

```bash
# Complete pre-commit test suite
./scripts/run-all-tests.sh --coverage --continue-on-fail

# Check coverage meets threshold
./scripts/generate-coverage-report.sh --threshold 80

# Format results for review
./scripts/format-test-results.sh -i test-results -f html
```

## Getting Help

### Debug Information

When reporting issues, include:

1. **System Information**
   ```bash
   sw_vers  # macOS version
   xcodebuild -version  # Xcode version
   xcrun simctl list devices  # Available simulators
   ```

2. **Test Output**
   ```bash
   ./scripts/run-unit-tests.sh --verbose > test-output.log 2>&1
   ```

3. **Environment Variables**
   ```bash
   env | grep -E "(UI_TESTING|MOCK_|TEST_)"
   ```

### Common Commands Reference

```bash
# Quick test run
./scripts/run-unit-tests.sh

# Full test suite with coverage
./scripts/run-all-tests.sh --coverage

# Debug specific test
./scripts/run-unit-tests.sh --test FailingTest --verbose

# Generate coverage report
./scripts/generate-coverage-report.sh

# Format test results
./scripts/format-test-results.sh -i test-results -f html

# Reset environment
xcrun simctl erase all
rm -rf test-results/
```

This guide should help you successfully run and debug tests in your local development environment. For more advanced topics, refer to the [Test Maintenance Guide](TEST_MAINTENANCE_GUIDE.md).