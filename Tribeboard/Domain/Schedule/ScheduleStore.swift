import Foundation

final class ScheduleStore {
    typealias DomainScheduleTemplate = SystemDomain.ScheduleTemplate
    typealias DomainStop = SystemDomain.Stop

    private struct PersistedSchedulesPayload: Codable {
        let schemaVersion: Int
        let templates: [DomainScheduleTemplate]
    }

    private let schemaVersion = 1
    private let fileName = "schedule_templates.json"
    private let fileStore: JSONFileStore

    private let demoTemplateDropoffIDString = "11111111-2222-3333-4444-555555555555"
    private let demoTemplatePickupIDString = "66666666-7777-8888-9999-AAAAAAAAAAAA"
    private let demoChildIDString = "BBBBBBBB-CCCC-DDDD-EEEE-FFFFFFFFFFFF"

    private let dropoffHomeStopIDString = "D1D1D1D1-1111-1111-1111-111111111111"
    private let dropoffFriendStopIDString = "D2D2D2D2-2222-2222-2222-222222222222"
    private let dropoffSchoolStopIDString = "D3D3D3D3-3333-3333-3333-333333333333"
    private let pickupHomeStopIDString = "A1A1A1A1-1111-1111-1111-111111111111"
    private let pickupFriendStopIDString = "A2A2A2A2-2222-2222-2222-222222222222"
    private let pickupSchoolStopIDString = "A3A3A3A3-3333-3333-3333-333333333333"

    private var demoTemplateDropoffID: UUID { UUID(uuidString: demoTemplateDropoffIDString)! }
    private var demoTemplatePickupID: UUID { UUID(uuidString: demoTemplatePickupIDString)! }
    private var demoChildID: UUID { UUID(uuidString: demoChildIDString)! }

    init(fileStore: JSONFileStore = JSONFileStore()) {
        self.fileStore = fileStore
    }

    func load() -> [DomainScheduleTemplate] {
        guard fileStore.fileExists(fileName: fileName) else { return [] }
        do {
            let payload = try fileStore.load(PersistedSchedulesPayload.self, from: fileName)
            if payload.schemaVersion != schemaVersion {
#if DEBUG
                print("ScheduleStore.load -> schema mismatch for \(fileName): found \(payload.schemaVersion), expected \(schemaVersion). Returning empty.")
#endif
                return []
            }
            let templates = payload.templates
#if DEBUG
            let storage = JSONFileStore.debugStorageDirectory().path
            print("ScheduleStore.load -> file: \(fileName), dir: \(storage), count: \(templates.count)")
#endif
            return templates
        } catch {
            do {
                let legacy = try fileStore.load([DomainScheduleTemplate].self, from: fileName)
                save(legacy)
#if DEBUG
                print("ScheduleStore.load -> migrated legacy array format for \(fileName).")
#endif
                return legacy
            } catch {
#if DEBUG
                print("ScheduleStore.load -> failed to decode \(fileName). Marking file as corrupt.")
#endif
                recoverCorruptFile()
                return []
            }
        }
    }

    func save(_ templates: [DomainScheduleTemplate]) {
        let validTemplates = templates.filter(isValidTemplate)
        let payload = PersistedSchedulesPayload(schemaVersion: schemaVersion, templates: validTemplates)
        do {
            try fileStore.save(payload, to: fileName)
#if DEBUG
            let storage = JSONFileStore.debugStorageDirectory().path
            print("ScheduleStore.save -> file: \(fileName), dir: \(storage), count: \(validTemplates.count)")
#endif
        } catch {
#if DEBUG
            print("ScheduleStore.save -> failed to save \(fileName): \(error)")
#endif
        }
    }

    func add(_ template: DomainScheduleTemplate) {
        guard isValidTemplate(template) else { return }
        var templates = load()
        templates.append(template)
        save(templates)
    }

    func remove(id: UUID) {
        let templates = load().filter { $0.id != id }
        save(templates)
    }

    func update(_ template: DomainScheduleTemplate) {
        guard isValidTemplate(template) else { return }
        var templates = load()
        if let index = templates.firstIndex(where: { $0.id == template.id }) {
            templates[index] = template
            save(templates)
        }
    }

    func validationError(for template: DomainScheduleTemplate) -> String? {
        if template.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Schedule title is required."
        }
        if template.weekdays.isEmpty {
            return "Select at least one weekday."
        }
        if template.stops.count < 2 {
            return "At least 2 stops are required."
        }
        for stop in template.stops {
            if stop.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return "Each stop needs a label."
            }
            if !(-90.0...90.0).contains(stop.latitude) {
                return "Stop latitude must be between -90 and 90."
            }
            if !(-180.0...180.0).contains(stop.longitude) {
                return "Stop longitude must be between -180 and 180."
            }
        }
        return nil
    }

    func seedDemoIfNeeded() {
#if DEBUG
        assert(UUID(uuidString: demoTemplateDropoffIDString) != nil, "Invalid UUID: \(demoTemplateDropoffIDString)")
        assert(UUID(uuidString: demoTemplatePickupIDString) != nil, "Invalid UUID: \(demoTemplatePickupIDString)")
        assert(UUID(uuidString: demoChildIDString) != nil, "Invalid UUID: \(demoChildIDString)")
        assert(UUID(uuidString: dropoffHomeStopIDString) != nil, "Invalid UUID: \(dropoffHomeStopIDString)")
        assert(UUID(uuidString: dropoffFriendStopIDString) != nil, "Invalid UUID: \(dropoffFriendStopIDString)")
        assert(UUID(uuidString: dropoffSchoolStopIDString) != nil, "Invalid UUID: \(dropoffSchoolStopIDString)")
        assert(UUID(uuidString: pickupHomeStopIDString) != nil, "Invalid UUID: \(pickupHomeStopIDString)")
        assert(UUID(uuidString: pickupFriendStopIDString) != nil, "Invalid UUID: \(pickupFriendStopIDString)")
        assert(UUID(uuidString: pickupSchoolStopIDString) != nil, "Invalid UUID: \(pickupSchoolStopIDString)")
#endif

        var templates = load()
        let hasDropoff = templates.contains { $0.name == "School Dropoff" }
        let hasPickup = templates.contains { $0.name == "School Pickup" }
        let shouldSeed = templates.isEmpty || !hasDropoff || !hasPickup
        guard shouldSeed else { return }

        if !hasDropoff {
            templates.append(
                DomainScheduleTemplate(
                    id: demoTemplateDropoffID,
                    name: "School Dropoff",
                    childId: demoChildID,
                    driverId: nil,
                    weekdays: [2, 3, 4, 5, 6], // Mon-Fri
                    hour: 6,
                    minute: 45,
                    stops: demoStops(prefix: "dropoff"),
                    isActive: true,
                    createdAt: Date()
                )
            )
        }

        if !hasPickup {
            templates.append(
                DomainScheduleTemplate(
                    id: demoTemplatePickupID,
                    name: "School Pickup",
                    childId: demoChildID,
                    driverId: nil,
                    weekdays: [2, 3, 4, 5, 6], // Mon-Fri
                    hour: 14,
                    minute: 30,
                    stops: demoStops(prefix: "pickup"),
                    isActive: true,
                    createdAt: Date()
                )
            )
        }

        save(templates)
    }

    private func demoStops(prefix: String) -> [DomainStop] {
        if prefix == "dropoff" {
            return [
                DomainStop(
                    id: UUID(uuidString: dropoffHomeStopIDString)!,
                    name: "Home",
                    latitude: -17.8249,
                    longitude: 31.0530,
                    order: 0
                ),
                DomainStop(
                    id: UUID(uuidString: dropoffFriendStopIDString)!,
                    name: "Friend",
                    latitude: -17.8150,
                    longitude: 31.0602,
                    order: 1
                ),
                DomainStop(
                    id: UUID(uuidString: dropoffSchoolStopIDString)!,
                    name: "School",
                    latitude: -17.8015,
                    longitude: 31.0476,
                    order: 2
                )
            ]
        }

        return [
            DomainStop(
                id: UUID(uuidString: pickupHomeStopIDString)!,
                name: "Home",
                latitude: -17.8249,
                longitude: 31.0530,
                order: 0
            ),
            DomainStop(
                id: UUID(uuidString: pickupFriendStopIDString)!,
                name: "Friend",
                latitude: -17.8150,
                longitude: 31.0602,
                order: 1
            ),
            DomainStop(
                id: UUID(uuidString: pickupSchoolStopIDString)!,
                name: "School",
                latitude: -17.8015,
                longitude: 31.0476,
                order: 2
            )
        ]
    }

    private func isValidTemplate(_ template: DomainScheduleTemplate) -> Bool {
        validationError(for: template) == nil
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
        print("ScheduleStore.load -> moved corrupt file to \(corruptURL.lastPathComponent)")
#endif
    }
}
