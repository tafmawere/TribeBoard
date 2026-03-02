import SwiftUI

struct LegacyMenuMainMenuView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                sectionCard("Account") {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        menuRow("Settings", icon: "gearshape.fill")
                    }

                    NavigationLink {
                        ProfileRolesEntryView()
                    } label: {
                        menuRow("Profile & Roles", icon: "person.crop.circle.fill")
                    }
                }

                sectionCard("Safety & Privacy") {
                    NavigationLink {
                        LocationSharingSettingsView()
                    } label: {
                        menuRow("Location Sharing Settings", icon: "location.fill")
                    }

                    NavigationLink {
                        PermissionsConsentView()
                    } label: {
                        menuRow("Permissions / Consent", icon: "checkmark.shield.fill")
                    }

                    NavigationLink {
                        EmergencyContactsView()
                    } label: {
                        menuRow("Emergency / Quick Contacts", icon: "phone.circle.fill")
                    }
                }
            }
            .padding(16)
        }
        .background(GeneralUXTheme.background.ignoresSafeArea())
        .navigationTitle("More")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func sectionCard<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(GeneralUXTheme.textSecondary)

            VStack(spacing: 8) {
                content()
            }
            .padding(16)
            .background(GeneralUXTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(GeneralUXTheme.border)
            )
            .shadow(color: GeneralUXTheme.shadow, radius: 8, x: 0, y: 5)
        }
    }

    private func menuRow(_ title: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(GeneralUXTheme.primary)
                .frame(width: 30, height: 30)
                .background(GeneralUXTheme.primary.opacity(0.12))
                .clipShape(Circle())

            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(GeneralUXTheme.textPrimary)

            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(GeneralUXTheme.textSecondary)
        }
        .padding(.vertical, 6)
    }
}

#Preview {
    NavigationStack {
        LegacyMenuMainMenuView()
    }
}
