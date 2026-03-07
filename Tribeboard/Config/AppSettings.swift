import Foundation

enum AppSettings {
    static let notificationLeadMinutesKey = "settings.notificationLeadMinutes"
    static let arrivalRadiusMetersKey = "settings.arrivalRadiusMeters"
    static let allowGoogleMapsKey = "settings.allowGoogleMaps"
    static let allowWazeKey = "settings.allowWaze"
    static let etaDefaultSpeedMetersPerSecondKey = "settings.etaDefaultSpeedMetersPerSecond"
    static let etaDwellTimePerStopSecondsKey = "settings.etaDwellTimePerStopSeconds"

    static var notificationLeadMinutes: Int {
        let stored = UserDefaults.standard.object(forKey: notificationLeadMinutesKey) as? Int
        return max(1, stored ?? 15)
    }

    static var arrivalRadiusMeters: Double {
        let stored = UserDefaults.standard.object(forKey: arrivalRadiusMetersKey) as? Double
        return max(10, stored ?? 100)
    }

    static var allowGoogleMaps: Bool {
        let stored = UserDefaults.standard.object(forKey: allowGoogleMapsKey) as? Bool
        return stored ?? true
    }

    static var allowWaze: Bool {
        let stored = UserDefaults.standard.object(forKey: allowWazeKey) as? Bool
        return stored ?? true
    }

    static var etaDefaultSpeedMetersPerSecond: Double {
        let stored = UserDefaults.standard.object(forKey: etaDefaultSpeedMetersPerSecondKey) as? Double
        return max(3.0, stored ?? 8.33)
    }

    static var etaDwellTimePerStopSeconds: Double {
        let stored = UserDefaults.standard.object(forKey: etaDwellTimePerStopSecondsKey) as? Double
        return max(0.0, stored ?? 90)
    }
}
