import Foundation
import Combine

enum RealtimeEntityType {
    case child
    case childActivity
    case householdMembership
    case run
    case runAssignment
    case runDriverPosition
}

enum RealtimeChangeType {
    case inserted
    case updated
    case deleted
}

struct RealtimeChangeEvent {
    let entityType: RealtimeEntityType
    let changeType: RealtimeChangeType
    let recordId: UUID?
    let householdId: UUID?
}

protocol RealtimeService {
    func subscribeToHousehold(householdId: UUID) async
    func reconnectForHousehold(householdId: UUID) async
    func unsubscribe() async
}

@MainActor
final class SupabaseRealtimeService: ObservableObject, RealtimeService {
    @Published private(set) var activeHouseholdId: UUID?
    @Published private(set) var subscriptionState: String = "disconnected"
    @Published private(set) var lastEventSummary: String?
    @Published private(set) var lastError: String?
    @Published private(set) var subscribedTables: [String] = []

    var onEvent: ((RealtimeChangeEvent) -> Void)?

    private struct RealtimeRow: Decodable {
        let id: UUID
        let markerValue: String?

        enum CodingKeys: String, CodingKey {
            case id
            case run_id
            case updated_at
            case assigned_at
            case created_at
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            if let runId = try container.decodeIfPresent(UUID.self, forKey: .run_id) {
                id = runId
            } else {
                id = try container.decode(UUID.self, forKey: .id)
            }
            markerValue =
                try container.decodeIfPresent(String.self, forKey: .updated_at)
                ?? container.decodeIfPresent(String.self, forKey: .assigned_at)
                ?? container.decodeIfPresent(String.self, forKey: .created_at)
        }
    }

    private struct TableSnapshot {
        let ids: Set<UUID>
        let latestMarker: String?
    }

    private let authService: AuthService
    private var pollingTask: Task<Void, Never>?
    private var snapshots: [RealtimeEntityType: TableSnapshot] = [:]

    init(authService: AuthService? = nil) {
        self.authService = authService ?? SupabaseAuthService()
    }

    func subscribeToHousehold(householdId: UUID) async {
        if activeHouseholdId == householdId, pollingTask != nil {
            return
        }
        await reconnectForHousehold(householdId: householdId)
    }

    func reconnectForHousehold(householdId: UUID) async {
        await unsubscribe()
        activeHouseholdId = householdId
        subscriptionState = "connecting"
        lastError = nil
        snapshots = [:]
        subscribedTables = [
            "children",
            "child_activities",
            "household_memberships",
            "runs",
            "run_driver_positions"
        ]

        pollingTask = Task { [weak self] in
            guard let self else { return }
            await self.runPollingLoop(for: householdId)
        }
    }

    func unsubscribe() async {
        pollingTask?.cancel()
        pollingTask = nil
        snapshots = [:]
        activeHouseholdId = nil
        subscribedTables = []
        subscriptionState = "disconnected"
    }

    private func runPollingLoop(for householdId: UUID) async {
        subscriptionState = "subscribed"
        while !Task.isCancelled {
            do {
                guard let session = try await authService.restoreSession() else {
                    subscriptionState = "waiting_auth"
                    try await Task.sleep(nanoseconds: 2_000_000_000)
                    continue
                }
                try await pollEntity(.child, table: "children", householdId: householdId, accessToken: session.accessToken)
                try await pollEntity(.childActivity, table: "child_activities", householdId: householdId, accessToken: session.accessToken)
                try await pollEntity(.householdMembership, table: "household_memberships", householdId: householdId, accessToken: session.accessToken)
                try await pollEntity(.run, table: "runs", householdId: householdId, accessToken: session.accessToken)
                try await pollEntity(.runDriverPosition, table: "run_driver_positions", householdId: householdId, accessToken: session.accessToken)
                subscriptionState = "subscribed"
                try await Task.sleep(nanoseconds: 2_000_000_000)
            } catch is CancellationError {
                break
            } catch {
                lastError = error.localizedDescription
                subscriptionState = "error"
                try? await Task.sleep(nanoseconds: 4_000_000_000)
            }
        }
    }

    private func pollEntity(
        _ entityType: RealtimeEntityType,
        table: String,
        householdId: UUID,
        accessToken: String
    ) async throws {
        let rows = try await fetchRows(table: table, householdId: householdId, accessToken: accessToken)
        let snapshot = TableSnapshot(
            ids: Set(rows.map(\.id)),
            latestMarker: rows.compactMap(\.markerValue).max()
        )

        guard let previous = snapshots[entityType] else {
            snapshots[entityType] = snapshot
            return
        }

        let changeType: RealtimeChangeType?
        let eventRecordId: UUID?
        if snapshot.ids.count > previous.ids.count {
            changeType = .inserted
            eventRecordId = snapshot.ids.subtracting(previous.ids).first
        } else if snapshot.ids.count < previous.ids.count {
            changeType = .deleted
            eventRecordId = previous.ids.subtracting(snapshot.ids).first
        } else if snapshot.latestMarker != previous.latestMarker {
            changeType = .updated
            eventRecordId = snapshot.ids.first
        } else {
            changeType = nil
            eventRecordId = nil
        }

        snapshots[entityType] = snapshot
        guard let changeType else { return }
        let event = RealtimeChangeEvent(
            entityType: entityType,
            changeType: changeType,
            recordId: eventRecordId,
            householdId: householdId
        )
        lastEventSummary = "\(entityName(entityType)) \(changeName(changeType)) \(eventRecordId?.uuidString ?? "")"
        onEvent?(event)
    }

    private func fetchRows(table: String, householdId: UUID, accessToken: String) async throws -> [RealtimeRow] {
        let markerColumn = markerColumn(for: table)
        let path = "\(table)?select=id,\(markerColumn)&household_id=eq.\(householdId.uuidString)"
        let url = try SupabaseClientProvider.restURL(path: path)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = try SupabaseClientProvider.defaultHeaders(accessToken: accessToken)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let text = String(data: data, encoding: .utf8) ?? "Unknown backend error."
            throw NSError(domain: "SupabaseRealtimeService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Realtime polling failed: \(text)"])
        }
        return try JSONDecoder().decode([RealtimeRow].self, from: data)
    }

    private func markerColumn(for table: String) -> String {
        switch table {
        case "household_memberships":
            return "created_at"
        case "run_assignments":
            return "assigned_at"
        default:
            return "updated_at"
        }
    }

    private func entityName(_ entityType: RealtimeEntityType) -> String {
        switch entityType {
        case .child: return "children"
        case .childActivity: return "child_activities"
        case .householdMembership: return "household_memberships"
        case .run: return "runs"
        case .runAssignment: return "run_assignments"
        case .runDriverPosition: return "run_driver_positions"
        }
    }

    private func changeName(_ changeType: RealtimeChangeType) -> String {
        switch changeType {
        case .inserted: return "inserted"
        case .updated: return "updated"
        case .deleted: return "deleted"
        }
    }
}
