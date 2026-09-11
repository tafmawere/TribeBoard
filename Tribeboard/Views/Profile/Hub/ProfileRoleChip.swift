import SwiftUI

struct ProfileRoleChip: View {
    let role: ProfileRoleKind

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: role.icon)
                .font(.system(size: 12, weight: .semibold))
            Text(role.title)
                .font(.system(size: 13, weight: .semibold))
        }
        .foregroundStyle(TribePalette.primary)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(TribePalette.primarySoft, in: Capsule())
    }
}

struct ProfileRoleChipRow: View {
    let roles: [ProfileRoleKind]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("My Roles")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(ProfileHubTheme.titlePrimary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(roles) { role in
                        ProfileRoleChip(role: role)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
