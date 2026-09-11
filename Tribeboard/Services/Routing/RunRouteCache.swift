import CoreLocation
import Foundation

actor RunRouteCache {
    private var entries: [String: RouteDirectionsResult] = [:]

    func cacheKey(runId: UUID, stopIndex: Int) -> String {
        "\(runId.uuidString.lowercased())-\(stopIndex)"
    }

    func result(runId: UUID, stopIndex: Int) -> RouteDirectionsResult? {
        entries[cacheKey(runId: runId, stopIndex: stopIndex)]
    }

    func store(_ result: RouteDirectionsResult, runId: UUID, stopIndex: Int) {
        entries[cacheKey(runId: runId, stopIndex: stopIndex)] = result
    }

    func invalidate(runId: UUID) {
        let prefix = runId.uuidString.lowercased()
        entries.keys.filter { $0.hasPrefix(prefix) }.forEach { entries[$0] = nil }
    }

    func clear() {
        entries.removeAll()
    }
}
