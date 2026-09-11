import Foundation

protocol ChildBackendService {
    func fetchChildren(householdId: UUID, session: AuthUserSession) async throws -> [BackendChild]
    func createChild(_ child: BackendChild, session: AuthUserSession) async throws -> BackendChild
    func updateChild(_ child: BackendChild, session: AuthUserSession) async throws -> BackendChild
    func deleteChild(id: UUID, session: AuthUserSession) async throws

    func fetchChildActivities(childId: UUID, session: AuthUserSession) async throws -> [BackendChildActivity]
    func createChildActivity(_ activity: BackendChildActivity, session: AuthUserSession) async throws -> BackendChildActivity
    func updateChildActivity(_ activity: BackendChildActivity, session: AuthUserSession) async throws -> BackendChildActivity
    func deleteChildActivity(id: UUID, session: AuthUserSession) async throws
}

struct SupabaseChildBackendService: ChildBackendService {
    enum ServiceError: LocalizedError {
        case backendNotConfigured
        case invalidResponse
        case requestFailed(String)

        var errorDescription: String? {
            switch self {
            case .backendNotConfigured:
                return "Backend is not configured."
            case .invalidResponse:
                return "Invalid backend response."
            case .requestFailed(let message):
                return message
            }
        }
    }

    private struct WriteDiagnosticContext {
        let operation: String
        let tableOrEndpoint: String
        let payloadSummary: String
    }
    private struct ReadDiagnosticContext {
        let operation: String
        let householdId: UUID?
    }

    func fetchChildren(householdId: UUID, session: AuthUserSession) async throws -> [BackendChild] {
        let path = "children?select=*&household_id=eq.\(householdId.uuidString)&order=created_at.asc"
        return try await get(
            path: path,
            session: session,
            readContext: ReadDiagnosticContext(operation: "fetchChildren", householdId: householdId)
        )
    }

    func createChild(_ child: BackendChild, session: AuthUserSession) async throws -> BackendChild {
        let created: [BackendChild] = try await post(
            table: "children",
            payload: [child],
            session: session,
            context: WriteDiagnosticContext(
                operation: "createChild",
                tableOrEndpoint: "children",
                payloadSummary: "id=\(child.id.uuidString), household_id=\(child.householdId.uuidString), legal_name=\(child.legalName)"
            )
        )
        guard let first = created.first else {
            throw ServiceError.requestFailed("Failed to create child.")
        }
        return first
    }

    func updateChild(_ child: BackendChild, session: AuthUserSession) async throws -> BackendChild {
        let path = "children?id=eq.\(child.id.uuidString)"
        let updated: [BackendChild] = try await patch(path: path, payload: [child], session: session)
        guard let first = updated.first else {
            throw ServiceError.requestFailed("Failed to update child.")
        }
        return first
    }

    func deleteChild(id: UUID, session: AuthUserSession) async throws {
        let path = "children?id=eq.\(id.uuidString)"
        _ = try await delete(path: path, session: session) as [BackendChild]
    }

    func fetchChildActivities(childId: UUID, session: AuthUserSession) async throws -> [BackendChildActivity] {
        let path = "child_activities?select=*&child_id=eq.\(childId.uuidString)"
        return try await get(path: path, session: session)
    }

    func createChildActivity(_ activity: BackendChildActivity, session: AuthUserSession) async throws -> BackendChildActivity {
        let created: [BackendChildActivity] = try await post(
            table: "child_activities",
            payload: [activity],
            session: session,
            context: WriteDiagnosticContext(
                operation: "createChildActivity",
                tableOrEndpoint: "child_activities",
                payloadSummary: "id=\(activity.id.uuidString), child_id=\(activity.childId.uuidString), household_id=\(activity.householdId.uuidString)"
            )
        )
        guard let first = created.first else {
            throw ServiceError.requestFailed("Failed to create child activity.")
        }
        return first
    }

    func updateChildActivity(_ activity: BackendChildActivity, session: AuthUserSession) async throws -> BackendChildActivity {
        let path = "child_activities?id=eq.\(activity.id.uuidString)"
        let updated: [BackendChildActivity] = try await patch(path: path, payload: [activity], session: session)
        guard let first = updated.first else {
            throw ServiceError.requestFailed("Failed to update child activity.")
        }
        return first
    }

    func deleteChildActivity(id: UUID, session: AuthUserSession) async throws {
        let path = "child_activities?id=eq.\(id.uuidString)"
        _ = try await delete(path: path, session: session) as [BackendChildActivity]
    }

    private func get<T: Decodable>(
        path: String,
        session: AuthUserSession,
        readContext: ReadDiagnosticContext? = nil
    ) async throws -> T {
        guard BackendConfig.isBackendConfigured else {
            throw ServiceError.backendNotConfigured
        }
        let url = try SupabaseClientProvider.restURL(path: path)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = try authenticatedHeaders(
            session: session,
            request: request,
            operation: "fetchChildren",
            tableOrEndpoint: path
        )
        return try await perform(request, readContext: readContext)
    }

    private func post<T: Decodable, P: Encodable>(
        table: String,
        payload: P,
        session: AuthUserSession,
        context: WriteDiagnosticContext? = nil
    ) async throws -> T {
        guard BackendConfig.isBackendConfigured else {
            throw ServiceError.backendNotConfigured
        }
        let url = try SupabaseClientProvider.restURL(path: table)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = try authenticatedHeaders(
            session: session,
            request: request,
            operation: context?.operation ?? "write",
            tableOrEndpoint: context?.tableOrEndpoint ?? table,
            payloadSummary: context?.payloadSummary ?? "n/a"
        )
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        request.httpBody = try JSONEncoder().encode(payload)
        return try await perform(request, writeContext: context)
    }

    private func patch<T: Decodable, P: Encodable>(path: String, payload: P, session: AuthUserSession) async throws -> T {
        guard BackendConfig.isBackendConfigured else {
            throw ServiceError.backendNotConfigured
        }
        let url = try SupabaseClientProvider.restURL(path: path)
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.allHTTPHeaderFields = try authenticatedHeaders(
            session: session,
            request: request,
            operation: "updateChild",
            tableOrEndpoint: path
        )
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        request.httpBody = try JSONEncoder().encode(payload)
        return try await perform(request)
    }

    private func delete<T: Decodable>(path: String, session: AuthUserSession) async throws -> T {
        guard BackendConfig.isBackendConfigured else {
            throw ServiceError.backendNotConfigured
        }
        let url = try SupabaseClientProvider.restURL(path: path)
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.allHTTPHeaderFields = try authenticatedHeaders(
            session: session,
            request: request,
            operation: "deleteChild",
            tableOrEndpoint: path
        )
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        return try await perform(request)
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
        writeContext: WriteDiagnosticContext? = nil,
        readContext: ReadDiagnosticContext? = nil
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
#if DEBUG
        if let readContext {
            print(
                "[ChildBackendService] \(readContext.operation) " +
                "household_id=\(readContext.householdId?.uuidString ?? "nil"), " +
                "url=\(request.url?.absoluteString ?? "nil"), status=\(http.statusCode), raw_response=\(text)"
            )
        }
#endif
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
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
#if DEBUG
            print(
                "[ChildBackendService] DECODE FAILED type=\(String(describing: T.self)), " +
                "url=\(request.url?.absoluteString ?? "nil"), household_id=\(readContext?.householdId?.uuidString ?? "nil"), " +
                "error=\(error.localizedDescription), raw_payload=\(text)"
            )
#endif
            throw error
        }
    }
}
