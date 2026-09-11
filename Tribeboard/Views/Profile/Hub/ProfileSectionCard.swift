import SwiftUI

struct ProfileSectionCard<Rows: View>: View {
    let title: String
    let accent: ProfileSectionAccent
    var cardBackground: Color = ProfileHubTheme.cardBackground
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
        .clipShape(RoundedRectangle(cornerRadius: ProfileHubTheme.cardCornerRadius, style: .continuous))
        .shadow(color: ProfileHubTheme.cardShadow, radius: 12, x: 0, y: 4)
    }
}

struct ProfileSectionHeader: View {
    let title: String
    var titleColor: Color = ProfileHubTheme.titlePrimary

    var body: some View {
        Text(title)
            .font(.system(size: 17, weight: .bold))
            .foregroundStyle(titleColor)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
    }
}
