import Foundation

extension UserDefaults {
    private static let activeHouseholdIdKey = "tb.backend.activeHouseholdId"

    var activeHouseholdId: UUID? {
        get {
            guard let raw = string(forKey: Self.activeHouseholdIdKey) else {
                return nil
            }
            return UUID(uuidString: raw)
        }
        set {
            guard let newValue else {
                removeObject(forKey: Self.activeHouseholdIdKey)
                return
            }
            set(newValue.uuidString, forKey: Self.activeHouseholdIdKey)
        }
    }
}
