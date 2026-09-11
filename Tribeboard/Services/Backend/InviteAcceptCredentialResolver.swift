import Foundation

/// Client-side routing key for an already-persisted invite.
/// Does not decide membership authorization or call the backend.
enum InviteAcceptCredential: Equatable {
    case inviteId(UUID)
    case inviteToken(String)
    case inviteCode(String)
}

/// Preference order for preview/accept *routing* only: invite id, then token, then code.
/// A null or blank preview token is normal and is not treated as a failure.
enum InviteAcceptCredentialResolver {
    static func resolve(
        inviteId: UUID?,
        inviteToken: String?,
        inviteCode: String?
    ) -> InviteAcceptCredential? {
        if let inviteId {
            return .inviteId(inviteId)
        }
        let token = inviteToken?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let token, !token.isEmpty {
            return .inviteToken(token)
        }
        let code = inviteCode?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let code, !code.isEmpty {
            return .inviteCode(code)
        }
        return nil
    }

    static func resolve(_ snapshot: PendingInviteSnapshot) -> InviteAcceptCredential? {
        resolve(
            inviteId: snapshot.inviteId,
            inviteToken: snapshot.inviteToken,
            inviteCode: snapshot.inviteCode
        )
    }

    static func resolve(_ preview: HouseholdInvitePreview) -> InviteAcceptCredential? {
        resolve(
            inviteId: preview.inviteId,
            inviteToken: preview.inviteToken?.uuidString,
            inviteCode: preview.backupInviteCode
        )
    }
}
