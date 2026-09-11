import SwiftUI
import UIKit

struct SettingsHubRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let accent: SettingsHubRowAccent
    var trailingValue: String? = nil
    var toggle: Binding<Bool>? = nil
    var showsDivider: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 14) {
                Image(systemName: resolvedIconName)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(accent.iconColor)
                    .symbolRenderingMode(.monochrome)
                    .frame(width: SettingsHubTheme.iconTileSize, height: SettingsHubTheme.iconTileSize)
                    .background(accent.iconBackground)
                    .clipShape(RoundedRectangle(cornerRadius: SettingsHubTheme.iconTileCornerRadius, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(accent.titleColor)
                        .multilineTextAlignment(.leading)
                    Text(subtitle)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(SettingsHubTheme.subtitleSecondary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                if let toggle {
                    Toggle("", isOn: toggle)
                        .labelsHidden()
                        .tint(TribePalette.primary)
                } else if let trailingValue {
                    HStack(spacing: 4) {
                        Text(trailingValue)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(SettingsHubTheme.subtitleSecondary)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color(red: 0.78, green: 0.80, blue: 0.84))
                    }
                } else {
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
                    .overlay(SettingsHubTheme.divider)
                    .padding(.leading, 16 + SettingsHubTheme.iconTileSize + 14)
            }
        }
    }

    private var resolvedIconName: String {
        if UIImage(systemName: icon) != nil { return icon }
        return "gearshape.fill"
    }
}

struct SettingsHubRowButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let accent: SettingsHubRowAccent
    var trailingValue: String? = nil
    var showsDivider: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            SettingsHubRow(
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
