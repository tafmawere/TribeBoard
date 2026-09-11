import Foundation

/// Parses Supabase auth callback URLs (email confirmation links, magic links) for session tokens.
enum AuthCallbackURLParser {
    struct ParsedSession {
        let accessToken: String
        let refreshToken: String?
        let expiresIn: Int?
        let tokenType: String?
        let authType: String?
    }

    /// Returns true when the URL is an auth callback (web universal link or custom scheme).
    static func isAuthCallbackURL(_ url: URL) -> Bool {
        if containsAuthSessionTokens(in: url) {
            return true
        }
        let scheme = url.scheme?.lowercased() ?? ""
        if scheme == "tribeboard" {
            let path = url.path.lowercased()
            return path == "/auth/callback" || path.hasPrefix("/auth/callback/")
        }
        guard let host = url.host?.lowercased() else { return false }
        let isTribeboardHost = host == "tribeboard.app" || host.hasSuffix(".tribeboard.app")
        guard isTribeboardHost else { return false }
        let path = url.path.lowercased()
        return path == "/auth/callback" || path.hasPrefix("/auth/callback/")
    }

    static func parseSession(from url: URL) -> ParsedSession? {
        guard isAuthCallbackURL(url) else { return nil }

        var items = mergedAuthTokenItems(from: url)
        guard let accessToken = items["access_token"]?.trimmingCharacters(in: .whitespacesAndNewlines),
              !accessToken.isEmpty else {
            return nil
        }

        let refreshToken = items["refresh_token"]?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        let expiresIn = items["expires_in"].flatMap { Int($0) }
        let tokenType = items["token_type"]?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        let authType = items["type"]?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty

        return ParsedSession(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresIn: expiresIn,
            tokenType: tokenType,
            authType: authType
        )
    }

    /// Supabase may redirect to Site URL root with tokens in the fragment (`/#access_token=…`).
    private static func containsAuthSessionTokens(in url: URL) -> Bool {
        let token = mergedAuthTokenItems(from: url)["access_token"]?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return !token.isEmpty
    }

    private static func mergedAuthTokenItems(from url: URL) -> [String: String] {
        var items = queryItems(from: url)
        if let fragmentItems = fragmentQueryItems(from: url.fragment) {
            for (key, value) in fragmentItems where items[key] == nil {
                items[key] = value
            }
        }
        return items
    }

    private static func queryItems(from url: URL) -> [String: String] {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            return [:]
        }
        var map: [String: String] = [:]
        for item in queryItems {
            guard let value = item.value else { continue }
            map[item.name.lowercased()] = value
        }
        return map
    }

    private static func fragmentQueryItems(from fragment: String?) -> [String: String]? {
        guard let fragment, !fragment.isEmpty else { return nil }
        let trimmed = fragment.hasPrefix("#") ? String(fragment.dropFirst()) : fragment
        guard !trimmed.isEmpty,
              let synthetic = URL(string: "https://example.invalid?\(trimmed)"),
              let components = URLComponents(url: synthetic, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            return nil
        }
        var map: [String: String] = [:]
        for item in queryItems {
            guard let value = item.value else { continue }
            map[item.name.lowercased()] = value
        }
        return map
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
