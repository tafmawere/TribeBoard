#!/bin/bash

# Script for running all test categories
# Usage: ./scripts/run-all-tests.sh [options]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
SCHEME="TribeBoard"
DESTINATION="platform=iOS Simulator,name=iPhone 15,OS=latest"
VERBOSE=false
COVERAGE=false
SCREENSHOTS=false
OUTPUT_DIR="test-results"
PARALLEL=false
CONTINUE_ON_FAILURE=false

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help              Show this help message"
    echo "  -v, --verbose           Enable verbose output"
    echo "  -c, --coverage          Generate code coverage report"
    echo "  -s, --screenshots       Capture screenshots on UI test failure"
    echo "  -p, --parallel          Run tests in parallel where possible"
    echo "  -f, --continue-on-fail  Continue running other test suites if one fails"
    echo "  -o, --output DIR        Output directory for test results (default: test-results)"
    echo "  -d, --destination DEST  Test destination (default: iPhone 15 simulator)"
    echo ""
    echo "Examples:"
    echo "  $0                      # Run all tests"
    echo "  $0 --coverage           # Run all tests with coverage"
    echo "  $0 --continue-on-fail   # Run all tests, don't stop on first failure"
    echo ""
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_usage
            exit 0
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -c|--coverage)
            COVERAGE=true
            shift
            ;;
        -s|--screenshots)
            SCREENSHOTS=true
            shift
            ;;
        -p|--parallel)
            PARALLEL=true
            shift
            ;;
        -f|--continue-on-fail)
            CONTINUE_ON_FAILURE=true
            shift
            ;;
        -o|--output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -d|--destination)
            DESTINATION="$2"
            shift 2
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Create output directory with timestamp
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
FULL_OUTPUT_DIR="$OUTPUT_DIR/all-tests-$TIMESTAMP"
mkdir -p "$FULL_OUTPUT_DIR"

print_status "Starting comprehensive test execution..."
print_status "Timestamp: $TIMESTAMP"
print_status "Output Directory: $FULL_OUTPUT_DIR"
print_status "Continue on failure: $CONTINUE_ON_FAILURE"

# Track test results
UNIT_TEST_RESULT=0
INTEGRATION_TEST_RESULT=0
UI_TEST_RESULT=0

# Build common arguments
COMMON_ARGS=""
if [ "$VERBOSE" = true ]; then
    COMMON_ARGS="$COMMON_ARGS --verbose"
fi
if [ "$COVERAGE" = true ]; then
    COMMON_ARGS="$COMMON_ARGS --coverage"
fi
COMMON_ARGS="$COMMON_ARGS --output $FULL_OUTPUT_DIR --destination '$DESTINATION'"

# Run Unit Tests
print_status "========================================="
print_status "Running Unit Tests"
print_status "========================================="

if ./scripts/run-unit-tests.sh $COMMON_ARGS; then
    print_success "Unit tests passed!"
    UNIT_TEST_RESULT=0
else
    print_error "Unit tests failed!"
    UNIT_TEST_RESULT=1
    if [ "$CONTINUE_ON_FAILURE" = false ]; then
        exit 1
    fi
fi

# Run Integration Tests
print_status "========================================="
print_status "Running Integration Tests"
print_status "========================================="

if ./scripts/run-integration-tests.sh $COMMON_ARGS; then
    print_success "Integration tests passed!"
    INTEGRATION_TEST_RESULT=0
else
    print_error "Integration tests failed!"
    INTEGRATION_TEST_RESULT=1
    if [ "$CONTINUE_ON_FAILURE" = false ]; then
        exit 1
    fi
fi

# Run UI Tests
print_status "========================================="
print_status "Running UI Tests"
print_status "========================================="

UI_ARGS="$COMMON_ARGS"
if [ "$SCREENSHOTS" = true ]; then
    UI_ARGS="$UI_ARGS --screenshots"
fi
if [ "$PARALLEL" = true ]; then
    UI_ARGS="$UI_ARGS --parallel"
fi

if ./scripts/run-ui-tests.sh $UI_ARGS; then
    print_success "UI tests passed!"
    UI_TEST_RESULT=0
else
    print_error "UI tests failed!"
    UI_TEST_RESULT=1
    if [ "$CONTINUE_ON_FAILURE" = false ]; then
        exit 1
    fi
fi

# Generate combined report
print_status "========================================="
print_status "Generating Combined Report"
print_status "========================================="

REPORT_FILE="$FULL_OUTPUT_DIR/test-summary-report.txt"

cat > "$REPORT_FILE" << EOF
TribeBoard Test Execution Summary
=================================

Execution Time: $(date)
Output Directory: $FULL_OUTPUT_DIR

Test Results:
-------------
Unit Tests:        $([ $UNIT_TEST_RESULT -eq 0 ] && echo "PASSED" || echo "FAILED")
Integration Tests: $([ $INTEGRATION_TEST_RESULT -eq 0 ] && echo "PASSED" || echo "FAILED")
UI Tests:          $([ $UI_TEST_RESULT -eq 0 ] && echo "PASSED" || echo "FAILED")

Configuration:
--------------
Scheme: $SCHEME
Destination: $DESTINATION
Coverage Enabled: $COVERAGE
Screenshots Enabled: $SCREENSHOTS
Parallel Execution: $PARALLEL
Continue on Failure: $CONTINUE_ON_FAILURE

Files Generated:
----------------
EOF

# List all generated files
find "$FULL_OUTPUT_DIR" -type f -name "*.xml" -o -name "*.json" -o -name "*.txt" -o -name "*.xcresult" | while read file; do
    echo "- $(basename "$file")" >> "$REPORT_FILE"
done

print_success "Test summary report generated: $REPORT_FILE"

# Calculate overall result
OVERALL_RESULT=$((UNIT_TEST_RESULT + INTEGRATION_TEST_RESULT + UI_TEST_RESULT))

if [ $OVERALL_RESULT -eq 0 ]; then
    print_success "========================================="
    print_success "ALL TESTS PASSED!"
    print_success "========================================="
    exit 0
else
    print_error "========================================="
    print_error "SOME TESTS FAILED!"
    print_error "Unit Tests: $([ $UNIT_TEST_RESULT -eq 0 ] && echo "PASSED" || echo "FAILED")"
    print_error "Integration Tests: $([ $INTEGRATION_TEST_RESULT -eq 0 ] && echo "PASSED" || echo "FAILED")"
    print_error "UI Tests: $([ $UI_TEST_RESULT -eq 0 ] && echo "PASSED" || echo "FAILED")"
    print_error "========================================="
    exit 1
fi