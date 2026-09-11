import Foundation

struct BackendProfile: Codable, Identifiable {
    let id: UUID
    let email: String?
    let display_name: String?
    let first_name: String?
    let last_name: String?
    let avatar_type: String?
    let avatar_key: String?
    let avatar_url: String?
    let avatar_updated_at: String?
    let created_at: String?
    let updated_at: String?
}

extension BackendProfile {
    func resolvedDisplayName(
        providerDisplayName: String?,
        fallbackEmail: String?
    ) -> (value: String, source: String) {
        if let display = display_name?.trimmingCharacters(in: .whitespacesAndNewlines), !display.isEmpty {
            return (display, "display_name")
        }
        let composedName = [first_name, last_name]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        if !composedName.isEmpty {
            return (composedName, "first_last")
        }
        if let provider = providerDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines), !provider.isEmpty {
            return (provider, "provider_name")
        }
        let emailCandidate = email?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            ?? fallbackEmail?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        if let emailCandidate {
            let alias = emailCandidate.split(separator: "@").first.map(String.init) ?? emailCandidate
            let trimmedAlias = alias.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedAlias.isEmpty {
                return (trimmedAlias, "email_alias")
            }
        }
        return ("User", "default")
    }

    func resolvedInitials(
        providerDisplayName: String?,
        fallbackEmail: String?
    ) -> String {
        let display = resolvedDisplayName(providerDisplayName: providerDisplayName, fallbackEmail: fallbackEmail).value
        let value = display
            .split(separator: " ")
            .prefix(2)
            .compactMap(\.first)
            .map(String.init)
            .joined()
            .uppercased()
        return value.isEmpty ? "U" : value
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
