import Foundation
import os

/// Temporary invite/join diagnostics. Secrets (codes, tokens) are logged only in DEBUG builds.
enum InviteFlowLogger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "net.dataenvy.tribeboard.ios"
    private static let log = Logger(subsystem: subsystem, category: "InviteFlow")

    static func inviteRowCreated(
        inviteId: UUID,
        householdId: UUID,
        invitedEmail: String,
        authUserId: String,
        inviteCode: String?,
        inviteToken: String?
    ) {
#if DEBUG
        print(
            "[InviteFlow] invite_row_created invite_id=\(inviteId.uuidString) household_id=\(householdId.uuidString) " +
            "email=\(invitedEmail) auth=\(authUserId) code=\(inviteCode ?? "nil") token=\(inviteToken ?? "nil")"
        )
#endif
        log.info(
            "invite_row_created invite_id=\(inviteId.uuidString, privacy: .public) household_id=\(householdId.uuidString, privacy: .public) auth_user_id=\(authUserId, privacy: .public)"
        )
    }

    static func inviteEmailHTTPResult(
        inviteId: UUID,
        householdId: UUID,
        invitedEmail: String,
        authUserId: String,
        success: Bool,
        statusCode: Int?,
        logPrefix: String
    ) {
#if DEBUG
        print(
            "[InviteFlow] invite_email_result prefix=\(logPrefix) invite_id=\(inviteId.uuidString) " +
            "household_id=\(householdId.uuidString) email=\(invitedEmail) auth=\(authUserId) " +
            "success=\(success) http=\(statusCode.map(String.init) ?? "nil")"
        )
#endif
        let http = statusCode ?? -1
        log.info(
            "invite_email_result prefix=\(logPrefix, privacy: .public) invite_id=\(inviteId.uuidString, privacy: .public) household_id=\(householdId.uuidString, privacy: .public) success=\(String(success), privacy: .public) http=\(http, privacy: .public)"
        )
    }

    static func previewRPCCompleted(
        function: String,
        authUserId: String?,
        rowCount: Int,
        preview: HouseholdInvitePreview?
    ) {
#if DEBUG
        if let preview {
            print(
                "[InviteFlow] preview_rpc function=\(function) auth=\(authUserId ?? "nil") rows=\(rowCount) " +
                "invite_id=\(preview.inviteId.uuidString) household_id=\(preview.householdId.uuidString) " +
                "status=\(preview.status) email_invitee=n/a"
            )
        } else {
            print("[InviteFlow] preview_rpc function=\(function) auth=\(authUserId ?? "nil") rows=\(rowCount) preview=nil")
        }
#endif
        let authPresent = authUserId != nil
        if let preview {
            log.info(
                "preview_rpc function=\(function, privacy: .public) invite_id=\(preview.inviteId.uuidString, privacy: .public) household_id=\(preview.householdId.uuidString, privacy: .public) status=\(preview.status, privacy: .public) auth_present=\(String(authPresent), privacy: .public)"
            )
        } else {
            log.info("preview_rpc function=\(function, privacy: .public) rows=\(rowCount, privacy: .public) empty=true auth_present=\(String(authPresent), privacy: .public)")
        }
    }

    static func rpcInviteCompleted(
        function: String,
        outcome: String,
        householdId: UUID?,
        authUserId: String
    ) {
#if DEBUG
        print(
            "[InviteFlow] rpc_invite function=\(function) outcome=\(outcome) " +
            "household_id=\(householdId?.uuidString ?? "nil") auth=\(authUserId)"
        )
#endif
        let hid = householdId?.uuidString ?? "nil"
        log.info(
            "rpc_invite function=\(function, privacy: .public) outcome=\(outcome, privacy: .public) household_id=\(hid, privacy: .public) auth_user_id=\(authUserId, privacy: .public)"
        )
    }

    static func pendingInvitePersisted(codePresent: Bool, tokenPresent: Bool, householdId: UUID?) {
#if DEBUG
        print(
            "[InviteFlow] pending_invite_persisted code=\(codePresent) token=\(tokenPresent) " +
            "household_id=\(householdId?.uuidString ?? "nil")"
        )
#endif
        let hid = householdId?.uuidString ?? "nil"
        log.info(
            "pending_invite_persisted code_present=\(String(codePresent), privacy: .public) token_present=\(String(tokenPresent), privacy: .public) household_id=\(hid, privacy: .public)"
        )
    }

    static func pendingInviteCleared(reason: String) {
#if DEBUG
        print("[InviteFlow] pending_invite_cleared reason=\(reason)")
#endif
        log.info("pending_invite_cleared reason=\(reason, privacy: .public)")
    }

    static func postAuthInviteGate(
        authUserId: String,
        showedAcceptanceUI: Bool,
        householdId: UUID?,
        inviteId: UUID?
    ) {
#if DEBUG
        print(
            "[InviteFlow] post_auth_invite_gate auth=\(authUserId) show_ui=\(showedAcceptanceUI) " +
            "household_id=\(householdId?.uuidString ?? "nil") invite_id=\(inviteId?.uuidString ?? "nil")"
        )
#endif
        let hid = householdId?.uuidString ?? "nil"
        let iid = inviteId?.uuidString ?? "nil"
        log.info(
            "post_auth_invite_gate auth_user_id=\(authUserId, privacy: .public) show_ui=\(String(showedAcceptanceUI), privacy: .public) household_id=\(hid, privacy: .public) invite_id=\(iid, privacy: .public)"
        )
    }

    static func routingDestination(_ label: String, authUserId: String) {
#if DEBUG
        print("[InviteFlow] routing_destination=\(label) auth=\(authUserId)")
#endif
        log.info("routing_destination=\(label, privacy: .public) auth_user_id=\(authUserId, privacy: .public)")
    }

    static func inviteDeepLinkIngested(authPresent: Bool, host: String?) {
#if DEBUG
        print("[InviteFlow] deep_link_ingested auth_present=\(authPresent) host=\(host ?? "nil")")
#endif
        let hostStr = host ?? "nil"
        log.info("deep_link_ingested auth_present=\(String(authPresent), privacy: .public) host=\(hostStr, privacy: .public)")
    }

    static func manualJoinPersistedNoSession(normalizedInviteCode: String) {
#if DEBUG
        print("[InviteFlow] manual_join_persisted_no_session code=\(normalizedInviteCode)")
#endif
        log.info("manual_join_persisted_no_session code_length=\(normalizedInviteCode.count, privacy: .public)")
    }
}
