import CoreLocation
import SwiftUI

/// Map-first full-screen driver experience after a run starts.
struct ActiveRunDriverView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var runDataSource: RunDataSource
    @EnvironmentObject private var locationService: LocationReadinessService
    @EnvironmentObject private var backendDriversContext: BackendDriversContext
    @EnvironmentObject private var backendHouseholdContext: BackendHouseholdContext
    @EnvironmentObject private var backendHouseholdLocationsContext: BackendHouseholdLocationsContext
    @EnvironmentObject private var familyQuickPlacesStore: FamilyQuickPlacesStore
    @EnvironmentObject private var activeRunDriverSession: ActiveRunDriverSessionStore

    let runId: UUID

    @StateObject private var directionsStore = RunDirectionsStore()
    @StateObject private var etaSmoothingService = ETASmoothingService()
    @State private var selectedStopId: UUID?
    @State private var isPerformingAction = false
    @State private var isFollowingRoute = true
    @State private var showExternalMapsOption = false

    private var run: SystemDomain.RunInstance? {
        runDataSource.run(withId: runId.uuidString)
    }

    private var canPerformRunActions: Bool {
        backendHouseholdContext.canUpdateRuns
    }

    private var routeContext: RunRouteValidationContext {
        var context = RunRouteValidationContext()
        if let home = backendHouseholdLocationsContext.homeLocation {
            context.homeCoordinate = CLLocationCoordinate2D(latitude: home.latitude, longitude: home.longitude)
        } else if let home = familyQuickPlacesStore.place(forSlotId: "home") {
            context.homeCoordinate = CLLocationCoordinate2D(latitude: home.latitude, longitude: home.longitude)
        }
        return context
    }

    var body: some View {
        Group {
            if let run {
                activeContent(run)
            } else {
                ContentUnavailableView("Run not found", systemImage: "car")
            }
        }
        .onChange(of: run?.activeStopIndex) { _, _ in
            if let run {
                directionsStore.refresh(run: run, origin: locationService.currentLocation, force: true)
            }
        }
        .onChange(of: locationService.currentLocation) { _, location in
            if let run { directionsStore.refresh(run: run, origin: location) }
        }
        .onAppear {
            isFollowingRoute = true
            if let run {
                directionsStore.refresh(run: run, origin: locationService.currentLocation, force: true)
            }
        }
        .confirmationDialog("Open in another app?", isPresented: $showExternalMapsOption, titleVisibility: .visible) {
            ForEach(NavigationApp.allCases, id: \.self) { app in
                if ExternalNavigationService.canOpen(app) {
                    Button(app.rawValue.capitalized) {
                        openExternalNavigation(app: app)
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var navigationCamera: GoogleMapCameraState? {
        guard let run, let destination = activeDestinationCoordinate(for: run) else { return nil }
        let driver = usableDriverCoordinate
        return ActiveRunNavigationCamera.activeLegCamera(
            driver: driver,
            destination: destination,
            follow: isFollowingRoute,
            bearingDegrees: locationService.navigationBearingDegrees
        )
    }

    private var usableDriverCoordinate: CLLocationCoordinate2D? {
        guard let coordinate = locationService.currentLocation?.coordinate,
              RunCoordinateGuard.isUsableForActiveRunRouting(coordinate) else {
            return nil
        }
        return coordinate
    }

    private func activeDestinationCoordinate(for run: SystemDomain.RunInstance?) -> CLLocationCoordinate2D? {
        guard let run, let idx = run.activeStopIndex else { return nil }
        let stops = run.stopSnapshots.sorted { $0.order < $1.order }
        guard stops.indices.contains(idx) else { return nil }
        let stop = stops[idx]
        let coordinate = CLLocationCoordinate2D(latitude: stop.latitude, longitude: stop.longitude)
        return RunRouteValidator.isPlausibleCoordinate(coordinate) ? coordinate : nil
    }

    @ViewBuilder
    private func activeContent(_ run: SystemDomain.RunInstance) -> some View {
        GeometryReader { proxy in
            let sheetHeight = proxy.size.height * 0.28
            let mapHeight = proxy.size.height - sheetHeight + 12

            ZStack(alignment: .bottom) {
                ActiveRunRouteMapView(
                    run: run,
                    currentLocation: locationService.currentLocation,
                    roadPolylineCoordinates: directionsStore.roadCoordinates,
                    routeContext: routeContext,
                    followNavigation: isFollowingRoute,
                    navigationCamera: navigationCamera,
                    routeStatusMessage: directionsStore.loadState.userFacingMessage,
                    isRouteLoading: directionsStore.loadState == .loading,
                    selectedStopId: $selectedStopId
                )
                .frame(height: mapHeight)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .ignoresSafeArea(edges: .top)

                VStack {
                    HStack {
                        Button {
                            activeRunDriverSession.dismiss()
                            dismiss()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 28))
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.white, Color.black.opacity(0.35))
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    Spacer()
                }

                bottomSheet(for: run)
            }
        }
        .background(Color.black.opacity(0.05))
    }

    @ViewBuilder
    private func bottomSheet(for run: SystemDomain.RunInstance) -> some View {
        let identity = RunDriverIdentityResolver.resolve(
            run: run,
            backendDriversContext: backendDriversContext,
            profilesByUserId: backendHouseholdContext.activeHouseholdProfilesByUserId
        )
        let stops = run.stopSnapshots.sorted { $0.order < $1.order }
        let activeIndex = run.activeStopIndex ?? 0
        let currentStop = stops.indices.contains(activeIndex) ? stops[activeIndex] : stops.first
        let primary = ActiveRunActionResolver.primaryAction(for: run)
        let secondary = ActiveRunActionResolver.secondaryAction(for: run)
        let etaMinutes = etaMinutes(for: run)
        let etaLabel = ETADisplayFormatter.minutesLabel(for: etaMinutes)
        let distanceMeters = sanitizedLegDistance(
            directionsStore.distanceMeters ?? legDistanceMeters(for: run)
        )
        let distanceLabel = ETADisplayFormatter.distanceKilometersLabel(meters: distanceMeters)
        let progress = ActiveRunProgressCalculator.progress(for: run)

        ActiveRunDriverBottomSheet(
            runTitle: runTitle(for: run, stopIndex: activeIndex),
            currentStopName: currentStop?.name ?? "Current stop",
            etaLabel: etaLabel,
            distanceLabel: distanceLabel,
            progress: progress,
            driverName: identity.displayName,
            driverAvatar: identity.avatar,
            routeStatusMessage: directionsStore.loadState.userFacingMessage,
            isRouteLoading: directionsStore.loadState == .loading,
            primaryAction: primary,
            secondaryAction: secondary,
            primaryTitle: ActiveRunActionResolver.primaryButtonTitle(for: primary, run: run),
            secondaryTitle: ActiveRunActionResolver.secondaryButtonTitle(
                for: secondary,
                isFollowingRoute: isFollowingRoute
            ),
            canPerformActions: canPerformRunActions,
            isPerformingAction: isPerformingAction,
            onPrimary: { Task { await perform(primary, run: run) } },
            onSecondary: { Task { await perform(secondary, run: run) } },
            onOpenExternalMaps: { showExternalMapsOption = true }
        )
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    private func runTitle(for run: SystemDomain.RunInstance, stopIndex: Int) -> String {
        let stops = run.stopSnapshots.sorted { $0.order < $1.order }
        guard stops.indices.contains(stopIndex) else { return run.title ?? "Active run" }
        let stop = stops[stopIndex]
        let kind = StopLocationClassifier.kind(for: stop, index: stopIndex, totalStops: stops.count)
        switch kind {
        case .school: return "School pickup"
        case .home: return stopIndex == stops.count - 1 ? "Arrived home" : "Home"
        case .other: return run.title ?? stop.name
        }
    }

    private func etaMinutes(for run: SystemDomain.RunInstance) -> Int? {
        if let seconds = directionsStore.travelTimeSeconds, seconds > 0 {
            return Int(ceil(seconds / 60.0))
        }
        if let location = locationService.currentLocation,
           RunCoordinateGuard.isUsableForActiveRunRouting(location.coordinate),
           let prediction = runDataSource.smoothedETAForRun(
               run.id,
               currentLocation: location,
               liveSpeedMetersPerSecond: locationService.estimatedSpeedMetersPerSecond,
               sampleCount: locationService.speedSampleCount,
               speedVariance: locationService.speedVariance,
               smoothingService: etaSmoothingService
           )?.estimatedMinutesRemaining {
            return prediction
        }
        return estimatedMinutesFromRouteDistance(directionsStore.distanceMeters ?? legDistanceMeters(for: run))
    }

    private func estimatedMinutesFromRouteDistance(_ meters: Double?) -> Int? {
        guard let meters, ActiveRunNavigationCamera.isReasonableLegDistance(meters: meters) else { return nil }
        let urbanSpeedMetersPerSecond = 11.1 // ~40 km/h
        return max(1, Int(ceil(meters / urbanSpeedMetersPerSecond / 60.0)))
    }

    private func legDistanceMeters(for run: SystemDomain.RunInstance) -> Double? {
        guard let idx = run.activeStopIndex else { return nil }
        let stops = run.stopSnapshots.sorted { $0.order < $1.order }
        guard stops.indices.contains(idx) else { return nil }
        let stop = stops[idx]
        let dest = CLLocation(latitude: stop.latitude, longitude: stop.longitude)

        if let driver = usableDriverCoordinate {
            return CLLocation(latitude: driver.latitude, longitude: driver.longitude).distance(from: dest)
        }

        if idx > 0 {
            let previous = stops[idx - 1]
            let previousCoord = CLLocationCoordinate2D(latitude: previous.latitude, longitude: previous.longitude)
            let origin = CLLocation(latitude: previous.latitude, longitude: previous.longitude)
            if RunCoordinateGuard.isUsableForActiveRunRouting(previousCoord) {
                return origin.distance(from: dest)
            }
        }
        return nil
    }

    private func sanitizedLegDistance(_ meters: Double?) -> Double? {
        guard ActiveRunNavigationCamera.isReasonableLegDistance(meters: meters) else { return nil }
        return meters
    }

    private func perform(_ action: ActiveRunDriverAction, run: SystemDomain.RunInstance) async {
        guard canPerformRunActions else { return }
        isPerformingAction = true
        defer { isPerformingAction = false }

        switch action {
        case .none:
            break
        case .navigate:
            isFollowingRoute = true
            if let run = self.run {
                directionsStore.refresh(run: run, origin: locationService.currentLocation, force: true)
            }
        case let .arrive(idx):
            await runDataSource.arriveStop(runId: run.id, stopIndex: idx, locationService: locationService)
            directionsStore.refresh(
                run: runDataSource.run(withId: run.id.uuidString) ?? run,
                origin: locationService.currentLocation,
                force: true
            )
        case let .childCollected(idx):
            await runDataSource.departStop(runId: run.id, stopIndex: idx, locationService: locationService)
            if let updated = runDataSource.run(withId: run.id.uuidString) {
                directionsStore.refresh(run: updated, origin: locationService.currentLocation, force: true)
            }
        case .complete:
            await runDataSource.completeRun(id: run.id, locationService: locationService)
            activeRunDriverSession.dismiss()
            dismiss()
        }
    }

    private func openExternalNavigation(app: NavigationApp) {
        guard let run, let idx = run.activeStopIndex else { return }
        let stops = run.stopSnapshots.sorted { $0.order < $1.order }
        guard stops.indices.contains(idx) else { return }
        let stop = stops[idx]
        ExternalNavigationService.open(
            app: app,
            destinationName: stop.name,
            latitude: stop.latitude,
            longitude: stop.longitude
        )
    }
}
