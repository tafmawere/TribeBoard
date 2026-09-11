import SwiftUI

struct ProfileDangerZoneCard<Rows: View>: View {
    @ViewBuilder let rows: () -> Rows

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(ProfileHubTheme.dangerAccent)
                Text("DANGER ZONE")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.5)
                    .foregroundStyle(ProfileHubTheme.dangerAccent)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 4)

            rows()
        }
        .background(ProfileHubTheme.dangerBackground)
        .clipShape(RoundedRectangle(cornerRadius: ProfileHubTheme.cardCornerRadius, style: .continuous))
        .shadow(color: ProfileHubTheme.cardShadow, radius: 12, x: 0, y: 4)
    }
}
