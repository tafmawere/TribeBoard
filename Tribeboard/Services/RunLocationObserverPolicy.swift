import Foundation

/// When `RunLocationObserverStore` may hit `run_driver_positions`.
/// Keep this REST observer gated — it is not a Realtime protocol change.
enum RunLocationObserverPolicy {
    static let pollIntervalNanoseconds: UInt64 = 7_000_000_000
    static let pollInterval: TimeInterval = 7

    static func shouldPoll(hasInProgressRun: Bool, isSceneActive: Bool) -> Bool {
        hasInProgressRun && isSceneActive
    }
}
