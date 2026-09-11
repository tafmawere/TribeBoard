import SwiftUI

struct ProfileHouseholdCard: View {
    let householdName: String
    let memberCount: Int
    let childCount: Int
    let driverCount: Int

    var body: some View {
        VStack(spacing: 0) {
                HStack(alignment: .center, spacing: 14) {
                    Image(systemName: "house.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(TribePalette.primary)
                        .frame(width: ProfileHubTheme.iconTileSize, height: ProfileHubTheme.iconTileSize)
                        .background(TribePalette.primarySoft)
                        .clipShape(RoundedRectangle(cornerRadius: ProfileHubTheme.iconTileCornerRadius, style: .continuous))

                    VStack(alignment: .leading, spacing: 3) {
                        Text("My Household")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(ProfileHubTheme.subtitleSecondary)
                        Text(householdName)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(TribePalette.primary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 8)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color(red: 0.78, green: 0.80, blue: 0.84))
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 12)

                Divider()
                    .overlay(ProfileHubTheme.divider)
                    .padding(.horizontal, 16)

                HStack(spacing: 0) {
                    statItem(
                        value: memberCount,
                        label: memberCount == 1 ? "Member" : "Members",
                        icon: "person.2.fill",
                        color: TribePalette.primary
                    )
                    statItem(
                        value: childCount,
                        label: childCount == 1 ? "Child" : "Children",
                        icon: "figure.child",
                        color: TribePalette.green
                    )
                    statItem(
                        value: driverCount,
                        label: driverCount == 1 ? "Driver" : "Drivers",
                        icon: "car.fill",
                        color: TribePalette.blue
                    )
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 12)
            }
        .background(ProfileHubTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: ProfileHubTheme.cardCornerRadius, style: .continuous))
        .shadow(color: ProfileHubTheme.cardShadow, radius: 12, x: 0, y: 4)
        .contentShape(Rectangle())
    }

    private func statItem(value: Int, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(color)
                Text("\(value)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(ProfileHubTheme.titlePrimary)
            }
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(ProfileHubTheme.subtitleSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}
