import XCTest
import Foundation
import SwiftData
@testable import TribeBoard

/// Utilities for measuring and validating database operation performance
class PerformanceTestUtilities {
    
    // MARK: - Performance Measurement
    
    /// Measures the execution time of a synchronous database operation
    static func measureDatabaseOperation<T>(
        operation: () throws -> T,
        expectedMaxDuration: TimeInterval,
        description: String
    ) throws -> (result: T, metrics: PerformanceMetrics) {
        print("⏱️ PerformanceTest: Starting measurement for '\(description)'")
        
        let startTime = CFAbsoluteTimeGetCurrent()
        let startMemory = getCurrentMemoryUsage()
        
        let result: T
        do {
            result = try operation()
        } catch {
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            print("❌ PerformanceTest: Operation '\(description)' failed after \(String(format: "%.3f", duration))s")
            throw error
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let endMemory = getCurrentMemoryUsage()
        let duration = endTime - startTime
        let memoryIncrease = endMemory - startMemory
        
        let metrics = PerformanceMetrics(
            operationName: description,
            duration: duration,
            memoryUsage: memoryIncrease,
            recordCount: 1,
            passed: duration <= expectedMaxDuration,
            threshold: expectedMaxDuration
        )
        
        logPerformanceResult(metrics)
        
        return (result, metrics)
    }
    
    /// Measures the execution time of an asynchronous database operation
    static func measureAsyncDatabaseOperation<T>(
        operation: () async throws -> T,
        expectedMaxDuration: TimeInterval,
        description: String
    ) async throws -> (result: T, metrics: PerformanceMetrics) {
        print("⏱️ PerformanceTest: Starting async measurement for '\(description)'")
        
        let startTime = CFAbsoluteTimeGetCurrent()
        let startMemory = getCurrentMemoryUsage()
        
        let result: T
        do {
            result = try await operation()
        } catch {
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            print("❌ PerformanceTest: Async operation '\(description)' failed after \(String(format: "%.3f", duration))s")
            throw error
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let endMemory = getCurrentMemoryUsage()
        let duration = endTime - startTime
        let memoryIncrease = endMemory - startMemory
        
        let metrics = PerformanceMetrics(
            operationName: description,
            duration: duration,
            memoryUsage: memoryIncrease,
            recordCount: 1,
            passed: duration <= expectedMaxDuration,
            threshold: expectedMaxDuration
        )
        
        logPerformanceResult(metrics)
        
        return (result, metrics)
    }
    
    /// Measures batch operations with record count tracking
    static func measureBatchOperation<T>(
        operation: () throws -> [T],
        expectedMaxDuration: TimeInterval,
        description: String
    ) throws -> (result: [T], metrics: PerformanceMetrics) {
        print("⏱️ PerformanceTest: Starting batch measurement for '\(description)'")
        
        let startTime = CFAbsoluteTimeGetCurrent()
        let startMemory = getCurrentMemoryUsage()
        
        let result: [T]
        do {
            result = try operation()
        } catch {
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            print("❌ PerformanceTest: Batch operation '\(description)' failed after \(String(format: "%.3f", duration))s")
            throw error
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let endMemory = getCurrentMemoryUsage()
        let duration = endTime - startTime
        let memoryIncrease = endMemory - startMemory
        
        let metrics = PerformanceMetrics(
            operationName: description,
            duration: duration,
            memoryUsage: memoryIncrease,
            recordCount: result.count,
            passed: duration <= expectedMaxDuration,
            threshold: expectedMaxDuration
        )
        
        logPerformanceResult(metrics)
        
        return (result, metrics)
    }
    
    // MARK: - Memory Usage Validation
    
    /// Validates memory usage during an operation
    static func validateMemoryUsage(
        during operation: () throws -> Void,
        maxMemoryIncrease: Int,
        description: String = "Memory validation"
    ) throws -> MemoryMetrics {
        print("🧠 PerformanceTest: Starting memory validation for '\(description)'")
        
        let startMemory = getCurrentMemoryUsage()
        
        try operation()
        
        let endMemory = getCurrentMemoryUsage()
        let memoryIncrease = endMemory - startMemory
        
        let metrics = MemoryMetrics(
            operationName: description,
            startMemory: startMemory,
            endMemory: endMemory,
            memoryIncrease: memoryIncrease,
            maxAllowedIncrease: maxMemoryIncrease,
            passed: memoryIncrease <= maxMemoryIncrease
        )
        
        logMemoryResult(metrics)
        
        return metrics
    }
    
    /// Validates memory usage during an async operation
    static func validateAsyncMemoryUsage(
        during operation: () async throws -> Void,
        maxMemoryIncrease: Int,
        description: String = "Async memory validation"
    ) async throws -> MemoryMetrics {
        print("🧠 PerformanceTest: Starting async memory validation for '\(description)'")
        
        let startMemory = getCurrentMemoryUsage()
        
        try await operation()
        
        let endMemory = getCurrentMemoryUsage()
        let memoryIncrease = endMemory - startMemory
        
        let metrics = MemoryMetrics(
            operationName: description,
            startMemory: startMemory,
            endMemory: endMemory,
            memoryIncrease: memoryIncrease,
            maxAllowedIncrease: maxMemoryIncrease,
            passed: memoryIncrease <= maxMemoryIncrease
        )
        
        logMemoryResult(metrics)
        
        return metrics
    }
    
    // MARK: - Performance Assertions
    
    /// Asserts that performance metrics meet expectations
    static func assertPerformance(
        _ metrics: PerformanceMetrics,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        XCTAssertTrue(
            metrics.passed,
            "Performance test failed for '\(metrics.operationName)': took \(String(format: "%.3f", metrics.duration))s, expected ≤ \(String(format: "%.3f", metrics.threshold))s",
            file: file,
            line: line
        )
        
        if metrics.recordCount > 1 {
            let avgTimePerRecord = metrics.duration / Double(metrics.recordCount)
            print("📊 Average time per record: \(String(format: "%.3f", avgTimePerRecord * 1000))ms")
        }
    }
    
    /// Asserts that memory metrics meet expectations
    static func assertMemoryUsage(
        _ metrics: MemoryMetrics,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        XCTAssertTrue(
            metrics.passed,
            "Memory test failed for '\(metrics.operationName)': used \(formatBytes(metrics.memoryIncrease)), expected ≤ \(formatBytes(metrics.maxAllowedIncrease))",
            file: file,
            line: line
        )
    }
    
    // MARK: - Benchmark Validation
    
    /// Validates operation against predefined benchmark
    static func validateAgainstBenchmark(
        _ metrics: PerformanceMetrics,
        benchmark: PerformanceBenchmark,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        XCTAssertEqual(
            metrics.operationName,
            benchmark.operationName,
            "Metrics operation name doesn't match benchmark",
            file: file,
            line: line
        )
        
        XCTAssertLessThanOrEqual(
            metrics.duration,
            benchmark.maxDuration,
            "Operation '\(benchmark.operationName)' exceeded benchmark: \(String(format: "%.3f", metrics.duration))s > \(String(format: "%.3f", benchmark.maxDuration))s",
            file: file,
            line: line
        )
        
        if metrics.memoryUsage > benchmark.maxMemoryIncrease {
            XCTFail(
                "Operation '\(benchmark.operationName)' exceeded memory benchmark: \(formatBytes(metrics.memoryUsage)) > \(formatBytes(benchmark.maxMemoryIncrease))",
                file: file,
                line: line
            )
        }
    }
    
    // MARK: - Reporting
    
    /// Generates a performance report from multiple metrics
    static func generatePerformanceReport(metrics: [PerformanceMetrics]) -> PerformanceReport {
        let totalDuration = metrics.reduce(0) { $0 + $1.duration }
        let totalMemoryUsage = metrics.reduce(0) { $0 + $1.memoryUsage }
        let passedCount = metrics.filter { $0.passed }.count
        let failedCount = metrics.count - passedCount
        
        let report = PerformanceReport(
            totalOperations: metrics.count,
            totalDuration: totalDuration,
            totalMemoryUsage: totalMemoryUsage,
            passedOperations: passedCount,
            failedOperations: failedCount,
            operationMetrics: metrics
        )
        
        logPerformanceReport(report)
        
        return report
    }
    
    // MARK: - Private Helpers
    
    /// Gets current memory usage in bytes
    private static func getCurrentMemoryUsage() -> Int {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Int(info.resident_size)
        } else {
            return 0
        }
    }
    
    /// Formats bytes into human-readable string
    private static func formatBytes(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: Int64(bytes))
    }
    
    /// Logs performance result
    private static func logPerformanceResult(_ metrics: PerformanceMetrics) {
        let status = metrics.passed ? "✅" : "❌"
        let durationStr = String(format: "%.3f", metrics.duration)
        let thresholdStr = String(format: "%.3f", metrics.threshold)
        
        print("\(status) PerformanceTest: '\(metrics.operationName)' - \(durationStr)s (threshold: \(thresholdStr)s)")
        
        if metrics.recordCount > 1 {
            let avgTime = metrics.duration / Double(metrics.recordCount) * 1000
            print("   📊 Records: \(metrics.recordCount), Avg: \(String(format: "%.2f", avgTime))ms/record")
        }
        
        if metrics.memoryUsage > 0 {
            print("   🧠 Memory: \(formatBytes(metrics.memoryUsage))")
        }
    }
    
    /// Logs memory result
    private static func logMemoryResult(_ metrics: MemoryMetrics) {
        let status = metrics.passed ? "✅" : "❌"
        let increaseStr = formatBytes(metrics.memoryIncrease)
        let maxStr = formatBytes(metrics.maxAllowedIncrease)
        
        print("\(status) MemoryTest: '\(metrics.operationName)' - \(increaseStr) (max: \(maxStr))")
        print("   📊 Start: \(formatBytes(metrics.startMemory)), End: \(formatBytes(metrics.endMemory))")
    }
    
    /// Logs performance report
    private static func logPerformanceReport(_ report: PerformanceReport) {
        print("📊 Performance Report:")
        print("   Total Operations: \(report.totalOperations)")
        print("   Passed: \(report.passedOperations), Failed: \(report.failedOperations)")
        print("   Total Duration: \(String(format: "%.3f", report.totalDuration))s")
        print("   Total Memory: \(formatBytes(report.totalMemoryUsage))")
        
        if report.totalOperations > 0 {
            let avgDuration = report.totalDuration / Double(report.totalOperations)
            print("   Average Duration: \(String(format: "%.3f", avgDuration))s per operation")
        }
    }
}

// MARK: - Performance Metrics Types

/// Metrics for a single performance test
struct PerformanceMetrics {
    let operationName: String
    let duration: TimeInterval
    let memoryUsage: Int
    let recordCount: Int
    let passed: Bool
    let threshold: TimeInterval
}

/// Metrics for memory usage testing
struct MemoryMetrics {
    let operationName: String
    let startMemory: Int
    let endMemory: Int
    let memoryIncrease: Int
    let maxAllowedIncrease: Int
    let passed: Bool
}

/// Performance benchmark definition
struct PerformanceBenchmark {
    let operationName: String
    let maxDuration: TimeInterval
    let maxMemoryIncrease: Int
    let description: String
}

/// Comprehensive performance report
struct PerformanceReport {
    let totalOperations: Int
    let totalDuration: TimeInterval
    let totalMemoryUsage: Int
    let passedOperations: Int
    let failedOperations: Int
    let operationMetrics: [PerformanceMetrics]
    
    var successRate: Double {
        guard totalOperations > 0 else { return 0 }
        return Double(passedOperations) / Double(totalOperations)
    }
}

// MARK: - Predefined Benchmarks

/// Standard performance benchmarks for database operations
struct DatabasePerformanceBenchmarks {
    
    /// Benchmark for creating a single family
    static let createFamily = PerformanceBenchmark(
        operationName: "Create Family",
        maxDuration: 0.010, // 10ms
        maxMemoryIncrease: 1_048_576, // 1MB
        description: "Single family creation should complete within 10ms"
    )
    
    /// Benchmark for fetching family by code
    static let fetchFamilyByCode = PerformanceBenchmark(
        operationName: "Fetch Family by Code",
        maxDuration: 0.005, // 5ms
        maxMemoryIncrease: 524_288, // 500KB
        description: "Family fetch by code should complete within 5ms"
    )
    
    /// Benchmark for creating a membership
    static let createMembership = PerformanceBenchmark(
        operationName: "Create Membership",
        maxDuration: 0.015, // 15ms
        maxMemoryIncrease: 1_048_576, // 1MB
        description: "Membership creation should complete within 15ms"
    )
    
    /// Benchmark for batch operations (100 records)
    static let batchOperations = PerformanceBenchmark(
        operationName: "Batch Operations (100 records)",
        maxDuration: 0.500, // 500ms
        maxMemoryIncrease: 10_485_760, // 10MB
        description: "Batch operations with 100 records should complete within 500ms"
    )
    
    /// Benchmark for CloudKit sync (single record)
    static let cloudKitSync = PerformanceBenchmark(
        operationName: "CloudKit Sync (single record)",
        maxDuration: 2.0, // 2s
        maxMemoryIncrease: 2_097_152, // 2MB
        description: "CloudKit sync for single record should complete within 2s"
    )
    
    /// Benchmark for full database query
    static let fullDatabaseQuery = PerformanceBenchmark(
        operationName: "Full Database Query",
        maxDuration: 0.100, // 100ms
        maxMemoryIncrease: 5_242_880, // 5MB
        description: "Full database query should complete within 100ms"
    )
    
    /// All standard benchmarks
    static let all: [PerformanceBenchmark] = [
        createFamily,
        fetchFamilyByCode,
        createMembership,
        batchOperations,
        cloudKitSync,
        fullDatabaseQuery
    ]
}

/// Scalability benchmarks for different data sizes
struct ScalabilityBenchmarks {
    
    /// Benchmark for fetching 10 families
    static let fetch10Families = PerformanceBenchmark(
        operationName: "Fetch 10 Families",
        maxDuration: 0.010, // 10ms
        maxMemoryIncrease: 1_048_576, // 1MB
        description: "Fetching 10 families should complete within 10ms"
    )
    
    /// Benchmark for fetching 100 families
    static let fetch100Families = PerformanceBenchmark(
        operationName: "Fetch 100 Families",
        maxDuration: 0.050, // 50ms
        maxMemoryIncrease: 5_242_880, // 5MB
        description: "Fetching 100 families should complete within 50ms"
    )
    
    /// Benchmark for fetching 1000 families
    static let fetch1000Families = PerformanceBenchmark(
        operationName: "Fetch 1000 Families",
        maxDuration: 0.200, // 200ms
        maxMemoryIncrease: 20_971_520, // 20MB
        description: "Fetching 1000 families should complete within 200ms"
    )
    
    /// Benchmark for querying 10 members per family
    static let query10MembersPerFamily = PerformanceBenchmark(
        operationName: "Query 10 Members per Family",
        maxDuration: 0.020, // 20ms
        maxMemoryIncrease: 2_097_152, // 2MB
        description: "Querying 10 members per family should complete within 20ms"
    )
    
    /// Benchmark for querying 50 members per family
    static let query50MembersPerFamily = PerformanceBenchmark(
        operationName: "Query 50 Members per Family",
        maxDuration: 0.100, // 100ms
        maxMemoryIncrease: 10_485_760, // 10MB
        description: "Querying 50 members per family should complete within 100ms"
    )
    
    /// All scalability benchmarks
    static let all: [PerformanceBenchmark] = [
        fetch10Families,
        fetch100Families,
        fetch1000Families,
        query10MembersPerFamily,
        query50MembersPerFamily
    ]
}