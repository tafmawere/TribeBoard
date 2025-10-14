import SwiftUI
import Foundation

/// ViewModel for School Run management and display
@MainActor
class SchoolRunViewModel: ObservableObject {
    // MARK: - Published Properties
    
    /// All school runs managed by the SchoolRunManager
    @Published var runs: [SchoolRun] = []
    
    /// Loading state for async operations
    @Published var isLoading: Bool = false
    
    /// Error message for display
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    
    /// Manager for school run data operations
    private let manager: SchoolRunManager
    
    /// Error handler for comprehensive error management
    private let errorHandler: SchoolRunErrorHandler
    
    // MARK: - Computed Properties
    
    /// Today's school runs
    var todaysRuns: [SchoolRun] {
        manager.todaysRuns
    }
    
    /// Upcoming school runs (future dates, excluding today)
    var upcomingRuns: [SchoolRun] {
        manager.upcomingRuns
    }
    
    /// Completed school runs
    var completedRuns: [SchoolRun] {
        manager.completedRuns
    }
    
    /// Scheduled school runs
    var scheduledRuns: [SchoolRun] {
        manager.scheduledRuns
    }
    
    /// In-progress school runs
    var inProgressRuns: [SchoolRun] {
        manager.inProgressRuns
    }
    
    /// Currently active run
    var activeRun: SchoolRun? {
        manager.activeRun
    }
    
    /// Check if there's an active run
    var hasActiveRun: Bool {
        manager.hasActiveRun
    }
    
    /// Total number of runs
    var totalRuns: Int {
        manager.totalRuns
    }
    
    // MARK: - Initialization
    
    init(manager: SchoolRunManager? = nil, errorHandler: SchoolRunErrorHandler? = nil) {
        if let manager = manager {
            self.manager = manager
        } else {
            self.manager = SchoolRunManager()
        }
        
        if let errorHandler = errorHandler {
            self.errorHandler = errorHandler
        } else {
            self.errorHandler = SchoolRunErrorHandler()
        }
        
        setupBindings()
        loadRuns()
    }
    
    // MARK: - Public Methods
    
    /// Load all school runs from the manager (optimized)
    func loadRuns() {
        guard !isLoading else { return } // Prevent multiple simultaneous loads
        
        isLoading = true
        errorMessage = nil
        
        // Load from storage on main actor since manager requires it
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            
            // Load from manager (which loads from storage) - already on MainActor
            self.manager.loadFromStorage()
            
            // Update UI properties
            self.runs = self.manager.runs
            self.isLoading = false
        }
    }
    
    /// Create a new school run with comprehensive error handling
    func createRun(_ run: SchoolRun) async {
        isLoading = true
        errorMessage = nil
        errorHandler.clearError()
        
        do {
            // Validate run before creating
            let validationResult = SchoolRunValidation.validateRun(
                title: run.title,
                date: run.date,
                stops: run.route
            )
            
            if !validationResult.isValid {
                let validationErrors = validationResult.errors
                errorHandler.handleErrors(validationErrors, context: "Create Run")
                throw validationErrors.first ?? SchoolRunError.invalidRunData("Validation failed")
            }
            
            try await manager.createRunAsync(run)
            runs = manager.runs
            
            // Success feedback
            ToastManager.shared.success("Run '\(run.title)' created successfully!")
            
            isLoading = false
        } catch let error as SchoolRunError {
            errorHandler.handleError(error, context: "Create Run")
            errorMessage = error.userFriendlyMessage
            isLoading = false
        } catch {
            let wrappedError = SchoolRunError.unexpectedError(error.localizedDescription)
            errorHandler.handleError(wrappedError, context: "Create Run")
            errorMessage = "Failed to create run: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    /// Delete a school run with confirmation and error handling
    func deleteRun(_ run: SchoolRun) async {
        isLoading = true
        errorMessage = nil
        errorHandler.clearError()
        
        do {
            // Check if run can be deleted
            if run.status == .inProgress {
                throw SchoolRunError.invalidRunState(run.status, "delete")
            }
            
            try await manager.deleteRunAsync(id: run.id)
            runs = manager.runs
            
            // Success feedback
            ToastManager.shared.success("Run '\(run.title)' deleted")
            
            isLoading = false
        } catch let error as SchoolRunError {
            errorHandler.handleError(error, context: "Delete Run")
            errorMessage = error.userFriendlyMessage
            isLoading = false
        } catch {
            let wrappedError = SchoolRunError.unexpectedError(error.localizedDescription)
            errorHandler.handleError(wrappedError, context: "Delete Run")
            errorMessage = "Failed to delete run: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    /// Delete a run by ID with error handling
    func deleteRun(id: UUID) async {
        guard let run = getRun(id: id) else {
            let error = SchoolRunError.runNotFound(id)
            errorHandler.handleError(error, context: "Delete Run by ID")
            errorMessage = error.userFriendlyMessage
            return
        }
        
        await deleteRun(run)
    }
    
    /// Start a school run with validation and error handling
    func startRun(_ run: SchoolRun) async {
        isLoading = true
        errorMessage = nil
        errorHandler.clearError()
        
        do {
            // Check if another run is already active
            if let activeRun = manager.activeRun, activeRun.id != run.id {
                throw SchoolRunError.runAlreadyActive(activeRun.title)
            }
            
            // Check if run can be started
            if run.status != .scheduled {
                throw SchoolRunError.invalidRunState(run.status, "start")
            }
            
            // Check if run date is today or in the past
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            let runDay = calendar.startOfDay(for: run.date)
            
            if runDay > today {
                throw SchoolRunError.operationNotAllowed("Cannot start future runs")
            }
            
            try await manager.startRunAsync(id: run.id)
            runs = manager.runs
            
            // Success feedback
            ToastManager.shared.success("Run '\(run.title)' started!")
            
            isLoading = false
        } catch let error as SchoolRunError {
            errorHandler.handleError(error, context: "Start Run")
            errorMessage = error.userFriendlyMessage
            isLoading = false
        } catch {
            let wrappedError = SchoolRunError.unexpectedError(error.localizedDescription)
            errorHandler.handleError(wrappedError, context: "Start Run")
            errorMessage = "Failed to start run: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    /// Complete a school run with validation
    func completeRun(_ run: SchoolRun) async {
        isLoading = true
        errorMessage = nil
        errorHandler.clearError()
        
        do {
            // Check if run can be completed
            if run.status != .inProgress {
                throw SchoolRunError.invalidRunState(run.status, "complete")
            }
            
            try await manager.completeRunAsync(id: run.id)
            runs = manager.runs
            
            // Success feedback
            ToastManager.shared.success("Run '\(run.title)' completed!")
            
            isLoading = false
        } catch let error as SchoolRunError {
            errorHandler.handleError(error, context: "Complete Run")
            errorMessage = error.userFriendlyMessage
            isLoading = false
        } catch {
            let wrappedError = SchoolRunError.unexpectedError(error.localizedDescription)
            errorHandler.handleError(wrappedError, context: "Complete Run")
            errorMessage = "Failed to complete run: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    /// Cancel a school run with confirmation
    func cancelRun(_ run: SchoolRun) async {
        isLoading = true
        errorMessage = nil
        errorHandler.clearError()
        
        do {
            // Check if run can be cancelled
            if run.status == .completed {
                throw SchoolRunError.invalidRunState(run.status, "cancel")
            }
            
            try await manager.cancelRunAsync(id: run.id)
            runs = manager.runs
            
            // Warning feedback for cancellation
            ToastManager.shared.warning("Run '\(run.title)' cancelled")
            
            isLoading = false
        } catch let error as SchoolRunError {
            errorHandler.handleError(error, context: "Cancel Run")
            errorMessage = error.userFriendlyMessage
            isLoading = false
        } catch {
            let wrappedError = SchoolRunError.unexpectedError(error.localizedDescription)
            errorHandler.handleError(wrappedError, context: "Cancel Run")
            errorMessage = "Failed to cancel run: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    /// Get a specific run by ID
    func getRun(id: UUID) -> SchoolRun? {
        return manager.getRun(id: id)
    }
    
    /// Get runs for a specific date
    func getRuns(for date: Date) -> [SchoolRun] {
        return manager.getRuns(for: date)
    }
    
    /// Get runs within a date range
    func getRuns(from startDate: Date, to endDate: Date) -> [SchoolRun] {
        return manager.getRuns(from: startDate, to: endDate)
    }
    
    /// Clear error message and error handler state
    func clearError() {
        errorMessage = nil
        errorHandler.clearError()
    }
    
    /// Refresh runs data
    func refresh() {
        loadRuns()
    }
    
    // MARK: - Private Methods
    
    /// Setup bindings to observe manager changes (optimized)
    private func setupBindings() {
        // Observe manager's runs changes with debouncing to prevent excessive updates
        manager.$runs
            .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main)
            .removeDuplicates { oldRuns, newRuns in
                // Only update if the runs actually changed
                oldRuns.count == newRuns.count && 
                zip(oldRuns, newRuns).allSatisfy { $0.id == $1.id && $0.status == $1.status }
            }
            .assign(to: &$runs)
        
        // Observe manager's error messages
        manager.$errorMessage
            .receive(on: DispatchQueue.main)
            .assign(to: &$errorMessage)
        
        // Observe manager's loading state with debouncing
        manager.$isLoading
            .debounce(for: .milliseconds(50), scheduler: DispatchQueue.main)
            .assign(to: &$isLoading)
    }
}

