import CryptoKit
import Foundation

/// Helpers for the Create Run (manual) flow: stable IDs, child resolution, and a local placeholder schedule when none exist.
enum RunStopLabelCodec {
    static let pickup = "Pickup"
    static let dropoff = "Dropoff"

    static func isStopKind(_ raw: String) -> Bool {
        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalized == pickup.lowercased() || normalized == dropoff.lowercased()
    }

    static func backendLabel(for snapshot: SystemDomain.Stop, order: Int, total: Int) -> String {
        let placeName = snapshot.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !placeName.isEmpty {
            return placeName
        }
        if let kind = normalizedKind(snapshot.kind) {
            return kind
        }
        return inferredKind(order: order, total: total)
    }

    static func inferredKind(order: Int, total: Int) -> String {
        if order == 0 { return pickup }
        if total > 1, order == total - 1 { return dropoff }
        return order == 0 ? pickup : dropoff
    }

    static func normalizedKind(_ raw: String?) -> String? {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return nil }
        switch raw.lowercased() {
        case "pickup": return pickup
        case "dropoff": return dropoff
        default: return isStopKind(raw) ? raw : nil
        }
    }
}

enum ManualRunCreationSupport {
    /// Well-known template id for ad-hoc runs that may not exist on the remote schedule API.
    static let manualRunAnchorTemplateId = UUID(uuidString: "AD0E0000-0000-4000-8000-000000000001")!

    static func stableUUID(namespace: UUID, string: String) -> UUID {
        var data = Data()
        data.append(contentsOf: namespace.uuidString.utf8)
        data.append(0)
        data.append(contentsOf: string.utf8)
        let digest = SHA256.hash(data: data)
        let bytes = Array(digest.prefix(16))
        return UUID(
            uuid: (
                bytes[0], bytes[1], bytes[2], bytes[3],
                bytes[4], bytes[5], bytes[6], bytes[7],
                bytes[8], bytes[9], bytes[10], bytes[11],
                bytes[12], bytes[13], bytes[14], bytes[15]
            )
        )
    }

    static func resolveChildId(passengerNames: [String], children: [BackendChild], householdId: UUID) -> UUID? {
        let scoped = children.filter { $0.householdId == householdId }
        for name in passengerNames {
            let key = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !key.isEmpty else { continue }
            if let match = scoped.first(where: { child in
                [child.displayName, child.legalName].compactMap { $0 }.contains { cand in
                    cand.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == key
                }
            }) {
                return match.id
            }
        }
        return scoped.first?.id
    }

    static func placeholderScheduleTemplate(
        householdId: UUID,
        childId: UUID,
        anchorDate: Date
    ) -> SystemDomain.ScheduleTemplate {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: anchorDate)
        let minute = calendar.component(.minute, from: anchorDate)
        let placeholderStopA = SystemDomain.Stop(
            id: stableUUID(namespace: householdId, string: "manual-placeholder-a"),
            name: "Manual anchor A",
            latitude: 0,
            longitude: 0,
            order: 0
        )
        let placeholderStopB = SystemDomain.Stop(
            id: stableUUID(namespace: householdId, string: "manual-placeholder-b"),
            name: "Manual anchor B",
            latitude: 0,
            longitude: 0,
            order: 1
        )
        return SystemDomain.ScheduleTemplate(
            id: manualRunAnchorTemplateId,
            householdId: householdId,
            name: "Manual / one-off runs",
            childId: childId,
            driverId: nil,
            weekdays: [1, 2, 3, 4, 5, 6, 7],
            hour: hour,
            minute: minute,
            stops: [placeholderStopA, placeholderStopB],
            isActive: true,
            createdAt: Date()
        )
    }
}
