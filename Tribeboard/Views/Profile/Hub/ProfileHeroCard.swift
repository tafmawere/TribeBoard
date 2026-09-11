import SwiftUI

struct ProfileHeroCard: View {
    let identity: TribeAvatarIdentity
    let displayName: String
    let roleBadge: String
    let householdName: String
    let isActiveMember: Bool
    let joinedDateText: String?
    let roles: [ProfileRoleKind]
    var accessToken: String? = nil
    var onAvatarEdit: (() -> Void)?

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            RoundedRectangle(cornerRadius: ProfileHubTheme.cardCornerRadius, style: .continuous)
                .fill(ProfileHubTheme.cardBackground)

            Image(systemName: "house.and.flag.fill")
                .font(.system(size: 96, weight: .ultraLight))
                .foregroundStyle(TribePalette.primary.opacity(0.08))
                .offset(x: 12, y: 18)
                .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 14) {
                    avatarBlock

                    VStack(alignment: .leading, spacing: 6) {
                        Text(displayName)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(ProfileHubTheme.titlePrimary)
                            .lineLimit(2)

                        Text(roleBadge)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(TribePalette.primary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(TribePalette.primarySoft, in: Capsule())

                        HStack(spacing: 5) {
                            Image(systemName: "house.fill")
                                .font(.system(size: 11, weight: .semibold))
                            Text(householdName)
                                .font(.system(size: 13, weight: .semibold))
                                .lineLimit(1)
                        }
                        .foregroundStyle(TribePalette.primary)

                        HStack(spacing: 6) {
                            Circle()
                                .fill(isActiveMember ? TribePalette.green : TribePalette.orange)
                                .frame(width: 8, height: 8)
                            Text(isActiveMember ? "Active member" : "Inactive member")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(isActiveMember ? TribePalette.green : TribePalette.orange)
                        }
                    }

                    Spacer(minLength: 0)

                    if let joinedDateText {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Joined")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(ProfileHubTheme.subtitleSecondary)
                            Text(joinedDateText)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(ProfileHubTheme.subtitleSecondary)
                        }
                    }
                }

                if !roles.isEmpty {
                    ProfileRoleChipRow(roles: roles)
                }
            }
            .padding(16)
        }
        .shadow(color: ProfileHubTheme.cardShadow, radius: 12, x: 0, y: 4)
    }

    private var avatarBlock: some View {
        ZStack(alignment: .bottomTrailing) {
            TribeAvatarView(
                identity: identity,
                size: .large,
                accessToken: accessToken
            )

            if let onAvatarEdit {
                Button(action: onAvatarEdit) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 26, height: 26)
                        .background(TribePalette.primary, in: Circle())
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                }
                .buttonStyle(.plain)
                .offset(x: 2, y: 2)
            }
        }
    }
}
