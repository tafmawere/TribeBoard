import CoreLocation
import SwiftUI

struct RunExecutionDetailView: View {
    private struct NavigationTarget {
        let name: String
        let latitude: Double
        let longitude: Double
    }

    let runId: String

    @EnvironmentObject private var runDataSource: RunDataSource
    @EnvironmentObject private var driverDataSource: DriverDataSource
    @EnvironmentObject private var householdContext: ActiveHouseholdContext
    @EnvironmentObject private var backendHouseholdContext: BackendHouseholdContext
    @EnvironmentObject private var backendDriversContext: BackendDriversContext
    @EnvironmentObject private var backendHouseholdPeopleContext: BackendHouseholdPeopleContext
    @EnvironmentObject private var backendChildrenContext: BackendChildrenContext
    @EnvironmentObject private var authSession: AuthSessionContext
    @EnvironmentObject private var activeRunDriverSessionStore: ActiveRunDriverSessionStore
    @EnvironmentObject private var familyQuickPlacesStore: FamilyQuickPlacesStore
    @EnvironmentObject private var backendHouseholdLocationsContext: BackendHouseholdLocationsContext
    @EnvironmentObject private var locationService: LocationReadinessService
    @State private var showCancelConfirmation = false
    @State private var showSkipConfirmation = false
    @State private var showStartRunConfirmation = false
    @State private var showDriverPicker = false
    @State private var showNavigationOptions = false
    @State private var showAddStopSheet = false
    @State private var newStopName = ""
    @State private var newStopLatitude = ""
    @State private var newStopLongitude = ""
    @StateObject private var etaSmoothingService = ETASmoothingService()
    private let runMapAdapter = RunMapAdapter()

    private var run: SystemDomain.RunInstance? {
        runDataSource.run(withId: runId)
    }

    private var isBusy: Bool {
        runDataSource.isLoading || runDataSource.isRefreshing
    }

    private var canUpdateRuns: Bool {
        backendHouseholdContext.canUpdateRuns
    }

    private var canManageRunAssignments: Bool {
        backendHouseholdContext.isCurrentUserOrganiser
    }

    private var activeStopIndex: Int? {
        guard let run, run.status == .inProgress else { return nil }
        return run.activeStopIndex
    }

    private var routeValidationContext: RunRouteValidationContext {
        var context = RunRouteValidationContext()
        if let home = backendHouseholdLocationsContext.homeLocation {
            context.homeCoordinate = CLLocationCoordinate2D(latitude: home.latitude, longitude: home.longitude)
        } else if let home = familyQuickPlacesStore.place(forSlotId: "home") {
            context.homeCoordinate = CLLocationCoordinate2D(latitude: home.latitude, longitude: home.longitude)
        }
        return context
    }

    private func routeValidation(for run: SystemDomain.RunInstance) -> RunRouteValidationResult {
        RunRouteValidator.validate(run: run, context: routeValidationContext)
    }

    private func refreshDriverCandidates() async {
        await backendHouseholdPeopleContext.refreshPeople(householdId: householdContext.householdId)
        await backendDriversContext.refreshDrivers(
            householdId: householdContext.householdId,
            memberships: backendHouseholdContext.activeHouseholdMembers,
            profilesByUserId: backendHouseholdContext.activeHouseholdProfilesByUserId,
            householdPeople: backendHouseholdPeopleContext.people,
            childIds: Set(backendChildrenContext.children.map(\.id)),
            currentUserId: authSession.currentUserId.flatMap(UUID.init(uuidString:))
        )
    }

    var body: some View {
        detailScrollView
            .background(UIRunDesignSystem.background.ignoresSafeArea())
            .navigationTitle(runTitle(run))
            .navigationBarTitleDisplayMode(.inline)
            .task { await loadRunDetail() }
            .onChange(of: run?.status) { _, _ in
                presentDriverViewIfNeeded()
            }
            .overlay { busyOverlay }
            .alert(
                "Run Action Failed",
                isPresented: Binding(
                    get: { runDataSource.lastError != nil },
                    set: { isPresented in
                        if !isPresented {
                            runDataSource.lastError = nil
                        }
                    }
                )
            ) {
                Button("OK", role: .cancel) {
                    runDataSource.lastError = nil
                }
            } message: {
                Text(runDataSource.lastError ?? "Unknown error.")
            }
            .alert("Cancel Run?", isPresented: $showCancelConfirmation) {
                Button("Keep", role: .cancel) { }
                Button("Cancel Run", role: .destructive) {
                    cancelRunAction()
                }
            } message: {
                Text("This run will be marked as cancelled.")
            }
            .alert("Skip Active Stop?", isPresented: $showSkipConfirmation) {
                Button("Keep", role: .cancel) { }
                Button("Skip Stop", role: .destructive) {
                    skipStopAction()
                }
            } message: {
                Text("Skipping marks this stop as skipped and moves to the next stop.")
            }
            .sheet(isPresented: $showDriverPicker) { driverPickerSheet }
            .sheet(isPresented: $showStartRunConfirmation) { startRunSheet }
            .sheet(isPresented: $showAddStopSheet, onDismiss: resetAddStopForm) { addStopSheet }
            .confirmationDialog("Navigate with", isPresented: $showNavigationOptions, titleVisibility: .visible) {
                navigationDialogButtons
            }
    }

    @ViewBuilder
    private var driverPickerSheet: some View {
        NavigationStack {
            if let run {
                DriverPickerView(
                    runId: run.id,
                    runHouseholdId: run.householdId,
                    onAddDriver: {
                        NotificationCenter.default.post(name: .tribeboardOpenFamilyForDriverSetup, object: nil)
                    }
                )
            } else {
                ContentUnavailableView("Run not found", systemImage: "car")
            }
        }
    }

    @ViewBuilder
    private var startRunSheet: some View {
        if let run {
            startRunConfirmationSheet(run)
                .presentationDetents([.height(360)])
                .presentationDragIndicator(.visible)
        }
    }

    private var addStopSheet: some View {
        NavigationStack {
            Form {
                Section("Stop Details") {
                    TextField("Stop Name", text: $newStopName)
                        .textInputAutocapitalization(.words)
                    TextField("Latitude", text: $newStopLatitude)
                        .keyboardType(.numbersAndPunctuation)
                    TextField("Longitude", text: $newStopLongitude)
                        .keyboardType(.numbersAndPunctuation)
                }
            }
            .navigationTitle("Add Stop")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showAddStopSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let run = run else { return }
                        guard let latitude = Double(newStopLatitude),
                              let longitude = Double(newStopLongitude) else {
                            runDataSource.lastError = "Enter valid latitude and longitude values."
                            return
                        }
                        Task {
                            await runDataSource.insertStop(
                                runId: run.id,
                                stopName: newStopName,
                                latitude: latitude,
                                longitude: longitude,
                                at: nil
                            )
                            if runDataSource.lastError == nil {
                                showAddStopSheet = false
                            }
                        }
                    }
                    .disabled(newStopName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    @ViewBuilder
    private var navigationDialogButtons: some View {
        if let run, let target = navigationTarget(for: run) {
            Button("Apple Maps") {
                ExternalNavigationService.open(
                    app: .appleMaps,
                    destinationName: target.name,
                    latitude: target.latitude,
                    longitude: target.longitude
                )
            }
            if ExternalNavigationService.canOpen(.googleMaps) {
                Button("Google Maps") {
                    ExternalNavigationService.open(
                        app: .googleMaps,
                        destinationName: target.name,
                        latitude: target.latitude,
                        longitude: target.longitude
                    )
                }
            }
            if ExternalNavigationService.canOpen(.waze) {
                Button("Waze") {
                    ExternalNavigationService.open(
                        app: .waze,
                        destinationName: target.name,
                        latitude: target.latitude,
                        longitude: target.longitude
                    )
                }
            }
        }
        Button("Cancel", role: .cancel) { }
    }

    private var detailScrollView: some View {
        ScrollView {
            VStack(spacing: 18) {
                syncPendingWarningBanner
                if let run {
                    roleAndStateCard(run)
                    mapCard(run)
                    executionDetailSections(for: run)
                } else {
                    ContentUnavailableView("Run not found", systemImage: "car")
                }
            }
            .padding(16)
        }
    }

    @ViewBuilder
    private var syncPendingWarningBanner: some View {
        if let warning = backendDriversContext.syncPendingWarning {
            HStack(spacing: 10) {
                Image(systemName: "icloud.and.arrow.up")
                    .foregroundStyle(.orange)
                Text(warning)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(UIRunDesignSystem.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Button {
                    backendDriversContext.syncPendingWarning = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(UIRunDesignSystem.textSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(12)
            .background(Color.orange.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    @ViewBuilder
    private var busyOverlay: some View {
        if isBusy {
            ZStack {
                Color.black.opacity(0.08).ignoresSafeArea()
                ProgressView("Updating run...")
                    .padding(16)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    private func loadRunDetail() async {
        await runDataSource.refresh()
        await driverDataSource.bootstrapIfNeeded()
        await refreshDriverCandidates()
        locationService.refreshAuthorizationState()
        if let id = UUID(uuidString: runId) {
            await backendHouseholdLocationsContext.refreshForActiveHousehold()
            let placeIndex = StopCoordinateHydrator.buildPlaceIndex(
                slotPlaces: familyQuickPlacesStore.slotPlaces,
                namedPlaces: familyQuickPlacesStore.namedPlaces,
                recentPlaces: familyQuickPlacesStore.recentPlaces,
                homeLocation: backendHouseholdLocationsContext.homeLocation,
                householdLocations: backendHouseholdLocationsContext.locations
            )
            await runDataSource.hydrateStopCoordinatesIfNeeded(runId: id, placeIndex: placeIndex)
            await runDataSource.hydrateStopCoordinatesFromHouseholdLocations(
                runId: id,
                locations: backendHouseholdLocationsContext.locations
            )
        }
        if let run {
            logRunDetailDebug(run)
        }
        presentDriverViewIfNeeded()
    }

    private func cancelRunAction() {
        guard canUpdateRuns else {
            runDataSource.lastError = "Only organisers and drivers can update runs."
            return
        }
        guard let id = run?.id else { return }
        Task { await runDataSource.cancelRun(id: id, locationService: locationService) }
    }

    private func skipStopAction() {
        guard canUpdateRuns else {
            runDataSource.lastError = "Only organisers and drivers can update runs."
            return
        }
        guard let run, let index = run.activeStopIndex else { return }
        Task {
            await runDataSource.skipStop(
                runId: run.id,
                stopIndex: index,
                locationService: locationService
            )
        }
    }

    @ViewBuilder
    private func executionDetailSections(for run: SystemDomain.RunInstance) -> some View {
        switch run.status {
        case .scheduled:
            navigationCard(run)
            etaCard(run)
            actionsCard(run)
            stopsCard(run)
            driverCard(run)
            adjustRouteCard(run)
        case .assigned:
            actionsCard(run)
            stopsCard(run)
            driverCard(run)
        case .inProgress:
            navigationCard(run)
            etaCard(run)
            actionsCard(run)
            stopsCard(run)
            driverCard(run)
            driverModeLinkCard(run)
        case .completed, .cancelled:
            stopsCard(run)
            driverCard(run)
        }
    }

    private func logRunDetailDebug(_ run: SystemDomain.RunInstance) {
        #if DEBUG
        let orderedSnapshots = run.stopSnapshots.sorted { $0.order < $1.order }
        let stopLabels = orderedSnapshots.map { snapshot -> String in
            let kind = RunStopLabelCodec.normalizedKind(snapshot.kind) ?? "-"
            let name = snapshot.name.trimmingCharacters(in: .whitespacesAndNewlines)
            if name.isEmpty { return kind }
            return "\(kind):\(name)"
        }.joined(separator: " | ")
        NSLog(
            "[RunDetail] run_id=%@ status=%@ progress_stops=%d snapshot_stops=%d",
            run.id.uuidString,
            run.status.rawValue,
            run.stops.count,
            run.stopSnapshots.count
        )
        NSLog("[RunDetail] stop_count=%d", orderedSnapshots.count)
        NSLog("[RunDetail] stop_labels=%@", stopLabels.isEmpty ? "(none)" : stopLabels)
        #endif
    }

    private func driverModeLinkCard(_ run: SystemDomain.RunInstance) -> some View {
        UICard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Driver Mode")
                    .font(.system(size: 16, weight: .semibold))
                Text("Full-screen navigation and map tracking.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(UIRunDesignSystem.textSecondary)
                secondaryButton("Open Driver Mode") {
                    activeRunDriverSessionStore.present(runId: run.id)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    @ViewBuilder
    private func roleAndStateCard(_ run: SystemDomain.RunInstance) -> some View {
        UICard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Text(stateTitle(run.status))
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(UIRunDesignSystem.textPrimary)
                    Spacer()
                    AppBadge(text: statusText(run.status), style: badgeStyle(for: run.status))
                }
                Text(formattedRunDate(run.date))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(UIRunDesignSystem.textSecondary)
                Text(permissionModeHint)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(UIRunDesignSystem.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func navigationCard(_ run: SystemDomain.RunInstance) -> some View {
        if run.status == .scheduled || run.status == .assigned || run.status == .inProgress {
            let routeIsValid = routeValidation(for: run).isValid
            let target = routeIsValid ? navigationTarget(for: run) : nil
            let isAuthorized = locationService.authorizationState == .authorizedWhenInUse
                || locationService.authorizationState == .authorizedAlways
            let needsPermission = !isAuthorized
            UICard {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(run.status == .inProgress ? "Current Stop / Next Stop" : "Current Stop / Next Stop")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(UIRunDesignSystem.textPrimary)
                        Spacer()
                        AppBadge(text: statusText(run.status), style: badgeStyle(for: run.status))
                    }

                    Text(formattedRunDate(run.date))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(UIRunDesignSystem.textSecondary)

                    if routeIsValid {
                        Text(target?.name ?? "Stop unavailable")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(UIRunDesignSystem.textPrimary)

                        if target != nil {
                            Text("Ready for navigation")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(UIRunDesignSystem.textSecondary)
                        }
                    } else {
                        Text("Route not ready")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(UIRunDesignSystem.textPrimary)
                        Text("Add valid pickup and drop-off locations to calculate navigation.")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(UIRunDesignSystem.textSecondary)
                    }

                    if locationService.currentLocation != nil {
                        Text("Current Location Available")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(UIRunDesignSystem.textSecondary)
                    }

                    if locationService.authorizationState == .denied || locationService.authorizationState == .restricted {
                        Text("Navigation will still open externally, but current location access is unavailable.")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.orange)
                    }

                    if needsPermission {
                        HStack {
                            Text("Location access improves navigation readiness.")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(UIRunDesignSystem.textSecondary)
                            Spacer()
                            Button("Enable Location") {
                                locationService.requestWhenInUseAccess()
                            }
                            .font(.system(size: 12, weight: .semibold))
                        }
                    }

                    Button("Navigate") {
                        showNavigationOptions = true
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(UIRunDesignSystem.primary)
                    .disabled(target == nil || !routeIsValid)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private func etaCard(_ run: SystemDomain.RunInstance) -> some View {
        if run.status == .scheduled || run.status == .assigned || run.status == .inProgress {
            let routeIsValid = routeValidation(for: run).isValid
            UICard {
                VStack(alignment: .leading, spacing: 10) {
                    Text("ETA")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(UIRunDesignSystem.textPrimary)

                    if !routeIsValid {
                        Text("Route not ready")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(UIRunDesignSystem.textPrimary)
                        Text("Add valid pickup and drop-off locations to calculate navigation.")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(UIRunDesignSystem.textSecondary)
                    } else if let prediction = etaPrediction(for: run) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Next Stop")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(UIRunDesignSystem.textSecondary)
                            Text(prediction.nextStopName)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(UIRunDesignSystem.textPrimary)
                            Text("\(distanceText(prediction.nextStopDistanceMeters)) • ETA \(formattedClock(prediction.nextStopETA))")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(UIRunDesignSystem.textPrimary)
                            Text("Arriving in \(prediction.estimatedMinutesRemaining) min")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(UIRunDesignSystem.textSecondary)
                            Text("Confidence: \(confidenceText(prediction.quality.confidence))")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(UIRunDesignSystem.textSecondary)

                            Divider()

                            Text("Final Stop")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(UIRunDesignSystem.textSecondary)
                            Text("\(prediction.finalStopName) • ETA \(formattedClock(prediction.finalStopETA))")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(UIRunDesignSystem.textPrimary)

                            Text(prediction.quality.reason)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(UIRunDesignSystem.textSecondary)
                        }
                    } else if locationService.currentLocation == nil {
                        Text("ETA available when live location is active.")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(UIRunDesignSystem.textSecondary)
                    } else {
                        Text("ETA unavailable for the current route.")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(UIRunDesignSystem.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func mapCard(_ run: SystemDomain.RunInstance) -> some View {
        let model = runMapAdapter.makeModel(
            run: run,
            currentLocation: locationService.currentLocation,
            routeContext: routeValidationContext
        )
        let routeIsValid = routeValidation(for: run).isValid
        return UICard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Run Map")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(UIRunDesignSystem.textPrimary)

                if routeIsValid || model.region != nil {
                    RunMapView(model: model)
                        .frame(height: 240)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "map")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(UIRunDesignSystem.textSecondary)
                        Text("Route not ready")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(UIRunDesignSystem.textPrimary)
                        Text("Add valid pickup and drop-off locations to calculate navigation.")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(UIRunDesignSystem.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 240)
                    .background(Color.gray.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                HStack(spacing: 8) {
                    AppBadge(text: "Driver", style: .enRoute, uppercased: false)
                    AppBadge(text: "Active Stop", style: .warning, uppercased: false)
                    AppBadge(text: "Pending", style: .pending, uppercased: false)
                    AppBadge(text: "Completed", style: .completed, uppercased: false)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func adjustRouteCard(_ run: SystemDomain.RunInstance) -> some View {
        if run.status == .scheduled || run.status == .assigned || run.status == .inProgress {
            UICard {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Adjust Route")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(UIRunDesignSystem.textPrimary)
                        Spacer()
                        Button("Add Stop") {
                            showAddStopSheet = true
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .disabled(isBusy || !canManageRunAssignments)
                    }
                    if !canManageRunAssignments {
                        Text("Only organisers can adjust routes.")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(UIRunDesignSystem.textSecondary)
                    }

                    if reorderableFutureIndices(for: run).isEmpty {
                        Text("No future stops available for route adjustment.")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(UIRunDesignSystem.textSecondary)
                    } else {
                        LazyVStack(alignment: .leading, spacing: 8) {
                            Text("Future Stops")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(UIRunDesignSystem.textSecondary)

                            ForEach(Array(reorderableFutureIndices(for: run).enumerated()), id: \.element) { position, index in
                                let stop = run.stops[index]
                                HStack(spacing: 8) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(stopLabel(for: run, stop: stop, index: index))
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(UIRunDesignSystem.textPrimary)
                                        Text("Stop \(index + 1)")
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundStyle(UIRunDesignSystem.textSecondary)
                                    }
                                    Spacer()

                                    Button {
                                        Task {
                                            await runDataSource.deferStop(runId: run.id, index: index)
                                        }
                                    } label: {
                                        Image(systemName: "arrow.uturn.down")
                                    }
                                    .buttonStyle(.bordered)
                                    .disabled(isBusy || !canManageRunAssignments || position == reorderableFutureIndices(for: run).count - 1)

                                    Button {
                                        guard position > 0 else { return }
                                        let destination = reorderableFutureIndices(for: run)[position - 1]
                                        Task {
                                            await runDataSource.moveStop(runId: run.id, from: index, to: destination)
                                        }
                                    } label: {
                                        Image(systemName: "arrow.up")
                                    }
                                    .buttonStyle(.bordered)
                                    .disabled(isBusy || !canManageRunAssignments || position == 0)

                                    Button {
                                        guard position < reorderableFutureIndices(for: run).count - 1 else { return }
                                        let destination = reorderableFutureIndices(for: run)[position + 1]
                                        Task {
                                            await runDataSource.moveStop(runId: run.id, from: index, to: destination)
                                        }
                                    } label: {
                                        Image(systemName: "arrow.down")
                                    }
                                    .buttonStyle(.bordered)
                                    .disabled(isBusy || !canManageRunAssignments || position == reorderableFutureIndices(for: run).count - 1)

                                    Button(role: .destructive) {
                                        Task {
                                            await runDataSource.removeStop(runId: run.id, index: index)
                                        }
                                    } label: {
                                        Image(systemName: "trash")
                                    }
                                    .buttonStyle(.bordered)
                                    .disabled(isBusy || !canManageRunAssignments || !canRemoveStop(in: run, index: index))
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func stopsCard(_ run: SystemDomain.RunInstance) -> some View {
        UICard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Stop Progress")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(UIRunDesignSystem.textPrimary)
                stopsCardContent(run)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func stopsCardContent(_ run: SystemDomain.RunInstance) -> some View {
        if run.stops.isEmpty {
            if run.stopSnapshots.isEmpty {
                Text("No stops attached to this run.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(UIRunDesignSystem.textSecondary)
            } else {
                plannedStopsList(run)
            }
        } else {
            progressStopsList(run)
        }
    }

    @ViewBuilder
    private func plannedStopsList(_ run: SystemDomain.RunInstance) -> some View {
        stopSectionHeader("Planned Stops")
        let ordered = run.stopSnapshots.sorted { $0.order < $1.order }
        ForEach(Array(ordered.enumerated()), id: \.element.id) { index, snapshot in
            plannedStopRow(snapshot: snapshot, index: index)
        }
    }

    private func plannedStopRow(snapshot: SystemDomain.Stop, index: Int) -> some View {
        HStack {
            Text(plannedStopLabel(snapshot: snapshot, index: index))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(UIRunDesignSystem.textPrimary)
            Spacer()
            AppBadge(text: "Pending", style: .pending, uppercased: false)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    @ViewBuilder
    private func progressStopsList(_ run: SystemDomain.RunInstance) -> some View {
        let completedIndexes = run.stops.indices.filter { run.stops[$0].status == .completed }
        let activeIndexes = run.activeStopIndex.map { [$0] } ?? []
        let remainingIndexes = run.stops.indices.filter { index in
            !completedIndexes.contains(index) && !activeIndexes.contains(index)
        }

        LazyVStack(alignment: .leading, spacing: 8) {
            if !completedIndexes.isEmpty {
                stopSectionHeader("Completed")
                ForEach(completedIndexes, id: \.self) { index in
                    stopRow(run: run, index: index, labelPrefix: "Completed")
                }
            }

            if !activeIndexes.isEmpty {
                stopSectionHeader("Current Stop")
                ForEach(activeIndexes, id: \.self) { index in
                    stopRow(run: run, index: index, labelPrefix: "Current Stop")
                }
            }

            if !remainingIndexes.isEmpty {
                stopSectionHeader("Remaining Stops")
                ForEach(remainingIndexes, id: \.self) { index in
                    stopRow(run: run, index: index, labelPrefix: nil)
                }
            }
        }
    }

    private func stopSectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(UIRunDesignSystem.textSecondary)
            .padding(.top, 2)
    }

    private func stopRow(run: SystemDomain.RunInstance, index: Int, labelPrefix: String?) -> some View {
        let stop = run.stops[index]
        let isCurrent = index == run.activeStopIndex
        let isCompleted = stop.status == .completed
        return HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(stopLabel(for: run, stop: stop, index: index))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isCurrent ? UIRunDesignSystem.primary : UIRunDesignSystem.textPrimary)
                if let labelPrefix {
                    Text(labelPrefix)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(UIRunDesignSystem.textSecondary)
                }
                if let arrivedAt = stop.arrivedAt {
                    Text("Arrived \(formattedClock(arrivedAt))")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(UIRunDesignSystem.textSecondary)
                }
                if let departedAt = stop.departedAt {
                    Text("Departed \(formattedClock(departedAt))")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(UIRunDesignSystem.textSecondary)
                }
            }
            Spacer()
            AppBadge(
                text: stopStatusText(stop.status, isActiveIndex: index == run.activeStopIndex),
                style: stopBadgeStyle(stop.status, isActiveIndex: index == run.activeStopIndex),
                uppercased: false
            )
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(stopBackground(isCurrent: isCurrent, isCompleted: isCompleted))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            if isCurrent {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(UIRunDesignSystem.primary.opacity(0.45), lineWidth: 1.5)
            }
        }
    }

    private func driverCard(_ run: SystemDomain.RunInstance) -> some View {
        let displayDriver = assignedDriverName(for: run)
        let isTerminal = run.status == .completed || run.status == .cancelled
        return UICard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Driver")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(UIRunDesignSystem.textPrimary)
                HStack {
                    Text(displayDriver ?? "Unassigned")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(displayDriver == nil ? Color.orange : UIRunDesignSystem.textPrimary)
                    Spacer()
                    if isTerminal {
                        Text("Locked")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(UIRunDesignSystem.textSecondary)
                    } else if displayDriver == nil, canManageRunAssignments {
                        Button("Assign Driver") {
                            showDriverPicker = true
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(UIRunDesignSystem.primary)
                        .disabled(isBusy)
                    } else if canManageRunAssignments {
                        Button("Assign Driver") {
                            showDriverPicker = true
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .disabled(isBusy)
                    }
                }
                if isTerminal {
                    Text("Driver assignment is locked for completed/cancelled runs.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(UIRunDesignSystem.textSecondary)
                } else if displayDriver == nil {
                    Text("No driver assigned")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.orange)
                } else if !canManageRunAssignments {
                    Text("Only organisers can assign drivers.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(UIRunDesignSystem.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func actionsCard(_ run: SystemDomain.RunInstance) -> some View {
        UICard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Actions")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(UIRunDesignSystem.textPrimary)

                switch run.status {
                case .scheduled, .assigned:
                    if canUpdateRuns {
                        routeSummaryCard(run)
                        if let validationMessage = startRunValidationMessage(for: run) {
                            Text(validationMessage)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.orange)
                                .fixedSize(horizontal: false, vertical: true)
                            NavigationLink(value: Destination.runEdit(runId: run.id.uuidString)) {
                                Text("Fix Location")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                        }
                        primaryButton("Start Run") {
                            showStartRunConfirmation = true
                        }
                        .disabled(startRunValidationMessage(for: run) != nil)
                    } else if backendHouseholdContext.hasActiveMembership {
                        Text("Observers have view-only access.")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(UIRunDesignSystem.textSecondary)
                    }
                    if canUpdateRuns {
                        dangerButton("Cancel Run") {
                            showCancelConfirmation = true
                        }
                    }
                case .inProgress:
                    if canUpdateRuns {
                        if let activeIndex = run.activeStopIndex, run.stops.indices.contains(activeIndex) {
                            let activeStop = run.stops[activeIndex]
                            Text("Current stop: \(stopLabel(for: run, stop: activeStop, index: activeIndex))")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(UIRunDesignSystem.textSecondary)
                            if activeStop.status == .arrived {
                                primaryButton("Depart Stop") {
                                    Task {
                                        await runDataSource.departStop(
                                            runId: run.id,
                                            stopIndex: activeIndex,
                                            locationService: locationService
                                        )
                                    }
                                }
                            } else {
                                primaryButton("Arrive") {
                                    Task {
                                        await runDataSource.arriveStop(
                                            runId: run.id,
                                            stopIndex: activeIndex,
                                            locationService: locationService
                                        )
                                    }
                                }
                            }
                            secondaryButton("Skip Stop") {
                                showSkipConfirmation = true
                            }
                        }

                        if canComplete(run) {
                            secondaryButton("Complete Run") {
                                Task { await runDataSource.completeRun(id: run.id, locationService: locationService) }
                            }
                        }

                        if canUpdateRuns {
                            Divider()
                            dangerButton("Cancel Run") {
                                showCancelConfirmation = true
                            }
                        }
                    } else if backendHouseholdContext.hasActiveMembership {
                        Text("Observers have view-only access.")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(UIRunDesignSystem.textSecondary)
                    }
                case .completed, .cancelled:
                    Text("Run is read-only in its current state.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(UIRunDesignSystem.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(UIRunDesignSystem.primary)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isBusy)
        .opacity(isBusy ? 0.7 : 1)
    }

    private func startRunConfirmationSheet(_ run: SystemDomain.RunInstance) -> some View {
        let child = RunDisplayStrings.childName(for: run, children: backendChildrenContext.children)
        let route = RunDisplayStrings.routeEndpoints(for: run)
        let assignedDriver = assignedDriverName(for: run) ?? "No driver assigned"
        let validationMessage = startRunValidationMessage(for: run)
        let canStart = validationMessage == nil
        return VStack(alignment: .leading, spacing: 14) {
            Text("Start Run?")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(UIRunDesignSystem.textPrimary)

            VStack(alignment: .leading, spacing: 8) {
                startRunDetailRow(label: "Child", value: child)
                startRunDetailRow(label: "Route", value: "\(route.pickup) → \(route.dropoff)")
                startRunDetailRow(label: "Departure", value: formattedClock(run.date))
                startRunDetailRow(
                    label: "Assigned Driver",
                    value: assignedDriver,
                    highlightWarning: assignedDriver == "No driver assigned"
                )
            }

            Spacer(minLength: 4)

            if let validationMessage {
                Text(validationMessage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.orange)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if canStart {
                primaryButton("Start Run") {
                    showStartRunConfirmation = false
                    Task {
                        await runDataSource.startRun(id: run.id, locationService: locationService)
                        presentDriverViewIfNeeded()
                    }
                }
            } else if assignedDriverName(for: run) == nil, canManageRunAssignments {
                primaryButton("Assign Driver First") {
                    showStartRunConfirmation = false
                    showDriverPicker = true
                }
            }

            secondaryButton("Cancel") {
                showStartRunConfirmation = false
            }
        }
        .padding(20)
        .background(UIRunDesignSystem.background)
    }

    private func startRunValidationMessage(for run: SystemDomain.RunInstance) -> String? {
        if !canUpdateRuns {
            return "Only organisers and drivers can start runs."
        }
        if assignedDriverName(for: run) == nil {
            return "A driver must be assigned before this run can start."
        }
        if run.stopSnapshots.count < 2 {
            return "At least two stops are required before starting this run."
        }
        return nil
    }

    private func presentDriverViewIfNeeded() {
        guard let run, run.status == .inProgress else { return }
        let currentUserId = authSession.currentUserId.flatMap(UUID.init(uuidString:))
        guard RunDriverIdentityResolver.isCurrentUserDriver(
            run: run,
            drivers: backendDriversContext.drivers,
            currentUserId: currentUserId
        ) else { return }
        activeRunDriverSessionStore.present(runId: run.id)
    }

    private func startRunDetailRow(label: String, value: String, highlightWarning: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(UIRunDesignSystem.textSecondary)
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(highlightWarning ? Color.orange : UIRunDesignSystem.textPrimary)
        }
    }

    private func secondaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(UIRunDesignSystem.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .background(Color.gray.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isBusy)
        .opacity(isBusy ? 0.7 : 1)
    }

    private func dangerButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(role: .destructive, action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.red)
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .background(Color.red.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isBusy)
        .opacity(isBusy ? 0.7 : 1)
    }

    private func canComplete(_ run: SystemDomain.RunInstance) -> Bool {
        guard run.status == .inProgress else { return false }
        if run.stops.isEmpty {
            return run.activeStopIndex == nil
        }
        return run.activeStopIndex == nil && run.stops.allSatisfy { $0.status == .completed || $0.status == .skipped }
    }

    private func plannedStopLabel(snapshot: SystemDomain.Stop, index: Int) -> String {
        let kind = RunStopLabelCodec.normalizedKind(snapshot.kind)
        let name = snapshot.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let kind, !name.isEmpty {
            return "\(kind) → \(name)"
        }
        if !name.isEmpty {
            return name
        }
        if let kind {
            return kind
        }
        return "Stop \(index + 1)"
    }

    private func stopLabel(for run: SystemDomain.RunInstance, stop: SystemDomain.RunStopProgress, index: Int) -> String {
        if let snapshot = run.stopSnapshots.first(where: { $0.id == stop.stopId }) {
            let kind = RunStopLabelCodec.normalizedKind(snapshot.kind)
            let name = snapshot.name.trimmingCharacters(in: .whitespacesAndNewlines)
            if let kind, !name.isEmpty {
                return "\(kind) → \(name)"
            }
            if !name.isEmpty {
                return name
            }
            if let kind {
                return kind
            }
        }
        return "Stop \(index + 1)"
    }

    private func statusText(_ status: SystemDomain.RunStatus) -> String {
        switch status {
        case .scheduled:
            return "Scheduled"
        case .assigned:
            return "Assigned"
        case .inProgress:
            return "In Progress"
        case .completed:
            return "Completed"
        case .cancelled:
            return "Cancelled"
        }
    }

    private func badgeStyle(for status: SystemDomain.RunStatus) -> BadgeStyle {
        switch status {
        case .scheduled:
            return .scheduled
        case .assigned:
            return .info
        case .inProgress:
            return .enRoute
        case .completed:
            return .completed
        case .cancelled:
            return .cancelled
        }
    }

    private func stopStatusText(_ status: SystemDomain.StopStatus, isActiveIndex: Bool) -> String {
        if isActiveIndex {
            return "Active"
        }
        switch status {
        case .pending:
            return "Pending"
        case .enRoute:
            return "En Route"
        case .arrived:
            return "Arrived"
        case .completed:
            return "Completed"
        case .skipped:
            return "Skipped"
        }
    }

    private func stopBadgeStyle(_ status: SystemDomain.StopStatus, isActiveIndex: Bool) -> BadgeStyle {
        if isActiveIndex {
            return .enRoute
        }
        switch status {
        case .pending:
            return .pending
        case .enRoute, .arrived:
            return .enRoute
        case .completed:
            return .completed
        case .skipped:
            return .cancelled
        }
    }

    private func reorderableFutureIndices(for run: SystemDomain.RunInstance) -> [Int] {
        if run.status == .completed || run.status == .cancelled {
            return []
        }
        let baseIndex: Int
        if run.status == .inProgress {
            baseIndex = (run.activeStopIndex ?? -1) + 1
        } else {
            baseIndex = 0
        }
        guard baseIndex < run.stops.count else { return [] }
        return run.stops.indices.filter { index in
            index >= baseIndex && (run.stops[index].status == .pending || run.stops[index].status == .skipped)
        }
    }

    private func canRemoveStop(in run: SystemDomain.RunInstance, index: Int) -> Bool {
        guard run.stops.indices.contains(index), run.stops.count > 1 else { return false }
        if run.stops[index].status == .completed { return false }
        if let active = run.activeStopIndex, index == active { return false }
        if run.status == .inProgress, let active = run.activeStopIndex, index < active { return false }
        return true
    }

    private func formattedRunDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, d MMM • h:mm a"
        return formatter.string(from: date)
    }

    private func formattedClock(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    private func distanceText(_ meters: Double) -> String {
        if meters < 1000 {
            return "\(Int(meters.rounded())) m"
        }
        return String(format: "%.1f km", meters / 1000)
    }

    private func navigationTarget(for run: SystemDomain.RunInstance) -> NavigationTarget? {
        guard run.status == .scheduled || run.status == .assigned || run.status == .inProgress else { return nil }
        guard routeValidation(for: run).isValid else { return nil }

        if run.status == .inProgress,
           let activeIndex = run.activeStopIndex,
           run.stops.indices.contains(activeIndex) {
            let activeStop = run.stops[activeIndex]
            if let snapshot = run.stopSnapshots.first(where: { $0.id == activeStop.stopId }),
               RunRouteValidator.isPlausibleCoordinate(
                   CLLocationCoordinate2D(latitude: snapshot.latitude, longitude: snapshot.longitude)
               ) {
                return NavigationTarget(name: snapshot.name, latitude: snapshot.latitude, longitude: snapshot.longitude)
            }
        }

        if let nextPending = run.stops.first(where: { $0.status == .pending || $0.status == .enRoute || $0.status == .arrived }),
           let snapshot = run.stopSnapshots.first(where: { $0.id == nextPending.stopId }),
           RunRouteValidator.isPlausibleCoordinate(
               CLLocationCoordinate2D(latitude: snapshot.latitude, longitude: snapshot.longitude)
           ) {
            return NavigationTarget(name: snapshot.name, latitude: snapshot.latitude, longitude: snapshot.longitude)
        }

        if let firstSnapshot = run.stopSnapshots.sorted(by: { $0.order < $1.order }).first,
           RunRouteValidator.isPlausibleCoordinate(
               CLLocationCoordinate2D(latitude: firstSnapshot.latitude, longitude: firstSnapshot.longitude)
           ) {
            let fallbackName = firstSnapshot.name.isEmpty
                ? String(format: "Stop %.4f, %.4f", firstSnapshot.latitude, firstSnapshot.longitude)
                : firstSnapshot.name
            return NavigationTarget(name: fallbackName, latitude: firstSnapshot.latitude, longitude: firstSnapshot.longitude)
        }

        return nil
    }

    private func runTitle(_ run: SystemDomain.RunInstance?) -> String {
        guard let run else { return "Run" }
        let trimmed = run.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "Scheduled Run" : trimmed
    }

    private var permissionModeHint: String {
        if backendHouseholdContext.isCurrentUserOrganiser {
            return "Organiser mode: assignment and operational oversight"
        }
        if backendHouseholdContext.isCurrentUserDriver {
            return "Driver mode: execute stop progression"
        }
        return "Observer mode: tracking only (view-only)"
    }

    private func stateTitle(_ status: SystemDomain.RunStatus) -> String {
        switch status {
        case .scheduled:
            return "Not Started"
        case .assigned:
            return "Assigned"
        case .inProgress:
            return "In Progress"
        case .completed:
            return "Completed"
        case .cancelled:
            return "Cancelled"
        }
    }

    private func assignedDriverName(for run: SystemDomain.RunInstance) -> String? {
        let backendName = backendDriversContext.driverName(forRunId: run.id)?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let backendName, !backendName.isEmpty {
            return backendName
        }
        let localName = run.assignedDriverName?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let localName, !localName.isEmpty {
            return localName
        }
        return nil
    }

    private func routeSummaryCard(_ run: SystemDomain.RunInstance) -> some View {
        let route = RunDisplayStrings.routeEndpoints(for: run)
        let child = RunDisplayStrings.childName(for: run, children: backendChildrenContext.children)
        let assigned = assignedDriverName(for: run) ?? "Unassigned"
        return VStack(alignment: .leading, spacing: 6) {
            Text("Run Summary")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(UIRunDesignSystem.textPrimary)
            Text("Child: \(child)")
                .font(.system(size: 12, weight: .semibold))
            Text("Route: \(route.pickup) → \(route.dropoff)")
                .font(.system(size: 12, weight: .medium))
            Text("Departure: \(formattedClock(run.date))")
                .font(.system(size: 12, weight: .medium))
            Text("Driver: \(assigned)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(assigned == "Unassigned" ? Color.orange : UIRunDesignSystem.textPrimary)
        }
        .foregroundStyle(UIRunDesignSystem.textSecondary)
        .padding(10)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func stopBackground(isCurrent: Bool, isCompleted: Bool) -> Color {
        if isCurrent {
            return UIRunDesignSystem.primary.opacity(0.10)
        }
        if isCompleted {
            return Color.green.opacity(0.08)
        }
        return Color.gray.opacity(0.08)
    }

    private func nonEmptyOrNil(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    private func etaPrediction(for run: SystemDomain.RunInstance) -> ETAPrediction? {
        guard routeValidation(for: run).isValid else {
            etaSmoothingService.clear(runId: run.id)
            return nil
        }
        guard let location = locationService.currentLocation else {
            etaSmoothingService.clear(runId: run.id)
            return nil
        }
        if run.status == .completed || run.status == .cancelled {
            etaSmoothingService.clear(runId: run.id)
            return nil
        }
        return runDataSource.smoothedETAForRun(
            run.id,
            currentLocation: location,
            liveSpeedMetersPerSecond: locationService.estimatedSpeedMetersPerSecond,
            sampleCount: locationService.speedSampleCount,
            speedVariance: locationService.speedVariance,
            smoothingService: etaSmoothingService
        )
    }

    private func confidenceText(_ confidence: ETAConfidenceLevel) -> String {
        confidence.rawValue.capitalized
    }

    private func resetAddStopForm() {
        newStopName = ""
        newStopLatitude = ""
        newStopLongitude = ""
    }

}

#Preview {
    NavigationStack {
        RunExecutionDetailView(runId: UUID().uuidString)
            .environmentObject(RunDataSource())
            .environmentObject(DriverDataSource())
            .environmentObject(ActiveHouseholdContext())
            .environmentObject(BackendDriversContext(backendRunsContext: BackendRunsContext()))
            .environmentObject(LocationReadinessService())
    }
}
