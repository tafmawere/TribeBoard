import Foundation
import Combine

@MainActor
final class BackendHouseholdLocationsContext: ObservableObject {
    @Published private(set) var locations: [BackendHouseholdLocation] = []
    @Published private(set) var isLoading = false
    @Published var lastError: String?

    private let service: HouseholdLocationBackendService
    private let authService: AuthService
    private let householdContext: BackendHouseholdContext
    private var currentSession: AuthUserSession?

    init(
        service: HouseholdLocationBackendService? = nil,
        authService: AuthService? = nil,
        householdContext: BackendHouseholdContext
    ) {
        self.service = service ?? SupabaseHouseholdLocationBackendService()
        self.authService = authService ?? SupabaseAuthService()
        self.householdContext = householdContext
    }

    var homeLocation: BackendHouseholdLocation? {
        locations.first(where: { $0.locationType == .home || $0.label.lowercased() == "home" })
    }

    func locations(ofType type: HouseholdLocationType) -> [BackendHouseholdLocation] {
        locations.filter { $0.locationType == type }
    }

    func location(id: UUID) -> BackendHouseholdLocation? {
        locations.first(where: { $0.id == id })
    }

    func refreshForActiveHousehold() async {
        guard let householdId = householdContext.activeHouseholdId else {
            locations = []
            lastError = nil
            return
        }
        await refresh(householdId: householdId)
    }

    func refresh(householdId: UUID) async {
        isLoading = true
        defer { isLoading = false }
        do {
            guard let session = try await ensuredSession() else {
                lastError = "No active auth session."
                return
            }
            locations = try await service.fetchLocations(householdId: householdId, session: session)
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    @discardableResult
    func saveLocation(
        draft: HouseholdLocationDraft,
        existingId: UUID? = nil,
        isVerified: Bool = true
    ) async -> BackendHouseholdLocation? {
        guard let householdId = householdContext.activeHouseholdId else {
            lastError = "No active household."
            return nil
        }
        isLoading = true
        defer { isLoading = false }
        do {
            guard let session = try await ensuredSession() else {
                lastError = "No active auth session."
                return nil
            }
            let saved: BackendHouseholdLocation
            if let existingId, let existing = locations.first(where: { $0.id == existingId }) {
                saved = try await service.updateLocation(
                    existing,
                    draft: draft,
                    isVerified: isVerified,
                    session: session
                )
            } else {
                saved = try await service.createLocation(
                    householdId: householdId,
                    draft: draft,
                    isVerified: isVerified,
                    session: session
                )
            }
            if let index = locations.firstIndex(where: { $0.id == saved.id }) {
                locations[index] = saved
            } else {
                locations.append(saved)
            }
            locations.sort {
                if $0.locationType.rawValue == $1.locationType.rawValue {
                    return $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
                }
                return $0.locationType.rawValue < $1.locationType.rawValue
            }
            lastError = nil
            return saved
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }

    func deleteLocation(id: UUID) async -> Bool {
        guard let householdId = householdContext.activeHouseholdId else {
            lastError = "No active household."
            return false
        }
        isLoading = true
        defer { isLoading = false }
        do {
            guard let session = try await ensuredSession() else {
                lastError = "No active auth session."
                return false
            }
            try await service.deleteLocation(id: id, householdId: householdId, session: session)
            locations.removeAll { $0.id == id }
            lastError = nil
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    func setDefaultHome(locationId: UUID) async -> Bool {
        guard let householdId = householdContext.activeHouseholdId else {
            lastError = "No active household."
            return false
        }
        isLoading = true
        defer { isLoading = false }
        do {
            guard let session = try await ensuredSession() else {
                lastError = "No active auth session."
                return false
            }
            let saved = try await service.setDefaultHome(
                householdId: householdId,
                locationId: locationId,
                session: session
            )
            if let index = locations.firstIndex(where: { $0.id == saved.id }) {
                locations[index] = saved
            }
            lastError = nil
            await refresh(householdId: householdId)
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    func findLocationByNameOrLabel(
        _ query: String,
        preferredType: HouseholdLocationType? = nil
    ) -> BackendHouseholdLocation? {
        service.findLocationByNameOrLabel(query, in: locations, preferredType: preferredType)
    }

    func resolveStop(
        label: String,
        preferredType: HouseholdLocationType? = nil
    ) -> SystemDomain.Stop? {
        guard let match = findLocationByNameOrLabel(label, preferredType: preferredType) else {
            return nil
        }
        return SystemDomain.Stop(
            id: UUID(),
            name: match.displayName,
            latitude: match.latitude,
            longitude: match.longitude,
            order: 0,
            locationId: match.id
        )
    }

    func reset() {
        locations = []
        isLoading = false
        lastError = nil
        currentSession = nil
    }

    private func ensuredSession() async throws -> AuthUserSession? {
        if let currentSession { return currentSession }
        let restored = try await authService.restoreSession()
        currentSession = restored
        return restored
    }
}
