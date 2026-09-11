import Foundation

enum BackendUserFacingErrorMapper {
    static let noActiveSession = "No active auth session."
    static let noActiveHousehold = "No active household."
    static let sessionExpired = "Session expired. Please sign in again to continue."
    static let networkFailure = "Could not reach the server. Check your connection and try again."
    static let genericLoadFailure = "Couldn't load this data. Check your connection and try again."

    static func message(for error: Error, fallback: String = genericLoadFailure) -> String? {
        if isCancellationError(error) {
            return nil
        }
        if let sessionMessage = sessionMessage(for: error) {
            return sessionMessage
        }
        if isNetworkFailure(error) {
            return networkFailure
        }
        let text = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? fallback : text
    }

    static func sessionMessage(for error: Error) -> String? {
        let normalized = error.localizedDescription.lowercased()
        if normalized.contains("session expired")
            || normalized.contains("jwt expired")
            || normalized.contains("invalid jwt")
            || normalized.contains("pgrst303")
            || normalized.contains("unauthenticated")
            || normalized.contains("not authenticated")
            || normalized.contains("unauthorized") {
            return sessionExpired
        }
        return nil
    }

    static func isNetworkFailure(_ error: Error) -> Bool {
        if error is URLError {
            return true
        }
        let normalized = error.localizedDescription.lowercased()
        return normalized.contains("network")
            || normalized.contains("could not reach")
            || normalized.contains("the internet connection appears to be offline")
    }

    static func isTransientLoadFailure(_ message: String?) -> Bool {
        guard let message, !message.isEmpty else { return false }
        if isCancellationMessage(message) { return false }
        let normalized = message.lowercased()
        return normalized.contains("could not")
            || normalized.contains("session expired")
            || normalized.contains("no active auth session")
            || normalized.contains("network")
            || normalized.contains("offline")
            || normalized.contains("timed out")
            || normalized.contains("timeout")
    }
}
