#if DEBUG
import CoreLocation
import Foundation

@MainActor
final class DebugLocationController {
    var onInjectLocation: ((CLLocation) -> Void)?

    private(set) var selectedPreset: DebugLocationPreset
    private var routeTimer: Timer?
    private var routeCoordinates: [CLLocationCoordinate2D] = []
    private var routeIndex = 0

    init(preset: DebugLocationPreset = DebugLocationPreferences.selectedPreset) {
        selectedPreset = preset
    }

    var isMockActive: Bool {
        selectedPreset.isMock
    }

    var sourceLabel: String {
        isMockActive ? "MOCK GPS" : "REAL GPS"
    }

    func applyPersistedPreset() {
        apply(selectedPreset)
    }

    func apply(_ preset: DebugLocationPreset) {
        selectedPreset = preset
        DebugLocationPreferences.selectedPreset = preset
        stopRouteSimulation()

        switch preset {
        case .device:
            break
        case .hydePark, .stStithians:
            guard let coordinate = preset.fixedCoordinate else { return }
            inject(makeLocation(at: coordinate, course: 0, speed: 0))
        case .homeToSchoolRoute, .schoolToHomeRoute:
            guard let coordinates = preset.routeCoordinates, coordinates.count >= 2 else { return }
            routeCoordinates = coordinates
            routeIndex = 0
            emitRouteLocation()
            startRouteSimulation()
        }
    }

    func stopMocking() {
        stopRouteSimulation()
    }

    func injectManualLocation(latitude: Double, longitude: Double) {
        inject(makeLocation(
            at: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            course: 0,
            speed: 0
        ))
    }

    private func startRouteSimulation() {
        stopRouteSimulation()
        routeTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.advanceRoute()
            }
        }
    }

    private func stopRouteSimulation() {
        routeTimer?.invalidate()
        routeTimer = nil
        routeCoordinates = []
        routeIndex = 0
    }

    private func advanceRoute() {
        guard !routeCoordinates.isEmpty else { return }
        routeIndex = min(routeIndex + 1, routeCoordinates.count - 1)
        emitRouteLocation()
        if routeIndex >= routeCoordinates.count - 1 {
            stopRouteSimulation()
        }
    }

    private func emitRouteLocation() {
        guard routeIndex < routeCoordinates.count else { return }
        let coordinate = routeCoordinates[routeIndex]
        let nextIndex = min(routeIndex + 1, routeCoordinates.count - 1)
        let nextCoordinate = routeCoordinates[nextIndex]
        let course = Self.bearing(from: coordinate, to: nextCoordinate)
        inject(makeLocation(at: coordinate, course: course, speed: 11.1))
    }

    private func inject(_ location: CLLocation) {
        onInjectLocation?(location)
    }

    private func makeLocation(at coordinate: CLLocationCoordinate2D, course: Double, speed: Double) -> CLLocation {
        CLLocation(
            coordinate: coordinate,
            altitude: 0,
            horizontalAccuracy: 5,
            verticalAccuracy: 5,
            course: course,
            speed: speed,
            timestamp: Date()
        )
    }

    private static func bearing(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D) -> Double {
        let lat1 = start.latitude * .pi / 180
        let lat2 = end.latitude * .pi / 180
        let deltaLon = (end.longitude - start.longitude) * .pi / 180
        let y = sin(deltaLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(deltaLon)
        let radians = atan2(y, x)
        let degrees = radians * 180 / .pi
        return degrees >= 0 ? degrees : degrees + 360
    }
}
#endif
