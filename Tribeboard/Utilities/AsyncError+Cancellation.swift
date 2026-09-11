import Foundation

func isCancellationError(_ error: Error) -> Bool {
    if error is CancellationError {
        return true
    }
    if let urlError = error as? URLError, urlError.code == .cancelled {
        return true
    }
    let nsError = error as NSError
    if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
        return true
    }
    let normalized = error.localizedDescription
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .lowercased()
    return normalized == "cancelled" || normalized == "canceled"
}

func isCancellationMessage(_ message: String?) -> Bool {
    guard let message else { return false }
    let normalized = message
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .lowercased()
    return normalized == "cancelled" || normalized == "canceled"
}
