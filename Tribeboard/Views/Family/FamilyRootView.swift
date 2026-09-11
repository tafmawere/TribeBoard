import SwiftUI
import UIKit

struct FamilyRootView: View {
    @StateObject private var store: TribeStore
    @EnvironmentObject private var authSession: AuthSessionContext
    @EnvironmentObject private var backendHouseholdContext: BackendHouseholdContext
    @State private var isShowingJoinTribeSheet = false
    @State private var isShowingCreateTribeSheet = false

    init(store: TribeStore) {
        _store = StateObject(wrappedValue: store)
    }

    @MainActor
    init() {
        _store = StateObject(wrappedValue: TribeStore())
    }

    var body: some View {
        Group {
            if shouldShowNoActiveTribeState {
                noActiveTribeEmptyState
            } else if shouldShowCreateFlow {
                FamilyCreateTribeView(store: store)
            } else {
                FamilyMemberManagementPhase3View(store: store)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 1) {
                    Text(backendHouseholdContext.activeHouseholdName ?? "Tribe")
                        .font(.system(size: 17, weight: .semibold))
                    if backendHouseholdContext.hasActiveMembership {
                        Text("Family")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if hasActiveTribeAccess && !backendHouseholdContext.canManageMembers {
                Text("Only organisers can manage members.")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
            }
        }
        .sheet(isPresented: $isShowingJoinTribeSheet) {
            NavigationStack {
                JoinFamilyByCodeView()
                    .environmentObject(backendHouseholdContext)
            }
        }
        .sheet(isPresented: $isShowingCreateTribeSheet) {
            NavigationStack {
                FamilyCreateTribeView(store: store)
            }
        }
    }

    private var hasActiveTribeAccess: Bool {
        if authSession.isAuthenticated {
            return backendHouseholdContext.hasActiveMembership
        }
        return store.tribe != nil
    }

    private var shouldShowNoActiveTribeState: Bool {
        authSession.isAuthenticated && !backendHouseholdContext.hasActiveMembership
    }

    private var shouldShowCreateFlow: Bool {
        !authSession.isAuthenticated && store.tribe == nil
    }

    private var noActiveTribeEmptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.3.sequence.fill")
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(Color.indigo)
            Text("No active tribe")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.primary)
            Text("You are not currently part of a tribe. Ask an organiser for a new invite or set up your own tribe.")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
            VStack(spacing: 10) {
                Button {
                    isShowingJoinTribeSheet = true
                } label: {
                    Text("Join a tribe")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.indigo)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
                Button {
                    isShowingCreateTribeSheet = true
                } label: {
                    Text("Set up a tribe")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.indigo)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.indigo.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 4)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemGroupedBackground))
    }

}

private enum FamilyDestination: Identifiable {
    case addChild
    case locations

    var id: String {
        switch self {
        case .addChild: return "addChild"
        case .locations: return "locations"
        }
    }
}

private enum FamilySeed {
    static let members: [TribeMember] = [
        TribeMember(
            id: UUID(uuidString: "A1111111-1111-1111-1111-111111111111") ?? UUID(),
            fullName: "Rue Mawere",
            memberType: .adult,
            relationship: "Parent",
            phone: "+263 77 100 0001",
            roles: [.parent, .admin, .observer],
            isLocationSharingEnabled: true,
            isOnline: true
        ),
        TribeMember(
            id: UUID(uuidString: "B2222222-2222-2222-2222-222222222222") ?? UUID(),
            fullName: "Tafadzwa Mawere",
            memberType: .adult,
            relationship: "Parent",
            phone: "+263 77 100 0002",
            roles: [.parent, .admin, .driver],
            isLocationSharingEnabled: true,
            isOnline: true
        ),
        TribeMember(
            id: UUID(uuidString: "C3333333-3333-3333-3333-333333333333") ?? UUID(),
            fullName: "TJ",
            memberType: .child,
            dateOfBirth: Calendar.current.date(byAdding: .year, value: -10, to: Date()),
            displayName: "TJ",
            schoolName: "Lincoln Elementary",
            roles: [.child, .passenger],
            isLocationSharingEnabled: true,
            isOnline: false
        ),
        TribeMember(
            id: UUID(uuidString: "D4444444-4444-4444-4444-444444444444") ?? UUID(),
            fullName: "Tawana",
            memberType: .child,
            dateOfBirth: Calendar.current.date(byAdding: .year, value: -8, to: Date()),
            displayName: "Tawana",
            schoolName: "Lincoln Elementary",
            roles: [.child, .passenger],
            isLocationSharingEnabled: true,
            isOnline: false
        )
    ]
}

private struct FamilyCreateTribeView: View {
    @ObservedObject var store: TribeStore
    @EnvironmentObject private var backendHouseholdContext: BackendHouseholdContext
    @State private var tribeName = ""
    @State private var homeAddress = ""
    @StateObject private var homeSearchModel = LocationSearchModel()
    @State private var selectedHomeLatitude: Double?
    @State private var selectedHomeLongitude: Double?
    @State private var isCreating = false
    @State private var createErrorMessage: String?

    var body: some View {
        Form {
            Section("Create Tribe") {
                TextField("Tribe name", text: $tribeName)
                LocationSearchField(
                    title: "Home Address",
                    placeholder: "Search home address (optional)",
                    model: homeSearchModel,
                    onSelected: { result in
                        homeAddress = result.fullAddress
                        selectedHomeLatitude = result.latitude
                        selectedHomeLongitude = result.longitude
                    },
                    onCleared: {
                        homeAddress = ""
                        selectedHomeLatitude = nil
                        selectedHomeLongitude = nil
                    }
                )
            }

            Section {
                Button("Create Tribe") {
                    Task {
                        await createTribe()
                    }
                }
                .disabled(tribeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isCreating)
            }

            Section("Or") {
                NavigationLink("Join a Family") {
                    JoinFamilyByCodeView()
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .onAppear {
            if homeAddress.isEmpty { return }
            homeSearchModel.applySelectedAddress(homeAddress)
        }
        .alert("Unable to Create Family", isPresented: Binding(
            get: { createErrorMessage != nil },
            set: { newValue in
                if !newValue { createErrorMessage = nil }
            }
        )) {
            Button("OK", role: .cancel) {
                createErrorMessage = nil
            }
        } message: {
            Text(createErrorMessage ?? "Creation failed.")
        }
    }

    private func createTribe() async {
        isCreating = true
        defer { isCreating = false }
        await backendHouseholdContext.createHousehold(name: tribeName)
        guard backendHouseholdContext.householdAlertError == nil else {
            createErrorMessage = backendHouseholdContext.householdAlertError ?? "We couldn't create your family. Please try again."
            return
        }

        store.createTribe(name: tribeName, tribeCode: nil)
        let manualFallback = homeSearchModel.query.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAddress = (homeAddress.isEmpty ? manualFallback : homeAddress)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedAddress.isEmpty {
            let coordText: String?
            if let lat = selectedHomeLatitude, let lon = selectedHomeLongitude {
                coordText = "lat=\(lat),lon=\(lon)"
            } else {
                coordText = nil
            }
            let home = TribeLocation(
                name: "Home",
                address: trimmedAddress,
                type: .home,
                tribeId: store.tribe?.id,
                notes: coordText
            )
            store.addOrUpdateLocation(home, setAsHome: true)
        }
        createErrorMessage = nil
    }
}

private struct FamilyMembersListView: View {
    @ObservedObject var store: TribeStore
    @EnvironmentObject private var authSession: AuthSessionContext
    @EnvironmentObject private var backendProfileContext: BackendProfileContext
    @EnvironmentObject private var backendHouseholdContext: BackendHouseholdContext
    @EnvironmentObject private var activeHouseholdStore: ActiveHouseholdStore
    @EnvironmentObject private var backendHouseholdPeopleContext: BackendHouseholdPeopleContext
    @EnvironmentObject private var backendChildrenContext: BackendChildrenContext
    let onSelectMember: (TribeMember) -> Void
    @State private var didCopyInviteCode = false
    @State private var selectedHouseholdPerson: FamilySelectedPerson?
    @State private var selectedMembershipEditor: FamilySelectedMembership?
    @State private var membershipNotice: MembershipNotice?
    @State private var pendingApprovalActionMembershipId: UUID?
    @State private var pendingApprovalErrorMessage: String?

    private var allMemberships: [BackendHouseholdMembership] {
        backendHouseholdContext.activeHouseholdMembers
    }

    private var pendingMemberships: [BackendHouseholdMembership] {
        allMemberships.filter { $0.normalizedStatus == .pending }
    }

    private var activeMemberships: [BackendHouseholdMembership] {
        backendHouseholdContext.activeHouseholdMembers
            .filter { membership in
                membership.normalizedStatus == .active || membership.status == nil
            }
    }

    private var isCurrentUserPendingApproval: Bool {
        backendHouseholdContext.currentUserMembershipStatusForActiveHousehold() == .pending
    }

    private var currentUserMembershipForActiveHousehold: BackendHouseholdMembership? {
        guard let currentUserId = authSession.currentUserId?.lowercased() else { return nil }
        return allMemberships.first { $0.userId.uuidString.lowercased() == currentUserId }
    }

    private var canManageHouseholdMembers: Bool {
        currentUserMembershipForActiveHousehold?.normalizedAccessRole == .organiser
    }

    private var admins: [TribeMember] {
        store.members
            .filter { $0.roles.contains(.admin) }
            .sorted { $0.fullName < $1.fullName }
    }

    private var parents: [TribeMember] {
        store.members
            .filter { $0.memberType == .adult && !$0.roles.contains(.admin) }
            .sorted { $0.fullName < $1.fullName }
    }

    private var children: [TribeMember] {
        let storeChildrenByID = Dictionary(
            uniqueKeysWithValues: store.members.filter { $0.memberType == .child }.map { ($0.id, $0) }
        )
        return backendChildrenContext.children.map { backendChild in
            if var existing = storeChildrenByID[backendChild.id] {
                existing.avatarType = AvatarType(rawValue: backendChild.avatarType ?? AvatarType.preset.rawValue)
                existing.avatarKey = backendChild.avatarKey ?? existing.avatarKey
                existing.avatarURL = backendChild.avatarURL ?? existing.avatarURL
                return existing
            }
            return TribeMember(
                id: backendChild.id,
                fullName: backendChild.displayName?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? backendChild.legalName,
                avatarType: AvatarType(rawValue: backendChild.avatarType ?? AvatarType.preset.rawValue),
                avatarKey: backendChild.avatarKey ?? AvatarPresetCatalog.defaultChildKey,
                avatarURL: backendChild.avatarURL,
                memberType: .child,
                schoolName: backendChild.schoolName,
                gradeOrClass: backendChild.gradeOrClass,
                roles: [.child, .passenger],
                isLocationSharingEnabled: true,
                isOnline: false
            )
        }
            .sorted { $0.fullName < $1.fullName }
    }

    private var driverCount: Int {
        backendHouseholdPeopleContext.people.filter { $0.role.lowercased() == "driver" || $0.isDriver }.count
    }

    private var childrenCount: Int {
        backendChildrenContext.children.count
    }

    private var hasHomeSet: Bool {
        if let homeLocationId = store.tribe?.homeLocationId {
            return store.locations.contains(where: { $0.id == homeLocationId })
        }
        return store.locations.contains(where: { $0.type == .home })
    }

    private var childNamesMissingSchedules: [String] {
        children
            .filter { store.ruleCount(for: $0.id) == 0 }
            .map(\.preferredDisplayName)
            .sorted()
    }

    private var childNamesMissingSchool: [String] {
        children
            .filter { member in
                backendChildrenContext.children.first(where: { $0.id == member.id })?.schoolName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true
            }
            .map(\.preferredDisplayName)
            .sorted()
    }

    private var childNamesMissingSchoolRoutine: [String] {
        children
            .filter { $0.hasSchoolConfigured && !$0.hasSchoolRoutineConfigured }
            .map(\.preferredDisplayName)
            .sorted()
    }

    private var childNamesMissingDOB: [String] {
        children
            .filter { member in
                backendChildrenContext.children.first(where: { $0.id == member.id })?.dateOfBirth?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true
            }
            .map(\.preferredDisplayName)
            .sorted()
    }

    private var childNamesMissingActivities: [String] {
        let childIdsWithActivities = Set(backendChildrenContext.activities.map(\.childId))
        return children
            .filter { !childIdsWithActivities.contains($0.id) }
            .map(\.preferredDisplayName)
            .sorted()
    }

    private var configurationWarnings: [String] {
        var warnings: [String] = []
        if driverCount == 0 {
            warnings.append("No driver assigned yet")
        }
        if !childNamesMissingSchedules.isEmpty {
            warnings.append(contentsOf: childNamesMissingSchedules.prefix(3).map { "\($0): child is missing school schedule" })
        }
        if !childNamesMissingDOB.isEmpty {
            warnings.append(contentsOf: childNamesMissingDOB.prefix(3).map { "\($0): child date of birth required" })
        }
        if !childNamesMissingSchool.isEmpty {
            warnings.append(contentsOf: childNamesMissingSchool.prefix(3).map { "\($0): school location required" })
        }
        if !childNamesMissingSchoolRoutine.isEmpty {
            warnings.append(contentsOf: childNamesMissingSchoolRoutine.prefix(3).map { "\($0): school routine required" })
        }
        if !childNamesMissingActivities.isEmpty {
            warnings.append(contentsOf: childNamesMissingActivities.prefix(3).map { "\($0): activity details missing" })
        }
        let timingWarnings = children.flatMap { child in
            child.activitiesMissingTiming.map { "\(child.preferredDisplayName): \($0.name) has no time set" }
        }
        if !timingWarnings.isEmpty {
            warnings.append(contentsOf: timingWarnings.prefix(2))
        }
        let locationWarnings = children.flatMap { child in
            child.externalActivitiesMissingLocation.map { "\(child.preferredDisplayName): \($0.name) has no location set" }
        }
        if !locationWarnings.isEmpty {
            warnings.append(contentsOf: locationWarnings.prefix(2))
        }
        if !hasHomeSet {
            warnings.append("Household home location required")
        }
        return warnings
    }

    private var roleSummaryText: String {
        let memberCount = activeMemberships.count
        return "\(memberCount) Members • \(childrenCount) Child\(childrenCount == 1 ? "" : "ren")"
    }

    private var activeMembershipCards: [FamilyPersonCardItem] {
        sortedActiveMemberships.map { membership in
            let resolved = resolvedMembershipDisplay(for: membership)
            let profile = backendHouseholdContext.activeHouseholdProfilesByUserId[membership.userId]
            let avatarIdentity = profile?.avatarIdentity(fallbackDisplayName: resolved.name)
                ?? TribeAvatarIdentity(displayName: resolved.name)
            return FamilyPersonCardItem(
                id: "membership-\(membership.id.uuidString)",
                name: resolved.name,
                relationship: membershipRelationshipText(for: membership, isCurrentUser: resolved.isCurrentUser),
                roleChips: membershipRoleChips(for: membership),
                showsChevron: true,
                avatarIdentity: avatarIdentity,
                source: .membership(membershipId: membership.id, userId: membership.userId)
            )
        }
    }

    private var sortedActiveMemberships: [BackendHouseholdMembership] {
        activeMemberships.sorted { lhs, rhs in
            let lhsCurrent = isCurrentUserMembership(lhs)
            let rhsCurrent = isCurrentUserMembership(rhs)
            if lhsCurrent != rhsCurrent { return lhsCurrent && !rhsCurrent }

            let lhsAdmin = isAdminMembership(lhs)
            let rhsAdmin = isAdminMembership(rhs)
            if lhsAdmin != rhsAdmin { return lhsAdmin && !rhsAdmin }

            let lhsName = resolvedMembershipDisplay(for: lhs).name
            let rhsName = resolvedMembershipDisplay(for: rhs).name
            return lhsName.localizedCaseInsensitiveCompare(rhsName) == .orderedAscending
        }
    }

    var body: some View {
        List {
            if let tribe = store.tribe {
                Section {
                    tribeHeaderCard(tribe: tribe)
                }
            }

            if !isCurrentUserPendingApproval {
                Section {
                    configurationHealthCard
                }
            }

            if isCurrentUserPendingApproval {
                Section("Pending approval") {
                    waitingForApprovalCard
                }
            } else {
                if canManageHouseholdMembers, !pendingMemberships.isEmpty {
                    Section("Pending approvals") {
                        pendingApprovalsSection
                    }
                }

                Section("Family Members") {
                    if activeMembershipCards.isEmpty {
                        Text("No active members yet")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(activeMembershipCards) { card in
                            Button {
                                handleCardTap(card)
                            } label: {
                                FamilyPersonCardView(item: card)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            if !isCurrentUserPendingApproval, !children.isEmpty {
                Section("Children") {
                    ForEach(children) { member in
                        Button {
                            onSelectMember(member)
                        } label: {
                            childMemberRow(member)
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else if !isCurrentUserPendingApproval {
                Section("Children") {
                    ProductEducationCard(item: ProductEducationProvider.item(for: .childFirstSetup))
                }
            }
        }
        .task {
            await backendHouseholdPeopleContext.refreshForActiveHousehold()
            logFamilyDiagnostics()
        }
        .onChange(of: activeHouseholdStore.activeHouseholdId) { _, _ in
            logFamilyDiagnostics()
        }
        .onChange(of: activeMemberships.count) { _, _ in
            logFamilyDiagnostics()
        }
        .onChange(of: backendHouseholdPeopleContext.people.count) { _, _ in
            logFamilyDiagnostics()
        }
        .onChange(of: backendChildrenContext.children.count) { _, _ in
            logFamilyDiagnostics()
        }
        .sheet(item: $selectedHouseholdPerson, onDismiss: {
            Task {
                await backendHouseholdPeopleContext.refreshForActiveHousehold()
            }
        }) { selected in
            MemberProfileView(store: store, memberID: selected.id, startInEditMode: true)
        }
        .sheet(item: $selectedMembershipEditor) { selected in
            HouseholdMembershipAssignmentSheet(
                selectedMembership: selected,
                canManageHouseholdMembers: canManageHouseholdMembers
            ) { membershipId, permissionRole, membershipStatus, familyRole, relationshipLabel in
                try await backendHouseholdContext.updateMembershipAttributes(
                    membershipId: membershipId,
                    role: permissionRole,
                    status: membershipStatus,
                    familyRole: familyRole,
                    relationshipLabel: relationshipLabel
                )
#if DEBUG
                print(
                    "[FamilyMembersListView] post-save regroup counts pending=\(pendingMemberships.count), " +
                    "activeMembers=\(activeMembershipCards.count)"
                )
#endif
            }
        }
        .alert("Member details", isPresented: Binding(
            get: { membershipNotice != nil },
            set: { newValue in
                if !newValue { membershipNotice = nil }
            }
        )) {
            Button("OK", role: .cancel) {
                membershipNotice = nil
            }
        } message: {
            Text(
                membershipNotice?.message
                    ?? "This person manages their own account profile. You can still approve membership, assign family role, and set household permissions."
            )
        }
        .alert("Unable to update member", isPresented: Binding(
            get: { pendingApprovalErrorMessage != nil },
            set: { newValue in
                if !newValue { pendingApprovalErrorMessage = nil }
            }
        )) {
            Button("OK", role: .cancel) {
                pendingApprovalErrorMessage = nil
            }
        } message: {
            Text(pendingApprovalErrorMessage ?? "Unable to update member status.")
        }
    }

    private func tribeHeaderCard(tribe: Tribe) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.indigo.opacity(0.12), Color.white],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(alignment: .leading, spacing: 10) {
                Text(tribe.name)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.primary)

                Text(roleSummaryText)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)

                Text("Invite Code")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(tribe.tribeCode)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.indigo)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color.indigo.opacity(0.10))
                    .clipShape(Capsule())

                HStack(spacing: 8) {
                    ShareLink(item: tribe.tribeCode) {
                        Label("Share Tribe", systemImage: "square.and.arrow.up")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .background(Color.indigo)
                            .clipShape(Capsule())
                    }

                    Button("Copy Code") {
                        copyInviteCode(tribe.tribeCode)
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.indigo)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(Color.indigo.opacity(0.10))
                    .clipShape(Capsule())
                    .buttonStyle(.plain)

                    Spacer()
                }

                if didCopyInviteCode {
                    Text("Invite code copied")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.green.opacity(0.85))
                }
            }
            .padding(12)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.indigo.opacity(0.14), lineWidth: 1)
        }
    }

    private var configurationHealthCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Configuration Health")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.primary)

            if configurationWarnings.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(Color.green.opacity(0.88))
                    Text("Tribe fully configured")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.green.opacity(0.88))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Color.green.opacity(0.10))
                .clipShape(Capsule())
            } else {
                ForEach(configurationWarnings, id: \.self) { warning in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.orange.opacity(0.92))
                            .padding(.top, 2)
                        Text(warning)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var waitingForApprovalCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Waiting for approval")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.primary)
            Text("The household admin must approve your access before you can view family, runs, and calendar data.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var pendingApprovalsSection: some View {
        ForEach(pendingMemberships, id: \.id) { membership in
            pendingApprovalRow(for: membership)
        }
    }

    private func pendingApprovalRow(for membership: BackendHouseholdMembership) -> some View {
        let resolved = resolvedMembershipDisplay(for: membership)
        let isUpdating = pendingApprovalActionMembershipId == membership.id
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(resolved.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)
                    if let relationship = membershipRelationshipText(for: membership, isCurrentUser: resolved.isCurrentUser) {
                        Text(relationship)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Text("Pending")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.12))
                    .clipShape(Capsule())
            }

            HStack(spacing: 8) {
                Button("Approve") {
                    Task {
                        await updatePendingMembershipStatus(membership, status: "active")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isUpdating)

                Button("Decline", role: .destructive) {
                    Task {
                        await updatePendingMembershipStatus(membership, status: "declined")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(isUpdating)
            }
        }
        .padding(.vertical, 4)
    }

    @MainActor
    private func updatePendingMembershipStatus(_ membership: BackendHouseholdMembership, status: String) async {
        guard canManageHouseholdMembers else { return }
        pendingApprovalActionMembershipId = membership.id
        defer { pendingApprovalActionMembershipId = nil }
        do {
            try await backendHouseholdContext.updateMembershipAttributes(
                membershipId: membership.id,
                role: membership.accessRole,
                status: status,
                familyRole: membership.familyRole,
                relationshipLabel: membership.relationshipLabel
            )
        } catch {
            pendingApprovalErrorMessage = "Unable to update this membership. Please try again."
        }
    }

    private func adultMemberRow(_ member: TribeMember) -> some View {
        HStack(spacing: 10) {
            MemberAvatarView(member: member, size: 44)
                .onTapGesture {
                    onSelectMember(member)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(member.fullName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                HStack(spacing: 6) {
                    Circle()
                        .fill(member.isDriver ? Color.indigo : Color.gray.opacity(0.45))
                        .frame(width: 8, height: 8)
                    Text(member.isDriver ? "Driver enabled" : "No driver role")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 6) {
                    ForEach(member.roles.sorted(by: { $0.sortOrder < $1.sortOrder }), id: \.self) { role in
                        rolePill(role: role)
                    }
                }
            }

            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .frame(minHeight: 56)
    }

    private func childMemberRow(_ member: TribeMember) -> some View {
        let scheduleCount = store.ruleCount(for: member.id)
        return HStack(spacing: 10) {
            MemberAvatarView(
                member: member,
                size: 44,
                accessToken: authSession.currentAccessToken
            )
                .onTapGesture {
                    onSelectMember(member)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(member.preferredDisplayName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                if let ageText = member.ageText {
                    Text(ageText)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                Text(member.schoolRoutineSummary)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                Text(member.activityCountText)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(scheduleCount > 0 ? "\(scheduleCount) schedule rule\(scheduleCount == 1 ? "" : "s")" : "Setup incomplete")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(scheduleCount > 0 ? Color.indigo : Color.orange.opacity(0.92))
                HStack(spacing: 6) {
                    ForEach(member.roles.sorted(by: { $0.sortOrder < $1.sortOrder }), id: \.self) { role in
                        rolePill(role: role)
                    }
                }
            }

            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .frame(minHeight: 56)
    }

    private func rolePill(role: Role) -> some View {
        let isSoftRole = (role == .child || role == .passenger)
        return Text(role.rawValue)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Color.indigo.opacity(isSoftRole ? 0.72 : 1))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.indigo.opacity(isSoftRole ? 0.07 : 0.12))
            .clipShape(Capsule())
    }

    private func copyInviteCode(_ code: String) {
        UIPasteboard.general.string = code
        withAnimation(.easeInOut(duration: 0.2)) {
            didCopyInviteCode = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation(.easeInOut(duration: 0.2)) {
                didCopyInviteCode = false
            }
        }
    }

    private func resolvedMembershipDisplay(for membership: BackendHouseholdMembership) -> (name: String, isCurrentUser: Bool) {
        let isCurrentUser = membership.userId.uuidString.lowercased() == authSession.currentUserId?.lowercased()
        let profile: BackendProfile?
        if isCurrentUser, let currentUserProfile = backendProfileContext.currentUserProfile {
            profile = currentUserProfile
        } else {
            profile = backendHouseholdContext.activeHouseholdProfilesByUserId[membership.userId]
        }
        if let profile {
            return (
                AuthBackedMemberDisplayResolver.resolveName(
                    profile: profile,
                    relationshipLabel: membership.relationshipLabel
                ),
                isCurrentUser
            )
        }
        return (
            AuthBackedMemberDisplayResolver.resolveName(
                profile: nil,
                relationshipLabel: membership.relationshipLabel
            ),
            isCurrentUser
        )
    }

    private func logFamilyDiagnostics() {
#if DEBUG
        let activeHouseholdId = activeHouseholdStore.activeHouseholdId?.uuidString ?? "nil"
        let membershipUserIds = activeMemberships.map { $0.userId.uuidString }.joined(separator: ",")
        let renderedMemberCount = activeMembershipCards.count + pendingMemberships.count
        print(
            "[FamilyMembers] activeHouseholdId=\(activeHouseholdId), membership_count=\(activeMemberships.count), " +
            "membership_user_ids=[\(membershipUserIds)], people_count=\(backendHouseholdPeopleContext.people.count), " +
            "children_count=\(backendChildrenContext.children.count), rendered_member_count=\(renderedMemberCount), " +
            "pending=\(pendingMemberships.count), active_members=\(activeMembershipCards.count), " +
            "summary_members=\(activeMemberships.count), summary_children=\(childrenCount)"
        )
#endif
    }

    private func handleCardTap(_ card: FamilyPersonCardItem) {
        switch card.source {
        case .householdPerson(let personId):
#if DEBUG
            print("[FamilyMembersListView] selected member id=\(personId.uuidString), source=household_people")
#endif
            selectedHouseholdPerson = FamilySelectedPerson(id: personId)
        case .membership(let membershipId, _):
#if DEBUG
            print("[FamilyMembersListView] selected member id=\(membershipId.uuidString), source=household_memberships")
#endif
            guard let membership = allMemberships.first(where: { $0.id == membershipId }) else {
                membershipNotice = MembershipNotice(
                    message: "This person manages their own account profile. You can still approve membership, assign family role, and set household permissions."
                )
                return
            }
            let resolved = resolvedMembershipDisplay(for: membership)
#if DEBUG
            let currentUserId = authSession.currentUserId ?? "nil"
            let currentRole = currentUserMembershipForActiveHousehold?.normalizedAccessRole?.rawValue ?? "nil"
            let mode = canManageHouseholdMembers ? "editable" : "read_only"
            print(
                "[FamilyMembersListView] open membership sheet current_user_id=\(currentUserId), " +
                "edited_membership_id=\(membership.id.uuidString), current_user_role=\(currentRole), " +
                "canManageHouseholdMembers=\(canManageHouseholdMembers), mode=\(mode)"
            )
#endif
            selectedMembershipEditor = FamilySelectedMembership(
                membershipId: membership.id,
                memberName: resolved.name,
                membershipStatus: membership.status,
                permissionRole: membership.accessRole,
                familyRole: membership.familyRole,
                relationshipLabel: membership.relationshipLabel
            )
        }
    }

    private func membershipRoleChips(for membership: BackendHouseholdMembership) -> [FamilyRoleChip] {
        var chips: [FamilyRoleChip] = []
        if isAdminMembership(membership) {
            chips.append(FamilyRoleChip(label: "Admin", tint: .indigo))
        }
        if let role = effectiveFamilyRole(for: membership) {
            switch role {
            case "parent":
                chips.append(FamilyRoleChip(label: "Parent", tint: .purple))
            case "driver":
                chips.append(FamilyRoleChip(label: "Driver", tint: .blue))
            case "helper":
                chips.append(FamilyRoleChip(label: "Helper", tint: .gray))
            case "guardian":
                chips.append(FamilyRoleChip(label: "Guardian", tint: .teal))
            default:
                chips.append(FamilyRoleChip(label: role.capitalized, tint: .gray))
            }
        }
        return chips
    }

    private func membershipRelationshipText(for membership: BackendHouseholdMembership, isCurrentUser: Bool) -> String? {
        if isCurrentUser { return "You" }
        return membership.relationshipLabel?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "Account member"
    }

    private func effectiveFamilyRole(for membership: BackendHouseholdMembership) -> String? {
        if let familyRole = membership.familyRole?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty?.lowercased() {
            return familyRole
        }
        if membership.normalizedAccessRole == .organiser {
            return "parent"
        }
        return nil
    }

    private func isCurrentUserMembership(_ membership: BackendHouseholdMembership) -> Bool {
        membership.userId.uuidString.lowercased() == authSession.currentUserId?.lowercased()
    }

    private func isAdminMembership(_ membership: BackendHouseholdMembership) -> Bool {
        membership.normalizedAccessRole == .organiser
    }
}

private struct FamilyPersonCardItem: Identifiable {
    enum Source {
        case membership(membershipId: UUID, userId: UUID)
        case householdPerson(personId: UUID)
    }

    let id: String
    let name: String
    let relationship: String?
    let roleChips: [FamilyRoleChip]
    let showsChevron: Bool
    let avatarIdentity: TribeAvatarIdentity
    let source: Source
}

private struct FamilyRoleChip {
    let label: String
    let tint: Color
}

private struct FamilySelectedPerson: Identifiable {
    let id: UUID
}

private struct MembershipNotice: Identifiable {
    let id = UUID()
    let message: String
}

private struct FamilySelectedMembership: Identifiable {
    let membershipId: UUID
    let memberName: String
    let membershipStatus: String?
    let permissionRole: String?
    let familyRole: String?
    let relationshipLabel: String?

    var id: UUID { membershipId }
}

private struct HouseholdMembershipAssignmentSheet: View {
    @Environment(\.dismiss) private var dismiss

    let selectedMembership: FamilySelectedMembership
    let canManageHouseholdMembers: Bool
    let onSave: (UUID, String?, String?, String?, String?) async throws -> Void

    @State private var membershipId: UUID?
    @State private var membershipStatus: String = "pending"
    @State private var permissionRole: String = "member"
    @State private var familyRole: String = ""
    @State private var relationshipLabel: String = ""
    @State private var isSaving: Bool = false
    @State private var saveErrorMessage: String?
    @State private var didPrefill = false

    private let availableFamilyRoles = ["parent", "driver", "helper", "guardian", "observer"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Member") {
                    Text(selectedMembership.memberName)
                        .font(.system(size: 16, weight: .semibold))
                    Text("This person manages their own account profile. You can still approve membership, assign family role, and set household permissions.")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }

                Section("Approval") {
                    Picker("Membership status", selection: $membershipStatus) {
                        Text("Pending").tag("pending")
                        Text("Active").tag("active")
                        Text("Declined").tag("declined")
                        Text("Revoked").tag("revoked")
                    }
                    .disabled(!canManageHouseholdMembers)
                    if membershipStatus == "pending" {
                        HStack(spacing: 8) {
                            Button("Approve") { membershipStatus = "active" }
                                .buttonStyle(.borderedProminent)
                                .disabled(!canManageHouseholdMembers)
                            Button("Decline", role: .destructive) { membershipStatus = "declined" }
                                .buttonStyle(.bordered)
                                .disabled(!canManageHouseholdMembers)
                        }
                    }
                }

                Section("Permissions") {
                    Picker("Permission role", selection: $permissionRole) {
                        Text("Member").tag("member")
                        Text("Admin").tag("admin")
                    }
                    .disabled(!canManageHouseholdMembers)
                }

                Section("Household Assignment") {
                    Picker("Family role", selection: Binding(
                        get: { familyRole.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "__none__" },
                        set: { newValue in
                            familyRole = (newValue == "__none__") ? "" : newValue
                        }
                    )) {
                        Text("Unassigned").tag("__none__")
                        ForEach(availableFamilyRoles, id: \.self) { role in
                            Text(role.capitalized).tag(role)
                        }
                    }
                    .disabled(!canManageHouseholdMembers)

                    TextField("Relationship label (optional)", text: $relationshipLabel)
                        .disabled(!canManageHouseholdMembers)
                }

                if !canManageHouseholdMembers {
                    Section {
                        Text("You don't have permission to edit this member.")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Edit Household Member")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                if canManageHouseholdMembers {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Save") {
                            Task {
                                await save()
                            }
                        }
                        .disabled(isSaving)
                    }
                }
            }
        }
        .onAppear {
            prefillFromSelectedMembership()
        }
        .alert("Unable to Save", isPresented: Binding(
            get: { saveErrorMessage != nil },
            set: { newValue in
                if !newValue { saveErrorMessage = nil }
            }
        )) {
            Button("OK", role: .cancel) {
                saveErrorMessage = nil
            }
        } message: {
            Text(saveErrorMessage ?? "Save failed.")
        }
    }

    @MainActor
    private func prefillFromSelectedMembership() {
        guard !didPrefill else { return }
        didPrefill = true

        membershipId = selectedMembership.membershipId
        membershipStatus = selectedMembership.membershipStatus ?? "pending"
        permissionRole = selectedMembership.permissionRole ?? "member"
        familyRole = selectedMembership.familyRole ?? ""
        relationshipLabel = selectedMembership.relationshipLabel ?? ""
#if DEBUG
        print(
            "[HouseholdMembershipAssignmentSheet] prefill id=\(selectedMembership.membershipId.uuidString), " +
            "status=\(membershipStatus), role=\(permissionRole), familyRole=\(familyRole), " +
            "relationshipLabel=\(relationshipLabel)"
        )
#endif
    }

    @MainActor
    private func save() async {
        guard canManageHouseholdMembers else {
#if DEBUG
            print("[FamilyEdit] blocked save: current user is not admin")
#endif
            return
        }
        guard !isSaving else { return }
        guard let membershipId else {
            saveErrorMessage = "Unable to locate this household membership."
            return
        }

        let normalizedMembershipStatus = membershipStatus
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let normalizedPermissionRole = permissionRole
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let normalizedFamilyRole = familyRole
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .nilIfEmpty
        let normalizedRelationshipLabel = relationshipLabel
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty
#if DEBUG
        print(
            "[HouseholdMembershipAssignmentSheet] save start id=\(membershipId.uuidString), " +
            "status=\(normalizedMembershipStatus), role=\(normalizedPermissionRole), " +
            "familyRole=\(normalizedFamilyRole ?? "nil"), relationshipLabel=\(normalizedRelationshipLabel ?? "nil")"
        )
#endif

        isSaving = true
        do {
            try await onSave(
                membershipId,
                normalizedPermissionRole.nilIfEmpty,
                normalizedMembershipStatus.nilIfEmpty,
                normalizedFamilyRole,
                normalizedRelationshipLabel
            )
            isSaving = false
#if DEBUG
            print("[HouseholdMembershipAssignmentSheet] save success id=\(membershipId.uuidString)")
#endif
            dismiss()
        } catch {
            isSaving = false
            switch error {
            case MembershipError.notAuthorizedOrNotFound:
                saveErrorMessage = "You don't have permission to update this member."
            default:
                saveErrorMessage = "Unable to save changes. Please try again."
            }
#if DEBUG
            print("[HouseholdMembershipAssignmentSheet] save failure id=\(membershipId.uuidString), error=\(error.localizedDescription)")
#endif
        }
    }
}

private struct FamilyPersonCardView: View {
    let item: FamilyPersonCardItem

    @EnvironmentObject private var authSession: AuthSessionContext

    var body: some View {
        HStack(spacing: 12) {
            TribeAvatarView(
                identity: item.avatarIdentity,
                size: .medium,
                accessToken: authSession.currentAccessToken
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)

                if let relationship = item.relationship {
                    Text(relationship)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                if !item.roleChips.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(Array(item.roleChips.enumerated()), id: \.offset) { _, chip in
                            Text(chip.label)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(chip.tint)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(chip.tint.opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }
                }
            }

            Spacer()

            if item.showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct FamilyAddMemberView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: TribeStore
    @EnvironmentObject private var authSession: AuthSessionContext
    @EnvironmentObject private var backendHouseholdContext: BackendHouseholdContext
    @EnvironmentObject private var backendHouseholdPeopleContext: BackendHouseholdPeopleContext
    @EnvironmentObject private var backendChildrenContext: BackendChildrenContext

    @State private var name = ""
    @State private var relationship = ""
    @State private var memberType: MemberType = .adult
    @State private var adultRole: Role = .parent
    @State private var phone = ""
    @State private var displayName = ""
    @State private var dateOfBirth: Date?
    @State private var schoolName = ""
    @State private var schoolAddress = ""
    @State private var gradeOrClass = ""
    @State private var schoolDays: Set<Weekday> = [.monday, .tuesday, .wednesday, .thursday, .friday]
    @State private var schoolStartTime: DateComponents?
    @State private var schoolEndTime: DateComponents?
    @State private var isSaving = false
    @State private var saveErrorMessage: String?
    @StateObject private var schoolSearchModel = LocationSearchModel()

    var body: some View {
        NavigationStack {
            Form {
                Section("Member") {
                    TextField("Name", text: $name)
                    TextField("Relationship (optional)", text: $relationship)
                    Picker("Member type", selection: $memberType) {
                        Text("Adult").tag(MemberType.adult)
                        Text("Child").tag(MemberType.child)
                    }
                    if memberType == .adult {
                        Picker("Adult role", selection: $adultRole) {
                            Text("Parent").tag(Role.parent)
                            Text("Driver").tag(Role.driver)
                            Text("Observer").tag(Role.observer)
                            Text("Admin").tag(Role.admin)
                        }
                    }
                    TextField("Phone (optional)", text: $phone)
                        .keyboardType(.phonePad)
                    if memberType == .child {
                        TextField("Preferred display name (optional)", text: $displayName)
                        DatePicker(
                            "Date of birth (optional)",
                            selection: dateOfBirthBinding,
                            in: ...Date(),
                            displayedComponents: .date
                        )
                        TextField("School name (optional)", text: $schoolName)
                        LocationSearchField(
                            title: "School Search",
                            placeholder: "Search school",
                            model: schoolSearchModel,
                            onSelected: { result in
                                if schoolName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    schoolName = result.title
                                }
                                schoolAddress = result.fullAddress
                            },
                            onCleared: { }
                        )
                        TextField("School address (optional)", text: $schoolAddress)
                        TextField("Grade/Class (optional)", text: $gradeOrClass)
                        schoolDaysPicker
                        DatePicker(
                            "School start time",
                            selection: schoolStartTimeBinding,
                            displayedComponents: .hourAndMinute
                        )
                        DatePicker(
                            "School end time",
                            selection: schoolEndTimeBinding,
                            displayedComponents: .hourAndMinute
                        )
                    }
                }
            }
            .navigationTitle("Add Member")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        Task {
                            await saveMember()
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                }
            }
        }
        .alert("Unable to Save", isPresented: Binding(
            get: { saveErrorMessage != nil },
            set: { newValue in
                if !newValue { saveErrorMessage = nil }
            }
        )) {
            Button("OK", role: .cancel) {
                saveErrorMessage = nil
            }
        } message: {
            Text(saveErrorMessage ?? "Save failed.")
        }
    }

    private func saveMember() async {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        print("[FamilyAddMemberView] Save tapped for memberType=\(memberType.rawValue), authenticated=\(authSession.isAuthenticated)")

        let newMember = TribeMember(
            fullName: trimmedName,
            memberType: memberType,
            relationship: relationship.nilIfEmpty,
            dateOfBirth: memberType == .child ? dateOfBirth : nil,
            displayName: memberType == .child ? displayName.nilIfEmpty : nil,
            schoolName: memberType == .child ? schoolName.nilIfEmpty : nil,
            schoolAddress: memberType == .child ? schoolAddress.nilIfEmpty : nil,
            gradeOrClass: memberType == .child ? gradeOrClass.nilIfEmpty : nil,
            schoolStartTime: memberType == .child ? schoolStartTime : nil,
            schoolEndTime: memberType == .child ? schoolEndTime : nil,
            schoolDays: memberType == .child ? (schoolDays.isEmpty ? nil : schoolDays) : nil,
            phone: phone.nilIfEmpty,
            roles: memberType == .child ? [.child, .passenger] : [adultRole],
            isLocationSharingEnabled: true,
            isOnline: false
        )

        isSaving = true
        saveErrorMessage = nil
        defer { isSaving = false }

        if newMember.memberType == .child {
            let didCreate = await backendChildrenContext.createChild(newMember)
            print("[FamilyAddMemberView] Child save result didCreate=\(didCreate)")
            if didCreate {
                dismiss()
            } else {
                saveErrorMessage = backendChildrenContext.lastError ?? "Unable to save child member. Please try again."
            }
            return
        }

        guard authSession.isAuthenticated else {
            store.addMember(newMember)
            print("[FamilyAddMemberView] Adult save completed locally for unauthenticated flow")
            dismiss()
            return
        }

        guard backendHouseholdContext.activeHouseholdId != nil else {
            let message = "No active household selected. Please create or join a family first."
            backendHouseholdPeopleContext.lastError = message
            saveErrorMessage = message
            print("[FamilyAddMemberView] Adult save failed: \(message)")
            return
        }

        let didSave = await backendHouseholdPeopleContext.createPerson(
            name: newMember.fullName,
            relationship: newMember.relationship,
            role: backendHouseholdPeopleContext.mapAdultMemberToBackendRole(newMember),
            phone: newMember.phone,
            isDriver: newMember.roles.contains(.driver)
        )
        print("[FamilyAddMemberView] Adult save result didSave=\(didSave)")
        guard didSave else {
            saveErrorMessage = backendHouseholdPeopleContext.lastError ?? "Unable to save adult member. Please try again."
            return
        }

        await backendHouseholdPeopleContext.refreshForActiveHousehold()
        dismiss()
    }

    private var dateOfBirthBinding: Binding<Date> {
        Binding(
            get: { dateOfBirth ?? Calendar.current.date(byAdding: .year, value: -8, to: Date()) ?? Date() },
            set: { dateOfBirth = $0 }
        )
    }

    private var schoolStartTimeBinding: Binding<Date> {
        Binding(
            get: {
                let fallback = DateComponents(hour: 7, minute: 45)
                return Calendar.current.date(from: schoolStartTime ?? fallback) ?? Date()
            },
            set: { schoolStartTime = Calendar.current.dateComponents([.hour, .minute], from: $0) }
        )
    }

    private var schoolEndTimeBinding: Binding<Date> {
        Binding(
            get: {
                let fallback = DateComponents(hour: 13, minute: 45)
                return Calendar.current.date(from: schoolEndTime ?? fallback) ?? Date()
            },
            set: { schoolEndTime = Calendar.current.dateComponents([.hour, .minute], from: $0) }
        )
    }

    private var schoolDaysPicker: some View {
        HStack(spacing: 8) {
            ForEach(Weekday.allCases, id: \.self) { day in
                let selected = schoolDays.contains(day)
                Button(day.shortLabel) {
                    if selected { schoolDays.remove(day) } else { schoolDays.insert(day) }
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(selected ? .white : .secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(selected ? Color.indigo : Color.gray.opacity(0.15))
                .clipShape(Capsule())
                .buttonStyle(.plain)
            }
        }
    }
}

private struct FamilyMemberDetailView: View {
    @ObservedObject var store: TribeStore
    let memberID: UUID

    var body: some View {
        Group {
            if let member = store.members.first(where: { $0.id == memberID }) {
                List {
                    Section("Member") {
                        Text(member.preferredDisplayName)
                        Text(member.subtitle).foregroundStyle(.secondary)
                        if member.memberType == .child {
                            Text(member.schoolRoutineSummary)
                                .foregroundStyle(.secondary)
                        }
                        if let phone = member.phone {
                            Text(phone).foregroundStyle(.secondary)
                        }
                    }
                    Section("Roles") {
                        Text(member.roleBadges.joined(separator: ", "))
                            .foregroundStyle(.secondary)
                    }
                    Section {
                        NavigationLink("Edit Role/Privileges") {
                            FamilyRolePrivilegesView(store: store, memberID: memberID)
                        }
                    }
                }
            } else {
                ContentUnavailableView("Member not found", systemImage: "person.crop.circle.badge.exclamationmark")
            }
        }
        .navigationTitle("Member Detail")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct FamilyRolePrivilegesView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: TribeStore
    let memberID: UUID

    @State private var role: Role = .passenger
    @State private var canCreateRuns = false
    @State private var canDriveRuns = false
    @State private var canSeeAllRuns = false
    @State private var canManageFamily = false

    var body: some View {
        Form {
            Section("Role") {
                Picker("Role", selection: $role) {
                    Text("Admin").tag(Role.admin)
                    Text("Driver").tag(Role.driver)
                    Text("Observer").tag(Role.observer)
                    Text("Parent").tag(Role.parent)
                    Text("Child").tag(Role.child)
                    Text("Passenger").tag(Role.passenger)
                }
            }

            Section("Privileges") {
                Toggle("Can create runs", isOn: $canCreateRuns)
                Toggle("Can drive runs", isOn: $canDriveRuns)
                Toggle("Can see all runs", isOn: $canSeeAllRuns)
                Toggle("Can manage family", isOn: $canManageFamily)
            }

            Section {
                Button("Save") {
                    save()
                    dismiss()
                }
            }
        }
        .navigationTitle("Role & Privileges")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            load()
        }
    }

    private func load() {
        guard let member = store.members.first(where: { $0.id == memberID }) else { return }
        role = member.roles.first ?? .passenger
        canCreateRuns = member.roles.contains(.admin) || member.roles.contains(.parent)
        canDriveRuns = member.roles.contains(.driver)
        canSeeAllRuns = member.roles.contains(.observer) || member.roles.contains(.admin)
        canManageFamily = member.roles.contains(.admin)
    }

    private func save() {
        guard var member = store.members.first(where: { $0.id == memberID }) else { return }

        var roles: Set<Role> = [role]
        if canCreateRuns { roles.insert(.parent) }
        if canDriveRuns { roles.insert(.driver) }
        if canSeeAllRuns { roles.insert(.observer) }
        if canManageFamily { roles.insert(.admin) }
        if role == .child { roles.insert(.child) }
        if role == .passenger { roles.insert(.passenger) }

        member.roles = roles
        store.updateMember(member)
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
        FamilyRootView()
    }
}
