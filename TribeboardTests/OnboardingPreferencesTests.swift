import XCTest
@testable import Tribeboard

final class OnboardingPreferencesTests: XCTestCase {
    func testCompleteWhenProfileHouseholdAndActiveMembershipExist() {
        let householdId = UUID()
        let snapshot = OnboardingPreferences.evaluateBackendCompletion(
            profile: makeProfile(first: "Rue", last: "Mawere"),
            memberships: [makeMembership(householdId: householdId, status: "active")],
            activeHouseholdId: householdId,
            childCount: 0
        )
        XCTAssertTrue(snapshot.isComplete)
        XCTAssertTrue(snapshot.profileExists)
        XCTAssertTrue(snapshot.householdExists)
        XCTAssertTrue(snapshot.activeMembershipExists)
        XCTAssertEqual(snapshot.activeHouseholdId, householdId)
    }

    func testIncompleteWithoutProfileName() {
        let householdId = UUID()
        let snapshot = OnboardingPreferences.evaluateBackendCompletion(
            profile: makeProfile(first: nil, last: nil, display: nil),
            memberships: [makeMembership(householdId: householdId, status: "active")],
            activeHouseholdId: householdId
        )
        XCTAssertFalse(snapshot.isComplete)
        XCTAssertFalse(snapshot.profileExists)
    }

    func testIncompleteWhenMembershipIsPendingOnly() {
        let householdId = UUID()
        let snapshot = OnboardingPreferences.evaluateBackendCompletion(
            profile: makeProfile(display: "Rue"),
            memberships: [makeMembership(householdId: householdId, status: "pending")],
            activeHouseholdId: householdId
        )
        XCTAssertFalse(snapshot.isComplete)
        XCTAssertTrue(snapshot.membershipExists)
        XCTAssertFalse(snapshot.activeMembershipExists)
    }

    func testHasMinimumProfileAcceptsDisplayNameAlone() {
        XCTAssertTrue(OnboardingPreferences.hasMinimumProfile(makeProfile(display: "Rue")))
        XCTAssertFalse(OnboardingPreferences.hasMinimumProfile(nil))
        XCTAssertFalse(OnboardingPreferences.hasMinimumProfile(makeProfile(first: "Rue", last: nil)))
    }

    private func makeProfile(
        first: String? = nil,
        last: String? = nil,
        display: String? = nil
    ) -> BackendProfile {
        BackendProfile(
            id: UUID(),
            email: "rue@example.com",
            display_name: display,
            first_name: first,
            last_name: last,
            avatar_type: nil,
            avatar_key: nil,
            avatar_url: nil,
            avatar_updated_at: nil,
            created_at: nil,
            updated_at: nil
        )
    }

    private func makeMembership(householdId: UUID, status: String) -> BackendHouseholdMembership {
        BackendHouseholdMembership(
            id: UUID(),
            householdId: householdId,
            userId: UUID(),
            role: "member",
            status: status,
            accessRole: "organiser",
            familyRole: "parent",
            relationshipLabel: "Parent",
            invitedByUserId: nil,
            createdAt: nil,
            updatedAt: nil
        )
    }
}
