import Foundation

/// Persists invite context across auth so first-time users can accept after signup.
enum PendingInvitePersistence {
    private static let codeKey = "tb.pendingInvite.inviteCode"
    private static let tokenKey = "tb.pendingInvite.inviteToken"
    private static let inviteIdKey = "tb.pendingInvite.inviteId"
    private static let householdIdKey = "tb.pendingInvite.householdId"
    private static let emailKey = "tb.pendingInvite.email"
    private static let savedAtKey = "tb.pendingInvite.savedAt"

    static func save(
        code: String?,
        token: String?,
        inviteId: UUID? = nil,
        householdId: UUID? = nil,
        email: String? = nil,
        userDefaults: UserDefaults = .standard
    ) {
        let trimmedCode = code?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let trimmedToken = token?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let trimmedEmail = email?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if let trimmedCode, !trimmedCode.isEmpty {
            userDefaults.set(trimmedCode, forKey: Self.codeKey)
        } else {
            userDefaults.removeObject(forKey: Self.codeKey)
        }
        if let trimmedToken, !trimmedToken.isEmpty {
            userDefaults.set(trimmedToken, forKey: Self.tokenKey)
        } else {
            userDefaults.removeObject(forKey: Self.tokenKey)
        }
        if let inviteId {
            userDefaults.set(inviteId.uuidString.lowercased(), forKey: Self.inviteIdKey)
        } else {
            userDefaults.removeObject(forKey: Self.inviteIdKey)
        }
        if let householdId {
            userDefaults.set(householdId.uuidString.lowercased(), forKey: Self.householdIdKey)
        } else {
            userDefaults.removeObject(forKey: Self.householdIdKey)
        }
        if let trimmedEmail, !trimmedEmail.isEmpty {
            userDefaults.set(trimmedEmail, forKey: Self.emailKey)
        } else {
            userDefaults.removeObject(forKey: Self.emailKey)
        }
        userDefaults.set(Date().timeIntervalSince1970, forKey: Self.savedAtKey)

        let codePresent = (trimmedCode?.isEmpty == false)
        let tokenPresent = (trimmedToken?.isEmpty == false)
        InviteFlowLogger.pendingInvitePersisted(
            codePresent: codePresent,
            tokenPresent: tokenPresent,
            householdId: householdId
        )
#if DEBUG
        print(
            "[PendingInvite] persisted invite_id=\(inviteId?.uuidString ?? "nil") " +
            "household_id=\(householdId?.uuidString ?? "nil") email=\(trimmedEmail ?? "nil") " +
            "token_present=\(tokenPresent) code_present=\(codePresent)"
        )
#endif
    }

    static func load(userDefaults: UserDefaults = .standard) -> PendingInviteSnapshot? {
        let code = userDefaults.string(forKey: Self.codeKey)?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let token = userDefaults.string(forKey: Self.tokenKey)?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let inviteIdRaw = userDefaults.string(forKey: Self.inviteIdKey)
        let inviteId = inviteIdRaw.flatMap { UUID(uuidString: $0) }
        let householdRaw = userDefaults.string(forKey: Self.householdIdKey)
        let householdId = householdRaw.flatMap { UUID(uuidString: $0) }
        let email = userDefaults.string(forKey: Self.emailKey)?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let savedAt = userDefaults.object(forKey: Self.savedAtKey) as? TimeInterval

        let hasCode = !(code?.isEmpty ?? true)
        let hasToken = !(token?.isEmpty ?? true)
        let hasInviteId = inviteId != nil
        let hasHouseholdAndEmail = householdId != nil && !(email?.isEmpty ?? true)
        if !hasCode, !hasToken, !hasInviteId, !hasHouseholdAndEmail {
            return nil
        }
        return PendingInviteSnapshot(
            inviteCode: (code?.isEmpty ?? true) ? nil : code,
            inviteToken: (token?.isEmpty ?? true) ? nil : token,
            inviteId: inviteId,
            householdId: householdId,
            invitedEmail: (email?.isEmpty ?? true) ? nil : email,
            savedAt: savedAt.map { Date(timeIntervalSince1970: $0) }
        )
    }

    static func clear(userDefaults: UserDefaults = .standard, reason: String = "explicit_clear") {
        userDefaults.removeObject(forKey: Self.codeKey)
        userDefaults.removeObject(forKey: Self.tokenKey)
        userDefaults.removeObject(forKey: Self.inviteIdKey)
        userDefaults.removeObject(forKey: Self.householdIdKey)
        userDefaults.removeObject(forKey: Self.emailKey)
        userDefaults.removeObject(forKey: Self.savedAtKey)
        InviteFlowLogger.pendingInviteCleared(reason: reason)
    }

    /// Parses universal links and custom scheme invite URLs.
    static func ingestInviteURL(_ url: URL, userDefaults: UserDefaults = .standard) -> Bool {
        guard isInviteURL(url) else { return false }
        let parsed = parseInviteParameters(from: url)
        guard parsed.hasAnyIdentifier else { return false }
        save(
            code: parsed.inviteCode,
            token: parsed.token,
            inviteId: parsed.inviteId,
            householdId: parsed.householdId,
            email: parsed.email,
            userDefaults: userDefaults
        )
#if DEBUG
        print("[InviteLink] parsed invite_id=\(parsed.inviteId?.uuidString ?? "nil")")
        print("[InviteLink] parsed household_id=\(parsed.householdId?.uuidString ?? "nil")")
        print("[InviteLink] parsed email=\(parsed.email ?? "nil")")
        print("[InviteLink] parsed token_present=\(!(parsed.token?.isEmpty ?? true))")
#endif
        return true
    }

    static func parseInviteToken(from url: URL) -> String? {
        parseInviteLink(url)?.token
    }

    /// Parsing only — does not persist or call the backend.
    static func parseInviteLink(_ url: URL) -> ParsedInviteLink? {
        guard isInviteURL(url) else { return nil }
        let parsed = parseInviteParameters(from: url)
        guard parsed.hasAnyIdentifier else { return nil }
        return ParsedInviteLink(
            token: parsed.token,
            inviteId: parsed.inviteId,
            householdId: parsed.householdId,
            email: parsed.email,
            inviteCode: parsed.inviteCode
        )
    }

    private static func isInviteURL(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        let scheme = url.scheme?.lowercased() ?? ""
        let isTribeboardScheme = scheme == "tribeboard"
        let isUniversalInviteHost = host == "tribeboard.app" || host.hasSuffix(".tribeboard.app")
        return isTribeboardScheme || isUniversalInviteHost
    }

    private struct ParsedInviteParameters {
        var token: String?
        var inviteId: UUID?
        var householdId: UUID?
        var email: String?
        var inviteCode: String?

        var hasAnyIdentifier: Bool {
            let hasToken = !(token?.isEmpty ?? true)
            let hasInviteId = inviteId != nil
            let hasCode = !(inviteCode?.isEmpty ?? true)
            let hasHouseholdAndEmail = householdId != nil && !(email?.isEmpty ?? true)
            return hasToken || hasInviteId || hasCode || hasHouseholdAndEmail
        }
    }

    private static func parseInviteParameters(from url: URL) -> ParsedInviteParameters {
        var parsed = ParsedInviteParameters()
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let items = components.queryItems {
            for item in items {
                guard let value = item.value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
                    continue
                }
                switch item.name.lowercased() {
                case "token":
                    parsed.token = value.lowercased()
                case "invite_id":
                    parsed.inviteId = UUID(uuidString: value.lowercased())
                case "household_id":
                    parsed.householdId = UUID(uuidString: value.lowercased())
                case "email":
                    parsed.email = value.lowercased()
                case "invite_code":
                    parsed.inviteCode = value.uppercased()
                default:
                    break
                }
            }
        }

        let path = url.path.lowercased()
        if path.hasPrefix("/invite/") {
            let suffix = String(path.dropFirst("/invite/".count))
            let candidate = suffix.split(separator: "/").first.map(String.init) ?? ""
            let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if let uuid = UUID(uuidString: trimmed) {
                if parsed.inviteId == nil {
                    parsed.inviteId = uuid
                }
                if parsed.token == nil {
                    parsed.token = trimmed
                }
            }
        }
        return parsed
    }
}

struct ParsedInviteLink: Equatable {
    let token: String?
    let inviteId: UUID?
    let householdId: UUID?
    let email: String?
    let inviteCode: String?
}

/// Parse + persist only. Accept/membership INSERT stays on the existing signed-in RPC path.
enum InviteDeepLinkIngest {
    enum NextStep: Equatable {
        case ignored
        case savedForSignIn
        case evaluatePostAuth
    }

    static let savedForSignInBanner =
        "We saved your invite. Sign in or create an account to finish joining."

    static func handle(
        url: URL,
        isAuthenticated: Bool,
        userDefaults: UserDefaults = .standard
    ) -> NextStep {
        guard PendingInvitePersistence.ingestInviteURL(url, userDefaults: userDefaults) else {
            return .ignored
        }
        return isAuthenticated ? .evaluatePostAuth : .savedForSignIn
    }
}

struct PendingInviteSnapshot: Equatable {
    let inviteCode: String?
    let inviteToken: String?
    let inviteId: UUID?
    let householdId: UUID?
    let invitedEmail: String?
    let savedAt: Date?

    var prefersToken: Bool {
        if let inviteToken, !inviteToken.isEmpty { return true }
        return false
    }
}
