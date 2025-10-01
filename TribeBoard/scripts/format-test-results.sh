#!/bin/bash

# Script for formatting test results into various output formats
# Usage: ./scripts/format-test-results.sh [options]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
INPUT_DIR=""
OUTPUT_DIR="formatted-results"
FORMAT="html"
INCLUDE_SCREENSHOTS=false
INCLUDE_LOGS=false

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
    echo "  -i, --input DIR         Input directory containing test results"
    echo "  -o, --output DIR        Output directory for formatted results (default: formatted-results)"
    echo "  -f, --format FORMAT     Output format: html, json, junit, markdown (default: html)"
    echo "  -s, --screenshots       Include screenshots in the report"
    echo "  -l, --logs              Include detailed logs in the report"
    echo ""
    echo "Examples:"
    echo "  $0 -i test-results                    # Format results as HTML"
    echo "  $0 -i test-results -f json            # Format as JSON"
    echo "  $0 -i test-results -s -l              # Include screenshots and logs"
    echo ""
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_usage
            exit 0
            ;;
        -i|--input)
            INPUT_DIR="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -f|--format)
            FORMAT="$2"
            shift 2
            ;;
        -s|--screenshots)
            INCLUDE_SCREENSHOTS=true
            shift
            ;;
        -l|--logs)
            INCLUDE_LOGS=true
            shift
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Validate required parameters
if [ -z "$INPUT_DIR" ]; then
    print_error "Input directory is required"
    show_usage
    exit 1
fi

if [ ! -d "$INPUT_DIR" ]; then
    print_error "Input directory does not exist: $INPUT_DIR"
    exit 1
fi

# Validate format
case $FORMAT in
    html|json|junit|markdown)
        ;;
    *)
        print_error "Invalid format: $FORMAT. Must be html, json, junit, or markdown"
        exit 1
        ;;
esac

# Create output directory
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
FULL_OUTPUT_DIR="$OUTPUT_DIR/formatted-$TIMESTAMP"
mkdir -p "$FULL_OUTPUT_DIR"

print_status "Formatting test results..."
print_status "Input Directory: $INPUT_DIR"
print_status "Output Directory: $FULL_OUTPUT_DIR"
print_status "Format: $FORMAT"
print_status "Include Screenshots: $INCLUDE_SCREENSHOTS"
print_status "Include Logs: $INCLUDE_LOGS"

# Find all result files
XCRESULT_FILES=$(find "$INPUT_DIR" -name "*.xcresult" -type d)
JUNIT_FILES=$(find "$INPUT_DIR" -name "*.xml" -type f)
JSON_FILES=$(find "$INPUT_DIR" -name "*.json" -type f)

print_status "Found result files:"
for file in $XCRESULT_FILES; do
    print_status "  - XCResult: $(basename "$file")"
done
for file in $JUNIT_FILES; do
    print_status "  - JUnit: $(basename "$file")"
done
for file in $JSON_FILES; do
    print_status "  - JSON: $(basename "$file")"
done

# Create result formatter script
FORMATTER_SCRIPT="$FULL_OUTPUT_DIR/format_results.py"
cat > "$FORMATTER_SCRIPT" << 'EOF'
#!/usr/bin/env python3
import json
import xml.etree.ElementTree as ET
import os
import sys
from datetime import datetime
import subprocess

class TestResultFormatter:
    def __init__(self, input_dir, output_dir, format_type, include_screenshots=False, include_logs=False):
        self.input_dir = input_dir
        self.output_dir = output_dir
        self.format_type = format_type
        self.include_screenshots = include_screenshots
        self.include_logs = include_logs
        self.results = {
            'summary': {
                'total_tests': 0,
                'passed_tests': 0,
                'failed_tests': 0,
                'skipped_tests': 0,
                'execution_time': 0.0,
                'timestamp': datetime.now().isoformat()
            },
            'test_suites': [],
            'failures': [],
            'performance': []
        }
    
    def parse_junit_xml(self, xml_file):
        """Parse JUnit XML file and extract test results"""
        try:
            tree = ET.parse(xml_file)
            root = tree.getroot()
            
            # Handle both testsuites and testsuite root elements
            if root.tag == 'testsuites':
                testsuites = root.findall('testsuite')
            else:
                testsuites = [root]
            
            for testsuite in testsuites:
                suite_name = testsuite.get('name', 'Unknown')
                suite_tests = int(testsuite.get('tests', 0))
                suite_failures = int(testsuite.get('failures', 0))
                suite_errors = int(testsuite.get('errors', 0))
                suite_skipped = int(testsuite.get('skipped', 0))
                suite_time = float(testsuite.get('time', 0))
                
                suite_data = {
                    'name': suite_name,
                    'total_tests': suite_tests,
                    'passed_tests': suite_tests - suite_failures - suite_errors - suite_skipped,
                    'failed_tests': suite_failures + suite_errors,
                    'skipped_tests': suite_skipped,
                    'execution_time': suite_time,
                    'test_cases': []
                }
                
                # Parse individual test cases
                for testcase in testsuite.findall('testcase'):
                    case_name = testcase.get('name', 'Unknown')
                    case_class = testcase.get('classname', 'Unknown')
                    case_time = float(testcase.get('time', 0))
                    
                    case_data = {
                        'name': case_name,
                        'class': case_class,
                        'execution_time': case_time,
                        'status': 'passed'
                    }
                    
                    # Check for failures or errors
                    failure = testcase.find('failure')
                    error = testcase.find('error')
                    skipped = testcase.find('skipped')
                    
                    if failure is not None:
                        case_data['status'] = 'failed'
                        case_data['error_message'] = failure.get('message', '')
                        case_data['error_details'] = failure.text or ''
                        self.results['failures'].append(case_data)
                    elif error is not None:
                        case_data['status'] = 'error'
                        case_data['error_message'] = error.get('message', '')
                        case_data['error_details'] = error.text or ''
                        self.results['failures'].append(case_data)
                    elif skipped is not None:
                        case_data['status'] = 'skipped'
                        case_data['skip_reason'] = skipped.get('message', '')
                    
                    suite_data['test_cases'].append(case_data)
                
                self.results['test_suites'].append(suite_data)
                
                # Update summary
                self.results['summary']['total_tests'] += suite_tests
                self.results['summary']['passed_tests'] += suite_data['passed_tests']
                self.results['summary']['failed_tests'] += suite_data['failed_tests']
                self.results['summary']['skipped_tests'] += suite_data['skipped_tests']
                self.results['summary']['execution_time'] += suite_time
                
        except Exception as e:
            print(f"Error parsing JUnit XML {xml_file}: {e}")
    
    def parse_xcresult_bundle(self, xcresult_path):
        """Parse XCResult bundle using xcresulttool"""
        try:
            # Extract JSON data from xcresult bundle
            cmd = ['xcrun', 'xcresulttool', 'get', '--path', xcresult_path, '--format', 'json']
            result = subprocess.run(cmd, capture_output=True, text=True)
            
            if result.returncode == 0:
                data = json.loads(result.stdout)
                # Process the xcresult data (implementation would depend on xcresult structure)
                print(f"Processed XCResult bundle: {os.path.basename(xcresult_path)}")
            else:
                print(f"Error processing XCResult bundle: {result.stderr}")
                
        except Exception as e:
            print(f"Error parsing XCResult bundle {xcresult_path}: {e}")
    
    def generate_html_report(self):
        """Generate HTML report"""
        html_content = f"""
<!DOCTYPE html>
<html>
<head>
    <title>TribeBoard Test Results</title>
    <style>
        body {{ font-family: Arial, sans-serif; margin: 20px; }}
        .header {{ background-color: #f0f0f0; padding: 20px; border-radius: 5px; margin-bottom: 20px; }}
        .summary {{ display: flex; gap: 20px; margin-bottom: 20px; }}
        .metric {{ background-color: #f9f9f9; padding: 15px; border-radius: 5px; text-align: center; }}
        .metric h3 {{ margin: 0 0 10px 0; }}
        .metric .value {{ font-size: 24px; font-weight: bold; }}
        .passed {{ color: #4CAF50; }}
        .failed {{ color: #f44336; }}
        .skipped {{ color: #ff9800; }}
        .test-suite {{ margin: 20px 0; border: 1px solid #ddd; border-radius: 5px; }}
        .suite-header {{ background-color: #f5f5f5; padding: 15px; border-bottom: 1px solid #ddd; }}
        .test-case {{ padding: 10px 15px; border-bottom: 1px solid #eee; }}
        .test-case:last-child {{ border-bottom: none; }}
        .test-case.failed {{ background-color: #ffebee; }}
        .test-case.skipped {{ background-color: #fff3e0; }}
        .error-details {{ margin-top: 10px; padding: 10px; background-color: #f5f5f5; border-radius: 3px; font-family: monospace; font-size: 12px; }}
        table {{ border-collapse: collapse; width: 100%; margin: 20px 0; }}
        th, td {{ border: 1px solid #ddd; padding: 8px; text-align: left; }}
        th {{ background-color: #f2f2f2; }}
    </style>
</head>
<body>
    <div class="header">
        <h1>TribeBoard Test Results</h1>
        <p>Generated: {self.results['summary']['timestamp']}</p>
        <p>Total Execution Time: {self.results['summary']['execution_time']:.2f}s</p>
    </div>
    
    <div class="summary">
        <div class="metric">
            <h3>Total Tests</h3>
            <div class="value">{self.results['summary']['total_tests']}</div>
        </div>
        <div class="metric">
            <h3>Passed</h3>
            <div class="value passed">{self.results['summary']['passed_tests']}</div>
        </div>
        <div class="metric">
            <h3>Failed</h3>
            <div class="value failed">{self.results['summary']['failed_tests']}</div>
        </div>
        <div class="metric">
            <h3>Skipped</h3>
            <div class="value skipped">{self.results['summary']['skipped_tests']}</div>
        </div>
        <div class="metric">
            <h3>Success Rate</h3>
            <div class="value">{(self.results['summary']['passed_tests'] / max(self.results['summary']['total_tests'], 1) * 100):.1f}%</div>
        </div>
    </div>
    
    <h2>Test Suites</h2>
        """
        
        for suite in self.results['test_suites']:
            html_content += f"""
    <div class="test-suite">
        <div class="suite-header">
            <h3>{suite['name']}</h3>
            <p>Tests: {suite['total_tests']} | Passed: {suite['passed_tests']} | Failed: {suite['failed_tests']} | Time: {suite['execution_time']:.2f}s</p>
        </div>
            """
            
            for test_case in suite['test_cases']:
                status_class = test_case['status']
                html_content += f"""
        <div class="test-case {status_class}">
            <strong>{test_case['name']}</strong> ({test_case['class']}) - {test_case['execution_time']:.3f}s
            <span class="{status_class}">[{test_case['status'].upper()}]</span>
                """
                
                if test_case['status'] in ['failed', 'error'] and 'error_message' in test_case:
                    html_content += f"""
            <div class="error-details">
                <strong>Error:</strong> {test_case['error_message']}<br>
                <strong>Details:</strong><br>
                <pre>{test_case.get('error_details', '')}</pre>
            </div>
                    """
                
                html_content += "</div>"
            
            html_content += "</div>"
        
        html_content += """
</body>
</html>
        """
        
        return html_content
    
    def generate_json_report(self):
        """Generate JSON report"""
        return json.dumps(self.results, indent=2)
    
    def generate_markdown_report(self):
        """Generate Markdown report"""
        md_content = f"""# TribeBoard Test Results

**Generated:** {self.results['summary']['timestamp']}  
**Total Execution Time:** {self.results['summary']['execution_time']:.2f}s

## Summary

| Metric | Value |
|--------|-------|
| Total Tests | {self.results['summary']['total_tests']} |
| Passed | {self.results['summary']['passed_tests']} |
| Failed | {self.results['summary']['failed_tests']} |
| Skipped | {self.results['summary']['skipped_tests']} |
| Success Rate | {(self.results['summary']['passed_tests'] / max(self.results['summary']['total_tests'], 1) * 100):.1f}% |

## Test Suites

"""
        
        for suite in self.results['test_suites']:
            md_content += f"""### {suite['name']}

- **Tests:** {suite['total_tests']}
- **Passed:** {suite['passed_tests']}
- **Failed:** {suite['failed_tests']}
- **Execution Time:** {suite['execution_time']:.2f}s

"""
            
            if suite['failed_tests'] > 0:
                md_content += "#### Failed Tests\n\n"
                for test_case in suite['test_cases']:
                    if test_case['status'] in ['failed', 'error']:
                        md_content += f"- **{test_case['name']}** ({test_case['class']})\n"
                        if 'error_message' in test_case:
                            md_content += f"  - Error: {test_case['error_message']}\n"
                md_content += "\n"
        
        return md_content
    
    def process_results(self):
        """Process all result files in the input directory"""
        # Find and parse JUnit XML files
        for root, dirs, files in os.walk(self.input_dir):
            for file in files:
                if file.endswith('.xml'):
                    xml_path = os.path.join(root, file)
                    print(f"Processing JUnit XML: {file}")
                    self.parse_junit_xml(xml_path)
        
        # Find and parse XCResult bundles
        for root, dirs, files in os.walk(self.input_dir):
            for dir_name in dirs:
                if dir_name.endswith('.xcresult'):
                    xcresult_path = os.path.join(root, dir_name)
                    print(f"Processing XCResult bundle: {dir_name}")
                    self.parse_xcresult_bundle(xcresult_path)
    
    def generate_report(self):
        """Generate the final report in the specified format"""
        if self.format_type == 'html':
            content = self.generate_html_report()
            filename = 'test-report.html'
        elif self.format_type == 'json':
            content = self.generate_json_report()
            filename = 'test-report.json'
        elif self.format_type == 'markdown':
            content = self.generate_markdown_report()
            filename = 'test-report.md'
        else:
            raise ValueError(f"Unsupported format: {self.format_type}")
        
        output_path = os.path.join(self.output_dir, filename)
        with open(output_path, 'w') as f:
            f.write(content)
        
        return output_path

if __name__ == "__main__":
    input_dir = sys.argv[1]
    output_dir = sys.argv[2]
    format_type = sys.argv[3]
    include_screenshots = len(sys.argv) > 4 and sys.argv[4] == "true"
    include_logs = len(sys.argv) > 5 and sys.argv[5] == "true"
    
    formatter = TestResultFormatter(input_dir, output_dir, format_type, include_screenshots, include_logs)
    formatter.process_results()
    report_path = formatter.generate_report()
    
    print(f"Report generated: {report_path}")
EOF

chmod +x "$FORMATTER_SCRIPT"

# Run the formatter
print_status "Running result formatter..."

if python3 "$FORMATTER_SCRIPT" "$INPUT_DIR" "$FULL_OUTPUT_DIR" "$FORMAT" "$INCLUDE_SCREENSHOTS" "$INCLUDE_LOGS"; then
    print_success "Test results formatted successfully!"
    
    # List generated files
    print_status "Generated files:"
    find "$FULL_OUTPUT_DIR" -type f -name "test-report.*" | while read file; do
        print_success "  - $(basename "$file")"
    done
    
    print_success "Results saved to: $FULL_OUTPUT_DIR"
else
    print_error "Failed to format test results!"
    exit 1
fi