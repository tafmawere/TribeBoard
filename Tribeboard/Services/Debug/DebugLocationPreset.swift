#if DEBUG
import CoreLocation
import Foundation

enum DebugLocationPreset: String, CaseIterable, Identifiable, Codable {
    case device
    case hydePark
    case stStithians
    case homeToSchoolRoute
    case schoolToHomeRoute

    var id: String { rawValue }

    var title: String {
        switch self {
        case .device:
            return "Current Device Location"
        case .hydePark:
            return "Hyde Park"
        case .stStithians:
            return "St Stithians"
        case .homeToSchoolRoute:
            return "Home → School Route"
        case .schoolToHomeRoute:
            return "School → Home Route"
        }
    }

    var subtitle: String {
        switch self {
        case .device:
            return "Use live GPS from this device"
        case .hydePark:
            return "Fixed point at Hyde Park Corner"
        case .stStithians:
            return "Fixed point at St Stithians College"
        case .homeToSchoolRoute:
            return "Simulated drive from home to school"
        case .schoolToHomeRoute:
            return "Simulated drive from school to home"
        }
    }

    var isMock: Bool {
        self != .device
    }

    static let hydeParkCoordinate = CLLocationCoordinate2D(latitude: -26.1445, longitude: 28.0286)
    static let stStithiansCoordinate = CLLocationCoordinate2D(latitude: -26.0706, longitude: 28.0392)
    static let homeCoordinate = CLLocationCoordinate2D(latitude: -26.1459, longitude: 28.0418)

    static func routeCoordinates(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D) -> [CLLocationCoordinate2D] {
        let steps = 18
        guard steps > 0 else { return [start, end] }
        return (0...steps).map { step in
            let fraction = Double(step) / Double(steps)
            return CLLocationCoordinate2D(
                latitude: start.latitude + (end.latitude - start.latitude) * fraction,
                longitude: start.longitude + (end.longitude - start.longitude) * fraction
            )
        }
    }

    var routeCoordinates: [CLLocationCoordinate2D]? {
        switch self {
        case .homeToSchoolRoute:
            return Self.routeCoordinates(from: Self.homeCoordinate, to: Self.stStithiansCoordinate)
        case .schoolToHomeRoute:
            return Self.routeCoordinates(from: Self.stStithiansCoordinate, to: Self.homeCoordinate)
        default:
            return nil
        }
    }

    var fixedCoordinate: CLLocationCoordinate2D? {
        switch self {
        case .hydePark:
            return Self.hydeParkCoordinate
        case .stStithians:
            return Self.stStithiansCoordinate
        default:
            return nil
        }
    }
}

enum DebugLocationPreferences {
    static let presetKey = "debug.location.preset"

    static var selectedPreset: DebugLocationPreset {
        get {
            guard let raw = UserDefaults.standard.string(forKey: presetKey),
                  let preset = DebugLocationPreset(rawValue: raw) else {
                return .device
            }
            return preset
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: presetKey)
        }
    }
}
#endif
