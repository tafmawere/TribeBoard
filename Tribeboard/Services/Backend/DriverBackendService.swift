import Foundation

protocol DriverBackendService {
    func assignDriverToRun(runId: UUID, driverId: UUID) async throws
    func clearDriverOnRun(runId: UUID) async throws
}

struct SupabaseDriverBackendService: DriverBackendService {
    enum ServiceError: LocalizedError {
        case backendNotConfigured
        case noActiveSession
        case invalidResponse
        case requestFailed(String)

        var errorDescription: String? {
            switch self {
            case .backendNotConfigured:
                return "Backend is not configured."
            case .noActiveSession:
                return "No active auth session."
            case .invalidResponse:
                return "Invalid backend response."
            case .requestFailed(let message):
                return message
            }
        }
    }

    private struct RunDriverPatchPayload: Codable {
        let driverId: UUID?
        let status: String?

        enum CodingKeys: String, CodingKey {
            case driverId = "driver_id"
            case status
        }
    }

    private let authService: AuthService
    private struct WriteDiagnosticContext {
        let operation: String
        let tableOrEndpoint: String
        let payloadSummary: String
    }

    init(authService: AuthService = SupabaseAuthService()) {
        self.authService = authService
    }

    func assignDriverToRun(runId: UUID, driverId: UUID) async throws {
        let session = try await ensuredSession()
        let patchPayload = [RunDriverPatchPayload(driverId: driverId, status: BackendRunStatusCodec.encode(.assigned))]
        let patchPath = "runs?id=eq.\(runId.uuidString)"
        let patchBody = try encodePayloadJSON(patchPayload)
        NSLog("[AssignDriver] saving run update")
        NSLog("[AssignDriver] run payload=\(patchBody)")

        _ = try await patch(
            path: patchPath,
            payload: patchPayload,
            session: session,
            writeContext: WriteDiagnosticContext(
                operation: "assignDriverToRun",
                tableOrEndpoint: patchPath,
                payloadSummary: patchBody
            )
        ) as [BackendRun]
        NSLog("[AssignDriver] save success")
    }

    func clearDriverOnRun(runId: UUID) async throws {
        let session = try await ensuredSession()
        _ = try await patch(
            path: "runs?id=eq.\(runId.uuidString)",
            payload: [RunDriverPatchPayload(driverId: nil, status: BackendRunStatusCodec.encode(.scheduled))],
            session: session
        ) as [BackendRun]
    }

    private func ensuredSession() async throws -> AuthUserSession {
        guard let session = try await authService.restoreSession() else {
            throw ServiceError.noActiveSession
        }
        return session
    }

    private func patch<T: Decodable, P: Encodable>(
        path: String,
        payload: P,
        session: AuthUserSession,
        writeContext: WriteDiagnosticContext? = nil
    ) async throws -> T {
        guard BackendConfig.isBackendConfigured else {
            throw ServiceError.backendNotConfigured
        }
        let url = try SupabaseClientProvider.restURL(path: path)
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        let context = writeContext ?? WriteDiagnosticContext(
            operation: "updateDriverAssignment",
            tableOrEndpoint: path,
            payloadSummary: (try? encodePayloadJSON(payload)) ?? "n/a"
        )
        request.allHTTPHeaderFields = try authenticatedHeaders(
            session: session,
            request: request,
            operation: context.operation,
            tableOrEndpoint: context.tableOrEndpoint,
            payloadSummary: context.payloadSummary
        )
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        request.httpBody = try makeEncoder().encode(payload)
        return try await perform(request, writeContext: context)
    }

    private func authenticatedHeaders(
        session: AuthUserSession,
        request: URLRequest,
        operation: String,
        tableOrEndpoint: String,
        payloadSummary: String = "n/a"
    ) throws -> [String: String] {
        do {
            return try SupabaseClientProvider.authenticatedHeaders(accessToken: session.accessToken)
        } catch {
            BackendWriteDiagnostics.record(
                operation: operation,
                tableOrEndpoint: tableOrEndpoint,
                request: request,
                statusCode: nil,
                responseBody: "",
                payloadSummary: payloadSummary,
                errorSummary: error.localizedDescription
            )
            throw ServiceError.requestFailed(error.localizedDescription)
        }
    }

    private func perform<T: Decodable>(
        _ request: URLRequest,
        writeContext: WriteDiagnosticContext? = nil
    ) async throws -> T {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            if let writeContext {
                BackendWriteDiagnostics.record(
                    operation: writeContext.operation,
                    tableOrEndpoint: writeContext.tableOrEndpoint,
                    request: request,
                    statusCode: nil,
                    responseBody: "Invalid backend response.",
                    payloadSummary: writeContext.payloadSummary,
                    errorSummary: "Invalid backend response."
                )
            }
            throw ServiceError.invalidResponse
        }
        let text = String(data: data, encoding: .utf8) ?? ""
        if let writeContext {
            BackendWriteDiagnostics.record(
                operation: writeContext.operation,
                tableOrEndpoint: writeContext.tableOrEndpoint,
                request: request,
                statusCode: http.statusCode,
                responseBody: text,
                payloadSummary: writeContext.payloadSummary,
                errorSummary: (200..<300).contains(http.statusCode) ? nil : "HTTP \(http.statusCode)"
            )
        }
        guard (200..<300).contains(http.statusCode) else {
            let context = writeContext ?? WriteDiagnosticContext(
                operation: request.httpMethod ?? "REQUEST",
                tableOrEndpoint: request.url?.lastPathComponent ?? "unknown",
                payloadSummary: "n/a"
            )
            NSLog("[AssignDriver] save failed error=HTTP \(http.statusCode)")
            NSLog("[AssignDriver] response=\(text)")
            NSLog("[AssignDriver] run payload=\(context.payloadSummary)")
            throw ServiceError.requestFailed(
                BackendWriteDiagnostics.describeBackendFailure(
                    operation: context.operation,
                    tableOrEndpoint: context.tableOrEndpoint,
                    statusCode: http.statusCode,
                    responseBody: text.isEmpty ? "Unknown backend error." : text
                )
            )
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: data)
    }

    private func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private func encodePayloadJSON<P: Encodable>(_ payload: P) throws -> String {
        let data = try makeEncoder().encode(payload)
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}
