import Foundation

/// Name normalization for household create. Does not touch membership INSERT.
enum HouseholdCreateName {
    static func normalized(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func isUsable(_ name: String) -> Bool {
        !normalized(name).isEmpty
    }
}

/// PostgREST `households` insert body only. Membership rows stay in the existing service path.
struct HouseholdCreateRowPayload: Encodable, Equatable {
    let id: UUID
    let name: String
    let created_by: UUID
    let invite_code: String

    static func make(
        id: UUID,
        name: String,
        createdBy: UUID,
        inviteCode: String
    ) -> HouseholdCreateRowPayload {
        HouseholdCreateRowPayload(
            id: id,
            name: HouseholdCreateName.normalized(name),
            created_by: createdBy,
            invite_code: inviteCode
        )
    }
}
