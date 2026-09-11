import Foundation

enum GoogleSignInConfig {
    private static let clientIDInfoPlistKey = "GIDClientID"
    private static let clientIDBuildSettingKey = "GOOGLE_IOS_CLIENT_ID"
    private static let webClientIDInfoPlistKey = "GOOGLE_WEB_CLIENT_ID"
    private static let webClientIDBuildSettingKey = "GOOGLE_WEB_CLIENT_ID"
    private static let reversedSchemePrefix = "com.googleusercontent.apps."

    /// iOS OAuth client ID from Info.plist (`GIDClientID` / `GOOGLE_IOS_CLIENT_ID` via xcconfig). Not the Supabase web client ID.
    static var clientID: String? {
        if let env = ProcessInfo.processInfo.environment[clientIDBuildSettingKey]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !env.isEmpty,
           !env.contains("$(") {
            return env
        }

        for key in [clientIDInfoPlistKey, clientIDBuildSettingKey] {
            if let value = resolvedClientID(fromInfoPlistKey: key) {
                return value
            }
        }

        return clientIDFromRegisteredURLScheme()
    }

    /// Web OAuth client ID (Google Cloud Console → Web application). Required as `serverClientID` so Google issues an ID token Supabase can verify.
    static var webClientID: String? {
        if let env = ProcessInfo.processInfo.environment[webClientIDBuildSettingKey]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !env.isEmpty,
           !env.contains("$(") {
            return env
        }

        for key in [webClientIDInfoPlistKey, webClientIDBuildSettingKey] {
            if let value = resolvedClientID(fromInfoPlistKey: key) {
                return value
            }
        }
        return nil
    }

    static var isConfigured: Bool {
        clientID != nil
    }

    static var isFullyConfiguredForSupabase: Bool {
        clientID != nil && webClientID != nil
    }

    /// Reversed client ID URL scheme required in Info.plist for Google Sign-In callbacks.
    static var reversedClientIDURLScheme: String? {
        if let clientID,
           clientID.hasSuffix(".apps.googleusercontent.com") {
            let uniquePart = String(clientID.dropLast(".apps.googleusercontent.com".count))
            guard !uniquePart.isEmpty else { return nil }
            return reversedSchemePrefix + uniquePart
        }
        return registeredReversedClientIDURLScheme()
    }

    private static func resolvedClientID(fromInfoPlistKey key: String) -> String? {
        guard let plistValue = Bundle.main.object(forInfoDictionaryKey: key) as? String else {
            return nil
        }
        let trimmed = plistValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains("$(") else { return nil }
        return trimmed
    }

    private static func clientIDFromRegisteredURLScheme() -> String? {
        guard let uniquePart = registeredReversedClientIDUniquePart() else { return nil }
        return "\(uniquePart).apps.googleusercontent.com"
    }

    private static func registeredReversedClientIDURLScheme() -> String? {
        guard let uniquePart = registeredReversedClientIDUniquePart() else { return nil }
        return reversedSchemePrefix + uniquePart
    }

    private static func registeredReversedClientIDUniquePart() -> String? {
        guard let urlTypes = Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]] else {
            return nil
        }
        for type in urlTypes {
            guard let schemes = type["CFBundleURLSchemes"] as? [String] else { continue }
            for scheme in schemes {
                let trimmed = scheme.trimmingCharacters(in: .whitespacesAndNewlines)
                guard trimmed.hasPrefix(reversedSchemePrefix), !trimmed.contains("$(") else { continue }
                let uniquePart = String(trimmed.dropFirst(reversedSchemePrefix.count))
                guard !uniquePart.isEmpty else { continue }
                return uniquePart
            }
        }
        return nil
    }
}
