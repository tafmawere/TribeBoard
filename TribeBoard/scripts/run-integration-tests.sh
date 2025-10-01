#!/bin/bash

# Script for running integration tests independently
# Usage: ./scripts/run-integration-tests.sh [options]

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
OUTPUT_DIR="test-results"
SPECIFIC_TEST=""

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
    echo "  -o, --output DIR        Output directory for test results (default: test-results)"
    echo "  -t, --test TEST_NAME    Run specific test class or method"
    echo "  -d, --destination DEST  Test destination (default: iPhone 15 simulator)"
    echo ""
    echo "Examples:"
    echo "  $0                                              # Run all integration tests"
    echo "  $0 --coverage                                   # Run with coverage report"
    echo "  $0 --test AuthenticationIntegrationTests       # Run specific test class"
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
        -o|--output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -t|--test)
            SPECIFIC_TEST="$2"
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

# Create output directory
mkdir -p "$OUTPUT_DIR"

print_status "Starting integration test execution..."
print_status "Scheme: $SCHEME"
print_status "Destination: $DESTINATION"
print_status "Output Directory: $OUTPUT_DIR"

if [ "$COVERAGE" = true ]; then
    print_status "Code coverage: Enabled"
fi

if [ -n "$SPECIFIC_TEST" ]; then
    print_status "Running specific test: $SPECIFIC_TEST"
fi

# Build the xcodebuild command for integration tests
XCODEBUILD_CMD="xcodebuild test"
XCODEBUILD_CMD="$XCODEBUILD_CMD -scheme $SCHEME"
XCODEBUILD_CMD="$XCODEBUILD_CMD -destination '$DESTINATION'"
XCODEBUILD_CMD="$XCODEBUILD_CMD -only-testing:TribeBoardTests/Integration"

# Add specific test if provided
if [ -n "$SPECIFIC_TEST" ]; then
    XCODEBUILD_CMD="$XCODEBUILD_CMD -only-testing:TribeBoardTests/Integration/$SPECIFIC_TEST"
fi

# Add coverage if requested
if [ "$COVERAGE" = true ]; then
    XCODEBUILD_CMD="$XCODEBUILD_CMD -enableCodeCoverage YES"
fi

# Add result bundle path
RESULT_BUNDLE_PATH="$OUTPUT_DIR/integration-tests-$(date +%Y%m%d-%H%M%S).xcresult"
XCODEBUILD_CMD="$XCODEBUILD_CMD -resultBundlePath '$RESULT_BUNDLE_PATH'"

# Add verbose output if requested
if [ "$VERBOSE" = true ]; then
    XCODEBUILD_CMD="$XCODEBUILD_CMD | xcpretty --report junit --output '$OUTPUT_DIR/integration-tests-report.xml'"
else
    XCODEBUILD_CMD="$XCODEBUILD_CMD | xcpretty --report junit --output '$OUTPUT_DIR/integration-tests-report.xml' --quiet"
fi

print_status "Executing: $XCODEBUILD_CMD"

# Execute the command
if eval $XCODEBUILD_CMD; then
    print_success "Integration tests completed successfully!"
    
    # Generate coverage report if requested
    if [ "$COVERAGE" = true ]; then
        print_status "Generating coverage report..."
        
        # Extract coverage data
        xcrun xccov view --report --json "$RESULT_BUNDLE_PATH" > "$OUTPUT_DIR/integration-coverage-report.json"
        
        # Generate human-readable coverage report
        xcrun xccov view --report "$RESULT_BUNDLE_PATH" > "$OUTPUT_DIR/integration-coverage-report.txt"
        
        print_success "Coverage report generated at $OUTPUT_DIR/integration-coverage-report.txt"
    fi
    
    print_success "Test results saved to: $RESULT_BUNDLE_PATH"
    print_success "JUnit report saved to: $OUTPUT_DIR/integration-tests-report.xml"
    
else
    print_error "Integration tests failed!"
    exit 1
fi