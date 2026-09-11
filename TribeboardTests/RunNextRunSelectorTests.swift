import XCTest
@testable import Tribeboard

final class RunNextRunSelectorTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)

    func testExcludesPastAssignedRunInFavorOfTodayManualRun() {
        let householdId = UUID()
        let reference = calendar.date(from: DateComponents(year: 2026, month: 6, day: 23, hour: 12))!
        let april = makeRun(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            title: "TJ School Pickup",
            date: calendar.date(from: DateComponents(year: 2026, month: 4, day: 20, hour: 7))!,
            createdAt: calendar.date(from: DateComponents(year: 2026, month: 4, day: 19))!,
            status: .assigned,
            householdId: householdId,
            stopCount: 2
        )
        let nyerere = makeRun(
            id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            title: "Nyerere",
            date: calendar.date(from: DateComponents(year: 2026, month: 6, day: 23, hour: 15))!,
            createdAt: calendar.date(from: DateComponents(year: 2026, month: 6, day: 23, hour: 11))!,
            status: .assigned,
            householdId: householdId,
            stopCount: 2
        )

        let result = RunNextRunSelector.select(
            from: [april, nyerere],
            referenceDate: reference,
            calendar: calendar
        )

        XCTAssertEqual(result.run?.id, nyerere.id)
        XCTAssertEqual(result.run?.title, "Nyerere")
        XCTAssertTrue(result.logs.contains(where: {
            $0.runId == april.id && $0.exclusionReason == "run_date_before_today"
        }))
    }

    func testPrefersRunWithStopsOverZeroStopRun() {
        let reference = calendar.date(from: DateComponents(year: 2026, month: 6, day: 23, hour: 12))!
        let emptyStops = makeRun(
            title: "Broken",
            date: reference,
            createdAt: reference.addingTimeInterval(100),
            status: .assigned,
            stopCount: 0
        )
        let valid = makeRun(
            title: "Nyerere",
            date: reference,
            createdAt: reference,
            status: .assigned,
            stopCount: 2
        )

        let result = RunNextRunSelector.select(from: [emptyStops, valid], referenceDate: reference, calendar: calendar)

        XCTAssertEqual(result.run?.title, "Nyerere")
    }

    func testUsesNewestCreatedAtAsTieBreakerForSameDay() {
        let reference = calendar.date(from: DateComponents(year: 2026, month: 6, day: 23, hour: 12))!
        let older = makeRun(
            title: "Earlier Created",
            date: reference,
            createdAt: reference.addingTimeInterval(-3600),
            status: .assigned,
            stopCount: 2
        )
        let newer = makeRun(
            title: "Nyerere",
            date: reference,
            createdAt: reference,
            status: .assigned,
            stopCount: 2
        )

        let result = RunNextRunSelector.select(from: [older, newer], referenceDate: reference, calendar: calendar)

        XCTAssertEqual(result.run?.title, "Nyerere")
    }

    func testPrefersInProgressOverLaterAssigned() {
        let reference = calendar.date(from: DateComponents(year: 2026, month: 6, day: 23, hour: 12))!
        let later = makeRun(
            title: "Later",
            date: reference.addingTimeInterval(3600),
            createdAt: reference,
            status: .assigned,
            stopCount: 2
        )
        let active = makeRun(
            title: "Live",
            date: reference.addingTimeInterval(7200),
            createdAt: reference.addingTimeInterval(-60),
            status: .inProgress,
            stopCount: 2
        )

        let result = RunNextRunSelector.select(from: [later, active], referenceDate: reference, calendar: calendar)
        XCTAssertEqual(result.run?.title, "Live")
        XCTAssertTrue(result.selectionReason.contains("in_progress"))
    }

    func testEmptyInputAndAllPastAssignedAreIneligible() {
        let reference = calendar.date(from: DateComponents(year: 2026, month: 6, day: 23, hour: 12))!
        let empty = RunNextRunSelector.select(from: [], referenceDate: reference, calendar: calendar)
        XCTAssertNil(empty.run)
        XCTAssertEqual(empty.selectionReason, "no_eligible_runs")

        let yesterday = calendar.date(byAdding: .day, value: -1, to: reference)!
        let lastWeek = calendar.date(byAdding: .day, value: -7, to: reference)!
        let past = [
            makeRun(title: "Yesterday", date: yesterday, createdAt: yesterday, status: .assigned, stopCount: 2),
            makeRun(title: "Last week", date: lastWeek, createdAt: lastWeek, status: .scheduled, stopCount: 2)
        ]
        let result = RunNextRunSelector.select(from: past, referenceDate: reference, calendar: calendar)
        XCTAssertNil(result.run)
        XCTAssertEqual(result.selectionReason, "no_eligible_runs")
        XCTAssertTrue(result.logs.allSatisfy { $0.exclusionReason == "run_date_before_today" })
    }

    func testReturnsNilWhenOnlyTerminalRunsExist() {
        let reference = calendar.date(from: DateComponents(year: 2026, month: 6, day: 23, hour: 12))!
        let completed = makeRun(
            title: "Done",
            date: reference,
            createdAt: reference,
            status: .completed,
            stopCount: 2
        )
        let cancelled = makeRun(
            title: "Cancelled",
            date: reference,
            createdAt: reference,
            status: .cancelled,
            stopCount: 2
        )

        let result = RunNextRunSelector.select(from: [completed, cancelled], referenceDate: reference, calendar: calendar)
        XCTAssertNil(result.run)
        XCTAssertEqual(result.selectionReason, "no_eligible_runs")
    }

    private func makeRun(
        id: UUID = UUID(),
        title: String,
        date: Date,
        createdAt: Date,
        status: SystemDomain.RunStatus,
        householdId: UUID = UUID(),
        stopCount: Int
    ) -> SystemDomain.RunInstance {
        let stops = (0..<stopCount).map { index in
            SystemDomain.Stop(
                id: UUID(),
                name: "Stop \(index)",
                latitude: -26.1,
                longitude: 28.0,
                order: index,
                kind: index == 0 ? RunStopLabelCodec.pickup : RunStopLabelCodec.dropoff
            )
        }
        return SystemDomain.RunInstance(
            id: id,
            householdId: householdId,
            templateId: UUID(),
            title: title,
            date: date,
            departureTime: RunScheduledTime.from(date: date),
            status: status,
            stops: stops.map { SystemDomain.RunStopProgress(stopId: $0.id, status: .pending, arrivedAt: nil, departedAt: nil) },
            stopSnapshots: stops,
            driverId: UUID(),
            childId: UUID(),
            createdAt: createdAt
        )
    }
}
