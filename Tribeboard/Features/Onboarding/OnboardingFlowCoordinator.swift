import Foundation
import SwiftUI
import Combine

@MainActor
final class OnboardingFlowCoordinator: ObservableObject {
    @Published var route: OnboardingStepRoute = .welcome {
        didSet {
            persistDraft()
            logRouteAdvance(from: oldValue, to: route)
        }
    }
    @Published var pathChoice: OnboardingPathChoice?
    @Published var profileDraft = OnboardingProfileDraft(firstName: "", lastName: "", displayName: "")
    @Published var tribeDraft = TribeDraft(tribeName: "")
    @Published var homeLocation: ResolvedLocationDraft?
    @Published var homeLocationPhase: OnboardingHomeLocationPhase = .search
    @Published private(set) var householdId: UUID?
    @Published var joinCode: String = ""
    @Published var joinResultStatus: OnboardingJoinResultStatus?
    @Published var joinResultMessage: String = ""
    @Published var joinResultHouseholdName: String = ""
    @Published var children: [ChildDraft] = [ChildDraft()]
    @Published var activeChildId: UUID?
    @Published var supportPeople: [SupportPersonDraft] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var didBootstrap = false
    @Published private(set) var isBootstrapping = false
    @Published private(set) var hasEmailPendingInvite = false
    @Published private(set) var pendingEmailInvites: [PendingEmailInvitePresentation] = []
    @Published var selectedPendingInviteId: UUID?
    @Published private(set) var pendingEmailInviteContext: PendingEmailInvitePresentation?
    @Published private(set) var requiresInviteProfileCapture = true

    private let authService: AuthService
    private let householdService: HouseholdBackendService
    private let childService: ChildBackendService
    private let scheduleService: ScheduleBackendService
    private let profileService: ProfileBackendService
    private let householdLocationService: HouseholdLocationBackendService
    private let userDefaults: UserDefaults
    private let draftKey = "tb.onboarding.tribe.flow.v1"
    private var isRestoringDraft = false

    init(
        authService: AuthService? = nil,
        householdService: HouseholdBackendService? = nil,
        childService: ChildBackendService? = nil,
        scheduleService: ScheduleBackendService? = nil,
        profileService: ProfileBackendService? = nil,
        householdLocationService: HouseholdLocationBackendService? = nil,
        userDefaults: UserDefaults = .standard
    ) {
        self.authService = authService ?? SupabaseAuthService()
        self.householdService = householdService ?? SupabaseHouseholdBackendService()
        self.childService = childService ?? SupabaseChildBackendService()
        self.scheduleService = scheduleService ?? SupabaseScheduleBackendService()
        self.profileService = profileService ?? SupabaseProfileBackendService()
        self.householdLocationService = householdLocationService ?? SupabaseHouseholdLocationBackendService()
        self.userDefaults = userDefaults
    }

    func bootstrap() async {
        guard !didBootstrap else { return }
        didBootstrap = true
        isBootstrapping = true
        defer { isBootstrapping = false }
        if children.isEmpty {
            children = [ChildDraft()]
        }
        await resolveOnboardingRouteAfterAuth()
        if route == .welcome || route == .invitedAcceptance {
            restoreDraftPreservingInviteRoute()
        } else {
            restoreDraft()
        }
        if children.isEmpty {
            children = [ChildDraft()]
        }
        await loadExistingSetupData()
    }

    func acceptSelectedInvite(flow: AppFlowState) async {
        guard let session = try? await resolvedSession() else {
            errorMessage = "No active session. Please sign in again."
            return
        }
        guard let inviteId = selectedPendingInviteId ?? pendingEmailInvites.first?.inviteId else {
            errorMessage = "Select an invitation to accept."
            return
        }
        guard let invite = pendingEmailInvites.first(where: { $0.inviteId == inviteId }) else {
            errorMessage = "Invitation details are unavailable."
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            if let profileError = inviteAcceptProfileValidationError(inviteeEmail: invite.inviteeEmail) {
                errorMessage = profileError
                return
            }
            if requiresInviteProfileCapture {
                try await persistInviteAcceptanceProfile(session: session, inviteeEmail: invite.inviteeEmail)
#if DEBUG
                print("[InviteAccept] profile_saved=true")
#endif
            }
#if DEBUG
            print("[InviteAccept] invite_id=\(inviteId.uuidString)")
            print("[InviteAccept] household_id=\(invite.householdId.uuidString)")
#endif
            let response = try await householdService.acceptHouseholdInviteRPC(inviteId: inviteId, session: session)
            let outcome = response.outcome.lowercased()
            guard outcome == "joined" || outcome == "already_member" else {
                errorMessage = inviteAcceptFailureMessage(for: outcome)
                return
            }
            let activeHouseholdId = response.householdId ?? invite.householdId
            userDefaults.activeHouseholdId = activeHouseholdId
            PendingInvitePersistence.clear(reason: "onboarding_accept_invite")
            OnboardingInviteDismissalStore.clear()
            let memberships = try await householdService.fetchMyMemberships(session: session)
            let childCount = try await countChildren(for: memberships, session: session)
            flow.updateOnboardingSnapshot(
                membershipCount: memberships.count,
                childCount: childCount,
                onboardingComplete: true
            )
            clearDraft()
#if DEBUG
            print("[InviteAccept] membership_created=true")
            print("[InviteAccept] active_household_set=\(activeHouseholdId.uuidString)")
            print("[InviteAccept] route=mainApp")
#endif
            flow.completeOnboarding(startingTab: .home)
        } catch {
            errorMessage = SupabaseHouseholdBackendService.ServiceError.userFacingInviteJoinMessage(for: error)
#if DEBUG
            print("[InviteAccept] failed error=\(error.localizedDescription)")
#endif
        }
    }

    func declineInvitesForNow() {
        OnboardingInviteDismissalStore.dismissAll(pendingEmailInvites.map(\.inviteId))
        hasEmailPendingInvite = false
        pendingEmailInvites = []
        pendingEmailInviteContext = nil
        selectedPendingInviteId = nil
        route = .welcome
#if DEBUG
        print("[OnboardingRoute] route=genericWelcome (declined_invites)")
#endif
    }

    func selectPath(_ choice: OnboardingPathChoice) {
        if choice == .setup, hasEmailPendingInvite {
            route = .invitedAcceptance
            errorMessage = "You have a family invite waiting. Accept it first, or choose Decline / Not now."
            return
        }
        pathChoice = choice
#if DEBUG
        print("[Onboarding] onboarding_path_selected path=\(choice.rawValue)")
#endif
        switch choice {
        case .join:
            route = hasEmailPendingInvite ? .invitedAcceptance : .joinCode
        case .setup:
            route = .setupProfile
        }
    }

    func canContinue(route: OnboardingStepRoute) -> Bool {
        validationError(route: route) == nil
    }

    func validationError(route: OnboardingStepRoute) -> String? {
        switch route {
        case .welcome:
            return nil
        case .invitedAcceptance:
            if pendingEmailInvites.isEmpty {
                return "Invite details are still loading. Try again in a moment."
            }
            if let invite = pendingEmailInvites.first(where: { $0.inviteId == selectedPendingInviteId })
                ?? pendingEmailInvites.first {
                return inviteAcceptProfileValidationError(inviteeEmail: invite.inviteeEmail)
            }
            return nil
        case .joinCode:
            if hasEmailPendingInvite {
                return nil
            }
            return normalized(joinCode).isEmpty ? "Enter your invite code to continue." : nil
        case .joinProfile:
            let hasFirst = !normalized(profileDraft.firstName).isEmpty
            let hasLast = !normalized(profileDraft.lastName).isEmpty
            let hasDisplay = !normalized(profileDraft.displayName).isEmpty
            return (hasFirst || hasLast || hasDisplay) ? nil : "Enter at least one name field."
        case .setupProfile:
            if normalized(profileDraft.firstName).isEmpty {
                return "First name is required."
            }
            if normalized(profileDraft.lastName).isEmpty {
                return "Last name is required."
            }
            return nil
        case .setupTribe:
            return normalized(tribeDraft.tribeName).isEmpty ? "Enter your family name." : nil
        case .setupHome:
            guard let homeLocation,
                  homeLocation.latitude != nil,
                  homeLocation.longitude != nil else {
                return "Select a verified home location."
            }
            return homeLocationPhase == .confirm ? nil : "Confirm your home location."
        case .nextUp:
            return nil
        case .setupChildren:
            return children.isEmpty ? "Add at least one child to continue." : nil
        case .childSetupList:
            return children.contains(where: { !$0.completedSchoolStep || !$0.completedRoutineStep })
                ? "Complete school and routine setup for every child."
                : nil
        case .childSchool(let childId):
            guard let child = child(for: childId) else { return "Select a child to continue." }
            return child.completedSchoolStep ? nil : "Set a school and choose a verified school location."
        case .childRoutine(let childId):
            guard let child = child(for: childId) else { return "Select a child to continue." }
            guard child.completedRoutineStep else { return "Enable at least one routine day." }
            let invalidTime = child.routine.days.contains { day in
                guard day.isEnabled else { return false }
                let dropoffMinutes = (day.dropoffHour * 60) + day.dropoffMinute
                let pickupMinutes = (day.pickupHour * 60) + day.pickupMinute
                return pickupMinutes <= dropoffMinutes
            }
            return invalidTime ? "Pickup must be after drop-off." : nil
        case .childActivities(let childId):
            guard let child = child(for: childId) else { return "Select a child to continue." }
            let hasInvalidActivity = child.activities.contains { activity in
                if activity.atSchool { return false }
                return activity.location == nil
            }
            return hasInvalidActivity ? "Choose a verified location for each off-school activity." : nil
        case .supportPeople:
            let invalidInvite = supportPeople.contains { person in
                let email = normalized(person.email)
                if email.isEmpty || !isValidEmail(email) {
                    return true
                }
                if normalizeAccessRole(person.accessRole) == nil {
                    return true
                }
                return normalized(person.relationshipLabel).isEmpty
            }
            if invalidInvite {
                return "Each invite needs a valid email, access role, and relationship."
            }
            return nil
        case .review, .joinResult, .finishing:
            return nil
        }
    }

    func advance(flow: AppFlowState, store: TribeStore) async {
        errorMessage = nil
        if let error = validationError(route: route) {
            errorMessage = error
            return
        }
        switch route {
        case .welcome:
            errorMessage = "Choose your onboarding path first."
        case .invitedAcceptance:
            errorMessage = "Use Accept invite or Decline on this screen."
        case .joinCode:
            route = .joinProfile
        case .joinProfile:
            await executeJoin(flow: flow)
        case .joinResult:
            await finishJoin(flow: flow)
        case .setupProfile:
            await persistProfileStep()
        case .setupTribe:
            await persistHouseholdStep()
        case .setupHome:
            await persistHomeLocationStep(store: store)
        case .nextUp:
            await finishMinimalSetup(flow: flow, openAddChild: false)
        case .setupChildren:
            route = .childSetupList
        case .childSetupList:
            route = .supportPeople
        case .childSchool(let childId):
            activeChildId = childId
            route = .childRoutine(childId: childId)
        case .childRoutine(let childId):
            activeChildId = childId
            route = .childActivities(childId: childId)
        case .childActivities:
            route = .childSetupList
        case .supportPeople:
            route = .review
        case .review:
            await finishSetup(flow: flow, store: store)
        case .finishing:
            break
        }
    }

    func goBack() {
        errorMessage = nil
        switch route {
        case .welcome:
            break
        case .joinCode, .setupProfile:
            route = .welcome
        case .invitedAcceptance:
            route = .welcome
        case .joinProfile:
            route = hasEmailPendingInvite ? .invitedAcceptance : .joinCode
        case .joinResult:
            route = .joinProfile
        case .setupTribe:
            route = .setupProfile
        case .setupHome:
            if homeLocationPhase == .confirm {
                homeLocationPhase = .search
            } else {
                route = .setupTribe
            }
        case .nextUp:
            route = .setupHome
        case .setupChildren:
            route = .setupHome
        case .childSetupList:
            route = .setupChildren
        case .childSchool:
            route = .childSetupList
        case .childRoutine(let childId):
            route = .childSchool(childId: childId)
        case .childActivities(let childId):
            route = .childRoutine(childId: childId)
        case .supportPeople:
            route = .childSetupList
        case .review:
            route = .supportPeople
        case .finishing:
            break
        }
    }

    func setActiveChild(_ childId: UUID) {
        activeChildId = childId
        route = .childSchool(childId: childId)
    }

    func addChild() {
        children.append(ChildDraft())
    }

    func removeChild(_ childId: UUID) {
        children.removeAll { $0.id == childId }
        if children.isEmpty {
            children = [ChildDraft()]
        }
    }

    func updateChild(_ childId: UUID, mutate: (inout ChildDraft) -> Void) {
        guard let index = children.firstIndex(where: { $0.id == childId }) else { return }
        var child = children[index]
        mutate(&child)
        children[index] = child
#if DEBUG
        print("[Onboarding] partial_save_state child_id=\(childId.uuidString), school_id=\(child.schoolId?.uuidString ?? "nil"), activities=\(child.activities.count)")
#endif
        persistDraft()
    }

    func siblingSchoolOptions(for childId: UUID) -> [SchoolDraft] {
        var seen = Set<UUID>()
        return children
            .filter { $0.id != childId }
            .compactMap { candidate -> SchoolDraft? in
                guard let schoolId = candidate.schoolId else { return nil }
                guard candidate.school.location != nil else { return nil }
                guard !normalized(candidate.school.schoolName).isEmpty else { return nil }
                guard !seen.contains(schoolId) else { return nil }
                seen.insert(schoolId)
                return candidate.school
            }
    }

    func appendInvitedMemberCandidate() {
        supportPeople.append(
            SupportPersonDraft(
                accessRole: HouseholdAccessRole.observer.rawValue,
                relationshipLabel: "Parent / Guardian"
            )
        )
#if DEBUG
        print("[Onboarding] partial_save_state support_people_count=\(supportPeople.count)")
#endif
    }

    func removeSupportPerson(_ id: UUID) {
        supportPeople.removeAll { $0.id == id }
    }

    var progressLabel: String {
        let total = max(1, progressTotal)
        if let stepTitle = route.progressStepTitle {
            return "Step \(progressIndex) of \(total): \(stepTitle)"
        }
        return "Step \(progressIndex) of \(total)"
    }

    var progressIndex: Int {
        switch route {
        case .welcome: return 1
        case .invitedAcceptance: return 1
        case .joinCode: return hasEmailPendingInvite ? 2 : 2
        case .joinProfile: return hasEmailPendingInvite ? 2 : 3
        case .joinResult: return 4
        case .setupProfile: return 2
        case .setupTribe: return 3
        case .setupHome: return 4
        case .nextUp: return 5
        case .setupChildren: return 5
        case .childSetupList: return 6
        case .childSchool: return 7
        case .childRoutine: return 8
        case .childActivities: return 9
        case .supportPeople: return 10
        case .review: return 11
        case .finishing: return 5
        }
    }

    var progressTotal: Int {
        switch pathChoice {
        case .join:
            return hasEmailPendingInvite ? 3 : 4
        case .setup: return 5
        case .none: return 1
        }
    }

    var firstChildDisplayName: String? {
        children
            .map { normalized($0.displayName).nilIfEmpty ?? normalized($0.legalName).nilIfEmpty }
            .compactMap { $0 }
            .first
    }

    func finishMinimalSetup(flow: AppFlowState, openAddChild: Bool) async {
        guard let session = try? await resolvedSession() else {
            errorMessage = "No active session. Please sign in again."
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let memberships = try await householdService.fetchMyMemberships(session: session)
            let householdIds = Set(memberships.filter(\.isActiveMembership).map(\.householdId))
            var childCount = 0
            for householdId in householdIds {
                let rows = try await childService.fetchChildren(householdId: householdId, session: session)
                childCount += rows.count
            }
            flow.updateOnboardingSnapshot(
                membershipCount: memberships.count,
                childCount: childCount,
                onboardingComplete: true
            )
            clearDraft()
            flow.pendingPostOnboardingAddChild = openAddChild
            flow.completeOnboarding(startingTab: openAddChild ? .family : .home)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func executeJoin(flow: AppFlowState) async {
        guard let session = try? await resolvedSession() else {
            errorMessage = "No active session. Please sign in again."
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            try await persistProfile(session: session)
            let preferredHouseholdId = pendingEmailInviteContext?.householdId
            try await completeInvitedUserJoin(session: session)
            let memberships = try await householdService.fetchMyMemberships(session: session)
            let matchedMembership = memberships.first(where: { membership in
                if let preferredHouseholdId {
                    return membership.householdId == preferredHouseholdId
                }
                return true
            }) ?? memberships
                .sorted(by: { BackendTimestampParser.parse($0.createdAt) ?? .distantPast > BackendTimestampParser.parse($1.createdAt) ?? .distantPast })
                .first
            guard let matchedMembership else {
                throw SupabaseHouseholdBackendService.ServiceError.inviteConnectionFailed
            }
#if DEBUG
            print(
                "[Onboarding] invited_user_join membership_result household_id=\(matchedMembership.householdId.uuidString) " +
                "status=\(matchedMembership.status ?? "nil") access_role=\(matchedMembership.accessRole)"
            )
#endif
            userDefaults.activeHouseholdId = preferredHouseholdId ?? matchedMembership.householdId
            if hasEmailPendingInvite {
#if DEBUG
                print(
                    "[Onboarding] invited_user_join final_route=main_app " +
                    "active_household_id=\(userDefaults.activeHouseholdId?.uuidString ?? "nil")"
                )
#endif
                await finishJoin(flow: flow)
                return
            }
#if DEBUG
            print("[Onboarding] invited_user_join routing_destination=joinResult")
#endif
            let status = (matchedMembership.status ?? "pending").lowercased()
            joinResultStatus = status == "active" ? .active : .pending
            let households = try await householdService.fetchMyHouseholds(session: session)
            joinResultHouseholdName = households.first(where: { $0.id == matchedMembership.householdId })?.name ?? "Tribe"
            joinResultMessage = joinResultStatus == .active
                ? "You are in. Your tribe is ready."
                : "Your join request is pending admin approval."
            route = .joinResult
        } catch {
            errorMessage = SupabaseHouseholdBackendService.ServiceError.userFacingInviteJoinMessage(for: error)
#if DEBUG
            print("[Onboarding] invited_user_join failed error=\(error.localizedDescription)")
#endif
        }
    }

    /// Email invite first, then stored deep-link invite, then manual join code (H-XXXXXXXX or invite code).
    private func completeInvitedUserJoin(session: AuthUserSession) async throws {
#if DEBUG
        print("[Onboarding] invited_user_join start email=\(session.email ?? "nil")")
#endif
        let pendingInvites = try await householdService.fetchPendingInvitesForSignedInUser(session: session)
#if DEBUG
        print("[Onboarding] invited_user_join pending_invite_count=\(pendingInvites.count)")
        if let selected = pendingInvites.first {
            print(
                "[Onboarding] invited_user_join selected_invite_id=\(selected.id.uuidString) " +
                "household_id=\(selected.householdId.uuidString)"
            )
        }
#endif
        if !pendingInvites.isEmpty {
            try await householdService.acceptPendingInvitesForSignedInUser(session: session)
            var memberships = try await householdService.fetchMyMemberships(session: session)
            if !memberships.isEmpty {
#if DEBUG
                print("[Onboarding] invited_user_join membership_via=email_pending_invites count=\(memberships.count)")
#endif
                return
            }
        }

        if let snap = PendingInvitePersistence.load() {
            let response: HouseholdInviteAcceptRPCResponse?
            if let inviteId = snap.inviteId {
                response = try await householdService.acceptHouseholdInviteRPC(inviteId: inviteId, session: session)
            } else if snap.prefersToken, let token = snap.inviteToken, !token.isEmpty {
                response = try await householdService.acceptHouseholdInviteRPC(inviteToken: token, session: session)
            } else if let code = snap.inviteCode, !normalized(code).isEmpty {
                response = try await householdService.acceptHouseholdInviteRPC(inviteCode: code, session: session)
            } else {
                response = nil
            }
            if let response {
#if DEBUG
                print(
                    "[Onboarding] invited_user_join stored_invite outcome=\(response.outcome) " +
                    "household_id=\(response.householdId?.uuidString ?? "nil")"
                )
#endif
                switch response.outcome.lowercased() {
                case "joined", "already_member":
                    PendingInvitePersistence.clear(reason: "onboarding_join_success")
                    let memberships = try await householdService.fetchMyMemberships(session: session)
                    if !memberships.isEmpty {
#if DEBUG
                        print("[Onboarding] invited_user_join membership_via=stored_invite")
#endif
                        return
                    }
                default:
                    break
                }
            }
        }

        let manualCode = normalized(joinCode)
        guard !manualCode.isEmpty else {
            let memberships = try await householdService.fetchMyMemberships(session: session)
            if memberships.isEmpty {
                throw SupabaseHouseholdBackendService.ServiceError.inviteConnectionFailed
            }
            return
        }

#if DEBUG
        print("[Onboarding] invited_user_join fallback_manual_code=\(manualCode)")
#endif
        _ = try await householdService.joinHouseholdByCode(manualCode, session: session)
    }

    private func resolveOnboardingRouteAfterAuth() async {
        guard let session = try? await resolvedSession() else { return }
        let authEmail = session.email ?? "nil"
#if DEBUG
        print("[OnboardingRoute] auth_email=\(authEmail)")
        print("[OnboardingRoute] checking_pending_invites=true")
#endif
        do {
            let pendingRows = try await householdService.fetchPendingInvitesForSignedInUser(session: session)
            let dismissed = OnboardingInviteDismissalStore.dismissedIds()
            let pending = pendingRows.filter { !dismissed.contains($0.id) }
            var presentations: [PendingEmailInvitePresentation] = []
            for invite in pending {
                presentations.append(
                    await buildPendingInvitePresentation(
                        from: invite,
                        pendingCount: pending.count,
                        session: session
                    )
                )
            }
            pendingEmailInvites = presentations
            hasEmailPendingInvite = !presentations.isEmpty
            pendingEmailInviteContext = presentations.first
            selectedPendingInviteId = presentations.first?.inviteId

#if DEBUG
            print("[OnboardingRoute] pending_invite_count=\(presentations.count)")
#endif

            await refreshInviteProfileCaptureState(session: session)

            if hasEmailPendingInvite {
                pathChoice = .join
                if let primary = pending.first,
                   let code = primary.inviteCode?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .uppercased(),
                   !code.isEmpty,
                   normalized(joinCode).isEmpty {
                    joinCode = code
                }
                route = .invitedAcceptance
#if DEBUG
                print("[OnboardingRoute] route=invitedAcceptance")
#endif
                return
            }

            pendingEmailInvites = []
            pendingEmailInviteContext = nil
            route = .welcome
#if DEBUG
            print("[OnboardingRoute] route=genericWelcome")
#endif
        } catch {
            pendingEmailInvites = []
            pendingEmailInviteContext = nil
            hasEmailPendingInvite = false
            route = .welcome
#if DEBUG
            print("[OnboardingRoute] route=genericWelcome (invite_check_failed)")
            print("[OnboardingRoute] error=\(error.localizedDescription)")
#endif
        }
    }

    private func restoreDraftPreservingInviteRoute() {
        guard route != .invitedAcceptance else { return }
        restoreDraft()
    }

    private func countChildren(
        for memberships: [BackendHouseholdMembership],
        session: AuthUserSession
    ) async throws -> Int {
        var allChildIds = Set<UUID>()
        for membership in memberships {
            let rows = try await childService.fetchChildren(householdId: membership.householdId, session: session)
            allChildIds.formUnion(rows.map(\.id))
        }
        return allChildIds.count
    }

    private func inviteAcceptFailureMessage(for outcome: String) -> String {
        switch outcome.lowercased() {
        case "invalid_code":
            return "This invite is no longer valid. Ask your organiser to resend it."
        case "expired":
            return "This invite has expired. Ask your organiser to send a new one."
        case "cancelled":
            return "This invite was cancelled."
        case "declined":
            return "This invite was declined."
        case "already_used":
            return "This invite was already used."
        default:
            return "We couldn't accept this invite. Try again or contact your organiser."
        }
    }

    private func buildPendingInvitePresentation(
        from invite: BackendHouseholdInvite,
        pendingCount: Int,
        session: AuthUserSession
    ) async -> PendingEmailInvitePresentation {
        var householdName = "your family"
        if let preview = try? await householdService.fetchInvitePreviewByInviteId(invite.id, session: session) {
            householdName = preview.householdName
        } else if let token = invite.inviteToken?.trimmingCharacters(in: .whitespacesAndNewlines),
           !token.isEmpty,
           let preview = try? await householdService.fetchInvitePreviewByToken(token, session: session) {
            householdName = preview.householdName
        } else if let code = invite.inviteCode?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !code.isEmpty,
                  let preview = try? await householdService.fetchInvitePreviewByCode(code, session: session) {
            householdName = preview.householdName
        }
        let inviteeEmail = invite.email.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            ?? session.email?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? ""
        return PendingEmailInvitePresentation(
            inviteId: invite.id,
            householdId: invite.householdId,
            householdName: householdName,
            inviteeEmail: inviteeEmail,
            accessRole: invite.accessRole,
            relationship: invite.relationship,
            pendingInviteCount: pendingCount
        )
    }

    var canAcceptSelectedInvite: Bool {
        guard selectedPendingInviteId != nil || pendingEmailInvites.first != nil else { return false }
        guard !isLoading else { return false }
        if let invite = pendingEmailInvites.first(where: { $0.inviteId == selectedPendingInviteId })
            ?? pendingEmailInvites.first {
            return inviteAcceptProfileValidationError(inviteeEmail: invite.inviteeEmail) == nil
        }
        return false
    }

    private func refreshInviteProfileCaptureState(session: AuthUserSession) async {
        let profile = try? await profileService.fetchMyProfile()
        profileDraft = OnboardingInviteProfileSupport.prefillDraft(from: profile)
        requiresInviteProfileCapture = OnboardingInviteProfileSupport.needsProfileCapture(
            profile: profile,
            email: session.email
        )
#if DEBUG
        print("[OnboardingRoute] requires_invite_profile_capture=\(requiresInviteProfileCapture)")
#endif
    }

    private func inviteAcceptProfileValidationError(inviteeEmail: String) -> String? {
        OnboardingInviteProfileSupport.validationError(
            firstName: profileDraft.firstName,
            lastName: profileDraft.lastName,
            displayName: profileDraft.displayName,
            email: inviteeEmail.nilIfEmpty ?? nil,
            requiresProfileFields: requiresInviteProfileCapture
        )
    }

    private func persistInviteAcceptanceProfile(session: AuthUserSession, inviteeEmail: String) async throws {
        let first = normalized(profileDraft.firstName)
        guard !first.isEmpty else {
            throw NSError(
                domain: "OnboardingFlowCoordinator",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Enter your first name to accept this invite."]
            )
        }
        let display = OnboardingInviteProfileSupport.resolvedDisplayName(
            firstName: profileDraft.firstName,
            displayName: profileDraft.displayName
        )
        guard !display.isEmpty else {
            throw NSError(
                domain: "OnboardingFlowCoordinator",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Enter how your name should appear in the tribe."]
            )
        }
        if OnboardingInviteProfileSupport.isDisplayNameOnlyEmail(display, email: inviteeEmail.nilIfEmpty ?? session.email) {
            throw NSError(
                domain: "OnboardingFlowCoordinator",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "Use a name instead of your email address."]
            )
        }
        let last = normalized(profileDraft.lastName).nilIfEmpty
        try await profileService.upsertMyProfile(
            email: session.email,
            displayName: display,
            firstName: first,
            lastName: last,
            avatarURL: nil
        )
        profileDraft.displayName = display
        requiresInviteProfileCapture = false
    }

    private func finishJoin(flow: AppFlowState) async {
        guard let session = try? await resolvedSession() else {
            errorMessage = "No active session. Please sign in again."
            return
        }
        do {
            let memberships = try await householdService.fetchMyMemberships(session: session)
            let householdIds = Set(memberships.map(\.householdId))
            var allChildren = Set<UUID>()
            for householdId in householdIds {
                let rows = try await childService.fetchChildren(householdId: householdId, session: session)
                allChildren.formUnion(rows.map(\.id))
            }
            flow.updateOnboardingSnapshot(
                membershipCount: memberships.count,
                childCount: allChildren.count,
                onboardingComplete: !memberships.isEmpty
            )
            clearDraft()
            flow.completeOnboarding(startingTab: .calendar)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func finishSetup(flow: AppFlowState, store: TribeStore) async {
        guard let session = try? await resolvedSession() else {
            errorMessage = "No active session. Please sign in again."
            return
        }
#if DEBUG
        print("[Onboarding] onboarding_finish_started")
#endif
        await resolveOnboardingRouteAfterAuth()
        if hasEmailPendingInvite {
            errorMessage = "You were invited to an existing family. Accept that invite before creating a new tribe."
            pathChoice = .join
            route = .invitedAcceptance
            return
        }
        route = .finishing
        isLoading = true
        defer { isLoading = false }

        do {
            // 1) profile upsert/patch
            try await persistProfile(session: session)

            // 2) create tribe/household
            let createdHousehold = try await householdService.createHousehold(
                name: normalized(tribeDraft.tribeName),
                session: session
            )
            userDefaults.activeHouseholdId = createdHousehold.id

            // 3) persist home location
            if let homeLocation {
                let home = TribeLocation(
                    name: homeLocation.title,
                    address: homeLocation.address,
                    type: .home,
                    tribeId: createdHousehold.id,
                    notes: coordinateNotes(for: homeLocation)
                )
                store.addOrUpdateLocation(home, setAsHome: true)
            }

            // 4) create children + 5) school data + 6) routines + 7) activities
            for childDraft in children {
                let createdChild = try await childService.createChild(
                    BackendChild(
                        id: UUID(),
                        householdId: createdHousehold.id,
                        legalName: normalizedLegalName(for: childDraft),
                        displayName: normalized(childDraft.displayName).nilIfEmpty,
                        dateOfBirth: formatDateOnly(childDraft.dateOfBirth),
                        schoolName: normalized(childDraft.school.schoolName).nilIfEmpty,
                        gradeOrClass: normalized(childDraft.gradeOrClass).nilIfEmpty,
                        createdAt: nil,
                        updatedAt: nil
                    ),
                    session: session
                )

#if DEBUG
                print("[Onboarding] onboarding_child_saved child_id=\(createdChild.id.uuidString)")
#endif
                if let schoolLocation = childDraft.school.location {
#if DEBUG
                    print("[Onboarding] onboarding_school_selected child_id=\(createdChild.id.uuidString), school=\(schoolLocation.title)")
#endif
                }

                for day in childDraft.routine.days where day.isEnabled {
                    let weekday = backendWeekday(day.weekday)
                    let dropoffTemplate = BackendScheduleTemplate(
                        id: UUID(),
                        householdId: createdHousehold.id,
                        childId: createdChild.id,
                        title: "\(createdChild.displayName ?? createdChild.legalName) School Drop-off",
                        weekday: weekday,
                        departureTime: String(format: "%02d:%02d:00", day.dropoffHour, day.dropoffMinute),
                        createdAt: nil
                    )
                    let pickupTemplate = BackendScheduleTemplate(
                        id: UUID(),
                        householdId: createdHousehold.id,
                        childId: createdChild.id,
                        title: "\(createdChild.displayName ?? createdChild.legalName) School Pickup",
                        weekday: weekday,
                        departureTime: String(format: "%02d:%02d:00", day.pickupHour, day.pickupMinute),
                        createdAt: nil
                    )
                    let createdDropoff = try await scheduleService.createSchedule(dropoffTemplate)
                    let createdPickup = try await scheduleService.createSchedule(pickupTemplate)

                    let homeLat = homeLocation?.latitude ?? 0
                    let homeLon = homeLocation?.longitude ?? 0
                    let schoolLat = childDraft.school.location?.latitude ?? 0
                    let schoolLon = childDraft.school.location?.longitude ?? 0
                    _ = try await scheduleService.replaceScheduleStops(
                        scheduleId: createdDropoff.id,
                        stops: [
                            BackendScheduleStop(id: UUID(), scheduleId: createdDropoff.id, childId: createdChild.id, label: "Home", latitude: homeLat, longitude: homeLon, stopOrder: 0),
                            BackendScheduleStop(
                                id: UUID(),
                                scheduleId: createdDropoff.id,
                                childId: createdChild.id,
                                label: normalized(childDraft.school.schoolName).nilIfEmpty ?? "School",
                                latitude: schoolLat,
                                longitude: schoolLon,
                                stopOrder: 1
                            )
                        ]
                    )
                    _ = try await scheduleService.replaceScheduleStops(
                        scheduleId: createdPickup.id,
                        stops: [
                            BackendScheduleStop(
                                id: UUID(),
                                scheduleId: createdPickup.id,
                                childId: createdChild.id,
                                label: normalized(childDraft.school.schoolName).nilIfEmpty ?? "School",
                                latitude: schoolLat,
                                longitude: schoolLon,
                                stopOrder: 0
                            ),
                            BackendScheduleStop(id: UUID(), scheduleId: createdPickup.id, childId: createdChild.id, label: "Home", latitude: homeLat, longitude: homeLon, stopOrder: 1)
                        ]
                    )
                }

                for activity in childDraft.activities {
                    let weekday = activity.weekday.rawValue
                    let timeComponents = DateComponents(hour: activity.hour, minute: activity.minute)
                    _ = try await childService.createChildActivity(
                        BackendChildActivity(
                            id: UUID(),
                            childId: createdChild.id,
                            householdId: createdHousehold.id,
                            name: normalized(activity.title),
                            type: activity.atSchool ? ChildActivityType.schoolBased.rawValue : ChildActivityType.external.rawValue,
                            locationName: activity.atSchool ? normalized(childDraft.school.schoolName).nilIfEmpty : normalized(activity.location?.title ?? "").nilIfEmpty,
                            days: [weekday],
                            startTime: formatTime(timeComponents),
                            endTime: nil,
                            createdAt: nil,
                            updatedAt: nil
                        ),
                        session: session
                    )
                }
            }

            // 8) support people
            for person in supportPeople {
                let email = normalized(person.email)
                guard !email.isEmpty else { continue }
                let accessRole = normalizeAccessRole(person.accessRole) ?? HouseholdAccessRole.observer.rawValue
                _ = try await householdService.createInviteOrPendingMembership(
                    householdId: createdHousehold.id,
                    email: email,
                    accessRole: accessRole,
                    relationshipLabel: normalized(person.relationshipLabel).nilIfEmpty,
                    invitedByUserId: session.userUUID,
                    session: session
                )
#if DEBUG
                print(
                    "[Onboarding] support_person invite_member persisted " +
                    "email=\(email), access_role=\(accessRole), relationship=\(normalized(person.relationshipLabel).nilIfEmpty ?? "nil")"
                )
#endif
                do {
                    try await sendInvite(email: email, tribeId: createdHousehold.id)
#if DEBUG
                    print("[Onboarding] invite_sent_success email=\(email)")
#endif
                } catch {
#if DEBUG
                    print("[Onboarding] invite_sent_failed email=\(email), error=\(error.localizedDescription)")
#endif
                }
            }

            let memberships = try await householdService.fetchMyMemberships(session: session)
            let backendChildren = try await childService.fetchChildren(householdId: createdHousehold.id, session: session)
#if DEBUG
            let payloadChildren = children.map { child in
                "\(child.displayName.isEmpty ? "unnamed" : child.displayName):school_id=\(child.schoolId?.uuidString ?? "nil"):activities=\(child.activities.count)"
            }.joined(separator: ",")
            print(
                "[Onboarding] onboarding_completion_payload tribe_id=\(createdHousehold.id.uuidString), " +
                "children=[\(payloadChildren)], support_people=\(supportPeople.count)"
            )
            print("[Onboarding] post_finish_refresh_pipeline_started")
#endif
            flow.updateOnboardingSnapshot(
                membershipCount: memberships.count,
                childCount: backendChildren.count,
                onboardingComplete: !memberships.isEmpty && !backendChildren.isEmpty
            )
            await MainActor.run {
                flow.updateOnboardingSnapshot(onboardingComplete: true)
            }
#if DEBUG
            print(
                "[Onboarding] post_finish_refresh_pipeline_succeeded memberships=\(memberships.count), " +
                "children=\(backendChildren.count)"
            )
#endif
            clearDraft()
#if DEBUG
            print("[Onboarding] onboarding_finish_succeeded")
#endif
            await MainActor.run {
                flow.completeOnboarding(startingTab: .calendar)
#if DEBUG
                print("[Onboarding] UI transition trigger onboardingComplete=\(flow.isOnboarded)")
#endif
            }
        } catch {
            errorMessage = error.localizedDescription
            route = .review
#if DEBUG
            print("[Onboarding] onboarding_finish_failed error=\(error.localizedDescription)")
#endif
        }
    }

    private func loadExistingSetupData() async {
        guard pathChoice == .setup || [.setupProfile, .setupTribe, .setupHome, .nextUp].contains(route) else {
            return
        }
        guard let session = try? await resolvedSession() else { return }
        do {
            if let profile = try await profileService.fetchMyProfile() {
                profileDraft = OnboardingInviteProfileSupport.prefillDraft(from: profile)
            }
            let households = try await householdService.fetchMyHouseholds(session: session)
            let preferredId = userDefaults.activeHouseholdId ?? households.first?.id
            if let preferredId,
               let household = households.first(where: { $0.id == preferredId }) ?? households.first {
                householdId = household.id
                tribeDraft.tribeName = household.name
                userDefaults.activeHouseholdId = household.id
                if let savedHome = try await householdLocationService.fetchHomeLocation(
                    householdId: household.id,
                    session: session
                ) {
                    homeLocation = ResolvedLocationDraft(
                        title: "Home",
                        address: savedHome.formattedAddress,
                        latitude: savedHome.latitude,
                        longitude: savedHome.longitude,
                        placeId: savedHome.placeId
                    )
                    homeLocationPhase = .confirm
                }
            }
        } catch {
#if DEBUG
            print("[Onboarding] loadExistingSetupData failed error=\(error.localizedDescription)")
#endif
        }
    }

    private func persistProfileStep() async {
        guard let session = try? await resolvedSession() else {
            errorMessage = "No active session. Please sign in again."
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            try await persistProfile(session: session)
            route = .setupTribe
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func persistHouseholdStep() async {
        guard let session = try? await resolvedSession() else {
            errorMessage = "No active session. Please sign in again."
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let name = normalized(tribeDraft.tribeName)
            if let existingId = householdId {
                _ = try await householdService.updateHouseholdName(
                    householdId: existingId,
                    name: name,
                    session: session
                )
            } else {
                let memberships = try await householdService.fetchMyMemberships(session: session)
                if let active = memberships.first(where: \.isActiveMembership) {
                    householdId = active.householdId
                    userDefaults.activeHouseholdId = active.householdId
                    _ = try await householdService.updateHouseholdName(
                        householdId: active.householdId,
                        name: name,
                        session: session
                    )
                } else {
                    let created = try await householdService.createHousehold(name: name, session: session)
                    householdId = created.id
                    userDefaults.activeHouseholdId = created.id
                }
            }
            route = .setupHome
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func persistHomeLocationStep(store: TribeStore) async {
        guard let session = try? await resolvedSession() else {
            errorMessage = "No active session. Please sign in again."
            return
        }
        guard let homeLocation,
              let latitude = homeLocation.latitude,
              let longitude = homeLocation.longitude else {
            errorMessage = "Select a verified home location."
            return
        }
        guard let householdId else {
            errorMessage = "Create your family before saving home."
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            _ = try await householdLocationService.upsertHomeLocation(
                householdId: householdId,
                location: homeLocation,
                isVerified: true,
                session: session
            )
            let home = TribeLocation(
                name: homeLocation.title,
                address: homeLocation.address,
                type: .home,
                tribeId: householdId,
                notes: coordinateNotes(for: homeLocation)
            )
            store.addOrUpdateLocation(home, setAsHome: true)
            route = .nextUp
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func persistProfile(session: AuthUserSession) async throws {
        let first = normalized(profileDraft.firstName)
        let last = normalized(profileDraft.lastName)
        guard !first.isEmpty, !last.isEmpty else {
            throw NSError(domain: "OnboardingFlowCoordinator", code: 422, userInfo: [
                NSLocalizedDescriptionKey: "First and last name are required."
            ])
        }
        var display = normalized(profileDraft.displayName).nilIfEmpty
        if display == nil {
            display = "\(first) \(last)"
            profileDraft.displayName = display ?? ""
        }
        try await profileService.upsertMyProfile(
            email: session.email,
            displayName: display,
            firstName: first,
            lastName: last,
            avatarURL: profileDraft.avatarURL
        )
        try await profileService.patchMyProfile(fields: [
            "avatar_type": profileDraft.avatarType.rawValue,
            "avatar_key": profileDraft.avatarKey,
            "avatar_url": profileDraft.avatarURL,
            "display_name": display
        ])
    }

    private func resolvedSession() async throws -> AuthUserSession {
        guard let session = try await authService.restoreSession() else {
            throw NSError(domain: "OnboardingFlowCoordinator", code: 401, userInfo: [
                NSLocalizedDescriptionKey: "No active session."
            ])
        }
        return session
    }

    private func child(for childId: UUID) -> ChildDraft? {
        children.first(where: { $0.id == childId })
    }

    private func normalizedLegalName(for child: ChildDraft) -> String {
        let legal = normalized(child.legalName)
        if !legal.isEmpty { return legal }
        return normalized(child.displayName)
    }

    private func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func normalizeAccessRole(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard let accessRole = HouseholdAccessRole(rawValue: value) else { return nil }
        return accessRole.rawValue
    }

    private func backendWeekday(_ day: Weekday) -> String {
        switch day {
        case .monday: return "monday"
        case .tuesday: return "tuesday"
        case .wednesday: return "wednesday"
        case .thursday: return "thursday"
        case .friday: return "friday"
        case .saturday: return "saturday"
        case .sunday: return "sunday"
        }
    }

    private func formatDateOnly(_ date: Date?) -> String? {
        guard let date else { return nil }
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func formatTime(_ components: DateComponents?) -> String? {
        guard let components,
              let hour = components.hour,
              let minute = components.minute else { return nil }
        return String(format: "%02d:%02d", hour, minute)
    }

    private func isValidEmail(_ email: String) -> Bool {
        let regex = #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return email.range(of: regex, options: .regularExpression) != nil
    }

    private func sendInvite(email: String, tribeId: UUID) async throws {
        // Stubbed invite dispatch for onboarding. Failures are logged but never block completion.
#if DEBUG
        print("[Onboarding] invite_dispatch_stub email=\(email), tribe_id=\(tribeId.uuidString)")
#endif
    }

    private func coordinateNotes(for location: ResolvedLocationDraft) -> String? {
        guard let lat = location.latitude, let lon = location.longitude else { return nil }
        return "lat=\(lat),lon=\(lon)"
    }

    private func logRouteAdvance(from oldRoute: OnboardingStepRoute, to newRoute: OnboardingStepRoute) {
        guard oldRoute != newRoute else { return }
#if DEBUG
        print("[Onboarding] onboarding_step_advanced from=\(oldRoute.title) to=\(newRoute.title)")
#endif
    }

    private func persistDraft() {
        guard !isRestoringDraft else { return }
        let snapshot = OnboardingFlowSnapshot(
            route: route,
            pathChoice: pathChoice,
            profileDraft: profileDraft,
            tribeDraft: tribeDraft,
            homeLocation: homeLocation,
            homeLocationPhase: homeLocationPhase,
            householdId: householdId,
            joinCode: joinCode,
            joinResultStatus: joinResultStatus,
            joinResultMessage: joinResultMessage,
            joinResultHouseholdName: joinResultHouseholdName,
            children: children,
            activeChildId: activeChildId,
            supportPeople: supportPeople
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(snapshot) else { return }
        userDefaults.set(data, forKey: draftKey)
    }

    private func restoreDraft() {
        guard let data = userDefaults.data(forKey: draftKey) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let snapshot = try? decoder.decode(OnboardingFlowSnapshot.self, from: data) else { return }
        isRestoringDraft = true
        route = snapshot.route
        pathChoice = snapshot.pathChoice
        profileDraft = snapshot.profileDraft
        tribeDraft = snapshot.tribeDraft
        homeLocation = snapshot.homeLocation
        homeLocationPhase = snapshot.homeLocationPhase ?? .search
        householdId = snapshot.householdId
        joinCode = snapshot.joinCode
        joinResultStatus = snapshot.joinResultStatus
        joinResultMessage = snapshot.joinResultMessage
        joinResultHouseholdName = snapshot.joinResultHouseholdName
        children = snapshot.children
        activeChildId = snapshot.activeChildId
        supportPeople = snapshot.supportPeople
        isRestoringDraft = false
    }

    private func clearDraft() {
        userDefaults.removeObject(forKey: draftKey)
    }
}

private struct OnboardingFlowSnapshot: Codable {
    let route: OnboardingStepRoute
    let pathChoice: OnboardingPathChoice?
    let profileDraft: OnboardingProfileDraft
    let tribeDraft: TribeDraft
    let homeLocation: ResolvedLocationDraft?
    let homeLocationPhase: OnboardingHomeLocationPhase?
    let householdId: UUID?
    let joinCode: String
    let joinResultStatus: OnboardingJoinResultStatus?
    let joinResultMessage: String
    let joinResultHouseholdName: String
    let children: [ChildDraft]
    let activeChildId: UUID?
    let supportPeople: [SupportPersonDraft]
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
