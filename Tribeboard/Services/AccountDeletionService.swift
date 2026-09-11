import Foundation

enum AccountDeletionError: LocalizedError {
    case notImplemented
    case missingUserId
    case backendFailure(String)

    var errorDescription: String? {
        switch self {
        case .notImplemented:
            return "Account deletion is not yet available. Please contact support@tribeboard.app."
        case .missingUserId:
            return "We could not identify your account. Please sign in again and try once more."
        case let .backendFailure(message):
            return message
        }
    }
}

/// Coordinates permanent account deletion on the backend.
/// Local-only data clearing is not sufficient for compliance — deletion must be queued or executed server-side.
enum AccountDeletionService {
    /// Permanently deletes the signed-in user's account and associated personal data on the backend.
    ///
    /// Backend integration required:
    /// - Call Supabase Auth admin/user delete or a secured Edge Function (e.g. `delete-account`).
    /// - Cascade-delete or anonymize profile, household memberships, child links, runs, locations, and uploads per retention policy.
    /// - Revoke active sessions and push tokens.
    /// - Return only after the deletion job is accepted or completed.
    static func deleteCurrentUserAccount(userId: String?) async throws {
        guard let userId, !userId.isEmpty else {
            throw AccountDeletionError.missingUserId
        }

        // TODO: Backend integration — replace stub with real deletion pipeline.
        // Example:
        // try await SupabaseAccountDeletionClient.requestDeletion(userId: userId)
        _ = userId
        throw AccountDeletionError.notImplemented
    }
}
