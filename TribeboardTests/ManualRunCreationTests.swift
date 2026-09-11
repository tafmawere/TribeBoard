import XCTest
@testable import Tribeboard

@MainActor
private final class InMemoryRunBackendService: RunBackendService {
    private var packagesByHousehold: [UUID: [BackendRunPackage]] = [:]

    func fetchRunPackages(householdId: UUID) async throws -> [BackendRunPackage] {
        packagesByHousehold[householdId] ?? []
    }

    func createRunPackage(_ package: BackendRunPackage) async throws -> BackendRunPackage {
        var list = packagesByHousehold[package.run.householdId] ?? []
        list.removeAll { $0.run.id == package.run.id }
        list.append(package)
        packagesByHousehold[package.run.householdId] = list
        return package
    }

    func updateRunHeader(_ run: BackendRun) async throws -> BackendRun { run }

    func replaceRunStops(runId: UUID, stops: [BackendRunStop]) async throws -> [BackendRunStop] { stops }

    func updateRunStop(_ stop: BackendRunStop) async throws -> BackendRunStop { stop }

    func deleteRun(id: UUID) async throws {
        for (householdId, packages) in packagesByHousehold {
            packagesByHousehold[householdId] = packages.filter { $0.run.id != id }
        }
    }

    func fetchRuns(householdId: UUID) async throws -> [BackendRun] {
        try await fetchRunPackages(householdId: householdId).map(\.run)
    }

    func createRun(_ run: BackendRun) async throws -> BackendRun { run }

    func updateRun(_ run: BackendRun) async throws -> BackendRun { run }
}

private enum ManualRunCreationTestError: Error {
    case unimplemented
}

private final class RefreshingAuthServiceMock: AuthService {
    private(set) var restoreCallCount = 0
    let refreshedSession: AuthUserSession

    init(refreshedSession: AuthUserSession) {
        self.refreshedSession = refreshedSession
    }

    func restoreSession() async throws -> AuthUserSession? {
        restoreCallCount += 1
        return refreshedSession
    }

    func checkEmailExists(email: String) async throws -> Bool { throw ManualRunCreationTestError.unimplemented }
    func signInWithEmailPassword(email: String, password: String) async throws -> AuthUserSession { throw ManualRunCreationTestError.unimplemented }
    func signUpWithEmailPassword(email: String, password: String, displayName: String?) async throws -> SignUpResult { throw ManualRunCreationTestError.unimplemented }
    func verifyEmailOTP(email: String, token: String, type: EmailOTPVerificationType) async throws -> AuthUserSession { throw ManualRunCreationTestError.unimplemented }
    func resendSignupVerification(email: String) async throws { throw ManualRunCreationTestError.unimplemented }
    func session(fromAuthCallback parsed: AuthCallbackURLParser.ParsedSession) async throws -> AuthUserSession { throw ManualRunCreationTestError.unimplemented }
    func signInWithApple() async throws -> AuthUserSession { throw ManualRunCreationTestError.unimplemented }
    func signInWithGoogle() async throws -> AuthUserSession { throw ManualRunCreationTestError.unimplemented }
    func signOut(currentSession: AuthUserSession?) async throws { }
}

private final class RunPermissionHouseholdBackendServiceMock: HouseholdBackendService {
    let membership: BackendHouseholdMembership
    private(set) var permissionSessionAccessToken: String?

    init(membership: BackendHouseholdMembership) {
        self.membership = membership
    }

    func fetchMyMemberships(session: AuthUserSession) async throws -> [BackendHouseholdMembership] {
        permissionSessionAccessToken = session.accessToken
        return [membership]
    }

    func createHousehold(name: String, session: AuthUserSession) async throws -> BackendHousehold { throw ManualRunCreationTestError.unimplemented }
    func updateHouseholdName(householdId: UUID, name: String, session: AuthUserSession) async throws -> BackendHousehold { throw ManualRunCreationTestError.unimplemented }
    func fetchMyHouseholds(session: AuthUserSession) async throws -> [BackendHousehold] { throw ManualRunCreationTestError.unimplemented }
    func createInviteCode(for householdId: UUID, session: AuthUserSession) async throws -> BackendHouseholdInvite { throw ManualRunCreationTestError.unimplemented }
    func createInviteOrPendingMembership(householdId: UUID, email: String, accessRole: String, relationshipLabel: String?, invitedByUserId: UUID?, session: AuthUserSession) async throws -> InviteOrMembershipCreateResult { throw ManualRunCreationTestError.unimplemented }
    func fetchInvites(householdId: UUID, session: AuthUserSession) async throws -> [BackendHouseholdInvite] { throw ManualRunCreationTestError.unimplemented }
    func resendInviteEmail(invite: BackendHouseholdInvite, household: BackendHousehold, session: AuthUserSession) async throws { throw ManualRunCreationTestError.unimplemented }
    func cancelInvite(inviteId: UUID, session: AuthUserSession) async throws { throw ManualRunCreationTestError.unimplemented }
    func fetchPendingInvitesForSignedInUser(session: AuthUserSession) async throws -> [BackendHouseholdInvite] { throw ManualRunCreationTestError.unimplemented }
    func acceptPendingInvitesForSignedInUser(session: AuthUserSession) async throws { throw ManualRunCreationTestError.unimplemented }
    func approveMembership(membershipId: UUID, session: AuthUserSession) async throws -> BackendHouseholdMembership { throw ManualRunCreationTestError.unimplemented }
    func approveMembershipRequest(membershipId: UUID, session: AuthUserSession) async throws { throw ManualRunCreationTestError.unimplemented }
    func rejectMembershipRequest(membershipId: UUID, session: AuthUserSession) async throws { throw ManualRunCreationTestError.unimplemented }
    func updateMembershipAccess(membershipId: UUID, accessRole: String, relationshipLabel: String?, session: AuthUserSession) async throws -> BackendHouseholdMembership { throw ManualRunCreationTestError.unimplemented }
    func removeHouseholdMember(membershipId: UUID, session: AuthUserSession) async throws -> BackendHouseholdMembership { throw ManualRunCreationTestError.unimplemented }
    func resolveHouseholdByJoinCode(prefix: String, session: AuthUserSession) async throws -> [BackendHousehold] { throw ManualRunCreationTestError.unimplemented }
    func fetchHouseholdByInviteCode(_ code: String, session: AuthUserSession) async throws -> BackendHousehold { throw ManualRunCreationTestError.unimplemented }
    func fetchInvitePreviewByCode(_ code: String, session: AuthUserSession?) async throws -> HouseholdInvitePreview? { throw ManualRunCreationTestError.unimplemented }
    func fetchInvitePreviewByToken(_ token: String, session: AuthUserSession?) async throws -> HouseholdInvitePreview? { throw ManualRunCreationTestError.unimplemented }
    func fetchInvitePreviewByInviteId(_ inviteId: UUID, session: AuthUserSession?) async throws -> HouseholdInvitePreview? { throw ManualRunCreationTestError.unimplemented }
    func inspectJoinByInviteCode(_ code: String, session: AuthUserSession?) async throws -> InviteCodeJoinResult { throw ManualRunCreationTestError.unimplemented }
    func hasPendingInviteForSignedInUser(householdId: UUID, session: AuthUserSession) async throws -> Bool { throw ManualRunCreationTestError.unimplemented }
    func joinHouseholdByInviteCode(_ code: String, session: AuthUserSession) async throws -> BackendHousehold { throw ManualRunCreationTestError.unimplemented }
    func joinHouseholdByCode(_ code: String, session: AuthUserSession) async throws -> BackendHousehold { throw ManualRunCreationTestError.unimplemented }
    func acceptHouseholdInviteRPC(inviteCode: String, session: AuthUserSession) async throws -> HouseholdInviteAcceptRPCResponse { throw ManualRunCreationTestError.unimplemented }
    func acceptHouseholdInviteRPC(inviteToken: String, session: AuthUserSession) async throws -> HouseholdInviteAcceptRPCResponse { throw ManualRunCreationTestError.unimplemented }
    func acceptHouseholdInviteRPC(inviteId: UUID, session: AuthUserSession) async throws -> HouseholdInviteAcceptRPCResponse { throw ManualRunCreationTestError.unimplemented }
    func declineHouseholdInviteRPC(inviteCode: String, session: AuthUserSession) async throws -> HouseholdInviteAcceptRPCResponse { throw ManualRunCreationTestError.unimplemented }
    func fetchHouseholdMembers(householdId: UUID, session: AuthUserSession) async throws -> [BackendHouseholdMembership] { throw ManualRunCreationTestError.unimplemented }
    func updateMembershipAttributes(membershipId: UUID, role: String?, status: String?, familyRole: String?, relationshipLabel: String?, session: AuthUserSession) async throws -> BackendHouseholdMembership { throw ManualRunCreationTestError.unimplemented }
}

@MainActor
final class ManualRunCreationTests: XCTestCase {
    func testResolveChildIdIgnoresOtherHouseholdAndFallsBackToFirstScoped() {
        let householdId = UUID()
        let otherHousehold = UUID()
        let local = BackendChild(
            id: UUID(),
            householdId: householdId,
            legalName: "Local Legal",
            displayName: "Local",
            dateOfBirth: nil,
            schoolName: nil,
            gradeOrClass: nil,
            createdAt: nil,
            updatedAt: nil
        )
        let outsider = BackendChild(
            id: UUID(),
            householdId: otherHousehold,
            legalName: "TJ",
            displayName: "TJ",
            dateOfBirth: nil,
            schoolName: nil,
            gradeOrClass: nil,
            createdAt: nil,
            updatedAt: nil
        )
        XCTAssertEqual(
            ManualRunCreationSupport.resolveChildId(
                passengerNames: ["TJ"],
                children: [outsider, local],
                householdId: householdId
            ),
            local.id
        )
        XCTAssertNil(
            ManualRunCreationSupport.resolveChildId(
                passengerNames: ["TJ"],
                children: [outsider],
                householdId: householdId
            )
        )
    }

    func testStopLabelCodecInfersPickupAndDropoff() {
        XCTAssertEqual(RunStopLabelCodec.inferredKind(order: 0, total: 2), RunStopLabelCodec.pickup)
        XCTAssertEqual(RunStopLabelCodec.inferredKind(order: 1, total: 2), RunStopLabelCodec.dropoff)
        XCTAssertEqual(RunStopLabelCodec.normalizedKind(" pickup "), RunStopLabelCodec.pickup)
        XCTAssertNil(RunStopLabelCodec.normalizedKind("Home"))
        XCTAssertTrue(RunStopLabelCodec.isStopKind("Dropoff"))
        XCTAssertFalse(RunStopLabelCodec.isStopKind("School"))
    }

    func testResolveChildIdMatchesDisplayName() {
        let householdId = UUID()
        let childA = BackendChild(
            id: UUID(),
            householdId: householdId,
            legalName: "Legal",
            displayName: "TJ",
            dateOfBirth: nil,
            schoolName: nil,
            gradeOrClass: nil,
            createdAt: nil,
            updatedAt: nil
        )
        let resolved = ManualRunCreationSupport.resolveChildId(
            passengerNames: ["TJ"],
            children: [childA],
            householdId: householdId
        )
        XCTAssertEqual(resolved, childA.id)
    }

    func testDriverCandidateDisplayNameAvoidsEmailUntilLastResort() {
        XCTAssertEqual(
            AssignDriverCandidateDisplayName.resolve(
                profile: BackendProfile(
                    id: UUID(),
                    email: "grandad@example.com",
                    display_name: "Grandad",
                    first_name: "George",
                    last_name: "Mawere",
                    avatar_type: nil,
                    avatar_key: nil,
                    avatar_url: nil,
                    avatar_updated_at: nil,
                    created_at: nil,
                    updated_at: nil
                ),
                relationshipLabel: "Grandfather",
                householdPersonName: nil
            ),
            "Grandad"
        )

        XCTAssertEqual(
            AssignDriverCandidateDisplayName.resolve(
                profile: BackendProfile(
                    id: UUID(),
                    email: "grandad@example.com",
                    display_name: nil,
                    first_name: "George",
                    last_name: "Mawere",
                    avatar_type: nil,
                    avatar_key: nil,
                    avatar_url: nil,
                    avatar_updated_at: nil,
                    created_at: nil,
                    updated_at: nil
                ),
                relationshipLabel: "Grandad",
                householdPersonName: nil
            ),
            "Grandad"
        )

        XCTAssertEqual(
            AssignDriverCandidateDisplayName.resolve(
                profile: BackendProfile(
                    id: UUID(),
                    email: "driver@example.com",
                    display_name: nil,
                    first_name: "Rue",
                    last_name: "Mawere",
                    avatar_type: nil,
                    avatar_key: nil,
                    avatar_url: nil,
                    avatar_updated_at: nil,
                    created_at: nil,
                    updated_at: nil
                ),
                relationshipLabel: nil,
                householdPersonName: nil
            ),
            "Rue Mawere"
        )

        XCTAssertEqual(
            AssignDriverCandidateDisplayName.resolve(
                profile: nil,
                relationshipLabel: nil,
                householdPersonName: "Family Helper"
            ),
            "Family Helper"
        )

        XCTAssertEqual(
            AssignDriverCandidateDisplayName.resolve(
                profile: BackendProfile(
                    id: UUID(),
                    email: "only-email@example.com",
                    display_name: nil,
                    first_name: nil,
                    last_name: nil,
                    avatar_type: nil,
                    avatar_key: nil,
                    avatar_url: nil,
                    avatar_updated_at: nil,
                    created_at: nil,
                    updated_at: nil
                ),
                relationshipLabel: nil,
                householdPersonName: nil
            ),
            "only-email@example.com"
        )
    }

    func testCreateRunFromManualFormUsesRefreshedSessionForPermissionCheck() async throws {
        try XCTSkipUnless(BackendConfig.isBackendConfigured, "Backend config is required for permission-gated create-run save.")

        let householdId = UUID()
        let userId = UUID()
        let childId = UUID()
        let active = ActiveHouseholdContext(householdId: householdId, householdName: "Test Home")
        let runRepository = LocalRunRepository()
        let scheduleRepository = LocalScheduleRepository()
        let driverRepository = LocalDriverRepository()
        let backendRunsContext = BackendRunsContext(
            service: InMemoryRunBackendService(),
            runRepository: runRepository,
            scheduleRepository: scheduleRepository
        )
        let refreshedSession = AuthUserSession(
            accessToken: "refreshed-access-token",
            refreshToken: "rotated-refresh-token",
            userId: userId.uuidString,
            email: "parent@example.com",
            expiresAt: Date().addingTimeInterval(3600),
            authProvider: "email",
            providerDisplayName: "Parent"
        )
        let authService = RefreshingAuthServiceMock(refreshedSession: refreshedSession)
        let membershipService = RunPermissionHouseholdBackendServiceMock(
            membership: BackendHouseholdMembership(
                id: UUID(),
                householdId: householdId,
                userId: userId,
                role: "parent",
                status: "active",
                accessRole: "organiser",
                familyRole: "parent",
                relationshipLabel: "Parent",
                invitedByUserId: nil,
                createdAt: nil,
                updatedAt: nil
            )
        )
        let runDataSource = RunDataSource(
            repository: runRepository,
            scheduleRepository: scheduleRepository,
            driverRepository: driverRepository,
            householdContext: active,
            backendRunsContext: backendRunsContext,
            authService: authService,
            householdBackendService: membershipService
        )

        let driverId = ManualRunCreationSupport.stableUUID(namespace: householdId, string: "seed-grandad")
        try await driverRepository.saveDrivers([
            SystemDomain.Driver(
                id: driverId,
                householdId: householdId,
                name: "Grandad",
                phoneNumber: nil,
                isActive: true,
                createdAt: Date()
            )
        ], for: householdId)

        let children = [
            BackendChild(
                id: childId,
                householdId: householdId,
                legalName: "TJ Legal",
                displayName: "TJ",
                dateOfBirth: nil,
                schoolName: nil,
                gradeOrClass: nil,
                createdAt: nil,
                updatedAt: nil
            )
        ]
        let uiRun = RunDetailsData.UIRun(
            id: UUID(),
            title: "Refresh token run",
            scheduledTime: Date(),
            status: "Scheduled",
            driverName: "Grandad",
            passengerNames: ["TJ"],
            passengerStatuses: ["Waiting"],
            stops: [
                .init(
                    type: "Pickup",
                    label: "Home",
                    placeName: "",
                    address: "1 Test St",
                    latitude: -17.8,
                    longitude: 31.0,
                    timeEstimate: "--"
                ),
                .init(
                    type: "Dropoff",
                    label: "School",
                    placeName: "",
                    address: "2 Test Ave",
                    latitude: -17.9,
                    longitude: 31.1,
                    timeEstimate: "--"
                )
            ],
            timeline: [],
            canEdit: true,
            canCancel: true,
            isHistory: false
        )

        let ok = await runDataSource.createRunFromManualForm(uiRun, children: children)

        XCTAssertTrue(ok, "save failed: \(runDataSource.lastError ?? "unknown")")
        XCTAssertEqual(authService.restoreCallCount, 1)
        XCTAssertEqual(membershipService.permissionSessionAccessToken, "refreshed-access-token")
        let loaded = try await runRepository.loadRuns(for: householdId)
        XCTAssertTrue(loaded.contains(where: { $0.id == uiRun.id }))
    }

    func testCreateRunFromManualFormPersistsSelectedDriverCandidateIdAndName() async throws {
        let householdId = UUID()
        let childId = UUID()
        let selectedDriverId = UUID()
        let active = ActiveHouseholdContext(householdId: householdId, householdName: "Test Home")
        let runRepository = LocalRunRepository()
        let scheduleRepository = LocalScheduleRepository()
        let driverRepository = LocalDriverRepository()
        let backendRunsContext = BackendRunsContext(
            service: InMemoryRunBackendService(),
            runRepository: runRepository,
            scheduleRepository: scheduleRepository,
            driverRepository: driverRepository
        )
        let runDataSource = RunDataSource(
            repository: runRepository,
            scheduleRepository: scheduleRepository,
            driverRepository: driverRepository,
            householdContext: active,
            backendRunsContext: backendRunsContext
        )
#if DEBUG
        runDataSource.testBypassRunMutationPermission = true
#endif

        let children = [
            BackendChild(
                id: childId,
                householdId: householdId,
                legalName: "TJ Legal",
                displayName: "TJ",
                dateOfBirth: nil,
                schoolName: nil,
                gradeOrClass: nil,
                createdAt: nil,
                updatedAt: nil
            )
        ]
        let uiRun = RunDetailsData.UIRun(
            id: UUID(),
            title: "Grandad pickup",
            scheduledTime: Date(),
            status: "Scheduled",
            driverName: "Grandad",
            passengerNames: ["TJ"],
            passengerStatuses: ["Waiting"],
            stops: [
                .init(
                    type: "Pickup",
                    label: "Home",
                    placeName: "",
                    address: "1 Test St",
                    latitude: -17.8,
                    longitude: 31.0,
                    timeEstimate: "--"
                ),
                .init(
                    type: "Dropoff",
                    label: "School",
                    placeName: "",
                    address: "2 Test Ave",
                    latitude: -17.9,
                    longitude: 31.1,
                    timeEstimate: "--"
                )
            ],
            timeline: [],
            canEdit: true,
            canCancel: true,
            isHistory: false
        )

        let ok = await runDataSource.createRunFromManualForm(
            uiRun,
            children: children,
            selectedDriverId: selectedDriverId,
            selectedDriverSource: "household_people"
        )

        XCTAssertTrue(ok, "save failed: \(runDataSource.lastError ?? "unknown")")
        let saved = runDataSource.run(withId: uiRun.id.uuidString)
        XCTAssertEqual(saved?.assignedDriverId, selectedDriverId)
        XCTAssertEqual(saved?.driverId, selectedDriverId)
        XCTAssertEqual(saved?.assignedDriverName, "Grandad")
        let drivers = try await driverRepository.loadDrivers(for: householdId)
        XCTAssertTrue(drivers.contains(where: { $0.id == selectedDriverId && $0.name == "Grandad" }))
    }

    func testCreateRunFromManualFormPersistsOnePickupOneDropoff() async throws {
        let householdId = UUID()
        let childId = UUID()
        let active = ActiveHouseholdContext(householdId: householdId, householdName: "Test Home")
        let runRepository = LocalRunRepository()
        let scheduleRepository = LocalScheduleRepository()
        let driverRepository = LocalDriverRepository()
        let householdRepository = LocalHouseholdRepository()
        let backendRunsContext = BackendRunsContext(
            service: InMemoryRunBackendService(),
            runRepository: runRepository,
            scheduleRepository: scheduleRepository
        )
        let runDataSource = RunDataSource(
            repository: runRepository,
            scheduleRepository: scheduleRepository,
            driverRepository: driverRepository,
            householdContext: active,
            backendRunsContext: backendRunsContext
        )
#if DEBUG
        runDataSource.testBypassRunMutationPermission = true
#endif

        let driverId = ManualRunCreationSupport.stableUUID(namespace: householdId, string: "seed-rue")
        let rue = SystemDomain.Driver(
            id: driverId,
            householdId: householdId,
            name: "Rue",
            phoneNumber: nil,
            isActive: true,
            createdAt: Date()
        )
        try await driverRepository.saveDrivers([rue], for: householdId)

        let children = [
            BackendChild(
                id: childId,
                householdId: householdId,
                legalName: "T",
                displayName: "TJ",
                dateOfBirth: nil,
                schoolName: nil,
                gradeOrClass: nil,
                createdAt: nil,
                updatedAt: nil
            )
        ]

        let runId = UUID()
        let uiRun = RunDetailsData.UIRun(
            id: runId,
            title: "School Pickup",
            scheduledTime: Date(),
            status: "Scheduled",
            driverName: "Rue",
            passengerNames: ["TJ"],
            passengerStatuses: ["Waiting"],
            stops: [
                .init(
                    type: "Pickup",
                    label: "Pickup",
                    placeName: "St Stithians",
                    address: "1 Test St",
                    latitude: -17.8,
                    longitude: 31.0,
                    timeEstimate: "--"
                ),
                .init(
                    type: "Dropoff",
                    label: "Dropoff",
                    placeName: "Home",
                    address: "2 Test Ave",
                    latitude: -17.9,
                    longitude: 31.1,
                    timeEstimate: "--"
                )
            ],
            timeline: [],
            canEdit: true,
            canCancel: true,
            isHistory: false
        )

        let ok = await runDataSource.createRunFromManualForm(uiRun, children: children)
        XCTAssertTrue(ok, "save failed: \(runDataSource.lastError ?? "unknown")")

        let loaded = try await runRepository.loadRuns(for: householdId)
        XCTAssertTrue(loaded.contains(where: { $0.id == runId }))
        let saved = loaded.first(where: { $0.id == runId })
        XCTAssertEqual(saved?.householdId, householdId)
        XCTAssertEqual(saved?.childId, childId)
        XCTAssertEqual(saved?.title, "School Pickup")
        XCTAssertEqual(saved?.assignedDriverId, driverId)
        XCTAssertEqual(saved?.stopSnapshots.count, 2)
        XCTAssertEqual(saved?.stopSnapshots.sorted(by: { $0.order < $1.order }).map(\.name), ["St Stithians", "Home"])
        XCTAssertEqual(saved?.stopSnapshots.sorted(by: { $0.order < $1.order }).map(\.kind), ["Pickup" as String?, "Dropoff" as String?])
        XCTAssertEqual(saved?.status, .assigned)
    }
}
