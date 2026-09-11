import SwiftUI

struct SettingsHeroCard: View {
    let identity: TribeAvatarIdentity
    let displayName: String
    let roleLabel: String
    let householdName: String
    let memberCount: Int
    let childCount: Int
    let driverCount: Int
    let connection: SettingsHouseholdIntelligence.HeroConnection
    var accessToken: String? = nil

    var body: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: SettingsHubTheme.cardCornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(tribeHex: "#6D5BD0"), Color(tribeHex: "#8B7BE8"), Color(tribeHex: "#5B7CFA")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Image(systemName: "house.lodge.fill")
                .font(.system(size: 88, weight: .ultraLight))
                .foregroundStyle(.white.opacity(0.10))
                .offset(x: 18, y: 42)
                .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 14) {
                profileRow
                householdHeaderRow
                statsRow
                connectionPill
            }
            .padding(16)
        }
        .shadow(color: TribePalette.primary.opacity(0.30), radius: 16, x: 0, y: 10)
    }

    private var profileRow: some View {
        HStack(alignment: .center, spacing: 12) {
            avatarView

            VStack(alignment: .leading, spacing: 3) {
                Text(displayName)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text("\(roleLabel) • \(householdName)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.88))
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            NavigationLink {
                ProfileView()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "person.fill")
                        .font(.system(size: 11, weight: .bold))
                    Text("View Profile")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundStyle(TribePalette.primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(.white.opacity(0.95), in: Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    private var avatarView: some View {
        TribeAvatarView(
            identity: identity,
            size: .medium,
            status: connection.isAllGood ? .available : nil,
            accessToken: accessToken
        )
    }

    private var householdHeaderRow: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(householdName)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)

            Spacer(minLength: 8)

            HStack(spacing: 5) {
                Circle()
                    .fill(connection.isAllGood ? TribePalette.green : TribePalette.orange)
                    .frame(width: 7, height: 7)
                Text(connection.stateLabel)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white.opacity(0.92))
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(Color.white.opacity(0.16), in: Capsule())
        }
    }

    private var statsRow: some View {
        HStack(spacing: 8) {
            statTile(value: memberCount, label: memberCount == 1 ? "Member" : "Members", icon: "person.2.fill")
            statTile(value: childCount, label: childCount == 1 ? "Child" : "Children", icon: "figure.child")
            statTile(value: driverCount, label: driverCount == 1 ? "Driver" : "Drivers", icon: "car.fill")
        }
    }

    private func statTile(value: Int, label: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
                Text("\(value)")
                    .font(.system(size: 15, weight: .bold))
            }
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var connectionPill: some View {
        HStack(spacing: 10) {
            Image(systemName: connection.isAllGood ? "checkmark.shield.fill" : "person.badge.plus")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(connection.isAllGood ? TribePalette.green : .white.opacity(0.9))
                .frame(width: 28, height: 28)
                .background(Color.white.opacity(0.18), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(connection.headline)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                Text(connection.lastActiveText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.82))
            }

            Spacer(minLength: 4)

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white.opacity(0.65))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
