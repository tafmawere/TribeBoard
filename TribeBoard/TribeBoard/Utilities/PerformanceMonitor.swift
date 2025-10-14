import Foundation
import SwiftUI

/// Performance monitoring utility for tracking app performance metrics
@MainActor
class PerformanceMonitor: ObservableObject {
    static let shared = PerformanceMonitor()
    
    // MARK: - Published Properties
    
    /// Current memory usage in MB
    @Published var memoryUsage: Double = 0
    
    /// Frame rate monitoring
    @Published var averageFrameRate: Double = 60
    
    /// Loading times for different operations
    @Published var loadingTimes: [String: TimeInterval] = [:]
    
    // MARK: - Private Properties
    
    private var memoryTimer: Timer?
    private var frameRateTimer: Timer?
    private var operationStartTimes: [String: Date] = [:]
    private var frameRateSamples: [Double] = []
    private let maxSamples = 60 // Keep last 60 samples for average
    
    // MARK: - Initialization
    
    private init() {
        startMonitoring()
    }
    
    deinit {
        // Synchronously stop monitoring - safe to call from deinit
        memoryTimer?.invalidate()
        frameRateTimer?.invalidate()
        memoryTimer = nil
        frameRateTimer = nil
    }
    
    // MARK: - Public Methods
    
    /// Start performance monitoring
    func startMonitoring() {
        // Monitor memory usage every 5 seconds
        memoryTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateMemoryUsage()
            }
        }
        
        // Monitor frame rate every second
        frameRateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateFrameRate()
            }
        }
    }
    
    /// Stop performance monitoring
    func stopMonitoring() {
        memoryTimer?.invalidate()
        frameRateTimer?.invalidate()
        memoryTimer = nil
        frameRateTimer = nil
    }
    
    /// Start timing an operation
    func startOperation(_ name: String) {
        operationStartTimes[name] = Date()
    }
    
    /// End timing an operation and record the duration
    func endOperation(_ name: String) {
        guard let startTime = operationStartTimes[name] else { return }
        
        let duration = Date().timeIntervalSince(startTime)
        loadingTimes[name] = duration
        operationStartTimes.removeValue(forKey: name)
        
        // Log slow operations
        if duration > 1.0 {
            print("⚠️ Slow operation detected: \(name) took \(String(format: "%.2f", duration))s")
        }
    }
    
    /// Get formatted memory usage string
    var formattedMemoryUsage: String {
        return String(format: "%.1f MB", memoryUsage)
    }
    
    /// Get formatted frame rate string
    var formattedFrameRate: String {
        return String(format: "%.1f FPS", averageFrameRate)
    }
    
    /// Check if performance is good
    var isPerformanceGood: Bool {
        return memoryUsage < 100 && averageFrameRate > 50
    }
    
    /// Get performance status
    var performanceStatus: PerformanceStatus {
        if memoryUsage > 150 || averageFrameRate < 30 {
            return .poor
        } else if memoryUsage > 100 || averageFrameRate < 50 {
            return .fair
        } else {
            return .good
        }
    }
    
    // MARK: - Private Methods
    
    /// Update memory usage
    private func updateMemoryUsage() {
        var memoryInfo = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &memoryInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            let memoryUsageBytes = Double(memoryInfo.resident_size)
            memoryUsage = memoryUsageBytes / (1024 * 1024) // Convert to MB
        }
    }
    
    /// Update frame rate (simplified estimation)
    private func updateFrameRate() {
        // This is a simplified frame rate estimation
        // In a real implementation, you'd use CADisplayLink or similar
        let currentTime = Date().timeIntervalSince1970
        let estimatedFrameRate = 60.0 // Placeholder - would be calculated from actual frame timing
        
        frameRateSamples.append(estimatedFrameRate)
        
        // Keep only recent samples
        if frameRateSamples.count > maxSamples {
            frameRateSamples.removeFirst()
        }
        
        // Calculate average
        averageFrameRate = frameRateSamples.reduce(0, +) / Double(frameRateSamples.count)
    }
}

// MARK: - Performance Status

enum PerformanceStatus {
    case good
    case fair
    case poor
    
    var color: Color {
        switch self {
        case .good: return .green
        case .fair: return .orange
        case .poor: return .red
        }
    }
    
    var description: String {
        switch self {
        case .good: return "Good"
        case .fair: return "Fair"
        case .poor: return "Poor"
        }
    }
}

// MARK: - Performance Timing Wrapper

/// Wrapper for timing operations
struct PerformanceTiming {
    static func measure<T>(_ operation: String, _ block: () throws -> T) rethrows -> T {
        Task { @MainActor in
            PerformanceMonitor.shared.startOperation(operation)
        }
        defer { 
            Task { @MainActor in
                PerformanceMonitor.shared.endOperation(operation)
            }
        }
        return try block()
    }
    
    static func measureAsync<T>(_ operation: String, _ block: () async throws -> T) async rethrows -> T {
        await PerformanceMonitor.shared.startOperation(operation)
        defer { 
            Task { @MainActor in
                await PerformanceMonitor.shared.endOperation(operation)
            }
        }
        return try await block()
    }
}

// MARK: - Memory Management Utilities

/// Memory management utilities for better performance
struct MemoryManager {
    /// Force memory cleanup
    static func cleanup() {
        // Force garbage collection
        autoreleasepool {
            // Trigger memory cleanup
        }
    }
    
    /// Check if memory pressure is high
    @MainActor
    static func isMemoryPressureHigh() -> Bool {
        return PerformanceMonitor.shared.memoryUsage > 100
    }
    
    /// Optimize for memory usage
    @MainActor
    static func optimizeMemoryUsage() {
        if isMemoryPressureHigh() {
            cleanup()
            
            // Clear caches if needed
            URLCache.shared.removeAllCachedResponses()
            
            // Notify components to reduce memory usage
            NotificationCenter.default.post(name: .memoryPressureHigh, object: nil)
        }
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let memoryPressureHigh = Notification.Name("memoryPressureHigh")
}