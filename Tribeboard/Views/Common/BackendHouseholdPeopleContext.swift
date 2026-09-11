import Foundation
import Combine

@MainActor
final class BackendHouseholdPeopleContext: ObservableObject {
    @Published private(set) var people: [BackendHouseholdPerson] = []
    @Published private(set) var isLoading: Bool = false
    @Published var lastError: String?

    private let service: HouseholdPeopleBackendService
    private let authService: AuthService
    private let activeHouseholdStore: ActiveHouseholdStore
    private var currentSession: AuthUserSession?
    private var activeHouseholdId: UUID?
    private var isRefreshInFlight = false
    private var hasPendingRefresh = false

    init(
        service: HouseholdPeopleBackendService? = nil,
        authService: AuthService? = nil,
        activeHouseholdStore: ActiveHouseholdStore
    ) {
        self.service = service ?? SupabaseHouseholdPeopleBackendService()
        self.authService = authService ?? SupabaseAuthService()
        self.activeHouseholdStore = activeHouseholdStore
    }

    func refreshForActiveHousehold() async {
        guard let householdId = activeHouseholdStore.activeHouseholdId else {
            people = []
            lastError = nil
            return
        }
        await refreshPeople(householdId: householdId)
    }

    func refreshPeople(householdId: UUID) async {
        activeHouseholdId = householdId
        if isRefreshInFlight {
            hasPendingRefresh = true
            return
        }
        isRefreshInFlight = true
        isLoading = true
        defer {
            isLoading = false
            isRefreshInFlight = false
        }
        do {
            guard let session = try await ensuredSession() else {
                lastError = BackendUserFacingErrorMapper.noActiveSession
                people = []
                return
            }
            let fetched = try await service.fetchPeople(householdId: householdId, session: session)
#if DEBUG
            print(
                "[BackendHouseholdPeopleContext] fetch returned rows=\(fetched.count), " +
                "activeHouseholdId=\(householdId.uuidString)"
            )
#endif
            await MainActor.run {
                people = fetched
                lastError = nil
            }
#if DEBUG
            print(
                "[BackendHouseholdPeopleContext] published people_count=\(people.count), " +
                "activeHouseholdId=\(householdId.uuidString)"
            )
#endif
        } catch {
            lastError = BackendUserFacingErrorMapper.message(for: error) ?? BackendUserFacingErrorMapper.genericLoadFailure
        }
        if hasPendingRefresh, let activeHouseholdId {
            hasPendingRefresh = false
            await refreshPeople(householdId: activeHouseholdId)
        }
    }

    @discardableResult
    func createPerson(
        name: String,
        relationship: String?,
        role: String,
        phone: String?,
        isDriver: Bool
    ) async -> Bool {
        isLoading = true
        defer { isLoading = false }
        do {
            guard let householdId = activeHouseholdStore.activeHouseholdId else {
                lastError = "No active backend household."
                return false
            }
            guard let session = try await ensuredSession() else {
                lastError = "No active auth session."
                return false
            }
            let created = try await service.createPerson(
                BackendHouseholdPerson(
                    id: UUID(),
                    householdId: householdId,
                    name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                    relationship: relationship?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                    role: role.lowercased(),
                    phone: phone?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                    isDriver: isDriver,
                    createdAt: nil,
                    updatedAt: nil
                ),
                session: session
            )
            people.removeAll { $0.id == created.id }
            people.append(created)
            people.sort { ($0.createdAtDate ?? .distantPast) < ($1.createdAtDate ?? .distantPast) }
            lastError = nil
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    @discardableResult
    func updatePerson(_ person: BackendHouseholdPerson) async -> Bool {
        isLoading = true
        defer { isLoading = false }
        do {
            guard let session = try await ensuredSession() else {
                lastError = "No active auth session."
                return false
            }
            let updated = try await service.updatePerson(
                BackendHouseholdPerson(
                    id: person.id,
                    householdId: person.householdId,
                    name: person.name.trimmingCharacters(in: .whitespacesAndNewlines),
                    relationship: person.relationship?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                    role: person.role.lowercased(),
                    phone: person.phone?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                    isDriver: person.isDriver,
                    createdAt: person.createdAt,
                    updatedAt: person.updatedAt
                ),
                session: session
            )
            people.removeAll { $0.id == updated.id }
            people.append(updated)
            people.sort { ($0.createdAtDate ?? .distantPast) < ($1.createdAtDate ?? .distantPast) }
            lastError = nil
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    @discardableResult
    func deletePerson(id: UUID) async -> Bool {
        isLoading = true
        defer { isLoading = false }
        do {
            guard let session = try await ensuredSession() else {
                lastError = "No active auth session."
                return false
            }
            try await service.deletePerson(id: id, session: session)
            people.removeAll { $0.id == id }
            lastError = nil
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    func person(for id: UUID) -> BackendHouseholdPerson? {
        people.first(where: { $0.id == id })
    }

    func mapAdultMemberToBackendRole(_ member: TribeMember) -> String {
        if member.roles.contains(.driver) {
            return "driver"
        }
        if member.roles.contains(.parent) || member.roles.contains(.admin) {
            return "parent"
        }
        if member.roles.contains(.observer) {
            return "helper"
        }
        return "other"
    }

    func mapToTribeMember(_ person: BackendHouseholdPerson) -> TribeMember {
        var roles: Set<Role> = []
        switch person.role.lowercased() {
        case "driver":
            roles.insert(.driver)
        case "parent", "guardian":
            roles.insert(.parent)
            roles.insert(.observer)
        case "helper", "relative", "other":
            roles.insert(.observer)
        default:
            roles.insert(.observer)
        }
        if person.isDriver {
            roles.insert(.driver)
        }
        if roles.isEmpty {
            roles.insert(.observer)
        }
        return TribeMember(
            id: person.id,
            fullName: person.name,
            avatarType: AvatarType(rawValue: person.avatarType ?? AvatarType.preset.rawValue),
            avatarKey: person.avatarKey ?? AvatarPresetCatalog.defaultExtendedTribeKey,
            avatarURL: person.avatarURL,
            memberType: .adult,
            relationship: person.relationship?.nilIfEmpty ?? person.role.capitalized,
            phone: person.phone,
            roles: roles,
            isLocationSharingEnabled: false,
            isOnline: false
        )
    }

    func reset() {
        people = []
        isLoading = false
        lastError = nil
        currentSession = nil
        activeHouseholdId = nil
        isRefreshInFlight = false
        hasPendingRefresh = false
    }

    private func ensuredSession() async throws -> AuthUserSession? {
        if let currentSession {
            return currentSession
        }
        let restored = try await authService.restoreSession()
        currentSession = restored
        return restored
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
