import Foundation

protocol EmergencyContactsBackendService {
    func fetchContacts(householdId: UUID, session: AuthUserSession) async throws -> [BackendEmergencyContact]
    func createContact(_ contact: BackendEmergencyContact, session: AuthUserSession) async throws -> BackendEmergencyContact
    func updateContact(_ contact: BackendEmergencyContact, session: AuthUserSession) async throws -> BackendEmergencyContact
    func deleteContact(id: UUID, session: AuthUserSession) async throws
}

struct SupabaseEmergencyContactsBackendService: EmergencyContactsBackendService {
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

    func fetchContacts(householdId: UUID, session: AuthUserSession) async throws -> [BackendEmergencyContact] {
        let path =
            "emergency_contacts?select=*&household_id=eq.\(householdId.uuidString)" +
            "&order=priority.asc,created_at.asc"
        return try await get(
            path: path,
            session: session,
            readContext: ReadDiagnosticContext(operation: "fetchEmergencyContacts", householdId: householdId)
        )
    }

    func createContact(_ contact: BackendEmergencyContact, session: AuthUserSession) async throws -> BackendEmergencyContact {
        let created: [BackendEmergencyContact] = try await post(
            table: "emergency_contacts",
            payload: [contact],
            session: session,
            context: WriteDiagnosticContext(
                operation: "createEmergencyContact",
                tableOrEndpoint: "emergency_contacts",
                payloadSummary: "id=\(contact.id.uuidString), household_id=\(contact.householdId.uuidString)"
            )
        )
        guard let first = created.first else {
            throw ServiceError.requestFailed("Failed to create emergency contact.")
        }
        return first
    }

    func updateContact(_ contact: BackendEmergencyContact, session: AuthUserSession) async throws -> BackendEmergencyContact {
        let path = "emergency_contacts?id=eq.\(contact.id.uuidString)"
        let updated: [BackendEmergencyContact] = try await patch(
            path: path,
            payload: [contact],
            session: session,
            context: WriteDiagnosticContext(
                operation: "updateEmergencyContact",
                tableOrEndpoint: "emergency_contacts",
                payloadSummary: "id=\(contact.id.uuidString), household_id=\(contact.householdId.uuidString)"
            )
        )
        guard let first = updated.first else {
            throw ServiceError.requestFailed("Failed to update emergency contact.")
        }
        return first
    }

    func deleteContact(id: UUID, session: AuthUserSession) async throws {
        let path = "emergency_contacts?id=eq.\(id.uuidString)"
        _ = try await delete(
            path: path,
            session: session,
            context: WriteDiagnosticContext(
                operation: "deleteEmergencyContact",
                tableOrEndpoint: "emergency_contacts",
                payloadSummary: "id=\(id.uuidString)"
            )
        ) as [BackendEmergencyContact]
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
            operation: "fetchEmergencyContacts",
            tableOrEndpoint: path
        )
        return try await perform(request, readContext: readContext)
    }

    private func post<T: Decodable, P: Encodable>(
        table: String,
        payload: P,
        session: AuthUserSession,
        context: WriteDiagnosticContext
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
            operation: context.operation,
            tableOrEndpoint: context.tableOrEndpoint,
            payloadSummary: context.payloadSummary
        )
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        request.httpBody = try JSONEncoder().encode(payload)
        return try await perform(request, writeContext: context)
    }

    private func patch<T: Decodable, P: Encodable>(
        path: String,
        payload: P,
        session: AuthUserSession,
        context: WriteDiagnosticContext
    ) async throws -> T {
        guard BackendConfig.isBackendConfigured else {
            throw ServiceError.backendNotConfigured
        }
        let url = try SupabaseClientProvider.restURL(path: path)
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.allHTTPHeaderFields = try authenticatedHeaders(
            session: session,
            request: request,
            operation: context.operation,
            tableOrEndpoint: context.tableOrEndpoint,
            payloadSummary: context.payloadSummary
        )
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        request.httpBody = try JSONEncoder().encode(payload)
        return try await perform(request, writeContext: context)
    }

    private func delete<T: Decodable>(
        path: String,
        session: AuthUserSession,
        context: WriteDiagnosticContext
    ) async throws -> T {
        guard BackendConfig.isBackendConfigured else {
            throw ServiceError.backendNotConfigured
        }
        let url = try SupabaseClientProvider.restURL(path: path)
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.allHTTPHeaderFields = try authenticatedHeaders(
            session: session,
            request: request,
            operation: context.operation,
            tableOrEndpoint: context.tableOrEndpoint,
            payloadSummary: context.payloadSummary
        )
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
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
                "[EmergencyContactsBackendService] \(readContext.operation) " +
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
                "[EmergencyContactsBackendService] DECODE FAILED type=\(String(describing: T.self)), " +
                "url=\(request.url?.absoluteString ?? "nil"), household_id=\(readContext?.householdId?.uuidString ?? "nil"), " +
                "error=\(error.localizedDescription), raw_payload=\(text)"
            )
#endif
            throw error
        }
    }
}
