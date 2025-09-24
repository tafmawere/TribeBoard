import Foundation
import SwiftUI

/// Supporting structures for static navigation simulation
struct NavigationUpdate {
    let currentLocation: String
    let estimatedArrival: Date
    let distanceRemaining: String
    let trafficConditions: String
}

struct SimulatedLocation {
    let address: String
    let coordinates: (lat: Double, lng: Double)
    let accuracy: String
}

/// Extension for Double to round to specific decimal places
extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}

/// ObservableObject that manages school run data persistence and state management
class ScheduledSchoolRunManager: ObservableObject {
    
    // MARK: - Published Properties
    
    /// All school runs stored locally
    @Published var runs: [ScheduledSchoolRun] = []
    
    /// Current execution state for active runs
    @Published var executionStates: [UUID: RunExecutionState] = [:]
    
    /// Current stop index for runs in execution
    @Published var currentStopIndices: [UUID: Int] = [:]
    
    // MARK: - Private Properties
    
    private let userDefaults = UserDefaults.standard
    private let runsKey = "school_runs"
    private let executionStatesKey = "run_execution_states"
    private let currentStopIndicesKey = "current_stop_indices"
    
    // MARK: - Initialization
    
    init() {
        loadRuns()
        loadExecutionStates()
        loadCurrentStopIndices()
        
        // Initialize with mock data if no runs exist
        if runs.isEmpty {
            initializeWithMockData()
        }
    }
    
    // MARK: - Data Persistence Methods
    
    /// Saves all runs to UserDefaults
    func saveRuns() {
        do {
            let data = try JSONEncoder().encode(runs)
            userDefaults.set(data, forKey: runsKey)
        } catch {
            print("Failed to save runs: \(error)")
        }
    }
    
    /// Loads runs from UserDefaults
    func loadRuns() {
        guard let data = userDefaults.data(forKey: runsKey) else { return }
        
        do {
            runs = try JSONDecoder().decode([ScheduledSchoolRun].self, from: data)
        } catch {
            print("Failed to load runs: \(error)")
            runs = []
        }
    }
    
    /// Saves execution states to UserDefaults
    private func saveExecutionStates() {
        do {
            let data = try JSONEncoder().encode(executionStates)
            userDefaults.set(data, forKey: executionStatesKey)
        } catch {
            print("Failed to save execution states: \(error)")
        }
    }
    
    /// Loads execution states from UserDefaults
    private func loadExecutionStates() {
        guard let data = userDefaults.data(forKey: executionStatesKey) else { return }
        
        do {
            executionStates = try JSONDecoder().decode([UUID: RunExecutionState].self, from: data)
        } catch {
            print("Failed to load execution states: \(error)")
            executionStates = [:]
        }
    }
    
    /// Saves current stop indices to UserDefaults
    private func saveCurrentStopIndices() {
        do {
            let data = try JSONEncoder().encode(currentStopIndices)
            userDefaults.set(data, forKey: currentStopIndicesKey)
        } catch {
            print("Failed to save current stop indices: \(error)")
        }
    }
    
    /// Loads current stop indices from UserDefaults
    private func loadCurrentStopIndices() {
        guard let data = userDefaults.data(forKey: currentStopIndicesKey) else { return }
        
        do {
            currentStopIndices = try JSONDecoder().decode([UUID: Int].self, from: data)
        } catch {
            print("Failed to load current stop indices: \(error)")
            currentStopIndices = [:]
        }
    }
    
    // MARK: - Run Management Methods
    
    /// Creates a new school run and saves it
    func createRun(_ run: ScheduledSchoolRun) {
        runs.append(run)
        executionStates[run.id] = .notStarted
        currentStopIndices[run.id] = 0
        saveRuns()
        saveExecutionStates()
        saveCurrentStopIndices()
    }
    
    /// Updates an existing school run
    func updateRun(_ run: ScheduledSchoolRun) {
        if let index = runs.firstIndex(where: { $0.id == run.id }) {
            runs[index] = run
            saveRuns()
        }
    }
    
    /// Deletes a school run by ID
    func deleteRun(withId id: UUID) {
        runs.removeAll { $0.id == id }
        executionStates.removeValue(forKey: id)
        currentStopIndices.removeValue(forKey: id)
        saveRuns()
        saveExecutionStates()
        saveCurrentStopIndices()
    }
    
    /// Deletes multiple runs by IDs
    func deleteRuns(withIds ids: [UUID]) {
        runs.removeAll { ids.contains($0.id) }
        for id in ids {
            executionStates.removeValue(forKey: id)
            currentStopIndices.removeValue(forKey: id)
        }
        saveRuns()
        saveExecutionStates()
        saveCurrentStopIndices()
    }
    
    /// Gets a specific run by ID
    func getRun(withId id: UUID) -> ScheduledSchoolRun? {
        return runs.first { $0.id == id }
    }
    
    // MARK: - Run Execution State Management
    
    /// Gets the execution state for a specific run
    func getExecutionState(for runId: UUID) -> RunExecutionState {
        return executionStates[runId] ?? .notStarted
    }
    
    /// Updates the execution state for a specific run
    func updateExecutionState(for runId: UUID, to state: RunExecutionState) {
        executionStates[runId] = state
        saveExecutionStates()
    }
    
    /// Gets the current stop index for a specific run
    func getCurrentStopIndex(for runId: UUID) -> Int {
        return currentStopIndices[runId] ?? 0
    }
    
    /// Updates the current stop index for a specific run
    func updateCurrentStopIndex(for runId: UUID, to index: Int) {
        currentStopIndices[runId] = index
        saveCurrentStopIndices()
    }
    
    /// Advances to the next stop in a run
    func advanceToNextStop(for runId: UUID) -> Bool {
        guard let run = getRun(withId: runId) else { return false }
        
        let currentIndex = getCurrentStopIndex(for: runId)
        let nextIndex = currentIndex + 1
        
        if nextIndex < run.stops.count {
            updateCurrentStopIndex(for: runId, to: nextIndex)
            return true
        } else {
            // Run completed
            updateExecutionState(for: runId, to: .completed)
            markRunAsCompleted(runId)
            return false
        }
    }
    
    /// Marks a run as completed
    private func markRunAsCompleted(_ runId: UUID) {
        if let index = runs.firstIndex(where: { $0.id == runId }) {
            runs[index].isCompleted = true
            saveRuns()
        }
    }
    
    /// Starts execution of a run
    func startRun(withId runId: UUID) {
        updateExecutionState(for: runId, to: .active)
        updateCurrentStopIndex(for: runId, to: 0)
    }
    
    /// Pauses execution of a run
    func pauseRun(withId runId: UUID) {
        updateExecutionState(for: runId, to: .paused)
    }
    
    /// Resumes execution of a run
    func resumeRun(withId runId: UUID) {
        updateExecutionState(for: runId, to: .active)
    }
    
    /// Cancels execution of a run
    func cancelRun(withId runId: UUID) {
        updateExecutionState(for: runId, to: .cancelled)
        updateCurrentStopIndex(for: runId, to: 0)
    }
    
    /// Completes execution of a run
    func completeRun(withId runId: UUID) {
        updateExecutionState(for: runId, to: .completed)
        markRunAsCompleted(runId)
    }
    
    // MARK: - Filtering Methods
    
    /// Returns upcoming runs (scheduled for future dates and not completed)
    var upcomingRuns: [ScheduledSchoolRun] {
        let now = Date()
        return runs.filter { run in
            !run.isCompleted && 
            Calendar.current.compare(run.scheduledDate, to: now, toGranularity: .day) != .orderedAscending
        }.sorted { $0.scheduledDate < $1.scheduledDate }
    }
    
    /// Returns past runs (completed or scheduled for past dates)
    var pastRuns: [ScheduledSchoolRun] {
        let now = Date()
        return runs.filter { run in
            run.isCompleted || 
            Calendar.current.compare(run.scheduledDate, to: now, toGranularity: .day) == .orderedAscending
        }.sorted { $0.scheduledDate > $1.scheduledDate }
    }
    
    /// Returns all runs sorted by scheduled date (upcoming first, then past)
    var allRunsSorted: [ScheduledSchoolRun] {
        return runs.sorted { run1, run2 in
            // Upcoming runs first, then past runs
            let now = Date()
            let run1IsUpcoming = !run1.isCompleted && Calendar.current.compare(run1.scheduledDate, to: now, toGranularity: .day) != .orderedAscending
            let run2IsUpcoming = !run2.isCompleted && Calendar.current.compare(run2.scheduledDate, to: now, toGranularity: .day) != .orderedAscending
            
            if run1IsUpcoming && !run2IsUpcoming {
                return true
            } else if !run1IsUpcoming && run2IsUpcoming {
                return false
            } else {
                return run1.scheduledDate < run2.scheduledDate
            }
        }
    }
    
    /// Returns runs currently in execution (active or paused)
    var runsInExecution: [ScheduledSchoolRun] {
        return runs.filter { run in
            let state = getExecutionState(for: run.id)
            return state == .active || state == .paused
        }
    }
    
    /// Returns runs scheduled for today
    var todaysRuns: [ScheduledSchoolRun] {
        let today = Date()
        return runs.filter { run in
            Calendar.current.isDate(run.scheduledDate, inSameDayAs: today)
        }.sorted { $0.scheduledTime < $1.scheduledTime }
    }
    
    // MARK: - Progress Tracking
    
    /// Gets the progress percentage for a run (0.0 to 1.0)
    func getProgress(for runId: UUID) -> Double {
        guard let run = getRun(withId: runId) else { return 0.0 }
        
        let currentIndex = getCurrentStopIndex(for: runId)
        let totalStops = run.stops.count
        
        guard totalStops > 0 else { return 0.0 }
        
        let state = getExecutionState(for: runId)
        if state == .completed {
            return 1.0
        } else if state == .notStarted {
            return 0.0
        } else {
            return Double(currentIndex) / Double(totalStops)
        }
    }
    
    /// Gets the current stop for a run in execution
    func getCurrentStop(for runId: UUID) -> RunStop? {
        guard let run = getRun(withId: runId) else { return nil }
        
        let currentIndex = getCurrentStopIndex(for: runId)
        guard currentIndex < run.stops.count else { return nil }
        
        return run.stops[currentIndex]
    }
    
    /// Gets the remaining stops for a run in execution
    func getRemainingStops(for runId: UUID) -> [RunStop] {
        guard let run = getRun(withId: runId) else { return [] }
        
        let currentIndex = getCurrentStopIndex(for: runId)
        guard currentIndex < run.stops.count else { return [] }
        
        return Array(run.stops.dropFirst(currentIndex + 1))
    }
    
    // MARK: - Utility Methods
    
    /// Initializes the manager with mock data for demonstration
    private func initializeWithMockData() {
        // Use comprehensive demo dataset
        runs = StaticDataGenerator.createDemoDataset()
        
        // Initialize execution states for all runs
        for run in runs {
            executionStates[run.id] = run.isCompleted ? .completed : .notStarted
            currentStopIndices[run.id] = 0
        }
        
        saveRuns()
        saveExecutionStates()
        saveCurrentStopIndices()
    }
    
    /// Simulates GPS navigation updates for demonstration purposes
    func simulateNavigationUpdate(for runId: UUID) -> NavigationUpdate? {
        guard let run = getRun(withId: runId),
              let currentStop = getCurrentStop(for: runId) else { return nil }
        
        let currentIndex = getCurrentStopIndex(for: runId)
        let progress = Double(currentIndex) / Double(run.stops.count)
        
        return NavigationUpdate(
            currentLocation: "En route to \(currentStop.name)",
            estimatedArrival: Date().addingTimeInterval(TimeInterval(currentStop.estimatedMinutes * 60)),
            distanceRemaining: "\(Double.random(in: 0.5...3.0).rounded(toPlaces: 1)) miles",
            trafficConditions: ["Light traffic", "Moderate traffic", "Heavy traffic"].randomElement() ?? "Normal traffic"
        )
    }
    
    /// Simulates real-time location updates for static demonstration
    func getSimulatedLocation() -> SimulatedLocation {
        return SimulatedLocation(
            address: "Current Location",
            coordinates: (lat: 37.7749, lng: -122.4194),
            accuracy: "±5 meters"
        )
    }
    
    /// Clears all data (useful for testing)
    func clearAllData() {
        runs.removeAll()
        executionStates.removeAll()
        currentStopIndices.removeAll()
        
        userDefaults.removeObject(forKey: runsKey)
        userDefaults.removeObject(forKey: executionStatesKey)
        userDefaults.removeObject(forKey: currentStopIndicesKey)
    }
    
    /// Resets to mock data
    func resetToMockData() {
        clearAllData()
        initializeWithMockData()
    }
    
    /// Generates fresh demo data for testing
    func generateFreshDemoData() {
        StaticDataGenerator.resetToFreshDemoData()
        initializeWithMockData()
    }
}