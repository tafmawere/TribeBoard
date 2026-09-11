import Combine
import CoreLocation
import Foundation

@MainActor
final class RunLocationPublishService {
    private let service: RunLocationBackendService
    private let locationService: LocationReadinessService
    private var publishTask: Task<Void, Never>?
    private var activeRunId: UUID?
    private var activeHouseholdId: UUID?
    private var activeDriverId: UUID?

    private let publishIntervalSeconds: UInt64 = 7

    init(
        service: RunLocationBackendService = SupabaseRunLocationBackendService(),
        locationService: LocationReadinessService
    ) {
        self.service = service
        self.locationService = locationService
    }

    func startPublishing(
        runId: UUID,
        householdId: UUID,
        driverId: UUID?
    ) {
        activeRunId = runId
        activeHouseholdId = householdId
        activeDriverId = driverId
        publishTask?.cancel()
        publishTask = Task { [weak self] in
            await self?.publishLoop()
        }
    }

    func stopPublishing() {
        publishTask?.cancel()
        publishTask = nil
        activeRunId = nil
        activeHouseholdId = nil
        activeDriverId = nil
    }

    private func publishLoop() async {
        while !Task.isCancelled {
            await publishCurrentPosition()
            try? await Task.sleep(nanoseconds: publishIntervalSeconds * 1_000_000_000)
        }
    }

    private func publishCurrentPosition() async {
        guard let runId = activeRunId,
              let householdId = activeHouseholdId,
              let location = locationService.currentLocation,
              RunRouteValidator.isPlausibleCoordinate(location.coordinate) else {
            return
        }

        let position = BackendRunDriverPosition(
            runId: runId,
            householdId: householdId,
            driverId: activeDriverId,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            speedMps: locationService.estimatedSpeedMetersPerSecond,
            headingDegrees: locationService.navigationBearingDegrees,
            updatedAt: Date()
        )

        do {
            try await service.upsertPosition(position)
        } catch {
            NSLog("[RunLocationPublish] failed upsert run=\(runId.uuidString)")
        }
    }
}
