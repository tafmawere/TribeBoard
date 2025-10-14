import Foundation
import os.log

/// Comprehensive errors that can occur during school run operations
enum SchoolRunError: LocalizedError, Equatable {
    // MARK: - Validation Errors
    case invalidRunTitle(String)
    case invalidRunDate(String)
    case invalidStopData(String)
    case duplicateStopNames
    case insufficientStops
    case invalidStopTiming(String)
    case stopTimeConflict(String)
    
    // MARK: - Data Errors
    case runNotFound(UUID)
    case stopNotFound(UUID)
    case invalidRunData(String)
    case dataCorruption(String)
    case storageError(String)
    case serializationError(String)
    
    // MARK: - State Errors
    case runAlreadyActive(String)
    case noActiveRun
    case invalidRunState(RunStatus, String)
    case operationNotAllowed(String)
    case concurrentModification
    
    // MARK: - System Errors
    case networkUnavailable
    case insufficientStorage
    case permissionDenied
    case unexpectedError(String)
    
    // MARK: - User Errors
    case userCancelled
    case invalidUserInput(String)
    case operationTimeout
    
    var errorDescription: String? {
        switch self {
        // Validation Errors
        case .invalidRunTitle(let details):
            return "Invalid run title: \(details)"
        case .invalidRunDate(let details):
            return "Invalid run date: \(details)"
        case .invalidStopData(let details):
            return "Invalid stop information: \(details)"
        case .duplicateStopNames:
            return "Duplicate stop names are not allowed"
        case .insufficientStops:
            return "At least one stop is required"
        case .invalidStopTiming(let details):
            return "Invalid stop timing: \(details)"
        case .stopTimeConflict(let details):
            return "Stop time conflict: \(details)"
            
        // Data Errors
        case .runNotFound(let id):
            return "School run not found (ID: \(id.uuidString.prefix(8)))"
        case .stopNotFound(let id):
            return "Stop not found (ID: \(id.uuidString.prefix(8)))"
        case .invalidRunData(let details):
            return "Invalid run data: \(details)"
        case .dataCorruption(let details):
            return "Data corruption detected: \(details)"
        case .storageError(let details):
            return "Storage error: \(details)"
        case .serializationError(let details):
            return "Data serialization error: \(details)"
            
        // State Errors
        case .runAlreadyActive(let runTitle):
            return "Another run '\(runTitle)' is already in progress"
        case .noActiveRun:
            return "No active run found"
        case .invalidRunState(let status, let operation):
            return "Cannot \(operation) - run is \(status.displayText.lowercased())"
        case .operationNotAllowed(let reason):
            return "Operation not allowed: \(reason)"
        case .concurrentModification:
            return "Run was modified by another process"
            
        // System Errors
        case .networkUnavailable:
            return "Network connection unavailable"
        case .insufficientStorage:
            return "Insufficient storage space"
        case .permissionDenied:
            return "Permission denied"
        case .unexpectedError(let message):
            return "Unexpected error: \(message)"
            
        // User Errors
        case .userCancelled:
            return "Operation cancelled by user"
        case .invalidUserInput(let details):
            return "Invalid input: \(details)"
        case .operationTimeout:
            return "Operation timed out"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        // Validation Errors
        case .invalidRunTitle:
            return "Enter a title between 3-50 characters"
        case .invalidRunDate:
            return "Select a date from today onwards"
        case .invalidStopData:
            return "Check stop name, time, and type are valid"
        case .duplicateStopNames:
            return "Use unique names for each stop"
        case .insufficientStops:
            return "Add at least one stop to the run"
        case .invalidStopTiming:
            return "Ensure stops are at least 5 minutes apart"
        case .stopTimeConflict:
            return "Adjust stop times to avoid conflicts"
            
        // Data Errors
        case .runNotFound, .stopNotFound:
            return "Refresh the list and try again"
        case .invalidRunData, .dataCorruption:
            return "Try restarting the app or recreate the run"
        case .storageError:
            return "Check available storage and try again"
        case .serializationError:
            return "Try saving again or restart the app"
            
        // State Errors
        case .runAlreadyActive:
            return "Complete or cancel the current run first"
        case .noActiveRun:
            return "Start a run before performing this action"
        case .invalidRunState:
            return "Wait for the run to reach the correct state"
        case .operationNotAllowed:
            return "Try a different action or check run status"
        case .concurrentModification:
            return "Refresh and try the operation again"
            
        // System Errors
        case .networkUnavailable:
            return "Check your internet connection"
        case .insufficientStorage:
            return "Free up storage space and try again"
        case .permissionDenied:
            return "Check app permissions in Settings"
        case .unexpectedError:
            return "Try again or restart the app"
            
        // User Errors
        case .userCancelled:
            return nil
        case .invalidUserInput:
            return "Check your input and try again"
        case .operationTimeout:
            return "Try the operation again"
        }
    }
    
    /// User-friendly message for display in UI
    var userFriendlyMessage: String {
        switch self {
        case .invalidRunTitle:
            return "Please enter a valid run title"
        case .invalidRunDate:
            return "Please select a valid date"
        case .invalidStopData, .duplicateStopNames, .insufficientStops, .invalidStopTiming, .stopTimeConflict:
            return "Please check your stop information"
        case .runNotFound, .stopNotFound:
            return "Item not found"
        case .runAlreadyActive:
            return "Another run is already active"
        case .noActiveRun:
            return "No active run"
        case .storageError, .dataCorruption, .serializationError:
            return "Unable to save data"
        case .networkUnavailable:
            return "No internet connection"
        case .userCancelled:
            return "Operation cancelled"
        default:
            return errorDescription ?? "An error occurred"
        }
    }
    
    /// Error category for handling and logging
    var category: ErrorCategory {
        switch self {
        case .invalidRunTitle, .invalidRunDate, .invalidStopData, .duplicateStopNames, .insufficientStops, .invalidStopTiming, .stopTimeConflict, .invalidUserInput:
            return .validation
        case .runNotFound, .stopNotFound, .invalidRunData, .dataCorruption, .storageError, .serializationError:
            return .data
        case .runAlreadyActive, .noActiveRun, .invalidRunState, .operationNotAllowed, .concurrentModification:
            return .state
        case .networkUnavailable:
            return .network
        case .insufficientStorage, .permissionDenied, .unexpectedError:
            return .system
        case .userCancelled, .operationTimeout:
            return .user
        }
    }
    
    /// Error severity level
    var severity: ErrorSeverity {
        switch self {
        case .invalidRunTitle, .invalidRunDate, .invalidStopData, .duplicateStopNames, .insufficientStops, .invalidStopTiming, .stopTimeConflict, .invalidUserInput:
            return .low
        case .runNotFound, .stopNotFound, .runAlreadyActive, .noActiveRun, .invalidRunState, .operationNotAllowed, .userCancelled:
            return .medium
        case .invalidRunData, .dataCorruption, .concurrentModification, .networkUnavailable, .operationTimeout:
            return .high
        case .storageError, .serializationError, .insufficientStorage, .permissionDenied, .unexpectedError:
            return .critical
        }
    }
    
    /// Whether this error can be retried
    var isRetryable: Bool {
        switch self {
        case .invalidRunTitle, .invalidRunDate, .invalidStopData, .duplicateStopNames, .insufficientStops, .invalidStopTiming, .stopTimeConflict, .invalidUserInput, .userCancelled:
            return false
        case .runNotFound, .stopNotFound, .runAlreadyActive, .noActiveRun, .invalidRunState, .operationNotAllowed:
            return true
        case .invalidRunData, .dataCorruption, .storageError, .serializationError, .concurrentModification, .networkUnavailable, .insufficientStorage, .permissionDenied, .operationTimeout:
            return true
        case .unexpectedError:
            return true
        }
    }
    
    /// Whether this error should be shown to the user
    var shouldShowToUser: Bool {
        switch self {
        case .userCancelled:
            return false
        default:
            return true
        }
    }
    
    /// Whether this error should trigger haptic feedback
    var shouldTriggerHaptic: Bool {
        switch severity {
        case .low:
            return false
        case .medium:
            return true
        case .high, .critical:
            return true
        }
    }
    
    /// Haptic feedback type for this error
    var hapticType: HapticFeedbackType {
        switch severity {
        case .low, .medium:
            return .warning
        case .high, .critical:
            return .error
        }
    }
}



/// Error severity levels
enum ErrorSeverity: String, CaseIterable {
    case low
    case medium
    case high
    case critical
}

/// Haptic feedback types for errors
enum HapticFeedbackType {
    case warning
    case error
    case success
}

/// Comprehensive handler for school run errors with logging, user feedback, and recovery strategies
@MainActor
class SchoolRunErrorHandler: ObservableObject {
    // MARK: - Published Properties
    
    /// Current error being handled
    @Published var currentError: SchoolRunError?
    
    /// Error message for display in UI
    @Published var errorMessage: String?
    
    /// Whether an error alert should be shown
    @Published var showingErrorAlert: Bool = false
    
    /// Whether a toast notification should be shown
    @Published var showingToast: Bool = false
    
    // MARK: - Private Properties
    
    private let logger = Logger(subsystem: "com.tribeboard.schoolrun", category: "ErrorHandler")
    private let toastManager = ToastManager.shared
    private let hapticManager = HapticManager.shared
    
    /// Error history for pattern analysis
    private var errorHistory: [ErrorHistoryEntry] = []
    
    /// Maximum number of errors to keep in history
    private let maxHistorySize = 50
    
    // MARK: - Public Methods
    
    /// Handle a school run error with comprehensive logging and user feedback
    func handleError(_ error: SchoolRunError, context: String = "") {
        currentError = error
        errorMessage = error.userFriendlyMessage
        
        // Add to error history
        addToHistory(error, context: context)
        
        // Log the error
        logError(error, context: context)
        
        // Trigger haptic feedback if appropriate
        if error.shouldTriggerHaptic {
            triggerHapticFeedback(for: error)
        }
        
        // Show user feedback based on error severity
        showUserFeedback(for: error)
    }
    
    /// Handle multiple errors (batch processing)
    func handleErrors(_ errors: [SchoolRunError], context: String = "") {
        guard !errors.isEmpty else { return }
        
        // Handle the most severe error first
        let sortedErrors = errors.sorted { $0.severity.rawValue > $1.severity.rawValue }
        
        if let primaryError = sortedErrors.first {
            handleError(primaryError, context: context)
        }
        
        // Log additional errors
        for error in sortedErrors.dropFirst() {
            logError(error, context: "\(context) (additional)")
        }
    }
    
    /// Clear the current error state
    func clearError() {
        currentError = nil
        errorMessage = nil
        showingErrorAlert = false
        showingToast = false
    }
    
    /// Clear all error state and history
    func clearAll() {
        clearError()
        errorHistory.removeAll()
    }
    
    /// Get error recovery suggestions
    func getRecoverySuggestions(for error: SchoolRunError) -> [String] {
        var suggestions: [String] = []
        
        if let recoverySuggestion = error.recoverySuggestion {
            suggestions.append(recoverySuggestion)
        }
        
        // Add context-specific suggestions
        switch error.category {
        case .validation:
            suggestions.append("Double-check all required fields")
            suggestions.append("Ensure data meets the specified format")
        case .data:
            suggestions.append("Try refreshing the data")
            suggestions.append("Restart the app if the problem persists")
        case .state:
            suggestions.append("Check the current run status")
            suggestions.append("Wait for ongoing operations to complete")
        case .network:
            suggestions.append("Check your internet connection")
            suggestions.append("Try again when connection is restored")
        case .system:
            suggestions.append("Restart the app")
            suggestions.append("Check device storage and permissions")
        case .user:
            suggestions.append("Try the operation again")
        case .authentication:
            suggestions.append("Check your login credentials")
            suggestions.append("Try signing out and back in")
        case .cloudKit:
            suggestions.append("Check your iCloud connection")
            suggestions.append("Try again when iCloud is available")
        case .codeGeneration:
            suggestions.append("Try generating a new code")
            suggestions.append("Contact support if the problem persists")
        case .localDatabase:
            suggestions.append("Try restarting the app")
            suggestions.append("Clear app data if the problem continues")
        }
        
        return suggestions
    }
    
    /// Check if error can be automatically retried
    func canRetry(_ error: SchoolRunError) -> Bool {
        return error.isRetryable && getRetryCount(for: error) < maxRetryAttempts(for: error)
    }
    
    /// Get retry delay for an error
    func getRetryDelay(for error: SchoolRunError) -> TimeInterval {
        let retryCount = getRetryCount(for: error)
        let baseDelay: TimeInterval = 1.0
        
        switch error.severity {
        case .low:
            return baseDelay
        case .medium:
            return baseDelay * pow(1.5, Double(retryCount))
        case .high:
            return baseDelay * pow(2.0, Double(retryCount))
        case .critical:
            return baseDelay * pow(3.0, Double(retryCount))
        }
    }
    
    /// Analyze error patterns and provide insights
    func analyzeErrorPatterns() -> SchoolRunErrorAnalysis {
        let recentErrors = errorHistory.suffix(10)
        let errorCounts = Dictionary(grouping: recentErrors) { $0.error.category }
        
        var analysis = SchoolRunErrorAnalysis()
        
        // Check for repeated validation errors
        if let validationErrors = errorCounts[.validation], validationErrors.count >= 3 {
            analysis.patterns.append(.repeatedValidation)
            analysis.recommendations.append("Review input validation requirements")
        }
        
        // Check for data corruption patterns
        if let dataErrors = errorCounts[.data], dataErrors.count >= 2 {
            analysis.patterns.append(.dataIssues)
            analysis.recommendations.append("Consider clearing app data or reinstalling")
        }
        
        // Check for network issues
        if let networkErrors = errorCounts[.network], networkErrors.count >= 2 {
            analysis.patterns.append(.connectivityIssues)
            analysis.recommendations.append("Check network stability")
        }
        
        return analysis
    }
    
    // MARK: - Validation Helpers
    
    /// Validate run title and return specific error if invalid
    func validateRunTitle(_ title: String) -> SchoolRunError? {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedTitle.isEmpty {
            return .invalidRunTitle("Title cannot be empty")
        }
        
        if trimmedTitle.count < 3 {
            return .invalidRunTitle("Title must be at least 3 characters")
        }
        
        if trimmedTitle.count > 50 {
            return .invalidRunTitle("Title must be less than 50 characters")
        }
        
        // Check for invalid characters
        let invalidCharacters = CharacterSet.alphanumerics.union(.whitespaces).union(.punctuationCharacters).inverted
        if trimmedTitle.rangeOfCharacter(from: invalidCharacters) != nil {
            return .invalidRunTitle("Title contains invalid characters")
        }
        
        return nil
    }
    
    /// Validate run date and return specific error if invalid
    func validateRunDate(_ date: Date) -> SchoolRunError? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let selectedDay = calendar.startOfDay(for: date)
        
        if selectedDay < today {
            return .invalidRunDate("Date cannot be in the past")
        }
        
        let maxDate = calendar.date(byAdding: .year, value: 1, to: today) ?? today
        if selectedDay > maxDate {
            return .invalidRunDate("Date cannot be more than 1 year in the future")
        }
        
        return nil
    }
    
    /// Validate stops and return specific errors if invalid
    func validateStops(_ stops: [RunStop]) -> [SchoolRunError] {
        var errors: [SchoolRunError] = []
        
        // Check minimum stops
        if stops.isEmpty {
            errors.append(.insufficientStops)
            return errors
        }
        
        // Check for empty stop names
        let emptyStops = stops.filter { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        if !emptyStops.isEmpty {
            errors.append(.invalidStopData("All stops must have a name"))
        }
        
        // Check for duplicate stop names
        let stopNames = stops.map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        let uniqueNames = Set(stopNames)
        if stopNames.count != uniqueNames.count {
            errors.append(.duplicateStopNames)
        }
        
        // Check stop timing
        let sortedStops = stops.sorted { $0.time < $1.time }
        for i in 1..<sortedStops.count {
            let timeDifference = sortedStops[i].time.timeIntervalSince(sortedStops[i-1].time)
            if timeDifference < 300 { // 5 minutes
                errors.append(.stopTimeConflict("Stops must be at least 5 minutes apart"))
                break
            }
        }
        
        // Validate individual stops
        for (index, stop) in stops.enumerated() {
            if let stopError = validateStop(stop, index: index) {
                errors.append(stopError)
            }
        }
        
        return errors
    }
    
    /// Validate individual stop
    func validateStop(_ stop: RunStop, index: Int) -> SchoolRunError? {
        let trimmedName = stop.name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedName.isEmpty {
            return .invalidStopData("Stop \(index + 1) name is required")
        }
        
        if trimmedName.count > 30 {
            return .invalidStopData("Stop \(index + 1) name must be less than 30 characters")
        }
        
        // Validate note length
        if stop.note.count > 100 {
            return .invalidStopData("Stop \(index + 1) note must be less than 100 characters")
        }
        
        return nil
    }
    
    // MARK: - Private Methods
    
    private func addToHistory(_ error: SchoolRunError, context: String) {
        let entry = ErrorHistoryEntry(
            error: error,
            context: context,
            timestamp: Date()
        )
        
        errorHistory.append(entry)
        
        // Trim history if needed
        if errorHistory.count > maxHistorySize {
            errorHistory.removeFirst(errorHistory.count - maxHistorySize)
        }
    }
    
    private func logError(_ error: SchoolRunError, context: String) {
        let contextInfo = context.isEmpty ? "" : " [\(context)]"
        
        switch error.severity {
        case .low:
            logger.info("SchoolRun Error\(contextInfo): \(error.localizedDescription ?? "Unknown error")")
        case .medium:
            logger.notice("SchoolRun Error\(contextInfo): \(error.localizedDescription ?? "Unknown error")")
        case .high:
            logger.error("SchoolRun Error\(contextInfo): \(error.localizedDescription ?? "Unknown error")")
        case .critical:
            logger.fault("SchoolRun Critical Error\(contextInfo): \(error.localizedDescription ?? "Unknown error")")
        }
        
        if let recovery = error.recoverySuggestion {
            logger.debug("Recovery suggestion: \(recovery)")
        }
    }
    
    private func triggerHapticFeedback(for error: SchoolRunError) {
        switch error.hapticType {
        case .warning:
            hapticManager.warning()
        case .error:
            hapticManager.error()
        case .success:
            hapticManager.success()
        }
    }
    
    private func showUserFeedback(for error: SchoolRunError) {
        guard error.shouldShowToUser else { return }
        
        switch error.severity {
        case .low:
            // Show inline error only
            break
        case .medium:
            // Show toast notification
            showingToast = true
            toastManager.warning(error.userFriendlyMessage)
        case .high:
            // Show error toast
            showingToast = true
            toastManager.error(error.userFriendlyMessage)
        case .critical:
            // Show alert dialog
            showingErrorAlert = true
            toastManager.error(error.userFriendlyMessage)
        }
    }
    
    private func getRetryCount(for error: SchoolRunError) -> Int {
        let recentErrors = errorHistory.suffix(5)
        return recentErrors.filter { $0.error == error }.count
    }
    
    private func maxRetryAttempts(for error: SchoolRunError) -> Int {
        switch error.severity {
        case .low:
            return 1
        case .medium:
            return 2
        case .high:
            return 3
        case .critical:
            return 1
        }
    }
    
    // MARK: - Computed Properties
    
    /// Check if there's an active error
    var hasError: Bool {
        return currentError != nil
    }
    
    /// Get current error severity
    var currentErrorSeverity: ErrorSeverity? {
        return currentError?.severity
    }
    
    /// Get error count for current session
    var errorCount: Int {
        return errorHistory.count
    }
    
    /// Get recent error count (last 10 minutes)
    var recentErrorCount: Int {
        let tenMinutesAgo = Date().addingTimeInterval(-600)
        return errorHistory.filter { $0.timestamp > tenMinutesAgo }.count
    }
}

// MARK: - Supporting Types

/// Error history entry for pattern analysis
struct ErrorHistoryEntry {
    let error: SchoolRunError
    let context: String
    let timestamp: Date
}

/// Error pattern analysis result
struct SchoolRunErrorAnalysis {
    var patterns: [SchoolRunErrorPattern] = []
    var recommendations: [String] = []
}

/// Detected error patterns
enum SchoolRunErrorPattern {
    case repeatedValidation
    case dataIssues
    case connectivityIssues
    case frequentRetries
}