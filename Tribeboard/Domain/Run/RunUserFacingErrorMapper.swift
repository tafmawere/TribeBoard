import Foundation

enum RunUserFacingErrorMapper {
    static let expiredSessionMessage = "Your session expired. Please sign in again, then try saving the run."
    static let runPermissionDeniedMessage = "You don't have permission to create runs for this household."
    static let mutationFailedMessage = "Could not save the run update. Please try again."

    static func readableTransitionError(_ error: RunTransitionError) -> String {
        switch error {
        case .invalidTransition:
            return "That action is not allowed for the run's current state."
        case .invalidStopIndex:
            return "That stop is not currently actionable."
        case .alreadyCompleted:
            return "This run is already completed."
        case .alreadyCancelled:
            return "This run is already cancelled."
        case .notStarted:
            return "Start the run before updating stops."
        }
    }

    static func mutationMessage(for error: Error) -> String {
        if let transition = error as? RunTransitionError {
            return readableTransitionError(transition)
        }
        let normalized = error.localizedDescription.lowercased()
        if normalized.contains("permission")
            || normalized.contains("row-level security")
            || normalized.contains("rls")
            || normalized.contains("403") {
            return runPermissionDeniedMessage
        }
        if normalized.contains("session")
            || normalized.contains("jwt")
            || normalized.contains("auth")
            || normalized.contains("unauthorized") {
            return expiredSessionMessage
        }
        if normalized.contains("network") || normalized.contains("could not reach") {
            return BackendUserFacingErrorMapper.networkFailure
        }
        return mutationFailedMessage
    }

    static func createRunMessage(for error: Error) -> String {
        if let validation = error as? RunCreationValidator.ValidationError {
            return validation.localizedDescription
        }
        if error is BackendPermissionError {
            return runPermissionDeniedMessage
        }
        let message = error.localizedDescription
        let normalized = message.lowercased()
        if normalized.contains("session expired")
            || normalized.contains("no active auth session")
            || normalized.contains("jwt expired")
            || normalized.contains("invalid jwt")
            || normalized.contains("unauthorized")
            || normalized.contains("not authenticated") {
            return expiredSessionMessage
        }
        if normalized.contains("permission denied")
            || normalized.contains("row-level security")
            || normalized.contains("rls")
            || normalized.contains("not allowed")
            || normalized.contains("403") {
            return runPermissionDeniedMessage
        }
        if normalized.contains("network") || normalized.contains("could not reach") {
            return BackendUserFacingErrorMapper.networkFailure
        }
        return message.isEmpty ? "Unable to save this run." : message
    }
}
