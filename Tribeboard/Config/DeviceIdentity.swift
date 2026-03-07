import Foundation

enum DeviceIdentity {
    private static let defaultsKey = "tb.device.identity"

    static var current: String {
        let defaults = UserDefaults.standard
        if let existing = defaults.string(forKey: defaultsKey), !existing.isEmpty {
            return existing
        }
        let generated = UUID().uuidString
        defaults.set(generated, forKey: defaultsKey)
        return generated
    }
}
