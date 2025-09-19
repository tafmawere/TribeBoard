import XCTest
import Foundation

/// Test observer that integrates with the database testing reporting system
class DatabaseTestObserver: NSObject, XCTestObservation {
    
    // MARK: - Properties
    
    private var testSuiteStartTime: Date?
    private var currentTestStartTime: Date?
    private var failedTests: Set<String> = []
    
    // MARK: - XCTestObservation Protocol
    
    func testBundleWillStart(_ testBundle: Bundle) {
        print("🚀 Database Test Bundle Starting...")
        
        // Initialize reporting systems
        TestMetricsCollector.shared.startTestSuite(name: "Database Tests")
        CITestReporter.shared.startTestSession()
        
        // Reset coverage analyzer
        TestCoverageAnalyzer.shared.reset()
    }
    
    func testBundleDidFinish(_ testBundle: Bundle) {
        print("🏁 Database Test Bundle Finished")
        
        // Generate final reports
        TestMetricsCollector.shared.endTestSuite(name: "Database Tests")
        CITestReporter.shared.endTestSession()
        
        // Generate coverage report
        TestCoverageAnalyzer.shared.printCoverageReport()
        TestCoverageAnalyzer.shared.saveCoverageReport()
        
        print("📊 All database test reports generated")
    }
    
    func testSuiteWillStart(_ testSuite: XCTestSuite) {
        if testSuite.name.contains("Database") {
            testSuiteStartTime = Date()
            print("📋 Database Test Suite Starting: \(testSuite.name)")
        }
    }
    
    func testSuiteDidFinish(_ testSuite: XCTestSuite) {
        if testSuite.name.contains("Database") {
            let duration = testSuiteStartTime.map { Date().timeIntervalSince($0) } ?? 0
            print("📋 Database Test Suite Finished: \(testSuite.name) (\(String(format: "%.2f", duration))s)")
        }
    }
    
    func testCaseWillStart(_ testCase: XCTestCase) {
        currentTestStartTime = Date()
        
        if isDatabaseTest(testCase) {
            let testName = extractTestName(from: testCase)
            let className = String(describing: type(of: testCase))
            print("🧪 Starting: \(className).\(testName)")
        }
    }
    
    func testCaseDidFinish(_ testCase: XCTestCase) {
        guard let startTime = currentTestStartTime else { return }
        
        if isDatabaseTest(testCase) {
            let duration = Date().timeIntervalSince(startTime)
            let testName = extractTestName(from: testCase)
            let className = String(describing: type(of: testCase))
            
            // Determine test result
            let result: CITestResultStatus = failedTests.contains(testCase.name) ? .failed : .passed
            
            // Update metrics with actual result
            updateTestResult(
                testName: testName,
                className: className,
                result: result,
                duration: duration
            )
            
            let resultIcon = result == .passed ? "✅" : "❌"
            print("\(resultIcon) Finished: \(className).\(testName) (\(String(format: "%.3f", duration))s)")
        }
        
        currentTestStartTime = nil
    }
    
    func testCase(_ testCase: XCTestCase, didFailWithDescription description: String, inFile filePath: String?, atLine lineNumber: Int) {
        if isDatabaseTest(testCase) {
            failedTests.insert(testCase.name)
            
            let testName = extractTestName(from: testCase)
            let className = String(describing: type(of: testCase))
            
            print("❌ Test Failed: \(className).\(testName)")
            print("   Error: \(description)")
            print("   File: \(filePath ?? "unknown"):\(lineNumber)")
            
            // Record failure details
            recordTestFailure(
                testName: testName,
                className: className,
                description: description,
                filePath: filePath,
                lineNumber: lineNumber
            )
        }
    }
    
    func testCase(_ testCase: XCTestCase, didRecord issue: XCTIssue) {
        if isDatabaseTest(testCase) && issue.type == .assertionFailure {
            let testName = extractTestName(from: testCase)
            let className = String(describing: type(of: testCase))
            
            print("⚠️ Test Issue: \(className).\(testName)")
            print("   Issue: \(issue.compactDescription)")
            
            if let location = issue.sourceCodeContext.location {
                print("   Location: \(location.filePath):\(location.lineNumber)")
            }
        }
    }
    
    // MARK: - Helper Methods
    
    /// Checks if a test case is a database test
    private func isDatabaseTest(_ testCase: XCTestCase) -> Bool {
        let className = String(describing: type(of: testCase))
        return className.contains("Database") || 
               className.contains("Model") ||
               className.contains("DataService") ||
               className.contains("CloudKit") ||
               className.contains("Performance") ||
               className.contains("Integration") ||
               className.contains("Relationship") ||
               className.contains("Constraint") ||
               className.contains("Migration")
    }
    
    /// Extracts the test method name from a test case
    private func extractTestName(from testCase: XCTestCase) -> String {
        return testCase.name.components(separatedBy: " ").last?.replacingOccurrences(of: "]", with: "") ?? "unknown"
    }
    
    /// Updates test result in reporting systems
    private func updateTestResult(
        testName: String,
        className: String,
        result: CITestResultStatus,
        duration: TimeInterval
    ) {
        // Update metrics collector
        let metricsResult: TestResult = result == .passed ? .passed : .failed
        
        // Find and update existing metric
        let currentMetrics = TestMetricsCollector.shared.getCurrentMetrics()
        if let existingMetric = currentMetrics.first(where: { $0.testName == testName && $0.className == className }) {
            // Remove old metric and add updated one
            TestMetricsCollector.shared.clearMetrics()
            
            // Re-add all metrics except the one we're updating
            for metric in currentMetrics where !(metric.testName == testName && metric.className == className) {
                TestMetricsCollector.shared.recordTestMetric(
                    testName: metric.testName,
                    className: metric.className,
                    duration: metric.duration,
                    result: metric.result,
                    memoryUsage: metric.memoryUsage,
                    errorMessage: metric.errorMessage
                )
            }
            
            // Add updated metric
            TestMetricsCollector.shared.recordTestMetric(
                testName: testName,
                className: className,
                duration: duration,
                result: metricsResult,
                memoryUsage: existingMetric.memoryUsage,
                errorMessage: result == .failed ? "Test failed" : nil
            )
        }
        
        // Update CI reporter
        CITestReporter.shared.recordTestResult(
            testName: testName,
            className: className,
            result: result,
            duration: duration,
            errorMessage: result == .failed ? "Test failed" : nil
        )
    }
    
    /// Records detailed test failure information
    private func recordTestFailure(
        testName: String,
        className: String,
        description: String,
        filePath: String?,
        lineNumber: Int
    ) {
        // Create detailed error message
        var errorMessage = description
        if let filePath = filePath {
            errorMessage += " (at \(filePath):\(lineNumber))"
        }
        
        // Record in CI reporter with detailed error
        CITestReporter.shared.recordTestResult(
            testName: testName,
            className: className,
            result: .failed,
            duration: currentTestStartTime.map { Date().timeIntervalSince($0) } ?? 0,
            errorMessage: errorMessage,
            stackTrace: Thread.callStackSymbols.joined(separator: "\n")
        )
    }
}

// MARK: - Test Observer Registration

extension DatabaseTestObserver {
    
    /// Registers the database test observer
    static func register() {
        let observer = DatabaseTestObserver()
        XCTestObservationCenter.shared.addTestObserver(observer)
        print("📊 Database Test Observer registered")
    }
}

// MARK: - XCTIssue Extension

private extension XCTIssue {
    var compactDescription: String {
        return "\(type.rawValue): \(compactDescription)"
    }
}