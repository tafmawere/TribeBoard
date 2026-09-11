import Foundation

final class DriverStore {
    typealias DomainDriver = SystemDomain.Driver

    private struct DemoDriverSeed {
        let id: String
        let name: String
        let phoneNumber: String?
    }

    private struct PersistedDriversPayload: Codable {
        let schemaVersion: Int
        let drivers: [DomainDriver]
    }

    private let schemaVersion = 1
    private let fileName = "drivers.json"
    private let fileStore: JSONFileStore

    init(fileStore: JSONFileStore = JSONFileStore()) {
        self.fileStore = fileStore
    }

    func load() -> [DomainDriver] {
        guard fileStore.fileExists(fileName: fileName) else { return [] }
        let drivers: [DomainDriver]
        do {
            let payload = try fileStore.load(PersistedDriversPayload.self, from: fileName)
            if payload.schemaVersion != schemaVersion {
#if DEBUG
                print("DriverStore.load -> schema mismatch for \(fileName): found \(payload.schemaVersion), expected \(schemaVersion). Returning empty.")
#endif
                return []
            }
            drivers = payload.drivers
        } catch {
            do {
                let legacyDrivers = try fileStore.load([DomainDriver].self, from: fileName)
                drivers = legacyDrivers
                save(legacyDrivers)
#if DEBUG
                print("DriverStore.load -> migrated legacy array format for \(fileName).")
#endif
            } catch {
#if DEBUG
                print("DriverStore.load -> failed to decode \(fileName). Marking file as corrupt.")
#endif
                recoverCorruptFile()
                return []
            }
        }
#if DEBUG
        let storage = JSONFileStore.debugStorageDirectory().path
        print("DriverStore.load -> file: \(fileName), dir: \(storage), count: \(drivers.count)")
#endif
        return drivers
    }

    func save(_ drivers: [DomainDriver]) {
        let payload = PersistedDriversPayload(schemaVersion: schemaVersion, drivers: drivers)
        do {
            try fileStore.save(payload, to: fileName)
        } catch {
#if DEBUG
            print("DriverStore.save -> failed to save \(fileName): \(error)")
#endif
        }
#if DEBUG
        let storage = JSONFileStore.debugStorageDirectory().path
        print("DriverStore.save -> file: \(fileName), dir: \(storage), count: \(drivers.count)")
#endif
    }

    func upsert(_ driver: DomainDriver) {
        var drivers = load()
        if let index = drivers.firstIndex(where: { $0.id == driver.id }) {
            drivers[index] = driver
        } else {
            drivers.append(driver)
        }
        save(drivers)
    }

    func remove(id: UUID) {
        let filtered = load().filter { $0.id != id }
        save(filtered)
    }

    func seedDemoIfNeeded() {
        guard AppConfig.isDemoFlowEnabled else { return }
        let existing = load()
        guard existing.isEmpty else { return }
        seedDemoDrivers()
    }

    func seedDemoDrivers() {
        guard AppConfig.isDemoFlowEnabled else { return }
        var drivers = load()
        let now = Date()
        for demo in Self.demoSeeds {
            guard let id = UUID(uuidString: demo.id) else { continue }
            if drivers.contains(where: { $0.id == id }) {
                continue
            }
            drivers.append(
                DomainDriver(
                    id: id,
                    name: demo.name,
                    phoneNumber: demo.phoneNumber,
                    isActive: true,
                    createdAt: now
                )
            )
        }
        save(drivers)
    }

    func clearAll() {
        save([])
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
        print("DriverStore.load -> moved corrupt file to \(corruptURL.lastPathComponent)")
#endif
    }

    private static let demoSeeds: [DemoDriverSeed] = [
        DemoDriverSeed(id: "A1000000-0000-0000-0000-000000000001", name: "Tafadzwa", phoneNumber: "+263771000001"),
        DemoDriverSeed(id: "A1000000-0000-0000-0000-000000000002", name: "Rue", phoneNumber: "+263771000002"),
        DemoDriverSeed(id: "A1000000-0000-0000-0000-000000000003", name: "Alex", phoneNumber: "+263771000003"),
        DemoDriverSeed(id: "A1000000-0000-0000-0000-000000000004", name: "Nyasha", phoneNumber: "+263771000004")
    ]
}
