import Foundation

enum OnboardingInviteProfileSupport {
    static func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func isDisplayNameOnlyEmail(_ displayName: String, email: String?) -> Bool {
        let trimmedDisplay = normalized(displayName).lowercased()
        guard !trimmedDisplay.isEmpty else { return false }
        guard let email = email?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              !email.isEmpty else {
            return false
        }
        return trimmedDisplay == email
    }

    /// Profile must be collected on invite acceptance when names are missing or display is email-only.
    static func needsProfileCapture(profile: BackendProfile?, email: String?) -> Bool {
        let candidateEmail = profile?.email ?? email
        let first = profile?.first_name?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        let display = profile?.display_name?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        if first == nil {
            return true
        }
        if display == nil {
            return true
        }
        if isDisplayNameOnlyEmail(display ?? "", email: candidateEmail) {
            return true
        }
        return false
    }

    static func prefillDraft(from profile: BackendProfile?) -> OnboardingProfileDraft {
        guard let profile else {
            return OnboardingProfileDraft(firstName: "", lastName: "", displayName: "")
        }
        let avatarType = AvatarType(rawValue: profile.avatar_type ?? AvatarType.preset.rawValue) ?? .preset
        return OnboardingProfileDraft(
            firstName: profile.first_name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            lastName: profile.last_name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            displayName: profile.display_name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            avatarType: avatarType,
            avatarKey: profile.avatar_key,
            avatarURL: profile.avatar_url
        )
    }

    static func resolvedDisplayName(firstName: String, displayName: String) -> String {
        let trimmedDisplay = normalized(displayName)
        if !trimmedDisplay.isEmpty {
            return trimmedDisplay
        }
        return normalized(firstName)
    }

    static func validationError(
        firstName: String,
        lastName: String,
        displayName: String,
        email: String?,
        requiresProfileFields: Bool
    ) -> String? {
        guard requiresProfileFields else { return nil }
        let first = normalized(firstName)
        let display = resolvedDisplayName(firstName: firstName, displayName: displayName)
        if first.isEmpty {
            return "Enter your first name to accept this invite."
        }
        if display.isEmpty {
            return "Enter how your name should appear in the tribe."
        }
        if isDisplayNameOnlyEmail(display, email: email) {
            return "Use a name instead of your email address."
        }
        _ = lastName
        return nil
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
