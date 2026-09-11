import SwiftUI

enum ProfileHubTheme {
    static let screenBackground = SettingsHubTheme.screenBackground
    static let cardBackground = SettingsHubTheme.cardBackground
    static let titlePrimary = SettingsHubTheme.titlePrimary
    static let subtitleSecondary = SettingsHubTheme.subtitleSecondary
    static let divider = SettingsHubTheme.divider
    static let cardCornerRadius = SettingsHubTheme.cardCornerRadius
    static let iconTileSize = SettingsHubTheme.iconTileSize
    static let iconTileCornerRadius = SettingsHubTheme.iconTileCornerRadius
    static let horizontalPadding = SettingsHubTheme.horizontalPadding
    static let sectionSpacing = SettingsHubTheme.sectionSpacing
    static let cardShadow = SettingsHubTheme.cardShadow
    static let tabBarClearance = SettingsHubTheme.tabBarClearance

    static let dangerBackground = Color(tribeHex: "#FDF2F4")
    static let dangerAccent = Color(tribeHex: "#E34B5E")
    static let dangerAccentSoft = Color(tribeHex: "#FDE8EB")
}

enum ProfileSectionAccent {
    case identity
    case account
    case danger

    var titleColor: Color {
        switch self {
        case .identity, .account: return TribePalette.primary
        case .danger: return ProfileHubTheme.dangerAccent
        }
    }

    var headerIcon: String {
        switch self {
        case .identity: return "person.fill"
        case .account: return "lock.shield.fill"
        case .danger: return "exclamationmark.triangle.fill"
        }
    }
}

enum ProfileRowAccent {
    case identity
    case account
    case danger

    var iconColor: Color {
        switch self {
        case .identity, .account: return TribePalette.primary
        case .danger: return ProfileHubTheme.dangerAccent
        }
    }

    var iconBackground: Color {
        switch self {
        case .identity, .account: return TribePalette.primarySoft
        case .danger: return ProfileHubTheme.dangerAccentSoft
        }
    }

    var titleColor: Color {
        switch self {
        case .danger: return ProfileHubTheme.dangerAccent
        default: return ProfileHubTheme.titlePrimary
        }
    }
}
