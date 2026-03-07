import Foundation

struct ResolvedSyncChange: Identifiable, Codable {
    let change: SyncChange
    let run: SystemDomain.RunInstance?
    let schedule: SystemDomain.ScheduleTemplate?
    let driver: SystemDomain.Driver?
    let household: Household?

    var id: UUID { change.id }
}

struct RemoteMirrorCounts: Equatable {
    let runs: Int
    let schedules: Int
    let drivers: Int
    let households: Int
    let changes: Int
}

protocol RemoteSyncDriver {
    func push(changes: [ResolvedSyncChange]) async throws
    func pull(since: Date?, householdId: UUID?) async throws -> [ResolvedSyncChange]
}

protocol RemoteSyncDebuggable {
    func seedRemoteMirrorDemoData(for householdId: UUID) async throws
    func seedDuplicateRemoteChange(for householdId: UUID) async throws
    func seedStaleRemoteChange(for householdId: UUID) async throws
    func seedNewerRemoteChange(for householdId: UUID) async throws
    func clearRemoteMirror() async throws
    func remoteMirrorCounts() async throws -> RemoteMirrorCounts
}

