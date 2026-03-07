import Foundation

struct HouseholdEnvelope: Codable {
    let schemaVersion: Int
    var households: [Household]
}

final class HouseholdStore {
    private let schemaVersion = 1
    private let fileName = "households.json"
    private let fileStore: JSONFileStore

    init(fileStore: JSONFileStore = JSONFileStore()) {
        self.fileStore = fileStore
    }

    func load() throws -> [Household] {
        guard fileStore.fileExists(fileName: fileName) else { return [] }

        do {
            let payload = try fileStore.load(HouseholdEnvelope.self, from: fileName)
            if payload.schemaVersion != schemaVersion {
#if DEBUG
                print("HouseholdStore.load -> schema mismatch for \(fileName): found \(payload.schemaVersion), expected \(schemaVersion). Returning empty.")
#endif
                return []
            }
            return payload.households
        } catch {
            do {
                let legacy = try fileStore.load([Household].self, from: fileName)
                try save(legacy)
#if DEBUG
                print("HouseholdStore.load -> migrated legacy array format for \(fileName).")
#endif
                return legacy
            } catch {
#if DEBUG
                print("HouseholdStore.load -> failed to decode \(fileName). Marking file as corrupt.")
#endif
                recoverCorruptFile()
                return []
            }
        }
    }

    func save(_ households: [Household]) throws {
        let payload = HouseholdEnvelope(schemaVersion: schemaVersion, households: households)
        try fileStore.save(payload, to: fileName)
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
        print("HouseholdStore.load -> moved corrupt file to \(corruptURL.lastPathComponent)")
#endif
    }
}
