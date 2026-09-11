import SwiftUI

struct MainMenuView: View {
    @EnvironmentObject var flow: AppFlowState
    @EnvironmentObject private var authSession: AuthSessionContext
    @EnvironmentObject private var backendProfileContext: BackendProfileContext
    @EnvironmentObject private var backendHouseholdContext: BackendHouseholdContext
    @EnvironmentObject private var backendHouseholdPeopleContext: BackendHouseholdPeopleContext
    @EnvironmentObject private var backendEmergencyContactsContext: BackendEmergencyContactsContext
    @EnvironmentObject private var backendChildrenContext: BackendChildrenContext
    @EnvironmentObject private var activeHouseholdStore: ActiveHouseholdStore
    @Binding var path: NavigationPath

    var body: some View {
        ZStack {
            TribePalette.canvas.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    familyHeroCard
                    quickActionsSection
                    driverModeToggleSection
                    familySafetySection
                    settingsSection
                    supportSection
#if DEBUG
                    systemSection
#endif
                    signOutSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 34)
            }
        }
        .navigationTitle("More")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(TribePalette.canvas, for: .navigationBar)
        .task {
            await backendProfileContext.refreshProfile()
            await backendEmergencyContactsContext.refreshForActiveHousehold()
#if DEBUG
            print(
                "[MainMenuView] auth.uid=\(authSession.currentUserId ?? "nil"), " +
                "display_name=\(backendProfileContext.currentUserProfile?.display_name ?? "nil"), " +
                "display_source=\(profileDisplaySource), memberships.count=\(backendHouseholdContext.memberships.count), " +
                "households.count=\(backendHouseholdContext.households.count), active_household_id=\(activeHouseholdStore.activeHouseholdId?.uuidString ?? "nil"), " +
                "household_name=\(activeHouseholdName)"
            )
#endif
        }
    }

    private var familyHeroCard: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                LinearGradient(
                    colors: [Color(tribeHex: "#7C5CE6"), Color(tribeHex: "#A98BF0")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Image(CalArt.family)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geo.size.width * 0.62, height: geo.size.height, alignment: .bottom)
                    .clipped()
                    .mask(
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0.0),
                                .init(color: .black, location: 0.22),
                                .init(color: .black, location: 1.0)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .allowsHitTesting(false)

                LinearGradient(
                    stops: [
                        .init(color: Color(tribeHex: "#7C5CE6").opacity(0.7), location: 0.0),
                        .init(color: Color(tribeHex: "#7C5CE6").opacity(0.08), location: 0.62)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .allowsHitTesting(false)

                VStack(alignment: .leading, spacing: 11) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(activeHouseholdDisplayName)
                            .font(.system(size: 25, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                        Text("Your family control centre")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.86))
                            .lineLimit(1)
                    }

                    HStack(spacing: 7) {
                        heroStatChip(icon: "person.2.fill", value: familySummary.totalMembers, label: familySummary.totalMembers == 1 ? "Member" : "Members")
                        heroStatChip(icon: "figure.child", value: familySummary.totalChildren, label: familySummary.totalChildren == 1 ? "Child" : "Children")
                        heroStatChip(icon: "car.fill", value: familySummary.totalDrivers, label: familySummary.totalDrivers == 1 ? "Driver" : "Drivers")
                    }
                    .lineLimit(1)
                    .fixedSize()

                    HStack(spacing: 7) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12, weight: .bold))
                        Text("Everyone connected")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(.white.opacity(0.96))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(.white.opacity(0.18), in: Capsule())
                    .lineLimit(1)
                }
                .padding(20)
                .frame(maxWidth: geo.size.width * 0.61, alignment: .leading)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .frame(height: 200)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Color(tribeHex: "#7C5CE6").opacity(0.26), radius: 18, x: 0, y: 10)
    }

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            controlSectionHeader("Quick Actions")
            LazyVGrid(columns: twoColumns, spacing: 10) {
                MoreQuickActionTile(title: "Profile", icon: "person.fill", badge: nil) {
                    path.append(Destination.profile)
                }
                MoreQuickActionTile(title: "Settings", icon: "gearshape.fill", badge: nil) {
                    path.append(Destination.settings)
                }
                MoreQuickActionTile(title: "Notifications", icon: "bell.fill", badge: notificationBadgeText) {
                    path.append(Destination.notificationsInbox)
                }
                MoreQuickActionTile(title: "Legal & Safety", icon: "lock.shield.fill", badge: nil) {
                    path.append(Destination.legalSafety)
                }
            }
        }
    }

    private var driverModeToggleSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            controlSectionHeader("Driver Mode Toggle")
            driverModeCard
        }
    }

    private var driverModeCard: some View {
        Button {
            path.append(Destination.driverModeSelector)
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    Circle().fill(TribePalette.primarySoft).frame(width: 34, height: 34)
                    Image(systemName: "car.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(TribePalette.primary)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("Driver Mode")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(TribePalette.ink)
                        .lineLimit(1)
                    Text("Use this phone")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(TribePalette.muted)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                MoreTogglePill(isOn: backendHouseholdContext.canStartRuns)
            }
            .controlCardStyle()
        }
        .buttonStyle(PressScaleButtonStyle())
    }

    private var familySafetySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Family Safety")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(TribePalette.ink)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(TribePalette.muted)
            }

            HStack(spacing: 0) {
                safetyMiniItem(title: "Location\nSharing", status: "Enabled", icon: "location.fill", action: { path.append(Destination.locationSharing) })
                divider
                safetyMiniItem(title: "Notifications", status: "Enabled", icon: "bell.fill", action: { path.append(Destination.notificationSettings) })
                divider
                safetyMiniItem(title: "Emergency\nContacts", status: emergencyContactsStatusText, icon: "cross.case.fill", action: { path.append(Destination.emergencyContacts) })
                divider
                safetyMiniItem(title: "Privacy &\nPermissions", status: "Up to date", icon: "lock.shield.fill", action: { path.append(Destination.permissionsConsent) })
            }
        }
        .illustratedPanel(cornerRadius: 20, padding: 14)
    }

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            controlSectionHeader("Settings")
            VStack(spacing: 0) {
                settingsMiniRow(title: "Privacy & Permissions", icon: "lock.shield.fill", action: { path.append(Destination.permissionsConsent) })
                horizontalDivider
                settingsMiniRow(title: "Calendar Sync", icon: "calendar.badge.clock", action: { path.append(Destination.calendarSync) })
            }
            .illustratedPanel(cornerRadius: 20, padding: 0)
        }
    }

    private var supportSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            controlSectionHeader("Support")
            HStack(spacing: 0) {
                supportMiniItem(title: "Help & Support", icon: "questionmark.circle.fill", action: { path.append(Destination.helpSupport) })
                divider
                supportMiniItem(title: "Feedback", icon: "bubble.left.and.bubble.right.fill", action: { path.append(Destination.quickContact) })
                divider
                supportMiniItem(title: "About", icon: "info.circle.fill", action: { path.append(Destination.about) })
            }
            .illustratedPanel(cornerRadius: 20, padding: 0)
        }
    }

#if DEBUG
    private var systemSection: some View {
        Button {
            path.append(Destination.systemTools)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "wrench.and.screwdriver.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(TribePalette.primary)
                    .frame(width: 34, height: 34)
                    .background(TribePalette.primarySoft, in: Circle())
                Text("System Tools")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(TribePalette.ink)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(TribePalette.muted)
            }
            .illustratedPanel(cornerRadius: 18, padding: 12)
        }
        .buttonStyle(PressScaleButtonStyle())
    }
#endif

    private var signOutSection: some View {
        Button(role: .destructive) {
            Task {
                await authSession.signOut()
                flow.signOut()
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color(tribeHex: "#E34B5E"))
                    .frame(width: 34, height: 34)
                Text("Sign out")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color(tribeHex: "#E34B5E"))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color(tribeHex: "#E34B5E").opacity(0.6))
            }
            .illustratedPanel(cornerRadius: 18, padding: 12)
        }
        .buttonStyle(PressScaleButtonStyle())
    }

    private var twoColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10)
        ]
    }

    private var activeHouseholdDisplayName: String {
        let name = activeHouseholdName.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty || name == "No active household" || name == "Loading household..." {
            return "La Familia"
        }
        return name
    }

    private var activeMemberships: [BackendHouseholdMembership] {
        backendHouseholdContext.activeMemberships
    }

    private var familySummary: FamilySummary {
        flow.tribeStore.familyStore.summary
    }

    private var notificationBadgeText: String? {
        nil
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.black.opacity(0.06))
            .frame(width: 1)
            .padding(.vertical, 12)
    }

    private var horizontalDivider: some View {
        Rectangle()
            .fill(Color.black.opacity(0.06))
            .frame(height: 1)
            .padding(.leading, 46)
    }

    private func controlSectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(TribePalette.ink)
            .padding(.leading, 4)
    }

    private func heroStatChip(icon: String, value: Int, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                Text("\(value)")
                    .font(.system(size: 13, weight: .bold))
            }
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .lineLimit(1)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .fixedSize()
    }

    private func safetyMiniItem(title: String, status: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(TribePalette.primary)
                    .frame(width: 30, height: 30)
                    .background(TribePalette.primarySoft, in: Circle())
                Text(title)
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(TribePalette.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                Text(status)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(TribePalette.green)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        }
        .buttonStyle(PressScaleButtonStyle())
    }

    private func settingsMiniRow(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(TribePalette.primary)
                    .frame(width: 26, height: 26)
                    .background(TribePalette.primarySoft.opacity(0.85), in: Circle())
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(TribePalette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(TribePalette.muted.opacity(0.8))
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 12)
        }
        .buttonStyle(PressScaleButtonStyle())
    }

    private func supportMiniItem(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(TribePalette.primary)
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(TribePalette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Image(systemName: "chevron.right")
                    .font(.system(size: 8.5, weight: .bold))
                    .foregroundStyle(TribePalette.muted.opacity(0.75))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .padding(.horizontal, 8)
        }
        .buttonStyle(PressScaleButtonStyle())
    }

    private func adultAvatar(forName name: String, role: String) -> String {
        let lower = "\(name) \(role)".lowercased()
        if lower.contains("grand") { return TribeArt.grandparent }
        if lower.contains("driver") { return TribeArt.father }
        return abs(name.hashValue).isMultiple(of: 2) ? TribeArt.mother : TribeArt.father
    }

    private func childAvatar(forName name: String) -> String {
        let pool = TribeArt.childAvatars
        return pool[abs(name.hashValue) % pool.count]
    }

    private func shortName(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.split(separator: " ").first else { return trimmed.isEmpty ? "Member" : trimmed }
        return String(first)
    }

    private var profileDisplayName: String {
        if let display = backendProfileContext.currentUserProfile?.display_name?.trimmingCharacters(in: .whitespacesAndNewlines),
           !display.isEmpty {
            return display
        }
        let first = backendProfileContext.currentUserProfile?.first_name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let last = backendProfileContext.currentUserProfile?.last_name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let composed = [first, last].filter { !$0.isEmpty }.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        if !composed.isEmpty {
            return composed
        }
        if let email = backendProfileContext.currentUserProfile?.email?.trimmingCharacters(in: .whitespacesAndNewlines), !email.isEmpty {
            return emailAlias(from: email)
        }
        if let authEmail = authSession.currentUserEmail?.trimmingCharacters(in: .whitespacesAndNewlines), !authEmail.isEmpty {
            return emailAlias(from: authEmail)
        }
        return "User"
    }

    private var profileDisplaySource: String {
        backendProfileContext.currentUserProfile?.resolvedDisplayName(
            providerDisplayName: authSession.currentUserProviderDisplayName,
            fallbackEmail: authSession.currentUserEmail
        ).source ?? "default"
    }

    private var emergencyContactsStatusText: String {
        if backendEmergencyContactsContext.isLoading && backendEmergencyContactsContext.contactCount == 0 {
            return "Loading…"
        }
        let count = backendEmergencyContactsContext.contactCount
        switch count {
        case 0:
            return "No contacts"
        case 1:
            return "1 contact"
        default:
            return "\(count) contacts"
        }
    }

    private var activeHouseholdName: String {
        guard let activeHouseholdId = activeHouseholdStore.activeHouseholdId else {
            return backendHouseholdContext.memberships.isEmpty ? "No active household" : "Loading household..."
        }
        if let name = backendHouseholdContext.households.first(where: { $0.id == activeHouseholdId })?.name,
           !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return name
        }
        return backendHouseholdContext.memberships.isEmpty ? "No active household" : "Loading household..."
    }

    private var profileRoleLabel: String {
        if let role = backendHouseholdContext.roleForActiveHousehold()?.capitalized, !role.isEmpty {
            return role
        }
        return "User"
    }

    private func emailAlias(from email: String) -> String {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "User" }
        guard let firstPart = trimmed.split(separator: "@").first.map(String.init) else { return "User" }
        let alias = firstPart.trimmingCharacters(in: .whitespacesAndNewlines)
        return alias.isEmpty ? "User" : alias
    }
}

private struct MoreFamilyPreviewItem: Identifiable {
    let id = UUID()
    var name: String
    var label: String
    var avatar: String
    var statusColor: Color
}

private struct MoreQuickActionTile: View {
    let title: String
    let icon: String
    let badge: String?
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 9) {
                    Image(systemName: icon)
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(TribePalette.primary)
                        .frame(width: 42, height: 42)
                        .background(TribePalette.primarySoft, in: Circle())
                    Text(title)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(TribePalette.ink)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.76)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 88)
                .background(TribePalette.surface)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.black.opacity(0.04), lineWidth: 1)
                }
                .shadow(color: Color.black.opacity(0.045), radius: 10, x: 0, y: 5)

                if let badge {
                    Text(badge)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 18, height: 18)
                        .background(Color(tribeHex: "#F0445E"), in: Circle())
                        .offset(x: 5, y: -6)
                }
            }
        }
        .buttonStyle(PressScaleButtonStyle())
    }
}

private struct MoreFamilyAvatarItem: View {
    let item: MoreFamilyPreviewItem

    var body: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .bottomTrailing) {
                avatarCircle(item.avatar, size: 48)
                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
                Circle()
                    .fill(item.statusColor)
                    .frame(width: 11, height: 11)
                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
            }
            Text(item.name)
                .font(.system(size: 10.5, weight: .bold))
                .foregroundStyle(TribePalette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(item.label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(TribePalette.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct MoreTogglePill: View {
    let isOn: Bool

    var body: some View {
        Capsule()
            .fill(isOn ? TribePalette.green.opacity(0.24) : Color.black.opacity(0.08))
            .frame(width: 36, height: 21)
            .overlay(alignment: isOn ? .trailing : .leading) {
                Circle()
                    .fill(isOn ? TribePalette.green : Color.white)
                    .frame(width: 17, height: 17)
                    .shadow(color: Color.black.opacity(0.12), radius: 2, x: 0, y: 1)
                    .padding(2)
            }
    }
}

private extension View {
    func controlCardStyle() -> some View {
        self
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
            .background(TribePalette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.black.opacity(0.04), lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.045), radius: 10, x: 0, y: 5)
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

#Preview {
    NavigationStack {
        MainMenuView(path: .constant(NavigationPath()))
            .environmentObject(AppFlowState())
            .environmentObject(AuthSessionContext())
            .environmentObject(BackendProfileContext())
    }
}
