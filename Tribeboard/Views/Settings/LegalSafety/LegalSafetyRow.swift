import SwiftUI
import UIKit

struct LegalSafetyRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let accent: LegalSafetyRowAccent
    var showsDivider: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 14) {
                iconTile

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(accent.titleColor)
                        .multilineTextAlignment(.leading)

                    Text(subtitle)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(LegalSafetyTheme.subtitleSecondary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(red: 0.78, green: 0.80, blue: 0.84))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())

            if showsDivider {
                Divider()
                    .overlay(LegalSafetyTheme.divider)
                    .padding(.leading, 16 + LegalSafetyTheme.iconTileSize + 14)
            }
        }
    }

    private var iconTile: some View {
        Image(systemName: resolvedIconName)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(accent.iconColor)
            .symbolRenderingMode(.monochrome)
            .frame(width: LegalSafetyTheme.iconTileSize, height: LegalSafetyTheme.iconTileSize)
            .background(accent.iconBackground)
            .clipShape(RoundedRectangle(cornerRadius: LegalSafetyTheme.iconTileCornerRadius, style: .continuous))
    }

    private var resolvedIconName: String {
        if UIImage(systemName: icon) != nil {
            return icon
        }
        return "globe.americas.fill"
    }
}

struct LegalSafetyRowButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let accent: LegalSafetyRowAccent
    var showsDivider: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            LegalSafetyRow(
                icon: icon,
                title: title,
                subtitle: subtitle,
                accent: accent,
                showsDivider: showsDivider
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack(spacing: 0) {
        LegalSafetyRow(
            icon: "hand.raised.fill",
            title: "Privacy Policy",
            subtitle: "How we collect, use, and protect your data",
            accent: .legal
        )
        LegalSafetyRow(
            icon: "trash.fill",
            title: "Delete My Account",
            subtitle: "Permanently remove your account and data",
            accent: .danger,
            showsDivider: false
        )
    }
    .background(Color.white)
    .clipShape(RoundedRectangle(cornerRadius: 20))
    .padding()
}
