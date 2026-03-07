import Foundation

final class SyncAuditStore {
    private struct SyncAuditEnvelope: Codable {
        let schemaVersion: Int
        let records: [SyncAuditRecord]
    }

    private let schemaVersion = 1
    private let fileName = "sync_audit.json"
    private let fileStore: JSONFileStore

    init(fileStore: JSONFileStore = JSONFileStore()) {
        self.fileStore = fileStore
    }

    func load() -> [SyncAuditRecord] {
        guard fileStore.fileExists(fileName: fileName) else { return [] }
        do {
            let payload = try fileStore.load(SyncAuditEnvelope.self, from: fileName)
            guard payload.schemaVersion == schemaVersion else {
#if DEBUG
                print("SyncAuditStore.load -> schema mismatch for \(fileName): found \(payload.schemaVersion), expected \(schemaVersion). Returning empty.")
#endif
                return []
            }
            return payload.records
        } catch {
            recoverCorruptFile()
            return []
        }
    }

    func save(_ records: [SyncAuditRecord]) {
        let payload = SyncAuditEnvelope(schemaVersion: schemaVersion, records: records)
        do {
            try fileStore.save(payload, to: fileName)
        } catch {
#if DEBUG
            print("SyncAuditStore.save -> failed to save \(fileName): \(error)")
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
        print("SyncAuditStore.load -> moved corrupt file to \(corruptURL.lastPathComponent)")
#endif
    }
}
