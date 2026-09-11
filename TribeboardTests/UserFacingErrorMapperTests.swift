import XCTest
@testable import Tribeboard

final class UserFacingErrorMapperTests: XCTestCase {
    func testRunTransitionMessages() {
        XCTAssertEqual(
            RunUserFacingErrorMapper.readableTransitionError(.notStarted),
            "Start the run before updating stops."
        )
        XCTAssertEqual(
            RunUserFacingErrorMapper.readableTransitionError(.alreadyCompleted),
            "This run is already completed."
        )
        XCTAssertEqual(
            RunUserFacingErrorMapper.readableTransitionError(.alreadyCancelled),
            "This run is already cancelled."
        )
        XCTAssertEqual(
            RunUserFacingErrorMapper.readableTransitionError(.invalidStopIndex),
            "That stop is not currently actionable."
        )
    }

    func testMutationMapsSessionAndPermission() {
        XCTAssertEqual(
            RunUserFacingErrorMapper.mutationMessage(for: TestError("JWT expired")),
            RunUserFacingErrorMapper.expiredSessionMessage
        )
        XCTAssertEqual(
            RunUserFacingErrorMapper.mutationMessage(for: TestError("row-level security violation")),
            RunUserFacingErrorMapper.runPermissionDeniedMessage
        )
        XCTAssertEqual(
            RunUserFacingErrorMapper.mutationMessage(for: RunTransitionError.notStarted),
            "Start the run before updating stops."
        )
    }

    func testCreateRunMapsValidationAndNetwork() {
        XCTAssertEqual(
            RunUserFacingErrorMapper.createRunMessage(for: RunCreationValidator.ValidationError.missingDepartureTime),
            RunCreationValidator.ValidationError.missingDepartureTime.localizedDescription
        )
        XCTAssertEqual(
            RunUserFacingErrorMapper.createRunMessage(for: TestError("Could not reach the host")),
            BackendUserFacingErrorMapper.networkFailure
        )
    }

    func testBackendMapperIgnoresCancellation() {
        XCTAssertNil(BackendUserFacingErrorMapper.message(for: CancellationError()))
        XCTAssertTrue(isCancellationMessage("Cancelled"))
        XCTAssertFalse(BackendUserFacingErrorMapper.isTransientLoadFailure("Cancelled"))
        XCTAssertTrue(BackendUserFacingErrorMapper.isTransientLoadFailure("Could not reach the server."))
    }

    func testBackendMapperSessionAndNetwork() {
        XCTAssertEqual(
            BackendUserFacingErrorMapper.message(for: TestError("PGRST303 JWT expired")),
            BackendUserFacingErrorMapper.sessionExpired
        )
        XCTAssertEqual(
            BackendUserFacingErrorMapper.message(for: URLError(.notConnectedToInternet)),
            BackendUserFacingErrorMapper.networkFailure
        )
    }

    func testInviteJoinMapperHidesFunctionErrors() {
        let hidden = SupabaseHouseholdBackendService.ServiceError.userFacingInviteJoinMessage(
            for: TestError("Could not find function get_invite_by_code")
        )
        XCTAssertEqual(hidden, SupabaseHouseholdBackendService.ServiceError.inviteConnectionFailedMessage)

        let passthrough = SupabaseHouseholdBackendService.ServiceError.userFacingInviteJoinMessage(
            for: TestError("Enter a valid family code.")
        )
        XCTAssertEqual(passthrough, "Enter a valid family code.")
    }

    private struct TestError: LocalizedError {
        let message: String
        init(_ message: String) { self.message = message }
        var errorDescription: String? { message }
    }
}
