import Foundation

final class RunStore {
    typealias DomainRunInstance = SystemDomain.RunInstance

    private struct PersistedRunsPayload: Codable {
        let schemaVersion: Int
        let runs: [DomainRunInstance]
    }

    private let schemaVersion = 1
    private let fileName = "run_instances.json"
    private let fileStore: JSONFileStore

    init(fileStore: JSONFileStore = JSONFileStore()) {
        self.fileStore = fileStore
    }

    func load() -> [DomainRunInstance] {
        guard fileStore.fileExists(fileName: fileName) else { return [] }
        let runs: [DomainRunInstance]
        do {
            let payload = try fileStore.load(PersistedRunsPayload.self, from: fileName)
            if payload.schemaVersion != schemaVersion {
#if DEBUG
                print("RunStore.load -> schema mismatch for \(fileName): found \(payload.schemaVersion), expected \(schemaVersion). Returning empty.")
#endif
                return []
            }
            runs = payload.runs
        } catch {
            do {
                let legacyRuns = try fileStore.load([DomainRunInstance].self, from: fileName)
                runs = legacyRuns
                // Legacy migration path: rewrite in versioned envelope.
                save(legacyRuns)
#if DEBUG
                print("RunStore.load -> migrated legacy array format for \(fileName).")
#endif
            } catch {
#if DEBUG
                print("RunStore.load -> failed to decode \(fileName). Marking file as corrupt.")
#endif
                recoverCorruptFile()
                return []
            }
        }
#if DEBUG
        let storage = JSONFileStore.debugStorageDirectory().path
        print("RunStore.load -> file: \(fileName), dir: \(storage), count: \(runs.count)")
#endif
        return runs
    }

    func save(_ runs: [DomainRunInstance]) {
        let payload = PersistedRunsPayload(schemaVersion: schemaVersion, runs: runs)
        do {
            try fileStore.save(payload, to: fileName)
        } catch {
#if DEBUG
            print("RunStore.save -> failed to save \(fileName): \(error)")
#endif
        }
#if DEBUG
        let storage = JSONFileStore.debugStorageDirectory().path
        print("RunStore.save -> file: \(fileName), dir: \(storage), count: \(runs.count)")
#endif
    }

    func add(_ run: DomainRunInstance) {
        var runs = load()
        runs.append(run)
        save(runs)
    }

    func remove(id: UUID) {
        let runs = load().filter { $0.id != id }
        save(runs)
    }

    func update(_ run: DomainRunInstance) {
        var runs = load()
        if let index = runs.firstIndex(where: { $0.id == run.id }) {
            runs[index] = run
            save(runs)
        }
    }

    private func recoverCorruptFile() {
        guard
            let directory = try? fileStore.applicationSupportDirectoryURL()
        else { return }
        let sourceURL = directory.appendingPathComponent(fileName, isDirectory: false)
        guard FileManager.default.fileExists(atPath: sourceURL.path) else { return }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let stamp = formatter.string(from: Date())
        let corruptURL = directory.appendingPathComponent("\(fileName).corrupt-\(stamp).json", isDirectory: false)
        try? FileManager.default.moveItem(at: sourceURL, to: corruptURL)
#if DEBUG
        print("RunStore.load -> moved corrupt file to \(corruptURL.lastPathComponent)")
#endif
    }
}
