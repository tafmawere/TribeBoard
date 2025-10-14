import Foundation
import SwiftUI

/// View model for managing live school run execution
/// 
/// This view model handles the execution of an active school run, including:
/// - Current stop tracking and progress calculation
/// - Next stop navigation and run completion logic
/// - Pause/resume functionality for runs
/// - Haptic feedback integration for user actions
///
/// Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6
@MainActor
class ActiveRunViewModel: ObservableObject {
    // MARK: - Published Properties
    
    /// The currently active school run
    @Published var currentRun: SchoolRun?
    
    /// Index of the current stop in the route
    @Published var currentStopIndex: Int = 0
    
    /// Whether the run is currently active/running
    @Published var isRunning: Bool = false
    
    /// Whether the run is paused
    @Published var isPaused: Bool = false
    
    /// Loading state for async operations
    @Published var isLoading: Bool = false
    
    /// Error message for display
    @Published var errorMessage: String?
    
    /// Whether to show completion confirmation
    @Published var showingCompletionConfirmation: Bool = false
    
    /// Whether to show cancellation confirmation
    @Published var showingCancellationConfirmation: Bool = false
    
    // MARK: - Dependencies
    
    private let runManager: SchoolRunManager
    private let hapticManager: HapticManager
    private let errorHandler: SchoolRunErrorHandler
    
    // MARK: - Computed Properties
    
    /// Current stop in the route (if any)
    var currentStop: RunStop? {
        guard let run = currentRun,
              currentStopIndex < run.route.count else {
            return nil
        }
        return run.route[currentStopIndex]
    }
    
    /// Next stop in the route (if any)
    var nextStop: RunStop? {
        guard let run = currentRun,
              currentStopIndex + 1 < run.route.count else {
            return nil
        }
        return run.route[currentStopIndex + 1]
    }
    
    /// Progress through the run (0.0 to 1.0)
    var progress: Double {
        guard let run = currentRun, !run.route.isEmpty else {
            return 0.0
        }
        return Double(currentStopIndex) / Double(run.route.count)
    }
    
    /// Percentage progress for display
    var progressPercentage: Int {
        Int(progress * 100)
    }
    
    /// Number of completed stops
    var completedStopsCount: Int {
        currentStopIndex
    }
    
    /// Total number of stops
    var totalStopsCount: Int {
        currentRun?.route.count ?? 0
    }
    
    /// Remaining stops count
    var remainingStopsCount: Int {
        totalStopsCount - completedStopsCount
    }
    
    /// Whether this is the last stop
    var isLastStop: Bool {
        guard let run = currentRun else { return false }
        return currentStopIndex >= run.route.count - 1
    }
    
    /// Whether there are more stops after current
    var hasNextStop: Bool {
        !isLastStop
    }
    
    /// Estimated time remaining (placeholder calculation)
    var estimatedTimeRemaining: TimeInterval {
        guard let run = currentRun, currentStopIndex < run.route.count else {
            return 0
        }
        
        // Simple calculation: assume 5 minutes per remaining stop
        let remainingStops = run.route.count - currentStopIndex
        return TimeInterval(remainingStops * 5 * 60) // 5 minutes per stop
    }
    
    /// Formatted estimated time remaining
    var formattedTimeRemaining: String {
        let minutes = Int(estimatedTimeRemaining / 60)
        if minutes < 60 {
            return "\(minutes) min"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return "\(hours)h \(remainingMinutes)m"
        }
    }
    
    /// Whether the run can be paused
    var canPause: Bool {
        isRunning && !isPaused
    }
    
    /// Whether the run can be resumed
    var canResume: Bool {
        isPaused
    }
    
    /// Whether the run can be completed
    var canComplete: Bool {
        isRunning && isLastStop
    }
    
    /// Whether the run can be cancelled
    var canCancel: Bool {
        isRunning || isPaused
    }
    
    // MARK: - Initialization
    
    @MainActor
    init(
        runManager: SchoolRunManager? = nil,
        hapticManager: HapticManager? = nil,
        errorHandler: SchoolRunErrorHandler? = nil
    ) {
        self.runManager = runManager ?? SchoolRunManager()
        self.hapticManager = hapticManager ?? HapticManager.shared
        self.errorHandler = errorHandler ?? SchoolRunErrorHandler()
        
        // Load active run if available
        loadActiveRun()
    }
    
    // MARK: - Public Methods
    
    /// Load the currently active run from the manager
    func loadActiveRun() {
        currentRun = runManager.activeRun
        
        if let run = currentRun {
            isRunning = run.status == .inProgress
            
            // Find current stop index based on completed stops
            currentStopIndex = run.route.firstIndex { !$0.isCompleted } ?? run.route.count
            
            // If all stops are completed but run is still in progress, set to last stop
            if currentStopIndex >= run.route.count && isRunning {
                currentStopIndex = max(0, run.route.count - 1)
            }
        } else {
            isRunning = false
            isPaused = false
            currentStopIndex = 0
        }
        
        clearError()
    }
    
    /// Start a run with the given ID
    func startRun(id: UUID) async {
        isLoading = true
        clearError()
        
        do {
            // Trigger haptic feedback for starting (respects accessibility settings)
            SchoolRunHapticFeedback.runStarted()
            
            try await runManager.startRunAsync(id: id)
            
            // Load the newly started run
            loadActiveRun()
            
            // Success haptic feedback
            SchoolRunHapticFeedback.saveSuccessful()
            
        } catch {
            handleError(error, context: "Start Run")
            SchoolRunHapticFeedback.errorOccurred()
        }
        
        isLoading = false
    }
    
    /// Move to the next stop in the route
    func moveToNextStop() {
        guard let run = currentRun,
              currentStopIndex < run.route.count else {
            return
        }
        
        // Trigger haptic feedback for progression (respects accessibility settings)
        SchoolRunHapticFeedback.stopProgressed()
        
        do {
            // Mark current stop as completed
            let currentStopId = run.route[currentStopIndex].id
            try runManager.completeStop(stopId: currentStopId)
            
            // Move to next stop
            currentStopIndex += 1
            
            // Reload the run to get updated data
            loadActiveRun()
            
            // Success haptic feedback for stop completion
            SchoolRunHapticFeedback.stopCompleted()
            
        } catch {
            handleError(error, context: "Next Stop")
            SchoolRunHapticFeedback.errorOccurred()
        }
    }
    
    /// Complete the current run
    func completeRun() {
        guard let run = currentRun else { return }
        
        showingCompletionConfirmation = true
    }
    
    /// Confirm completion of the run
    func confirmCompleteRun() async {
        guard let run = currentRun else { return }
        
        isLoading = true
        showingCompletionConfirmation = false
        
        do {
            try await runManager.completeRunAsync(id: run.id)
            
            // Clear active run state
            currentRun = nil
            isRunning = false
            isPaused = false
            currentStopIndex = 0
            
            // Success haptic feedback for run completion (respects accessibility settings)
            SchoolRunHapticFeedback.runCompleted()
            
        } catch {
            handleError(error)
            SchoolRunHapticFeedback.errorOccurred()
        }
        
        isLoading = false
    }
    
    /// Pause the current run
    func pauseRun() async {
        guard let run = currentRun else { return }
        
        isLoading = true
        
        do {
            try await runManager.pauseRunAsync(id: run.id)
            
            // Update local state
            isPaused = true
            isRunning = false
            
            // Reload run data
            loadActiveRun()
            
            // Haptic feedback for run state change (respects accessibility settings)
            SchoolRunHapticFeedback.runStateChanged()
            
        } catch {
            handleError(error)
            SchoolRunHapticFeedback.errorOccurred()
        }
        
        isLoading = false
    }
    
    /// Resume the current run
    func resumeRun() async {
        guard let run = currentRun else { return }
        
        isLoading = true
        
        do {
            try await runManager.startRunAsync(id: run.id)
            
            // Update local state
            isPaused = false
            isRunning = true
            
            // Reload run data
            loadActiveRun()
            
            // Haptic feedback for run state change (respects accessibility settings)
            SchoolRunHapticFeedback.runStateChanged()
            
        } catch {
            handleError(error)
            SchoolRunHapticFeedback.errorOccurred()
        }
        
        isLoading = false
    }
    
    /// Cancel the current run
    func cancelRun() {
        showingCancellationConfirmation = true
    }
    
    /// Confirm cancellation of the run
    func confirmCancelRun() async {
        guard let run = currentRun else { return }
        
        isLoading = true
        showingCancellationConfirmation = false
        
        do {
            try await runManager.cancelRunAsync(id: run.id)
            
            // Clear active run state
            currentRun = nil
            isRunning = false
            isPaused = false
            currentStopIndex = 0
            
            // Haptic feedback for run cancellation (respects accessibility settings)
            SchoolRunHapticFeedback.runCancelled()
            
        } catch {
            handleError(error)
            SchoolRunHapticFeedback.errorOccurred()
        }
        
        isLoading = false
    }
    
    /// Skip to a specific stop (for testing/debugging)
    func skipToStop(index: Int) {
        guard let run = currentRun,
              index >= 0 && index < run.route.count else {
            return
        }
        
        // Mark all previous stops as completed
        var updatedRun = run
        for i in 0..<index {
            updatedRun.route[i].isCompleted = true
        }
        
        do {
            try runManager.updateRun(updatedRun)
            currentStopIndex = index
            loadActiveRun()
            
            // Haptic feedback for navigation action (respects accessibility settings)
            SchoolRunHapticFeedback.navigationAction()
            
        } catch {
            handleError(error)
            SchoolRunHapticFeedback.errorOccurred()
        }
    }
    
    /// Get stop at specific index
    func getStop(at index: Int) -> RunStop? {
        guard let run = currentRun,
              index >= 0 && index < run.route.count else {
            return nil
        }
        return run.route[index]
    }
    
    /// Check if stop at index is completed
    func isStopCompleted(at index: Int) -> Bool {
        return getStop(at: index)?.isCompleted ?? false
    }
    
    /// Get all completed stops
    var completedStops: [RunStop] {
        currentRun?.route.filter(\.isCompleted) ?? []
    }
    
    /// Get all remaining stops
    var remainingStops: [RunStop] {
        guard let run = currentRun else { return [] }
        return Array(run.route.dropFirst(currentStopIndex))
    }
    
    // MARK: - Private Methods
    
    /// Handle errors from operations with comprehensive error management
    private func handleError(_ error: Error, context: String = "") {
        if let schoolRunError = error as? SchoolRunError {
            errorHandler.handleError(schoolRunError, context: context)
            errorMessage = schoolRunError.userFriendlyMessage
        } else {
            let schoolRunError = SchoolRunError.unexpectedError(error.localizedDescription)
            errorHandler.handleError(schoolRunError, context: context)
            errorMessage = schoolRunError.userFriendlyMessage
        }
    }
    
    /// Clear error state
    private func clearError() {
        errorMessage = nil
        errorHandler.clearError()
    }
    
    // MARK: - Refresh Methods
    
    /// Refresh the current run data
    func refreshRun() {
        loadActiveRun()
    }
    
    /// Force reload from manager
    func forceReload() {
        runManager.loadFromStorage()
        loadActiveRun()
    }
}

// MARK: - Preview Support
extension ActiveRunViewModel {
    /// Create a view model with mock data for previews
    static func preview(with run: SchoolRun? = nil) -> ActiveRunViewModel {
        let viewModel = ActiveRunViewModel()
        
        if let run = run {
            viewModel.currentRun = run
            viewModel.isRunning = run.status == .inProgress
            viewModel.currentStopIndex = run.route.firstIndex { !$0.isCompleted } ?? 0
        }
        
        return viewModel
    }
}