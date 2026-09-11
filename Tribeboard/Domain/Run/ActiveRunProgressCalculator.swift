import Foundation

struct ActiveRunProgress: Equatable {
    let completedStops: Int
    let totalStops: Int
    let activeStopIndex: Int
    let fraction: Double
    let statusLabel: String
}

enum ActiveRunProgressCalculator {
    static func progress(for run: SystemDomain.RunInstance) -> ActiveRunProgress {
        let total = max(run.stops.count, 1)
        let completed = run.stops.filter { $0.status == .completed || $0.status == .skipped }.count
        let activeIndex = run.activeStopIndex ?? min(completed, total - 1)
        let fraction = total > 0 ? Double(completed) / Double(total) : 0
        let current = min(activeIndex + 1, total)
        return ActiveRunProgress(
            completedStops: completed,
            totalStops: total,
            activeStopIndex: activeIndex,
            fraction: fraction,
            statusLabel: "Stop \(current) of \(total)"
        )
    }
}
