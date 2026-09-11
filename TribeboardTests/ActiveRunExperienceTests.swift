import CoreLocation
import XCTest
@testable import Tribeboard

final class ActiveRunStateResolverTests: XCTestCase {
    func testHeadingToFirstStopWhenEnRoute() {
        let run = makeRun(
            status: .inProgress,
            activeIndex: 0,
            stopStatuses: [.enRoute, .pending, .pending]
        )
        XCTAssertEqual(ActiveRunStateResolver.resolve(for: run), .headingToStop(stopIndex: 0))
    }

    func testArrivedAtSchoolStop() {
        let run = makeRun(
            status: .inProgress,
            activeIndex: 1,
            stopStatuses: [.completed, .arrived, .pending],
            stopNames: ["Home", "St Stithians School", "Home"]
        )
        XCTAssertEqual(ActiveRunStateResolver.resolve(for: run), .arrivedAtStop(stopIndex: 1))
    }

    func testCompletedWhenAllStopsDone() {
        let run = makeRun(
            status: .inProgress,
            activeIndex: 2,
            stopStatuses: [.completed, .completed, .completed]
        )
        XCTAssertEqual(ActiveRunStateResolver.resolve(for: run), .completed)
    }

    private func makeRun(
        status: SystemDomain.RunStatus,
        activeIndex: Int,
        stopStatuses: [SystemDomain.StopStatus],
        stopNames: [String]? = nil
    ) -> SystemDomain.RunInstance {
        let stops: [SystemDomain.Stop] = stopStatuses.enumerated().map { index, _ in
            SystemDomain.Stop(
                id: UUID(),
                name: stopNames?[index] ?? "Stop \(index)",
                latitude: -26.1 + Double(index) * 0.01,
                longitude: 28.0 + Double(index) * 0.01,
                order: index
            )
        }
        let progress = zip(stops, stopStatuses).map {
            SystemDomain.RunStopProgress(stopId: $0.id, status: $1, arrivedAt: nil, departedAt: nil)
        }
        return SystemDomain.RunInstance(
            id: UUID(),
            templateId: UUID(),
            title: "School run",
            date: Date(),
            departureTime: RunScheduledTime.from(date: Date()),
            status: status,
            stops: progress,
            stopSnapshots: stops,
            activeStopIndex: activeIndex,
            driverId: UUID(),
            childId: UUID(),
            createdAt: Date()
        )
    }
}

final class ActiveRunActionResolverTests: XCTestCase {
    func testPickupHomeStopAfterArriveOffersDepartNotComplete() {
        let stops = [
            SystemDomain.Stop(id: UUID(), name: "Home", latitude: -26.1, longitude: 28.0, order: 0),
            SystemDomain.Stop(id: UUID(), name: "St Stithians School", latitude: -26.2, longitude: 28.1, order: 1)
        ]
        let progress = [
            SystemDomain.RunStopProgress(stopId: stops[0].id, status: .arrived, arrivedAt: Date(), departedAt: nil),
            SystemDomain.RunStopProgress(stopId: stops[1].id, status: .pending, arrivedAt: nil, departedAt: nil)
        ]
        let run = SystemDomain.RunInstance(
            id: UUID(),
            templateId: UUID(),
            title: "School run",
            date: Date(),
            departureTime: RunScheduledTime.from(date: Date()),
            status: .inProgress,
            stops: progress,
            stopSnapshots: stops,
            activeStopIndex: 0,
            driverId: UUID(),
            childId: UUID(),
            createdAt: Date()
        )

        XCTAssertEqual(
            ActiveRunActionResolver.primaryAction(for: run),
            .childCollected(stopIndex: 0)
        )
    }

    func testHeadingToNextStopUsesActiveStopIndexForArrive() {
        let stops = (0..<2).map { index in
            SystemDomain.Stop(id: UUID(), name: "Stop \(index)", latitude: -26.1, longitude: 28.0, order: index)
        }
        let progress = [
            SystemDomain.RunStopProgress(stopId: stops[0].id, status: .completed, arrivedAt: Date(), departedAt: Date()),
            SystemDomain.RunStopProgress(stopId: stops[1].id, status: .enRoute, arrivedAt: nil, departedAt: nil)
        ]
        let run = SystemDomain.RunInstance(
            id: UUID(),
            templateId: UUID(),
            title: "Run",
            date: Date(),
            departureTime: RunScheduledTime.from(date: Date()),
            status: .inProgress,
            stops: progress,
            stopSnapshots: stops,
            activeStopIndex: 1,
            driverId: UUID(),
            childId: UUID(),
            createdAt: Date()
        )

        XCTAssertEqual(ActiveRunStateResolver.resolve(for: run), .headingToNextStop(fromIndex: 0))
        XCTAssertEqual(ActiveRunActionResolver.primaryAction(for: run), .arrive(stopIndex: 1))
    }
}

final class RunRouteValidatorTests: XCTestCase {
    func testRejectsDistanceAbove150km() {
        let stops = [
            SystemDomain.Stop(id: UUID(), name: "A", latitude: -26.0, longitude: 28.0, order: 0),
            SystemDomain.Stop(id: UUID(), name: "B", latitude: -27.5, longitude: 30.0, order: 1)
        ]
        let progress = stops.map {
            SystemDomain.RunStopProgress(stopId: $0.id, status: .pending, arrivedAt: nil, departedAt: nil)
        }
        let run = SystemDomain.RunInstance(
            id: UUID(),
            templateId: UUID(),
            title: "Long",
            date: Date(),
            departureTime: RunScheduledTime.from(date: Date()),
            status: .scheduled,
            stops: progress,
            stopSnapshots: stops,
            driverId: UUID(),
            childId: UUID(),
            createdAt: Date()
        )
        var context = RunRouteValidationContext()
        context.maxRouteDistanceMeters = 150_000
        let result = RunRouteValidator.validate(run: run, context: context)
        guard case .invalid(let reason) = result else {
            return XCTFail("Expected invalid route")
        }
        guard case .unrealisticDistance = reason else {
            return XCTFail("Expected unrealistic distance")
        }
    }
}

final class ETADisplayFormatterTests: XCTestCase {
    func testUnavailableWhenTooLarge() {
        XCTAssertEqual(ETADisplayFormatter.minutesLabel(for: 33942), "ETA unavailable")
    }

    func testDistanceUnavailableWhenTooLarge() {
        XCTAssertEqual(ETADisplayFormatter.distanceKilometersLabel(meters: 16_962_500), "Distance unavailable")
    }

    func testFormatsReasonableMinutes() {
        XCTAssertEqual(ETADisplayFormatter.minutesLabel(for: 11), "11 min")
    }
}

final class RunJourneyStatusBuilderTests: XCTestCase {
    func testWaitingForPickupAtSchool() {
        let stops = [
            SystemDomain.Stop(id: UUID(), name: "Home", latitude: -26.1, longitude: 28.0, order: 0),
            SystemDomain.Stop(id: UUID(), name: "St Stithians", latitude: -26.2, longitude: 28.1, order: 1),
            SystemDomain.Stop(id: UUID(), name: "Home", latitude: -26.1, longitude: 28.0, order: 2)
        ]
        let progress = [
            SystemDomain.RunStopProgress(stopId: stops[0].id, status: .completed, arrivedAt: nil, departedAt: nil),
            SystemDomain.RunStopProgress(stopId: stops[1].id, status: .arrived, arrivedAt: nil, departedAt: nil),
            SystemDomain.RunStopProgress(stopId: stops[2].id, status: .pending, arrivedAt: nil, departedAt: nil)
        ]
        let run = SystemDomain.RunInstance(
            id: UUID(),
            templateId: UUID(),
            title: "School run",
            date: Date(),
            departureTime: RunScheduledTime.from(date: Date()),
            status: .inProgress,
            stops: progress,
            stopSnapshots: stops,
            activeStopIndex: 1,
            driverId: UUID(),
            childId: UUID(),
            createdAt: Date()
        )
        let status = RunJourneyStatusBuilder.build(run: run, childDisplayName: "TJ", etaMinutes: nil)
        XCTAssertEqual(status.headline, "TJ is at St Stithians")
        XCTAssertEqual(status.detail, "Waiting for pickup")
    }
}

final class RunCoordinateGuardTests: XCTestCase {
    func testAcceptsJohannesburgCoordinate() {
        let jhb = CLLocationCoordinate2D(latitude: -26.2041, longitude: 28.0473)
        XCTAssertTrue(RunCoordinateGuard.isUsableForActiveRunRouting(jhb))
        XCTAssertNil(RunCoordinateGuard.rejectionReason(for: jhb, label: "origin"))
    }

    func testRejectsSimulatorDefaultLocationInDebug() {
        let cupertino = CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.0090)
        #if DEBUG
        XCTAssertFalse(RunCoordinateGuard.isUsableForActiveRunRouting(cupertino))
        XCTAssertNotNil(RunCoordinateGuard.rejectionReason(for: cupertino, label: "current location"))
        #else
        XCTAssertTrue(RunCoordinateGuard.isUsableForActiveRunRouting(cupertino))
        #endif
    }
}

final class ActiveRunProgressCalculatorTests: XCTestCase {
    func testProgressLabelAndFraction() {
        let stops = (0..<3).map { index in
            SystemDomain.Stop(id: UUID(), name: "Stop \(index)", latitude: -26.1, longitude: 28.0, order: index)
        }
        let progress = [
            SystemDomain.RunStopProgress(stopId: stops[0].id, status: .completed, arrivedAt: nil, departedAt: nil),
            SystemDomain.RunStopProgress(stopId: stops[1].id, status: .enRoute, arrivedAt: nil, departedAt: nil),
            SystemDomain.RunStopProgress(stopId: stops[2].id, status: .pending, arrivedAt: nil, departedAt: nil)
        ]
        let run = SystemDomain.RunInstance(
            id: UUID(),
            templateId: UUID(),
            title: "Run",
            date: Date(),
            departureTime: RunScheduledTime.from(date: Date()),
            status: .inProgress,
            stops: progress,
            stopSnapshots: stops,
            activeStopIndex: 1,
            driverId: UUID(),
            childId: UUID(),
            createdAt: Date()
        )
        let result = ActiveRunProgressCalculator.progress(for: run)
        XCTAssertEqual(result.completedStops, 1)
        XCTAssertEqual(result.totalStops, 3)
        XCTAssertEqual(result.statusLabel, "Stop 2 of 3")
        XCTAssertEqual(result.fraction, 1.0 / 3.0, accuracy: 0.001)
    }
}
