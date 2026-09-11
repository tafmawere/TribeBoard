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
