import CoreLocation
import SwiftUI

/// Full-screen driver mode for one active run (map-first, minimal chrome).
struct DriverModeActiveRunFullscreenView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var runDataSource: RunDataSource
    @EnvironmentObject private var locationService: LocationReadinessService

    let systemRun: SystemDomain.RunInstance
    let canPerformRunActions: Bool

    @StateObject private var etaSmoothingService = ETASmoothingService()
    @State private var selectedStopId: UUID?
    @State private var isPerformingAction = false

    var body: some View {
        ZStack(alignment: .top) {
            ActiveRunRouteMapView(
                run: systemRun,
                currentLocation: locationService.currentLocation,
                selectedStopId: $selectedStopId
            )
            .ignoresSafeArea()

            LinearGradient(
                colors: [Color.black.opacity(0.45), Color.clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 100)
            .ignoresSafeArea(edges: .top)
            .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28, weight: .regular))
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, Color.black.opacity(0.35))
                    }
                    .accessibilityLabel("Close driver mode")
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)

                Spacer(minLength: 0)

                if let callout = calloutText {
                    Text(callout)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                }

                primaryActionBar
                    .padding(.horizontal, 16)
                    .padding(.bottom, 28)
            }
        }
        .statusBarHidden(false)
    }

    private var calloutText: String? {
        guard let id = selectedStopId,
              let stop = systemRun.stopSnapshots.first(where: { $0.id == id }) else { return nil }
        return "\(stop.name)"
    }

    private var primaryActionBar: some View {
        let action = ActiveRunPrimaryAction.resolve(for: systemRun)
        return Button {
            Task { await perform(action) }
        } label: {
            Group {
                if isPerformingAction {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text(action.title)
                        .font(.system(size: 17, weight: .bold))
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(canPerformRunActions ? Color.blue : Color.gray.opacity(0.55))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
            .disabled(!canPerformRunActions || isPerformingAction || !action.allowsAction)
    }

    private func perform(_ action: ActiveRunPrimaryAction) async {
        guard canPerformRunActions else { return }
        isPerformingAction = true
        defer { isPerformingAction = false }
        switch action {
        case let .arrive(idx):
            await runDataSource.arriveStop(runId: systemRun.id, stopIndex: idx, locationService: locationService)
        case let .depart(idx):
            await runDataSource.departStop(runId: systemRun.id, stopIndex: idx, locationService: locationService)
        case .complete:
            await runDataSource.completeRun(id: systemRun.id, locationService: locationService)
            dismiss()
        case .none:
            break
        }
    }
}

enum ActiveRunPrimaryAction: Equatable {
    case none
    case arrive(stopIndex: Int)
    case depart(stopIndex: Int)
    case complete

    var allowsAction: Bool {
        switch self {
        case .none: return false
        default: return true
        }
    }

    var title: String {
        switch self {
        case .none: return "—"
        case .arrive: return "Arrive"
        case .depart: return "Depart"
        case .complete: return "Complete run"
        }
    }

    static func resolve(for run: SystemDomain.RunInstance) -> ActiveRunPrimaryAction {
        guard run.status == .inProgress else { return .none }
        let allDone = run.stops.allSatisfy { $0.status == .completed || $0.status == .skipped }
        if !run.stops.isEmpty, allDone {
            return .complete
        }
        guard let idx = run.activeStopIndex, run.stops.indices.contains(idx) else {
            return .none
        }
        switch run.stops[idx].status {
        case .pending, .enRoute:
            return .arrive(stopIndex: idx)
        case .arrived:
            return .depart(stopIndex: idx)
        case .completed, .skipped:
            return .none
        }
    }
}

/// Map-first active run layout for the Runs tab (status strip, current stop, driver mode entry, stops sheet).
struct RunsActiveRunExperienceView: View {
    @EnvironmentObject private var runDataSource: RunDataSource
    @EnvironmentObject private var locationService: LocationReadinessService
    @EnvironmentObject private var backendDriversContext: BackendDriversContext
    @EnvironmentObject private var backendHouseholdContext: BackendHouseholdContext
    @EnvironmentObject private var runLocationObserverStore: RunLocationObserverStore
    @EnvironmentObject private var authSession: AuthSessionContext

    let systemRun: SystemDomain.RunInstance
    let uiRun: UIRun
    let permissions: RunsOverviewPermissions
    /// When `false`, the parent supplies the basemap (e.g. `RunsTripMapBackground`); route polylines are omitted so the shared map stays visible and interactive.
    var embedRouteMap: Bool = true
    let onEnterDriverMode: () -> Void
    let onOpenAllRuns: () -> Void

    @StateObject private var etaSmoothingService = ETASmoothingService()
    @StateObject private var directionsStore = RunDirectionsStore()
    @State private var selectedStopId: UUID?
    @State private var showStopsSheet = false
    @State private var isPerformingAction = false

    var body: some View {
        ZStack(alignment: .bottom) {
            if embedRouteMap {
                ActiveRunRouteMapView(
                    run: systemRun,
                    currentLocation: effectiveDriverLocation,
                    roadPolylineCoordinates: directionsStore.roadCoordinates,
                    routeStatusMessage: directionsStore.loadState.userFacingMessage,
                    isRouteLoading: directionsStore.loadState == .loading,
                    selectedStopId: $selectedStopId
                )
                .ignoresSafeArea(edges: [.horizontal, .top])

                LinearGradient(
                    colors: [Color.black.opacity(0.42), Color.clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 120)
                .frame(maxWidth: .infinity, alignment: .top)
                .ignoresSafeArea(edges: .top)
                .allowsHitTesting(false)
            } else {
                Color.clear
                    .ignoresSafeArea(edges: [.horizontal, .top])
                    .allowsHitTesting(false)
            }

            VStack(alignment: .leading, spacing: 0) {
                statusOverlay
                    .padding(.horizontal, 16)
                    .padding(.top, 10)

                Spacer(minLength: 0)
                    .allowsHitTesting(false)

                if let callout = calloutSubtitle {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "mappin.and.ellipse")
                            .foregroundStyle(UIRunDesignSystem.primary)
                        Text(callout)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(UIRunDesignSystem.textPrimary)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                }

                currentStopCard
                    .padding(.horizontal, 16)

                if permissions.canOpenDriverMode {
                    Button(action: onEnterDriverMode) {
                        Label("Return to navigation", systemImage: "steeringwheel")
                            .font(.system(size: 15, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.black.opacity(0.35))
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }

                Button {
                    showStopsSheet = true
                } label: {
                    Label("All stops", systemImage: "list.number")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.top, 4)

                Button(action: onOpenAllRuns) {
                    HStack(spacing: 7) {
                        Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                            .font(.system(size: 14, weight: .semibold))
                        Text("All runs")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(Color.primary.opacity(0.06))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 10)
            }
        }
        .sheet(isPresented: $showStopsSheet) {
            NavigationStack {
                stopsList
                    .navigationTitle("Stops")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") { showStopsSheet = false }
                        }
                    }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .onAppear {
            directionsStore.refresh(run: systemRun, origin: effectiveDriverLocation, force: true)
        }
        .onChange(of: effectiveDriverLocation) { _, location in
            directionsStore.refresh(run: systemRun, origin: location)
        }
        .onChange(of: systemRun.activeStopIndex) { _, _ in
            directionsStore.refresh(run: systemRun, origin: effectiveDriverLocation)
        }
    }

    private var effectiveDriverLocation: CLLocation? {
        if isCurrentUserDriver {
            return locationService.currentLocation
        }
        return runLocationObserverStore.position(for: systemRun.id)?.location
    }

    private var isCurrentUserDriver: Bool {
        RunDriverIdentityResolver.isCurrentUserDriver(
            run: systemRun,
            drivers: backendDriversContext.drivers,
            currentUserId: authSession.currentUserId.flatMap(UUID.init(uuidString:))
        )
    }

    private var journeyHeadline: String {
        let child = uiRun.passengers.first?.name ?? "Child"
        let eta: Int? = {
            guard let loc = effectiveDriverLocation else { return nil }
            return runDataSource.smoothedETAForRun(
                systemRun.id,
                currentLocation: loc,
                liveSpeedMetersPerSecond: locationService.estimatedSpeedMetersPerSecond,
                sampleCount: locationService.speedSampleCount,
                speedVariance: locationService.speedVariance,
                smoothingService: etaSmoothingService
            )?.estimatedMinutesRemaining
        }()
        return RunJourneyStatusBuilder.build(
            run: systemRun,
            childDisplayName: child,
            etaMinutes: eta
        ).headline
    }

    private var statusOverlay: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                AppBadge(text: "In progress", style: .enRoute, uppercased: false)
                Spacer()
            }
            Text(uiRun.passengers.first?.name ?? "Passenger")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(UIRunDesignSystem.textSecondary)
            Text(uiRun.title)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.35), radius: 2, x: 0, y: 1)
            Text("Driver: \(driverDisplayName)")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.92))
            Text(journeyHeadline)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.92))
            Text("ETA: \(nextStopETALabel)")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.88))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.black.opacity(0.38))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var driverDisplayName: String {
        if let name = backendDriversContext.driverName(forRunId: systemRun.id), !name.isEmpty {
            return name
        }
        return uiRun.driverName
    }

    private var nextStopETALabel: String {
        if let seconds = directionsStore.travelTimeSeconds, seconds > 0 {
            return ETADisplayFormatter.minutesLabel(for: Int(ceil(seconds / 60.0)))
        }
        guard let loc = effectiveDriverLocation,
              RunCoordinateGuard.isUsableForActiveRunRouting(loc.coordinate) else {
            if let meters = directionsStore.distanceMeters,
               ActiveRunNavigationCamera.isReasonableLegDistance(meters: meters) {
                let minutes = max(1, Int(ceil(meters / 11.1 / 60.0)))
                return ETADisplayFormatter.minutesLabel(for: minutes)
            }
            return ETADisplayFormatter.minutesLabel(for: Optional<Int>.none)
        }
        let prediction = runDataSource.smoothedETAForRun(
            systemRun.id,
            currentLocation: loc,
            liveSpeedMetersPerSecond: locationService.estimatedSpeedMetersPerSecond,
            sampleCount: locationService.speedSampleCount,
            speedVariance: locationService.speedVariance,
            smoothingService: etaSmoothingService
        )
        if let prediction {
            return ETADisplayFormatter.minutesLabel(for: prediction)
        }
        return ETADisplayFormatter.minutesLabel(for: Optional<Int>.none)
    }

    private var calloutSubtitle: String? {
        guard let id = selectedStopId,
              let stop = systemRun.stopSnapshots.first(where: { $0.id == id }) else { return nil }
        return stop.name
    }

    private var currentStopCard: some View {
        let action = ActiveRunPrimaryAction.resolve(for: systemRun)
        let stopTitle = currentStopName
        return VStack(alignment: .leading, spacing: 10) {
            Text("Current stop")
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(UIRunDesignSystem.textSecondary)
            Text(stopTitle)
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(UIRunDesignSystem.textPrimary)
            Text("ETA \(nextStopETALabel)")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(UIRunDesignSystem.primary)

            Button {
                Task { await performPrimary(action) }
            } label: {
                Group {
                    if isPerformingAction {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text(action.title)
                            .font(.system(size: 16, weight: .bold))
                    }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(permissions.canPerformRunActions && action.allowsAction ? UIRunDesignSystem.primary : Color.gray.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(!permissions.canPerformRunActions || isPerformingAction || !action.allowsAction)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.35), lineWidth: 1)
        }
    }

    private var currentStopName: String {
        if let idx = systemRun.activeStopIndex,
           systemRun.stops.indices.contains(idx),
           let snap = systemRun.stopSnapshots.first(where: { $0.id == systemRun.stops[idx].stopId }) {
            return snap.name
        }
        if let next = systemRun.stops.first(where: { $0.status == .pending || $0.status == .enRoute || $0.status == .arrived }),
           let snap = systemRun.stopSnapshots.first(where: { $0.id == next.stopId }) {
            return snap.name
        }
        return systemRun.stopSnapshots.sorted(by: { $0.order < $1.order }).first?.name ?? "Stop"
    }

    private func performPrimary(_ action: ActiveRunPrimaryAction) async {
        guard permissions.canPerformRunActions else { return }
        isPerformingAction = true
        defer { isPerformingAction = false }
        switch action {
        case let .arrive(idx):
            await runDataSource.arriveStop(runId: systemRun.id, stopIndex: idx, locationService: locationService)
        case let .depart(idx):
            await runDataSource.departStop(runId: systemRun.id, stopIndex: idx, locationService: locationService)
        case .complete:
            await runDataSource.completeRun(id: systemRun.id, locationService: locationService)
        case .none:
            break
        }
    }

    private var sortedStops: [SystemDomain.Stop] {
        systemRun.stopSnapshots.sorted { $0.order < $1.order }
    }

    private var progressByStopId: [UUID: SystemDomain.RunStopProgress] {
        Dictionary(uniqueKeysWithValues: systemRun.stops.map { ($0.stopId, $0) })
    }

    private var stopsList: some View {
        List {
            ForEach(Array(sortedStops.enumerated()), id: \.element.id) { index, stop in
                let style = rowStyle(stopId: stop.id, order: index + 1)
                HStack(alignment: .top, spacing: 12) {
                    Text("\(index + 1)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(style.badgeForeground)
                        .frame(width: 28, height: 28)
                        .background(style.badgeBackground)
                        .clipShape(Circle())
                    VStack(alignment: .leading, spacing: 4) {
                        Text(stop.name)
                            .font(.system(size: 16, weight: .semibold))
                        Text(style.subtitle)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
                .listRowBackground(style.rowTint)
            }
        }
    }

    private func rowStyle(stopId: UUID, order: Int) -> (badgeBackground: Color, badgeForeground: Color, subtitle: String, rowTint: Color) {
        let progress = progressByStopId[stopId]
        let isCurrent = systemRun.activeStopIndex.flatMap { idx -> Bool in
            guard systemRun.stops.indices.contains(idx) else { return false }
            return systemRun.stops[idx].stopId == stopId
        } ?? false

        switch progress?.status {
        case .completed:
            return (.gray.opacity(0.35), .white, "Completed", Color.gray.opacity(0.08))
        case .skipped:
            return (.gray.opacity(0.28), .white, "Skipped", Color.gray.opacity(0.08))
        default:
            break
        }

        if isCurrent {
            return (.blue, .white, "Current", Color.blue.opacity(0.10))
        }
        return (.gray.opacity(0.22), .primary, "Upcoming", Color.clear)
    }
}
