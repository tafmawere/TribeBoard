import Foundation

struct StoreHealthEntry: Identifiable {
    let id: String
    let fileName: String
    let fileExists: Bool
    let lastModified: Date?
    let sizeBytes: Int64
    let schemaVersionSeen: Int?
    let corruptBackupCount: Int
}

struct StoreHealthReport {
    let entries: [StoreHealthEntry]
}

struct StoreHealthReporter {
    private let fileManager: FileManager
    private let directoryURL: URL

    init(
        fileManager: FileManager = .default,
        directoryURL: URL = JSONFileStore.debugStorageDirectory()
    ) {
        self.fileManager = fileManager
        self.directoryURL = directoryURL
    }

    func generate() -> StoreHealthReport {
        let files = ["run_instances.json", "schedule_templates.json", "drivers.json"]
        return StoreHealthReport(entries: files.map(entry(for:)))
    }

    private func entry(for fileName: String) -> StoreHealthEntry {
        let fileURL = directoryURL.appendingPathComponent(fileName, isDirectory: false)
        let exists = fileManager.fileExists(atPath: fileURL.path)
        let attrs = exists ? (try? fileManager.attributesOfItem(atPath: fileURL.path)) : nil
        let modified = attrs?[.modificationDate] as? Date
        let size = attrs?[.size] as? NSNumber
        let schemaVersion = schemaVersionFromJSON(at: fileURL)
        let corruptCount = corruptBackupCount(for: fileName)
        return StoreHealthEntry(
            id: fileName,
            fileName: fileName,
            fileExists: exists,
            lastModified: modified,
            sizeBytes: size?.int64Value ?? 0,
            schemaVersionSeen: schemaVersion,
            corruptBackupCount: corruptCount
        )
    }

    private func schemaVersionFromJSON(at url: URL) -> Int? {
        guard let data = try? Data(contentsOf: url),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return object["schemaVersion"] as? Int
    }

    private func corruptBackupCount(for fileName: String) -> Int {
        let prefix = "\(fileName).corrupt-"
        guard let items = try? fileManager.contentsOfDirectory(atPath: directoryURL.path) else { return 0 }
        return items.filter { $0.hasPrefix(prefix) }.count
    }
}
