import Foundation
import SwiftUI
import Combine

// Note: SchoolRunError is defined in SchoolRunErrorHandler.swift
// We'll extend it with additional cases needed for the manager

/// Manager class for school run data persistence and state management
@MainActor
class SchoolRunManager: ObservableObject {
    // MARK: - Published Properties
    
    /// All school runs stored in the system
    @Published var runs: [SchoolRun] = []
    
    /// Currently active run (if any)
    @Published var activeRun: SchoolRun?
    
    /// Loading state for async operations
    @Published var isLoading: Bool = false
    
    /// Error message for display
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    
    /// UserDefaults storage for persistence
    private let storage: UserDefaults
    
    /// Storage keys
    private let runsKey = "school_runs_data"
    private let activeRunKey = "active_school_run"
    private let dataVersionKey = "school_runs_data_version"
    
    /// Current data version for migration handling
    private let currentDataVersion = 1
    
    /// JSON encoder for data persistence
    private let encoder = JSONEncoder()
    
    /// JSON decoder for data loading
    private let decoder = JSONDecoder()
    
    /// Cancellables for background app state monitoring
    private var cancellables = Set<AnyCancellable>()
    
    /// Optimized timer manager for better performance
    private let timerManager = OptimizedTimerManager.shared
    
    /// Flag to track if data needs to be saved
    private var needsSave = false
    
    /// Queue for background data operations
    private let backgroundQueue = DispatchQueue(label: "school-run-data", qos: .utility)
    
    // MARK: - Initialization
    
    init(storage: UserDefaults = .standard) {
        self.storage = storage
        
        // Configure date encoding/decoding strategy
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        
        // Load existing data on initialization
        loadFromStorage()
        
        // Set up background app state monitoring
        setupBackgroundStateMonitoring()
        
        // Set up automatic cleanup timer
        setupCleanupTimer()
        
        // Set up memory pressure monitoring
        setupMemoryPressureMonitoring()
    }
    
    deinit {
        Task { @MainActor in
            timerManager.cancelTimer(identifier: "cleanup")
            timerManager.cancelTimer(identifier: "auto_save")
        }
        cancellables.removeAll()
    }
    
    // MARK: - Computed Properties
    
    /// Cached computed properties for performance optimization
    private var _todaysRuns: [SchoolRun]?
    private var _upcomingRuns: [SchoolRun]?
    private var _completedRuns: [SchoolRun]?
    private var _scheduledRuns: [SchoolRun]?
    private var _inProgressRuns: [SchoolRun]?
    private var _cancelledRuns: [SchoolRun]?
    private var _cacheInvalidationDate: Date = Date()
    
    /// Runs scheduled for today (cached for performance)
    var todaysRuns: [SchoolRun] {
        if let cached = _todaysRuns, _cacheInvalidationDate.timeIntervalSinceNow > -300 { // 5 minute cache
            return cached
        }
        
        let result = runs.filter { Calendar.current.isDateInToday($0.date) }
            .sorted { $0.date < $1.date }
        _todaysRuns = result
        return result
    }
    
    /// Upcoming runs (future dates) - cached for performance
    var upcomingRuns: [SchoolRun] {
        if let cached = _upcomingRuns, _cacheInvalidationDate.timeIntervalSinceNow > -300 {
            return cached
        }
        
        let result = runs.filter { $0.date > Date() && !Calendar.current.isDateInToday($0.date) }
            .sorted { $0.date < $1.date }
        _upcomingRuns = result
        return result
    }
    
    /// Completed runs - cached for performance
    var completedRuns: [SchoolRun] {
        if let cached = _completedRuns, _cacheInvalidationDate.timeIntervalSinceNow > -300 {
            return cached
        }
        
        let result = runs.filter { $0.status == .completed }
            .sorted { $0.date > $1.date } // Most recent first
        _completedRuns = result
        return result
    }
    
    /// Scheduled runs - cached for performance
    var scheduledRuns: [SchoolRun] {
        if let cached = _scheduledRuns, _cacheInvalidationDate.timeIntervalSinceNow > -300 {
            return cached
        }
        
        let result = runs.filter { $0.status == .scheduled }
            .sorted { $0.date < $1.date }
        _scheduledRuns = result
        return result
    }
    
    /// In-progress runs - cached for performance
    var inProgressRuns: [SchoolRun] {
        if let cached = _inProgressRuns, _cacheInvalidationDate.timeIntervalSinceNow > -300 {
            return cached
        }
        
        let result = runs.filter { $0.status == .inProgress }
            .sorted { $0.date < $1.date }
        _inProgressRuns = result
        return result
    }
    
    /// Cancelled runs - cached for performance
    var cancelledRuns: [SchoolRun] {
        if let cached = _cancelledRuns, _cacheInvalidationDate.timeIntervalSinceNow > -300 {
            return cached
        }
        
        let result = runs.filter { $0.status == .cancelled }
            .sorted { $0.date > $1.date } // Most recent first
        _cancelledRuns = result
        return result
    }
    
    /// Check if there's an active run
    var hasActiveRun: Bool {
        activeRun != nil
    }
    
    /// Total number of runs
    var totalRuns: Int {
        runs.count
    }
    
    // MARK: - Background State Monitoring
    
    /// Set up monitoring for app background/foreground state
    private func setupBackgroundStateMonitoring() {
        // Monitor app going to background
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                self?.saveOnBackground()
            }
            .store(in: &cancellables)
        
        // Monitor app coming to foreground
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                self?.loadFromStorage()
            }
            .store(in: &cancellables)
        
        // Monitor app termination
        NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)
            .sink { [weak self] _ in
                self?.saveOnBackground()
            }
            .store(in: &cancellables)
    }
    
    /// Set up automatic cleanup timer (optimized)
    private func setupCleanupTimer() {
        // Run cleanup every 24 hours with optimized timer
        timerManager.createCleanupTimer(interval: 86400) { [weak self] in
            self?.performCleanup()
        }
        
        // Set up auto-save timer for better data persistence
        timerManager.createAutoSaveTimer(interval: 300) { [weak self] in // 5 minutes
            self?.autoSave()
        }
    }
    
    /// Set up memory pressure monitoring
    private func setupMemoryPressureMonitoring() {
        NotificationCenter.default.addObserver(
            forName: .memoryPressureHigh,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleMemoryPressure()
            }
        }
    }
    
    /// Handle memory pressure by optimizing data usage
    private func handleMemoryPressure() {
        // Clear caches
        invalidateCache()
        
        // Reduce timer frequency
        timerManager.handleMemoryPressure()
        
        // Force save and cleanup
        do {
            try saveToStorage()
            performCleanup()
        } catch {
            print("Failed to save during memory pressure: \(error)")
        }
        
        print("🔧 Handled memory pressure in SchoolRunManager")
    }
    
    /// Auto-save if data needs saving
    private func autoSave() {
        guard needsSave else { return }
        
        do {
            try saveToStorage()
            try saveActiveRunToStorage()
        } catch {
            print("Auto-save failed: \(error)")
        }
    }
    
    // MARK: - CRUD Operations
    
    /// Create a new school run
    func createRun(_ run: SchoolRun) throws {
        // Validate run data
        try validateRunData(run)
        
        // Check if run with same ID already exists
        if runs.contains(where: { $0.id == run.id }) {
            throw SchoolRunError.invalidRunData("Run with this ID already exists")
        }
        
        // Add to runs array
        runs.append(run)
        
        // Invalidate cache
        invalidateCache()
        
        // Mark as needing save
        needsSave = true
        
        // Save to storage
        try saveToStorage()
        
        clearError()
    }
    
    /// Read/fetch a run by ID
    func getRun(id: UUID) -> SchoolRun? {
        return runs.first { $0.id == id }
    }
    
    /// Update an existing run
    func updateRun(_ updatedRun: SchoolRun) throws {
        // Validate run data
        try validateRunData(updatedRun)
        
        // Find the index of the run to update
        guard let index = runs.firstIndex(where: { $0.id == updatedRun.id }) else {
            throw SchoolRunError.runNotFound(updatedRun.id)
        }
        
        // Update the run
        runs[index] = updatedRun
        
        // Update active run if it's the same run
        if activeRun?.id == updatedRun.id {
            activeRun = updatedRun
        }
        
        // Invalidate cache
        invalidateCache()
        
        // Mark as needing save
        needsSave = true
        
        // Save to storage
        try saveToStorage()
        
        clearError()
    }
    
    /// Delete a run by ID
    func deleteRun(id: UUID) throws {
        // Find the run to delete
        guard let index = runs.firstIndex(where: { $0.id == id }) else {
            throw SchoolRunError.runNotFound(id)
        }
        
        let runToDelete = runs[index]
        
        // Check if the run can be deleted (not in progress)
        guard runToDelete.status.canDelete else {
            throw SchoolRunError.invalidRunState(runToDelete.status, "delete")
        }
        
        // Clear active run if it's the one being deleted
        if activeRun?.id == id {
            activeRun = nil
            try saveActiveRunToStorage()
        }
        
        // Remove from runs array
        runs.remove(at: index)
        
        // Invalidate cache
        invalidateCache()
        
        // Mark as needing save
        needsSave = true
        
        // Save to storage
        try saveToStorage()
        
        clearError()
    }
    
    /// Delete all runs (for testing/reset purposes)
    func deleteAllRuns() throws {
        runs.removeAll()
        activeRun = nil
        needsSave = true
        
        try saveToStorage()
        try saveActiveRunToStorage()
        
        clearError()
    }
    
    // MARK: - Run Execution State Management
    
    /// Start a run
    func startRun(id: UUID) throws {
        // Check if there's already an active run
        if let currentActiveRun = activeRun, currentActiveRun.id != id {
            throw SchoolRunError.runAlreadyActive(currentActiveRun.title)
        }
        
        // Find the run to start
        guard let index = runs.firstIndex(where: { $0.id == id }) else {
            throw SchoolRunError.runNotFound(id)
        }
        
        var run = runs[index]
        
        // Check if run can be started
        guard run.status.canStart else {
            throw SchoolRunError.invalidRunState(run.status, "start")
        }
        
        // Update run status
        run.status = .inProgress
        
        // Reset all stops to not completed
        for i in 0..<run.route.count {
            run.route[i].isCompleted = false
        }
        
        // Update the run in the array
        runs[index] = run
        
        // Set as active run
        activeRun = run
        
        // Mark as needing save
        needsSave = true
        
        // Save to storage
        try saveToStorage()
        try saveActiveRunToStorage()
        
        clearError()
    }
    
    /// Pause a run (sets status back to scheduled)
    func pauseRun(id: UUID) throws {
        // Find the run to pause
        guard let index = runs.firstIndex(where: { $0.id == id }) else {
            throw SchoolRunError.runNotFound(id)
        }
        
        var run = runs[index]
        
        // Check if run can be paused
        guard run.status.canPause else {
            throw SchoolRunError.invalidRunState(run.status, "pause")
        }
        
        // Update run status
        run.status = .scheduled
        
        // Update the run in the array
        runs[index] = run
        
        // Clear active run if it's the one being paused
        if activeRun?.id == id {
            activeRun = nil
            try saveActiveRunToStorage()
        }
        
        // Mark as needing save
        needsSave = true
        
        // Save to storage
        try saveToStorage()
        
        clearError()
    }
    
    /// Complete a run
    func completeRun(id: UUID) throws {
        // Find the run to complete
        guard let index = runs.firstIndex(where: { $0.id == id }) else {
            throw SchoolRunError.runNotFound(id)
        }
        
        var run = runs[index]
        
        // Check if run can be completed
        guard run.status.canComplete else {
            throw SchoolRunError.invalidRunState(run.status, "complete")
        }
        
        // Update run status
        run.status = .completed
        
        // Mark all stops as completed
        for i in 0..<run.route.count {
            run.route[i].isCompleted = true
        }
        
        // Update the run in the array
        runs[index] = run
        
        // Clear active run if it's the one being completed
        if activeRun?.id == id {
            activeRun = nil
            try saveActiveRunToStorage()
        }
        
        // Mark as needing save
        needsSave = true
        
        // Save to storage
        try saveToStorage()
        
        clearError()
    }
    
    /// Cancel a run
    func cancelRun(id: UUID) throws {
        // Find the run to cancel
        guard let index = runs.firstIndex(where: { $0.id == id }) else {
            throw SchoolRunError.runNotFound(id)
        }
        
        var run = runs[index]
        
        // Check if run can be cancelled
        guard run.status.canCancel else {
            throw SchoolRunError.invalidRunState(run.status, "cancel")
        }
        
        // Update run status
        run.status = .cancelled
        
        // Update the run in the array
        runs[index] = run
        
        // Clear active run if it's the one being cancelled
        if activeRun?.id == id {
            activeRun = nil
            try saveActiveRunToStorage()
        }
        
        // Mark as needing save
        needsSave = true
        
        // Save to storage
        try saveToStorage()
        
        clearError()
    }
    
    /// Complete a specific stop in the active run
    func completeStop(stopId: UUID) throws {
        guard var activeRun = activeRun else {
            throw SchoolRunError.noActiveRun
        }
        
        // Find the stop to complete
        guard let stopIndex = activeRun.route.firstIndex(where: { $0.id == stopId }) else {
            throw SchoolRunError.stopNotFound(stopId)
        }
        
        // Mark the stop as completed
        activeRun.route[stopIndex].isCompleted = true
        
        // Update the active run
        self.activeRun = activeRun
        
        // Mark as needing save
        needsSave = true
        
        // Update the run in the runs array
        try updateRun(activeRun)
        
        clearError()
    }
    
    /// Get the next incomplete stop in the active run
    func getNextStop() -> RunStop? {
        return activeRun?.nextStop
    }
    
    /// Get the current progress of the active run
    func getActiveRunProgress() -> Double {
        return activeRun?.progress ?? 0.0
    }
    
    // MARK: - Data Persistence
    
    /// Save runs to UserDefaults storage with error recovery
    func saveToStorage() throws {
        do {
            // Validate data before saving
            try validateDataIntegrity()
            
            // Encode runs data
            let runsData = try encoder.encode(runs)
            
            // Save to storage atomically
            storage.set(runsData, forKey: runsKey)
            storage.set(currentDataVersion, forKey: dataVersionKey)
            
            // Mark as saved
            needsSave = false
            
        } catch let error as SchoolRunError {
            throw error
        } catch {
            throw SchoolRunError.storageError("Failed to save runs: \(error.localizedDescription)")
        }
    }
    
    /// Save active run to UserDefaults storage
    private func saveActiveRunToStorage() throws {
        do {
            if let activeRun = activeRun {
                let data = try encoder.encode(activeRun)
                storage.set(data, forKey: activeRunKey)
            } else {
                storage.removeObject(forKey: activeRunKey)
            }
        } catch {
            throw SchoolRunError.storageError("Failed to save active run: \(error.localizedDescription)")
        }
    }
    
    /// Load runs from UserDefaults storage with migration and validation
    func loadFromStorage() {
        do {
            // Check if migration is needed
            let storedVersion = storage.integer(forKey: dataVersionKey)
            if storedVersion < currentDataVersion {
                try migrateData(from: storedVersion, to: currentDataVersion)
            }
            
            // Load runs with validation
            if let data = storage.data(forKey: runsKey) {
                let loadedRuns = try decoder.decode([SchoolRun].self, from: data)
                
                // Validate loaded data
                let validRuns = try validateAndCleanLoadedRuns(loadedRuns)
                runs = validRuns
            } else {
                runs = []
            }
            
            // Load active run with validation
            if let data = storage.data(forKey: activeRunKey) {
                let loadedActiveRun = try decoder.decode(SchoolRun.self, from: data)
                
                // Validate active run still exists in runs array and is valid
                if runs.contains(where: { $0.id == loadedActiveRun.id }),
                   loadedActiveRun.status == .inProgress {
                    activeRun = loadedActiveRun
                } else {
                    activeRun = nil
                    // Clean up invalid active run from storage
                    storage.removeObject(forKey: activeRunKey)
                }
            } else {
                activeRun = nil
            }
            
            // Perform cleanup of old runs
            performCleanup()
            
        } catch {
            print("Failed to load runs from storage: \(error)")
            // Attempt data recovery
            attemptDataRecovery()
        }
    }
    
    /// Save data when app goes to background
    func saveOnBackground() {
        guard needsSave else { return }
        
        backgroundQueue.async { [weak self] in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                do {
                    try self.saveToStorage()
                    try self.saveActiveRunToStorage()
                } catch {
                    print("Failed to save data on background: \(error)")
                }
            }
        }
    }
    
    /// Clear all stored data (for testing/reset purposes)
    func clearStorage() {
        storage.removeObject(forKey: runsKey)
        storage.removeObject(forKey: activeRunKey)
        storage.removeObject(forKey: dataVersionKey)
        runs.removeAll()
        activeRun = nil
        needsSave = false
    }
    
    // MARK: - Data Migration
    
    /// Migrate data from older versions
    private func migrateData(from oldVersion: Int, to newVersion: Int) throws {
        print("Migrating school run data from version \(oldVersion) to \(newVersion)")
        
        switch (oldVersion, newVersion) {
        case (0, 1):
            // Migration from no version to version 1
            // This handles the initial migration where we add version tracking
            try migrateToVersion1()
        default:
            print("No migration path from version \(oldVersion) to \(newVersion)")
        }
        
        // Update version after successful migration
        storage.set(newVersion, forKey: dataVersionKey)
    }
    
    /// Migrate to version 1 (add version tracking and data validation)
    private func migrateToVersion1() throws {
        // Load existing data without version checking
        if let data = storage.data(forKey: runsKey) {
            do {
                let existingRuns = try decoder.decode([SchoolRun].self, from: data)
                
                // Validate and clean existing runs
                let validRuns = try validateAndCleanLoadedRuns(existingRuns)
                
                // Save cleaned data
                let cleanedData = try encoder.encode(validRuns)
                storage.set(cleanedData, forKey: runsKey)
                
                print("Successfully migrated \(validRuns.count) runs to version 1")
            } catch {
                print("Failed to migrate existing runs, starting fresh: \(error)")
                storage.removeObject(forKey: runsKey)
            }
        }
    }
    
    // MARK: - Data Validation
    
    /// Validate overall data integrity
    private func validateDataIntegrity() throws {
        // Check for duplicate IDs
        let runIds = runs.map { $0.id }
        let uniqueIds = Set(runIds)
        guard runIds.count == uniqueIds.count else {
            throw SchoolRunError.dataCorruption("Duplicate run IDs detected")
        }
        
        // Validate each run
        for run in runs {
            try validateRunData(run)
        }
        
        // Validate active run consistency
        if let activeRun = activeRun {
            guard runs.contains(where: { $0.id == activeRun.id }) else {
                throw SchoolRunError.dataCorruption("Active run not found in runs array")
            }
            
            guard activeRun.status == .inProgress else {
                throw SchoolRunError.dataCorruption("Active run has invalid status")
            }
        }
    }
    
    /// Validate run data before saving
    private func validateRunData(_ run: SchoolRun) throws {
        // Check if title is not empty
        let trimmedTitle = run.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            throw SchoolRunError.invalidRunData("Run title cannot be empty")
        }
        
        guard trimmedTitle.count >= 3 && trimmedTitle.count <= 50 else {
            throw SchoolRunError.invalidRunData("Run title must be between 3-50 characters")
        }
        
        // Check if date is reasonable (not too far in the past or future)
        let oneYearAgo = Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date()
        let oneYearFromNow = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
        
        guard run.date >= oneYearAgo && run.date <= oneYearFromNow else {
            throw SchoolRunError.invalidRunData("Run date must be within one year range")
        }
        
        // Check if route has at least one stop
        guard !run.route.isEmpty else {
            throw SchoolRunError.invalidRunData("Run must have at least one stop")
        }
        
        // Validate each stop
        for (index, stop) in run.route.enumerated() {
            let trimmedName = stop.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedName.isEmpty else {
                throw SchoolRunError.invalidRunData("Stop \(index + 1) name cannot be empty")
            }
            
            guard trimmedName.count <= 30 else {
                throw SchoolRunError.invalidRunData("Stop \(index + 1) name must be 30 characters or less")
            }
            
            guard stop.note.count <= 100 else {
                throw SchoolRunError.invalidRunData("Stop \(index + 1) note must be 100 characters or less")
            }
        }
        
        // Validate stop timing
        let sortedStops = run.route.sorted { $0.time < $1.time }
        for i in 1..<sortedStops.count {
            let timeDifference = sortedStops[i].time.timeIntervalSince(sortedStops[i-1].time)
            guard timeDifference >= 300 else { // 5 minutes minimum
                throw SchoolRunError.invalidRunData("Stops must be at least 5 minutes apart")
            }
        }
    }
    
    /// Validate and clean loaded runs, removing invalid ones
    private func validateAndCleanLoadedRuns(_ loadedRuns: [SchoolRun]) throws -> [SchoolRun] {
        var validRuns: [SchoolRun] = []
        var removedCount = 0
        
        for run in loadedRuns {
            do {
                try validateRunData(run)
                validRuns.append(run)
            } catch {
                print("Removing invalid run '\(run.title)': \(error)")
                removedCount += 1
            }
        }
        
        if removedCount > 0 {
            print("Removed \(removedCount) invalid runs during data validation")
        }
        
        return validRuns
    }
    
    // MARK: - Data Cleanup
    
    /// Perform cleanup of old completed runs
    func performCleanup() {
        let calendar = Calendar.current
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        
        let initialCount = runs.count
        
        // Remove completed runs older than 30 days
        runs.removeAll { run in
            run.status == .completed && run.date < thirtyDaysAgo
        }
        
        // Remove cancelled runs older than 7 days
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        runs.removeAll { run in
            run.status == .cancelled && run.date < sevenDaysAgo
        }
        
        let removedCount = initialCount - runs.count
        if removedCount > 0 {
            print("Cleaned up \(removedCount) old runs")
            needsSave = true
            
            // Save after cleanup
            do {
                try saveToStorage()
            } catch {
                print("Failed to save after cleanup: \(error)")
            }
        }
    }
    
    /// Attempt data recovery when loading fails
    private func attemptDataRecovery() {
        print("Attempting data recovery...")
        
        // Try to load runs without validation first
        if let data = storage.data(forKey: runsKey) {
            do {
                let rawRuns = try decoder.decode([SchoolRun].self, from: data)
                
                // Try to salvage valid runs
                var recoveredRuns: [SchoolRun] = []
                for run in rawRuns {
                    do {
                        try validateRunData(run)
                        recoveredRuns.append(run)
                    } catch {
                        // Skip invalid runs
                        continue
                    }
                }
                
                runs = recoveredRuns
                activeRun = nil // Clear active run for safety
                
                print("Recovered \(recoveredRuns.count) valid runs out of \(rawRuns.count)")
                
                // Save recovered data
                try saveToStorage()
                
            } catch {
                print("Data recovery failed, starting with empty data: \(error)")
                runs = []
                activeRun = nil
                clearStorage()
            }
        } else {
            // No data to recover, start fresh
            runs = []
            activeRun = nil
        }
    }
    
    // MARK: - Error Handling
    
    /// Show error message
    func showError(_ message: String) {
        errorMessage = message
    }
    
    /// Show error from SchoolRunError
    func showError(_ error: SchoolRunError) {
        errorMessage = error.localizedDescription
    }
    
    /// Clear error message
    func clearError() {
        errorMessage = nil
    }
    
    // MARK: - Convenience Methods
    
    /// Get runs by status
    func getRuns(withStatus status: RunStatus) -> [SchoolRun] {
        return runs.filter { $0.status == status }
    }
    
    /// Get runs for a specific date
    func getRuns(for date: Date) -> [SchoolRun] {
        return runs.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }
    
    /// Get runs within a date range
    func getRuns(from startDate: Date, to endDate: Date) -> [SchoolRun] {
        return runs.filter { $0.date >= startDate && $0.date <= endDate }
    }
    
    /// Check if a run exists with the given ID
    func runExists(id: UUID) -> Bool {
        return runs.contains { $0.id == id }
    }
    
    /// Get the most recent run
    var mostRecentRun: SchoolRun? {
        return runs.max { $0.createdAt < $1.createdAt }
    }
    
    /// Get the next scheduled run
    var nextScheduledRun: SchoolRun? {
        return scheduledRuns.first
    }
    
    // MARK: - Testing and Debugging Methods
    
    /// Force save data (for testing)
    func forceSave() throws {
        needsSave = true
        try saveToStorage()
        try saveActiveRunToStorage()
    }
    
    /// Get data version (for testing)
    var dataVersion: Int {
        return storage.integer(forKey: dataVersionKey)
    }
    
    /// Check if data needs saving (for testing)
    var dataNeedsSave: Bool {
        return needsSave
    }
    
    /// Get storage size estimate (for debugging)
    var storageSize: Int {
        var size = 0
        
        if let runsData = storage.data(forKey: runsKey) {
            size += runsData.count
        }
        
        if let activeRunData = storage.data(forKey: activeRunKey) {
            size += activeRunData.count
        }
        
        return size
    }
    
    /// Validate current data integrity (for testing)
    func validateCurrentData() throws {
        try validateDataIntegrity()
    }
    
    /// Trigger manual cleanup (for testing)
    func triggerCleanup() {
        performCleanup()
    }
    
    /// Simulate app launch (for testing)
    func simulateAppLaunch() {
        loadFromStorage()
    }
    
    /// Simulate app background (for testing)
    func simulateAppBackground() {
        saveOnBackground()
    }
    
    // MARK: - Performance Optimization Methods
    
    /// Invalidate cached computed properties
    private func invalidateCache() {
        _todaysRuns = nil
        _upcomingRuns = nil
        _completedRuns = nil
        _scheduledRuns = nil
        _inProgressRuns = nil
        _cancelledRuns = nil
        _cacheInvalidationDate = Date()
    }
    
    /// Force cache refresh (for testing)
    func refreshCache() {
        invalidateCache()
    }
    
    /// Get cache status (for debugging)
    var cacheStatus: [String: Bool] {
        return [
            "todaysRuns": _todaysRuns != nil,
            "upcomingRuns": _upcomingRuns != nil,
            "completedRuns": _completedRuns != nil,
            "scheduledRuns": _scheduledRuns != nil,
            "inProgressRuns": _inProgressRuns != nil,
            "cancelledRuns": _cancelledRuns != nil
        ]
    }
}

// MARK: - Async Convenience Methods
extension SchoolRunManager {
    /// Async wrapper for createRun
    func createRunAsync(_ run: SchoolRun) async throws {
        try createRun(run)
    }
    
    /// Async wrapper for updateRun
    func updateRunAsync(_ run: SchoolRun) async throws {
        try updateRun(run)
    }
    
    /// Async wrapper for deleteRun
    func deleteRunAsync(id: UUID) async throws {
        try deleteRun(id: id)
    }
    
    /// Async wrapper for startRun
    func startRunAsync(id: UUID) async throws {
        try startRun(id: id)
    }
    
    /// Async wrapper for completeRun
    func completeRunAsync(id: UUID) async throws {
        try completeRun(id: id)
    }
    
    /// Async wrapper for cancelRun
    func cancelRunAsync(id: UUID) async throws {
        try cancelRun(id: id)
    }
    
    /// Async wrapper for pauseRun
    func pauseRunAsync(id: UUID) async throws {
        try pauseRun(id: id)
    }
}