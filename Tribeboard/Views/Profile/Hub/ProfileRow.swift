import SwiftUI
import UIKit

struct ProfileRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let accent: ProfileRowAccent
    var trailingValue: String? = nil
    var showsDivider: Bool = true
    var isDisabled: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 14) {
                Image(systemName: resolvedIconName)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(accent.iconColor.opacity(isDisabled ? 0.45 : 1))
                    .symbolRenderingMode(.monochrome)
                    .frame(width: ProfileHubTheme.iconTileSize, height: ProfileHubTheme.iconTileSize)
                    .background(accent.iconBackground.opacity(isDisabled ? 0.55 : 1))
                    .clipShape(RoundedRectangle(cornerRadius: ProfileHubTheme.iconTileCornerRadius, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(accent.titleColor.opacity(isDisabled ? 0.55 : 1))
                        .multilineTextAlignment(.leading)
                    Text(subtitle)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(ProfileHubTheme.subtitleSecondary.opacity(isDisabled ? 0.7 : 1))
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                if let trailingValue {
                    HStack(spacing: 4) {
                        Text(trailingValue)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(ProfileHubTheme.subtitleSecondary)
                        if !isDisabled {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color(red: 0.78, green: 0.80, blue: 0.84))
                        }
                    }
                } else if !isDisabled {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color(red: 0.78, green: 0.80, blue: 0.84))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())

            if showsDivider {
                Divider()
                    .overlay(ProfileHubTheme.divider)
                    .padding(.leading, 16 + ProfileHubTheme.iconTileSize + 14)
            }
        }
    }

    private var resolvedIconName: String {
        if UIImage(systemName: icon) != nil { return icon }
        return "person.fill"
    }
}

struct ProfileRowButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let accent: ProfileRowAccent
    var trailingValue: String? = nil
    var showsDivider: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ProfileRow(
                icon: icon,
                title: title,
                subtitle: subtitle,
                accent: accent,
                trailingValue: trailingValue,
                showsDivider: showsDivider
            )
        }
        .buttonStyle(.plain)
    }
}

struct ProfileManageActionTileContent: View {
    let icon: String
    let title: String
    let subtitle: String
    var isDisabled: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(TribePalette.primary.opacity(isDisabled ? 0.45 : 1))
                .frame(width: 40, height: 40)
                .background(TribePalette.primarySoft.opacity(isDisabled ? 0.55 : 1))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(ProfileHubTheme.titlePrimary.opacity(isDisabled ? 0.55 : 1))
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(ProfileHubTheme.subtitleSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(ProfileHubTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: ProfileHubTheme.cardShadow, radius: 8, x: 0, y: 3)
    }
}

struct ProfileManageActionTile: View {
    let icon: String
    let title: String
    let subtitle: String
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ProfileManageActionTileContent(
                icon: icon,
                title: title,
                subtitle: subtitle,
                isDisabled: isDisabled
            )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }
}
