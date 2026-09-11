import Foundation
import Combine

@MainActor
final class BackendHouseholdContext: ObservableObject {
    @Published private(set) var households: [BackendHousehold] = []
    @Published private(set) var memberships: [BackendHouseholdMembership] = []
    @Published private(set) var activeHouseholdMembers: [BackendHouseholdMembership] = []
    @Published private(set) var activeHouseholdProfilesByUserId: [UUID: BackendProfile] = [:]
    @Published private(set) var activeHouseholdInvites: [BackendHouseholdInvite] = []
    @Published private(set) var activeHouseholdId: UUID?
    @Published private(set) var isLoading: Bool = false
    @Published var lastError: String?
    /// User-facing errors from create/join/switch household operations only.
    @Published var householdAlertError: String?

    private let service: HouseholdBackendService
    private let profileService: ProfileBackendService
    private let authService: AuthService
    private let localHouseholdContext: ActiveHouseholdContext
    private let localHouseholdDataSource: HouseholdDataSource
    private let activeHouseholdStore: ActiveHouseholdStore?
    private let userDefaults: UserDefaults
    private var currentSession: AuthUserSession?
    private var isRealtimeRefreshInFlight = false
    private var hasPendingRealtimeRefresh = false
    private var realtimeDebounceTask: Task<Void, Never>?

    init(
        service: HouseholdBackendService? = nil,
        profileService: ProfileBackendService? = nil,
        authService: AuthService? = nil,
        localHouseholdContext: ActiveHouseholdContext,
        localHouseholdDataSource: HouseholdDataSource,
        activeHouseholdStore: ActiveHouseholdStore? = nil,
        userDefaults: UserDefaults = .standard
    ) {
        self.service = service ?? SupabaseHouseholdBackendService()
        self.profileService = profileService ?? SupabaseProfileBackendService()
        self.authService = authService ?? SupabaseAuthService()
        self.localHouseholdContext = localHouseholdContext
        self.localHouseholdDataSource = localHouseholdDataSource
        self.activeHouseholdStore = activeHouseholdStore
        self.userDefaults = userDefaults
        self.activeHouseholdId = userDefaults.activeHouseholdId
        self.activeHouseholdStore?.setActiveHousehold(id: userDefaults.activeHouseholdId)
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        do {
            guard let session = try await authService.restoreSession() else {
                households = []
                memberships = []
                activeHouseholdMembers = []
                activeHouseholdInvites = []
                activeHouseholdId = nil
                activeHouseholdStore?.clear()
                userDefaults.activeHouseholdId = nil
                lastError = "No active auth session."
                return
            }
            currentSession = session
            try await service.acceptPendingInvitesForSignedInUser(session: session)
#if DEBUG
            print("[BackendHouseholdContext] accepted pending invites for session user_id=\(session.userId)")
#endif
            let loadedMemberships = try await service.fetchMyMemberships(session: session)
            memberships = loadedMemberships
#if DEBUG
            let before = activeHouseholdId?.uuidString ?? "nil"
            print(
                "[BackendHouseholdContext] auth.uid=\(session.userId), memberships.count=\(memberships.count), " +
                "activeHouseholdId.before=\(before)"
            )
#endif
            let loadedHouseholds = try await service.fetchMyHouseholds(session: session)
            households = loadedHouseholds
            restoreOrAutoSelectActiveHousehold()
#if DEBUG
            let after = activeHouseholdId?.uuidString ?? "nil"
            print(
                "[BackendHouseholdContext] auth.uid=\(session.userId), households.count=\(households.count), " +
                "activeHouseholdId.after=\(after)"
            )
#endif
            if let activeHouseholdId, hasActiveMembership {
                async let membersTask = service.fetchHouseholdMembers(householdId: activeHouseholdId, session: session)
                async let invitesTask = service.fetchInvites(householdId: activeHouseholdId, session: session)
                let (members, invites) = try await (membersTask, invitesTask)
                activeHouseholdMembers = members
#if DEBUG
                let memberUserIds = members.map { $0.userId.uuidString }.joined(separator: ",")
                print(
                    "[BackendHouseholdContext] activeHouseholdId=\(activeHouseholdId.uuidString), " +
                    "fetched_membership_count=\(members.count), fetched_membership_user_ids=[\(memberUserIds)]"
                )
#endif
                activeHouseholdProfilesByUserId = await loadProfilesByUserId(for: members.map(\.userId))
                activeHouseholdInvites = invites
            } else {
                clearHouseholdScopedState()
            }
#if DEBUG
            print("[AccessGuard] active_membership_count=\(activeMemberships.count)")
            print("[AccessGuard] active_household_id=\(activeHouseholdId?.uuidString ?? "nil")")
#endif
            clearTransientErrors()
        } catch {
            recordBackgroundRefreshError(error, operation: "refresh")
        }
    }

    func createHousehold(name: String) async {
        isLoading = true
        defer { isLoading = false }
        householdAlertError = nil
        do {
            guard let session = try await ensuredSession() else {
                presentHouseholdAlert("No active auth session.", logPrefix: "HouseholdCreate")
                return
            }
            let createdHousehold = try await service.createHousehold(name: name, session: session)
#if DEBUG
            print("[HouseholdCreate] success household_id=\(createdHousehold.id.uuidString)")
#endif
            if !households.contains(where: { $0.id == createdHousehold.id }) {
                households.append(createdHousehold)
            }
            householdAlertError = nil
            lastError = nil
            selectHousehold(createdHousehold.id)
            Task { await refreshInBackground() }
        } catch {
            presentHouseholdOperationError(error, logPrefix: "HouseholdCreate")
        }
    }

    func joinHousehold(inviteCode: String) async {
        isLoading = true
        defer { isLoading = false }
        householdAlertError = nil
        let normalizedCode = inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        do {
            guard let session = try await ensuredSession() else {
                PendingInvitePersistence.save(code: normalizedCode, token: nil, householdId: nil)
                presentHouseholdAlert(
                    "Sign in or create an account to finish joining this family. Your invite has been saved.",
                    logPrefix: "HouseholdJoin"
                )
                InviteFlowLogger.manualJoinPersistedNoSession(normalizedInviteCode: normalizedCode)
                return
            }
            let joined: BackendHousehold
            if parseHouseholdJoinCode(normalizedCode) != nil {
                joined = try await service.joinHouseholdByCode(normalizedCode, session: session)
            } else {
                joined = try await service.joinHouseholdByInviteCode(normalizedCode, session: session)
            }
#if DEBUG
            print("[HouseholdJoin] success household_id=\(joined.id.uuidString)")
#endif
            if !households.contains(where: { $0.id == joined.id }) {
                households.append(joined)
            }
            selectHousehold(joined.id)
            let hasMembership = activeMemberships.contains { membership in
                membership.householdId == joined.id && membership.userId.uuidString == session.userId
            }
            if !hasMembership {
                presentHouseholdAlert(
                    "Joined household locally, but membership was not confirmed on backend.",
                    logPrefix: "HouseholdJoin"
                )
                return
            }
            householdAlertError = nil
            lastError = nil
            Task { await refreshInBackground() }
        } catch {
            presentHouseholdOperationError(error, logPrefix: "HouseholdJoin")
        }
    }

    func previewHousehold(inviteCode: String) async throws -> BackendHousehold {
        guard let session = try await ensuredSession() else {
            throw SupabaseHouseholdBackendService.ServiceError.requestFailed("No active auth session.")
        }
        return try await service.fetchHouseholdByInviteCode(inviteCode, session: session)
    }

    func previewJoinResult(inviteCode: String) async throws -> InviteCodeJoinResult {
        let session = try? await ensuredSession()
#if DEBUG
        print("[BackendHouseholdContext] previewJoinResult auth_present=\(session != nil)")
#endif
        return try await service.inspectJoinByInviteCode(inviteCode, session: session)
    }

    func resolvePendingInvitePreviewFromPersistence() async throws -> HouseholdInvitePreview? {
        guard let session = try await ensuredSession() else { return nil }
        guard let snap = PendingInvitePersistence.load() else { return nil }
        if snap.prefersToken, let token = snap.inviteToken {
            return try await service.fetchInvitePreviewByToken(token, session: session)
        }
        if let code = snap.inviteCode {
            return try await service.fetchInvitePreviewByCode(code, session: session)
        }
        return nil
    }

    @discardableResult
    func acceptStoredPendingInvite() async -> Bool {
        do {
            guard let session = try await ensuredSession() else {
                lastError = "No active auth session."
                return false
            }
            guard let snap = PendingInvitePersistence.load() else { return false }
            let response: HouseholdInviteAcceptRPCResponse
            if snap.prefersToken, let token = snap.inviteToken {
                response = try await service.acceptHouseholdInviteRPC(inviteToken: token, session: session)
            } else if let code = snap.inviteCode {
                response = try await service.acceptHouseholdInviteRPC(inviteCode: code, session: session)
            } else {
                return false
            }
#if DEBUG
            print("[BackendHouseholdContext] acceptStoredPendingInvite outcome=\(response.outcome)")
#endif
            switch response.outcome.lowercased() {
            case "joined", "already_member":
                PendingInvitePersistence.clear(reason: "accept_stored_success")
                if let householdId = response.householdId {
                    selectHousehold(householdId)
                }
                householdAlertError = nil
                lastError = nil
                Task { await refreshInBackground() }
                return true
            default:
                lastError = Self.userFacingMessageForInviteOutcome(response.outcome)
                return false
            }
        } catch {
            presentHouseholdOperationError(error, logPrefix: "HouseholdJoin")
            return false
        }
    }

    @discardableResult
    func declineStoredPendingInvite() async -> Bool {
        do {
            guard let session = try await ensuredSession() else {
                lastError = "No active auth session."
                return false
            }
            guard let code = PendingInvitePersistence.load()?.inviteCode, !code.isEmpty else {
                PendingInvitePersistence.clear(reason: "decline_no_code")
                return true
            }
            _ = try await service.declineHouseholdInviteRPC(inviteCode: code, session: session)
            PendingInvitePersistence.clear(reason: "decline_completed")
            lastError = nil
            return true
        } catch {
            assignLastError(from: error)
            return false
        }
    }

    private static func userFacingMessageForInviteOutcome(_ outcome: String) -> String {
        switch outcome.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "invalid_code":
            return "This invite code does not exist."
        case "expired":
            return "This invite has expired."
        case "already_used":
            return "This invite has already been used."
        case "cancelled":
            return "This invite was cancelled by the organiser."
        case "declined":
            return "This invite is no longer available."
        case "not_authenticated":
            return "Session expired. Please sign in again to continue."
        default:
            return "Something went wrong while joining the household. Please try again."
        }
    }

    func hasPendingInviteForCurrentUser(householdId: UUID) async throws -> Bool {
        guard let session = try await ensuredSession() else {
            throw SupabaseHouseholdBackendService.ServiceError.requestFailed("No active auth session.")
        }
        return try await service.hasPendingInviteForSignedInUser(householdId: householdId, session: session)
    }

    func createInviteCode() async -> BackendHouseholdInvite? {
        guard canManageInvites else {
            lastError = "Only organisers can manage invites."
            return nil
        }
        do {
            guard let session = try await ensuredSession() else {
                lastError = "No active auth session."
                return nil
            }
            guard let activeHouseholdId else {
                lastError = "No active household selected."
                return nil
            }
            let invite = try await service.createInviteCode(for: activeHouseholdId, session: session)
            await refreshInvites()
            return invite
        } catch {
            assignLastError(from: error)
            return nil
        }
    }

    @discardableResult
    func createInviteOrPendingMembership(
        email: String,
        accessRole: String,
        relationshipLabel: String?,
        invitedByUserId: UUID?
    ) async -> InviteOrMembershipCreateResult? {
        guard canManageMembers else {
            lastError = "Only organisers can manage members."
            return nil
        }
        do {
            guard let session = try await ensuredSession() else {
                lastError = "No active auth session."
                return nil
            }
            guard let activeHouseholdId else {
                lastError = "No active household selected."
                return nil
            }
            let result = try await service.createInviteOrPendingMembership(
                householdId: activeHouseholdId,
                email: email,
                accessRole: accessRole,
                relationshipLabel: relationshipLabel,
                invitedByUserId: invitedByUserId,
                session: session
            )
            await refreshMemberships()
            await refreshInvites()
            lastError = nil
            return result
        } catch {
            assignLastError(from: error)
            return nil
        }
    }

    @discardableResult
    func resendInvite(_ invite: BackendHouseholdInvite) async -> Bool {
        guard canManageInvites else {
            lastError = "Only organisers can manage invites."
            return false
        }
        do {
            guard let session = try await ensuredSession() else {
                lastError = "No active auth session."
                return false
            }
            guard let household = activeHousehold else {
                lastError = "No active household selected."
                return false
            }
            try await service.resendInviteEmail(invite: invite, household: household, session: session)
            await refreshInvites()
            lastError = nil
            return true
        } catch {
            assignLastError(from: error)
            return false
        }
    }

    @discardableResult
    func cancelInvite(inviteId: UUID) async -> Bool {
        guard canManageInvites else {
            lastError = "Only organisers can manage invites."
            return false
        }
        do {
            guard let session = try await ensuredSession() else {
                lastError = "No active auth session."
                return false
            }
#if DEBUG
            print(
                "[BackendHouseholdContext] cancelInvite request " +
                "invite_id=\(inviteId.uuidString.lowercased()), user_id=\(session.userId), " +
                "active_household_id=\(activeHouseholdId?.uuidString ?? "nil")"
            )
#endif
            try await service.cancelInvite(inviteId: inviteId, session: session)
            await refreshInvites()
            lastError = nil
            return true
        } catch {
            assignLastError(from: error)
            return false
        }
    }

    func acceptPendingInvitesForSignedInUser() async {
        do {
            guard let session = try await ensuredSession() else {
                lastError = "No active auth session."
                return
            }
            try await service.acceptPendingInvitesForSignedInUser(session: session)
            await refresh()
            lastError = nil
        } catch {
            assignLastError(from: error)
        }
    }

    @discardableResult
    func approveMembership(_ membershipId: UUID) async -> Bool {
        guard canManageMembers else {
            lastError = "Only organisers can approve members."
            return false
        }
        do {
            guard let session = try await ensuredSession() else {
                lastError = "No active auth session."
                return false
            }
            _ = try await service.approveMembership(membershipId: membershipId, session: session)
            await refreshMemberships()
            lastError = nil
            return true
        } catch {
            assignLastError(from: error)
            return false
        }
    }

    @discardableResult
    func approveMembershipRequest(_ membership: BackendHouseholdMembership) async -> Bool {
        guard canApproveRequests else {
            lastError = "Only organisers can approve members."
            return false
        }
        do {
            guard let session = try await ensuredSession() else {
                lastError = "No active auth session."
                return false
            }
#if DEBUG
            print("[BackendHouseholdContext] approve request start membership_id=\(membership.id.uuidString)")
#endif
            try await service.approveMembershipRequest(membershipId: membership.id, session: session)
            await refreshMemberships()
            lastError = nil
#if DEBUG
            print("[BackendHouseholdContext] approve request success membership_id=\(membership.id.uuidString)")
#endif
            return true
        } catch {
#if DEBUG
            print("[BackendHouseholdContext] approve request failure membership_id=\(membership.id.uuidString) error=\(error.localizedDescription)")
#endif
            assignLastError(from: error)
            return false
        }
    }

    @discardableResult
    func rejectMembershipRequest(_ membership: BackendHouseholdMembership) async -> Bool {
        guard canApproveRequests else {
            lastError = "Only organisers can reject members."
            return false
        }
        do {
            guard let session = try await ensuredSession() else {
                lastError = "No active auth session."
                return false
            }
#if DEBUG
            print("[BackendHouseholdContext] reject request start membership_id=\(membership.id.uuidString)")
#endif
            try await service.rejectMembershipRequest(membershipId: membership.id, session: session)
            await refreshMemberships()
            lastError = nil
#if DEBUG
            print("[BackendHouseholdContext] reject request success membership_id=\(membership.id.uuidString)")
#endif
            return true
        } catch {
#if DEBUG
            print("[BackendHouseholdContext] reject request failure membership_id=\(membership.id.uuidString) error=\(error.localizedDescription)")
#endif
            assignLastError(from: error)
            return false
        }
    }

    @discardableResult
    func updateMembershipAccess(
        membershipId: UUID,
        accessRole: String,
        relationshipLabel: String?
    ) async -> Bool {
        guard canManageMembers else {
            lastError = "Only organisers can manage members."
            return false
        }
        do {
            guard let session = try await ensuredSession() else {
                lastError = "No active auth session."
                return false
            }
            _ = try await service.updateMembershipAccess(
                membershipId: membershipId,
                accessRole: accessRole,
                relationshipLabel: relationshipLabel,
                session: session
            )
            await refreshMemberships()
            lastError = nil
            return true
        } catch {
            assignLastError(from: error)
            return false
        }
    }

    func removalEligibility(for membership: BackendHouseholdMembership) -> HouseholdMemberRemovalPolicy.Evaluation {
        guard canManageMembers else {
            return HouseholdMemberRemovalPolicy.Evaluation(
                canRemove: false,
                blockedReason: nil,
                requiresOrganiserRemovalWarning: false
            )
        }
        let activeMembers = activeHouseholdMembers.filter(\.isActive)
        return HouseholdMemberRemovalPolicy.evaluate(
            membership: membership,
            activeMembers: activeMembers
        )
    }

    @discardableResult
    func removeMember(membershipId: UUID) async -> Bool {
        guard canManageMembers else {
            lastError = "Only organisers can manage members."
            return false
        }
        do {
            guard let session = try await ensuredSession() else {
                lastError = "No active auth session."
                return false
            }
            let removedMembership = memberships.first(where: { $0.id == membershipId })
            let removedCurrentUser = removedMembership?.userId.uuidString.lowercased() == session.userId.lowercased()
            _ = try await service.removeHouseholdMember(membershipId: membershipId, session: session)
#if DEBUG
            print("[MembershipRemoval] removed_membership_id=\(membershipId.uuidString)")
            print("[MembershipRemoval] removed_current_user=\(removedCurrentUser)")
            print("[MembershipRemoval] status=revoked")
#endif
            await refresh()
            if removedCurrentUser || !hasActiveMembership {
                clearHouseholdScopedState()
            }
            lastError = nil
            return true
        } catch {
            assignLastError(from: error)
            return false
        }
    }

    func refreshMemberships() async {
        do {
            guard let session = try await ensuredSession() else {
                lastError = "No active auth session."
                return
            }
            guard let activeHouseholdId, hasActiveMembership else {
                clearHouseholdScopedState()
                return
            }
            let members = try await service.fetchHouseholdMembers(householdId: activeHouseholdId, session: session)
            activeHouseholdMembers = members
#if DEBUG
            let memberUserIds = members.map { $0.userId.uuidString }.joined(separator: ",")
            print(
                "[BackendHouseholdContext] refreshMemberships activeHouseholdId=\(activeHouseholdId.uuidString), " +
                "fetched_membership_count=\(members.count), fetched_membership_user_ids=[\(memberUserIds)]"
            )
#endif
            activeHouseholdProfilesByUserId = await loadProfilesByUserId(for: activeHouseholdMembers.map(\.userId))
            clearTransientErrors()
        } catch {
            recordBackgroundRefreshError(error, operation: "refreshMemberships")
        }
    }

    func refreshInvites() async {
        do {
            guard let session = try await ensuredSession() else {
                lastError = "No active auth session."
                return
            }
            guard let activeHouseholdId else {
                activeHouseholdInvites = []
                return
            }
            activeHouseholdInvites = try await service.fetchInvites(householdId: activeHouseholdId, session: session)
            clearTransientErrors()
        } catch {
            recordBackgroundRefreshError(error, operation: "refreshInvites")
        }
    }

    func selectHousehold(_ id: UUID) {
        guard activeMemberships.contains(where: { $0.householdId == id }) else {
#if DEBUG
            print("[BackendHouseholdContext] selectHousehold rejected id=\(id.uuidString) (no active membership)")
#endif
            return
        }
        if activeHouseholdId == id {
#if DEBUG
            print("[BackendHouseholdContext] selectHousehold no-op id=\(id.uuidString)")
#endif
            return
        }
        applyActiveHouseholdSelection(id)
        householdAlertError = nil
        lastError = nil
        if let household = households.first(where: { $0.id == id }) {
            Task {
                await localHouseholdDataSource.adoptBackendHousehold(
                    id: id,
                    name: household.name.isEmpty ? "Shared Household" : household.name
                )
                localHouseholdContext.householdId = id
                localHouseholdContext.householdName = household.name
            }
        }
        Task {
            await refreshMemberships()
            await refreshInvites()
        }
    }

    func roleForActiveHousehold() -> String? {
        currentUserAccessRoleForActiveHousehold?.rawValue
    }

    var activeMemberships: [BackendHouseholdMembership] {
        memberships.filter(\.isActiveMembership)
    }

    var hasActiveMembership: Bool {
        !activeMemberships.isEmpty
    }

    var currentActiveMembership: BackendHouseholdMembership? {
        guard let activeHouseholdId,
              let currentUserId = currentSession?.userId.lowercased() else {
            return nil
        }
        return activeMemberships.first {
            $0.householdId == activeHouseholdId &&
            $0.userId.uuidString.lowercased() == currentUserId
        }
    }

    private var currentUserMembershipForActiveHousehold: BackendHouseholdMembership? {
        currentActiveMembership
    }

    var currentUserAccessRoleForActiveHousehold: HouseholdAccessRole? {
        guard let membership = currentUserMembershipForActiveHousehold else { return nil }
        let isActiveMembership = membership.normalizedStatus == .active || membership.normalizedStatus == nil
        guard isActiveMembership else { return nil }
        return membership.normalizedAccessRole
    }

    var currentUserAccessRole: AccessRole? {
        guard let role = currentUserAccessRoleForActiveHousehold?.rawValue else { return nil }
        return AccessRole(rawValue: role)
    }

    var isCurrentUserOrganiser: Bool {
        currentUserAccessRoleForActiveHousehold == .organiser
    }

    var isCurrentUserDriver: Bool {
        currentUserAccessRoleForActiveHousehold == .driver
    }

    var isCurrentUserObserver: Bool {
        currentUserAccessRoleForActiveHousehold == .observer
    }

    var canManageMembers: Bool {
        hasActiveMembership && isCurrentUserOrganiser
    }

    var canManageInvites: Bool {
        isCurrentUserOrganiser
    }

    var canApproveRequests: Bool {
        isCurrentUserOrganiser
    }

    var canEditSchedules: Bool {
        isCurrentUserOrganiser
    }

    var canManageSchedules: Bool {
        canEditSchedules
    }

    var canStartRuns: Bool {
        isCurrentUserOrganiser || isCurrentUserDriver
    }

    var canUpdateRuns: Bool {
        isCurrentUserOrganiser || isCurrentUserDriver
    }

    var canManageTribeSettings: Bool {
        isCurrentUserOrganiser
    }

    var canViewRunTracking: Bool {
        currentUserAccessRoleForActiveHousehold != nil
    }

    var canViewSchedules: Bool {
        currentUserAccessRole != nil
    }

    var canViewRuns: Bool {
        currentUserAccessRole != nil
    }

    func updateMembershipAttributes(
        membershipId: UUID,
        role: String?,
        status: String?,
        familyRole: String?,
        relationshipLabel: String?
    ) async throws {
        guard canManageMembers else {
            throw NSError(domain: "BackendHouseholdContext", code: 403, userInfo: [
                NSLocalizedDescriptionKey: "Only organisers can manage members."
            ])
        }
        guard let session = try await ensuredSession() else {
            throw NSError(domain: "BackendHouseholdContext", code: 401, userInfo: [
                NSLocalizedDescriptionKey: "No active auth session."
            ])
        }
        _ = try await service.updateMembershipAttributes(
            membershipId: membershipId,
            role: role,
            status: status,
            familyRole: familyRole,
            relationshipLabel: relationshipLabel,
            session: session
        )
        await refreshMemberships()
    }

    func handleRealtimeEvent(_ event: RealtimeChangeEvent) async {
        guard event.entityType == .householdMembership else { return }
        guard let activeHouseholdId else { return }
        guard event.householdId == nil || event.householdId == activeHouseholdId else { return }

        realtimeDebounceTask?.cancel()
        realtimeDebounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 500_000_000)
            await self?.runSafeRealtimeRefresh()
        }
    }

    private func restoreOrAutoSelectActiveHousehold() {
        reconcileActiveHouseholdSelection()
    }

    private func reconcileActiveHouseholdSelection() {
        let active = activeMemberships
        let previousActiveHouseholdId = activeHouseholdId
#if DEBUG
        print("[AccessGuard] active_membership_count=\(active.count)")
#endif
        guard !active.isEmpty else {
            if previousActiveHouseholdId != nil {
                clearHouseholdScopedState()
#if DEBUG
                print("[AccessGuard] active_household_invalidated=true")
                print("[AccessGuard] cleared_household_scoped_state=true")
                print("[AccessGuard] route=noActiveTribe")
#endif
            }
            return
        }

        let restoredActiveHouseholdId = activeHouseholdStore?.activeHouseholdId ?? userDefaults.activeHouseholdId
        if let restoredActiveHouseholdId,
           active.contains(where: { $0.householdId == restoredActiveHouseholdId }) {
#if DEBUG
            print(
                "[AccessGuard] active_household_id=\(restoredActiveHouseholdId.uuidString), " +
                "active_household_invalidated=false"
            )
#endif
            applyActiveHouseholdSelection(restoredActiveHouseholdId)
            return
        }

        if let previousActiveHouseholdId,
           active.contains(where: { $0.householdId == previousActiveHouseholdId }) {
            applyActiveHouseholdSelection(previousActiveHouseholdId)
            return
        }

        if let firstActiveMembership = active.first {
            let invalidated = previousActiveHouseholdId != nil && previousActiveHouseholdId != firstActiveMembership.householdId
#if DEBUG
            print(
                "[AccessGuard] active_household_id=\(firstActiveMembership.householdId.uuidString), " +
                "active_household_invalidated=\(invalidated)"
            )
            if invalidated {
                print("[AccessGuard] cleared_household_scoped_state=true")
            }
            print("[AccessGuard] route=mainApp")
#endif
            applyActiveHouseholdSelection(firstActiveMembership.householdId)
        }
    }

    func ensureActiveHouseholdSelectionFromMemberships() -> UUID? {
        reconcileActiveHouseholdSelection()
        return activeHouseholdId
    }

    func clearHouseholdScopedState() {
        activeHouseholdMembers = []
        activeHouseholdProfilesByUserId = [:]
        activeHouseholdInvites = []
        applyActiveHouseholdSelection(nil)
        localHouseholdContext.householdId = HouseholdDefaults.defaultHouseholdId
        localHouseholdContext.householdName = HouseholdDefaults.defaultHouseholdName
#if DEBUG
        print("[AccessGuard] cleared_household_scoped_state=true")
#endif
    }

    private func applyActiveHouseholdSelection(_ id: UUID?) {
        activeHouseholdId = id
        activeHouseholdStore?.setActiveHousehold(id: id)
        userDefaults.activeHouseholdId = id
    }

    private func ensuredSession() async throws -> AuthUserSession? {
        if let currentSession {
            return currentSession
        }
        let restored = try await authService.restoreSession()
        currentSession = restored
        return restored
    }

    private func runSafeRealtimeRefresh() async {
        if isRealtimeRefreshInFlight {
            hasPendingRealtimeRefresh = true
            return
        }
        isRealtimeRefreshInFlight = true
        defer { isRealtimeRefreshInFlight = false }
        await refresh()
        if hasPendingRealtimeRefresh {
            hasPendingRealtimeRefresh = false
            await refresh()
        }
    }

    private func loadProfilesByUserId(for userIds: [UUID]) async -> [UUID: BackendProfile] {
        do {
            let profiles = try await profileService.fetchProfiles(userIds: userIds)
            return Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0) })
        } catch {
            return [:]
        }
    }

    private func refreshInBackground() async {
        await refresh()
    }

    private func clearTransientErrors() {
        lastError = nil
    }

    private func recordBackgroundRefreshError(_ error: Error, operation: String) {
        if isCancellationError(error) {
#if DEBUG
            print("[HouseholdCreate] ignored cancellation during background refresh operation=\(operation)")
#endif
            return
        }
        if let message = userFacingErrorMessage(error) {
            lastError = message
#if DEBUG
            print("[BackendHouseholdContext] background refresh failed operation=\(operation) error=\(message)")
#endif
        }
    }

    private func presentHouseholdAlert(_ message: String, logPrefix: String) {
#if DEBUG
        print("[\(logPrefix)] presenting error=\(message)")
#endif
        householdAlertError = message
        lastError = message
    }

    private func presentHouseholdOperationError(_ error: Error, logPrefix: String) {
        if isCancellationError(error) {
#if DEBUG
            print("[\(logPrefix)] ignored cancellation during background refresh")
#endif
            return
        }
        guard let message = userFacingErrorMessage(error) else { return }
#if DEBUG
        print("[\(logPrefix)] presenting error=\(message)")
#endif
        householdAlertError = message
        lastError = message
    }

    private func assignLastError(from error: Error) {
        if let message = userFacingErrorMessage(error) {
            lastError = message
        }
    }

    private func userFacingErrorMessage(_ error: Error) -> String? {
        if isCancellationError(error) {
            return nil
        }
        let normalized = error.localizedDescription.lowercased()
        if normalized.contains("session expired")
            || normalized.contains("jwt expired")
            || normalized.contains("pgrst303")
            || normalized.contains("unauthenticated") {
            return "Session expired. Please sign in again to continue."
        }
        return SupabaseHouseholdBackendService.ServiceError.userFacingInviteJoinMessage(for: error)
    }

    func currentUserMembershipStatusForActiveHousehold() -> HouseholdMembershipStatus? {
        currentActiveMembership?.normalizedStatus
    }

    var activeHousehold: BackendHousehold? {
        guard hasActiveMembership, let activeHouseholdId else { return nil }
        return households.first(where: { $0.id == activeHouseholdId })
    }

    var activeHouseholdName: String? {
        guard hasActiveMembership else { return nil }
        guard let value = activeHousehold?.name.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else {
            return nil
        }
        return value
    }

    var activeHouseholdInviteCode: String? {
        guard hasActiveMembership else { return nil }
        guard let value = activeHousehold?.inviteCode?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
              !value.isEmpty else {
            return nil
        }
        return value
    }
    
    func reset() {
        households = []
        memberships = []
        activeHouseholdMembers = []
        activeHouseholdProfilesByUserId = [:]
        activeHouseholdInvites = []
        activeHouseholdId = nil
        activeHouseholdStore?.clear()
        isLoading = false
        lastError = nil
        householdAlertError = nil
        currentSession = nil
        realtimeDebounceTask?.cancel()
        realtimeDebounceTask = nil
        isRealtimeRefreshInFlight = false
        hasPendingRealtimeRefresh = false
        userDefaults.activeHouseholdId = nil
    }
}
