import XCTest
@testable import Tribeboard

final class AssignDriverEligibilityTests: XCTestCase {
    func testIncludesCurrentUserEvenWhenObserver() {
        let householdId = UUID()
        let userId = UUID()
        let membership = makeMembership(
            householdId: householdId,
            userId: userId,
            accessRole: "observer",
            familyRole: nil,
            status: "active"
        )
        let candidates = AssignDriverEligibility.resolve(
            activeHouseholdId: householdId,
            memberships: [membership],
            profilesByUserId: [userId: makeProfile(id: userId, display: "Me")],
            householdPeople: [],
            childIds: [],
            currentUserId: userId
        )
        XCTAssertEqual(candidates.map(\.id), [userId])
        XCTAssertEqual(candidates.first?.displayName, "Me")
    }

    func testExcludesPendingMembershipAndChildren() {
        let householdId = UUID()
        let pendingUser = UUID()
        let childId = UUID()
        let person = BackendHouseholdPerson(
            id: childId,
            householdId: householdId,
            name: "Child Person",
            relationship: "Child",
            role: "child",
            phone: nil,
            isDriver: true,
            createdAt: nil,
            updatedAt: nil
        )
        let candidates = AssignDriverEligibility.resolve(
            activeHouseholdId: householdId,
            memberships: [
                makeMembership(
                    householdId: householdId,
                    userId: pendingUser,
                    accessRole: "driver",
                    familyRole: "parent",
                    status: "pending"
                )
            ],
            profilesByUserId: [:],
            householdPeople: [person],
            childIds: [childId],
            currentUserId: UUID()
        )
        XCTAssertTrue(candidates.isEmpty)
    }

    func testIncludesHouseholdPersonMarkedAsDriver() {
        let householdId = UUID()
        let personId = UUID()
        let person = BackendHouseholdPerson(
            id: personId,
            householdId: householdId,
            name: "Aunt Nyasha",
            relationship: "Aunt",
            role: "adult",
            phone: nil,
            isDriver: true,
            createdAt: nil,
            updatedAt: nil
        )
        let candidates = AssignDriverEligibility.resolve(
            activeHouseholdId: householdId,
            memberships: [],
            profilesByUserId: [:],
            householdPeople: [person],
            childIds: [],
            currentUserId: nil
        )
        XCTAssertEqual(candidates.map(\.id), [personId])
        XCTAssertEqual(candidates.first?.source, .householdPerson)
        XCTAssertEqual(candidates.first?.role, "driver")
    }

    func testDisplayNamePrefersProfileThenRelationshipThenPerson() {
        XCTAssertEqual(
            AssignDriverCandidateDisplayName.resolve(
                profile: makeProfile(id: UUID(), display: "  Rue  "),
                relationshipLabel: "Mum",
                householdPersonName: "Person"
            ),
            "Rue"
        )
        XCTAssertEqual(
            AssignDriverCandidateDisplayName.resolve(
                profile: nil,
                relationshipLabel: "Mum",
                householdPersonName: "Person"
            ),
            "Mum"
        )
        XCTAssertEqual(
            AssignDriverCandidateDisplayName.resolve(
                profile: nil,
                relationshipLabel: "  ",
                householdPersonName: "Aunt Nyasha"
            ),
            "Aunt Nyasha"
        )
    }

    private func makeMembership(
        householdId: UUID,
        userId: UUID,
        accessRole: String,
        familyRole: String?,
        status: String
    ) -> BackendHouseholdMembership {
        BackendHouseholdMembership(
            id: UUID(),
            householdId: householdId,
            userId: userId,
            role: "member",
            status: status,
            accessRole: accessRole,
            familyRole: familyRole,
            relationshipLabel: nil,
            invitedByUserId: nil,
            createdAt: nil,
            updatedAt: nil
        )
    }

    private func makeProfile(id: UUID, display: String) -> BackendProfile {
        BackendProfile(
            id: id,
            email: "user@example.com",
            display_name: display,
            first_name: nil,
            last_name: nil,
            avatar_type: nil,
            avatar_key: nil,
            avatar_url: nil,
            avatar_updated_at: nil,
            created_at: nil,
            updated_at: nil
        )
    }
}
