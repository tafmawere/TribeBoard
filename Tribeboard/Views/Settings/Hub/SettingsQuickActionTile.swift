import SwiftUI

struct SettingsQuickActionTile: View {
    let icon: String
    let title: String
    let subtitle: String
    let accent: SettingsHubRowAccent

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(accent.iconColor)
                .frame(width: 38, height: 38)
                .background(accent.iconBackground, in: RoundedRectangle(cornerRadius: 11, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(SettingsHubTheme.titlePrimary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(SettingsHubTheme.subtitleSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(SettingsHubTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: SettingsHubTheme.cardShadow, radius: 10, x: 0, y: 4)
    }
}

struct SettingsQuickActionsRow: View {
    let householdName: String
    let onInvite: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            NavigationLink {
                HouseholdSwitcherView()
            } label: {
                SettingsQuickActionTile(
                    icon: "house.fill",
                    title: "Switch Household",
                    subtitle: householdName,
                    accent: .household
                )
            }
            .buttonStyle(.plain)

            Button(action: onInvite) {
                SettingsQuickActionTile(
                    icon: "person.badge.plus",
                    title: "Invite Member",
                    subtitle: "Add to your family",
                    accent: .household
                )
            }
            .buttonStyle(.plain)
        }
    }
}
