#!/bin/bash

# Script for running UI tests independently
# Usage: ./scripts/run-ui-tests.sh [options]

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
SCREENSHOTS=false
OUTPUT_DIR="test-results"
SPECIFIC_TEST=""
PARALLEL=false

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
    echo "  -s, --screenshots       Capture screenshots on failure"
    echo "  -p, --parallel          Run tests in parallel (if supported)"
    echo "  -o, --output DIR        Output directory for test results (default: test-results)"
    echo "  -t, --test TEST_NAME    Run specific test class or method"
    echo "  -d, --destination DEST  Test destination (default: iPhone 15 simulator)"
    echo ""
    echo "Examples:"
    echo "  $0                                        # Run all UI tests"
    echo "  $0 --screenshots                         # Run with screenshot capture"
    echo "  $0 --test SignInFlowUITests              # Run specific test class"
    echo "  $0 --test SignInFlowUITests/testSignIn   # Run specific test method"
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
        -s|--screenshots)
            SCREENSHOTS=true
            shift
            ;;
        -p|--parallel)
            PARALLEL=true
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

print_status "Starting UI test execution..."
print_status "Scheme: $SCHEME"
print_status "Destination: $DESTINATION"
print_status "Output Directory: $OUTPUT_DIR"

if [ "$SCREENSHOTS" = true ]; then
    print_status "Screenshot capture: Enabled"
fi

if [ "$PARALLEL" = true ]; then
    print_status "Parallel execution: Enabled"
fi

if [ -n "$SPECIFIC_TEST" ]; then
    print_status "Running specific test: $SPECIFIC_TEST"
fi

# Build the xcodebuild command
XCODEBUILD_CMD="xcodebuild test"
XCODEBUILD_CMD="$XCODEBUILD_CMD -scheme $SCHEME"
XCODEBUILD_CMD="$XCODEBUILD_CMD -destination '$DESTINATION'"
XCODEBUILD_CMD="$XCODEBUILD_CMD -only-testing:TribeBoardUITests"

# Add specific test if provided
if [ -n "$SPECIFIC_TEST" ]; then
    XCODEBUILD_CMD="$XCODEBUILD_CMD -only-testing:TribeBoardUITests/$SPECIFIC_TEST"
fi

# Add parallel execution if requested
if [ "$PARALLEL" = true ]; then
    XCODEBUILD_CMD="$XCODEBUILD_CMD -parallel-testing-enabled YES"
fi

# Add result bundle path
RESULT_BUNDLE_PATH="$OUTPUT_DIR/ui-tests-$(date +%Y%m%d-%H%M%S).xcresult"
XCODEBUILD_CMD="$XCODEBUILD_CMD -resultBundlePath '$RESULT_BUNDLE_PATH'"

# Add verbose output if requested
if [ "$VERBOSE" = true ]; then
    XCODEBUILD_CMD="$XCODEBUILD_CMD | xcpretty --report junit --output '$OUTPUT_DIR/ui-tests-report.xml'"
else
    XCODEBUILD_CMD="$XCODEBUILD_CMD | xcpretty --report junit --output '$OUTPUT_DIR/ui-tests-report.xml' --quiet"
fi

print_status "Executing: $XCODEBUILD_CMD"

# Execute the command
if eval $XCODEBUILD_CMD; then
    print_success "UI tests completed successfully!"
    
    # Extract screenshots if requested
    if [ "$SCREENSHOTS" = true ]; then
        print_status "Extracting screenshots..."
        
        SCREENSHOTS_DIR="$OUTPUT_DIR/screenshots"
        mkdir -p "$SCREENSHOTS_DIR"
        
        # Extract screenshots from result bundle
        xcrun xcresulttool get --path "$RESULT_BUNDLE_PATH" --format json > "$OUTPUT_DIR/test-results.json"
        
        print_success "Screenshots extracted to: $SCREENSHOTS_DIR"
    fi
    
    print_success "Test results saved to: $RESULT_BUNDLE_PATH"
    print_success "JUnit report saved to: $OUTPUT_DIR/ui-tests-report.xml"
    
else
    print_error "UI tests failed!"
    
    # Extract failure screenshots if available
    if [ "$SCREENSHOTS" = true ]; then
        print_status "Extracting failure screenshots..."
        
        SCREENSHOTS_DIR="$OUTPUT_DIR/failure-screenshots"
        mkdir -p "$SCREENSHOTS_DIR"
        
        # Extract failure information
        xcrun xcresulttool get --path "$RESULT_BUNDLE_PATH" --format json > "$OUTPUT_DIR/failure-results.json"
        
        print_status "Failure screenshots saved to: $SCREENSHOTS_DIR"
    fi
    
    exit 1
fi