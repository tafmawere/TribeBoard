import SwiftUI

struct SettingsHubSectionCard<Rows: View>: View {
    let title: String
    let accent: SettingsHubSectionAccent
    var cardBackground: Color = SettingsHubTheme.cardBackground
    @ViewBuilder let rows: () -> Rows

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: accent.headerIcon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(accent.titleColor)
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.5)
                    .foregroundStyle(accent.titleColor)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 4)

            rows()
        }
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: SettingsHubTheme.cardCornerRadius, style: .continuous))
        .shadow(color: SettingsHubTheme.cardShadow, radius: 12, x: 0, y: 4)
    }
}
