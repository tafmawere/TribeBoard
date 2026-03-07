import Foundation

struct ProcessedSyncChange: Identifiable, Codable, Equatable {
    let id: UUID
    let changeId: UUID
    let processedAt: Date
}

final class ProcessedChangeStore {
    private struct ProcessedEnvelope: Codable {
        let schemaVersion: Int
        let processed: [ProcessedSyncChange]
    }

    private let schemaVersion = 1
    private let fileName = "processed_sync_changes.json"
    private let fileStore: JSONFileStore

    init(fileStore: JSONFileStore = JSONFileStore()) {
        self.fileStore = fileStore
    }

    func load() -> [ProcessedSyncChange] {
        guard fileStore.fileExists(fileName: fileName) else { return [] }
        do {
            let payload = try fileStore.load(ProcessedEnvelope.self, from: fileName)
            guard payload.schemaVersion == schemaVersion else {
#if DEBUG
                print("ProcessedChangeStore.load -> schema mismatch for \(fileName): found \(payload.schemaVersion), expected \(schemaVersion). Returning empty.")
#endif
                return []
            }
            return payload.processed
        } catch {
            recoverCorruptFile()
            return []
        }
    }

    func save(_ processed: [ProcessedSyncChange]) {
        let payload = ProcessedEnvelope(schemaVersion: schemaVersion, processed: processed)
        do {
            try fileStore.save(payload, to: fileName)
        } catch {
#if DEBUG
            print("ProcessedChangeStore.save -> failed to save \(fileName): \(error)")
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
        print("ProcessedChangeStore.load -> moved corrupt file to \(corruptURL.lastPathComponent)")
#endif
    }
}
