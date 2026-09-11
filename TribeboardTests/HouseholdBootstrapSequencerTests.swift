import XCTest
@testable import Tribeboard

final class HouseholdBootstrapSequencerTests: XCTestCase {
    func testEmptyMembershipsWithLoadErrorIsFailureNotEmptyTribe() {
        let phase = HouseholdBootstrapSequencer.phaseAfterMembershipRefresh(
            membershipCount: 0,
            lastError: "Couldn't load",
            treatsErrorAsCancellation: false
        )
        XCTAssertEqual(phase, .loadFailed(message: "Couldn't load"))
        XCTAssertFalse(
            HouseholdBootstrapSequencer.showsCreateFlow(
                isAuthenticated: true,
                didRestoreSession: true,
                phase: phase!,
                hasActiveMembership: false
            )
        )
        XCTAssertTrue(
            HouseholdBootstrapSequencer.showsLoadFailure(
                isAuthenticated: true,
                didRestoreSession: true,
                phase: phase!
            )
        )
    }

    func testEmptyMembershipsWithoutErrorResolvesCreateFlow() {
        let phase = HouseholdBootstrapSequencer.phaseAfterMembershipRefresh(
            membershipCount: 0,
            lastError: nil,
            treatsErrorAsCancellation: false
        )
        XCTAssertEqual(phase, .resolved(hasHousehold: false))
        XCTAssertTrue(
            HouseholdBootstrapSequencer.showsCreateFlow(
                isAuthenticated: true,
                didRestoreSession: true,
                phase: .resolved(hasHousehold: false),
                hasActiveMembership: false
            )
        )
    }

    func testCancellationErrorDoesNotCountAsLoadFailure() {
        let phase = HouseholdBootstrapSequencer.phaseAfterMembershipRefresh(
            membershipCount: 0,
            lastError: "Cancelled",
            treatsErrorAsCancellation: true
        )
        XCTAssertEqual(phase, .resolved(hasHousehold: false))
    }

    func testMembershipsPresentContinueToSelection() {
        XCTAssertNil(
            HouseholdBootstrapSequencer.phaseAfterMembershipRefresh(
                membershipCount: 1,
                lastError: nil,
                treatsErrorAsCancellation: false
            )
        )
        XCTAssertEqual(
            HouseholdBootstrapSequencer.phaseAfterSelection(resolvedHouseholdId: UUID()),
            .resolved(hasHousehold: true)
        )
        XCTAssertEqual(
            HouseholdBootstrapSequencer.phaseAfterSelection(resolvedHouseholdId: nil),
            .resolved(hasHousehold: false)
        )
    }

    func testCreateFlowHiddenUntilSessionRestored() {
        XCTAssertFalse(
            HouseholdBootstrapSequencer.showsCreateFlow(
                isAuthenticated: true,
                didRestoreSession: false,
                phase: .resolved(hasHousehold: false),
                hasActiveMembership: false
            )
        )
    }

    func testContentLoadingWhileIdleThenStopsOnFailure() {
        XCTAssertTrue(
            HouseholdBootstrapSequencer.isContentLoading(
                isAuthenticated: true,
                didRestoreSession: true,
                phase: .idle,
                showsCreateFlow: false,
                restoredActiveHouseholdId: nil,
                activeHouseholdId: nil,
                isDependentDataLoading: false,
                dependentDataLoadedHouseholdId: nil
            )
        )
        XCTAssertFalse(
            HouseholdBootstrapSequencer.isContentLoading(
                isAuthenticated: true,
                didRestoreSession: true,
                phase: .loadFailed(message: "down"),
                showsCreateFlow: false,
                restoredActiveHouseholdId: nil,
                activeHouseholdId: nil,
                isDependentDataLoading: true,
                dependentDataLoadedHouseholdId: nil
            )
        )
    }
}

final class HouseholdCreateHelpersTests: XCTestCase {
    func testCreateNameTrimsAndRejectsBlank() {
        XCTAssertEqual(HouseholdCreateName.normalized("  Mawere  "), "Mawere")
        XCTAssertTrue(HouseholdCreateName.isUsable(" Tribe "))
        XCTAssertFalse(HouseholdCreateName.isUsable("   "))
        XCTAssertFalse(HouseholdCreateName.isUsable(""))
    }

    func testHouseholdRowPayloadUsesTrimmedNameOnly() throws {
        let householdId = UUID()
        let creator = UUID()
        let payload = HouseholdCreateRowPayload.make(
            id: householdId,
            name: "  Family One  ",
            createdBy: creator,
            inviteCode: "ABCD2345"
        )
        XCTAssertEqual(payload.name, "Family One")
        XCTAssertEqual(payload.id, householdId)
        XCTAssertEqual(payload.created_by, creator)
        XCTAssertEqual(payload.invite_code, "ABCD2345")

        let data = try JSONEncoder().encode(payload)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(object?["name"] as? String, "Family One")
        XCTAssertEqual(object?["created_by"] as? String, creator.uuidString)
        XCTAssertNil(object?["status"])
        XCTAssertNil(object?["access_role"])
    }

    func testJoinCodeFormatAndParseRoundTrip() {
        let householdId = UUID(uuidString: "aabbccdd-1234-5678-9abc-def012345678")!
        let formatted = formatHouseholdJoinCode(householdId: householdId)
        XCTAssertEqual(formatted, "H-AABBCCDD")
        XCTAssertEqual(parseHouseholdJoinCode("  h-aabbccdd  "), "AABBCCDD")
        XCTAssertNil(parseHouseholdJoinCode("INVITE-NOT-H"))
        XCTAssertNil(parseHouseholdJoinCode("H-ZZZZZZZZ"))
    }

    func testGeneratedInviteCodeStaysInSafeAlphabet() {
        let code = generateHouseholdInviteCode(length: 8)
        XCTAssertEqual(code.count, 8)
        XCTAssertTrue(code.unicodeScalars.allSatisfy { "ABCDEFGHJKLMNPQRSTUVWXYZ23456789".unicodeScalars.contains($0) })
    }
}
