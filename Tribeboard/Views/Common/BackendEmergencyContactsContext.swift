import Foundation
import Combine

@MainActor
final class BackendEmergencyContactsContext: ObservableObject {
    @Published private(set) var contacts: [BackendEmergencyContact] = []
    @Published private(set) var isLoading: Bool = false
    @Published var lastError: String?

    private let service: EmergencyContactsBackendService
    private let authService: AuthService
    private let activeHouseholdStore: ActiveHouseholdStore
    private var currentSession: AuthUserSession?
    private var activeHouseholdId: UUID?
    private var isRefreshInFlight = false
    private var hasPendingRefresh = false

    init(
        service: EmergencyContactsBackendService? = nil,
        authService: AuthService? = nil,
        activeHouseholdStore: ActiveHouseholdStore
    ) {
        self.service = service ?? SupabaseEmergencyContactsBackendService()
        self.authService = authService ?? SupabaseAuthService()
        self.activeHouseholdStore = activeHouseholdStore
    }

    var contactCount: Int {
        contacts.count
    }

    func refreshForActiveHousehold() async {
        guard let householdId = activeHouseholdStore.activeHouseholdId else {
            contacts = []
            lastError = "No active backend household."
            return
        }
        await refreshContacts(householdId: householdId)
    }

    func refreshContacts(householdId: UUID) async {
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
                lastError = "No active auth session."
                contacts = []
                return
            }
            let fetched = try await service.fetchContacts(householdId: householdId, session: session)
            contacts = Self.sorted(fetched)
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
        if hasPendingRefresh, let activeHouseholdId {
            hasPendingRefresh = false
            await refreshContacts(householdId: activeHouseholdId)
        }
    }

    @discardableResult
    func createContact(
        name: String,
        relationship: String?,
        phone: String,
        email: String?,
        canPickUpChild: Bool,
        notes: String?
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
            let priority = (contacts.map(\.priority).max() ?? 0) + 1
            let created = try await service.createContact(
                BackendEmergencyContact(
                    id: UUID(),
                    householdId: householdId,
                    name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                    relationship: relationship?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                    phone: phone.trimmingCharacters(in: .whitespacesAndNewlines),
                    email: email?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                    priority: priority,
                    canPickUpChild: canPickUpChild,
                    notes: notes?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                    createdBy: session.userUUID,
                    createdAt: nil,
                    updatedAt: nil
                ),
                session: session
            )
            contacts.removeAll { $0.id == created.id }
            contacts.append(created)
            contacts = Self.sorted(contacts)
            lastError = nil
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    @discardableResult
    func updateContact(_ contact: BackendEmergencyContact) async -> Bool {
        isLoading = true
        defer { isLoading = false }
        do {
            guard let session = try await ensuredSession() else {
                lastError = "No active auth session."
                return false
            }
            let updated = try await service.updateContact(
                BackendEmergencyContact(
                    id: contact.id,
                    householdId: contact.householdId,
                    name: contact.name.trimmingCharacters(in: .whitespacesAndNewlines),
                    relationship: contact.relationship?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                    phone: contact.phone.trimmingCharacters(in: .whitespacesAndNewlines),
                    email: contact.email?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                    priority: contact.priority,
                    canPickUpChild: contact.canPickUpChild,
                    notes: contact.notes?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                    createdBy: contact.createdBy,
                    createdAt: contact.createdAt,
                    updatedAt: contact.updatedAt
                ),
                session: session
            )
            contacts.removeAll { $0.id == updated.id }
            contacts.append(updated)
            contacts = Self.sorted(contacts)
            lastError = nil
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    @discardableResult
    func deleteContact(id: UUID) async -> Bool {
        isLoading = true
        defer { isLoading = false }
        do {
            guard let session = try await ensuredSession() else {
                lastError = "No active auth session."
                return false
            }
            try await service.deleteContact(id: id, session: session)
            contacts.removeAll { $0.id == id }
            lastError = nil
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    func contact(for id: UUID) -> BackendEmergencyContact? {
        contacts.first(where: { $0.id == id })
    }

    func reset() {
        contacts = []
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

    private static func sorted(_ items: [BackendEmergencyContact]) -> [BackendEmergencyContact] {
        items.sorted {
            if $0.priority != $1.priority {
                return $0.priority < $1.priority
            }
            return ($0.createdAtDate ?? .distantPast) < ($1.createdAtDate ?? .distantPast)
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
