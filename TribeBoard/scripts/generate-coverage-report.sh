#!/bin/bash

# Script for generating comprehensive test coverage reports
# Usage: ./scripts/generate-coverage-report.sh [options]

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
OUTPUT_DIR="coverage-reports"
THRESHOLD=80
FORMAT="html"
INCLUDE_TESTS=false

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
    echo "  -o, --output DIR        Output directory for coverage reports (default: coverage-reports)"
    echo "  -t, --threshold NUM     Coverage threshold percentage (default: 80)"
    echo "  -f, --format FORMAT     Report format: html, json, text (default: html)"
    echo "  -i, --include-tests     Include test files in coverage analysis"
    echo "  -d, --destination DEST  Test destination (default: iPhone 15 simulator)"
    echo ""
    echo "Examples:"
    echo "  $0                              # Generate HTML coverage report"
    echo "  $0 --format json --threshold 90 # Generate JSON report with 90% threshold"
    echo "  $0 --include-tests              # Include test files in analysis"
    echo ""
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_usage
            exit 0
            ;;
        -o|--output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -t|--threshold)
            THRESHOLD="$2"
            shift 2
            ;;
        -f|--format)
            FORMAT="$2"
            shift 2
            ;;
        -i|--include-tests)
            INCLUDE_TESTS=true
            shift
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

# Validate format
case $FORMAT in
    html|json|text)
        ;;
    *)
        print_error "Invalid format: $FORMAT. Must be html, json, or text"
        exit 1
        ;;
esac

# Create output directory with timestamp
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
FULL_OUTPUT_DIR="$OUTPUT_DIR/coverage-$TIMESTAMP"
mkdir -p "$FULL_OUTPUT_DIR"

print_status "Generating coverage report..."
print_status "Output Directory: $FULL_OUTPUT_DIR"
print_status "Coverage Threshold: $THRESHOLD%"
print_status "Report Format: $FORMAT"
print_status "Include Tests: $INCLUDE_TESTS"

# Run tests with coverage enabled
print_status "Running tests with coverage enabled..."

RESULT_BUNDLE_PATH="$FULL_OUTPUT_DIR/coverage-test-results.xcresult"

XCODEBUILD_CMD="xcodebuild test"
XCODEBUILD_CMD="$XCODEBUILD_CMD -scheme $SCHEME"
XCODEBUILD_CMD="$XCODEBUILD_CMD -destination '$DESTINATION'"
XCODEBUILD_CMD="$XCODEBUILD_CMD -enableCodeCoverage YES"
XCODEBUILD_CMD="$XCODEBUILD_CMD -resultBundlePath '$RESULT_BUNDLE_PATH'"

if ! eval $XCODEBUILD_CMD > /dev/null 2>&1; then
    print_warning "Some tests failed, but continuing with coverage analysis..."
fi

# Generate coverage reports
print_status "Extracting coverage data..."

# Generate JSON report
JSON_REPORT="$FULL_OUTPUT_DIR/coverage-report.json"
xcrun xccov view --report --json "$RESULT_BUNDLE_PATH" > "$JSON_REPORT"

# Generate text report
TEXT_REPORT="$FULL_OUTPUT_DIR/coverage-report.txt"
xcrun xccov view --report "$RESULT_BUNDLE_PATH" > "$TEXT_REPORT"

# Generate detailed file-by-file coverage
DETAILED_REPORT="$FULL_OUTPUT_DIR/coverage-detailed.txt"
xcrun xccov view --file-list "$RESULT_BUNDLE_PATH" > "$DETAILED_REPORT"

print_success "Coverage reports generated!"

# Parse coverage data and generate analysis
print_status "Analyzing coverage data..."

# Create coverage analysis script
ANALYSIS_SCRIPT="$FULL_OUTPUT_DIR/analyze_coverage.py"
cat > "$ANALYSIS_SCRIPT" << 'EOF'
#!/usr/bin/env python3
import json
import sys
import os

def analyze_coverage(json_file, threshold, include_tests=False):
    with open(json_file, 'r') as f:
        data = json.load(f)
    
    # Extract overall coverage
    overall_coverage = data.get('lineCoverage', 0) * 100
    
    print(f"Overall Line Coverage: {overall_coverage:.2f}%")
    print(f"Coverage Threshold: {threshold}%")
    print(f"Status: {'PASS' if overall_coverage >= threshold else 'FAIL'}")
    print()
    
    # Analyze by target
    targets = data.get('targets', [])
    
    print("Coverage by Target:")
    print("-" * 50)
    
    for target in targets:
        target_name = target.get('name', 'Unknown')
        target_coverage = target.get('lineCoverage', 0) * 100
        
        # Skip test targets unless explicitly included
        if not include_tests and 'Test' in target_name:
            continue
            
        status = "PASS" if target_coverage >= threshold else "FAIL"
        print(f"{target_name:<30} {target_coverage:>6.2f}% [{status}]")
    
    print()
    
    # Find files with low coverage
    print("Files with Coverage Below Threshold:")
    print("-" * 50)
    
    low_coverage_files = []
    
    for target in targets:
        if not include_tests and 'Test' in target.get('name', ''):
            continue
            
        files = target.get('files', [])
        for file_info in files:
            file_path = file_info.get('path', '')
            file_coverage = file_info.get('lineCoverage', 0) * 100
            
            if file_coverage < threshold:
                low_coverage_files.append((file_path, file_coverage))
    
    if low_coverage_files:
        low_coverage_files.sort(key=lambda x: x[1])  # Sort by coverage
        for file_path, coverage in low_coverage_files:
            filename = os.path.basename(file_path)
            print(f"{filename:<40} {coverage:>6.2f}%")
    else:
        print("All files meet the coverage threshold!")
    
    print()
    
    # Summary statistics
    all_files = []
    for target in targets:
        if not include_tests and 'Test' in target.get('name', ''):
            continue
        files = target.get('files', [])
        for file_info in files:
            coverage = file_info.get('lineCoverage', 0) * 100
            all_files.append(coverage)
    
    if all_files:
        avg_coverage = sum(all_files) / len(all_files)
        min_coverage = min(all_files)
        max_coverage = max(all_files)
        
        print("Coverage Statistics:")
        print("-" * 50)
        print(f"Average Coverage: {avg_coverage:.2f}%")
        print(f"Minimum Coverage: {min_coverage:.2f}%")
        print(f"Maximum Coverage: {max_coverage:.2f}%")
        print(f"Files Analyzed: {len(all_files)}")
        print(f"Files Below Threshold: {len(low_coverage_files)}")
    
    return overall_coverage >= threshold

if __name__ == "__main__":
    json_file = sys.argv[1]
    threshold = float(sys.argv[2])
    include_tests = len(sys.argv) > 3 and sys.argv[3] == "true"
    
    success = analyze_coverage(json_file, threshold, include_tests)
    sys.exit(0 if success else 1)
EOF

chmod +x "$ANALYSIS_SCRIPT"

# Run coverage analysis
ANALYSIS_REPORT="$FULL_OUTPUT_DIR/coverage-analysis.txt"
if python3 "$ANALYSIS_SCRIPT" "$JSON_REPORT" "$THRESHOLD" "$INCLUDE_TESTS" > "$ANALYSIS_REPORT"; then
    COVERAGE_STATUS="PASS"
else
    COVERAGE_STATUS="FAIL"
fi

# Display analysis results
print_status "Coverage Analysis Results:"
cat "$ANALYSIS_REPORT"

# Generate HTML report if requested
if [ "$FORMAT" = "html" ]; then
    print_status "Generating HTML report..."
    
    HTML_REPORT="$FULL_OUTPUT_DIR/coverage-report.html"
    
    cat > "$HTML_REPORT" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>TribeBoard Coverage Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background-color: #f0f0f0; padding: 20px; border-radius: 5px; }
        .pass { color: green; font-weight: bold; }
        .fail { color: red; font-weight: bold; }
        .warning { color: orange; font-weight: bold; }
        .section { margin: 20px 0; }
        .coverage-bar { 
            width: 200px; 
            height: 20px; 
            background-color: #f0f0f0; 
            border-radius: 10px; 
            overflow: hidden;
            display: inline-block;
            vertical-align: middle;
        }
        .coverage-fill { 
            height: 100%; 
            background-color: #4CAF50; 
            transition: width 0.3s ease;
        }
        .coverage-fill.low { background-color: #f44336; }
        .coverage-fill.medium { background-color: #ff9800; }
        pre { background-color: #f5f5f5; padding: 15px; border-radius: 5px; overflow-x: auto; }
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
    </style>
</head>
<body>
    <div class="header">
        <h1>TribeBoard Test Coverage Report</h1>
        <p>Generated: $(date)</p>
        <p>Threshold: $THRESHOLD%</p>
        <p>Status: <span class="$([ "$COVERAGE_STATUS" = "PASS" ] && echo "pass" || echo "fail")">$COVERAGE_STATUS</span></p>
    </div>
    
    <div class="section">
        <h2>Coverage Analysis</h2>
        <pre>$(cat "$ANALYSIS_REPORT")</pre>
    </div>
    
    <div class="section">
        <h2>Detailed Coverage Report</h2>
        <pre>$(cat "$TEXT_REPORT")</pre>
    </div>
</body>
</html>
EOF
    
    print_success "HTML report generated: $HTML_REPORT"
fi

# Create summary file
SUMMARY_FILE="$FULL_OUTPUT_DIR/coverage-summary.json"
cat > "$SUMMARY_FILE" << EOF
{
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "threshold": $THRESHOLD,
    "status": "$COVERAGE_STATUS",
    "format": "$FORMAT",
    "include_tests": $INCLUDE_TESTS,
    "reports": {
        "json": "$(basename "$JSON_REPORT")",
        "text": "$(basename "$TEXT_REPORT")",
        "detailed": "$(basename "$DETAILED_REPORT")",
        "analysis": "$(basename "$ANALYSIS_REPORT")"
    }
}
EOF

print_success "Coverage analysis complete!"
print_success "Reports saved to: $FULL_OUTPUT_DIR"
print_success "Summary: $SUMMARY_FILE"

if [ "$COVERAGE_STATUS" = "PASS" ]; then
    print_success "Coverage threshold met!"
    exit 0
else
    print_error "Coverage threshold not met!"
    exit 1
fi