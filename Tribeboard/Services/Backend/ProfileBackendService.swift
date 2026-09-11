import Foundation

protocol ProfileBackendService {
    func currentAuthUserId() async throws -> UUID
    func fetchMyProfile() async throws -> BackendProfile?
    func fetchProfiles(userIds: [UUID]) async throws -> [BackendProfile]
    func upsertMyProfile(
        email: String?,
        displayName: String?,
        firstName: String?,
        lastName: String?,
        avatarURL: String?
    ) async throws
    func patchMyProfile(fields: [String: String?]) async throws
}

struct SupabaseProfileBackendService: ProfileBackendService {
    enum ServiceError: LocalizedError {
        case notAuthenticated
        case invalidUserId
        case requestFailed(String)

        var errorDescription: String? {
            switch self {
            case .notAuthenticated:
                return "No authenticated session."
            case .invalidUserId:
                return "Authenticated user id is not a valid UUID."
            case .requestFailed(let message):
                return message
            }
        }
    }

    private struct UpsertPayload: Encodable {
        let id: UUID
        let email: String?
        let display_name: String?
        let first_name: String?
        let last_name: String?
        let avatar_url: String?
    }

    private let authService: AuthService

    init(authService: AuthService = SupabaseAuthService()) {
        self.authService = authService
    }

    func fetchMyProfile() async throws -> BackendProfile? {
        let session = try await resolvedSession()
        let path = "profiles?select=*&id=eq.\(session.userId.uuidString)&limit=1"
        let profiles: [BackendProfile] = try await get(path: path, accessToken: session.accessToken)
        return profiles.first
    }

    func currentAuthUserId() async throws -> UUID {
        let session = try await resolvedSession()
        return session.userId
    }

    func fetchProfiles(userIds: [UUID]) async throws -> [BackendProfile] {
        let uniqueIds = Array(Set(userIds))
        guard !uniqueIds.isEmpty else { return [] }
        let session = try await resolvedSession()
        let idsParam = uniqueIds.map(\.uuidString).joined(separator: ",")
        let path = "profiles?select=*&id=in.(\(idsParam))"
        let profiles: [BackendProfile] = try await get(path: path, accessToken: session.accessToken)
        return profiles
    }

    func upsertMyProfile(
        email: String?,
        displayName: String?,
        firstName: String? = nil,
        lastName: String? = nil,
        avatarURL: String? = nil
    ) async throws {
        let session = try await resolvedSession()
        let payload = [
            UpsertPayload(
                id: session.userId,
                email: email,
                display_name: displayName,
                first_name: firstName,
                last_name: lastName,
                avatar_url: avatarURL
            )
        ]
        _ = try await post(
            table: "profiles",
            payload: payload,
            accessToken: session.accessToken
        ) as [BackendProfile]
    }

    func patchMyProfile(fields: [String: String?]) async throws {
        guard !fields.isEmpty else { return }
        let session = try await resolvedSession()
        let path = "profiles?id=eq.\(session.userId.uuidString)"
        _ = try await patch(path: path, payload: fields, accessToken: session.accessToken) as [BackendProfile]
    }

    private func resolvedSession() async throws -> (userId: UUID, accessToken: String) {
        guard let session = try await authService.restoreSession() else {
            throw ServiceError.notAuthenticated
        }
        guard let userId = UUID(uuidString: session.userId) else {
            throw ServiceError.invalidUserId
        }
        return (userId: userId, accessToken: session.accessToken)
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
        headers["Prefer"] = "resolution=merge-duplicates,return=representation"
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

    private func perform<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ServiceError.requestFailed("Invalid backend response.")
        }
        let bodyText = String(data: data, encoding: .utf8) ?? ""
#if DEBUG
        print(
            "[ProfileBackendService] HTTP status=\(http.statusCode), path=\(request.url?.absoluteString ?? "unknown"), " +
            "raw_response=\(bodyText)"
        )
#endif
        guard (200..<300).contains(http.statusCode) else {
            throw ServiceError.requestFailed("Backend request failed (\(http.statusCode)): \(bodyText.isEmpty ? "Unknown backend error." : bodyText)")
        }
        do {
            let decoder = JSONDecoder()
            return try decoder.decode(T.self, from: data)
        } catch {
#if DEBUG
            print(
                "[ProfileBackendService] DECODE FAILED type=\(String(describing: T.self)), " +
                "error=\(error.localizedDescription), raw_payload=\(bodyText)"
            )
#endif
            throw error
        }
    }
}
