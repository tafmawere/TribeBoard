import Foundation

protocol RunLocationBackendService {
    func upsertPosition(_ position: BackendRunDriverPosition) async throws
    func fetchPositions(householdId: UUID) async throws -> [BackendRunDriverPosition]
    func fetchPosition(runId: UUID) async throws -> BackendRunDriverPosition?
}

struct SupabaseRunLocationBackendService: RunLocationBackendService {
    enum ServiceError: LocalizedError {
        case backendNotConfigured
        case noActiveSession

        var errorDescription: String? {
            switch self {
            case .backendNotConfigured: return "Backend is not configured."
            case .noActiveSession: return "No active auth session."
            }
        }
    }

    private let authService: AuthService

    init(authService: AuthService = SupabaseAuthService()) {
        self.authService = authService
    }

    func upsertPosition(_ position: BackendRunDriverPosition) async throws {
        guard BackendConfig.isBackendConfigured else { return }
        let session = try await ensuredSession()
        let url = try SupabaseClientProvider.restURL(path: "run_driver_positions?on_conflict=run_id")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = try SupabaseClientProvider.defaultHeaders(accessToken: session.accessToken)
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        request.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
        request.httpBody = try makeEncoder().encode([position])
        _ = try await perform(request) as [BackendRunDriverPosition]
    }

    func fetchPositions(householdId: UUID) async throws -> [BackendRunDriverPosition] {
        guard BackendConfig.isBackendConfigured else { return [] }
        let session = try await ensuredSession()
        let path = "run_driver_positions?select=*&household_id=eq.\(householdId.uuidString)"
        return try await get(path: path, session: session)
    }

    func fetchPosition(runId: UUID) async throws -> BackendRunDriverPosition? {
        guard BackendConfig.isBackendConfigured else { return nil }
        let session = try await ensuredSession()
        let path = "run_driver_positions?select=*&run_id=eq.\(runId.uuidString)&limit=1"
        let rows: [BackendRunDriverPosition] = try await get(path: path, session: session)
        return rows.first
    }

    private func ensuredSession() async throws -> AuthUserSession {
        guard let session = try await authService.restoreSession() else {
            throw ServiceError.noActiveSession
        }
        return session
    }

    private func get<T: Decodable>(path: String, session: AuthUserSession) async throws -> T {
        let url = try SupabaseClientProvider.restURL(path: path)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = try SupabaseClientProvider.defaultHeaders(accessToken: session.accessToken)
        return try await perform(request)
    }

    private func perform<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let text = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "RunLocationBackendService", code: 1, userInfo: [NSLocalizedDescriptionKey: text])
        }
        if data.isEmpty, T.self == [BackendRunDriverPosition].self {
            return [] as! T
        }
        return try makeDecoder().decode(T.self, from: data)
    }

    private func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
