import XCTest
@testable import Tribeboard

/// UX-only copies of client permission *messages* and role gates.
/// These tests do not exercise RLS, membership INSERT, or invite accept authorization.
final class BackendPermissionGuardTests: XCTestCase {
    func testActiveMembershipIgnoresOtherHouseholdAndPending() {
        let householdId = UUID()
        let userId = UUID()
        let active = makeMembership(householdId: householdId, userId: userId, status: "active", accessRole: "driver")
        let pending = makeMembership(householdId: householdId, userId: UUID(), status: "pending", accessRole: "organiser")
        let other = makeMembership(householdId: UUID(), userId: userId, status: "active", accessRole: "organiser")

        let resolved = BackendPermissionGuard.activeMembership(
            for: householdId,
            memberships: [pending, other, active]
        )
        XCTAssertEqual(resolved?.id, active.id)
    }

    func testRequireOrganiserIsUXCopyOnly() {
        let organiser = makeMembership(householdId: UUID(), userId: UUID(), status: "active", accessRole: "organiser")
        XCTAssertNoThrow(try BackendPermissionGuard.requireOrganiser(organiser, action: "manageMembers"))

        let driver = makeMembership(householdId: UUID(), userId: UUID(), status: "active", accessRole: "driver")
        XCTAssertThrowsError(try BackendPermissionGuard.requireOrganiser(driver, action: "manageMembers")) { error in
            guard let permission = error as? BackendPermissionError else {
                return XCTFail("Expected BackendPermissionError")
            }
            XCTAssertEqual(
                permission.localizedDescription,
                "Permission denied for manageMembers. Role driver is not allowed."
            )
        }
    }

    func testRequireRunOperatorAllowsDriverAndOrganiser() throws {
        let driver = makeMembership(householdId: UUID(), userId: UUID(), status: "active", accessRole: "driver")
        let organiser = makeMembership(householdId: UUID(), userId: UUID(), status: "active", accessRole: "organiser")
        let observer = makeMembership(householdId: UUID(), userId: UUID(), status: "active", accessRole: "observer")
        XCTAssertNoThrow(try BackendPermissionGuard.requireRunOperator(driver, action: "startRun"))
        XCTAssertNoThrow(try BackendPermissionGuard.requireRunOperator(organiser, action: "startRun"))
        XCTAssertThrowsError(try BackendPermissionGuard.requireRunOperator(observer, action: "startRun"))
        XCTAssertThrowsError(try BackendPermissionGuard.requireActiveMembership(nil, action: "startRun")) { error in
            XCTAssertEqual(
                (error as? BackendPermissionError)?.localizedDescription,
                "Permission denied for startRun. No active household membership."
            )
        }
    }

    func testMembershipStatusDecodeIsExposedAndNormalized() throws {
        let json = """
        {
          "id": "11111111-1111-1111-1111-111111111111",
          "household_id": "22222222-2222-2222-2222-222222222222",
          "user_id": "33333333-3333-3333-3333-333333333333",
          "role": "member",
          "status": "ACTIVE",
          "access_role": "organiser"
        }
        """.data(using: .utf8)!
        let membership = try JSONDecoder().decode(BackendHouseholdMembership.self, from: json)
        XCTAssertEqual(membership.normalizedStatus, .active)
        XCTAssertTrue(membership.isActiveMembership)
        XCTAssertEqual(HouseholdMembershipStatus(rawValue: "pending"), .pending)
        XCTAssertEqual(HouseholdMembershipStatus(rawValue: "revoked"), .revoked)
        XCTAssertNil(HouseholdMembershipStatus(rawValue: "not-a-status"))
    }

    private func makeMembership(
        householdId: UUID,
        userId: UUID,
        status: String,
        accessRole: String
    ) -> BackendHouseholdMembership {
        BackendHouseholdMembership(
            id: UUID(),
            householdId: householdId,
            userId: userId,
            role: "member",
            status: status,
            accessRole: accessRole,
            familyRole: nil,
            relationshipLabel: nil,
            invitedByUserId: nil,
            createdAt: nil,
            updatedAt: nil
        )
    }
}
