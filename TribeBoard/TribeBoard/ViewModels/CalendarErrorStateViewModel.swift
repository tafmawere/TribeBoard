import SwiftUI
import Foundation

/// ViewModel for managing calendar error states with recovery options and user guidance
@MainActor
class CalendarErrorStateViewModel: ObservableObject {
    
    // MARK: - Properties
    
    @Published var currentError: CalendarError?
    @Published var errorContext: CalendarErrorContext?
    @Published var isShowingError = false
    @Published var isRecovering = false
    @Published var recoveryProgress: Double = 0.0
    @Published var recoveryMessage: String = ""
    @Published var availableRecoveryOptions: [CalendarErrorRecoveryOption] = []
    @Published var errorHistory: [CalendarErrorLogEntry] = []
    @Published var showErrorDetails = false
    
    private let errorLogger = CalendarErrorLogger.shared
    private let recoveryService: CalendarErrorRecoveryService
    private var retryAction: (() async throws -> Void)?
    
    // MARK: - Initialization
    
    init(recoveryService: CalendarErrorRecoveryService) {
        self.recoveryService = recoveryService
        setupErrorObservation()
    }
    
    // MARK: - Error Handling Methods
    
    /// Presents an error with recovery options
    func presentError(
        _ error: CalendarError,
        context: CalendarErrorContext? = nil,
        retryAction: (() async throws -> Void)? = nil
    ) {
        self.currentError = error
        self.errorContext = context
        self.retryAction = retryAction
        self.isShowingError = true
        self.showErrorDetails = false
        
        // Log the error
        if let context = context {
            errorLogger.logError(error, context: context)
        }
        
        // Get recovery options
        self.availableRecoveryOptions = recoveryService.getRecoveryOptions(for: error)
        
        // Update error history
        refreshErrorHistory()
        
        print("🚨 CalendarErrorStateViewModel: Presenting error - \(error.localizedDescription)")
    }
    
    /// Dismisses the current error
    func dismissError() {
        currentError = nil
        errorContext = nil
        retryAction = nil
        isShowingError = false
        availableRecoveryOptions = []
        
        print("✅ CalendarErrorStateViewModel: Error dismissed")
    }
    
    /// Attempts to recover from the current error
    func recoverFromError() async {
        guard let error = currentError,
              let context = errorContext else {
            return
        }
        
        isRecovering = true
        
        do {
            try await recoveryService.recoverFromError(
                error,
                context: context,
                retryAction: retryAction
            )
            
            // Recovery successful - dismiss error
            dismissError()
            
        } catch {
            // Recovery failed - update with new error
            if let calendarError = error as? CalendarError {
                presentError(calendarError, context: context, retryAction: retryAction)
            } else {
                let wrappedError = CalendarError.databaseOperationFailed(
                    operation: "error recovery",
                    error: error.localizedDescription
                )
                presentError(wrappedError, context: context, retryAction: retryAction)
            }
        }
        
        isRecovering = false
    }
    
    /// Executes a specific recovery action
    func executeRecoveryAction(_ option: CalendarErrorRecoveryOption) async {
        guard let error = currentError,
              let context = errorContext else {
            return
        }
        
        isRecovering = true
        
        do {
            try await recoveryService.executeRecoveryAction(
                option.action,
                for: error,
                context: context
            )
            
            // If automated recovery, dismiss error on success
            if option.isAutomated {
                dismissError()
            }
            
        } catch {
            // Recovery action failed
            if let calendarError = error as? CalendarError {
                presentError(calendarError, context: context, retryAction: retryAction)
            }
        }
        
        isRecovering = false
    }
    
    /// Retries the failed operation
    func retryOperation() async {
        guard let retryAction = retryAction else {
            return
        }
        
        isRecovering = true
        
        do {
            try await retryAction()
            dismissError()
        } catch {
            // Retry failed - present new error
            if let calendarError = error as? CalendarError {
                presentError(calendarError, context: errorContext, retryAction: retryAction)
            } else {
                let wrappedError = CalendarError.databaseOperationFailed(
                    operation: "retry operation",
                    error: error.localizedDescription
                )
                presentError(wrappedError, context: errorContext, retryAction: retryAction)
            }
        }
        
        isRecovering = false
    }
    
    /// Toggles error details visibility
    func toggleErrorDetails() {
        showErrorDetails.toggle()
    }
    
    /// Refreshes error history from logger
    func refreshErrorHistory() {
        errorHistory = errorLogger.getErrorHistory(limit: 50)
    }
    
    /// Clears error history
    func clearErrorHistory() {
        errorLogger.clearErrorHistory()
        refreshErrorHistory()
    }
    
    /// Gets error statistics
    func getErrorStatistics() -> CalendarErrorStats {
        return errorLogger.getErrorStats()
    }
    
    /// Gets error analysis
    func getErrorAnalysis() -> CalendarErrorAnalysis {
        return errorLogger.analyzeErrorPatterns()
    }
    
    // MARK: - Error Categorization
    
    /// Determines if an error should be shown to the user
    func shouldShowError(_ error: CalendarError) -> Bool {
        switch error.severity {
        case .low:
            return false // Log only, don't show to user
        case .medium, .high, .critical:
            return true
        }
    }
    
    /// Gets user-friendly error message
    func getUserFriendlyMessage(for error: CalendarError) -> String {
        switch error.category {
        case .validation:
            return "Please check your input and try again."
        case .permission:
            return "You don't have permission to perform this action."
        case .sync:
            return "There was a problem syncing with Apple Calendar."
        case .network:
            return "Please check your internet connection."
        case .data:
            return "There was a problem with your data."
        case .businessLogic:
            return "This action cannot be completed right now."
        case .configuration:
            return "There's a configuration issue that needs attention."
        }
    }
    
    /// Gets appropriate icon for error category
    func getErrorIcon(for error: CalendarError) -> String {
        return error.category.icon
    }
    
    /// Gets appropriate color for error severity
    func getErrorColor(for error: CalendarError) -> Color {
        switch error.severity {
        case .low:
            return .blue
        case .medium:
            return .orange
        case .high:
            return .red
        case .critical:
            return .purple
        }
    }
    
    // MARK: - Private Methods
    
    private func setupErrorObservation() {
        // Observe recovery service progress
        recoveryService.$isRecovering
            .assign(to: &$isRecovering)
        
        recoveryService.$recoveryProgress
            .assign(to: &$recoveryProgress)
        
        recoveryService.$recoveryMessage
            .assign(to: &$recoveryMessage)
    }
}

// MARK: - Error Presentation Helpers

extension CalendarErrorStateViewModel {
    
    /// Creates a validation error presentation
    static func validationError(
        _ error: CalendarError,
        field: String,
        recoveryService: CalendarErrorRecoveryService
    ) -> CalendarErrorStateViewModel {
        let viewModel = CalendarErrorStateViewModel(recoveryService: recoveryService)
        let context = CalendarErrorContext(
            operation: "validate \(field)",
            additionalInfo: ["field": field]
        )
        viewModel.presentError(error, context: context)
        return viewModel
    }
    
    /// Creates a permission error presentation
    static func permissionError(
        _ error: CalendarError,
        userId: String,
        operation: String,
        recoveryService: CalendarErrorRecoveryService
    ) -> CalendarErrorStateViewModel {
        let viewModel = CalendarErrorStateViewModel(recoveryService: recoveryService)
        let context = CalendarErrorContext(
            userId: userId,
            operation: operation
        )
        viewModel.presentError(error, context: context)
        return viewModel
    }
    
    /// Creates a sync error presentation with retry
    static func syncError(
        _ error: CalendarError,
        userId: String,
        eventId: String,
        retryAction: @escaping () async throws -> Void,
        recoveryService: CalendarErrorRecoveryService
    ) -> CalendarErrorStateViewModel {
        let viewModel = CalendarErrorStateViewModel(recoveryService: recoveryService)
        let context = CalendarErrorContext(
            userId: userId,
            eventId: eventId,
            operation: "sync event"
        )
        viewModel.presentError(error, context: context, retryAction: retryAction)
        return viewModel
    }
    
    /// Creates a network error presentation with retry
    static func networkError(
        _ error: CalendarError,
        operation: String,
        retryAction: @escaping () async throws -> Void,
        recoveryService: CalendarErrorRecoveryService
    ) -> CalendarErrorStateViewModel {
        let viewModel = CalendarErrorStateViewModel(recoveryService: recoveryService)
        let context = CalendarErrorContext(
            operation: operation
        )
        viewModel.presentError(error, context: context, retryAction: retryAction)
        return viewModel
    }
}