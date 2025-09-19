import XCTest
import Foundation

/// Collects and reports test execution metrics for database tests
@MainActor
class TestMetricsCollector {
    
    // MARK: - Shared Instance
    
    static let shared = TestMetricsCollector()
    
    // MARK: - Properties
    
    private var testMetrics: [TestMetric] = []
    private var performanceMetrics: [PerformanceMetric] = []
    private var testSuiteStartTime: Date?
    private var testSuiteEndTime: Date?
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Test Suite Lifecycle
    
    /// Starts collecting metrics for a test suite
    func startTestSuite(name: String) {
        testSuiteStartTime = Date()
        testMetrics.removeAll()
        performanceMetrics.removeAll()
        
        print("📊 Starting metrics collection for test suite: \(name)")
    }
    
    /// Ends metrics collection for a test suite and generates report
    func endTestSuite(name: String) {
        testSuiteEndTime = Date()
        
        print("📊 Ending metrics collection for test suite: \(name)")
        generateTestReport(suiteName: name)
    }
    
    // MARK: - Test Metrics Collection
    
    /// Records metrics for a completed test
    func recordTestMetric(
        testName: String,
        className: String,
        duration: TimeInterval,
        result: TestResult,
        memoryUsage: Int? = nil,
        errorMessage: String? = nil
    ) {
        let metric = TestMetric(
            testName: testName,
            className: className,
            duration: duration,
            result: result,
            memoryUsage: memoryUsage,
            errorMessage: errorMessage,
            timestamp: Date()
        )
        
        testMetrics.append(metric)
        
        // Log test completion
        let resultIcon = result == .passed ? "✅" : "❌"
        let durationText = String(format: "%.3fs", duration)
        print("\(resultIcon) \(className).\(testName) - \(durationText)")
        
        if let error = errorMessage {
            print("   Error: \(error)")
        }
        
        if let memory = memoryUsage {
            let memoryMB = Double(memory) / 1_000_000
            print("   Memory: \(String(format: "%.2f", memoryMB))MB")
        }
    }
    
    /// Records performance metrics for a test
    func recordPerformanceMetric(
        testName: String,
        operationName: String,
        duration: TimeInterval,
        benchmark: TimeInterval,
        memoryUsage: Int,
        memoryLimit: Int,
        recordCount: Int = 1,
        passed: Bool
    ) {
        let metric = PerformanceMetric(
            testName: testName,
            operationName: operationName,
            duration: duration,
            benchmark: benchmark,
            memoryUsage: memoryUsage,
            memoryLimit: memoryLimit,
            recordCount: recordCount,
            passed: passed,
            timestamp: Date()
        )
        
        performanceMetrics.append(metric)
        
        // Log performance result
        let resultIcon = passed ? "⚡" : "🐌"
        let durationText = String(format: "%.3fs", duration)
        let benchmarkText = String(format: "%.3fs", benchmark)
        let memoryMB = Double(memoryUsage) / 1_000_000
        let memoryLimitMB = Double(memoryLimit) / 1_000_000
        
        print("\(resultIcon) \(operationName) - \(durationText) (benchmark: \(benchmarkText)) - \(String(format: "%.2f", memoryMB))MB (limit: \(String(format: "%.2f", memoryLimitMB))MB)")
        
        if !passed {
            if duration > benchmark {
                print("   ⚠️ Performance benchmark exceeded by \(String(format: "%.3f", duration - benchmark))s")
            }
            if memoryUsage > memoryLimit {
                let excess = Double(memoryUsage - memoryLimit) / 1_000_000
                print("   ⚠️ Memory limit exceeded by \(String(format: "%.2f", excess))MB")
            }
        }
    }
    
    // MARK: - Report Generation
    
    /// Generates a comprehensive test report
    private func generateTestReport(suiteName: String) {
        guard let startTime = testSuiteStartTime,
              let endTime = testSuiteEndTime else {
            print("❌ Cannot generate report: missing start/end times")
            return
        }
        
        let totalDuration = endTime.timeIntervalSince(startTime)
        let passedTests = testMetrics.filter { $0.result == .passed }.count
        let failedTests = testMetrics.filter { $0.result == .failed }.count
        let totalTests = testMetrics.count
        
        let passedPerformanceTests = performanceMetrics.filter { $0.passed }.count
        let failedPerformanceTests = performanceMetrics.filter { !$0.passed }.count
        let totalPerformanceTests = performanceMetrics.count
        
        // Generate console report
        generateConsoleReport(
            suiteName: suiteName,
            totalDuration: totalDuration,
            passedTests: passedTests,
            failedTests: failedTests,
            totalTests: totalTests,
            passedPerformanceTests: passedPerformanceTests,
            failedPerformanceTests: failedPerformanceTests,
            totalPerformanceTests: totalPerformanceTests
        )
        
        // Generate JSON report
        generateJSONReport(suiteName: suiteName, totalDuration: totalDuration)
        
        // Generate performance trend data
        generatePerformanceTrendData()
    }
    
    /// Generates a console-friendly test report
    private func generateConsoleReport(
        suiteName: String,
        totalDuration: TimeInterval,
        passedTests: Int,
        failedTests: Int,
        totalTests: Int,
        passedPerformanceTests: Int,
        failedPerformanceTests: Int,
        totalPerformanceTests: Int
    ) {
        print("\n" + "="*80)
        print("📊 TEST METRICS REPORT - \(suiteName)")
        print("="*80)
        
        // Overall summary
        print("\n📈 OVERALL SUMMARY")
        print("   Total Duration: \(String(format: "%.2f", totalDuration))s")
        print("   Tests Run: \(totalTests)")
        print("   Tests Passed: \(passedTests) (\(totalTests > 0 ? Int(Double(passedTests) / Double(totalTests) * 100) : 0)%)")
        print("   Tests Failed: \(failedTests)")
        
        if totalPerformanceTests > 0 {
            print("   Performance Tests: \(totalPerformanceTests)")
            print("   Performance Passed: \(passedPerformanceTests) (\(Int(Double(passedPerformanceTests) / Double(totalPerformanceTests) * 100))%)")
            print("   Performance Failed: \(failedPerformanceTests)")
        }
        
        // Test category breakdown
        generateCategoryBreakdown()
        
        // Performance summary
        if !performanceMetrics.isEmpty {
            generatePerformanceSummary()
        }
        
        // Failed tests details
        if failedTests > 0 {
            generateFailedTestsDetails()
        }
        
        // Performance failures
        if failedPerformanceTests > 0 {
            generatePerformanceFailuresDetails()
        }
        
        print("\n" + "="*80)
    }
    
    /// Generates test category breakdown
    private func generateCategoryBreakdown() {
        print("\n📋 TEST CATEGORY BREAKDOWN")
        
        let categories = Dictionary(grouping: testMetrics) { metric in
            // Extract category from class name
            if metric.className.contains("Model") {
                return "Model Validation"
            } else if metric.className.contains("DataService") {
                return "Data Service"
            } else if metric.className.contains("CloudKit") {
                return "CloudKit"
            } else if metric.className.contains("Performance") {
                return "Performance"
            } else if metric.className.contains("Integration") {
                return "Integration"
            } else if metric.className.contains("Relationship") {
                return "Relationships"
            } else if metric.className.contains("Migration") {
                return "Migration"
            } else {
                return "Other"
            }
        }
        
        for (category, metrics) in categories.sorted(by: { $0.key < $1.key }) {
            let passed = metrics.filter { $0.result == .passed }.count
            let failed = metrics.filter { $0.result == .failed }.count
            let total = metrics.count
            let avgDuration = metrics.map { $0.duration }.reduce(0, +) / Double(total)
            
            print("   \(category): \(passed)/\(total) passed (avg: \(String(format: "%.3f", avgDuration))s)")
            if failed > 0 {
                print("     ❌ \(failed) failed")
            }
        }
    }
    
    /// Generates performance summary
    private func generatePerformanceSummary() {
        print("\n⚡ PERFORMANCE SUMMARY")
        
        let avgDuration = performanceMetrics.map { $0.duration }.reduce(0, +) / Double(performanceMetrics.count)
        let avgMemory = performanceMetrics.map { Double($0.memoryUsage) }.reduce(0, +) / Double(performanceMetrics.count)
        
        print("   Average Operation Duration: \(String(format: "%.3f", avgDuration))s")
        print("   Average Memory Usage: \(String(format: "%.2f", avgMemory / 1_000_000))MB")
        
        // Top 5 slowest operations
        let slowestOperations = performanceMetrics
            .sorted { $0.duration > $1.duration }
            .prefix(5)
        
        if !slowestOperations.isEmpty {
            print("\n   🐌 Slowest Operations:")
            for (index, metric) in slowestOperations.enumerated() {
                print("     \(index + 1). \(metric.operationName): \(String(format: "%.3f", metric.duration))s")
            }
        }
        
        // Top 5 memory-intensive operations
        let memoryIntensiveOperations = performanceMetrics
            .sorted { $0.memoryUsage > $1.memoryUsage }
            .prefix(5)
        
        if !memoryIntensiveOperations.isEmpty {
            print("\n   🧠 Most Memory-Intensive Operations:")
            for (index, metric) in memoryIntensiveOperations.enumerated() {
                let memoryMB = Double(metric.memoryUsage) / 1_000_000
                print("     \(index + 1). \(metric.operationName): \(String(format: "%.2f", memoryMB))MB")
            }
        }
    }
    
    /// Generates details for failed tests
    private func generateFailedTestsDetails() {
        print("\n❌ FAILED TESTS DETAILS")
        
        let failedTests = testMetrics.filter { $0.result == .failed }
        for test in failedTests {
            print("   \(test.className).\(test.testName)")
            print("     Duration: \(String(format: "%.3f", test.duration))s")
            if let error = test.errorMessage {
                print("     Error: \(error)")
            }
        }
    }
    
    /// Generates details for performance failures
    private func generatePerformanceFailuresDetails() {
        print("\n🐌 PERFORMANCE FAILURES DETAILS")
        
        let failedPerformanceTests = performanceMetrics.filter { !$0.passed }
        for test in failedPerformanceTests {
            print("   \(test.operationName)")
            print("     Duration: \(String(format: "%.3f", test.duration))s (benchmark: \(String(format: "%.3f", test.benchmark))s)")
            
            let memoryMB = Double(test.memoryUsage) / 1_000_000
            let memoryLimitMB = Double(test.memoryLimit) / 1_000_000
            print("     Memory: \(String(format: "%.2f", memoryMB))MB (limit: \(String(format: "%.2f", memoryLimitMB))MB)")
            
            if test.duration > test.benchmark {
                print("     ⚠️ Exceeded time benchmark by \(String(format: "%.3f", test.duration - test.benchmark))s")
            }
            if test.memoryUsage > test.memoryLimit {
                let excess = Double(test.memoryUsage - test.memoryLimit) / 1_000_000
                print("     ⚠️ Exceeded memory limit by \(String(format: "%.2f", excess))MB")
            }
        }
    }
    
    /// Generates JSON report for CI/CD integration
    private func generateJSONReport(suiteName: String, totalDuration: TimeInterval) {
        let report = TestReport(
            suiteName: suiteName,
            timestamp: Date(),
            totalDuration: totalDuration,
            testMetrics: testMetrics,
            performanceMetrics: performanceMetrics
        )
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            
            let jsonData = try encoder.encode(report)
            
            // Save to file
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let reportURL = documentsPath.appendingPathComponent("test-report-\(suiteName)-\(Int(Date().timeIntervalSince1970)).json")
            
            try jsonData.write(to: reportURL)
            print("\n💾 JSON report saved to: \(reportURL.path)")
            
        } catch {
            print("❌ Failed to generate JSON report: \(error)")
        }
    }
    
    /// Generates performance trend data for tracking over time
    private func generatePerformanceTrendData() {
        guard !performanceMetrics.isEmpty else { return }
        
        let trendData = PerformanceTrendData(
            timestamp: Date(),
            metrics: performanceMetrics.map { metric in
                PerformanceTrendPoint(
                    operationName: metric.operationName,
                    duration: metric.duration,
                    memoryUsage: metric.memoryUsage,
                    recordCount: metric.recordCount
                )
            }
        )
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            
            let jsonData = try encoder.encode(trendData)
            
            // Append to trend file
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let trendURL = documentsPath.appendingPathComponent("performance-trends.jsonl")
            
            let jsonString = String(data: jsonData, encoding: .utf8)! + "\n"
            
            if FileManager.default.fileExists(atPath: trendURL.path) {
                let fileHandle = try FileHandle(forWritingTo: trendURL)
                fileHandle.seekToEndOfFile()
                fileHandle.write(jsonString.data(using: .utf8)!)
                fileHandle.closeFile()
            } else {
                try jsonString.write(to: trendURL, atomically: true, encoding: .utf8)
            }
            
            print("📈 Performance trend data appended to: \(trendURL.path)")
            
        } catch {
            print("❌ Failed to save performance trend data: \(error)")
        }
    }
    
    // MARK: - Utility Methods
    
    /// Clears all collected metrics
    func clearMetrics() {
        testMetrics.removeAll()
        performanceMetrics.removeAll()
        testSuiteStartTime = nil
        testSuiteEndTime = nil
    }
    
    /// Returns current test metrics
    func getCurrentMetrics() -> [TestMetric] {
        return testMetrics
    }
    
    /// Returns current performance metrics
    func getCurrentPerformanceMetrics() -> [PerformanceMetric] {
        return performanceMetrics
    }
}

// MARK: - Data Models

/// Represents the result of a test
enum TestResult: String, Codable {
    case passed
    case failed
    case skipped
}

/// Represents metrics for a single test
struct TestMetric: Codable {
    let testName: String
    let className: String
    let duration: TimeInterval
    let result: TestResult
    let memoryUsage: Int?
    let errorMessage: String?
    let timestamp: Date
}

/// Represents performance metrics for a test operation
struct PerformanceMetric: Codable {
    let testName: String
    let operationName: String
    let duration: TimeInterval
    let benchmark: TimeInterval
    let memoryUsage: Int
    let memoryLimit: Int
    let recordCount: Int
    let passed: Bool
    let timestamp: Date
}

/// Represents a complete test report
struct TestReport: Codable {
    let suiteName: String
    let timestamp: Date
    let totalDuration: TimeInterval
    let testMetrics: [TestMetric]
    let performanceMetrics: [PerformanceMetric]
    
    var summary: TestSummary {
        let passedTests = testMetrics.filter { $0.result == .passed }.count
        let failedTests = testMetrics.filter { $0.result == .failed }.count
        let passedPerformanceTests = performanceMetrics.filter { $0.passed }.count
        let failedPerformanceTests = performanceMetrics.filter { !$0.passed }.count
        
        return TestSummary(
            totalTests: testMetrics.count,
            passedTests: passedTests,
            failedTests: failedTests,
            totalPerformanceTests: performanceMetrics.count,
            passedPerformanceTests: passedPerformanceTests,
            failedPerformanceTests: failedPerformanceTests,
            totalDuration: totalDuration
        )
    }
}

/// Represents a test summary
struct TestSummary: Codable {
    let totalTests: Int
    let passedTests: Int
    let failedTests: Int
    let totalPerformanceTests: Int
    let passedPerformanceTests: Int
    let failedPerformanceTests: Int
    let totalDuration: TimeInterval
    
    var passRate: Double {
        guard totalTests > 0 else { return 0 }
        return Double(passedTests) / Double(totalTests)
    }
    
    var performancePassRate: Double {
        guard totalPerformanceTests > 0 else { return 0 }
        return Double(passedPerformanceTests) / Double(totalPerformanceTests)
    }
}

/// Represents performance trend data
struct PerformanceTrendData: Codable {
    let timestamp: Date
    let metrics: [PerformanceTrendPoint]
}

/// Represents a single point in performance trend data
struct PerformanceTrendPoint: Codable {
    let operationName: String
    let duration: TimeInterval
    let memoryUsage: Int
    let recordCount: Int
}

// MARK: - String Extension

private extension String {
    static func *(lhs: String, rhs: Int) -> String {
        return String(repeating: lhs, count: rhs)
    }
}