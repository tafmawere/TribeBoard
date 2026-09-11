import Foundation

/// Outcome of the optional `auth-check` Edge Function.
///
/// The function is not always deployed. Mapping must never invent whether an
/// email has an account — that would steer users to the wrong auth screen.
enum EmailExistenceCheckResult: Equatable {
    case exists
    case doesNotExist
    /// Function missing, 5xx, transport failure, or undecodable payload.
    case unavailable
    case failed(message: String)
}

enum EmailExistenceCheckMapper {
    static let unavailableUserMessage =
        "We couldn't verify this email right now. Sign in if you already have an account, or create a new one."

    static func mapHTTP(statusCode: Int, body: Data) -> EmailExistenceCheckResult {
        if (200..<300).contains(statusCode) {
            if let payload = try? JSONDecoder().decode(EmailCheckResponse.self, from: body) {
                return payload.exists ? .exists : .doesNotExist
            }
            return .unavailable
        }

        if isFunctionUnavailable(statusCode: statusCode, body: body) {
            return .unavailable
        }

        if let message = decodeMessage(from: body), !message.isEmpty {
            return .failed(message: message)
        }
        return .failed(message: "Could not verify email (\(statusCode)).")
    }

    static func mapTransportError(_ error: Error) -> EmailExistenceCheckResult {
        if isCancellationError(error) {
            return .failed(message: "Cancelled")
        }
        return .unavailable
    }

    static func isFunctionUnavailable(statusCode: Int, body: Data) -> Bool {
        if [404, 501, 502, 503, 504].contains(statusCode) {
            return true
        }
        let text = String(data: body, encoding: .utf8)?.lowercased() ?? ""
        return text.contains("function_not_found")
            || text.contains("requested function was not found")
            || text.contains("could not find function")
            || text.contains("not found") && text.contains("auth-check")
    }

    private static func decodeMessage(from data: Data) -> String? {
        struct Payload: Decodable {
            let msg: String?
            let error_description: String?
            let message: String?
            let error: String?
        }
        guard let decoded = try? JSONDecoder().decode(Payload.self, from: data) else {
            return nil
        }
        return decoded.msg ?? decoded.error_description ?? decoded.message ?? decoded.error
    }

    private struct EmailCheckResponse: Decodable {
        let exists: Bool
    }
}
