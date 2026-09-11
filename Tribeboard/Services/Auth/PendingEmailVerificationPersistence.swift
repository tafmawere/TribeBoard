import Foundation

/// Keeps the pending signup email when the user must verify before a session exists.
enum PendingEmailVerificationPersistence {
    private static let emailKey = "tb.pendingEmailVerification.email"

    static func save(email: String, userDefaults: UserDefaults = .standard) {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return }
        userDefaults.set(trimmed, forKey: emailKey)
    }

    static func load(userDefaults: UserDefaults = .standard) -> String? {
        let value = userDefaults.string(forKey: emailKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard let value, !value.isEmpty else { return nil }
        return value
    }

    static func clear(userDefaults: UserDefaults = .standard) {
        userDefaults.removeObject(forKey: emailKey)
    }
}
