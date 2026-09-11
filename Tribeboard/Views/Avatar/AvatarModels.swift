import SwiftUI

enum AvatarType: String, Codable, CaseIterable, Hashable {
    case preset
    case uploaded
}

/// Presence / location ring shown around avatars across the app.
enum TribeAvatarStatus: Hashable {
    case available
    case atSchool
    case driving
    case activity

    var ringColor: Color {
        switch self {
        case .available: return Color(tribeHex: "#16B981")
        case .atSchool: return Color(tribeHex: "#F59E0B")
        case .driving: return Color(tribeHex: "#3B82F6")
        case .activity: return Color(tribeHex: "#6D5BD0")
        }
    }
}

enum TribeAvatarSize: Hashable {
    /// Stacked / inline avatars (e.g. passenger chips).
    case compact
    /// Top navigation bar profile avatar (48pt).
    case small
    /// Household and status cards (64pt).
    case medium
    case large
    case hero

    var dimension: CGFloat {
        switch self {
        case .compact: return 34
        case .small: return 48
        case .medium: return 64
        case .large: return 72
        case .hero: return 96
        }
    }

    var initialsFontSize: CGFloat {
        switch self {
        case .compact: return 11
        case .small: return 13
        case .medium: return 16
        case .large: return 22
        case .hero: return 28
        }
    }

    var borderWidth: CGFloat {
        switch self {
        case .compact: return 1.5
        case .small: return 2
        case .medium: return 2
        case .large: return 2
        case .hero: return 3
        }
    }

    var statusRingWidth: CGFloat {
        switch self {
        case .compact: return 1.5
        case .small: return 2
        case .medium: return 2
        case .large: return 2.5
        case .hero: return 3
        }
    }

    var statusDotSize: CGFloat {
        switch self {
        case .compact: return 9
        case .small: return 11
        case .medium: return 13
        case .large: return 14
        case .hero: return 16
        }
    }

    var statusDotStrokeWidth: CGFloat {
        switch self {
        case .compact: return 1.5
        case .small: return 2
        case .medium: return 2
        case .large: return 2.5
        case .hero: return 2.5
        }
    }

    var shadowRadius: CGFloat {
        switch self {
        case .compact: return 4
        case .small: return 5
        case .medium: return 5
        case .large: return 6
        case .hero: return 8
        }
    }

    var shadowYOffset: CGFloat {
        switch self {
        case .compact: return 2
        case .small: return 2
        case .medium: return 2
        case .large: return 3
        case .hero: return 4
        }
    }
}

struct TribeAvatarIdentity: Hashable {
    var avatarType: AvatarType
    var avatarKey: String?
    var avatarURL: String?
    var displayName: String

    init(
        avatarType: AvatarType = .preset,
        avatarKey: String? = nil,
        avatarURL: String? = nil,
        displayName: String
    ) {
        self.avatarType = avatarType
        self.avatarKey = avatarKey?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        self.avatarURL = avatarURL?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        self.displayName = displayName
    }

    var initials: String {
        TribeAvatarIdentity.initials(from: displayName)
    }

    static func initials(from name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let source = trimmed.isEmpty ? "Member" : trimmed
        let value = source
            .split(separator: " ")
            .prefix(2)
            .compactMap(\.first)
            .map(String.init)
            .joined()
            .uppercased()
        return value.isEmpty ? "M" : value
    }
}

extension BackendProfile {
    func avatarIdentity(fallbackDisplayName: String) -> TribeAvatarIdentity {
        let name = resolvedDisplayName(
            providerDisplayName: nil,
            fallbackEmail: nil
        ).value
        let resolvedName = name == "User" ? fallbackDisplayName : name
        let type = AvatarType(rawValue: avatar_type ?? AvatarType.preset.rawValue) ?? .preset
        return TribeAvatarIdentity(
            avatarType: type,
            avatarKey: avatar_key,
            avatarURL: avatar_url,
            displayName: resolvedName
        )
    }
}

extension BackendChild {
    func avatarIdentity() -> TribeAvatarIdentity {
        let name = displayName?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? legalName
        let type = AvatarType(rawValue: avatarType ?? AvatarType.preset.rawValue) ?? .preset
        return TribeAvatarIdentity(
            avatarType: type,
            avatarKey: avatarKey ?? AvatarPresetCatalog.defaultChildKey,
            avatarURL: avatarURL,
            displayName: name
        )
    }
}

extension BackendHouseholdPerson {
    func avatarIdentity() -> TribeAvatarIdentity {
        let type = AvatarType(rawValue: avatarType ?? AvatarType.preset.rawValue) ?? .preset
        return TribeAvatarIdentity(
            avatarType: type,
            avatarKey: avatarKey ?? AvatarPresetCatalog.defaultExtendedTribeKey,
            avatarURL: avatarURL,
            displayName: name
        )
    }
}

extension TribeMember {
    var avatarIdentity: TribeAvatarIdentity {
        if let storedType = avatarType {
            return TribeAvatarIdentity(
                avatarType: storedType,
                avatarKey: avatarKey,
                avatarURL: avatarURL,
                displayName: preferredDisplayName
            )
        }
        if let resolvedURL = avatarURL ?? profileImageURL?.absoluteString {
            return TribeAvatarIdentity(
                avatarType: .uploaded,
                avatarKey: nil,
                avatarURL: resolvedURL,
                displayName: preferredDisplayName
            )
        }
        if let key = avatarKey ?? avatarImageName {
            return TribeAvatarIdentity(
                avatarType: .preset,
                avatarKey: key,
                avatarURL: nil,
                displayName: preferredDisplayName
            )
        }
        return TribeAvatarIdentity(
            avatarType: .preset,
            avatarKey: AvatarPresetCatalog.defaultKey(for: memberType),
            avatarURL: nil,
            displayName: preferredDisplayName
        )
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
