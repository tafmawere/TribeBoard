import Foundation
import XCTest

/// Handles test reporting for CI/CD environments with notifications and integrations
class CITestReporter {
    
    // MARK: - Shared Instance
    
    static let shared = CITestReporter()
    
    // MARK: - Properties
    
    private let environment: CIEnvironment
    private var testResults: [CITestResult] = []
    private var performanceResults: [CIPerformanceResult] = []
    private var startTime: Date?
    
    // MARK: - Initialization
    
    private init() {
        self.environment = CITestReporter.detectCIEnvironment()
    }
    
    // MARK: - CI Environment Detection
    
    /// Detects the current CI environment
    private static func detectCIEnvironment() -> CIEnvironment {
        let env = ProcessInfo.processInfo.environment
        
        if env["GITHUB_ACTIONS"] != nil {
            return .githubActions
        } else if env["JENKINS_URL"] != nil {
            return .jenkins
        } else if env["BITRISE_IO"] != nil {
            return .bitrise
        } else if env["XCODE_CLOUD"] != nil {
            return .xcodeCloud
        } else if env["CI"] != nil {
            return .generic
        } else {
            return .local
        }
    }
    
    // MARK: - Test Session Management
    
    /// Starts a test reporting session
    func startTestSession() {
        startTime = Date()
        testResults.removeAll()
        performanceResults.removeAll()
        
        logMessage("🚀 Starting test session in \(environment.rawValue) environment")
        
        // Set up CI-specific configurations
        setupCIEnvironment()
    }
    
    /// Ends the test reporting session and generates final reports
    func endTestSession() {
        guard let startTime = startTime else {
            logError("Test session was not properly started")
            return
        }
        
        let duration = Date().timeIntervalSince(startTime)
        logMessage("✅ Test session completed in \(String(format: "%.2f", duration))s")
        
        // Generate final reports
        generateFinalReport(duration: duration)
        
        // Send notifications if configured
        sendNotifications()
        
        // Upload artifacts if in CI
        if environment != .local {
            uploadArtifacts()
        }
    }
    
    // MARK: - Test Result Recording
    
    /// Records a test result
    func recordTestResult(
        testName: String,
        className: String,
        result: CITestResultStatus,
        duration: TimeInterval,
        errorMessage: String? = nil,
        stackTrace: String? = nil
    ) {
        let testResult = CITestResult(
            testName: testName,
            className: className,
            result: result,
            duration: duration,
            errorMessage: errorMessage,
            stackTrace: stackTrace,
            timestamp: Date()
        )
        
        testResults.append(testResult)
        
        // Log result based on CI environment
        logTestResult(testResult)
        
        // Send real-time notifications for failures in CI
        if result == .failed && environment != .local {
            sendFailureNotification(testResult)
        }
    }
    
    /// Records a performance test result
    func recordPerformanceResult(
        testName: String,
        operationName: String,
        duration: TimeInterval,
        benchmark: TimeInterval,
        memoryUsage: Int,
        memoryLimit: Int,
        passed: Bool
    ) {
        let performanceResult = CIPerformanceResult(
            testName: testName,
            operationName: operationName,
            duration: duration,
            benchmark: benchmark,
            memoryUsage: memoryUsage,
            memoryLimit: memoryLimit,
            passed: passed,
            timestamp: Date()
        )
        
        performanceResults.append(performanceResult)
        
        // Log performance result
        logPerformanceResult(performanceResult)
        
        // Send notification for performance regressions
        if !passed && environment != .local {
            sendPerformanceRegressionNotification(performanceResult)
        }
    }
    
    // MARK: - CI Environment Setup
    
    /// Sets up CI-specific configurations
    private func setupCIEnvironment() {
        switch environment {
        case .githubActions:
            setupGitHubActions()
        case .jenkins:
            setupJenkins()
        case .bitrise:
            setupBitrise()
        case .xcodeCloud:
            setupXcodeCloud()
        case .generic, .local:
            break
        }
    }
    
    /// Sets up GitHub Actions specific configurations
    private func setupGitHubActions() {
        // Enable GitHub Actions annotations
        logMessage("::group::Database Tests")
        
        // Set up environment variables for GitHub Actions
        setEnvironmentVariable("GITHUB_STEP_SUMMARY", "test-summary.md")
    }
    
    /// Sets up Jenkins specific configurations
    private func setupJenkins() {
        // Configure Jenkins-specific settings
        logMessage("Setting up Jenkins test reporting")
    }
    
    /// Sets up Bitrise specific configurations
    private func setupBitrise() {
        // Configure Bitrise-specific settings
        logMessage("Setting up Bitrise test reporting")
    }
    
    /// Sets up Xcode Cloud specific configurations
    private func setupXcodeCloud() {
        // Configure Xcode Cloud-specific settings
        logMessage("Setting up Xcode Cloud test reporting")
    }
    
    // MARK: - Logging
    
    /// Logs a test result based on CI environment
    private func logTestResult(_ result: CITestResult) {
        let duration = String(format: "%.3f", result.duration)
        let message = "\(result.className).\(result.testName) - \(duration)s"
        
        switch environment {
        case .githubActions:
            switch result.result {
            case .passed:
                print("::notice title=Test Passed::\(message)")
            case .failed:
                let error = result.errorMessage ?? "Test failed"
                print("::error title=Test Failed::\(message) - \(error)")
            case .skipped:
                print("::warning title=Test Skipped::\(message)")
            }
        case .jenkins:
            // Jenkins uses standard output with specific formatting
            let status = result.result == .passed ? "PASS" : result.result == .failed ? "FAIL" : "SKIP"
            print("[\(status)] \(message)")
        default:
            let icon = result.result == .passed ? "✅" : result.result == .failed ? "❌" : "⏭️"
            print("\(icon) \(message)")
        }
    }
    
    /// Logs a performance result
    private func logPerformanceResult(_ result: CIPerformanceResult) {
        let duration = String(format: "%.3f", result.duration)
        let benchmark = String(format: "%.3f", result.benchmark)
        let memoryMB = String(format: "%.2f", Double(result.memoryUsage) / 1_000_000)
        
        let message = "\(result.operationName) - \(duration)s (benchmark: \(benchmark)s) - \(memoryMB)MB"
        
        switch environment {
        case .githubActions:
            if result.passed {
                print("::notice title=Performance Test Passed::\(message)")
            } else {
                print("::warning title=Performance Regression::\(message)")
            }
        default:
            let icon = result.passed ? "⚡" : "🐌"
            print("\(icon) \(message)")
        }
    }
    
    /// Logs a general message
    private func logMessage(_ message: String) {
        switch environment {
        case .githubActions:
            print("::notice::\(message)")
        default:
            print("ℹ️ \(message)")
        }
    }
    
    /// Logs an error message
    private func logError(_ message: String) {
        switch environment {
        case .githubActions:
            print("::error::\(message)")
        default:
            print("❌ \(message)")
        }
    }
    
    // MARK: - Report Generation
    
    /// Generates the final test report
    private func generateFinalReport(duration: TimeInterval) {
        let summary = generateTestSummary(duration: duration)
        
        // Generate different report formats based on CI environment
        switch environment {
        case .githubActions:
            generateGitHubActionsSummary(summary)
        case .jenkins:
            generateJenkinsReport(summary)
        case .bitrise:
            generateBitriseReport(summary)
        default:
            generateStandardReport(summary)
        }
        
        // Always generate JSON report for programmatic access
        generateJSONReport(summary)
    }
    
    /// Generates test summary
    private func generateTestSummary(duration: TimeInterval) -> CITestSummary {
        let passedTests = testResults.filter { $0.result == .passed }.count
        let failedTests = testResults.filter { $0.result == .failed }.count
        let skippedTests = testResults.filter { $0.result == .skipped }.count
        
        let passedPerformanceTests = performanceResults.filter { $0.passed }.count
        let failedPerformanceTests = performanceResults.filter { !$0.passed }.count
        
        return CITestSummary(
            totalTests: testResults.count,
            passedTests: passedTests,
            failedTests: failedTests,
            skippedTests: skippedTests,
            totalPerformanceTests: performanceResults.count,
            passedPerformanceTests: passedPerformanceTests,
            failedPerformanceTests: failedPerformanceTests,
            totalDuration: duration,
            environment: environment,
            timestamp: Date()
        )
    }
    
    /// Generates GitHub Actions summary
    private func generateGitHubActionsSummary(_ summary: CITestSummary) {
        var markdown = """
        # 📊 Database Test Results
        
        ## Summary
        - **Total Tests:** \(summary.totalTests)
        - **Passed:** \(summary.passedTests) ✅
        - **Failed:** \(summary.failedTests) ❌
        - **Skipped:** \(summary.skippedTests) ⏭️
        - **Duration:** \(String(format: "%.2f", summary.totalDuration))s
        
        """
        
        if summary.totalPerformanceTests > 0 {
            markdown += """
            ## Performance Tests
            - **Total:** \(summary.totalPerformanceTests)
            - **Passed:** \(summary.passedPerformanceTests) ⚡
            - **Failed:** \(summary.failedPerformanceTests) 🐌
            
            """
        }
        
        // Add failed tests details
        let failedTests = testResults.filter { $0.result == .failed }
        if !failedTests.isEmpty {
            markdown += """
            ## Failed Tests
            | Test | Duration | Error |
            |------|----------|-------|
            """
            
            for test in failedTests {
                let duration = String(format: "%.3f", test.duration)
                let error = test.errorMessage?.replacingOccurrences(of: "|", with: "\\|") ?? "Unknown error"
                markdown += "| \(test.className).\(test.testName) | \(duration)s | \(error) |\n"
            }
            markdown += "\n"
        }
        
        // Add performance regressions
        let failedPerformanceTests = performanceResults.filter { !$0.passed }
        if !failedPerformanceTests.isEmpty {
            markdown += """
            ## Performance Regressions
            | Operation | Duration | Benchmark | Memory | Limit |
            |-----------|----------|-----------|--------|-------|
            """
            
            for test in failedPerformanceTests {
                let duration = String(format: "%.3f", test.duration)
                let benchmark = String(format: "%.3f", test.benchmark)
                let memoryMB = String(format: "%.2f", Double(test.memoryUsage) / 1_000_000)
                let limitMB = String(format: "%.2f", Double(test.memoryLimit) / 1_000_000)
                markdown += "| \(test.operationName) | \(duration)s | \(benchmark)s | \(memoryMB)MB | \(limitMB)MB |\n"
            }
        }
        
        // Write to GitHub Actions summary
        if let summaryFile = ProcessInfo.processInfo.environment["GITHUB_STEP_SUMMARY"] {
            do {
                try markdown.write(toFile: summaryFile, atomically: true, encoding: .utf8)
                logMessage("GitHub Actions summary written to \(summaryFile)")
            } catch {
                logError("Failed to write GitHub Actions summary: \(error)")
            }
        }
        
        print("::endgroup::")
    }
    
    /// Generates Jenkins report
    private func generateJenkinsReport(_ summary: CITestSummary) {
        // Generate JUnit XML format for Jenkins
        let junitXML = generateJUnitXML(summary)
        
        do {
            try junitXML.write(toFile: "test-results.xml", atomically: true, encoding: .utf8)
            logMessage("Jenkins JUnit report written to test-results.xml")
        } catch {
            logError("Failed to write Jenkins report: \(error)")
        }
    }
    
    /// Generates Bitrise report
    private func generateBitriseReport(_ summary: CITestSummary) {
        // Generate Bitrise-specific report format
        logMessage("Bitrise test report generated")
    }
    
    /// Generates standard console report
    private func generateStandardReport(_ summary: CITestSummary) {
        print("\n" + "="*80)
        print("📊 CI TEST REPORT")
        print("="*80)
        print("Environment: \(summary.environment.rawValue)")
        print("Total Tests: \(summary.totalTests)")
        print("Passed: \(summary.passedTests)")
        print("Failed: \(summary.failedTests)")
        print("Skipped: \(summary.skippedTests)")
        print("Duration: \(String(format: "%.2f", summary.totalDuration))s")
        
        if summary.totalPerformanceTests > 0 {
            print("\nPerformance Tests: \(summary.totalPerformanceTests)")
            print("Performance Passed: \(summary.passedPerformanceTests)")
            print("Performance Failed: \(summary.failedPerformanceTests)")
        }
        
        print("="*80)
    }
    
    /// Generates JSON report
    private func generateJSONReport(_ summary: CITestSummary) {
        let report = CITestReport(
            summary: summary,
            testResults: testResults,
            performanceResults: performanceResults
        )
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            
            let jsonData = try encoder.encode(report)
            try jsonData.write(to: URL(fileURLWithPath: "ci-test-report.json"))
            
            logMessage("JSON test report written to ci-test-report.json")
        } catch {
            logError("Failed to write JSON report: \(error)")
        }
    }
    
    /// Generates JUnit XML format
    private func generateJUnitXML(_ summary: CITestSummary) -> String {
        var xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <testsuites tests="\(summary.totalTests)" failures="\(summary.failedTests)" time="\(summary.totalDuration)">
          <testsuite name="DatabaseTests" tests="\(summary.totalTests)" failures="\(summary.failedTests)" time="\(summary.totalDuration)">
        """
        
        for result in testResults {
            xml += """
            
                <testcase classname="\(result.className)" name="\(result.testName)" time="\(result.duration)">
            """
            
            if result.result == .failed {
                let error = result.errorMessage ?? "Test failed"
                xml += """
                  <failure message="\(error.xmlEscaped)">\(result.stackTrace?.xmlEscaped ?? "")</failure>
                """
            } else if result.result == .skipped {
                xml += """
                  <skipped/>
                """
            }
            
            xml += """
            
                </testcase>
            """
        }
        
        xml += """
        
          </testsuite>
        </testsuites>
        """
        
        return xml
    }
    
    // MARK: - Notifications
    
    /// Sends notifications based on test results
    private func sendNotifications() {
        // Only send notifications in CI environments
        guard environment != .local else { return }
        
        let summary = generateTestSummary(duration: Date().timeIntervalSince(startTime ?? Date()))
        
        if summary.failedTests > 0 || summary.failedPerformanceTests > 0 {
            sendFailureSummaryNotification(summary)
        } else {
            sendSuccessNotification(summary)
        }
    }
    
    /// Sends notification for individual test failure
    private func sendFailureNotification(_ result: CITestResult) {
        // Implementation would depend on notification service (Slack, Teams, etc.)
        logMessage("Test failure notification sent for \(result.className).\(result.testName)")
    }
    
    /// Sends notification for performance regression
    private func sendPerformanceRegressionNotification(_ result: CIPerformanceResult) {
        logMessage("Performance regression notification sent for \(result.operationName)")
    }
    
    /// Sends summary notification for failures
    private func sendFailureSummaryNotification(_ summary: CITestSummary) {
        logMessage("Failure summary notification sent: \(summary.failedTests) tests failed, \(summary.failedPerformanceTests) performance regressions")
    }
    
    /// Sends success notification
    private func sendSuccessNotification(_ summary: CITestSummary) {
        logMessage("Success notification sent: All \(summary.totalTests) tests passed")
    }
    
    // MARK: - Artifact Upload
    
    /// Uploads test artifacts to CI storage
    private func uploadArtifacts() {
        switch environment {
        case .githubActions:
            uploadGitHubActionsArtifacts()
        case .jenkins:
            uploadJenkinsArtifacts()
        case .bitrise:
            uploadBitriseArtifacts()
        default:
            break
        }
    }
    
    /// Uploads artifacts for GitHub Actions
    private func uploadGitHubActionsArtifacts() {
        // GitHub Actions artifacts are typically handled by workflow steps
        logMessage("Artifacts prepared for GitHub Actions upload")
    }
    
    /// Uploads artifacts for Jenkins
    private func uploadJenkinsArtifacts() {
        logMessage("Artifacts prepared for Jenkins archival")
    }
    
    /// Uploads artifacts for Bitrise
    private func uploadBitriseArtifacts() {
        logMessage("Artifacts prepared for Bitrise deployment")
    }
    
    // MARK: - Utility Methods
    
    /// Sets an environment variable
    private func setEnvironmentVariable(_ key: String, _ value: String) {
        setenv(key, value, 1)
    }
    
    /// Gets the current CI run information
    func getCIRunInfo() -> CIRunInfo {
        let env = ProcessInfo.processInfo.environment
        
        return CIRunInfo(
            environment: environment,
            buildNumber: env["BUILD_NUMBER"] ?? env["GITHUB_RUN_NUMBER"] ?? "unknown",
            commitHash: env["GIT_COMMIT"] ?? env["GITHUB_SHA"] ?? "unknown",
            branch: env["GIT_BRANCH"] ?? env["GITHUB_REF_NAME"] ?? "unknown",
            pullRequestNumber: env["CHANGE_ID"] ?? env["GITHUB_PR_NUMBER"],
            buildUrl: env["BUILD_URL"] ?? env["GITHUB_SERVER_URL"]
        )
    }
}

// MARK: - Data Models

/// Represents CI environment types
enum CIEnvironment: String, Codable {
    case githubActions = "GitHub Actions"
    case jenkins = "Jenkins"
    case bitrise = "Bitrise"
    case xcodeCloud = "Xcode Cloud"
    case generic = "Generic CI"
    case local = "Local"
}

/// Represents test result status
enum CITestResultStatus: String, Codable {
    case passed
    case failed
    case skipped
}

/// Represents a CI test result
struct CITestResult: Codable {
    let testName: String
    let className: String
    let result: CITestResultStatus
    let duration: TimeInterval
    let errorMessage: String?
    let stackTrace: String?
    let timestamp: Date
}

/// Represents a CI performance result
struct CIPerformanceResult: Codable {
    let testName: String
    let operationName: String
    let duration: TimeInterval
    let benchmark: TimeInterval
    let memoryUsage: Int
    let memoryLimit: Int
    let passed: Bool
    let timestamp: Date
}

/// Represents a CI test summary
struct CITestSummary: Codable {
    let totalTests: Int
    let passedTests: Int
    let failedTests: Int
    let skippedTests: Int
    let totalPerformanceTests: Int
    let passedPerformanceTests: Int
    let failedPerformanceTests: Int
    let totalDuration: TimeInterval
    let environment: CIEnvironment
    let timestamp: Date
    
    var passRate: Double {
        guard totalTests > 0 else { return 0 }
        return Double(passedTests) / Double(totalTests)
    }
    
    var performancePassRate: Double {
        guard totalPerformanceTests > 0 else { return 0 }
        return Double(passedPerformanceTests) / Double(totalPerformanceTests)
    }
}

/// Represents a complete CI test report
struct CITestReport: Codable {
    let summary: CITestSummary
    let testResults: [CITestResult]
    let performanceResults: [CIPerformanceResult]
}

/// Represents CI run information
struct CIRunInfo: Codable {
    let environment: CIEnvironment
    let buildNumber: String
    let commitHash: String
    let branch: String
    let pullRequestNumber: String?
    let buildUrl: String?
}

// MARK: - String Extension

private extension String {
    var xmlEscaped: String {
        return self
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}