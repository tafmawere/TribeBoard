import SwiftUI

struct FamilyStatusCard: View {
    let status: SettingsHouseholdIntelligence.FamilyStatus

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(TribePalette.green)
                .frame(width: 40, height: 40)
                .background(TribePalette.greenSoft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text("Family Status")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(TribePalette.green)

                Text(status.statusText)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(SettingsHubTheme.titlePrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(status.subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(SettingsHubTheme.subtitleSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: SettingsHubTheme.cardCornerRadius, style: .continuous)
                .fill(TribePalette.greenSoft.opacity(0.55))
        )
        .overlay {
            RoundedRectangle(cornerRadius: SettingsHubTheme.cardCornerRadius, style: .continuous)
                .stroke(TribePalette.green.opacity(0.12), lineWidth: 1)
        }
        .shadow(color: SettingsHubTheme.cardShadow, radius: 10, x: 0, y: 4)
    }
}
