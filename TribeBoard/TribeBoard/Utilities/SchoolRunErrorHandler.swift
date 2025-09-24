import Foundation
import SwiftUI

/// Centralized error handling for School Run feature
class SchoolRunErrorHandler: ObservableObject {
    @Published var currentError: SchoolRunError?
    @Published var showingErrorAlert = false
    
    /// Shows an error to the user
    func handleError(_ error: SchoolRunError) {
        currentError = error
        showingErrorAlert = true
    }
    
    /// Shows validation errors as a toast
    @MainActor
    func handleValidationErrors(_ errors: [ValidationError], toastManager: ToastManager) {
        guard !errors.isEmpty else { return }
        
        let primaryError = errors.first!
        toastManager.error(primaryError.errorDescription ?? "Validation error")
    }
    
    /// Clears the current error
    func clearError() {
        currentError = nil
        showingErrorAlert = false
    }
}

/// Specific errors that can occur in the School Run system
enum SchoolRunError: LocalizedError, Identifiable {
    case runNotFound
    case invalidRunData
    case executionFailed
    case saveFailed
    case loadFailed
    case networkUnavailable
    case permissionDenied
    case unexpectedError(String)
    
    var id: String {
        switch self {
        case .runNotFound: return "runNotFound"
        case .invalidRunData: return "invalidRunData"
        case .executionFailed: return "executionFailed"
        case .saveFailed: return "saveFailed"
        case .loadFailed: return "loadFailed"
        case .networkUnavailable: return "networkUnavailable"
        case .permissionDenied: return "permissionDenied"
        case .unexpectedError: return "unexpectedError"
        }
    }
    
    var errorDescription: String? {
        switch self {
        case .runNotFound:
            return "Run Not Found"
        case .invalidRunData:
            return "Invalid Run Data"
        case .executionFailed:
            return "Execution Failed"
        case .saveFailed:
            return "Save Failed"
        case .loadFailed:
            return "Load Failed"
        case .networkUnavailable:
            return "Network Unavailable"
        case .permissionDenied:
            return "Permission Denied"
        case .unexpectedError:
            return "Unexpected Error"
        }
    }
    
    var failureReason: String? {
        switch self {
        case .runNotFound:
            return "The requested school run could not be found."
        case .invalidRunData:
            return "The run data is corrupted or invalid."
        case .executionFailed:
            return "The run execution encountered an error."
        case .saveFailed:
            return "Failed to save the run data."
        case .loadFailed:
            return "Failed to load run data."
        case .networkUnavailable:
            return "Network connection is not available."
        case .permissionDenied:
            return "Permission to access this feature was denied."
        case .unexpectedError(let message):
            return message
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .runNotFound:
            return "Please check if the run still exists or try refreshing the list."
        case .invalidRunData:
            return "Try creating a new run or contact support if the problem persists."
        case .executionFailed:
            return "Please try starting the run again or check your device settings."
        case .saveFailed:
            return "Check your device storage and try saving again."
        case .loadFailed:
            return "Try restarting the app or check your device storage."
        case .networkUnavailable:
            return "Check your internet connection and try again."
        case .permissionDenied:
            return "Please grant the necessary permissions in Settings."
        case .unexpectedError:
            return "Please try again or restart the app if the problem persists."
        }
    }
    
    var severity: ErrorSeverity {
        switch self {
        case .runNotFound, .invalidRunData:
            return .high
        case .executionFailed, .saveFailed:
            return .medium
        case .loadFailed, .networkUnavailable:
            return .low
        case .permissionDenied:
            return .high
        case .unexpectedError:
            return .medium
        }
    }
}

/// Error severity levels
enum ErrorSeverity {
    case low, medium, high
    
    var color: Color {
        switch self {
        case .low: return .orange
        case .medium: return .red
        case .high: return .red
        }
    }
    
    var icon: String {
        switch self {
        case .low: return "exclamationmark.triangle"
        case .medium: return "exclamationmark.circle"
        case .high: return "xmark.circle"
        }
    }
}

/// View modifier for handling School Run errors
struct SchoolRunErrorHandling: ViewModifier {
    @ObservedObject var errorHandler: SchoolRunErrorHandler
    
    func body(content: Content) -> some View {
        content
            .alert(
                errorHandler.currentError?.errorDescription ?? "Error",
                isPresented: $errorHandler.showingErrorAlert,
                presenting: errorHandler.currentError
            ) { error in
                Button("OK") {
                    errorHandler.clearError()
                }
            } message: { error in
                VStack(alignment: .leading, spacing: 8) {
                    if let reason = error.failureReason {
                        Text(reason)
                    }
                    if let suggestion = error.recoverySuggestion {
                        Text(suggestion)
                    }
                }
            }
    }
}

extension View {
    /// Adds School Run error handling to a view
    func schoolRunErrorHandling(_ errorHandler: SchoolRunErrorHandler) -> some View {
        modifier(SchoolRunErrorHandling(errorHandler: errorHandler))
    }
}