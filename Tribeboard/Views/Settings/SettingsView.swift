import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var flow: AppFlowState
    @AppStorage("profile.displayName") private var displayName = "Tafadzwa Mawere"
    @AppStorage("profile.activeRole") private var activeRoleRawValue = "driver"
    @AppStorage("profile.isAdmin") private var isAdmin = true
    @AppStorage(AppSettings.notificationLeadMinutesKey) private var notificationLeadMinutes = 15
    @AppStorage(AppSettings.arrivalRadiusMetersKey) private var arrivalRadiusMeters = 100.0
    @AppStorage(AppSettings.allowGoogleMapsKey) private var allowGoogleMaps = true
    @AppStorage(AppSettings.allowWazeKey) private var allowWaze = true
    @State private var locationSharingEnabled = true

    private var currentRole: SettingsRole {
        SettingsRole(rawValue: activeRoleRawValue) ?? .driver
    }

    private var headerSubtitle: String {
        isAdmin ? "Family Organizer" : currentRole.title
    }

    private var profileInitials: String {
        displayName
            .split(separator: " ")
            .prefix(2)
            .compactMap(\.first)
            .map(String.init)
            .joined()
            .uppercased()
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                profileHeaderCard
                familySectionCard
                householdSectionCard
                runsCalendarSectionCard
                safetyPrivacySectionCard
                appSectionCard
                dangerZoneSectionCard
            }
            .padding(16)
        }
        .background(Color(red: 0.976, green: 0.980, blue: 0.984).ignoresSafeArea())
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var profileHeaderCard: some View {
        SettingsSectionCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    Circle()
                        .fill(Color(red: 0.388, green: 0.400, blue: 0.945).opacity(0.14))
                        .frame(width: 52, height: 52)
                        .overlay {
                            Text(profileInitials)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(Color(red: 0.388, green: 0.400, blue: 0.945))
                        }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(flow.isAuthenticated ? displayName : "Guest User")
                            .font(.system(size: 18, weight: .bold))
                        Text(headerSubtitle)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }

                HStack(spacing: 8) {
                    roleChip("Parent", style: .parent)
                    if isAdmin {
                        roleChip("Admin", style: .admin)
                    }
                    roleChip("Observer", style: .observer)
                    roleChip("Driver", style: .driver)
                }

                NavigationLink {
                    SettingsPlaceholderView(title: "Profile")
                } label: {
                    SettingsRow(icon: "person.circle", title: "View Profile", showsChevron: true)
                }
            }
        }
    }

    private var familySectionCard: some View {
        SettingsSectionCard {
            sectionHeader("Family")
            VStack(spacing: 8) {
                NavigationLink {
                    SettingsPlaceholderView(title: "Family Members & Roles")
                } label: {
                    SettingsRow(icon: "person.3.fill", title: "Family Members & Roles", showsChevron: true)
                }
            }
        }
    }

    private var householdSectionCard: some View {
        SettingsSectionCard {
            sectionHeader("Household")
            VStack(spacing: 8) {
                NavigationLink {
                    HouseholdSwitcherView()
                } label: {
                    SettingsRow(
                        icon: "arrow.triangle.2.circlepath",
                        title: "Switch Household",
                        subtitle: "Choose active family",
                        showsChevron: true
                    )
                }
            }
        }
    }

    private var runsCalendarSectionCard: some View {
        SettingsSectionCard {
            sectionHeader("Runs & Calendar")
            VStack(spacing: 8) {
                compactPeopleRow(icon: "steeringwheel", title: "Default Driver", names: ["Tafadzwa"])
                compactPeopleRow(icon: "person.2.fill", title: "Default Passengers", names: ["TJ", "Tawana"])
                NavigationLink {
                    SettingsPlaceholderView(title: "Schedule Preferences")
                } label: {
                    SettingsRow(icon: "calendar", title: "Schedule Preferences", showsChevron: true)
                }
            }
        }
    }

    private var safetyPrivacySectionCard: some View {
        SettingsSectionCard {
            sectionHeader("Safety & Privacy")
            VStack(spacing: 8) {
                SettingsRow(
                    icon: "location.fill",
                    title: "Location Sharing",
                    subtitle: "Share your real-time location during active runs.",
                    toggle: $locationSharingEnabled
                )
                SettingsRow(
                    icon: "eye",
                    title: "Who can track me",
                    trailingValue: "Parents",
                    showsChevron: true
                ) {
                    print("Who can track me tapped")
                }
                NavigationLink {
                    SettingsPlaceholderView(title: "Emergency Contacts")
                } label: {
                    SettingsRow(icon: "cross.case.fill", title: "Emergency Contacts", showsChevron: true)
                }
            }
        }
    }

    private var appSectionCard: some View {
        SettingsSectionCard {
            sectionHeader("App")
            VStack(spacing: 8) {
                SettingsRow(
                    icon: "circle.lefthalf.filled",
                    title: "Appearance",
                    trailingValue: "System"
                )
                SettingsRow(
                    icon: "info.circle",
                    title: "About",
                    trailingValue: appVersionText
                )

                HStack {
                    Label("Notification Lead (min)", systemImage: "bell.badge.fill")
                        .font(.system(size: 14, weight: .semibold))
                    Spacer()
                    Stepper("\(notificationLeadMinutes)", value: $notificationLeadMinutes, in: 1...60)
                        .labelsHidden()
                }

                HStack {
                    Label("Arrival Radius (m)", systemImage: "location.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                    Spacer()
                    Stepper(
                        "\(Int(arrivalRadiusMeters))",
                        value: $arrivalRadiusMeters,
                        in: 25...500,
                        step: 25
                    )
                    .labelsHidden()
                }

                Toggle(isOn: $allowGoogleMaps) {
                    Label("Allow Google Maps", systemImage: "map")
                        .font(.system(size: 14, weight: .semibold))
                }
                .tint(Color.indigo)

                Toggle(isOn: $allowWaze) {
                    Label("Allow Waze", systemImage: "car")
                        .font(.system(size: 14, weight: .semibold))
                }
                .tint(Color.indigo)
            }
        }
    }

    private var dangerZoneSectionCard: some View {
        SettingsSectionCard {
            sectionHeader("Danger Zone")
            VStack(spacing: 8) {
                SettingsRow(
                    icon: "arrow.counterclockwise.circle.fill",
                    title: "Reset Data",
                    foreground: .orange
                ) {
                    print("Reset Data tapped")
                }
                SettingsRow(
                    icon: "trash.fill",
                    title: "Delete Account",
                    foreground: .red
                ) {
                    print("Delete Account tapped")
                }
            }
        }
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 4)
    }

    private func roleChip(_ text: String, style: SettingsRolePillStyle) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(style.foreground)
            .frame(minWidth: 68, minHeight: 28)
            .padding(.horizontal, 8)
            .background(style.background)
            .clipShape(Capsule())
    }

    private func compactPeopleRow(icon: String, title: String, names: [String]) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 28, height: 28)
                .background(Color.gray.opacity(0.10))
                .clipShape(Circle())

            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary)

            Spacer(minLength: 8)

            HStack(spacing: 6) {
                ForEach(names, id: \.self) { name in
                    inlineAvatarChip(name: name)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func inlineAvatarChip(name: String) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(Color.indigo.opacity(0.15))
                .frame(width: 20, height: 20)
                .overlay {
                    Text(name.prefix(1).uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.indigo.opacity(0.82))
                }
            Text(name)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.gray.opacity(0.08))
        .clipShape(Capsule())
    }

    private var appVersionText: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "v\(version) (\(build))"
    }
}

private enum SettingsRole: String {
    case driver = "driver"
    case observer = "observer"

    var title: String {
        switch self {
        case .driver: return "Driver"
        case .observer: return "Observer"
        }
    }
}

private enum SettingsRolePillStyle {
    case parent
    case admin
    case observer
    case driver

    var foreground: Color {
        switch self {
        case .parent: return Color(red: 0.40, green: 0.38, blue: 0.64)
        case .admin: return Color(red: 0.68, green: 0.46, blue: 0.24)
        case .observer: return Color(red: 0.26, green: 0.50, blue: 0.42)
        case .driver: return Color(red: 0.30, green: 0.40, blue: 0.68)
        }
    }

    var background: Color {
        switch self {
        case .parent: return Color(red: 0.90, green: 0.88, blue: 0.96)
        case .admin: return Color(red: 0.96, green: 0.90, blue: 0.84)
        case .observer: return Color(red: 0.87, green: 0.94, blue: 0.90)
        case .driver: return Color(red: 0.87, green: 0.91, blue: 0.97)
        }
    }
}

private struct SettingsPlaceholderView: View {
    let title: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "hammer.fill")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(Color(red: 0.388, green: 0.400, blue: 0.945))
            Text(title)
                .font(.system(size: 20, weight: .bold))
            Text("This section is available in upcoming internal builds.")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.976, green: 0.980, blue: 0.984))
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
