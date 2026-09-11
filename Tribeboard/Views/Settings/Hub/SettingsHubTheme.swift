import SwiftUI

enum SettingsHubTheme {
    static let screenBackground = TribePalette.canvas
    static let cardBackground = TribePalette.surface
    static let titlePrimary = TribePalette.ink
    static let subtitleSecondary = TribePalette.muted
    static let divider = Color(red: 0.90, green: 0.91, blue: 0.93)

    static let cardCornerRadius: CGFloat = 20
    static let iconTileSize: CGFloat = 44
    static let iconTileCornerRadius: CGFloat = 12
    static let horizontalPadding: CGFloat = 16
    static let sectionSpacing: CGFloat = 12
    static let cardShadow = Color.black.opacity(0.06)
    static let tabBarClearance: CGFloat = 49 + 48
}

enum SettingsHubSectionAccent {
    case household
    case runs
    case safety
    case legalSupport
    case app
    case danger

    var titleColor: Color {
        switch self {
        case .household, .legalSupport: return TribePalette.primary
        case .runs, .app: return TribePalette.blue
        case .safety: return TribePalette.green
        case .danger: return Color(tribeHex: "#E34B5E")
        }
    }

    var headerIcon: String {
        switch self {
        case .household: return "house.fill"
        case .runs: return "car.fill"
        case .safety: return "shield.lefthalf.filled"
        case .legalSupport: return "lock.shield.fill"
        case .app: return "gearshape.fill"
        case .danger: return "exclamationmark.triangle.fill"
        }
    }
}

enum SettingsHubRowAccent {
    case household
    case runs
    case safety
    case legal
    case support
    case app
    case danger
    case warning

    var iconColor: Color {
        switch self {
        case .household, .legal: return TribePalette.primary
        case .runs, .app, .support: return TribePalette.blue
        case .safety: return TribePalette.green
        case .danger: return Color(tribeHex: "#E34B5E")
        case .warning: return TribePalette.orange
        }
    }

    var iconBackground: Color {
        switch self {
        case .household, .legal: return TribePalette.primarySoft
        case .runs, .app, .support: return TribePalette.blueSoft
        case .safety: return TribePalette.greenSoft
        case .danger: return Color(tribeHex: "#FDE8EB")
        case .warning: return TribePalette.orangeSoft
        }
    }

    var titleColor: Color {
        switch self {
        case .danger: return Color(tribeHex: "#E34B5E")
        case .warning: return TribePalette.orange
        default: return SettingsHubTheme.titlePrimary
        }
    }
}
