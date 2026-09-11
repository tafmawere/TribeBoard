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
}
