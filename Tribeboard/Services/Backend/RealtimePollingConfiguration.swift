import Foundation

/// REST polling stand-in for Supabase Realtime. Documented in
/// `docs/REALTIME_POLLING_INVESTIGATION.md`. Do not change intervals here
/// without updating that doc.
enum RealtimePollingConfiguration {
    static let pollIntervalNanoseconds: UInt64 = 2_000_000_000
    static let waitingAuthIntervalNanoseconds: UInt64 = 2_000_000_000
    static let errorBackoffNanoseconds: UInt64 = 4_000_000_000

    static let pollInterval: TimeInterval = 2
    static let waitingAuthInterval: TimeInterval = 2
    static let errorBackoffInterval: TimeInterval = 4

    /// Restore the session this many seconds before `expiresAt`.
    static let accessTokenRefreshLeeway: TimeInterval = 30

    static let pollTableSpecs: [RealtimePollTableSpec] = [
        RealtimePollTableSpec(entity: .child, table: "children"),
        RealtimePollTableSpec(entity: .childActivity, table: "child_activities"),
        RealtimePollTableSpec(entity: .householdMembership, table: "household_memberships"),
        RealtimePollTableSpec(entity: .run, table: "runs"),
        RealtimePollTableSpec(entity: .runDriverPosition, table: "run_driver_positions")
    ]

    static let subscribedTables = pollTableSpecs.map(\.table)

    /// Marker used to synthesize `.updated` when the ID set is unchanged.
    /// `household_memberships.status` changes (pending → active) only bump `updated_at`.
    static func markerColumn(for table: String) -> String {
        switch table {
        case "run_assignments":
            return "assigned_at"
        default:
            return "updated_at"
        }
    }

    static func shouldRestoreAccessToken(
        cached: AuthUserSession?,
        now: Date = Date()
    ) -> Bool {
        guard let cached else { return true }
        let token = cached.accessToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else { return true }
        guard let expiresAt = cached.expiresAt else { return false }
        return expiresAt.timeIntervalSince(now) <= accessTokenRefreshLeeway
    }

    static func isUnauthorized(_ error: Error) -> Bool {
        if let http = error as? RealtimePollingHTTPError {
            return http.isUnauthorized
        }
        return false
    }
}

struct RealtimePollTableSpec: Equatable {
    let entity: RealtimeEntityType
    let table: String
}

enum RealtimePollTickOutcome: Equatable {
    case allSucceeded
    case partialFailure(failedTables: [String])
    case allFailed(failedTables: [String])

    static func from(failedTables: [String], totalTables: Int) -> RealtimePollTickOutcome {
        if failedTables.isEmpty {
            return .allSucceeded
        }
        if totalTables > 0, failedTables.count >= totalTables {
            return .allFailed(failedTables: failedTables)
        }
        return .partialFailure(failedTables: failedTables)
    }

    var shouldApplyErrorBackoff: Bool {
        if case .allFailed = self { return true }
        return false
    }
}

struct RealtimePollingHTTPError: LocalizedError, Equatable {
    let table: String
    let statusCode: Int
    let body: String

    var isUnauthorized: Bool { statusCode == 401 }

    var errorDescription: String? {
        "Realtime polling failed (\(table) \(statusCode)): \(body)"
    }
}
