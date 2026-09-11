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

    static let subscribedTables = [
        "children",
        "child_activities",
        "household_memberships",
        "runs",
        "run_driver_positions"
    ]
}
