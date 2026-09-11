import Foundation

protocol ScheduleBackendService {
    func fetchSchedules(householdId: UUID) async throws -> [BackendScheduleTemplate]
    func fetchScheduleStops(scheduleIds: [UUID]) async throws -> [BackendScheduleStop]
    func createSchedule(_ schedule: BackendScheduleTemplate) async throws -> BackendScheduleTemplate
    func updateSchedule(_ schedule: BackendScheduleTemplate) async throws -> BackendScheduleTemplate
    func replaceScheduleStops(scheduleId: UUID, stops: [BackendScheduleStop]) async throws -> [BackendScheduleStop]
    func deleteSchedule(id: UUID) async throws
}

struct SupabaseScheduleBackendService: ScheduleBackendService {
    enum ServiceError: LocalizedError {
        case backendNotConfigured
        case noActiveSession
        case invalidResponse
        case permissionDenied(action: String, role: String)
        case requestFailed(String)

        var errorDescription: String? {
            switch self {
            case .backendNotConfigured:
                return "Backend is not configured."
            case .noActiveSession:
                return "No active auth session."
            case .invalidResponse:
                return "Invalid backend response."
            case .permissionDenied(let action, let role):
                return "Permission denied for \(action). Role \(role) is not allowed."
            case .requestFailed(let message):
                return message
            }
        }
    }

    private let authService: AuthService
    private let scheduleTemplatesTable = "schedule_templates"
    private let scheduleStopsTable = "schedule_stops"
    private struct ScheduleTemplateInsertPayload: Encodable {
        let householdId: UUID
        let childId: UUID
        let title: String
        let weekday: String
        let departureTime: String

        enum CodingKeys: String, CodingKey {
            case householdId = "household_id"
            case childId = "child_id"
            case title
            case weekday
            case departureTime = "departure_time"
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

    init(authService: AuthService = SupabaseAuthService()) {
        self.authService = authService
    }

    func fetchSchedules(householdId: UUID) async throws -> [BackendScheduleTemplate] {
        let session = try await ensuredSession()
        let path = "\(scheduleTemplatesTable)?select=*&household_id=eq.\(householdId.uuidString)&order=created_at.asc"
        return try await get(
            path: path,
            session: session,
            readContext: ReadDiagnosticContext(operation: "fetchSchedules", householdId: householdId)
        )
    }

    func fetchScheduleStops(scheduleIds: [UUID]) async throws -> [BackendScheduleStop] {
        guard !scheduleIds.isEmpty else { return [] }
        let session = try await ensuredSession()
        let ids = scheduleIds.map(\.uuidString).joined(separator: ",")
        let path = "\(scheduleStopsTable)?select=*&schedule_id=in.(\(ids))&order=stop_order.asc"
        return try await get(path: path, session: session)
    }

    func createSchedule(_ schedule: BackendScheduleTemplate) async throws -> BackendScheduleTemplate {
        let session = try await ensuredSession()
        try await requireOrganiserPermission(
            householdId: schedule.householdId,
            session: session,
            action: "createSchedule"
        )
        let departureTime = try normalizedSQLTime(schedule.departureTime)
        let payload = ScheduleTemplateInsertPayload(
            householdId: schedule.householdId,
            childId: schedule.childId,
            title: schedule.title,
            weekday: schedule.weekday,
            departureTime: departureTime
        )
#if DEBUG
        if let payloadData = try? JSONEncoder().encode(payload),
           let payloadText = String(data: payloadData, encoding: .utf8) {
            print("[SupabaseScheduleBackendService] schedule_templates create payload: \(payloadText)")
        }
#endif
        let created: [BackendScheduleTemplate] = try await post(
            table: scheduleTemplatesTable,
            payload: [payload],
            session: session,
            context: WriteDiagnosticContext(
                operation: "createSchedule",
                tableOrEndpoint: scheduleTemplatesTable,
                payloadSummary: "household_id=\(schedule.householdId.uuidString), child_id=\(schedule.childId.uuidString), title=\(schedule.title), weekday=\(schedule.weekday), departure_time=\(departureTime)"
            )
        )
        guard let first = created.first else {
            throw ServiceError.requestFailed("Failed to create schedule.")
        }
        return first
    }

    func updateSchedule(_ schedule: BackendScheduleTemplate) async throws -> BackendScheduleTemplate {
        let session = try await ensuredSession()
        try await requireOrganiserPermission(
            householdId: schedule.householdId,
            session: session,
            action: "updateSchedule"
        )
        let departureTime = try normalizedSQLTime(schedule.departureTime)
        let payload = ScheduleTemplateInsertPayload(
            householdId: schedule.householdId,
            childId: schedule.childId,
            title: schedule.title,
            weekday: schedule.weekday,
            departureTime: departureTime
        )
        let path = "\(scheduleTemplatesTable)?id=eq.\(schedule.id.uuidString)"
        let updated: [BackendScheduleTemplate] = try await patch(path: path, payload: [payload], session: session)
        guard let first = updated.first else {
            throw ServiceError.requestFailed("Failed to update schedule.")
        }
        return first
    }

    func replaceScheduleStops(scheduleId: UUID, stops: [BackendScheduleStop]) async throws -> [BackendScheduleStop] {
        let session = try await ensuredSession()
        let schedule = try await fetchScheduleById(id: scheduleId, session: session)
        try await requireOrganiserPermission(
            householdId: schedule.householdId,
            session: session,
            action: "replaceScheduleStops"
        )
        let deletePath = "\(scheduleStopsTable)?schedule_id=eq.\(scheduleId.uuidString)"
        _ = try await delete(path: deletePath, session: session) as [BackendScheduleStop]
        guard !stops.isEmpty else { return [] }
#if DEBUG
        for stop in stops.sorted(by: { $0.stopOrder < $1.stopOrder }) {
            print(
                "[SupabaseScheduleBackendService] schedule_stops payload: " +
                "schedule_id=\(stop.scheduleId.uuidString), " +
                "child_id=\(stop.childId.uuidString), " +
                "label=\(stop.label), " +
                "stop_order=\(stop.stopOrder)"
            )
        }
#endif
        let created: [BackendScheduleStop] = try await post(
            table: scheduleStopsTable,
            payload: stops,
            session: session,
            context: WriteDiagnosticContext(
                operation: "replaceScheduleStops",
                tableOrEndpoint: scheduleStopsTable,
                payloadSummary: "schedule_id=\(scheduleId.uuidString), stop_count=\(stops.count)"
            )
        )
        return created.sorted { $0.stopOrder < $1.stopOrder }
    }

    func deleteSchedule(id: UUID) async throws {
        let session = try await ensuredSession()
        let schedule = try await fetchScheduleById(id: id, session: session)
        try await requireOrganiserPermission(
            householdId: schedule.householdId,
            session: session,
            action: "deleteSchedule"
        )
        let path = "\(scheduleTemplatesTable)?id=eq.\(id.uuidString)"
        _ = try await delete(path: path, session: session) as [BackendScheduleTemplate]
    }

    private func fetchScheduleById(id: UUID, session: AuthUserSession) async throws -> BackendScheduleTemplate {
        let path = "\(scheduleTemplatesTable)?select=*&id=eq.\(id.uuidString.lowercased())&limit=1"
        let rows: [BackendScheduleTemplate] = try await get(path: path, session: session)
        guard let schedule = rows.first else {
            throw ServiceError.requestFailed("Schedule not found.")
        }
        return schedule
    }

    private func requireOrganiserPermission(
        householdId: UUID,
        session: AuthUserSession,
        action: String
    ) async throws {
        guard let userId = UUID(uuidString: session.userId) else {
            throw ServiceError.requestFailed("Invalid authenticated user.")
        }
        let path = "household_memberships?select=*&household_id=eq.\(householdId.uuidString.lowercased())&user_id=eq.\(userId.uuidString.lowercased())&limit=1"
        let memberships: [BackendHouseholdMembership] = try await get(path: path, session: session)
        let membership = memberships.first
        do {
            try BackendPermissionGuard.requireOrganiser(membership, action: action)
        } catch let error as BackendPermissionError {
            throw mapPermissionError(error)
        }
    }

    private func mapPermissionError(_ error: BackendPermissionError) -> ServiceError {
        switch error {
        case .missingActiveMembership(let action):
            return .permissionDenied(action: action, role: "none")
        case .permissionDenied(let action, let role):
            return .permissionDenied(action: action, role: role)
        }
    }

    private func ensuredSession() async throws -> AuthUserSession {
        guard let session = try await authService.restoreSession() else {
            throw ServiceError.noActiveSession
        }
        return session
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
            operation: "fetchSchedules",
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
            operation: "updateSchedule",
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
            operation: "deleteSchedule",
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

    private func normalizedSQLTime(_ value: String) throws -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let fullPattern = #"^\d{2}:\d{2}:\d{2}$"#
        let shortPattern = #"^\d{2}:\d{2}$"#
        if trimmed.range(of: fullPattern, options: .regularExpression) != nil {
            return trimmed
        }
        if trimmed.range(of: shortPattern, options: .regularExpression) != nil {
            return "\(trimmed):00"
        }
        throw ServiceError.requestFailed("Invalid departure_time format. Expected HH:mm:ss.")
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
                "[ScheduleBackendService] \(readContext.operation) " +
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
                "[ScheduleBackendService] DECODE FAILED type=\(String(describing: T.self)), " +
                "url=\(request.url?.absoluteString ?? "nil"), household_id=\(readContext?.householdId?.uuidString ?? "nil"), " +
                "error=\(error.localizedDescription), raw_payload=\(text)"
            )
#endif
            throw error
        }
    }
}
