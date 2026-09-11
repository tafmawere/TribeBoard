import XCTest
@testable import Tribeboard

final class RunStateMachineTests: XCTestCase {
    private let machine = RunStateMachine()

    func testStartSetsInProgressAndStartedAt() throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let run = makeRun(status: .assigned)

        let updated = try machine.start(run, now: now)

        XCTAssertEqual(updated.status, .inProgress)
        XCTAssertEqual(updated.startedAt, now)
        XCTAssertNil(updated.completedAt)
        XCTAssertNil(updated.cancelledAt)
    }

    func testCompleteSetsCompletedAt() throws {
        let startedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let arrivedAt = startedAt.addingTimeInterval(600)
        let completedAt = startedAt.addingTimeInterval(1_800)
        var run = makeRun(status: .inProgress)
        run.startedAt = startedAt
        run.stops = [
            SystemDomain.RunStopProgress(
                stopId: UUID(),
                status: .completed,
                arrivedAt: arrivedAt,
                departedAt: completedAt
            )
        ]

        let updated = try machine.complete(run, now: completedAt)

        XCTAssertEqual(updated.status, .completed)
        XCTAssertEqual(updated.startedAt, startedAt)
        XCTAssertEqual(updated.completedAt, completedAt)
        XCTAssertNil(updated.cancelledAt)
    }

    func testArriveAtStopSetsArrivedStatusAndTimestamp() throws {
        let now = Date(timeIntervalSince1970: 1_700_000_100)
        let stopId = UUID()
        var run = makeRun(status: .inProgress)
        run.activeStopIndex = 0
        run.stops = [
            SystemDomain.RunStopProgress(stopId: stopId, status: .enRoute, arrivedAt: nil, departedAt: nil)
        ]
        run.stopSnapshots = [
            SystemDomain.Stop(id: stopId, name: "Home", latitude: -26.1, longitude: 28.0, order: 0)
        ]

        let updated = try machine.arriveAtStop(run, stopIndex: 0, now: now)

        XCTAssertEqual(updated.stops[0].status, .arrived)
        XCTAssertEqual(updated.stops[0].arrivedAt, now)
        XCTAssertNil(updated.stops[0].departedAt)
        XCTAssertEqual(updated.activeStopIndex, 0)
    }

    func testDepartStopSetsCompletedStatusAndTimestamp() throws {
        let arrivedAt = Date(timeIntervalSince1970: 1_700_000_200)
        let departedAt = arrivedAt.addingTimeInterval(300)
        let firstStopId = UUID()
        let secondStopId = UUID()
        var run = makeRun(status: .inProgress)
        run.activeStopIndex = 0
        run.stops = [
            SystemDomain.RunStopProgress(stopId: firstStopId, status: .arrived, arrivedAt: arrivedAt, departedAt: nil),
            SystemDomain.RunStopProgress(stopId: secondStopId, status: .pending, arrivedAt: nil, departedAt: nil)
        ]
        run.stopSnapshots = [
            SystemDomain.Stop(id: firstStopId, name: "Home", latitude: -26.1, longitude: 28.0, order: 0),
            SystemDomain.Stop(id: secondStopId, name: "School", latitude: -26.2, longitude: 28.1, order: 1)
        ]

        let updated = try machine.departStop(run, stopIndex: 0, now: departedAt)

        XCTAssertEqual(updated.stops[0].status, .completed)
        XCTAssertEqual(updated.stops[0].arrivedAt, arrivedAt)
        XCTAssertEqual(updated.stops[0].departedAt, departedAt)
        XCTAssertEqual(updated.stops[1].status, .enRoute)
        XCTAssertEqual(updated.activeStopIndex, 1)
    }

    func testDepartStopRejectsMissingArrivedTimestamp() {
        let stopId = UUID()
        var run = makeRun(status: .inProgress)
        run.activeStopIndex = 0
        run.stops = [
            SystemDomain.RunStopProgress(stopId: stopId, status: .arrived, arrivedAt: nil, departedAt: nil)
        ]

        XCTAssertThrowsError(try machine.departStop(run, stopIndex: 0, now: Date())) { error in
            XCTAssertEqual(error as? RunTransitionError, .invalidTransition)
        }
    }

    func testArriveAtStopRejectsNonActiveStop() {
        let stopId = UUID()
        var run = makeRun(status: .inProgress)
        run.activeStopIndex = 1
        run.stops = [
            SystemDomain.RunStopProgress(stopId: UUID(), status: .enRoute, arrivedAt: nil, departedAt: nil),
            SystemDomain.RunStopProgress(stopId: stopId, status: .pending, arrivedAt: nil, departedAt: nil)
        ]

        XCTAssertThrowsError(try machine.arriveAtStop(run, stopIndex: 0, now: Date())) { error in
            XCTAssertEqual(error as? RunTransitionError, .invalidStopIndex)
        }
    }

    func testCancelSetsCancelledAt() throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let run = makeRun(status: .assigned)

        let updated = try machine.cancel(run, now: now)

        XCTAssertEqual(updated.status, .cancelled)
        XCTAssertEqual(updated.cancelledAt, now)
        XCTAssertNil(updated.completedAt)
    }

    private func makeRun(status: SystemDomain.RunStatus) -> SystemDomain.RunInstance {
        SystemDomain.RunInstance(
            id: UUID(),
            householdId: UUID(),
            templateId: UUID(),
            title: "School run",
            date: Date(),
            departureTime: "07:45:00",
            status: status,
            stops: [],
            stopSnapshots: [],
            assignedDriverId: UUID(),
            driverId: UUID(),
            childId: UUID(),
            createdAt: Date()
        )
    }
}
