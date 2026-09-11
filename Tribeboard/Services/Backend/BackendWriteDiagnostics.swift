import Foundation
import Combine

struct BackendWriteDiagnosticEvent {
    let timestamp: Date
    let operation: String
    let tableOrEndpoint: String
    let requestURL: String
    let statusCode: Int?
    let responseBody: String
    let payloadSummary: String
    let hadAuthToken: Bool
    let errorSummary: String?
    let likelyRLSWarning: String?
}

@MainActor
final class BackendWriteDiagnosticsStore: ObservableObject {
    static let shared = BackendWriteDiagnosticsStore()

    @Published private(set) var lastEvent: BackendWriteDiagnosticEvent?

    func record(_ event: BackendWriteDiagnosticEvent) {
        lastEvent = event
    }
}

enum BackendWriteDiagnostics {
    static func record(
        operation: String,
        tableOrEndpoint: String,
        request: URLRequest,
        statusCode: Int?,
        responseBody: String,
        payloadSummary: String,
        errorSummary: String? = nil
    ) {
#if DEBUG
        let hadAuthToken = hasAuthorizationHeader(request)
        let missingAuthMessage = hadAuthToken ? nil : "Missing Authorization header on backend write request."
        let event = BackendWriteDiagnosticEvent(
            timestamp: Date(),
            operation: operation,
            tableOrEndpoint: tableOrEndpoint,
            requestURL: request.url?.absoluteString ?? "Unknown URL",
            statusCode: statusCode,
            responseBody: trimmed(responseBody),
            payloadSummary: payloadSummary,
            hadAuthToken: hadAuthToken,
            errorSummary: errorSummary ?? missingAuthMessage,
            likelyRLSWarning: likelyRLSWarning(statusCode: statusCode, body: responseBody)
        )
        Task { @MainActor in
            BackendWriteDiagnosticsStore.shared.record(event)
        }
#endif
    }

    static func describeBackendFailure(
        operation: String,
        tableOrEndpoint: String,
        statusCode: Int,
        responseBody: String
    ) -> String {
        let trimmedBody = trimmed(responseBody)
        let likelyRLS = likelyRLSWarning(statusCode: statusCode, body: trimmedBody)
        var reasons: [String] = []
        switch statusCode {
        case 400:
            reasons.append("Likely payload mismatch or missing required field.")
        case 401:
            reasons.append("Unauthenticated request. Session may be missing or expired.")
        case 403:
            reasons.append("Permission denied. This may be blocked by RLS.")
        case 404:
            reasons.append("Endpoint/table may be incorrect or unavailable.")
        case 409:
            reasons.append("Conflict detected (possibly duplicate key).")
        default:
            break
        }
        if let likelyRLS {
            reasons.append(likelyRLS)
        }
        let reasonText = reasons.isEmpty ? "" : " \(reasons.joined(separator: " "))"
        return "\(operation) failed for \(tableOrEndpoint) (\(statusCode)).\(reasonText)"
    }

    static func likelyRLSWarning(statusCode: Int?, body: String) -> String? {
        guard let statusCode else { return nil }
        let text = body.lowercased()
        let hints = [
            "row-level security",
            "rls",
            "permission denied",
            "not allowed",
            "insufficient_privilege",
            "42501"
        ]
        let hasPolicyHint = hints.contains { text.contains($0) }
        if statusCode == 403 || hasPolicyHint {
            return "Insert likely blocked by RLS policy."
        }
        return nil
    }

    private static func trimmed(_ body: String) -> String {
        let value = body.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.isEmpty { return "(empty)" }
        if value.count > 500 {
            return String(value.prefix(500)) + "…"
        }
        return value
    }

    private static func hasAuthorizationHeader(_ request: URLRequest) -> Bool {
        guard let value = request.value(forHTTPHeaderField: "Authorization") else { return false }
        return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
