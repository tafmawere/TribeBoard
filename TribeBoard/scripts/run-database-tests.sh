#!/bin/bash

# TribeBoard Database Testing Script
# This script runs the comprehensive database test suite with various configurations

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCHEME="TribeBoard"
DESTINATION="platform=iOS Simulator,name=iPhone 15"
RESULT_BUNDLE_PATH="TestResults"
COVERAGE_REPORT_PATH="CoverageReport"

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

# Function to run tests with specific filter
run_test_category() {
    local category=$1
    local description=$2
    
    print_status "Running $description..."
    
    xcodebuild test \
        -scheme "$SCHEME" \
        -destination "$DESTINATION" \
        -only-testing:"TribeBoardTests/Database/$category" \
        -resultBundlePath "${RESULT_BUNDLE_PATH}_${category}" \
        -enableCodeCoverage YES \
        -quiet
    
    if [ $? -eq 0 ]; then
        print_success "$description completed successfully"
    else
        print_error "$description failed"
        return 1
    fi
}

# Function to run performance tests with extended timeout
run_performance_tests() {
    print_status "Running Performance Tests (may take longer)..."
    
    xcodebuild test \
        -scheme "$SCHEME" \
        -destination "$DESTINATION" \
        -only-testing:"TribeBoardTests/Database/DatabasePerformanceTests" \
        -only-testing:"TribeBoardTests/Database/LoadTests" \
        -only-testing:"TribeBoardTests/Database/MemoryTests" \
        -resultBundlePath "${RESULT_BUNDLE_PATH}_Performance" \
        -enableCodeCoverage YES \
        -testTimeoutsEnabled YES \
        -defaultTestExecutionTimeAllowance 300 \
        -maximumTestExecutionTimeAllowance 600 \
        -quiet
    
    if [ $? -eq 0 ]; then
        print_success "Performance tests completed successfully"
    else
        print_error "Performance tests failed"
        return 1
    fi
}

# Function to generate coverage report
generate_coverage_report() {
    print_status "Generating code coverage report..."
    
    # Create coverage directory
    mkdir -p "$COVERAGE_REPORT_PATH"
    
    # Find the latest result bundle
    LATEST_RESULT=$(find . -name "TestResults*.xcresult" -type d | head -1)
    
    if [ -n "$LATEST_RESULT" ]; then
        xcrun xccov view --report --json "$LATEST_RESULT" > "${COVERAGE_REPORT_PATH}/coverage.json"
        xcrun xccov view --report "$LATEST_RESULT" > "${COVERAGE_REPORT_PATH}/coverage.txt"
        
        print_success "Coverage report generated in $COVERAGE_REPORT_PATH"
        
        # Extract and display coverage percentage
        COVERAGE_PERCENT=$(xcrun xccov view --report "$LATEST_RESULT" | grep -E "TribeBoard\.app" | awk '{print $NF}' | head -1)
        if [ -n "$COVERAGE_PERCENT" ]; then
            print_status "Overall coverage: $COVERAGE_PERCENT"
        fi
    else
        print_warning "No test results found for coverage report"
    fi
}

# Function to clean up old test results
cleanup_old_results() {
    print_status "Cleaning up old test results..."
    rm -rf TestResults*.xcresult
    rm -rf "$COVERAGE_REPORT_PATH"
    print_success "Cleanup completed"
}

# Function to display help
show_help() {
    echo "TribeBoard Database Testing Script"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --all                 Run all database tests (default)"
    echo "  --model               Run model validation tests only"
    echo "  --crud                Run CRUD operation tests only"
    echo "  --cloudkit            Run CloudKit synchronization tests only"
    echo "  --performance         Run performance tests only"
    echo "  --integration         Run integration tests only"
    echo "  --relationships       Run relationship tests only"
    echo "  --migration           Run schema migration tests only"
    echo "  --fast                Run fast tests only (excludes performance)"
    echo "  --coverage            Generate coverage report after tests"
    echo "  --clean               Clean up old test results before running"
    echo "  --help                Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                    # Run all tests"
    echo "  $0 --fast --coverage  # Run fast tests with coverage"
    echo "  $0 --performance      # Run only performance tests"
    echo "  $0 --clean --all      # Clean and run all tests"
}

# Parse command line arguments
RUN_ALL=true
RUN_MODEL=false
RUN_CRUD=false
RUN_CLOUDKIT=false
RUN_PERFORMANCE=false
RUN_INTEGRATION=false
RUN_RELATIONSHIPS=false
RUN_MIGRATION=false
RUN_FAST=false
GENERATE_COVERAGE=false
CLEAN_FIRST=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --all)
            RUN_ALL=true
            shift
            ;;
        --model)
            RUN_ALL=false
            RUN_MODEL=true
            shift
            ;;
        --crud)
            RUN_ALL=false
            RUN_CRUD=true
            shift
            ;;
        --cloudkit)
            RUN_ALL=false
            RUN_CLOUDKIT=true
            shift
            ;;
        --performance)
            RUN_ALL=false
            RUN_PERFORMANCE=true
            shift
            ;;
        --integration)
            RUN_ALL=false
            RUN_INTEGRATION=true
            shift
            ;;
        --relationships)
            RUN_ALL=false
            RUN_RELATIONSHIPS=true
            shift
            ;;
        --migration)
            RUN_ALL=false
            RUN_MIGRATION=true
            shift
            ;;
        --fast)
            RUN_ALL=false
            RUN_FAST=true
            shift
            ;;
        --coverage)
            GENERATE_COVERAGE=true
            shift
            ;;
        --clean)
            CLEAN_FIRST=true
            shift
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Main execution
print_status "Starting TribeBoard Database Tests"
print_status "Scheme: $SCHEME"
print_status "Destination: $DESTINATION"
echo ""

# Clean up if requested
if [ "$CLEAN_FIRST" = true ]; then
    cleanup_old_results
    echo ""
fi

# Check if Xcode is available
if ! command -v xcodebuild &> /dev/null; then
    print_error "xcodebuild not found. Please install Xcode."
    exit 1
fi

# Check if simulator is available
print_status "Checking simulator availability..."
xcrun simctl list devices | grep "iPhone 15" | grep "Booted\|Shutdown" > /dev/null
if [ $? -ne 0 ]; then
    print_warning "iPhone 15 simulator not found. Using default simulator."
    DESTINATION="platform=iOS Simulator"
fi

# Run tests based on options
TESTS_FAILED=false

if [ "$RUN_ALL" = true ] || [ "$RUN_FAST" = true ]; then
    # Run all tests or fast tests
    if [ "$RUN_FAST" = true ]; then
        print_status "Running fast tests (excluding performance tests)..."
        
        # Model validation tests
        run_test_category "ModelValidationTests" "Model Validation Tests" || TESTS_FAILED=true
        
        # Container and schema tests
        run_test_category "ContainerConfigurationTests" "Container Configuration Tests" || TESTS_FAILED=true
        run_test_category "SchemaValidationTests" "Schema Validation Tests" || TESTS_FAILED=true
        
        # Data service tests
        run_test_category "DataServiceCRUDTests" "Data Service CRUD Tests" || TESTS_FAILED=true
        run_test_category "DataServiceValidationTests" "Data Service Validation Tests" || TESTS_FAILED=true
        run_test_category "DataServiceConstraintTests" "Data Service Constraint Tests" || TESTS_FAILED=true
        run_test_category "DataServiceAdvancedTests" "Data Service Advanced Tests" || TESTS_FAILED=true
        
        # CloudKit tests
        run_test_category "CloudKitSyncTests" "CloudKit Sync Tests" || TESTS_FAILED=true
        run_test_category "CloudKitConflictResolutionTests" "CloudKit Conflict Resolution Tests" || TESTS_FAILED=true
        run_test_category "CloudKitErrorHandlingTests" "CloudKit Error Handling Tests" || TESTS_FAILED=true
        
        # Relationship and constraint tests
        run_test_category "RelationshipTests" "Relationship Tests" || TESTS_FAILED=true
        run_test_category "ConstraintTests" "Constraint Tests" || TESTS_FAILED=true
        
        # Integration tests
        run_test_category "EndToEndWorkflowTests" "End-to-End Workflow Tests" || TESTS_FAILED=true
        run_test_category "CrossServiceIntegrationTests" "Cross-Service Integration Tests" || TESTS_FAILED=true
        run_test_category "AppLaunchIntegrationTests" "App Launch Integration Tests" || TESTS_FAILED=true
        
        # Migration tests
        run_test_category "SchemaMigrationTests" "Schema Migration Tests" || TESTS_FAILED=true
        run_test_category "CloudKitSchemaMigrationTests" "CloudKit Schema Migration Tests" || TESTS_FAILED=true
        
    else
        # Run all tests including performance
        print_status "Running all database tests..."
        
        xcodebuild test \
            -scheme "$SCHEME" \
            -destination "$DESTINATION" \
            -only-testing:"TribeBoardTests/Database" \
            -resultBundlePath "$RESULT_BUNDLE_PATH" \
            -enableCodeCoverage YES \
            -testTimeoutsEnabled YES \
            -defaultTestExecutionTimeAllowance 300 \
            -maximumTestExecutionTimeAllowance 600 \
            -quiet
        
        if [ $? -eq 0 ]; then
            print_success "All database tests completed successfully"
        else
            print_error "Some database tests failed"
            TESTS_FAILED=true
        fi
    fi
else
    # Run specific test categories
    if [ "$RUN_MODEL" = true ]; then
        run_test_category "ModelValidationTests" "Model Validation Tests" || TESTS_FAILED=true
    fi
    
    if [ "$RUN_CRUD" = true ]; then
        run_test_category "DataServiceCRUDTests" "Data Service CRUD Tests" || TESTS_FAILED=true
        run_test_category "DataServiceValidationTests" "Data Service Validation Tests" || TESTS_FAILED=true
        run_test_category "DataServiceConstraintTests" "Data Service Constraint Tests" || TESTS_FAILED=true
        run_test_category "DataServiceAdvancedTests" "Data Service Advanced Tests" || TESTS_FAILED=true
    fi
    
    if [ "$RUN_CLOUDKIT" = true ]; then
        run_test_category "CloudKitSyncTests" "CloudKit Sync Tests" || TESTS_FAILED=true
        run_test_category "CloudKitConflictResolutionTests" "CloudKit Conflict Resolution Tests" || TESTS_FAILED=true
        run_test_category "CloudKitErrorHandlingTests" "CloudKit Error Handling Tests" || TESTS_FAILED=true
    fi
    
    if [ "$RUN_PERFORMANCE" = true ]; then
        run_performance_tests || TESTS_FAILED=true
    fi
    
    if [ "$RUN_INTEGRATION" = true ]; then
        run_test_category "EndToEndWorkflowTests" "End-to-End Workflow Tests" || TESTS_FAILED=true
        run_test_category "CrossServiceIntegrationTests" "Cross-Service Integration Tests" || TESTS_FAILED=true
        run_test_category "AppLaunchIntegrationTests" "App Launch Integration Tests" || TESTS_FAILED=true
    fi
    
    if [ "$RUN_RELATIONSHIPS" = true ]; then
        run_test_category "RelationshipTests" "Relationship Tests" || TESTS_FAILED=true
        run_test_category "ConstraintTests" "Constraint Tests" || TESTS_FAILED=true
    fi
    
    if [ "$RUN_MIGRATION" = true ]; then
        run_test_category "SchemaMigrationTests" "Schema Migration Tests" || TESTS_FAILED=true
        run_test_category "CloudKitSchemaMigrationTests" "CloudKit Schema Migration Tests" || TESTS_FAILED=true
    fi
fi

# Generate coverage report if requested
if [ "$GENERATE_COVERAGE" = true ]; then
    echo ""
    generate_coverage_report
fi

# Final status
echo ""
if [ "$TESTS_FAILED" = true ]; then
    print_error "Some tests failed. Check the output above for details."
    exit 1
else
    print_success "All requested tests passed successfully!"
    print_status "Test results saved in TestResults*.xcresult"
    if [ "$GENERATE_COVERAGE" = true ]; then
        print_status "Coverage report saved in $COVERAGE_REPORT_PATH"
    fi
fi