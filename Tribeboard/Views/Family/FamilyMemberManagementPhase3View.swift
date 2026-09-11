import SwiftUI
import UIKit

struct FamilyMemberManagementPhase3View: View {
    @ObservedObject var store: TribeStore
    @EnvironmentObject private var authSession: AuthSessionContext
    @EnvironmentObject private var backendHouseholdContext: BackendHouseholdContext
    @EnvironmentObject private var backendChildrenContext: BackendChildrenContext
    @EnvironmentObject private var backendHouseholdPeopleContext: BackendHouseholdPeopleContext
    @EnvironmentObject private var flow: AppFlowState

    @State private var selectedMembership: BackendHouseholdMembership?
    @State private var presentRemovalConfirmationOnOpen = false
    @State private var isPresentingAddMember = false
    @State private var isPresentingAddChild = false
    @State private var hiddenPendingInviteIds: Set<UUID> = []
    @State private var cancelingInviteIds: Set<UUID> = []
    @State private var resendingInviteIds: Set<UUID> = []
    @State private var processingMembershipRequestIds: Set<UUID> = []
    @State private var inviteActionError: String?
    @State private var inviteActionNotice: String?
    @State private var didCopyInviteCode = false
    @State private var schoolLinkChild: BackendChild?
    private let sectionSpacing: CGFloat = 18
    private let cardSpacing: CGFloat = 12

    private var memberships: [BackendHouseholdMembership] {
        backendHouseholdContext.activeHouseholdMembers
    }

    private var organisers: [BackendHouseholdMembership] {
        activeMemberships.filter { $0.normalizedAccessRole == .organiser }
    }

    /// A driver-capable row resolved from `AssignDriverEligibility` (shared with Create Run and
    /// Assign Driver). Carries the backing membership or household person for tap/context actions.
    private struct FamilyDriverRow: Identifiable {
        let id: UUID
        let name: String
        let membership: BackendHouseholdMembership?
        let person: BackendHouseholdPerson?
    }

    /// Single source of truth for driver eligibility: same resolver and inputs as
    /// `BackendDriversContext.refreshDrivers` (Create Run / Assign Driver).
    private var driverRows: [FamilyDriverRow] {
        guard let activeHouseholdId = backendHouseholdContext.activeHouseholdId else { return [] }
        let candidates = AssignDriverEligibility.resolve(
            activeHouseholdId: activeHouseholdId,
            memberships: memberships,
            profilesByUserId: backendHouseholdContext.activeHouseholdProfilesByUserId,
            householdPeople: backendHouseholdPeopleContext.people,
            childIds: Set(backendChildrenContext.children.map(\.id)),
            currentUserId: authSession.currentUserId.flatMap(UUID.init(uuidString:))
        )
        return candidates.map { candidate in
            switch candidate.source {
            case .householdMembership:
                let membership = activeMemberships.first { $0.userId == candidate.id }
                return FamilyDriverRow(id: candidate.id, name: candidate.displayName, membership: membership, person: nil)
            case .householdPerson:
                let person = backendHouseholdPeopleContext.people.first { $0.id == candidate.id }
                return FamilyDriverRow(id: candidate.id, name: candidate.displayName, membership: nil, person: person)
            }
        }
    }

    private var observers: [BackendHouseholdMembership] {
        activeMemberships.filter { $0.normalizedAccessRole == .observer }
    }

    private var pendingRequests: [BackendHouseholdMembership] {
        memberships.filter {
            $0.normalizedStatus == .pending &&
            !isCurrentUserMembership($0)
        }
    }

    private var pendingInvites: [BackendHouseholdInvite] {
        backendHouseholdContext.activeHouseholdInvites.filter {
            $0.normalizedStatus == .pending &&
            !hiddenPendingInviteIds.contains($0.id)
        }
    }

    private var activeMemberships: [BackendHouseholdMembership] {
        memberships.filter { $0.normalizedStatus == .active || $0.status == nil }
    }

    private var supportPeopleRows: [BackendHouseholdPerson] {
        backendHouseholdPeopleContext.people
    }

    private var activeFamilyName: String {
        backendHouseholdContext.activeHouseholdName ?? "Family"
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: sectionSpacing) {
                heroCard

                familyLocationsSection

                childrenSectionNew
                meetTheTribeSection
                driversSectionNew
                inviteSectionNew

                if backendHouseholdContext.canApproveRequests && !pendingRequests.isEmpty {
                    pendingRequestsSection
                }
                if !pendingInvites.isEmpty {
                    pendingInvitesSection
                }
                if !supportPeopleRows.isEmpty {
                    supportPeopleSection
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 40)
        }
        .background(TribePalette.canvas)
        .sheet(item: $selectedMembership) { membership in
            HouseholdMemberDetailSheet(
                membership: membership,
                householdName: activeFamilyName,
                canManageMembers: backendHouseholdContext.canManageMembers,
                presentRemovalConfirmation: presentRemovalConfirmationOnOpen
            )
            .environmentObject(backendHouseholdContext)
            .onDisappear {
                presentRemovalConfirmationOnOpen = false
            }
        }
        .sheet(isPresented: $isPresentingAddMember) {
            FamilyAddMemberInviteFlowView()
                .environmentObject(authSession)
                .environmentObject(backendHouseholdContext)
        }
        .sheet(isPresented: $isPresentingAddChild) {
            NavigationStack {
                ChildSetupFlowView(store: store)
            }
        }
        .sheet(item: $schoolLinkChild) { child in
            NavigationStack {
                AddEditHouseholdLocationView(
                    prefilledDraft: HouseholdLocationDraft(
                        name: child.schoolName ?? child.displayName ?? child.legalName,
                        label: child.schoolName ?? "School",
                        locationType: .school
                    ),
                    linkSchoolChildId: child.id
                )
            }
        }
        .task {
            guard backendHouseholdContext.hasActiveMembership else { return }
            await backendHouseholdContext.refreshMemberships()
            await backendHouseholdContext.refreshInvites()
            await backendChildrenContext.refreshForActiveHousehold()
            await backendHouseholdPeopleContext.refreshForActiveHousehold()
            NSLog(
                "[FamilyDrivers] householdId=%@ memberships=%d householdPeople=%d eligibleDrivers=%d",
                backendHouseholdContext.activeHouseholdId?.uuidString ?? "nil",
                memberships.count,
                backendHouseholdPeopleContext.people.count,
                driverRows.count
            )
        }
        .onAppear {
            if flow.pendingPostOnboardingAddChild {
                flow.pendingPostOnboardingAddChild = false
                isPresentingAddChild = true
            }
        }
        .alert("Unable to cancel invite", isPresented: Binding(
            get: { inviteActionError != nil },
            set: { if !$0 { inviteActionError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(inviteActionError ?? "Unknown error.")
        }
        .alert("Invite", isPresented: Binding(
            get: { inviteActionNotice != nil },
            set: { if !$0 { inviteActionNotice = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(inviteActionNotice ?? "")
        }
    }

    // MARK: - Illustrated sections (people-first redesign)

    private var heroCard: some View {
        FamilyHeroCardPhase3(
            householdName: activeFamilyName,
            members: familySummary.totalMembers,
            children: familySummary.totalChildren,
            drivers: driverRows.count,
            statusMessage: heroStatusMessage,
            onInvite: { isPresentingAddMember = true }
        )
    }

    private var familySummary: FamilySummary {
        store.familyStore.summary
    }

    private var heroStatusMessage: String {
        activeMemberships.count <= 1 ? "Invite your family to join" : "Everyone connected"
    }

    private var familyLocationsSection: some View {
        FamilyLocationsSectionView()
    }

    // MARK: Children

    private var childrenSectionNew: some View {
        VStack(alignment: .leading, spacing: 12) {
            HomeSectionHeader(
                title: "Children",
                actionTitle: backendHouseholdContext.canManageMembers ? "Add" : nil,
                action: backendHouseholdContext.canManageMembers ? { isPresentingAddChild = true } : nil
            )
            if backendChildrenContext.children.isEmpty {
                FamilyEmptyCardPhase3(
                    illustration: TribeArt.childAvatars.first ?? TribeArt.grandparent,
                    title: "No children yet",
                    message: "Add your children to start planning school runs and activities.",
                    ctaTitle: backendHouseholdContext.canManageMembers ? "Add Child" : nil,
                    onTap: { isPresentingAddChild = true }
                )
            } else {
                ForEach(backendChildrenContext.children, id: \.id) { child in
                    let name = child.displayName?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? child.legalName
                    let school = child.schoolName?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
                    let status = childStatus(hasSchool: school != nil)
                    let today = childTodayText(for: child.id)
                    let schoolLocationMissing = school != nil && child.schoolLocationId == nil
                    FamilyChildCardPhase3(
                        name: name,
                        school: school ?? "No school added yet",
                        hasSchool: school != nil,
                        schoolLocationMissing: schoolLocationMissing,
                        onAddSchoolAddress: schoolLocationMissing ? { schoolLinkChild = child } : nil,
                        statusText: status.text,
                        statusColor: status.color,
                        todayText: today.text,
                        hasActivityToday: today.hasActivity,
                        identity: child.avatarIdentity()
                    )
                }
            }
        }
    }

    // MARK: Meet the tribe

    private var meetTheTribeSection: some View {
        let everyone = activeMemberships
        return Group {
            if !everyone.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HomeSectionHeader(title: "Meet the tribe")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(everyone, id: \.id) { membership in
                                let display = resolveMembershipDisplay(membership)
                                Button {
                                    presentRemovalConfirmationOnOpen = false
                                    selectedMembership = membership
                                } label: {
                                    FamilyMemberChipPhase3(
                                        name: display.name,
                                        roleLabel: roleDisplayLabel(membership.accessRole),
                                        statusLine: memberStatusLine(
                                            role: membership.accessRole,
                                            isOnline: membership.normalizedStatus == .active || membership.status == nil
                                        ),
                                        identity: membershipAvatarIdentity(for: membership),
                                        isOnline: membership.normalizedStatus == .active || membership.status == nil
                                    )
                                }
                                .buttonStyle(PressScaleButtonStyle())
                                .contextMenu { membershipContextMenu(for: membership) }
                            }
                        }
                        .padding(.horizontal, 2)
                        .padding(.vertical, 2)
                    }
                }
            }
        }
    }

    // MARK: Drivers

    private var driversSectionNew: some View {
        VStack(alignment: .leading, spacing: 12) {
            HomeSectionHeader(title: "Family drivers")
            if driverRows.isEmpty {
                FamilyEmptyCardPhase3(
                    illustration: TribeArt.adultAvatars.first ?? TribeArt.grandparent,
                    title: "No drivers yet",
                    message: "Drivers handle the school runs and activity trips for your tribe.",
                    ctaTitle: backendHouseholdContext.canManageMembers ? "Add Driver" : nil,
                    onTap: { isPresentingAddMember = true }
                )
            } else {
                ForEach(driverRows) { row in
                    if let membership = row.membership {
                        Button {
                            presentRemovalConfirmationOnOpen = false
                            selectedMembership = membership
                        } label: {
                            FamilyDriverCardPhase3(
                                name: row.name,
                                availability: "Available for runs",
                                nextRunText: driverNextRunText(for: row.name),
                                identity: membershipAvatarIdentity(for: membership)
                            )
                        }
                        .buttonStyle(.plain)
                        .contextMenu { membershipContextMenu(for: membership) }
                    } else {
                        FamilyDriverCardPhase3(
                            name: row.name,
                            availability: "Available for runs",
                            nextRunText: driverNextRunText(for: row.name),
                            identity: row.person?.avatarIdentity() ?? TribeAvatarIdentity(displayName: row.name)
                        )
                    }
                }
            }
        }
    }

    // MARK: Invite

    @ViewBuilder
    private var inviteSectionNew: some View {
        if let code = backendHouseholdContext.activeHouseholdInviteCode {
            VStack(alignment: .leading, spacing: 12) {
                HomeSectionHeader(title: "Grow your tribe")
                FamilyInviteCardPhase3(
                    code: code,
                    didCopy: didCopyInviteCode,
                    canShare: backendHouseholdContext.canManageMembers,
                    onCopy: { copyInviteCode(code) }
                )
            }
        }
    }

    // MARK: Avatar helpers

    private func membershipAvatarIdentity(for membership: BackendHouseholdMembership) -> TribeAvatarIdentity {
        let profile = backendHouseholdContext.activeHouseholdProfilesByUserId[membership.userId]
        let name = AuthBackedMemberDisplayResolver.resolveName(
            profile: profile,
            relationshipLabel: membership.relationshipLabel
        )
        if let profile {
            return profile.avatarIdentity(fallbackDisplayName: name)
        }
        return TribeAvatarIdentity(displayName: name)
    }

    // MARK: Status + activity helpers

    /// 1 = Mon ... 7 = Sun (matches the backend activity `days` encoding).
    private var todayWeekdayRaw: Int {
        (Calendar.current.component(.weekday, from: Date()) + 5) % 7 + 1
    }

    private func todayActivities(for childId: UUID) -> [BackendChildActivity] {
        backendChildrenContext.activities.filter {
            $0.childId == childId && $0.days.contains(todayWeekdayRaw)
        }
    }

    private func childTodayText(for childId: UUID) -> (text: String, hasActivity: Bool) {
        if let first = todayActivities(for: childId).first {
            return ("\(first.name) today", true)
        }
        return ("No activities today", false)
    }

    private func childStatus(hasSchool: Bool) -> (text: String, color: Color) {
        let hour = Calendar.current.component(.hour, from: Date())
        let isSchoolDay = todayWeekdayRaw <= 5
        if hasSchool && isSchoolDay && (8..<15).contains(hour) {
            return ("At school", TribePalette.primary)
        }
        return ("At home", TribePalette.green)
    }

    private func memberStatusLine(role: String, isOnline: Bool) -> String {
        switch role.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "driver": return "Available"
        case "organiser": return isOnline ? "Online" : "Last seen recently"
        case "observer": return "Last seen recently"
        default: return isOnline ? "Online" : "At home"
        }
    }

    private func driverNextRunText(for driverName: String) -> String? {
        let trimmed = driverName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let run = backendChildrenContext.children
            .compactMap { store.nextUpcomingRun(for: $0.id) }
            .filter { ($0.driverName ?? "").localizedCaseInsensitiveCompare(trimmed) == .orderedSame }
            .min(by: { $0.proposedStart < $1.proposedStart })
        guard let run else { return nil }
        return "\(run.title) • \(formatRunTime(run.proposedStart))"
    }

    private func formatRunTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    private func roleDisplayLabel(_ accessRole: String) -> String {
        switch accessRole.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "organiser": return "Organiser"
        case "driver": return "Driver"
        case "observer": return "Observer"
        default: return accessRole.capitalized
        }
    }

    private var pendingInvitesSection: some View {
        sectionCard {
            sectionHeader("Pending Invites", subtitle: "Sent but not accepted", count: pendingInvites.count)
            VStack(alignment: .leading, spacing: cardSpacing) {
                if pendingInvites.isEmpty {
                    sectionEmptyState("No pending invites")
                } else {
                    LazyVStack(spacing: cardSpacing) {
                        ForEach(pendingInvites, id: \.id) { invite in
                            InviteCardView(
                                invite: invite,
                                canManageMembers: backendHouseholdContext.canManageInvites,
                                isCancelling: cancelingInviteIds.contains(invite.id),
                                isResending: resendingInviteIds.contains(invite.id),
                                onCancel: { Task { await cancelInvite(invite) } },
                                onResend: { Task { await resendInvite(invite) } }
                            )
                        }
                    }
                }
            }
        }
    }

    private var pendingRequestsSection: some View {
        sectionCard {
            sectionHeader("Pending Requests", subtitle: "Awaiting organiser review", count: pendingRequests.count)
            VStack(alignment: .leading, spacing: cardSpacing) {
                if pendingRequests.isEmpty {
                    sectionEmptyState("No pending join requests")
                } else {
                    LazyVStack(spacing: cardSpacing) {
                        ForEach(pendingRequests, id: \.id) { membership in
                            pendingRequestRow(membership)
                        }
                    }
                }
            }
        }
    }

    private var supportPeopleSection: some View {
        sectionCard {
            sectionHeader("Support People", subtitle: "Non-member contacts", count: supportPeopleRows.count)
            VStack(alignment: .leading, spacing: cardSpacing) {
                if supportPeopleRows.isEmpty {
                    sectionEmptyState("No non-member support people")
                } else {
                    LazyVStack(spacing: cardSpacing) {
                        SwiftUI.ForEach(supportPeopleRows, id: \.id) { person in
                            let relationship = person.relationship?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
                            let role = person.role.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
                            MemberCardView(
                                title: person.name,
                                subtitle: relationship ?? role ?? "Support person",
                                badges: supportBadges(for: person, relationship: relationship, role: role),
                                status: person.isDriver ? .active : .inactive,
                                showsChevron: false,
                                identity: person.avatarIdentity()
                            )
                        }
                    }
                }
            }
        }
    }

    private func pendingRequestRow(_ membership: BackendHouseholdMembership) -> some View {
        let display = resolveMembershipDisplay(membership)
        let role = RoleBadgeView.Role(rawValue: membership.accessRole.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()) ?? .observer
        let isProcessing = processingMembershipRequestIds.contains(membership.id)
        return VStack(alignment: .leading, spacing: 10) {
            Button {
                presentRemovalConfirmationOnOpen = false
                selectedMembership = membership
            } label: {
                MemberCardView(
                    title: display.name,
                    subtitle: membershipSubtitle(for: membership),
                    badges: [
                        RoleBadgeView.Model(role: role),
                        RoleBadgeView.Model(label: "Pending", style: .muted),
                        RoleBadgeView.Model(label: "Request", style: .observer)
                    ],
                    status: .inactive,
                    identity: membershipAvatarIdentity(for: membership)
                )
            }
            .buttonStyle(.plain)
            HStack(spacing: 8) {
                Button(isProcessing ? "Processing..." : "Approve") {
                    Task { await approvePendingRequest(membership) }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isProcessing)

                Button("Reject", role: .destructive) {
                    Task { await rejectPendingRequest(membership) }
                }
                .buttonStyle(.bordered)
                .disabled(isProcessing)
            }
            .padding(.horizontal, 4)
        }
    }

    private func resolveMembershipDisplay(_ membership: BackendHouseholdMembership) -> (name: String, email: String?) {
        let profile = backendHouseholdContext.activeHouseholdProfilesByUserId[membership.userId]
        let name = AuthBackedMemberDisplayResolver.resolveName(
            profile: profile,
            relationshipLabel: membership.relationshipLabel
        )
        let email = profile?.email?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        if name == email {
            if let relationship = membership.relationshipLabel?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty {
                return (relationship, email)
            }
            return ("Member", email)
        }
        return (name, email)
    }

    private func membershipSubtitle(for membership: BackendHouseholdMembership) -> String {
        membership.relationshipLabel?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            ?? "Family member"
    }

    @ViewBuilder
    private func membershipContextMenu(for membership: BackendHouseholdMembership) -> some View {
        if backendHouseholdContext.canManageMembers {
            Button("View member details") {
                presentRemovalConfirmationOnOpen = false
                selectedMembership = membership
            }
            let evaluation = backendHouseholdContext.removalEligibility(for: membership)
            if evaluation.canRemove {
                Button("Remove from family", role: .destructive) {
                    presentRemovalConfirmationOnOpen = true
                    selectedMembership = membership
                }
            }
        }
    }

    private func cancelInvite(_ invite: BackendHouseholdInvite) async {
        guard backendHouseholdContext.canManageInvites else { return }
        guard !cancelingInviteIds.contains(invite.id) else { return }
        cancelingInviteIds.insert(invite.id)
        let cancelled = await backendHouseholdContext.cancelInvite(inviteId: invite.id)
        cancelingInviteIds.remove(invite.id)
        if cancelled {
            hiddenPendingInviteIds.insert(invite.id)
            await backendHouseholdContext.refreshInvites()
        } else {
            hiddenPendingInviteIds.remove(invite.id)
            inviteActionError = backendHouseholdContext.lastError ?? "Cancel invite failed."
        }
    }

    private func resendInvite(_ invite: BackendHouseholdInvite) async {
        guard backendHouseholdContext.canManageInvites else { return }
        guard !resendingInviteIds.contains(invite.id) else { return }
        resendingInviteIds.insert(invite.id)
        let resent = await backendHouseholdContext.resendInvite(invite)
        resendingInviteIds.remove(invite.id)
        if resent {
            inviteActionNotice = "Invite resent."
        } else {
            inviteActionError = backendHouseholdContext.lastError ?? "Resend invite failed."
        }
    }

    private func approvePendingRequest(_ membership: BackendHouseholdMembership) async {
        guard backendHouseholdContext.canApproveRequests else { return }
        guard !processingMembershipRequestIds.contains(membership.id) else { return }
        processingMembershipRequestIds.insert(membership.id)
        let ok = await backendHouseholdContext.approveMembershipRequest(membership)
        processingMembershipRequestIds.remove(membership.id)
        if ok {
            inviteActionNotice = "Membership approved."
        } else {
            inviteActionError = backendHouseholdContext.lastError ?? "Unable to approve membership request."
        }
    }

    private func rejectPendingRequest(_ membership: BackendHouseholdMembership) async {
        guard backendHouseholdContext.canApproveRequests else { return }
        guard !processingMembershipRequestIds.contains(membership.id) else { return }
        processingMembershipRequestIds.insert(membership.id)
        let ok = await backendHouseholdContext.rejectMembershipRequest(membership)
        processingMembershipRequestIds.remove(membership.id)
        if ok {
            inviteActionNotice = "Membership rejected."
        } else {
            inviteActionError = backendHouseholdContext.lastError ?? "Unable to reject membership request."
        }
    }

    private func isCurrentUserMembership(_ membership: BackendHouseholdMembership) -> Bool {
        guard let currentUserId = authSession.currentUserId?.lowercased() else { return false }
        return membership.userId.uuidString.lowercased() == currentUserId
    }

    private func sectionHeader(_ title: String, subtitle: String? = nil, count: Int? = nil) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.primary.opacity(0.92))
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let count {
                Text("\(count)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.indigo)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.indigo.opacity(0.10))
                    .clipShape(Capsule())
            }
        }
    }

    private func sectionCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: cardSpacing) {
            content()
        }
        .illustratedPanel(cornerRadius: 22, padding: 16)
    }

    private func sectionEmptyState(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.secondary)
            .padding(.leading, 2)
    }

    private func supportBadges(
        for person: BackendHouseholdPerson,
        relationship: String?,
        role: String?
    ) -> [RoleBadgeView.Model] {
        var badges: [RoleBadgeView.Model] = [
            RoleBadgeView.Model(label: "Support", style: .support)
        ]
        if let relationship {
            badges.append(RoleBadgeView.Model(label: relationship, style: .observer))
        } else if let role {
            badges.append(RoleBadgeView.Model(label: role.capitalized, style: .observer))
        }
        if person.isDriver {
            badges.append(RoleBadgeView.Model(role: .driver))
        }
        return badges
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
}

// MARK: - Illustrated cards (people-first redesign)

private struct FamilyHeroCardPhase3: View {
    let householdName: String
    let members: Int
    let children: Int
    let drivers: Int
    let statusMessage: String
    var onInvite: () -> Void

    private var gradient: LinearGradient {
        LinearGradient(
            colors: [Color(tribeHex: "#7C5CE6"), Color(tribeHex: "#A98BF0")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                gradient

                Image(CalArt.family)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geo.size.width * 0.68, height: geo.size.height, alignment: .bottom)
                    .clipped()
                    .mask(
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0.0),
                                .init(color: .black, location: 0.26),
                                .init(color: .black, location: 1.0)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .allowsHitTesting(false)

                // Soft left scrim keeps the text readable without covering the illustration.
                LinearGradient(
                    stops: [
                        .init(color: Color(tribeHex: "#7C5CE6").opacity(0.55), location: 0.0),
                        .init(color: Color(tribeHex: "#7C5CE6").opacity(0.0), location: 0.6)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .allowsHitTesting(false)

                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(householdName)
                            .font(.system(size: 25, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Text("Your family circle")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.85))
                    }

                    HStack(spacing: 7) {
                        statChip("person.2.fill", members)
                        statChip("figure.child", children)
                        statChip("car.fill", drivers)
                    }
                    .fixedSize()

                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                        Text(statusMessage)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.95))
                    }
                    .padding(.horizontal, 11)
                    .padding(.vertical, 6)
                    .background(.white.opacity(0.18), in: Capsule())

                    Button(action: onInvite) {
                        HStack(spacing: 7) {
                            Image(systemName: "person.badge.plus")
                                .font(.system(size: 13, weight: .bold))
                            Text("Invite Member")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .foregroundStyle(Color(tribeHex: "#7C5CE6"))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 11)
                        .background(.white, in: Capsule())
                    }
                    .buttonStyle(PressScaleButtonStyle())
                    .padding(.top, 2)
                }
                .padding(18)
                .frame(maxWidth: geo.size.width * 0.62, alignment: .leading)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .frame(height: 214)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: Color(tribeHex: "#7C5CE6").opacity(0.32), radius: 18, x: 0, y: 12)
    }

    private func statChip(_ systemName: String, _ value: Int) -> some View {
        HStack(spacing: 5) {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
            Text("\(value)")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
        }
        .fixedSize()
        .lineLimit(1)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.white.opacity(0.18), in: Capsule())
    }
}

private struct FamilyChildCardPhase3: View {
    let name: String
    let school: String
    let hasSchool: Bool
    var schoolLocationMissing: Bool = false
    var onAddSchoolAddress: (() -> Void)?
    let statusText: String
    let statusColor: Color
    let todayText: String
    let hasActivityToday: Bool
    let identity: TribeAvatarIdentity

    @EnvironmentObject private var authSession: AuthSessionContext

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            TribeAvatarView(
                identity: identity,
                size: .medium,
                status: statusColor == TribePalette.green ? .available : (statusColor == TribePalette.orange ? .atSchool : .activity),
                accessToken: authSession.currentAccessToken
            )

            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 8) {
                    Text(name)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(TribePalette.ink)
                        .lineLimit(1)
                    Text("Child")
                        .font(.system(size: 10.5, weight: .bold))
                        .foregroundStyle(TribePalette.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(TribePalette.primarySoft, in: Capsule())
                }

                HStack(spacing: 5) {
                    Image(systemName: hasSchool ? "graduationcap.fill" : "graduationcap")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(TribePalette.muted)
                    Text(school)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(TribePalette.muted)
                        .lineLimit(1)
                }

                if schoolLocationMissing {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.orange)
                        Text("School address missing")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.orange)
                        if let onAddSchoolAddress {
                            Button("Add school address", action: onAddSchoolAddress)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(TribePalette.primary)
                        }
                    }
                }

                HStack(spacing: 8) {
                    HStack(spacing: 5) {
                        Circle().fill(statusColor).frame(width: 7, height: 7)
                        Text(statusText)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(statusColor)
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.12), in: Capsule())

                    HStack(spacing: 5) {
                        Image(systemName: hasActivityToday ? "figure.run" : "calendar")
                            .font(.system(size: 10.5, weight: .semibold))
                        Text(todayText)
                            .font(.system(size: 12, weight: .medium))
                            .lineLimit(1)
                    }
                    .foregroundStyle(hasActivityToday ? TribePalette.primary : TribePalette.muted)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background((hasActivityToday ? TribePalette.primarySoft : TribePalette.muted.opacity(0.1)), in: Capsule())
                }
            }
            Spacer(minLength: 0)
        }
        .illustratedPanel(cornerRadius: 22, padding: 14)
    }
}

private struct FamilyMemberChipPhase3: View {
    let name: String
    let roleLabel: String
    let statusLine: String
    let identity: TribeAvatarIdentity
    let isOnline: Bool

    @EnvironmentObject private var authSession: AuthSessionContext

    var body: some View {
        VStack(spacing: 8) {
            TribeAvatarView(
                identity: identity,
                size: .medium,
                status: isOnline ? .available : nil,
                accessToken: authSession.currentAccessToken
            )
            Text(name)
                .font(.system(size: 13.5, weight: .bold))
                .foregroundStyle(TribePalette.ink)
                .lineLimit(1)
            Text(roleLabel)
                .font(.system(size: 10.5, weight: .bold))
                .foregroundStyle(TribePalette.primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(TribePalette.primarySoft, in: Capsule())
            HStack(spacing: 4) {
                Circle()
                    .fill(isOnline ? TribePalette.green : Color.gray.opacity(0.5))
                    .frame(width: 5, height: 5)
                Text(statusLine)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(TribePalette.muted)
                    .lineLimit(1)
            }
        }
        .frame(width: 112)
        .padding(.vertical, 14)
        .padding(.horizontal, 8)
        .background(TribePalette.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 5)
    }
}

private struct FamilyDriverCardPhase3: View {
    let name: String
    let availability: String
    let nextRunText: String?
    let identity: TribeAvatarIdentity

    @EnvironmentObject private var authSession: AuthSessionContext

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            TribeAvatarView(
                identity: identity,
                size: .small,
                status: .driving,
                accessToken: authSession.currentAccessToken
            )

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(name)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(TribePalette.ink)
                        .lineLimit(1)
                    Text("Driver")
                        .font(.system(size: 10.5, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 3)
                        .background(TribePalette.primary, in: Capsule())
                }
                HStack(spacing: 5) {
                    Circle().fill(TribePalette.green).frame(width: 8, height: 8)
                    Text(availability)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(TribePalette.muted)
                        .lineLimit(1)
                }
                HStack(spacing: 6) {
                    Image(systemName: "car.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(nextRunText == nil ? TribePalette.muted : TribePalette.primary)
                    Text(nextRunText.map { "Next run: \($0)" } ?? "No runs assigned")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(nextRunText == nil ? TribePalette.muted : TribePalette.ink)
                        .lineLimit(1)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    (nextRunText == nil ? TribePalette.muted.opacity(0.1) : TribePalette.primarySoft),
                    in: Capsule()
                )
                .padding(.top, 1)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(TribePalette.muted.opacity(0.6))
                .padding(.top, 4)
        }
        .illustratedPanel(cornerRadius: 22, padding: 14)
    }
}

private struct FamilyEmptyCardPhase3: View {
    let illustration: String
    let title: String
    let message: String
    var ctaTitle: String?
    var onTap: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            avatarCircle(illustration, size: 54)
                .opacity(0.9)
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.system(size: 15.5, weight: .bold))
                    .foregroundStyle(TribePalette.ink)
                Text(message)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(TribePalette.muted)
                    .fixedSize(horizontal: false, vertical: true)
                if let ctaTitle {
                    Button(action: onTap) {
                        Text(ctaTitle)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(TribePalette.primary, in: Capsule())
                    }
                    .buttonStyle(PressScaleButtonStyle())
                    .padding(.top, 2)
                }
            }
            Spacer(minLength: 0)
        }
        .illustratedPanel(cornerRadius: 22, padding: 16)
    }
}

private struct FamilyInviteCardPhase3: View {
    let code: String
    let didCopy: Bool
    let canShare: Bool
    var onCopy: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Invite family members, drivers or trusted helpers.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(TribePalette.muted)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                Text(code)
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundStyle(TribePalette.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(TribePalette.primarySoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                Button(action: onCopy) {
                    Image(systemName: "doc.on.doc.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(TribePalette.primary)
                        .frame(width: 46, height: 46)
                        .background(TribePalette.primarySoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(PressScaleButtonStyle())

                if canShare {
                    ShareLink(item: "Join our family on TribeBoard with code \(code)") {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 46, height: 46)
                            .background(TribePalette.primary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
            }

            if didCopy {
                Text("Invite code copied")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(TribePalette.green)
            }
        }
        .illustratedPanel(cornerRadius: 22, padding: 18)
    }
}

private struct MemberCardView: View {
    let title: String
    let subtitle: String?
    let badges: [RoleBadgeView.Model]
    let status: StatusDotView.State
    var showsChevron: Bool = true
    var identity: TribeAvatarIdentity?

    @EnvironmentObject private var authSession: AuthSessionContext

    var body: some View {
        HStack(spacing: 12) {
            TribeAvatarView(
                identity: identity ?? TribeAvatarIdentity(displayName: title),
                size: .small,
                accessToken: authSession.currentAccessToken
            )
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                if !badges.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(Array(badges.enumerated()), id: \.offset) { _, badge in
                                RoleBadgeView(model: badge)
                            }
                        }
                    }
                }
            }
            Spacer()
            HStack(spacing: 10) {
                StatusDotView(state: status)
                if showsChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(14)
        .background(Color(uiColor: .systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 3)
    }
}

private struct InviteCardView: View {
    let invite: BackendHouseholdInvite
    let canManageMembers: Bool
    let isCancelling: Bool
    let isResending: Bool
    let onCancel: () -> Void
    let onResend: () -> Void

    @EnvironmentObject private var authSession: AuthSessionContext

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 12) {
                TribeAvatarView(
                    identity: TribeAvatarIdentity(displayName: invite.email),
                    size: .small,
                    accessToken: authSession.currentAccessToken
                )

                Text(invite.email)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer(minLength: 8)

                Text("Pending")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }

            HStack(alignment: .center, spacing: 10) {
                HStack(spacing: 6) {
                    RoleBadgeView(role: invite.normalizedAccessRole)
                    RoleBadgeView(model: .init(label: "Invited", style: .muted))
                    if let relationship = invite.relationship?.trimmingCharacters(in: .whitespacesAndNewlines), !relationship.isEmpty {
                        Text(relationship)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
                .lineLimit(1)

                Spacer(minLength: 8)

                if canManageMembers {
                    HStack(spacing: 8) {
                        Button(isResending ? "Resending..." : "Resend", action: onResend)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.indigo)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                            .padding(.horizontal, 11)
                            .padding(.vertical, 7)
                            .background(Color.indigo.opacity(0.10))
                            .clipShape(Capsule())
                            .disabled(isResending || isCancelling)
                        Button(isCancelling ? "Cancelling..." : "Cancel", action: onCancel)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.indigo)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                            .padding(.horizontal, 11)
                            .padding(.vertical, 7)
                            .background(Color.indigo.opacity(0.10))
                            .clipShape(Capsule())
                            .disabled(isCancelling || isResending)
                    }
                    .fixedSize(horizontal: true, vertical: false)
                    .layoutPriority(1)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(Color(uiColor: .systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 3)
    }
}

private struct RoleBadgeView: View {
    enum Role: String {
        case organiser
        case driver
        case observer
    }

    enum Style {
        case organiser
        case driver
        case observer
        case child
        case support
        case muted
    }

    struct Model {
        let label: String
        let style: Style

        init(role: Role) {
            switch role {
            case .organiser:
                self.label = "Organiser"
                self.style = .organiser
            case .driver:
                self.label = "Driver"
                self.style = .driver
            case .observer:
                self.label = "Observer"
                self.style = .observer
            }
        }

        init(label: String, style: Style) {
            self.label = label
            self.style = style
        }
    }

    let model: Model

    init(model: Model) {
        self.model = model
    }

    init(role: AccessRole) {
        switch role {
        case .organiser:
            self.model = Model(role: .organiser)
        case .driver:
            self.model = Model(role: .driver)
        case .observer:
            self.model = Model(role: .observer)
        }
    }

    var body: some View {
        Text(model.label)
            .font(.system(size: 12, weight: model.style == .organiser ? .bold : .semibold))
            .foregroundStyle(foreground)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(background)
            .clipShape(Capsule())
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
    }

    private var foreground: Color {
        switch model.style {
        case .organiser:
            return .white
        case .driver:
            return Color.blue.opacity(0.95)
        case .observer:
            return Color.gray.opacity(0.85)
        case .child:
            return Color.teal.opacity(0.95)
        case .support:
            return Color.purple.opacity(0.92)
        case .muted:
            return Color.orange.opacity(0.95)
        }
    }

    private var background: Color {
        switch model.style {
        case .organiser:
            return Color.indigo
        case .driver:
            return Color.blue.opacity(0.16)
        case .observer:
            return Color.gray.opacity(0.18)
        case .child:
            return Color.teal.opacity(0.14)
        case .support:
            return Color.purple.opacity(0.14)
        case .muted:
            return Color.orange.opacity(0.14)
        }
    }
}

private struct StatusDotView: View {
    enum State {
        case active
        case inactive
    }

    let state: State

    var body: some View {
        Circle()
            .fill(state == .active ? Color.green : Color.gray.opacity(0.42))
            .frame(width: 9, height: 9)
    }
}

struct FamilyAddMemberInviteFlowView: View {
    private enum Step: Int {
        case email
        case accessRole
        case relationship
        case confirm
    }

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authSession: AuthSessionContext
    @EnvironmentObject private var backendHouseholdContext: BackendHouseholdContext

    @State private var step: Step = .email
    @State private var email: String = ""
    @State private var accessRole: String = "observer"
    @State private var relationshipChoice: String = "Parent / Guardian"
    @State private var customRelationship: String = ""
    @State private var isSubmitting = false
    @State private var resultMessage: String?
    @State private var errorMessage: String?

    private let relationships = ["Parent / Guardian", "Aunt", "Uncle", "Granny", "Grandad", "Helper / Nanny", "Relative", "Custom"]

    var body: some View {
        NavigationStack {
            Form {
                switch step {
                case .email:
                    Section("Enter email") {
                        TextField("name@example.com", text: $email)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
                            .autocorrectionDisabled()
                    }
                case .accessRole:
                    Section("Choose access role") {
                        Picker("Access role", selection: $accessRole) {
                            Text("Organiser").tag("organiser")
                            Text("Driver").tag("driver")
                            Text("Observer").tag("observer")
                        }
                        .pickerStyle(.inline)
                    }
                case .relationship:
                    Section("Choose relationship") {
                        Picker("Relationship", selection: $relationshipChoice) {
                            ForEach(relationships, id: \.self) { choice in
                                Text(choice).tag(choice)
                            }
                        }
                        if relationshipChoice == "Custom" {
                            TextField("Custom relationship", text: $customRelationship)
                        }
                    }
                case .confirm:
                    Section("Confirm") {
                        Text("Email: \(email)")
                        Text("Access role: \(displayRole(accessRole))")
                        Text("Relationship: \(resolvedRelationshipLabel() ?? "Not set")")
                    }
                    if !backendHouseholdContext.canManageMembers {
                        Section {
                            Text("Only organisers can manage members.")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    Section {
                        Button(isSubmitting ? "Sending..." : "Submit") {
                            Task { await submit() }
                        }
                        .disabled(isSubmitting)
                    }
                }
            }
            .navigationTitle("Add member")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(step == .email ? "Close" : "Back") {
                        if step == .email {
                            dismiss()
                        } else if let previous = Step(rawValue: step.rawValue - 1) {
                            step = previous
                        }
                    }
                }
                if step != .confirm {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Next") {
                            if let next = Step(rawValue: step.rawValue + 1) {
                                step = next
                            }
                        }
                        .disabled(!canAdvance)
                    }
                }
            }
            .alert("Add member", isPresented: Binding(
                get: { resultMessage != nil },
                set: { if !$0 { resultMessage = nil } }
            )) {
                Button("OK") {
                    resultMessage = nil
                    dismiss()
                }
            } message: {
                Text(resultMessage ?? "")
            }
            .alert("Unable to add member", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private var canAdvance: Bool {
        switch step {
        case .email:
            return email.trimmingCharacters(in: .whitespacesAndNewlines).contains("@")
        case .accessRole:
            return true
        case .relationship:
            return relationshipChoice != "Custom" || !customRelationship.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .confirm:
            return false
        }
    }

    private func submit() async {
        guard backendHouseholdContext.canManageMembers else {
            errorMessage = "Only organisers can manage members."
            return
        }
        isSubmitting = true
        defer { isSubmitting = false }
        let inviterId = authSession.currentUserId.flatMap(UUID.init(uuidString:))
        let result = await backendHouseholdContext.createInviteOrPendingMembership(
            email: email,
            accessRole: accessRole,
            relationshipLabel: resolvedRelationshipLabel(),
            invitedByUserId: inviterId
        )
        if let result {
            switch result {
            case .existingMember(let membership):
                if membership.normalizedStatus == .pending {
                    resultMessage = "This member already has a pending request."
                } else {
                    resultMessage = "This member already exists in the household."
                }
            case .pendingMembershipCreated:
                resultMessage = "Member added immediately."
            case .inviteCreated:
                resultMessage = "Invite sent."
            case .existingPendingInvite:
                resultMessage = "An invite is already pending for this email."
            }
        } else {
            errorMessage = backendHouseholdContext.lastError ?? "Unable to add member."
        }
    }

    private func resolvedRelationshipLabel() -> String? {
        if relationshipChoice == "Custom" {
            return customRelationship.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        }
        return relationshipChoice
    }

    private func displayRole(_ role: String) -> String {
        switch role {
        case "organiser": return "Organiser"
        case "driver": return "Driver"
        default: return "Observer"
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
