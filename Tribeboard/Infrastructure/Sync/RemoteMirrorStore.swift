import Foundation

final class RemoteMirrorStore {
    struct Snapshot: Codable {
        let schemaVersion: Int
        var runs: [SystemDomain.RunInstance]
        var schedules: [SystemDomain.ScheduleTemplate]
        var drivers: [SystemDomain.Driver]
        var households: [Household]
        var changes: [ResolvedSyncChange]
    }

    private let schemaVersion = 1
    private let fileName = "remote_mirror.json"
    private let fileStore: JSONFileStore

    init(fileStore: JSONFileStore = JSONFileStore()) {
        self.fileStore = fileStore
    }

    func load() -> Snapshot {
        guard fileStore.fileExists(fileName: fileName) else { return .empty(schemaVersion: schemaVersion) }
        do {
            let payload = try fileStore.load(Snapshot.self, from: fileName)
            guard payload.schemaVersion == schemaVersion else {
#if DEBUG
                print("RemoteMirrorStore.load -> schema mismatch for \(fileName): found \(payload.schemaVersion), expected \(schemaVersion). Returning empty.")
#endif
                return .empty(schemaVersion: schemaVersion)
            }
            return payload
        } catch {
            recoverCorruptFile()
            return .empty(schemaVersion: schemaVersion)
        }
    }

    func save(_ snapshot: Snapshot) {
        do {
            try fileStore.save(snapshot, to: fileName)
        } catch {
#if DEBUG
            print("RemoteMirrorStore.save -> failed to save \(fileName): \(error)")
#endif
        }
    }

    private func recoverCorruptFile() {
        guard let directory = try? fileStore.applicationSupportDirectoryURL() else { return }
        let sourceURL = directory.appendingPathComponent(fileName, isDirectory: false)
        guard FileManager.default.fileExists(atPath: sourceURL.path) else { return }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let stamp = formatter.string(from: Date())
        let corruptURL = directory.appendingPathComponent("\(fileName).corrupt-\(stamp).json", isDirectory: false)
        try? FileManager.default.moveItem(at: sourceURL, to: corruptURL)
#if DEBUG
        print("RemoteMirrorStore.load -> moved corrupt file to \(corruptURL.lastPathComponent)")
#endif
    }
}

private extension RemoteMirrorStore.Snapshot {
    static func empty(schemaVersion: Int) -> Self {
        Self(
            schemaVersion: schemaVersion,
            runs: [],
            schedules: [],
            drivers: [],
            households: [],
            changes: []
        )
    }
}

