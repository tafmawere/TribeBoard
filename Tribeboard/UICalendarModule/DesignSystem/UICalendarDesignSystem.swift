import SwiftUI

enum UICalendarDesignSystem {
    enum Colors {
        static let background = Color(red: 0.976, green: 0.980, blue: 0.984) // #F9FAFB
        static let card = Color.white
        static let primary = Color(red: 0.388, green: 0.400, blue: 0.945) // #6366F1
        static let success = Color(red: 0.063, green: 0.725, blue: 0.506) // #10B981
        static let warning = Color(red: 0.961, green: 0.620, blue: 0.043) // #F59E0B
        static let textPrimary = Color(red: 0.122, green: 0.161, blue: 0.216) // #1F2937
        static let textSecondary = Color(red: 0.420, green: 0.447, blue: 0.502) // #6B7280
        static let textTertiary = Color(red: 0.612, green: 0.635, blue: 0.690) // #9CA3AF
        static let border = Color.black.opacity(0.08)
    }

    enum Spacing {
        static let xSmall: CGFloat = 8
        static let small: CGFloat = 12
        static let medium: CGFloat = 16
        static let large: CGFloat = 20
        static let xLarge: CGFloat = 24
    }

    enum Radius {
        static let small: CGFloat = 12
        static let medium: CGFloat = 16
        static let large: CGFloat = 20
        static let xLarge: CGFloat = 24
    }

    enum Shadow {
        static let color = Color.black.opacity(0.06)
        static let radius: CGFloat = 10
        static let y: CGFloat = 6
    }
}
