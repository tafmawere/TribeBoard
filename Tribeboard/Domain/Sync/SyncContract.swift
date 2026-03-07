import Foundation

// Placeholder sync boundary for a future backend integration.
// Responsibilities to be implemented later:
// - pull remote updates into local repositories
// - push local run/schedule/driver changes to backend
// - conflict resolution and merge strategies
// - multi-device consistency guarantees
protocol SyncService {
    func pull() async throws
    func pushRuns(_ runs: [SystemDomain.RunInstance]) async throws
    func pushSchedules(_ schedules: [SystemDomain.ScheduleTemplate]) async throws
    func pushDrivers(_ drivers: [SystemDomain.Driver]) async throws
}
