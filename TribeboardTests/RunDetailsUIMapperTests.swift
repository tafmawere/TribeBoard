import XCTest
@testable import Tribeboard

final class RunDetailsUIMapperTests: XCTestCase {
    func testMapsRealRunIdentityInsteadOfCannedSchoolDropoff() {
        let runId = UUID()
        let scheduled = Date(timeIntervalSince1970: 1_800_000_100)
        let run = makeRun(
            id: runId,
            title: "Clinic pickup",
            date: scheduled,
            status: .assigned,
            driverName: "Rue",
            childId: UUID()
        )

        let ui = RunDetailsUIMapper.map(run, childName: "TJ")
        XCTAssertEqual(ui.id, runId)
        XCTAssertEqual(ui.title, "Clinic pickup")
        XCTAssertEqual(ui.scheduledTime, scheduled)
        XCTAssertEqual(ui.status, "Assigned")
        XCTAssertEqual(ui.driverName, "Rue")
        XCTAssertEqual(ui.passengerNames, ["TJ"])
        XCTAssertTrue(ui.canEdit)
        XCTAssertTrue(ui.canCancel)
        XCTAssertFalse(ui.isHistory)
        XCTAssertNotEqual(ui.title, RunDetailsData.scheduledRun.title)
    }

    func testResolveReturnsNilWhenRunMissing() {
        XCTAssertNil(
            RunDetailsUIMapper.resolve(runId: UUID().uuidString, run: { _ in nil })
        )
    }

    func testHistoryFlagsTerminalRuns() {
        let completed = makeRun(status: .completed, completedAt: Date())
        let ui = RunDetailsUIMapper.map(completed)
        XCTAssertEqual(ui.status, "Completed")
        XCTAssertTrue(ui.isHistory)
        XCTAssertFalse(ui.canEdit)
        XCTAssertFalse(ui.canCancel)
        XCTAssertEqual(ui.timeline.last?.title, "Completed")
    }

    private func makeRun(
        id: UUID = UUID(),
        title: String = "Clinic pickup",
        date: Date = Date(timeIntervalSince1970: 1_800_000_100),
        status: SystemDomain.RunStatus = .scheduled,
        driverName: String? = "Rue",
        childId: UUID = UUID(),
        completedAt: Date? = nil
    ) -> SystemDomain.RunInstance {
        let stop = SystemDomain.Stop(
            id: UUID(),
            name: "Clinic",
            latitude: -26.1,
            longitude: 28.0,
            order: 0,
            kind: RunStopLabelCodec.pickup
        )
        return SystemDomain.RunInstance(
            id: id,
            householdId: UUID(),
            templateId: UUID(),
            title: title,
            date: date,
            departureTime: RunScheduledTime.from(date: date),
            status: status,
            stops: [
                SystemDomain.RunStopProgress(stopId: stop.id, status: .pending, arrivedAt: nil, departedAt: nil)
            ],
            stopSnapshots: [stop],
            completedAt: completedAt,
            assignedDriverName: driverName,
            driverId: UUID(),
            childId: childId,
            createdAt: date.addingTimeInterval(-3600)
        )
    }
}
