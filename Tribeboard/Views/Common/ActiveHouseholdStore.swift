import Foundation
import Combine

@MainActor
final class ActiveHouseholdStore: ObservableObject {
    @Published private(set) var activeHouseholdId: UUID?
    let restoredActiveHouseholdId: UUID?
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        let restored = userDefaults.activeHouseholdId
        self.restoredActiveHouseholdId = restored
        self.activeHouseholdId = restored
#if DEBUG
        print("[ActiveHouseholdStore] restored activeHouseholdId=\(restored?.uuidString ?? "nil")")
#endif
    }

    func setActiveHousehold(id: UUID?) {
        guard activeHouseholdId != id else { return }
        activeHouseholdId = id
        userDefaults.activeHouseholdId = id
    }

    func clear() {
        setActiveHousehold(id: nil)
    }
}
