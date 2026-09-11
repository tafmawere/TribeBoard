import XCTest
@testable import Tribeboard

final class RunLocationObserverPolicyTests: XCTestCase {
    func testPollsOnlyInProgressAndActiveScene() {
        XCTAssertTrue(RunLocationObserverPolicy.shouldPoll(hasInProgressRun: true, isSceneActive: true))
        XCTAssertFalse(RunLocationObserverPolicy.shouldPoll(hasInProgressRun: true, isSceneActive: false))
        XCTAssertFalse(RunLocationObserverPolicy.shouldPoll(hasInProgressRun: false, isSceneActive: true))
        XCTAssertFalse(RunLocationObserverPolicy.shouldPoll(hasInProgressRun: false, isSceneActive: false))
    }

    func testPollIntervalRemainsSevenSeconds() {
        XCTAssertEqual(RunLocationObserverPolicy.pollInterval, 7)
        XCTAssertEqual(RunLocationObserverPolicy.pollIntervalNanoseconds, 7_000_000_000)
    }
}
