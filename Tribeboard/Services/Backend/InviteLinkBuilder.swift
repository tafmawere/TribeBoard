import Foundation

/// Canonical TribeBoard invite URLs for email, web, and universal links.
enum InviteLinkBuilder {
    static let webBase = "https://tribeboard.app/invite"

    static func webURL(for invite: BackendHouseholdInvite) -> String {
        var components = URLComponents(string: webBase)!
        var items: [URLQueryItem] = [
            URLQueryItem(name: "invite_id", value: invite.id.uuidString.lowercased()),
            URLQueryItem(name: "household_id", value: invite.householdId.uuidString.lowercased()),
            URLQueryItem(name: "email", value: invite.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()),
        ]
        if let token = invite.inviteToken?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased(),
           !token.isEmpty {
            items.append(URLQueryItem(name: "token", value: token))
        }
        if let code = invite.inviteCode?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased(),
           !code.isEmpty {
            items.append(URLQueryItem(name: "invite_code", value: code))
        }
        components.queryItems = items
        return components.url?.absoluteString ?? "\(webBase)?invite_id=\(invite.id.uuidString.lowercased())"
    }

    static func appDeepLinkURL(for invite: BackendHouseholdInvite) -> String {
        guard var components = URLComponents(string: "tribeboard://invite") else {
            return "tribeboard://invite"
        }
        var items: [URLQueryItem] = [
            URLQueryItem(name: "invite_id", value: invite.id.uuidString.lowercased()),
            URLQueryItem(name: "household_id", value: invite.householdId.uuidString.lowercased()),
        ]
        let email = invite.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !email.isEmpty {
            items.append(URLQueryItem(name: "email", value: email))
        }
        if let token = invite.inviteToken?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased(),
           !token.isEmpty {
            items.append(URLQueryItem(name: "token", value: token))
        }
        components.queryItems = items
        return components.url?.absoluteString ?? "tribeboard://invite"
    }
}
