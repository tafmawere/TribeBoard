import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var authSession: AuthSessionContext
    @EnvironmentObject private var backendProfileContext: BackendProfileContext
    @EnvironmentObject private var backendHouseholdContext: BackendHouseholdContext
    @EnvironmentObject private var backendChildrenContext: BackendChildrenContext
    @EnvironmentObject private var runDataSource: RunDataSource

    @StateObject private var familyStore = TribeStore()
    @State private var locationSharingEnabled = true
    @State private var isPresentingInvite = false

    private var canManageTribeSettings: Bool {
        backendHouseholdContext.canManageTribeSettings
    }

    private var rolePermissionsHint: String? {
        guard backendHouseholdContext.hasActiveMembership else { return nil }
        if backendHouseholdContext.isCurrentUserDriver {
            return "Drivers can start runs but cannot change tribe settings."
        }
        if backendHouseholdContext.isCurrentUserObserver {
            return "Observers have view-only access."
        }
        return nil
    }

    private var displayName: String {
        backendProfileContext.currentUserProfile?.resolvedDisplayName(
            providerDisplayName: authSession.currentUserProviderDisplayName,
            fallbackEmail: authSession.currentUserEmail
        ).value ?? "User"
    }

    private var profileAvatarIdentity: TribeAvatarIdentity {
        if let profile = backendProfileContext.currentUserProfile {
            return profile.avatarIdentity(fallbackDisplayName: displayName)
        }
        return TribeAvatarIdentity(displayName: displayName)
    }

    private var roleLabel: String {
        if let role = backendHouseholdContext.roleForActiveHousehold()?.capitalized, !role.isEmpty {
            return role
        }
        return backendHouseholdContext.hasActiveMembership ? "Organiser" : "Member"
    }

    private var householdName: String {
        backendHouseholdContext.activeHouseholdName ?? "Your Household"
    }

    private var activeMembers: [BackendHouseholdMembership] {
        backendHouseholdContext.activeHouseholdMembers.filter(\.isActive)
    }

    private var memberCount: Int { activeMembers.count }
    private var childCount: Int { backendChildrenContext.children.count }
    private var driverCount: Int {
        activeMembers.filter { $0.normalizedAccessRole == .driver }.count
    }

    private var heroConnection: SettingsHouseholdIntelligence.HeroConnection {
        SettingsHouseholdIntelligence.heroConnection(activeMemberCount: memberCount)
    }

    private var familyStatus: SettingsHouseholdIntelligence.FamilyStatus {
        let activeRuns = runDataSource.activeRuns()
        let attention = runDataSource.attentionSummary(for: Date())
        let alertCount = attention.critical + attention.warning
        let upcomingTitle = SettingsHouseholdIntelligence.upcomingRunTitle(from: runDataSource)
        return SettingsHouseholdIntelligence.familyStatus(
            activeRuns: activeRuns,
            alertCount: alertCount,
            upcomingRunTitle: upcomingTitle
        )
    }

    private var appVersionText: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "v\(version) (\(build))"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: SettingsHubTheme.sectionSpacing) {
                SettingsHeroCard(
                    identity: profileAvatarIdentity,
                    displayName: displayName,
                    roleLabel: roleLabel,
                    householdName: householdName,
                    memberCount: memberCount,
                    childCount: childCount,
                    driverCount: driverCount,
                    connection: heroConnection,
                    accessToken: authSession.currentAccessToken
                )

                FamilyStatusCard(status: familyStatus)

                SettingsQuickActionsRow(
                    householdName: householdName,
                    onInvite: { isPresentingInvite = true }
                )

                if let rolePermissionsHint {
                    Text(rolePermissionsHint)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(SettingsHubTheme.subtitleSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                }

                householdSection
                runsSection
                safetySection
                legalSupportSection
                appSection
#if DEBUG
                developerSection
#endif
                dangerSection

                LegalSafetyReassuranceCard()
            }
            .padding(.horizontal, SettingsHubTheme.horizontalPadding)
            .padding(.top, 8)
            .padding(.bottom, SettingsHubTheme.tabBarClearance)
        }
        .background(SettingsHubTheme.screenBackground.ignoresSafeArea())
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isPresentingInvite) {
            NavigationStack {
                FamilyAddMemberInviteFlowView()
            }
        }
    }

    // MARK: - Sections

    private var householdSection: some View {
        SettingsHubSectionCard(title: "Household", accent: .household) {
            NavigationLink {
                FamilyMemberManagementPhase3View(store: familyStore)
            } label: {
                SettingsHubRow(
                    icon: "person.3.fill",
                    title: "Family Members & Roles",
                    subtitle: "Manage members and roles",
                    accent: .household
                )
            }
            .buttonStyle(.plain)

            SettingsHubRowButton(
                icon: "person.badge.plus",
                title: "Invite Family Member",
                subtitle: "Add a new member",
                accent: .household
            ) {
                isPresentingInvite = true
            }

            NavigationLink {
                HouseholdSwitcherView()
            } label: {
                SettingsHubRow(
                    icon: "arrow.triangle.2.circlepath",
                    title: "Switch Household",
                    subtitle: "View or join another household",
                    accent: .household,
                    showsDivider: false
                )
            }
            .buttonStyle(.plain)
        }
        .disabled(!canManageTribeSettings)
        .opacity(canManageTribeSettings ? 1 : 0.55)
    }

    private var runsSection: some View {
        SettingsHubSectionCard(title: "Runs & Activities", accent: .runs) {
            SettingsHubRow(
                icon: "steeringwheel",
                title: "Default Driver",
                subtitle: "Configured in runs and setup",
                accent: .runs
            )
            SettingsHubRow(
                icon: "person.2.fill",
                title: "Default Passengers",
                subtitle: "Configured per child and run",
                accent: .runs
            )
            NavigationLink {
                SchedulesListView()
            } label: {
                SettingsHubRow(
                    icon: "calendar",
                    title: "Schedule Preferences",
                    subtitle: "Manage from Calendar",
                    accent: .runs
                )
            }
            .buttonStyle(.plain)

            SettingsHubRow(
                icon: "figure.play",
                title: "Activity Preferences",
                subtitle: "Manage activity settings",
                accent: .runs,
                showsDivider: false
            )
        }
        .disabled(!canManageTribeSettings)
        .opacity(canManageTribeSettings ? 1 : 0.55)
    }

    private var safetySection: some View {
        SettingsHubSectionCard(title: "Safety", accent: .safety) {
            SettingsHubRow(
                icon: "location.fill",
                title: "Location Sharing",
                subtitle: "Share real-time location",
                accent: .safety,
                toggle: $locationSharingEnabled
            )
            NavigationLink {
                LocationSharingSettingsView()
            } label: {
                SettingsHubRow(
                    icon: "eye.fill",
                    title: "Who Can Track Me",
                    subtitle: "Manage who can see location",
                    accent: .safety,
                    trailingValue: "Parents"
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                EmergencyContactsView()
            } label: {
                SettingsHubRow(
                    icon: "cross.case.fill",
                    title: "Emergency Contacts",
                    subtitle: "Manage emergency contacts",
                    accent: .safety
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                DriverModeSelectorView()
            } label: {
                SettingsHubRow(
                    icon: "car.fill",
                    title: "Driver Mode",
                    subtitle: "Enable safe driving mode",
                    accent: .safety,
                    trailingValue: "On",
                    showsDivider: false
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var legalSupportSection: some View {
        SettingsHubSectionCard(title: "Legal & Support", accent: .legalSupport) {
            NavigationLink {
                LegalSafetyView()
            } label: {
                SettingsHubRow(
                    icon: "lock.shield.fill",
                    title: "Legal & Safety",
                    subtitle: "Privacy, child safety and account controls",
                    accent: .legal
                )
            }
            .buttonStyle(.plain)

            SettingsHubRowButton(
                icon: "envelope.fill",
                title: "Contact Support",
                subtitle: "Get help from our team",
                accent: .support,
                showsDivider: false
            ) {
                if let url = ExternalLinks.supportEmailURL() {
                    UIApplication.shared.open(url)
                }
            }
        }
    }

    private var appSection: some View {
        SettingsHubSectionCard(title: "App", accent: .app) {
            SettingsHubRow(
                icon: "circle.lefthalf.filled",
                title: "Appearance",
                subtitle: "Choose light, dark or system",
                accent: .app,
                trailingValue: "System"
            )
            NavigationLink {
                NotificationSettingsView()
            } label: {
                SettingsHubRow(
                    icon: "bell.badge.fill",
                    title: "Notifications",
                    subtitle: "Manage notification settings",
                    accent: .app
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                NavigationAppsSettingsView()
            } label: {
                SettingsHubRow(
                    icon: "map.fill",
                    title: "Navigation Apps",
                    subtitle: "Google Maps & Waze settings",
                    accent: .app
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                AboutView()
            } label: {
                SettingsHubRow(
                    icon: "info.circle.fill",
                    title: "About",
                    subtitle: "Version, terms and more",
                    accent: .app,
                    trailingValue: appVersionText,
                    showsDivider: false
                )
            }
            .buttonStyle(.plain)
        }
        .disabled(!canManageTribeSettings)
        .opacity(canManageTribeSettings ? 1 : 0.55)
    }

#if DEBUG
    private var developerSection: some View {
        SettingsHubSectionCard(title: "Developer", accent: .app) {
            NavigationLink {
                DeveloperSettingsView()
            } label: {
                SettingsHubRow(
                    icon: "location.fill.viewfinder",
                    title: "Debug Location",
                    subtitle: "Simulate GPS presets for testing",
                    accent: .app,
                    showsDivider: false
                )
            }
            .buttonStyle(.plain)
        }
    }
#endif

    private var dangerSection: some View {
        SettingsHubSectionCard(
            title: "Danger Zone",
            accent: .danger,
            cardBackground: Color(tribeHex: "#FDF2F4")
        ) {
            SettingsHubRowButton(
                icon: "arrow.counterclockwise.circle.fill",
                title: "Reset Data",
                subtitle: "Clear local data and cache",
                accent: .warning
            ) {
                print("Reset Data tapped")
            }

            NavigationLink {
                DeleteAccountView()
            } label: {
                SettingsHubRow(
                    icon: "trash.fill",
                    title: "Delete Account",
                    subtitle: "Permanently delete your account and data",
                    accent: .danger,
                    showsDivider: false
                )
            }
            .buttonStyle(.plain)
        }
        .disabled(!canManageTribeSettings)
        .opacity(canManageTribeSettings ? 1 : 0.55)
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
