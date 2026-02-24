import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var flow: AppFlowState
    @AppStorage("profile.activeRole") private var activeRoleRawValue = ProfileSessionRole.driver.rawValue

    private var activeRole: ProfileSessionRole {
        get { ProfileSessionRole(rawValue: activeRoleRawValue) ?? .driver }
        set { activeRoleRawValue = newValue.rawValue }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                headerCard
                roleSwitcherCard
                accountCard
                sessionCard
            }
            .padding(16)
        }
        .background(Color(white: 0.97))
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var headerCard: some View {
        VStack(spacing: 10) {
            Circle()
                .fill(Color.indigo.opacity(0.14))
                .frame(width: 72, height: 72)
                .overlay(Text("TM").font(.title3).bold().foregroundStyle(Color.indigo))

            Text("Tafadzwa Mawere")
                .font(.title3.bold())

            HStack(spacing: 8) {
                rolePill("Parent")
                rolePill("Admin")
                rolePill(activeRole.title)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(18)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
    }

    private var roleSwitcherCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Active Role")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)

            Picker("Active Role", selection: Binding(
                get: { activeRole },
                set: { activeRole = $0 }
            )) {
                ForEach(ProfileSessionRole.allCases, id: \.self) { role in
                    Text(role.title).tag(role)
                }
            }
            .pickerStyle(.segmented)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
    }

    private var accountCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Account")
            profileRow(title: "Manage Account")
            profileRow(title: "Privacy & Safety")
            profileRow(title: "Emergency Contacts")
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
    }

    private var sessionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Session")
            Button(role: .destructive) {
                flow.signOut()
            } label: {
                HStack {
                    Text("Sign Out")
                        .font(.system(size: 15, weight: .semibold))
                    Spacer()
                }
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.secondary)
    }

    private func profileRow(title: String) -> some View {
        NavigationLink {
            Text("TODO: \(title)")
                .font(.system(size: 16, weight: .semibold))
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(white: 0.97))
        } label: {
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
    }

    private func rolePill(_ label: String) -> some View {
        Text(label)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Color.indigo)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.indigo.opacity(0.12))
            .clipShape(Capsule())
    }
}

private enum ProfileSessionRole: String, CaseIterable {
    case driver = "driver"
    case observer = "observer"

    var title: String {
        switch self {
        case .driver:
            return "Driver"
        case .observer:
            return "Observer"
        }
    }
}

#Preview {
    NavigationStack {
        ProfileView()
            .environmentObject(AppFlowState())
    }
}
