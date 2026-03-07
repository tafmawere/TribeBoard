import Foundation
import Combine

@MainActor
final class ActiveHouseholdContext: ObservableObject {
    @Published var householdId: UUID
    @Published var householdName: String

    init(
        householdId: UUID = HouseholdDefaults.defaultHouseholdId,
        householdName: String = HouseholdDefaults.defaultHouseholdName
    ) {
        self.householdId = householdId
        self.householdName = householdName
    }
}
