import SwiftUI

enum LegalSafetyTheme {
    static let screenBackground = Color(red: 0.965, green: 0.969, blue: 0.976)
    static let cardBackground = Color.white
    static let titlePrimary = Color(red: 0.12, green: 0.16, blue: 0.28)
    static let subtitleSecondary = Color(red: 0.45, green: 0.48, blue: 0.55)
    static let divider = Color(red: 0.90, green: 0.91, blue: 0.93)

    static let brandPurple = Color(red: 0.388, green: 0.400, blue: 0.945)
    static let legalBlue = Color(red: 0.22, green: 0.45, blue: 0.95)
    static let safetyGreen = Color(red: 0.18, green: 0.62, blue: 0.42)
    static let alertOrange = Color(red: 0.92, green: 0.48, blue: 0.22)
    static let dangerRed = Color(red: 0.90, green: 0.28, blue: 0.28)
    static let supportBlue = Color(red: 0.22, green: 0.45, blue: 0.95)

    static let cardCornerRadius: CGFloat = 20
    static let iconTileSize: CGFloat = 44
    static let iconTileCornerRadius: CGFloat = 12
    static let horizontalPadding: CGFloat = 16
    static let cardShadow = Color.black.opacity(0.06)
    static let sectionSpacing: CGFloat = 12
    static let scrollBottomInset: CGFloat = 48

    /// Standard tab bar (~49pt) plus extra breathing room above the home indicator.
    static let tabBarClearance: CGFloat = 49 + scrollBottomInset
}

enum LegalSafetySectionAccent {
    case legal
    case safety
    case account

    var titleColor: Color {
        switch self {
        case .legal: return LegalSafetyTheme.brandPurple
        case .safety: return LegalSafetyTheme.safetyGreen
        case .account: return LegalSafetyTheme.brandPurple
        }
    }

    var headerIcon: String {
        switch self {
        case .legal: return "doc.text.fill"
        case .safety: return "shield.lefthalf.filled"
        case .account: return "person.crop.circle.fill"
        }
    }
}

enum LegalSafetyRowAccent {
    case legal
    case safety
    case alert
    case danger
    case support

    var iconColor: Color {
        switch self {
        case .legal: return LegalSafetyTheme.legalBlue
        case .safety: return LegalSafetyTheme.safetyGreen
        case .alert: return LegalSafetyTheme.alertOrange
        case .danger: return LegalSafetyTheme.dangerRed
        case .support: return LegalSafetyTheme.supportBlue
        }
    }

    var iconBackground: Color {
        iconColor.opacity(0.14)
    }

    var titleColor: Color {
        switch self {
        case .alert, .danger: return iconColor
        default: return LegalSafetyTheme.titlePrimary
        }
    }
}
