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
    @EnvironmentObject private var locationService: LocationReadinessService
    @State private var showCancelConfirmation = false
    @State private var showSkipConfirmation = false
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

    private var activeStopIndex: Int? {
        guard let run, run.status == .inProgress else { return nil }
        return run.activeStopIndex
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                if let run {
                    mapCard(run)
                    navigationCard(run)
                    etaCard(run)
                    actionsCard(run)
                    driverCard(run)
                    adjustRouteCard(run)
                    stopsCard(run)
                } else {
                    ContentUnavailableView("Run not found", systemImage: "car")
                }
            }
            .padding(16)
        }
        .background(UIRunDesignSystem.background.ignoresSafeArea())
        .navigationTitle(runTitle(run))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await runDataSource.refresh()
            await driverDataSource.bootstrapIfNeeded()
            locationService.refreshAuthorizationState()
        }
        .overlay {
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
                guard let id = run?.id else { return }
                Task { await runDataSource.cancelRun(id: id, locationService: locationService) }
            }
        } message: {
            Text("This run will be marked as cancelled.")
        }
        .alert("Skip Active Stop?", isPresented: $showSkipConfirmation) {
            Button("Keep", role: .cancel) { }
            Button("Skip Stop", role: .destructive) {
                guard let run, let index = run.activeStopIndex else { return }
                Task {
                    await runDataSource.skipStop(
                        runId: run.id,
                        stopIndex: index,
                        locationService: locationService
                    )
                }
            }
        } message: {
            Text("Skipping marks this stop as skipped and moves to the next stop.")
        }
        .sheet(isPresented: $showDriverPicker) {
            NavigationStack {
                if let run {
                    DriverPickerView(runId: run.id)
                } else {
                    ContentUnavailableView("Run not found", systemImage: "car")
                }
            }
        }
        .sheet(isPresented: $showAddStopSheet, onDismiss: resetAddStopForm) {
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
        .confirmationDialog("Navigate with", isPresented: $showNavigationOptions, titleVisibility: .visible) {
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
    }

    @ViewBuilder
    private func navigationCard(_ run: SystemDomain.RunInstance) -> some View {
        if run.status == .scheduled || run.status == .inProgress {
            let target = navigationTarget(for: run)
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

                    Text(target?.name ?? "Stop unavailable")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(UIRunDesignSystem.textPrimary)

                    if target != nil {
                        Text("Ready for navigation")
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
                    .disabled(target == nil)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private func etaCard(_ run: SystemDomain.RunInstance) -> some View {
        if run.status == .scheduled || run.status == .inProgress {
            UICard {
                VStack(alignment: .leading, spacing: 10) {
                    Text("ETA")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(UIRunDesignSystem.textPrimary)

                    if let prediction = etaPrediction(for: run) {
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
        let model = runMapAdapter.makeModel(run: run, currentLocation: locationService.currentLocation)
        return UICard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Run Map")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(UIRunDesignSystem.textPrimary)

                RunMapView(model: model)
                    .frame(height: 240)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

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
        if run.status == .scheduled || run.status == .inProgress {
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
                        .disabled(isBusy)
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
                                    .disabled(isBusy || position == reorderableFutureIndices(for: run).count - 1)

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
                                    .disabled(isBusy || position == 0)

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
                                    .disabled(isBusy || position == reorderableFutureIndices(for: run).count - 1)

                                    Button(role: .destructive) {
                                        Task {
                                            await runDataSource.removeStop(runId: run.id, index: index)
                                        }
                                    } label: {
                                        Image(systemName: "trash")
                                    }
                                    .buttonStyle(.bordered)
                                    .disabled(isBusy || !canRemoveStop(in: run, index: index))
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
                if run.stops.isEmpty {
                    Text("No stops attached to this run.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(UIRunDesignSystem.textSecondary)
                } else {
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
                                stopRow(run: run, index: index, labelPrefix: "Active")
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
            }
            .frame(maxWidth: .infinity, alignment: .leading)
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
        return HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(stopLabel(for: run, stop: stop, index: index))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(UIRunDesignSystem.textPrimary)
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
        .padding(.vertical, 4)
    }

    private func driverCard(_ run: SystemDomain.RunInstance) -> some View {
        let driverName = run.assignedDriverName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let isTerminal = run.status == .completed || run.status == .cancelled
        return UICard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Driver")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(UIRunDesignSystem.textPrimary)
                HStack {
                    Text((driverName?.isEmpty == false ? driverName! : nil) ?? "Unassigned")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(UIRunDesignSystem.textPrimary)
                    Spacer()
                    Button(isTerminal ? "Locked" : "Assign Driver") {
                        showDriverPicker = true
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .disabled(isTerminal || isBusy)
                }
                if isTerminal {
                    Text("Driver assignment is locked for completed/cancelled runs.")
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
                case .scheduled:
                    primaryButton("Start Run") {
                        Task { await runDataSource.startRun(id: run.id, locationService: locationService) }
                    }
                    dangerButton("Cancel Run") {
                        showCancelConfirmation = true
                    }
                case .inProgress:
                    if let activeIndex = run.activeStopIndex, run.stops.indices.contains(activeIndex) {
                        let activeStop = run.stops[activeIndex]
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

                    Divider()

                    dangerButton("Cancel Run") {
                        showCancelConfirmation = true
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

    private func stopLabel(for run: SystemDomain.RunInstance, stop: SystemDomain.RunStopProgress, index: Int) -> String {
        if let snapshot = run.stopSnapshots.first(where: { $0.id == stop.stopId }) {
            return snapshot.name
        }
        return "Stop \(index + 1)"
    }

    private func statusText(_ status: SystemDomain.RunStatus) -> String {
        switch status {
        case .scheduled:
            return "Scheduled"
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
        guard run.status == .scheduled || run.status == .inProgress else { return nil }

        if run.status == .inProgress,
           let activeIndex = run.activeStopIndex,
           run.stops.indices.contains(activeIndex) {
            let activeStop = run.stops[activeIndex]
            if let snapshot = run.stopSnapshots.first(where: { $0.id == activeStop.stopId }) {
                return NavigationTarget(name: snapshot.name, latitude: snapshot.latitude, longitude: snapshot.longitude)
            }
        }

        if let nextPending = run.stops.first(where: { $0.status == .pending || $0.status == .enRoute || $0.status == .arrived }),
           let snapshot = run.stopSnapshots.first(where: { $0.id == nextPending.stopId }) {
            return NavigationTarget(name: snapshot.name, latitude: snapshot.latitude, longitude: snapshot.longitude)
        }

        if let firstSnapshot = run.stopSnapshots.sorted(by: { $0.order < $1.order }).first {
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

    private func etaPrediction(for run: SystemDomain.RunInstance) -> ETAPrediction? {
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
            .environmentObject(LocationReadinessService())
    }
}
