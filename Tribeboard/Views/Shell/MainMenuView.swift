import SwiftUI

struct MainMenuView: View {
    @EnvironmentObject var flow: AppFlowState
    @Binding var path: NavigationPath

    var body: some View {
        List {
            Section {
                accountHeader
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                    .listRowBackground(Color.clear)
            }

            Section {
                sectionHeader("Account")
                menuRow(title: "Profile", icon: "person.crop.circle") {
                    path.append(Destination.settings)
                }
                menuRow(title: "Manage Tribe", icon: "person.3.fill") {
                    path.append(Destination.settings)
                }
                menuRow(title: "Switch Role", icon: "arrow.triangle.2.circlepath") {
                    path.append(Destination.permissionsConsent)
                }
            }

            Section {
                sectionHeader("Safety")
                menuRow(title: "Privacy & Permissions", icon: "lock.shield.fill") {
                    path.append(Destination.permissionsConsent)
                }
                menuRow(title: "Location Settings", icon: "location.fill") {
                    path.append(Destination.locationSharing)
                }
                menuRow(title: "Emergency Contacts", icon: "cross.case.fill") {
                    path.append(Destination.emergencyContacts)
                }
            }

            Section {
                sectionHeader("Preferences")
                menuRow(title: "Notifications", icon: "bell.fill") {
                    path.append(Destination.notificationsInbox)
                }
                menuRow(title: "App Settings", icon: "gearshape.fill") {
                    path.append(Destination.settings)
                }
                menuRow(title: "Calendar Sync", icon: "calendar.badge.clock") {
                    path.append(Destination.schedulesList)
                }
            }

            Section {
                sectionHeader("Support")
                menuRow(title: "Help & Support", icon: "questionmark.circle.fill") {
                    path.append(Destination.error(message: "Help & Support coming soon."))
                }
                menuRow(title: "Feedback", icon: "bubble.left.and.bubble.right.fill") {
                    path.append(Destination.quickContact)
                }
                menuRow(title: "About", icon: "info.circle.fill") {
                    path.append(Destination.settings)
                }
            }

            Section {
                Button("Sign out", role: .destructive) {
                    flow.signOut()
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("More")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var accountHeader: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.indigo.opacity(0.14))
                .frame(width: 54, height: 54)
                .overlay {
                    Text("RM")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.indigo)
                }

            VStack(alignment: .leading, spacing: 3) {
                Text("Rue Mawere")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.primary)
                Text("Admin")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text("Mawere Tribe")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
    }

    private func menuRow(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.indigo)
                    .frame(width: 24)
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .frame(minHeight: 30)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        MainMenuView(path: .constant(NavigationPath()))
            .environmentObject(AppFlowState())
    }
}
