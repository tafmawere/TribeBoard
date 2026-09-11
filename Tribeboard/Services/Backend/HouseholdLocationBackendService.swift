import Foundation

struct BackendHouseholdLocation: Codable, Identifiable, Hashable {
    let id: UUID
    let householdId: UUID
    let label: String
    var name: String?
    var locationTypeRaw: String?
    let placeId: String?
    let formattedAddress: String
    let latitude: Double
    let longitude: Double
    var city: String?
    var province: String?
    var country: String?
    var postalCode: String?
    let provider: String?
    let isVerified: Bool
    let createdBy: UUID?
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case householdId = "household_id"
        case label
        case name
        case locationTypeRaw = "location_type"
        case placeId = "place_id"
        case formattedAddress = "formatted_address"
        case latitude
        case longitude
        case city
        case province
        case country
        case postalCode = "postal_code"
        case provider
        case isVerified = "is_verified"
        case createdBy = "created_by"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct HouseholdLocationDraft: Identifiable, Hashable {
    let id: UUID
    var name: String
    var label: String
    var locationType: HouseholdLocationType
    var formattedAddress: String
    var latitude: Double?
    var longitude: Double?
    var placeId: String?
    var city: String?
    var province: String?
    var country: String?
    var postalCode: String?

    init(
        id: UUID = UUID(),
        name: String,
        label: String? = nil,
        locationType: HouseholdLocationType = .custom,
        formattedAddress: String = "",
        latitude: Double? = nil,
        longitude: Double? = nil,
        placeId: String? = nil,
        city: String? = nil,
        province: String? = nil,
        country: String? = nil,
        postalCode: String? = nil
    ) {
        self.id = id
        self.name = name
        self.label = label ?? name
        self.locationType = locationType
        self.formattedAddress = formattedAddress
        self.latitude = latitude
        self.longitude = longitude
        self.placeId = placeId
        self.city = city
        self.province = province
        self.country = country
        self.postalCode = postalCode
    }

    init(from location: BackendHouseholdLocation) {
        self.init(
            id: location.id,
            name: location.displayName,
            label: location.label,
            locationType: location.locationType,
            formattedAddress: location.formattedAddress,
            latitude: location.latitude,
            longitude: location.longitude,
            placeId: location.placeId,
            city: location.city,
            province: location.province,
            country: location.country,
            postalCode: location.postalCode
        )
    }

    init(from resolved: ResolvedLocationDraft, locationType: HouseholdLocationType = .custom) {
        self.init(
            id: resolved.id,
            name: resolved.title,
            label: resolved.title,
            locationType: locationType,
            formattedAddress: resolved.address,
            latitude: resolved.latitude,
            longitude: resolved.longitude,
            placeId: resolved.placeId
        )
    }
}

protocol HouseholdLocationBackendService {
    func fetchLocations(householdId: UUID, session: AuthUserSession) async throws -> [BackendHouseholdLocation]
    func fetchHomeLocation(householdId: UUID, session: AuthUserSession) async throws -> BackendHouseholdLocation?
    func createLocation(
        householdId: UUID,
        draft: HouseholdLocationDraft,
        isVerified: Bool,
        session: AuthUserSession
    ) async throws -> BackendHouseholdLocation
    func updateLocation(
        _ location: BackendHouseholdLocation,
        draft: HouseholdLocationDraft,
        isVerified: Bool,
        session: AuthUserSession
    ) async throws -> BackendHouseholdLocation
    func deleteLocation(id: UUID, householdId: UUID, session: AuthUserSession) async throws
    func setDefaultHome(
        householdId: UUID,
        locationId: UUID,
        session: AuthUserSession
    ) async throws -> BackendHouseholdLocation
    func findLocationByNameOrLabel(
        _ query: String,
        in locations: [BackendHouseholdLocation],
        preferredType: HouseholdLocationType?
    ) -> BackendHouseholdLocation?
    func upsertHomeLocation(
        householdId: UUID,
        location: ResolvedLocationDraft,
        isVerified: Bool,
        session: AuthUserSession
    ) async throws -> BackendHouseholdLocation
}

struct SupabaseHouseholdLocationBackendService: HouseholdLocationBackendService {
    enum ServiceError: LocalizedError {
        case notAuthenticated
        case invalidCoordinates
        case locationReferenced
        case requestFailed(String)

        var errorDescription: String? {
            switch self {
            case .notAuthenticated:
                return "No authenticated session."
            case .invalidCoordinates:
                return "A verified location with coordinates is required."
            case .locationReferenced:
                return "This location is linked to a child, activity, or schedule and cannot be deleted."
            case .requestFailed(let message):
                return message
            }
        }
    }

    private struct LocationPayload: Encodable {
        let household_id: UUID
        let label: String
        let name: String?
        let location_type: String
        let place_id: String?
        let formatted_address: String
        let latitude: Double
        let longitude: Double
        let city: String?
        let province: String?
        let country: String?
        let postal_code: String?
        let provider: String
        let is_verified: Bool
        let created_by: UUID?
        let updated_at: String
    }

    private let authService: AuthService
    private let table = "household_locations"

    init(authService: AuthService = SupabaseAuthService()) {
        self.authService = authService
    }

    func fetchLocations(householdId: UUID, session: AuthUserSession) async throws -> [BackendHouseholdLocation] {
        let path =
            "\(table)?select=*&household_id=eq.\(householdId.uuidString)" +
            "&order=location_type.asc,label.asc"
        return try await get(path: path, accessToken: session.accessToken)
    }

    func fetchHomeLocation(householdId: UUID, session: AuthUserSession) async throws -> BackendHouseholdLocation? {
        let locations = try await fetchLocations(householdId: householdId, session: session)
        if let home = locations.first(where: { $0.locationType == .home || $0.label.lowercased() == "home" }) {
            return home
        }
        return nil
    }

    func createLocation(
        householdId: UUID,
        draft: HouseholdLocationDraft,
        isVerified: Bool,
        session: AuthUserSession
    ) async throws -> BackendHouseholdLocation {
        guard let userId = UUID(uuidString: session.userId) else {
            throw ServiceError.notAuthenticated
        }
        let payload = try makePayload(
            householdId: householdId,
            draft: draft,
            isVerified: isVerified,
            createdBy: userId
        )
        let rows: [BackendHouseholdLocation] = try await post(
            table: table,
            payload: [payload],
            accessToken: session.accessToken
        )
        guard let saved = rows.first else {
            throw ServiceError.requestFailed("Failed to create location.")
        }
        return saved
    }

    func updateLocation(
        _ location: BackendHouseholdLocation,
        draft: HouseholdLocationDraft,
        isVerified: Bool,
        session: AuthUserSession
    ) async throws -> BackendHouseholdLocation {
        let payload = try makePayload(
            householdId: location.householdId,
            draft: draft,
            isVerified: isVerified,
            createdBy: location.createdBy
        )
        let path = "\(table)?id=eq.\(location.id.uuidString)"
        let rows: [BackendHouseholdLocation] = try await patch(
            path: path,
            payload: [payload],
            accessToken: session.accessToken
        )
        guard let saved = rows.first else {
            throw ServiceError.requestFailed("Failed to update location.")
        }
        return saved
    }

    func deleteLocation(id: UUID, householdId: UUID, session: AuthUserSession) async throws {
        let referenced = try await isLocationReferenced(id: id, session: session)
        if referenced {
            throw ServiceError.locationReferenced
        }
        let path = "\(table)?id=eq.\(id.uuidString)&household_id=eq.\(householdId.uuidString)"
        _ = try await delete(path: path, accessToken: session.accessToken) as [BackendHouseholdLocation]
    }

    func setDefaultHome(
        householdId: UUID,
        locationId: UUID,
        session: AuthUserSession
    ) async throws -> BackendHouseholdLocation {
        let locations = try await fetchLocations(householdId: householdId, session: session)
        guard var target = locations.first(where: { $0.id == locationId }) else {
            throw ServiceError.requestFailed("Location not found.")
        }
        var draft = HouseholdLocationDraft(from: target)
        draft.locationType = .home
        draft.label = "home"
        if draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            draft.name = "Home"
        }
        target = try await updateLocation(target, draft: draft, isVerified: target.isVerified, session: session)
        return target
    }

    func findLocationByNameOrLabel(
        _ query: String,
        in locations: [BackendHouseholdLocation],
        preferredType: HouseholdLocationType? = nil
    ) -> BackendHouseholdLocation? {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return nil }

        func matches(_ location: BackendHouseholdLocation) -> Bool {
            let candidates = [
                location.displayName.lowercased(),
                location.label.lowercased(),
                location.formattedAddress.lowercased()
            ]
            return candidates.contains(normalized) || candidates.contains(where: { normalized.contains($0) || $0.contains(normalized) })
        }

        if let preferredType {
            if let exact = locations.first(where: { $0.locationType == preferredType && matches($0) }) {
                return exact
            }
        }
        return locations.first(where: matches)
    }

    func upsertHomeLocation(
        householdId: UUID,
        location: ResolvedLocationDraft,
        isVerified: Bool,
        session: AuthUserSession
    ) async throws -> BackendHouseholdLocation {
        let draft = HouseholdLocationDraft(
            from: location,
            locationType: .home
        )
        var mutableDraft = draft
        mutableDraft.label = "home"
        if mutableDraft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            mutableDraft.name = "Home"
        }

        if let existing = try await fetchHomeLocation(householdId: householdId, session: session) {
            return try await updateLocation(existing, draft: mutableDraft, isVerified: isVerified, session: session)
        }
        return try await createLocation(
            householdId: householdId,
            draft: mutableDraft,
            isVerified: isVerified,
            session: session
        )
    }

    private func makePayload(
        householdId: UUID,
        draft: HouseholdLocationDraft,
        isVerified: Bool,
        createdBy: UUID?
    ) throws -> LocationPayload {
        try HouseholdLocationCoordinateValidator.validate(
            latitude: draft.latitude,
            longitude: draft.longitude
        )
        guard let latitude = draft.latitude, let longitude = draft.longitude else {
            throw ServiceError.invalidCoordinates
        }
        let address = draft.formattedAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !address.isEmpty else {
            throw ServiceError.requestFailed("Address is required.")
        }
        let label = draft.label.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return LocationPayload(
            household_id: householdId,
            label: label.isEmpty ? draft.locationType.rawValue : label,
            name: name.nilIfEmpty,
            location_type: draft.locationType.rawValue,
            place_id: draft.placeId,
            formatted_address: address,
            latitude: latitude,
            longitude: longitude,
            city: draft.city?.nilIfEmpty,
            province: draft.province?.nilIfEmpty,
            country: draft.country?.nilIfEmpty,
            postal_code: draft.postalCode?.nilIfEmpty,
            provider: "google",
            is_verified: isVerified,
            created_by: createdBy,
            updated_at: ISO8601DateFormatter().string(from: Date())
        )
    }

    private struct IdRow: Decodable { let id: UUID }

    private func isLocationReferenced(id: UUID, session: AuthUserSession) async throws -> Bool {
        let idString = id.uuidString
        let checks: [String] = [
            "children?school_location_id=eq.\(idString)&select=id&limit=1",
            "child_activities?location_id=eq.\(idString)&select=id&limit=1",
            "schedule_stops?location_id=eq.\(idString)&select=id&limit=1",
            "run_stops?location_id=eq.\(idString)&select=id&limit=1"
        ]
        for path in checks {
            let rows: [IdRow] = try await get(path: path, accessToken: session.accessToken)
            if !rows.isEmpty { return true }
        }
        return false
    }

    private func get<T: Decodable>(path: String, accessToken: String) async throws -> T {
        let url = try SupabaseClientProvider.restURL(path: path)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = try SupabaseClientProvider.defaultHeaders(accessToken: accessToken)
        return try await perform(request)
    }

    private func post<T: Decodable, P: Encodable>(table: String, payload: P, accessToken: String) async throws -> T {
        let url = try SupabaseClientProvider.restURL(path: table)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        var headers = try SupabaseClientProvider.defaultHeaders(accessToken: accessToken)
        headers["Prefer"] = "return=representation"
        request.allHTTPHeaderFields = headers
        request.httpBody = try JSONEncoder().encode(payload)
        return try await perform(request)
    }

    private func patch<T: Decodable, P: Encodable>(path: String, payload: P, accessToken: String) async throws -> T {
        let url = try SupabaseClientProvider.restURL(path: path)
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        var headers = try SupabaseClientProvider.defaultHeaders(accessToken: accessToken)
        headers["Prefer"] = "return=representation"
        request.allHTTPHeaderFields = headers
        request.httpBody = try JSONEncoder().encode(payload)
        return try await perform(request)
    }

    private func delete<T: Decodable>(path: String, accessToken: String) async throws -> T {
        let url = try SupabaseClientProvider.restURL(path: path)
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        var headers = try SupabaseClientProvider.defaultHeaders(accessToken: accessToken)
        headers["Prefer"] = "return=representation"
        request.allHTTPHeaderFields = headers
        return try await perform(request)
    }

    private func perform<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ServiceError.requestFailed("Invalid backend response.")
        }
        let bodyText = String(data: data, encoding: .utf8) ?? ""
        guard (200..<300).contains(http.statusCode) else {
            throw ServiceError.requestFailed(
                "Backend request failed (\(http.statusCode)): \(bodyText.isEmpty ? "Unknown error." : bodyText)"
            )
        }
        if data.isEmpty, let empty = [] as? T {
            return empty
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
