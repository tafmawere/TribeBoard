import Foundation
import XCTest

/// Utility for analyzing and formatting test results
class TestResultAnalyzer {
    
    // MARK: - Test Result Analysis
    
    /// Analyzes test execution results and generates a comprehensive report
    static func analyzeTestResults(from resultBundle: URL) -> TestAnalysisResult {
        var analysisResult = TestAnalysisResult()
        
        // This would typically parse the xcresult bundle
        // For now, we'll provide a framework for analysis
        
        analysisResult.timestamp = Date()
        analysisResult.resultBundlePath = resultBundle.path
        
        return analysisResult
    }
    
    /// Extracts failure information from test results
    static func extractFailures(from resultBundle: URL) -> [TestFailure] {
        var failures: [TestFailure] = []
        
        // This would parse the xcresult bundle for failure information
        // Implementation would use xcresulttool or similar
        
        return failures
    }
    
    /// Generates a summary of test performance metrics
    static func generatePerformanceMetrics(from resultBundle: URL) -> TestPerformanceMetrics {
        var metrics = TestPerformanceMetrics()
        
        // Extract performance data from result bundle
        metrics.totalExecutionTime = 0.0
        metrics.averageTestTime = 0.0
        metrics.slowestTests = []
        metrics.fastestTests = []
        
        return metrics
    }
    
    // MARK: - Report Generation
    
    /// Generates a formatted test report
    static func generateTestReport(analysisResult: TestAnalysisResult) -> String {
        var report = """
        TribeBoard Test Execution Report
        ================================
        
        Execution Time: \(analysisResult.timestamp)
        Result Bundle: \(analysisResult.resultBundlePath)
        
        Summary:
        --------
        Total Tests: \(analysisResult.totalTests)
        Passed: \(analysisResult.passedTests)
        Failed: \(analysisResult.failedTests)
        Skipped: \(analysisResult.skippedTests)
        Success Rate: \(String(format: "%.2f", analysisResult.successRate))%
        
        """
        
        if !analysisResult.failures.isEmpty {
            report += """
            
            Failures:
            ---------
            """
            
            for (index, failure) in analysisResult.failures.enumerated() {
                report += """
                
                \(index + 1). \(failure.testName)
                   Class: \(failure.testClass)
                   Error: \(failure.errorMessage)
                   File: \(failure.fileName):\(failure.lineNumber)
                """
            }
        }
        
        if !analysisResult.performanceMetrics.slowestTests.isEmpty {
            report += """
            
            Performance:
            ------------
            Total Execution Time: \(String(format: "%.2f", analysisResult.performanceMetrics.totalExecutionTime))s
            Average Test Time: \(String(format: "%.2f", analysisResult.performanceMetrics.averageTestTime))s
            
            Slowest Tests:
            """
            
            for slowTest in analysisResult.performanceMetrics.slowestTests.prefix(5) {
                report += """
                
                - \(slowTest.testName): \(String(format: "%.2f", slowTest.executionTime))s
                """
            }
        }
        
        return report
    }
    
    /// Generates a JSON report for programmatic consumption
    static func generateJSONReport(analysisResult: TestAnalysisResult) -> Data? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        return try? encoder.encode(analysisResult)
    }
    
    /// Generates an HTML report for web viewing
    static func generateHTMLReport(analysisResult: TestAnalysisResult) -> String {
        let successRate = analysisResult.successRate
        let statusClass = successRate >= 90 ? "success" : (successRate >= 70 ? "warning" : "failure")
        
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <title>TribeBoard Test Report</title>
            <style>
                body { font-family: Arial, sans-serif; margin: 20px; }
                .header { background-color: #f0f0f0; padding: 20px; border-radius: 5px; }
                .success { color: green; font-weight: bold; }
                .warning { color: orange; font-weight: bold; }
                .failure { color: red; font-weight: bold; }
                .metric { display: inline-block; margin: 10px; padding: 15px; background-color: #f9f9f9; border-radius: 5px; }
                .failure-item { margin: 10px 0; padding: 10px; background-color: #ffe6e6; border-left: 4px solid #ff0000; }
                table { border-collapse: collapse; width: 100%; margin: 20px 0; }
                th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
                th { background-color: #f2f2f2; }
            </style>
        </head>
        <body>
            <div class="header">
                <h1>TribeBoard Test Execution Report</h1>
                <p>Generated: \(analysisResult.timestamp)</p>
                <p>Status: <span class="\(statusClass)">\(successRate >= 90 ? "EXCELLENT" : (successRate >= 70 ? "GOOD" : "NEEDS IMPROVEMENT"))</span></p>
            </div>
            
            <div class="metrics">
                <div class="metric">
                    <h3>Total Tests</h3>
                    <p>\(analysisResult.totalTests)</p>
                </div>
                <div class="metric">
                    <h3>Passed</h3>
                    <p class="success">\(analysisResult.passedTests)</p>
                </div>
                <div class="metric">
                    <h3>Failed</h3>
                    <p class="failure">\(analysisResult.failedTests)</p>
                </div>
                <div class="metric">
                    <h3>Success Rate</h3>
                    <p class="\(statusClass)">\(String(format: "%.2f", successRate))%</p>
                </div>
            </div>
            
            \(analysisResult.failures.isEmpty ? "" : generateFailuresHTML(analysisResult.failures))
            
            \(analysisResult.performanceMetrics.slowestTests.isEmpty ? "" : generatePerformanceHTML(analysisResult.performanceMetrics))
        </body>
        </html>
        """
    }
    
    private static func generateFailuresHTML(_ failures: [TestFailure]) -> String {
        var html = """
        <h2>Test Failures</h2>
        """
        
        for failure in failures {
            html += """
            <div class="failure-item">
                <h4>\(failure.testName)</h4>
                <p><strong>Class:</strong> \(failure.testClass)</p>
                <p><strong>Error:</strong> \(failure.errorMessage)</p>
                <p><strong>Location:</strong> \(failure.fileName):\(failure.lineNumber)</p>
            </div>
            """
        }
        
        return html
    }
    
    private static func generatePerformanceHTML(_ metrics: TestPerformanceMetrics) -> String {
        var html = """
        <h2>Performance Metrics</h2>
        <p><strong>Total Execution Time:</strong> \(String(format: "%.2f", metrics.totalExecutionTime))s</p>
        <p><strong>Average Test Time:</strong> \(String(format: "%.2f", metrics.averageTestTime))s</p>
        """
        
        if !metrics.slowestTests.isEmpty {
            html += """
            <h3>Slowest Tests</h3>
            <table>
                <tr><th>Test Name</th><th>Execution Time</th></tr>
            """
            
            for test in metrics.slowestTests.prefix(10) {
                html += """
                <tr>
                    <td>\(test.testName)</td>
                    <td>\(String(format: "%.2f", test.executionTime))s</td>
                </tr>
                """
            }
            
            html += "</table>"
        }
        
        return html
    }
    
    // MARK: - Failure Analysis
    
    /// Categorizes test failures by type
    static func categorizeFailures(_ failures: [TestFailure]) -> [FailureCategory: [TestFailure]] {
        var categorized: [FailureCategory: [TestFailure]] = [:]
        
        for failure in failures {
            let category = determineFailureCategory(failure)
            if categorized[category] == nil {
                categorized[category] = []
            }
            categorized[category]?.append(failure)
        }
        
        return categorized
    }
    
    private static func determineFailureCategory(_ failure: TestFailure) -> FailureCategory {
        let errorMessage = failure.errorMessage.lowercased()
        
        if errorMessage.contains("timeout") || errorMessage.contains("wait") {
            return .timeout
        } else if errorMessage.contains("assertion") || errorMessage.contains("expected") {
            return .assertion
        } else if errorMessage.contains("network") || errorMessage.contains("connection") {
            return .network
        } else if errorMessage.contains("ui") || errorMessage.contains("element") {
            return .ui
        } else if errorMessage.contains("auth") || errorMessage.contains("credential") {
            return .authentication
        } else {
            return .other
        }
    }
    
    /// Generates recommendations based on failure analysis
    static func generateRecommendations(from failures: [TestFailure]) -> [String] {
        let categorized = categorizeFailures(failures)
        var recommendations: [String] = []
        
        if let timeoutFailures = categorized[.timeout], !timeoutFailures.isEmpty {
            recommendations.append("Consider increasing timeout values for \(timeoutFailures.count) timeout-related failures")
        }
        
        if let assertionFailures = categorized[.assertion], !assertionFailures.isEmpty {
            recommendations.append("Review test assertions and expected values for \(assertionFailures.count) assertion failures")
        }
        
        if let networkFailures = categorized[.network], !networkFailures.isEmpty {
            recommendations.append("Check network connectivity and mock service configuration for \(networkFailures.count) network failures")
        }
        
        if let uiFailures = categorized[.ui], !uiFailures.isEmpty {
            recommendations.append("Verify UI element accessibility and timing for \(uiFailures.count) UI failures")
        }
        
        if let authFailures = categorized[.authentication], !authFailures.isEmpty {
            recommendations.append("Review authentication mock setup and credentials for \(authFailures.count) auth failures")
        }
        
        return recommendations
    }
}

// MARK: - Supporting Types

/// Complete test analysis result
struct TestAnalysisResult: Codable {
    var timestamp: Date = Date()
    var resultBundlePath: String = ""
    var totalTests: Int = 0
    var passedTests: Int = 0
    var failedTests: Int = 0
    var skippedTests: Int = 0
    var failures: [TestFailure] = []
    var performanceMetrics: TestPerformanceMetrics = TestPerformanceMetrics()
    
    var successRate: Double {
        guard totalTests > 0 else { return 0.0 }
        return (Double(passedTests) / Double(totalTests)) * 100.0
    }
}

/// Individual test failure information
struct TestFailure: Codable {
    let testName: String
    let testClass: String
    let errorMessage: String
    let fileName: String
    let lineNumber: Int
    let timestamp: Date
    
    init(testName: String, testClass: String, errorMessage: String, fileName: String = "", lineNumber: Int = 0) {
        self.testName = testName
        self.testClass = testClass
        self.errorMessage = errorMessage
        self.fileName = fileName
        self.lineNumber = lineNumber
        self.timestamp = Date()
    }
}

/// Performance metrics for test execution
struct TestPerformanceMetrics: Codable {
    var totalExecutionTime: TimeInterval = 0.0
    var averageTestTime: TimeInterval = 0.0
    var slowestTests: [TestPerformanceData] = []
    var fastestTests: [TestPerformanceData] = []
}

/// Individual test performance data
struct TestPerformanceData: Codable {
    let testName: String
    let testClass: String
    let executionTime: TimeInterval
    
    init(testName: String, testClass: String, executionTime: TimeInterval) {
        self.testName = testName
        self.testClass = testClass
        self.executionTime = executionTime
    }
}

/// Categories for failure analysis
enum FailureCategory: String, CaseIterable, Codable {
    case timeout = "Timeout"
    case assertion = "Assertion"
    case network = "Network"
    case ui = "UI"
    case authentication = "Authentication"
    case other = "Other"
}

/// Test execution context for analysis
struct TestExecutionContext {
    let testSuite: String
    let testClass: String
    let testMethod: String
    let startTime: Date
    let endTime: Date
    let result: TestResult
    let errorMessage: String?
    
    var executionTime: TimeInterval {
        return endTime.timeIntervalSince(startTime)
    }
}

/// Test result enumeration
enum TestResult: String, Codable {
    case passed = "Passed"
    case failed = "Failed"
    case skipped = "Skipped"
}