import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var flow: AppFlowState
    @EnvironmentObject private var authSession: AuthSessionContext
    @EnvironmentObject private var backendProfileContext: BackendProfileContext
    @EnvironmentObject private var backendHouseholdContext: BackendHouseholdContext
    @EnvironmentObject private var backendChildrenContext: BackendChildrenContext

    @StateObject private var familyStore = TribeStore()
    @State private var showAvatarPicker = false

    private var displayName: String {
        backendProfileContext.currentUserProfile?.resolvedDisplayName(
            providerDisplayName: authSession.currentUserProviderDisplayName,
            fallbackEmail: authSession.currentUserEmail
        ).value ?? "User"
    }

    private var resolvedEmail: String {
        if let email = backendProfileContext.currentUserProfile?.email?
            .trimmingCharacters(in: .whitespacesAndNewlines), !email.isEmpty {
            return email
        }
        if let email = authSession.currentUserEmail?
            .trimmingCharacters(in: .whitespacesAndNewlines), !email.isEmpty {
            return email
        }
        return "Not added"
    }

    private var phoneSubtitle: String {
        "Not added"
    }

    private var profileAvatarIdentity: TribeAvatarIdentity {
        if let profile = backendProfileContext.currentUserProfile {
            return profile.avatarIdentity(fallbackDisplayName: displayName)
        }
        return TribeAvatarIdentity(
            avatarType: .preset,
            avatarKey: AvatarPresetCatalog.defaultAdultKey,
            displayName: displayName
        )
    }

    private var roleBadge: String {
        if let role = backendHouseholdContext.roleForActiveHousehold()?.capitalized, !role.isEmpty {
            return role
        }
        return backendHouseholdContext.hasActiveMembership ? "Member" : "Guest"
    }

    private var householdName: String {
        backendHouseholdContext.activeHouseholdName ?? "Your Household"
    }

    private var currentMembership: BackendHouseholdMembership? {
        backendHouseholdContext.currentActiveMembership
    }

    private var isActiveMember: Bool {
        guard let membership = currentMembership else { return false }
        return membership.isActiveMembership
    }

    private var joinedDateText: String? {
        if let membershipDate = ProfileIdentityRoles.joinedMonthYear(from: currentMembership?.createdAt) {
            return membershipDate
        }
        return ProfileIdentityRoles.joinedMonthYear(from: backendProfileContext.currentUserProfile?.created_at)
    }

    private var visibleRoles: [ProfileRoleKind] {
        ProfileIdentityRoles.visibleRoles(
            membership: currentMembership,
            isOrganiser: backendHouseholdContext.isCurrentUserOrganiser,
            isDriver: backendHouseholdContext.isCurrentUserDriver
        )
    }

    private var activeMembers: [BackendHouseholdMembership] {
        backendHouseholdContext.activeHouseholdMembers.filter(\.isActive)
    }

    private var memberCount: Int { activeMembers.count }
    private var childCount: Int { backendChildrenContext.children.count }
    private var driverCount: Int {
        activeMembers.filter { $0.normalizedAccessRole == .driver }.count
    }

    var body: some View {
        ScrollView {
            VStack(spacing: ProfileHubTheme.sectionSpacing) {
                ProfileHeroCard(
                    identity: profileAvatarIdentity,
                    displayName: displayName,
                    roleBadge: roleBadge,
                    householdName: householdName,
                    isActiveMember: isActiveMember,
                    joinedDateText: joinedDateText,
                    roles: visibleRoles,
                    accessToken: authSession.currentAccessToken,
                    onAvatarEdit: { showAvatarPicker = true }
                )

                NavigationLink {
                    FamilyMemberManagementPhase3View(store: familyStore)
                } label: {
                    ProfileHouseholdCard(
                        householdName: householdName,
                        memberCount: memberCount,
                        childCount: childCount,
                        driverCount: driverCount
                    )
                }
                .buttonStyle(.plain)

                manageProfileSection
                accountSecuritySection
                dangerZoneSection
            }
            .padding(.horizontal, ProfileHubTheme.horizontalPadding)
            .padding(.top, 8)
            .padding(.bottom, ProfileHubTheme.tabBarClearance)
        }
        .background(ProfileHubTheme.screenBackground.ignoresSafeArea())
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAvatarPicker) {
            if let profileId = backendProfileContext.currentUserProfile?.id,
               let token = authSession.currentAccessToken {
                NavigationStack {
                    AvatarPickerView(
                        subjectKind: .profile(profileId),
                        displayName: displayName,
                        memberType: .adult,
                        isDriver: backendHouseholdContext.isCurrentUserDriver,
                        canUploadPhoto: true,
                        initialIdentity: profileAvatarIdentity,
                        accessToken: token
                    )
                }
            }
        }
        .task {
            await backendProfileContext.refreshProfile(
                authEmail: authSession.currentUserEmail,
                providerDisplayName: authSession.currentUserProviderDisplayName
            )
        }
    }

    // MARK: - Sections

    private var manageProfileSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            ProfileSectionHeader(title: "Manage My Profile")

            HStack(spacing: 10) {
                NavigationLink {
                    EditProfileView()
                } label: {
                    ProfileManageActionTileContent(
                        icon: "person.crop.circle.badge.plus",
                        title: "Edit Profile",
                        subtitle: "Update your details"
                    )
                }
                .buttonStyle(.plain)

                ProfileManageActionTile(
                    icon: "camera.fill",
                    title: "Change Avatar",
                    subtitle: "Update your photo",
                    action: { showAvatarPicker = true }
                )

                ProfileManageActionTile(
                    icon: "shield.lefthalf.filled",
                    title: "Manage Roles",
                    subtitle: "View and manage",
                    isDisabled: true,
                    action: {}
                )
            }
        }
    }

    private var accountSecuritySection: some View {
        ProfileSectionCard(title: "Account & Security", accent: .account) {
            ProfileRow(
                icon: "envelope.fill",
                title: "Email Address",
                subtitle: resolvedEmail,
                accent: .account,
                showsDivider: true,
                isDisabled: true
            )

            ProfileRow(
                icon: "phone.fill",
                title: "Phone Number",
                subtitle: phoneSubtitle,
                accent: .account,
                showsDivider: true,
                isDisabled: true
            )

            NavigationLink {
                PermissionsConsentView()
            } label: {
                ProfileRow(
                    icon: "hand.raised.fill",
                    title: "Privacy & Permissions",
                    subtitle: "Manage who can see your data",
                    accent: .account
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                LegalSafetyView()
            } label: {
                ProfileRow(
                    icon: "lock.shield.fill",
                    title: "Legal & Safety",
                    subtitle: "Policies and account controls",
                    accent: .account,
                    showsDivider: false
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var dangerZoneSection: some View {
        ProfileDangerZoneCard {
            ProfileRowButton(
                icon: "rectangle.portrait.and.arrow.right.fill",
                title: "Sign Out",
                subtitle: "Sign out of your account",
                accent: .danger
            ) {
                Task {
                    await authSession.signOut()
                    flow.signOut()
                }
            }

            NavigationLink {
                DeleteAccountView()
            } label: {
                ProfileRow(
                    icon: "trash.fill",
                    title: "Delete Account",
                    subtitle: "Permanently delete your account and data",
                    accent: .danger,
                    showsDivider: false
                )
            }
            .buttonStyle(.plain)
        }
    }
}

#Preview {
    NavigationStack {
        ProfileView()
            .environmentObject(AppFlowState())
            .environmentObject(AuthSessionContext())
            .environmentObject(BackendProfileContext())
    }
}
