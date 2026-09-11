import Foundation
import Combine

@MainActor
final class ActiveHouseholdContext: ObservableObject {
    @Published var householdId: UUID
    @Published var householdName: String

    init(
        householdId: UUID? = nil,
        householdName: String? = nil
    ) {
        self.householdId = householdId ?? HouseholdDefaults.defaultHouseholdId
        self.householdName = householdName ?? HouseholdDefaults.defaultHouseholdName
    }
}
