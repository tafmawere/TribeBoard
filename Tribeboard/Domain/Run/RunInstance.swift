import Foundation

extension SystemDomain {
    struct RunInstance: Identifiable, Codable {
        // Stable identity for cross-device/backend sync. Must decode exactly as persisted.
        var id: UUID
        // Ownership anchor for household/tenant scope in future sync and permissions.
        let householdId: UUID
        var templateId: UUID
        var title: String?
        var date: Date
        var status: RunStatus
        var stops: [RunStopProgress]
        var stopSnapshots: [Stop]
        var startedAt: Date?
        var completedAt: Date?
        var cancelledAt: Date?
        var activeStopIndex: Int?
        var assignedDriverId: UUID?
        var assignedDriverName: String?
        var driverId: UUID?
        var childId: UUID
        var createdAt: Date

        enum CodingKeys: String, CodingKey {
            case id
            case householdId
            case templateId
            case title
            case date
            case status
            case stops
            case stopSnapshots
            case startedAt
            case completedAt
            case cancelledAt
            case activeStopIndex
            case assignedDriverId
            case assignedDriverName
            case driverId
            case childId
            case createdAt
        }

        init(
            id: UUID,
            householdId: UUID = HouseholdDefaults.defaultHouseholdId,
            templateId: UUID,
            title: String?,
            date: Date,
            status: RunStatus,
            stops: [RunStopProgress],
            stopSnapshots: [Stop],
            startedAt: Date? = nil,
            completedAt: Date? = nil,
            cancelledAt: Date? = nil,
            activeStopIndex: Int? = nil,
            assignedDriverId: UUID? = nil,
            assignedDriverName: String? = nil,
            driverId: UUID?,
            childId: UUID,
            createdAt: Date
        ) {
            self.id = id
            self.householdId = householdId
            self.templateId = templateId
            self.title = title
            self.date = date
            self.status = status
            self.stops = stops
            self.stopSnapshots = stopSnapshots
            self.startedAt = startedAt
            self.completedAt = completedAt
            self.cancelledAt = cancelledAt
            self.activeStopIndex = activeStopIndex
            self.assignedDriverId = assignedDriverId ?? driverId
            self.assignedDriverName = assignedDriverName
            self.driverId = driverId
            self.childId = childId
            self.createdAt = createdAt
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            // Never regenerate IDs during decode/migration.
            id = try container.decode(UUID.self, forKey: .id)
            if let decodedHouseholdId = try container.decodeIfPresent(UUID.self, forKey: .householdId) {
                householdId = decodedHouseholdId
            } else {
                householdId = HouseholdDefaults.defaultHouseholdId
#if DEBUG
                print("RunInstance.decode -> missing householdId for run \(id); defaulting to \(householdId).")
#endif
            }
            templateId = try container.decode(UUID.self, forKey: .templateId)
            title = try container.decodeIfPresent(String.self, forKey: .title)
            date = try container.decode(Date.self, forKey: .date)
            status = try container.decodeIfPresent(RunStatus.self, forKey: .status) ?? .scheduled
            stopSnapshots = try container.decodeIfPresent([Stop].self, forKey: .stopSnapshots) ?? []

            if let decodedStops = try container.decodeIfPresent([RunStopProgress].self, forKey: .stops) {
                stops = decodedStops
            } else if let legacyStops = try container.decodeIfPresent([Stop].self, forKey: .stops) {
                stopSnapshots = legacyStops
                stops = legacyStops.sorted { $0.order < $1.order }.map {
                    RunStopProgress(stopId: $0.id, status: .pending, arrivedAt: nil, departedAt: nil)
                }
            } else {
                stops = []
            }

            startedAt = try container.decodeIfPresent(Date.self, forKey: .startedAt)
            completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
            cancelledAt = try container.decodeIfPresent(Date.self, forKey: .cancelledAt)
            activeStopIndex = try container.decodeIfPresent(Int.self, forKey: .activeStopIndex)
            assignedDriverId = try container.decodeIfPresent(UUID.self, forKey: .assignedDriverId)
            assignedDriverName = try container.decodeIfPresent(String.self, forKey: .assignedDriverName)
            driverId = try container.decodeIfPresent(UUID.self, forKey: .driverId)
            if assignedDriverId == nil {
                assignedDriverId = driverId
            }
            childId = try container.decode(UUID.self, forKey: .childId)
            createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        }
    }
}
