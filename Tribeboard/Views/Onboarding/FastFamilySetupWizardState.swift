import Foundation
import SwiftUI
import Combine

enum FastFamilySetupStep: Int, CaseIterable, Codable {
    case welcome
    case familyPath
    case addChild
    case school
    case routine
    case activities
    case assignment
    case review

    var title: String {
        switch self {
        case .welcome: return "Welcome"
        case .familyPath: return "Family"
        case .addChild: return "First Child"
        case .school: return "School"
        case .routine: return "Weekly Routine"
        case .activities: return "Activities"
        case .assignment: return "Driver / Helper"
        case .review: return "Review"
        }
    }
}

enum FastFamilyPathChoice: String, Codable, CaseIterable {
    case create
    case join
}

enum FastRoleSuggestion: String, Codable, CaseIterable, Identifiable {
    case parent
    case driver
    case helper
    case guardian

    var id: String { rawValue }
}

struct FastSchoolSuggestion: Codable, Identifiable, Hashable {
    let id: UUID
    let schoolName: String
    let schoolAddress: String?
    let startHour: Int?
    let startMinute: Int?
    let endHour: Int?
    let endMinute: Int?
}

struct FastRoutineDayDraft: Codable, Identifiable, Hashable {
    let id: UUID
    let weekday: Weekday
    var isEnabled: Bool
    var startHour: Int
    var startMinute: Int
    var endHour: Int
    var endMinute: Int
}

struct FastActivityDraft: Codable, Identifiable, Hashable {
    let id: UUID
    var title: String
    var weekday: Weekday
    var hour: Int
    var minute: Int
    var location: String
    var atSchool: Bool
}

struct FastMemberOption: Codable, Identifiable, Hashable {
    let id: UUID // membership id
    let userId: UUID
    let displayName: String
    let role: String
    let status: String?
}

struct FastPersonOption: Codable, Identifiable, Hashable {
    let id: UUID
    let name: String
    let role: String
    let isDriver: Bool
}

private struct FastWizardSnapshot: Codable {
    var step: FastFamilySetupStep
    var familyPathChoice: FastFamilyPathChoice
    var familyName: String
    var joinCode: String

    var childDisplayName: String
    var childLegalName: String
    var childDateOfBirth: Date?
    var childGradeOrClass: String

    var schoolSearchQuery: String
    var schoolName: String
    var schoolAddress: String
    var schoolStartHour: Int
    var schoolStartMinute: Int
    var schoolEndHour: Int
    var schoolEndMinute: Int

    var routineDays: [FastRoutineDayDraft]
    var activities: [FastActivityDraft]

    var selectedMemberId: UUID?
    var selectedPersonId: UUID?
    var newPersonName: String
    var newPersonRelationship: String
    var newPersonRoleSuggestion: FastRoleSuggestion
    var newPersonPhone: String
}

@MainActor
final class FastFamilySetupWizardState: ObservableObject {
    @Published var step: FastFamilySetupStep = .welcome { didSet { persistDraft(); logStepTransition(old: oldValue, new: step) } }
    let totalSteps = FastFamilySetupStep.allCases.count

    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var completionMessage: String?

    @Published var hasExistingHousehold = false
    @Published var existingHouseholdName: String?
    @Published var householdId: UUID?

    @Published var familyPathChoice: FastFamilyPathChoice = .create { didSet { persistDraft() } }
    @Published var familyName: String = "" { didSet { persistDraft() } }
    @Published var joinCode: String = "" { didSet { persistDraft() } }

    @Published var childDisplayName: String = "" { didSet { persistDraft() } }
    @Published var childLegalName: String = "" { didSet { persistDraft() } }
    @Published var childDateOfBirth: Date? { didSet { persistDraft() } }
    @Published var childGradeOrClass: String = "" { didSet { persistDraft() } }

    @Published var schoolSearchQuery: String = "" { didSet { persistDraft() } }
    @Published var schoolSuggestions: [FastSchoolSuggestion] = []
    @Published var selectedSchoolSuggestionId: UUID?
    @Published var schoolName: String = "" { didSet { persistDraft() } }
    @Published var schoolAddress: String = "" { didSet { persistDraft() } }
    @Published var schoolStartHour: Int = 7 { didSet { persistDraft() } }
    @Published var schoolStartMinute: Int = 30 { didSet { persistDraft() } }
    @Published var schoolEndHour: Int = 14 { didSet { persistDraft() } }
    @Published var schoolEndMinute: Int = 30 { didSet { persistDraft() } }

    @Published var routineDays: [FastRoutineDayDraft] = FastFamilySetupWizardState.defaultRoutineDays() { didSet { persistDraft() } }
    @Published var activities: [FastActivityDraft] = [] { didSet { persistDraft() } }

    @Published var memberOptions: [FastMemberOption] = []
    @Published var personOptions: [FastPersonOption] = []
    @Published var selectedMemberId: UUID? { didSet { persistDraft() } }
    @Published var selectedPersonId: UUID? { didSet { persistDraft() } }
    @Published var newPersonName: String = "" { didSet { persistDraft() } }
    @Published var newPersonRelationship: String = "" { didSet { persistDraft() } }
    @Published var newPersonRoleSuggestion: FastRoleSuggestion = .helper { didSet { persistDraft() } }
    @Published var newPersonPhone: String = "" { didSet { persistDraft() } }

    private let authService: AuthService
    private let householdService: HouseholdBackendService
    private let childService: ChildBackendService
    private let peopleService: HouseholdPeopleBackendService
    private let scheduleService: ScheduleBackendService
    private let profileService: ProfileBackendService
    private let userDefaults: UserDefaults
    private let draftKey = "tb.onboarding.fastFamilySetup.v1"
    private var restoredSnapshot = false
    private var isRestoringDraft = false
    private var session: AuthUserSession?

    init() {
        self.authService = SupabaseAuthService()
        self.householdService = SupabaseHouseholdBackendService()
        self.childService = SupabaseChildBackendService()
        self.peopleService = SupabaseHouseholdPeopleBackendService()
        self.scheduleService = SupabaseScheduleBackendService()
        self.profileService = SupabaseProfileBackendService()
        self.userDefaults = .standard
    }

    init(
        authService: AuthService,
        householdService: HouseholdBackendService,
        childService: ChildBackendService,
        peopleService: HouseholdPeopleBackendService,
        scheduleService: ScheduleBackendService,
        profileService: ProfileBackendService,
        userDefaults: UserDefaults
    ) {
        self.authService = authService
        self.householdService = householdService
        self.childService = childService
        self.peopleService = peopleService
        self.scheduleService = scheduleService
        self.profileService = profileService
        self.userDefaults = userDefaults
    }

    func bootstrap() async {
        if !restoredSnapshot {
            restoredSnapshot = true
            restoreDraft()
        }
        do {
            session = try await authService.restoreSession()
            guard let session else {
                errorMessage = "No active session. Please sign in again."
                return
            }

            let memberships = try await householdService.fetchMyMemberships(session: session)
            let households = try await householdService.fetchMyHouseholds(session: session)
            let validHouseholdIds = Set(memberships.map(\.householdId))
            let preferred = userDefaults.activeHouseholdId
            let resolvedHouseholdId: UUID? = {
                if let preferred, validHouseholdIds.contains(preferred) { return preferred }
                return memberships.first?.householdId
            }()

            householdId = resolvedHouseholdId
            hasExistingHousehold = resolvedHouseholdId != nil
            if let resolvedHouseholdId {
                userDefaults.activeHouseholdId = resolvedHouseholdId
                existingHouseholdName = households.first(where: { $0.id == resolvedHouseholdId })?.name
                if step.rawValue < FastFamilySetupStep.addChild.rawValue {
                    step = .familyPath
                }
                await loadSchoolSuggestions(householdId: resolvedHouseholdId, session: session)
                try await loadAssignmentOptions(householdId: resolvedHouseholdId, session: session)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func goBack() {
        guard let previous = FastFamilySetupStep(rawValue: step.rawValue - 1) else { return }
        step = previous
    }

    func goNext() async {
        errorMessage = nil
        switch step {
        case .welcome:
            step = .familyPath
        case .familyPath:
            await handleFamilyPath()
        case .addChild:
            guard validateChild() else { return }
            step = .school
        case .school:
            guard validateSchool() else { return }
            applySchoolDefaultsToRoutine()
            step = .routine
        case .routine:
            guard validateRoutine() else { return }
            step = .activities
        case .activities:
            step = .assignment
        case .assignment:
            step = .review
        case .review:
            break
        }
    }

    func selectSchoolSuggestion(_ suggestion: FastSchoolSuggestion) {
        selectedSchoolSuggestionId = suggestion.id
        schoolSearchQuery = suggestion.schoolName
        schoolName = suggestion.schoolName
        schoolAddress = suggestion.schoolAddress ?? schoolAddress
        if let startHour = suggestion.startHour { schoolStartHour = startHour }
        if let startMinute = suggestion.startMinute { schoolStartMinute = startMinute }
        if let endHour = suggestion.endHour { schoolEndHour = endHour }
        if let endMinute = suggestion.endMinute { schoolEndMinute = endMinute }
        persistDraft()
    }

    func setRoutineDayEnabled(_ dayId: UUID, enabled: Bool) {
        guard let index = routineDays.firstIndex(where: { $0.id == dayId }) else { return }
        routineDays[index].isEnabled = enabled
    }

    func updateRoutineDayTime(_ dayId: UUID, startHour: Int, startMinute: Int, endHour: Int, endMinute: Int) {
        guard let index = routineDays.firstIndex(where: { $0.id == dayId }) else { return }
        routineDays[index].startHour = startHour
        routineDays[index].startMinute = startMinute
        routineDays[index].endHour = endHour
        routineDays[index].endMinute = endMinute
    }

    func addActivity(
        title: String,
        weekday: Weekday,
        hour: Int,
        minute: Int,
        location: String,
        atSchool: Bool
    ) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }
        activities.append(
            FastActivityDraft(
                id: UUID(),
                title: trimmedTitle,
                weekday: weekday,
                hour: hour,
                minute: minute,
                location: location.trimmingCharacters(in: .whitespacesAndNewlines),
                atSchool: atSchool
            )
        )
#if DEBUG
        print("[FastSetupWizard] partial save activities_count=\(activities.count)")
#endif
    }

    func removeActivity(_ id: UUID) {
        activities.removeAll { $0.id == id }
    }

    func complete(flow: AppFlowState) async -> Bool {
        guard validateChild(), validateSchool(), validateRoutine() else { return false }
        guard let session = try? await resolvedSession() else {
            errorMessage = "No active session."
            return false
        }

        isLoading = true
        defer { isLoading = false }

        do {
            if householdId == nil {
                await handleFamilyPath()
            }
            guard let householdId else {
                errorMessage = "Unable to resolve household."
                return false
            }

            let createdChild = try await childService.createChild(
                BackendChild(
                    id: UUID(),
                    householdId: householdId,
                    legalName: normalizedLegalName(),
                    displayName: childDisplayName.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                    dateOfBirth: formatDateOnly(childDateOfBirth),
                    schoolName: schoolName.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                    gradeOrClass: childGradeOrClass.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                    createdAt: nil,
                    updatedAt: nil
                ),
                session: session
            )

            let homeStop = SystemDomain.Stop(id: UUID(), name: "Home", latitude: 0, longitude: 0, order: 0)
            let schoolStop = SystemDomain.Stop(
                id: UUID(),
                name: schoolName.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "School",
                latitude: 0,
                longitude: 0,
                order: 1
            )

            var schedulesCreated = 0
            for day in routineDays where day.isEnabled {
                let weekday = backendWeekday(day.weekday)
                let dropoff = BackendScheduleTemplate(
                    id: UUID(),
                    householdId: householdId,
                    childId: createdChild.id,
                    title: "\(createdChild.displayName ?? createdChild.legalName) School Drop-off",
                    weekday: weekday,
                    departureTime: String(format: "%02d:%02d:00", day.startHour, day.startMinute),
                    createdAt: nil
                )
                let createdDropoff = try await scheduleService.createSchedule(dropoff)
                _ = try await scheduleService.replaceScheduleStops(
                    scheduleId: createdDropoff.id,
                    stops: [
                        BackendScheduleStop(
                            id: UUID(),
                            scheduleId: createdDropoff.id,
                            childId: createdChild.id,
                            label: homeStop.name,
                            latitude: 0,
                            longitude: 0,
                            stopOrder: 0
                        ),
                        BackendScheduleStop(
                            id: UUID(),
                            scheduleId: createdDropoff.id,
                            childId: createdChild.id,
                            label: schoolStop.name,
                            latitude: 0,
                            longitude: 0,
                            stopOrder: 1
                        )
                    ]
                )
                schedulesCreated += 1

                let pickup = BackendScheduleTemplate(
                    id: UUID(),
                    householdId: householdId,
                    childId: createdChild.id,
                    title: "\(createdChild.displayName ?? createdChild.legalName) School Pickup",
                    weekday: weekday,
                    departureTime: String(format: "%02d:%02d:00", day.endHour, day.endMinute),
                    createdAt: nil
                )
                let createdPickup = try await scheduleService.createSchedule(pickup)
                _ = try await scheduleService.replaceScheduleStops(
                    scheduleId: createdPickup.id,
                    stops: [
                        BackendScheduleStop(
                            id: UUID(),
                            scheduleId: createdPickup.id,
                            childId: createdChild.id,
                            label: schoolStop.name,
                            latitude: 0,
                            longitude: 0,
                            stopOrder: 0
                        ),
                        BackendScheduleStop(
                            id: UUID(),
                            scheduleId: createdPickup.id,
                            childId: createdChild.id,
                            label: homeStop.name,
                            latitude: 0,
                            longitude: 0,
                            stopOrder: 1
                        )
                    ]
                )
                schedulesCreated += 1
            }

            for activity in activities {
                let locationName: String? = activity.atSchool
                    ? schoolName.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
                    : activity.location.nilIfEmpty
                _ = try await childService.createChildActivity(
                    BackendChildActivity(
                        id: UUID(),
                        childId: createdChild.id,
                        householdId: householdId,
                        name: activity.title,
                        type: activity.atSchool ? ChildActivityType.schoolBased.rawValue : ChildActivityType.external.rawValue,
                        locationName: locationName,
                        days: [activity.weekday.rawValue],
                        startTime: String(format: "%02d:%02d", activity.hour, activity.minute),
                        endTime: nil,
                        createdAt: nil,
                        updatedAt: nil
                    ),
                    session: session
                )
            }

            if let selectedMemberId,
               let member = memberOptions.first(where: { $0.id == selectedMemberId }) {
                _ = try await householdService.updateMembershipAttributes(
                    membershipId: member.id,
                    role: nil,
                    status: nil,
                    familyRole: newPersonRoleSuggestion.rawValue,
                    relationshipLabel: nil,
                    session: session
                )
            }

            if !newPersonName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                _ = try await peopleService.createPerson(
                    BackendHouseholdPerson(
                        id: UUID(),
                        householdId: householdId,
                        name: newPersonName.trimmingCharacters(in: .whitespacesAndNewlines),
                        relationship: newPersonRelationship.nilIfEmpty,
                        role: newPersonRoleSuggestion.rawValue,
                        phone: newPersonPhone.nilIfEmpty,
                        isDriver: newPersonRoleSuggestion == .driver,
                        createdAt: nil,
                        updatedAt: nil
                    ),
                    session: session
                )
            }

            let updatedMemberships = try await householdService.fetchMyMemberships(session: session)
            var updatedChildIds = Set<UUID>()
            for householdId in Set(updatedMemberships.map(\.householdId)) {
                let householdChildren = try await childService.fetchChildren(householdId: householdId, session: session)
                updatedChildIds.formUnion(householdChildren.map(\.id))
            }
            flow.updateOnboardingSnapshot(
                membershipCount: updatedMemberships.count,
                childCount: updatedChildIds.count
            )

#if DEBUG
            print(
                "[FastSetupWizard] completion payload household_id=\(householdId.uuidString), " +
                "child=\(createdChild.id.uuidString), schedules_created=\(schedulesCreated), " +
                "activities_created=\(activities.count), assignment_member=\(selectedMemberId?.uuidString ?? "nil"), " +
                "assignment_person=\(selectedPersonId?.uuidString ?? "nil"), new_person=\(!newPersonName.isEmpty)"
            )
            print(
                "[FastSetupWizard] post-finish refresh pipeline memberships=\(updatedMemberships.count), " +
                "children=\(updatedChildIds.count), isOnboarded=\(flow.isOnboarded)"
            )
#endif
            clearDraft()
            completionMessage = "Setup complete."
            flow.completeOnboarding(startingTab: schedulesCreated > 0 ? .calendar : .home)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    var canMoveForward: Bool {
        switch step {
        case .welcome:
            return true
        case .familyPath:
            if hasExistingHousehold { return true }
            switch familyPathChoice {
            case .create:
                return !familyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            case .join:
                return !joinCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
        case .addChild:
            return validateChild(silent: true)
        case .school:
            return validateSchool(silent: true)
        case .routine:
            return validateRoutine(silent: true)
        case .activities, .assignment, .review:
            return true
        }
    }

    var filteredSchoolSuggestions: [FastSchoolSuggestion] {
        let query = schoolSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return schoolSuggestions }
        return schoolSuggestions.filter { suggestion in
            suggestion.schoolName.lowercased().contains(query)
        }
    }

    private func handleFamilyPath() async {
        if hasExistingHousehold, householdId != nil {
            step = .addChild
            return
        }
        do {
            let session = try await resolvedSession()
            switch familyPathChoice {
            case .create:
                let name = familyName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else {
                    errorMessage = "Family name is required."
                    return
                }
                let created = try await householdService.createHousehold(name: name, session: session)
                householdId = created.id
                existingHouseholdName = created.name
                hasExistingHousehold = true
            case .join:
                let code = joinCode.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !code.isEmpty else {
                    errorMessage = "Join code is required."
                    return
                }
                let joined = try await householdService.joinHouseholdByCode(code, session: session)
                householdId = joined.id
                existingHouseholdName = joined.name
                hasExistingHousehold = true
            }
            if let householdId {
                userDefaults.activeHouseholdId = householdId
                await loadSchoolSuggestions(householdId: householdId, session: session)
                try await loadAssignmentOptions(householdId: householdId, session: session)
                step = .addChild
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadSchoolSuggestions(householdId: UUID, session: AuthUserSession) async {
        do {
            let children = try await childService.fetchChildren(householdId: householdId, session: session)
            let grouped = Dictionary(grouping: children.compactMap { child -> (String, BackendChild)? in
                guard let school = child.schoolName?.trimmingCharacters(in: .whitespacesAndNewlines), !school.isEmpty else {
                    return nil
                }
                return (school, child)
            }, by: { $0.0.lowercased() })
            schoolSuggestions = grouped.values.compactMap { entries in
                guard let first = entries.first else { return nil }
                return FastSchoolSuggestion(
                    id: UUID(),
                    schoolName: first.0,
                    schoolAddress: nil,
                    startHour: schoolStartHour,
                    startMinute: schoolStartMinute,
                    endHour: schoolEndHour,
                    endMinute: schoolEndMinute
                )
            }
            .sorted { $0.schoolName.localizedCaseInsensitiveCompare($1.schoolName) == .orderedAscending }
        } catch {
#if DEBUG
            print("[FastSetupWizard] school suggestions load failed error=\(error.localizedDescription)")
#endif
        }
    }

    private func loadAssignmentOptions(householdId: UUID, session: AuthUserSession) async throws {
        let memberships = try await householdService.fetchHouseholdMembers(householdId: householdId, session: session)
        let userIds = memberships.map(\.userId)
        let profiles = try await profileService.fetchProfiles(userIds: userIds)
        let profileById = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0) })
        memberOptions = memberships
            .filter { $0.normalizedStatus == .active || $0.status == nil }
            .map { membership in
                let displayName = AuthBackedMemberDisplayResolver.resolveName(
                    profile: profileById[membership.userId],
                    relationshipLabel: membership.relationshipLabel
                )
                return FastMemberOption(
                    id: membership.id,
                    userId: membership.userId,
                    displayName: displayName,
                    role: membership.role,
                    status: membership.status
                )
            }
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }

        let people = try await peopleService.fetchPeople(householdId: householdId, session: session)
        personOptions = people.map { person in
            FastPersonOption(id: person.id, name: person.name, role: person.role, isDriver: person.isDriver)
        }
    }

    private func validateChild(silent: Bool = false) -> Bool {
        guard !childDisplayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            if !silent { errorMessage = "Child display name is required." }
            return false
        }
        return true
    }

    private func validateSchool(silent: Bool = false) -> Bool {
        guard !schoolName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            if !silent { errorMessage = "School name is required." }
            return false
        }
        guard !schoolAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            if !silent { errorMessage = "School address/location is required." }
            return false
        }
        return true
    }

    private func validateRoutine(silent: Bool = false) -> Bool {
        guard routineDays.contains(where: { $0.isEnabled }) else {
            if !silent { errorMessage = "Enable at least one school day." }
            return false
        }
        return true
    }

    private func normalizedLegalName() -> String {
        let legal = childLegalName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !legal.isEmpty { return legal }
        return childDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func applySchoolDefaultsToRoutine() {
        for index in routineDays.indices where routineDays[index].isEnabled {
            routineDays[index].startHour = schoolStartHour
            routineDays[index].startMinute = schoolStartMinute
            routineDays[index].endHour = schoolEndHour
            routineDays[index].endMinute = schoolEndMinute
        }
    }

    private func resolvedSession() async throws -> AuthUserSession {
        if let session { return session }
        if let restored = try await authService.restoreSession() {
            session = restored
            return restored
        }
        throw NSError(domain: "FastFamilySetupWizardState", code: 401, userInfo: [
            NSLocalizedDescriptionKey: "No active auth session."
        ])
    }

    private func restoreDraft() {
        guard let data = userDefaults.data(forKey: draftKey) else { return }
        guard let snapshot = try? JSONDecoder().decode(FastWizardSnapshot.self, from: data) else { return }
        isRestoringDraft = true
        defer { isRestoringDraft = false }

        step = snapshot.step
        familyPathChoice = snapshot.familyPathChoice
        familyName = snapshot.familyName
        joinCode = snapshot.joinCode
        childDisplayName = snapshot.childDisplayName
        childLegalName = snapshot.childLegalName
        childDateOfBirth = snapshot.childDateOfBirth
        childGradeOrClass = snapshot.childGradeOrClass
        schoolSearchQuery = snapshot.schoolSearchQuery
        schoolName = snapshot.schoolName
        schoolAddress = snapshot.schoolAddress
        schoolStartHour = snapshot.schoolStartHour
        schoolStartMinute = snapshot.schoolStartMinute
        schoolEndHour = snapshot.schoolEndHour
        schoolEndMinute = snapshot.schoolEndMinute
        routineDays = snapshot.routineDays
        activities = snapshot.activities
        selectedMemberId = snapshot.selectedMemberId
        selectedPersonId = snapshot.selectedPersonId
        newPersonName = snapshot.newPersonName
        newPersonRelationship = snapshot.newPersonRelationship
        newPersonRoleSuggestion = snapshot.newPersonRoleSuggestion
        newPersonPhone = snapshot.newPersonPhone
    }

    private func persistDraft() {
        guard !isRestoringDraft else { return }
        let snapshot = FastWizardSnapshot(
            step: step,
            familyPathChoice: familyPathChoice,
            familyName: familyName,
            joinCode: joinCode,
            childDisplayName: childDisplayName,
            childLegalName: childLegalName,
            childDateOfBirth: childDateOfBirth,
            childGradeOrClass: childGradeOrClass,
            schoolSearchQuery: schoolSearchQuery,
            schoolName: schoolName,
            schoolAddress: schoolAddress,
            schoolStartHour: schoolStartHour,
            schoolStartMinute: schoolStartMinute,
            schoolEndHour: schoolEndHour,
            schoolEndMinute: schoolEndMinute,
            routineDays: routineDays,
            activities: activities,
            selectedMemberId: selectedMemberId,
            selectedPersonId: selectedPersonId,
            newPersonName: newPersonName,
            newPersonRelationship: newPersonRelationship,
            newPersonRoleSuggestion: newPersonRoleSuggestion,
            newPersonPhone: newPersonPhone
        )
        if let data = try? JSONEncoder().encode(snapshot) {
            userDefaults.set(data, forKey: draftKey)
#if DEBUG
            print("[FastSetupWizard] partial save state step=\(step.rawValue + 1)")
#endif
        }
    }

    private func clearDraft() {
        userDefaults.removeObject(forKey: draftKey)
    }

    private func backendWeekday(_ weekday: Weekday) -> String {
        switch weekday {
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

    private func logStepTransition(old: FastFamilySetupStep, new: FastFamilySetupStep) {
        guard old != new else { return }
#if DEBUG
        print("[FastSetupWizard] step transition from=\(old.rawValue + 1) to=\(new.rawValue + 1)")
#endif
    }

    private static func defaultRoutineDays() -> [FastRoutineDayDraft] {
        Weekday.allCases.map { weekday in
            FastRoutineDayDraft(
                id: UUID(),
                weekday: weekday,
                isEnabled: weekday == .monday || weekday == .tuesday || weekday == .wednesday || weekday == .thursday || weekday == .friday,
                startHour: 7,
                startMinute: 30,
                endHour: 14,
                endMinute: 30
            )
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
