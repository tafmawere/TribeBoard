import XCTest
@testable import Tribeboard

final class RunPersistenceMapperTests: XCTestCase {
    func testRoundTripPackagePreservesStopProgress() {
        let stopId = UUID()
        let runId = UUID()
        let templateId = UUID()
        let householdId = UUID()
        let childId = UUID()
        let driverId = UUID()

        let startedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let run = SystemDomain.RunInstance(
            id: runId,
            householdId: householdId,
            templateId: templateId,
            title: "School run",
            date: Date(),
            departureTime: "07:45:00",
            status: .inProgress,
            stops: [
                SystemDomain.RunStopProgress(stopId: stopId, status: .enRoute, arrivedAt: nil, departedAt: nil)
            ],
            stopSnapshots: [
                SystemDomain.Stop(id: stopId, name: "School", latitude: -26.1, longitude: 28.0, order: 0)
            ],
            startedAt: startedAt,
            activeStopIndex: 0,
            assignedDriverId: driverId,
            driverId: driverId,
            childId: childId,
            createdAt: Date()
        )

        let package = RunPersistenceMapper.package(from: run)
        XCTAssertEqual(package.run.title, "School run")
        XCTAssertEqual(package.run.status, BackendRunStatusCodec.encode(.inProgress))
        XCTAssertEqual(package.run.startedAt, startedAt)
        XCTAssertEqual(package.stops[0].label, "School")

        let mapped = RunPersistenceMapper.runInstance(
            from: package,
            template: nil,
            driverName: "Rue",
            childId: childId
        )
        XCTAssertEqual(mapped.id, runId)
        XCTAssertEqual(mapped.title, "School run")
        XCTAssertEqual(mapped.status, .inProgress)
        XCTAssertEqual(mapped.stops.first?.status, .enRoute)
        XCTAssertEqual(mapped.childId, childId)
        XCTAssertEqual(mapped.departureTime, "07:45:00")
        XCTAssertEqual(mapped.startedAt, startedAt)
    }

    func testRunInstanceDateUsesPersistedDepartureTimeNotTemplate() {
        let calendar = Calendar(identifier: .gregorian)
        var components = DateComponents()
        components.year = 2026
        components.month = 6
        components.day = 23
        let runDay = calendar.date(from: components)!
        let package = BackendRunPackage(
            run: BackendRun(
                id: UUID(),
                householdId: UUID(),
                scheduleId: UUID(),
                childId: UUID(),
                title: "School run",
                runDate: runDay,
                departureTime: "07:45:00",
                status: "assigned",
                driverId: UUID(),
                createdAt: Date()
            ),
            stops: []
        )
        let changedTemplate = SystemDomain.ScheduleTemplate(
            id: package.run.scheduleId,
            householdId: package.run.householdId,
            name: "Changed schedule title",
            childId: package.run.childId ?? UUID(),
            driverId: nil,
            weekdays: [2],
            hour: 15,
            minute: 30,
            stops: [],
            isActive: true,
            createdAt: Date()
        )

        let mapped = RunPersistenceMapper.runInstance(
            from: package,
            template: changedTemplate,
            driverName: nil,
            childId: package.run.childId
        )

        XCTAssertEqual(mapped.title, "School run")
        XCTAssertEqual(mapped.departureTime, "07:45:00")
        XCTAssertEqual(calendar.component(.hour, from: mapped.date), 7)
        XCTAssertEqual(calendar.component(.minute, from: mapped.date), 45)
    }

    func testRoundTripPackagePreservesPlaceNameInStopLabel() {
        let stopId = UUID()
        let runId = UUID()
        let householdId = UUID()
        let childId = UUID()
        let driverId = UUID()

        let run = SystemDomain.RunInstance(
            id: runId,
            householdId: householdId,
            templateId: ManualRunCreationSupport.manualRunAnchorTemplateId,
            title: "Nyerere",
            date: Date(),
            departureTime: "15:00:00",
            status: .assigned,
            stops: [
                SystemDomain.RunStopProgress(stopId: stopId, status: .pending, arrivedAt: nil, departedAt: nil)
            ],
            stopSnapshots: [
                SystemDomain.Stop(
                    id: stopId,
                    name: "Rosebank Mall",
                    latitude: -26.1,
                    longitude: 28.0,
                    order: 0,
                    kind: RunStopLabelCodec.pickup
                )
            ],
            assignedDriverId: driverId,
            driverId: driverId,
            childId: childId,
            createdAt: Date()
        )

        let package = RunPersistenceMapper.package(from: run)
        XCTAssertEqual(package.stops[0].label, "Rosebank Mall")

        let mapped = RunPersistenceMapper.runInstance(
            from: package,
            template: nil,
            driverName: "Rue",
            childId: childId
        )
        XCTAssertEqual(mapped.stopSnapshots.first?.name, "Rosebank Mall")
        XCTAssertEqual(mapped.stopSnapshots.first?.kind, RunStopLabelCodec.pickup)
    }

    func testAssignedStatusEncodesForBackend() {
        XCTAssertEqual(BackendRunStatusCodec.encode(.assigned), "assigned")
        XCTAssertEqual(BackendRunStatusCodec.decode("assigned"), .assigned)
    }

    func testCancelledRunUpdatePayloadDoesNotSendMissingCancelledAtColumn() throws {
        let run = BackendRun(
            id: UUID(),
            householdId: UUID(),
            scheduleId: UUID(),
            childId: UUID(),
            title: "Cancelled run",
            runDate: Date(),
            departureTime: "08:00:00",
            status: BackendRunStatusCodec.encode(.cancelled),
            driverId: UUID(),
            startedAt: nil,
            completedAt: nil,
            cancelledAt: Date(),
            createdAt: Date()
        )

        let payload = BackendRunUpdatePayload(from: run)
        let data = try SupabaseJSONCoding.makeSupabaseEncoder().encode([payload])
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [[String: Any]])
        let encoded = try XCTUnwrap(object.first)

        XCTAssertEqual(encoded["status"] as? String, "cancelled")
        XCTAssertNil(encoded["cancelled_at"])
    }

    func testRunDisplayStringsUseSelectedChildAndPickupDropoffStops() {
        let childId = UUID()
        let pickupId = UUID()
        let dropoffId = UUID()
        let run = SystemDomain.RunInstance(
            id: UUID(),
            householdId: UUID(),
            templateId: ManualRunCreationSupport.manualRunAnchorTemplateId,
            title: "School Pickup",
            date: Date(),
            departureTime: "15:00:00",
            status: .assigned,
            stops: [
                SystemDomain.RunStopProgress(stopId: pickupId, status: .pending, arrivedAt: nil, departedAt: nil),
                SystemDomain.RunStopProgress(stopId: dropoffId, status: .pending, arrivedAt: nil, departedAt: nil)
            ],
            stopSnapshots: [
                SystemDomain.Stop(
                    id: pickupId,
                    name: "St Stithians",
                    latitude: -26.1,
                    longitude: 28.0,
                    order: 0,
                    kind: RunStopLabelCodec.pickup
                ),
                SystemDomain.Stop(
                    id: dropoffId,
                    name: "Home",
                    latitude: -26.2,
                    longitude: 28.1,
                    order: 1,
                    kind: RunStopLabelCodec.dropoff
                )
            ],
            assignedDriverId: UUID(),
            driverId: UUID(),
            childId: childId,
            createdAt: Date()
        )
        let children = [
            BackendChild(
                id: childId,
                householdId: run.householdId,
                legalName: "Tafadzwa Junior",
                displayName: "TJ",
                dateOfBirth: nil,
                schoolName: nil,
                gradeOrClass: nil,
                createdAt: nil,
                updatedAt: nil
            )
        ]

        let route = RunDisplayStrings.routeEndpoints(for: run)
        let uiRun = RunUIAdapter.mapToUIRun(
            run,
            childName: RunDisplayStrings.childName(for: run, children: children)
        )

        XCTAssertEqual(uiRun.title, "School Pickup")
        XCTAssertEqual(uiRun.passengers.first?.name, "TJ")
        XCTAssertEqual(route.pickup, "St Stithians")
        XCTAssertEqual(route.dropoff, "Home")
        XCTAssertEqual(uiRun.stops.map(\.label), ["St Stithians", "Home"])
    }

    func testRoundTripPackagePreservesStopArrivalAndDepartureTimestamps() {
        let firstStopId = UUID()
        let secondStopId = UUID()
        let runId = UUID()
        let householdId = UUID()
        let childId = UUID()
        let driverId = UUID()
        let arrivedAt = Date(timeIntervalSince1970: 1_700_000_300)
        let departedAt = arrivedAt.addingTimeInterval(420)

        let run = SystemDomain.RunInstance(
            id: runId,
            householdId: householdId,
            templateId: UUID(),
            title: "Morning run",
            date: Date(),
            departureTime: "07:30:00",
            status: .inProgress,
            stops: [
                SystemDomain.RunStopProgress(
                    stopId: firstStopId,
                    status: .completed,
                    arrivedAt: arrivedAt,
                    departedAt: departedAt
                ),
                SystemDomain.RunStopProgress(
                    stopId: secondStopId,
                    status: .arrived,
                    arrivedAt: arrivedAt.addingTimeInterval(900),
                    departedAt: nil
                )
            ],
            stopSnapshots: [
                SystemDomain.Stop(id: firstStopId, name: "Home", latitude: -26.1, longitude: 28.0, order: 0),
                SystemDomain.Stop(id: secondStopId, name: "School", latitude: -26.2, longitude: 28.1, order: 1)
            ],
            activeStopIndex: 1,
            assignedDriverId: driverId,
            driverId: driverId,
            childId: childId,
            createdAt: Date()
        )

        let package = RunPersistenceMapper.package(from: run)
        XCTAssertEqual(package.stops[0].status, "completed")
        XCTAssertEqual(package.stops[0].arrivedAt, arrivedAt)
        XCTAssertEqual(package.stops[0].departedAt, departedAt)
        XCTAssertEqual(package.stops[1].status, "arrived")
        XCTAssertNotNil(package.stops[1].arrivedAt)
        XCTAssertNil(package.stops[1].departedAt)

        let mapped = RunPersistenceMapper.runInstance(
            from: package,
            template: nil,
            driverName: "Rue",
            childId: childId
        )
        XCTAssertEqual(mapped.stops[0].status, .completed)
        XCTAssertEqual(mapped.stops[0].arrivedAt, arrivedAt)
        XCTAssertEqual(mapped.stops[0].departedAt, departedAt)
        XCTAssertEqual(mapped.stops[1].status, .arrived)
        XCTAssertEqual(mapped.stops[1].arrivedAt, arrivedAt.addingTimeInterval(900))
    }

    func testRunInstanceSanitizesCompletedStopWithoutTimestamps() {
        let stopId = UUID()
        let package = BackendRunPackage(
            run: BackendRun(
                id: UUID(),
                householdId: UUID(),
                scheduleId: UUID(),
                childId: UUID(),
                title: "Run",
                runDate: Date(),
                departureTime: "08:00:00",
                status: "in_progress",
                driverId: UUID(),
                createdAt: Date()
            ),
            stops: [
                BackendRunStop(
                    id: stopId,
                    runId: UUID(),
                    childId: UUID(),
                    label: "Pickup",
                    latitude: -26.1,
                    longitude: 28.0,
                    stopOrder: 0,
                    status: "completed",
                    locationId: nil,
                    arrivedAt: nil,
                    departedAt: nil
                )
            ]
        )

        let mapped = RunPersistenceMapper.runInstance(from: package, template: nil, driverName: nil)
        XCTAssertEqual(mapped.stops[0].status, .arrived)
        XCTAssertNil(mapped.stops[0].arrivedAt)
        XCTAssertNil(mapped.stops[0].departedAt)
    }
}
