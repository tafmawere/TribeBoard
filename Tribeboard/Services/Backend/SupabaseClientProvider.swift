import Foundation

enum SupabaseClientProvider {
    struct Configuration {
        let projectURL: URL
        let anonKey: String
    }

    enum ProviderError: LocalizedError {
        case invalidURL
        case missingKey
        case missingAccessToken

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Supabase URL is not configured."
            case .missingKey:
                return "Supabase anon key is not configured."
            case .missingAccessToken:
                return "Authenticated backend write attempted without access token."
            }
        }
    }

    static func configuration() throws -> Configuration {
        guard let url = URL(string: BackendConfig.supabaseURL), !BackendConfig.supabaseURL.isEmpty else {
            throw ProviderError.invalidURL
        }
        guard !BackendConfig.supabaseAnonKey.isEmpty else {
            throw ProviderError.missingKey
        }
        return Configuration(projectURL: url, anonKey: BackendConfig.supabaseAnonKey)
    }

    static func authURL(path: String, queryItems: [URLQueryItem] = []) throws -> URL {
        let config = try configuration()
        let base = config.projectURL
            .appendingPathComponent("auth")
            .appendingPathComponent("v1")
        return try buildURL(base: base, path: path, queryItems: queryItems)
    }

    static func restURL(path: String) throws -> URL {
        let config = try configuration()
        let base = config.projectURL
            .appendingPathComponent("rest")
            .appendingPathComponent("v1")
        return try buildURL(base: base, path: path)
    }

    static func functionsURL(path: String) throws -> URL {
        let config = try configuration()
        let base = config.projectURL
            .appendingPathComponent("functions")
            .appendingPathComponent("v1")
        return try buildURL(base: base, path: path)
    }

    static func defaultHeaders(accessToken: String? = nil) throws -> [String: String] {
        let config = try configuration()
        var headers = [
            "apikey": config.anonKey,
            "Content-Type": "application/json"
        ]
        if let accessToken, !accessToken.isEmpty {
            headers["Authorization"] = "Bearer \(accessToken)"
        }
        return headers
    }

    static func authenticatedHeaders(accessToken: String) throws -> [String: String] {
        let trimmed = accessToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ProviderError.missingAccessToken
        }
        return try defaultHeaders(accessToken: trimmed)
    }

    private static func buildURL(base: URL, path: String, queryItems: [URLQueryItem] = []) throws -> URL {
        let components = path.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
        let rawPath = String(components.first ?? "")
        let queryFromPath = components.count > 1 ? String(components[1]) : nil

        var finalURL = base.appendingPathComponent(rawPath)
        guard var urlComponents = URLComponents(url: finalURL, resolvingAgainstBaseURL: false) else {
            throw ProviderError.invalidURL
        }

        var mergedItems = queryItems
        if let queryFromPath, !queryFromPath.isEmpty,
           let synthetic = URL(string: "https://example.invalid?\(queryFromPath)"),
           let extra = URLComponents(url: synthetic, resolvingAgainstBaseURL: false)?.queryItems {
                mergedItems.append(contentsOf: extra)
        }
        if !mergedItems.isEmpty {
            urlComponents.queryItems = mergedItems
        }

        guard let url = urlComponents.url else {
            throw ProviderError.invalidURL
        }
        finalURL = url
        return finalURL
    }
}
