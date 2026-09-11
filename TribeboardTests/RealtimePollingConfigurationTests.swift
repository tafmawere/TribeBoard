import XCTest
@testable import Tribeboard

final class RealtimePollingConfigurationTests: XCTestCase {
    func testPollIntervalIsTwoSeconds() {
        XCTAssertEqual(RealtimePollingConfiguration.pollInterval, 2)
        XCTAssertEqual(RealtimePollingConfiguration.pollIntervalNanoseconds, 2_000_000_000)
        XCTAssertEqual(RealtimePollingConfiguration.waitingAuthIntervalNanoseconds, 2_000_000_000)
        XCTAssertEqual(RealtimePollingConfiguration.errorBackoffNanoseconds, 4_000_000_000)
    }

    func testSubscribedTablesMatchPollingLoop() {
        XCTAssertEqual(
            RealtimePollingConfiguration.subscribedTables,
            [
                "children",
                "child_activities",
                "household_memberships",
                "runs",
                "run_driver_positions"
            ]
        )
        XCTAssertFalse(RealtimePollingConfiguration.subscribedTables.contains("run_assignments"))
    }

    func testMembershipsAndDefaultTablesUseUpdatedAt() {
        XCTAssertEqual(RealtimePollingConfiguration.markerColumn(for: "household_memberships"), "updated_at")
        XCTAssertEqual(RealtimePollingConfiguration.markerColumn(for: "children"), "updated_at")
        XCTAssertEqual(RealtimePollingConfiguration.markerColumn(for: "runs"), "updated_at")
        XCTAssertEqual(RealtimePollingConfiguration.markerColumn(for: "run_driver_positions"), "updated_at")
        XCTAssertEqual(RealtimePollingConfiguration.markerColumn(for: "run_assignments"), "assigned_at")
    }

    func testAccessTokenCacheSkipsRestoreWhileValid() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let valid = makeSession(expiresAt: now.addingTimeInterval(120))
        XCTAssertFalse(RealtimePollingConfiguration.shouldRestoreAccessToken(cached: valid, now: now))

        let expiring = makeSession(expiresAt: now.addingTimeInterval(15))
        XCTAssertTrue(RealtimePollingConfiguration.shouldRestoreAccessToken(cached: expiring, now: now))

        XCTAssertTrue(RealtimePollingConfiguration.shouldRestoreAccessToken(cached: nil, now: now))

        let noExpiry = makeSession(expiresAt: nil)
        XCTAssertFalse(RealtimePollingConfiguration.shouldRestoreAccessToken(cached: noExpiry, now: now))
    }

    func testTickOutcomeIsolatesPartialTableFailure() {
        let partial = RealtimePollTickOutcome.from(
            failedTables: ["run_driver_positions"],
            totalTables: 5
        )
        XCTAssertEqual(partial, .partialFailure(failedTables: ["run_driver_positions"]))
        XCTAssertFalse(partial.shouldApplyErrorBackoff)

        let allFailed = RealtimePollTickOutcome.from(
            failedTables: ["children", "child_activities", "household_memberships", "runs", "run_driver_positions"],
            totalTables: 5
        )
        XCTAssertTrue(allFailed.shouldApplyErrorBackoff)

        let ok = RealtimePollTickOutcome.from(failedTables: [], totalTables: 5)
        XCTAssertEqual(ok, .allSucceeded)
        XCTAssertFalse(ok.shouldApplyErrorBackoff)
    }

    func testUnauthorizedIsDetectedFromHTTPError() {
        let unauthorized = RealtimePollingHTTPError(table: "runs", statusCode: 401, body: "expired")
        XCTAssertTrue(RealtimePollingConfiguration.isUnauthorized(unauthorized))
        let missing = RealtimePollingHTTPError(table: "run_driver_positions", statusCode: 404, body: "not found")
        XCTAssertFalse(RealtimePollingConfiguration.isUnauthorized(missing))
    }

    private func makeSession(expiresAt: Date?) -> AuthUserSession {
        AuthUserSession(
            accessToken: "cached-token",
            refreshToken: "refresh",
            userId: UUID().uuidString,
            email: "tester@example.com",
            expiresAt: expiresAt,
            authProvider: "email",
            providerDisplayName: nil
        )
    }
}
