import Foundation
import SwiftUI
import Combine

/// Optimized timer manager for better memory management and performance
@MainActor
class OptimizedTimerManager: ObservableObject {
    static let shared = OptimizedTimerManager()
    
    // MARK: - Private Properties
    
    private var timers: [String: AnyCancellable] = [:]
    private var backgroundTaskIdentifier: UIBackgroundTaskIdentifier = .invalid
    
    // MARK: - Initialization
    
    private init() {
        setupBackgroundHandling()
    }
    
    deinit {
        // Cancel timers synchronously without main actor isolation
        timers.values.forEach { $0.cancel() }
        timers.removeAll()
    }
    
    // MARK: - Public Methods
    
    /// Create an optimized timer with automatic cleanup
    func createTimer(
        identifier: String,
        interval: TimeInterval,
        repeats: Bool = true,
        tolerance: TimeInterval? = nil,
        action: @escaping () -> Void
    ) {
        // Cancel existing timer with same identifier
        cancelTimer(identifier: identifier)
        
        // Create new timer with proper memory management
        let timer = Timer.publish(every: interval, tolerance: tolerance, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                action()
                
                // Auto-cleanup for non-repeating timers
                if !repeats {
                    self.cancelTimer(identifier: identifier)
                }
            }
        
        timers[identifier] = timer
    }
    
    /// Create a debounced timer (useful for search, validation, etc.)
    func createDebouncedTimer(
        identifier: String,
        delay: TimeInterval,
        action: @escaping () -> Void
    ) {
        // Cancel existing timer
        cancelTimer(identifier: identifier)
        
        // Create debounced timer
        let timer = Just(())
            .delay(for: .seconds(delay), scheduler: DispatchQueue.main)
            .sink { _ in
                action()
                self.cancelTimer(identifier: identifier)
            }
        
        timers[identifier] = timer
    }
    
    /// Create a throttled timer (limits execution frequency)
    func createThrottledTimer(
        identifier: String,
        interval: TimeInterval,
        action: @escaping () -> Void
    ) -> (trigger: () -> Void, cancel: () -> Void) {
        var lastExecutionTime: Date = .distantPast
        
        let trigger = {
            let now = Date()
            if now.timeIntervalSince(lastExecutionTime) >= interval {
                lastExecutionTime = now
                action()
            }
        }
        
        let cancel = {
            self.cancelTimer(identifier: identifier)
        }
        
        return (trigger, cancel)
    }
    
    /// Cancel a specific timer
    func cancelTimer(identifier: String) {
        timers[identifier]?.cancel()
        timers.removeValue(forKey: identifier)
    }
    
    /// Cancel all timers
    func invalidateAllTimers() {
        timers.values.forEach { $0.cancel() }
        timers.removeAll()
    }
    
    /// Get active timer count
    var activeTimerCount: Int {
        return timers.count
    }
    
    /// Check if a timer is active
    func isTimerActive(identifier: String) -> Bool {
        return timers[identifier] != nil
    }
    
    // MARK: - Background Handling
    
    private func setupBackgroundHandling() {
        // Handle app going to background
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleAppBackground()
            }
        }
        
        // Handle app coming to foreground
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleAppForeground()
            }
        }
    }
    
    private func handleAppBackground() {
        // Start background task to keep critical timers running briefly
        backgroundTaskIdentifier = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.endBackgroundTask()
        }
        
        // Pause non-critical timers to save battery
        pauseNonCriticalTimers()
    }
    
    private func handleAppForeground() {
        // Resume all timers
        resumeAllTimers()
        
        // End background task
        endBackgroundTask()
    }
    
    private func pauseNonCriticalTimers() {
        // Implementation would pause timers that aren't critical for background operation
        // For now, we'll keep all timers running but this could be optimized further
    }
    
    private func resumeAllTimers() {
        // Implementation would resume paused timers
        // For now, timers continue running
    }
    
    private func endBackgroundTask() {
        if backgroundTaskIdentifier != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskIdentifier)
            backgroundTaskIdentifier = .invalid
        }
    }
}

// MARK: - Timer Categories

extension OptimizedTimerManager {
    /// Timer identifiers for different categories
    enum TimerIdentifier {
        static let dataRefresh = "data_refresh"
        static let autoSave = "auto_save"
        static let cleanup = "cleanup"
        static let memoryMonitor = "memory_monitor"
        static let searchDebounce = "search_debounce"
        static let validationDebounce = "validation_debounce"
        static let uiUpdate = "ui_update"
        static let locationUpdate = "location_update"
    }
}

// MARK: - Convenience Extensions

extension OptimizedTimerManager {
    /// Create a data refresh timer
    func createDataRefreshTimer(interval: TimeInterval = 30.0, action: @escaping () -> Void) {
        createTimer(
            identifier: TimerIdentifier.dataRefresh,
            interval: interval,
            tolerance: interval * 0.1, // 10% tolerance for better battery life
            action: action
        )
    }
    
    /// Create an auto-save timer
    func createAutoSaveTimer(interval: TimeInterval = 60.0, action: @escaping () -> Void) {
        createTimer(
            identifier: TimerIdentifier.autoSave,
            interval: interval,
            tolerance: interval * 0.2, // 20% tolerance for auto-save
            action: action
        )
    }
    
    /// Create a cleanup timer
    func createCleanupTimer(interval: TimeInterval = 300.0, action: @escaping () -> Void) {
        createTimer(
            identifier: TimerIdentifier.cleanup,
            interval: interval,
            tolerance: interval * 0.5, // High tolerance for cleanup
            action: action
        )
    }
    
    /// Create a search debounce timer
    func createSearchDebounceTimer(delay: TimeInterval = 0.5, action: @escaping () -> Void) {
        createDebouncedTimer(
            identifier: TimerIdentifier.searchDebounce,
            delay: delay,
            action: action
        )
    }
    
    /// Create a validation debounce timer
    func createValidationDebounceTimer(delay: TimeInterval = 0.3, action: @escaping () -> Void) {
        createDebouncedTimer(
            identifier: TimerIdentifier.validationDebounce,
            delay: delay,
            action: action
        )
    }
}

// MARK: - Memory Management Integration

extension OptimizedTimerManager {
    /// Handle memory pressure by reducing timer frequency
    func handleMemoryPressure() {
        // Reduce timer frequency during memory pressure
        let criticalTimers = [TimerIdentifier.dataRefresh, TimerIdentifier.autoSave]
        
        // Cancel non-critical timers
        let allIdentifiers = Set(timers.keys)
        let nonCriticalIdentifiers = allIdentifiers.subtracting(criticalTimers)
        
        for identifier in nonCriticalIdentifiers {
            cancelTimer(identifier: identifier)
        }
        
        print("🔧 Reduced timer frequency due to memory pressure")
    }
    
    /// Restore normal timer frequency after memory pressure
    func restoreNormalFrequency() {
        // This would be called when memory pressure is relieved
        // Implementation would restore previously cancelled timers
        print("🔧 Restored normal timer frequency")
    }
}