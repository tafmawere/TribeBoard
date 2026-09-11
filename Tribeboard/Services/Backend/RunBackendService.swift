import Foundation

protocol RunBackendService {
    func fetchRunPackages(householdId: UUID) async throws -> [BackendRunPackage]
    func createRunPackage(_ package: BackendRunPackage) async throws -> BackendRunPackage
    func updateRunHeader(_ run: BackendRun) async throws -> BackendRun
    func replaceRunStops(runId: UUID, stops: [BackendRunStop]) async throws -> [BackendRunStop]
    func updateRunStop(_ stop: BackendRunStop) async throws -> BackendRunStop
    func deleteRun(id: UUID) async throws

    // Legacy helpers retained for narrow call sites during migration.
    func fetchRuns(householdId: UUID) async throws -> [BackendRun]
    func createRun(_ run: BackendRun) async throws -> BackendRun
    func updateRun(_ run: BackendRun) async throws -> BackendRun
}

struct SupabaseRunBackendService: RunBackendService {
    enum ServiceError: LocalizedError {
        case backendNotConfigured
        case noActiveSession
        case invalidResponse
        case permissionDenied(action: String, role: String)
        case requestFailed(String)
        case decodeFailed(table: String, details: String, responseBody: String)

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
            case .decodeFailed(let table, let details, let responseBody):
                let preview = responseBody.isEmpty ? "(empty)" : String(responseBody.prefix(400))
                return "Could not read \(table) response from server (\(details)). Body: \(preview)"
            }
        }
    }

    private let authService: AuthService
    private let runsTable = "runs"
    private let runStopsTable = "run_stops"

    private struct WriteDiagnosticContext {
        let operation: String
        let tableOrEndpoint: String
        let payloadSummary: String
    }

    private struct HTTPResult {
        let statusCode: Int
        let body: String
        let data: Data
    }

    init(authService: AuthService = SupabaseAuthService()) {
        self.authService = authService
    }

    func fetchRunPackages(householdId: UUID) async throws -> [BackendRunPackage] {
        let runs = try await fetchRuns(householdId: householdId)
        guard !runs.isEmpty else { return [] }
        let runIds = runs.map(\.id)
        let stops = try await fetchRunStops(runIds: runIds)
        let stopsByRunId = Dictionary(grouping: stops, by: \.runId)
        return runs.map { run in
            BackendRunPackage(
                run: run,
                stops: (stopsByRunId[run.id] ?? []).sorted { $0.stopOrder < $1.stopOrder }
            )
        }
    }

    func createRunPackage(_ package: BackendRunPackage) async throws -> BackendRunPackage {
        let session = try await ensuredSession()
        try await requireRunOperatorPermission(
            householdId: package.run.householdId,
            session: session,
            action: "createRunPackage"
        )

        do {
            try RunCreationValidator.validate(backendRun: package.run)
        } catch let error as RunCreationValidator.ValidationError {
            throw ServiceError.requestFailed(error.localizedDescription)
        }

        let runInsert = BackendRunInsertPayload(from: package.run)
        let runPayloadJSON = SupabaseJSONCoding.encodePayloadJSON([runInsert])
        #if DEBUG
        NSLog("[CreateRunPackage] POST \(runsTable) payload=\(runPayloadJSON)")
        #endif

        let runHTTP = try await postRaw(
            table: runsTable,
            body: try SupabaseJSONCoding.makeSupabaseEncoder().encode([runInsert]),
            session: session,
            context: WriteDiagnosticContext(
                operation: "createRunPackage.runs",
                tableOrEndpoint: runsTable,
                payloadSummary: "id=\(package.run.id.uuidString), status=\(package.run.status)"
            )
        )
        #if DEBUG
        NSLog("[CreateRunPackage] POST \(runsTable) status=\(runHTTP.statusCode) body=\(runHTTP.body)")
        #endif

        let createdRun: BackendRun
        do {
            createdRun = try await decodeInsertedRun(
                data: runHTTP.data,
                fallbackId: package.run.id,
                session: session
            )
        } catch {
            #if DEBUG
            NSLog("[CreateRunPackage] runs decode error -> \(SupabaseJSONCoding.describeDecodingError(error))")
            #endif
            if let serviceError = error as? ServiceError {
                throw serviceError
            }
            throw ServiceError.decodeFailed(
                table: runsTable,
                details: SupabaseJSONCoding.describeDecodingError(error),
                responseBody: runHTTP.body
            )
        }

        let stopsWithRunId = package.stops.map { stop -> BackendRunStop in
            var mutable = stop
            mutable.runId = createdRun.id
            return mutable
        }
        let stopInserts = stopsWithRunId.map(BackendRunStopInsertPayload.init(from:))
        let stopsPayloadJSON = SupabaseJSONCoding.encodePayloadJSON(stopInserts)
        #if DEBUG
        NSLog("[CreateRunPackage] POST \(runStopsTable) payload=\(stopsPayloadJSON)")
        #endif

        let stopsHTTP = try await postRaw(
            table: runStopsTable,
            body: try SupabaseJSONCoding.makeSupabaseEncoder().encode(stopInserts),
            session: session,
            context: WriteDiagnosticContext(
                operation: "createRunPackage.run_stops",
                tableOrEndpoint: runStopsTable,
                payloadSummary: "run_id=\(createdRun.id.uuidString), stop_count=\(stopInserts.count)"
            )
        )
        #if DEBUG
        NSLog("[CreateRunPackage] POST \(runStopsTable) status=\(stopsHTTP.statusCode) body=\(stopsHTTP.body)")
        #endif

        let createdStops: [BackendRunStop]
        do {
            createdStops = try await decodeInsertedRunStops(
                data: stopsHTTP.data,
                runId: createdRun.id,
                session: session
            )
        } catch {
            #if DEBUG
            NSLog("[CreateRunPackage] run_stops decode error -> \(SupabaseJSONCoding.describeDecodingError(error))")
            #endif
            if let serviceError = error as? ServiceError {
                throw serviceError
            }
            throw ServiceError.decodeFailed(
                table: runStopsTable,
                details: SupabaseJSONCoding.describeDecodingError(error),
                responseBody: stopsHTTP.body
            )
        }

        return BackendRunPackage(run: createdRun, stops: createdStops.sorted { $0.stopOrder < $1.stopOrder })
    }

    func updateRunHeader(_ run: BackendRun) async throws -> BackendRun {
        try await updateRun(run)
    }

    func replaceRunStops(runId: UUID, stops: [BackendRunStop]) async throws -> [BackendRunStop] {
        let session = try await ensuredSession()
        let existingRun = try await fetchRunById(id: runId, session: session)
        try await requireRunOperatorPermission(
            householdId: existingRun.householdId,
            session: session,
            action: "replaceRunStops"
        )
        let deletePath = "\(runStopsTable)?run_id=eq.\(runId.uuidString)"
        _ = try await delete(path: deletePath, session: session) as [BackendRunStop]
        guard !stops.isEmpty else { return [] }
        return try await insertRunStops(stops, householdId: existingRun.householdId)
    }

    func updateRunStop(_ stop: BackendRunStop) async throws -> BackendRunStop {
        let session = try await ensuredSession()
        let existingRun = try await fetchRunById(id: stop.runId, session: session)
        try await requireRunOperatorPermission(
            householdId: existingRun.householdId,
            session: session,
            action: "updateRunStop"
        )
        let path = "\(runStopsTable)?id=eq.\(stop.id.uuidString)"
        let payload = BackendRunStopUpdatePayload(from: stop)
        let updated: [BackendRunStop] = try await patch(path: path, payload: [payload], session: session)
        guard let first = updated.first else {
            throw ServiceError.requestFailed("Failed to update run stop.")
        }
        return first
    }

    func fetchRuns(householdId: UUID) async throws -> [BackendRun] {
        let session = try await ensuredSession()
        let path = "\(runsTable)?select=*&household_id=eq.\(householdId.uuidString)&order=run_date.asc"
        return try await get(path: path, session: session)
    }

    func createRun(_ run: BackendRun) async throws -> BackendRun {
        let session = try await ensuredSession()
        try await requireRunOperatorPermission(
            householdId: run.householdId,
            session: session,
            action: "createRun"
        )
        let insert = BackendRunInsertPayload(from: run)
        let http = try await postRaw(
            table: runsTable,
            body: try SupabaseJSONCoding.makeSupabaseEncoder().encode([insert]),
            session: session,
            context: WriteDiagnosticContext(
                operation: "createRun",
                tableOrEndpoint: runsTable,
                payloadSummary: "id=\(run.id.uuidString), status=\(run.status)"
            )
        )
        return try await decodeInsertedRun(data: http.data, fallbackId: run.id, session: session)
    }

    func updateRun(_ run: BackendRun) async throws -> BackendRun {
        let session = try await ensuredSession()
        try await requireRunOperatorPermission(
            householdId: run.householdId,
            session: session,
            action: "updateRun"
        )
        if run.status == BackendRunStatusCodec.encode(.inProgress), run.driverId == nil {
            throw ServiceError.requestFailed("Assign a driver before starting this run.")
        }
        let path = "\(runsTable)?id=eq.\(run.id.uuidString)"
        let payload = BackendRunUpdatePayload(from: run)
        let updated: [BackendRun] = try await patch(path: path, payload: [payload], session: session)
        guard let first = updated.first else {
            throw ServiceError.requestFailed("Failed to update run.")
        }
        return first
    }

    func deleteRun(id: UUID) async throws {
        let session = try await ensuredSession()
        let existingRun = try await fetchRunById(id: id, session: session)
        try await requireRunOperatorPermission(
            householdId: existingRun.householdId,
            session: session,
            action: "deleteRun"
        )
        let path = "\(runsTable)?id=eq.\(id.uuidString)"
        _ = try await delete(path: path, session: session) as [BackendRun]
    }

    private func fetchRunStops(runIds: [UUID]) async throws -> [BackendRunStop] {
        guard !runIds.isEmpty else { return [] }
        let session = try await ensuredSession()
        let ids = runIds.map(\.uuidString).joined(separator: ",")
        let path = "\(runStopsTable)?select=*&run_id=in.(\(ids))&order=stop_order.asc"
        return try await get(path: path, session: session)
    }

    private func insertRunStops(_ stops: [BackendRunStop], householdId: UUID) async throws -> [BackendRunStop] {
        let session = try await ensuredSession()
        try await requireRunOperatorPermission(
            householdId: householdId,
            session: session,
            action: "createRunStops"
        )
        let inserts = stops.map(BackendRunStopInsertPayload.init(from:))
        let http = try await postRaw(
            table: runStopsTable,
            body: try SupabaseJSONCoding.makeSupabaseEncoder().encode(inserts),
            session: session,
            context: WriteDiagnosticContext(
                operation: "createRunStops",
                tableOrEndpoint: runStopsTable,
                payloadSummary: "run_id=\(stops.first?.runId.uuidString ?? "n/a"), stop_count=\(stops.count)"
            )
        )
        guard let runId = stops.first?.runId else { return [] }
        return try await decodeInsertedRunStops(data: http.data, runId: runId, session: session)
    }

    private func decodeInsertedRun(
        data: Data,
        fallbackId: UUID,
        session: AuthUserSession
    ) async throws -> BackendRun {
        let body = String(data: data, encoding: .utf8) ?? ""
        if isEmptyRepresentationBody(body) {
            return try await fetchRunById(id: fallbackId, session: session)
        }
        do {
            let decoded = try SupabaseJSONCoding.makeSupabaseDecoder().decode([BackendRun].self, from: data)
            if let first = decoded.first {
                return first
            }
            return try await fetchRunById(id: fallbackId, session: session)
        } catch {
            throw ServiceError.decodeFailed(
                table: runsTable,
                details: SupabaseJSONCoding.describeDecodingError(error),
                responseBody: body
            )
        }
    }

    private func decodeInsertedRunStops(
        data: Data,
        runId: UUID,
        session: AuthUserSession
    ) async throws -> [BackendRunStop] {
        let body = String(data: data, encoding: .utf8) ?? ""
        if isEmptyRepresentationBody(body) {
            return try await fetchRunStops(runIds: [runId])
        }
        do {
            let decoded = try SupabaseJSONCoding.makeSupabaseDecoder().decode([BackendRunStop].self, from: data)
            if !decoded.isEmpty {
                return decoded
            }
            return try await fetchRunStops(runIds: [runId])
        } catch {
            throw ServiceError.decodeFailed(
                table: runStopsTable,
                details: SupabaseJSONCoding.describeDecodingError(error),
                responseBody: body
            )
        }
    }

    private func isEmptyRepresentationBody(_ body: String) -> Bool {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty || trimmed == "[]" || trimmed == "null"
    }

    private func fetchRunById(id: UUID, session: AuthUserSession) async throws -> BackendRun {
        let path = "\(runsTable)?select=*&id=eq.\(id.uuidString.lowercased())&limit=1"
        let rows: [BackendRun] = try await get(path: path, session: session)
        guard let run = rows.first else {
            throw ServiceError.requestFailed("Run not found.")
        }
        return run
    }

    private func requireRunOperatorPermission(
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
            try BackendPermissionGuard.requireRunOperator(membership, action: action)
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

    private func get<T: Decodable>(path: String, session: AuthUserSession) async throws -> T {
        guard BackendConfig.isBackendConfigured else {
            throw ServiceError.backendNotConfigured
        }
        let url = try SupabaseClientProvider.restURL(path: path)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = try authenticatedHeaders(
            session: session,
            request: request,
            operation: "fetchRuns",
            tableOrEndpoint: path
        )
        return try await performDecode(request)
    }

    private func postRaw(
        table: String,
        body: Data,
        session: AuthUserSession,
        context: WriteDiagnosticContext
    ) async throws -> HTTPResult {
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
        request.httpBody = body
        return try await performRaw(request, writeContext: context)
    }

    private func post<T: Decodable, P: Encodable>(
        table: String,
        payload: P,
        session: AuthUserSession,
        context: WriteDiagnosticContext? = nil
    ) async throws -> T {
        let http = try await postRaw(
            table: table,
            body: try SupabaseJSONCoding.makeSupabaseEncoder().encode(payload),
            session: session,
            context: context ?? WriteDiagnosticContext(
                operation: "write",
                tableOrEndpoint: table,
                payloadSummary: "n/a"
            )
        )
        return try SupabaseJSONCoding.makeSupabaseDecoder().decode(T.self, from: http.data)
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
            operation: "updateRun",
            tableOrEndpoint: path
        )
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        request.httpBody = try SupabaseJSONCoding.makeSupabaseEncoder().encode(payload)
        return try await performDecode(request)
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
            operation: "deleteRun",
            tableOrEndpoint: path
        )
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        return try await performDecode(request)
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

    private func performDecode<T: Decodable>(_ request: URLRequest) async throws -> T {
        let http = try await performRaw(request, writeContext: nil)
        do {
            return try SupabaseJSONCoding.makeSupabaseDecoder().decode(T.self, from: http.data)
        } catch {
            throw ServiceError.decodeFailed(
                table: request.url?.lastPathComponent ?? "unknown",
                details: SupabaseJSONCoding.describeDecodingError(error),
                responseBody: http.body
            )
        }
    }

    private func performRaw(
        _ request: URLRequest,
        writeContext: WriteDiagnosticContext?
    ) async throws -> HTTPResult {
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
            #if DEBUG
            NSLog(
                "[BackendWrite] raw failure operation=%@ table=%@ status=%d body=%@",
                context.operation,
                context.tableOrEndpoint,
                http.statusCode,
                text.isEmpty ? "Unknown backend error." : text
            )
            #endif
            throw ServiceError.requestFailed(
                BackendWriteDiagnostics.describeBackendFailure(
                    operation: context.operation,
                    tableOrEndpoint: context.tableOrEndpoint,
                    statusCode: http.statusCode,
                    responseBody: text.isEmpty ? "Unknown backend error." : text
                )
            )
        }
        return HTTPResult(statusCode: http.statusCode, body: text, data: data)
    }
}
