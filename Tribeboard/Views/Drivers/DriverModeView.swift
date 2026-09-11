import SwiftUI

struct DriverModeView: View {
    private struct NavigationTarget {
        let name: String
        let latitude: Double
        let longitude: Double
    }

    let driverId: UUID

    @EnvironmentObject private var runDataSource: RunDataSource
    @EnvironmentObject private var driverDataSource: DriverDataSource
    @EnvironmentObject private var locationService: LocationReadinessService
    @StateObject private var etaSmoothingService = ETASmoothingService()
    private let runMapAdapter = RunMapAdapter()

    private var driverName: String {
        driverDataSource.drivers.first(where: { $0.id == driverId })?.name ?? "Driver"
    }

    private var daySummary: DriverDaySummary {
        runDataSource.driverSummary(for: driverId, on: Date())
    }

    private var todayRuns: [SystemDomain.RunInstance] {
        runDataSource.runsForDriver(driverId, on: Date())
    }

    private var activeRun: SystemDomain.RunInstance? {
        runDataSource.activeRunForDriver(driverId, on: Date())
    }

    private var nextScheduledRun: SystemDomain.RunInstance? {
        runDataSource.nextScheduledRunForDriver(driverId, on: Date())
    }

    private var primaryRun: SystemDomain.RunInstance? {
        activeRun ?? nextScheduledRun
    }

    private var primaryLabel: String {
        activeRun != nil ? "Current Run" : "Next Run"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                summaryStrip
                primaryPanel
                assignedRunsSection
            }
            .padding(16)
        }
        .background(UIRunDesignSystem.background.ignoresSafeArea())
        .navigationTitle("Driver Mode")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await runDataSource.refresh()
            await driverDataSource.bootstrapIfNeeded()
            locationService.refreshAuthorizationState()
        }
        .refreshable {
            await runDataSource.refresh()
            await driverDataSource.refresh()
        }
    }

    private var header: some View {
        UICard {
            VStack(alignment: .leading, spacing: 4) {
                Text("Driver Mode")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(UIRunDesignSystem.textPrimary)
                Text(driverName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(UIRunDesignSystem.textPrimary)
                Text(formattedDate(Date()))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(UIRunDesignSystem.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var summaryStrip: some View {
        HStack(spacing: 8) {
            summaryPill(title: "Total", value: daySummary.total, style: .neutral)
            summaryPill(title: "Active", value: daySummary.active, style: .enRoute)
            summaryPill(title: "Scheduled", value: daySummary.scheduled, style: .scheduled)
            summaryPill(title: "Completed", value: daySummary.completed, style: .completed)
        }
    }

    @ViewBuilder
    private var primaryPanel: some View {
        if let run = primaryRun {
            UICard {
                VStack(alignment: .leading, spacing: 10) {
                    Text(primaryLabel)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(UIRunDesignSystem.textSecondary)
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(runTitle(run))
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(UIRunDesignSystem.textPrimary)
                            Text(formattedTime(run.date))
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(UIRunDesignSystem.textSecondary)
                            Text("Stop: \(stopName(for: run))")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(UIRunDesignSystem.textPrimary)
                            if let prediction = etaPrediction(for: run) {
                                Text("ETA: \(formattedTime(prediction.nextStopETA))")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(UIRunDesignSystem.textPrimary)
                                Text("Arriving in \(prediction.estimatedMinutesRemaining) min")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(UIRunDesignSystem.textSecondary)
                                Text(prediction.quality.usedLiveSpeed ? "Live speed" : "Estimated")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(UIRunDesignSystem.textSecondary)
                            }
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 6) {
                            AppBadge(text: statusText(run.status), style: badgeStyle(for: run.status))
                            if locationService.authorizationState == .authorizedWhenInUse
                                || locationService.authorizationState == .authorizedAlways {
                                AppBadge(text: "Location Ready", style: .success)
                            }
                        }
                    }

                    HStack(spacing: 8) {
                        Button("Navigate") {
                            openNavigation(for: run)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(UIRunDesignSystem.primary)
                        .disabled(navigationTarget(for: run) == nil)

                        NavigationLink(value: Destination.runDetails(runId: run.id.uuidString)) {
                            Text("Open Run")
                        }
                        .buttonStyle(.bordered)
                    }

                    RunMapView(model: runMapAdapter.makeModel(run: run, currentLocation: locationService.currentLocation))
                        .frame(height: 160)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    if run.status == .inProgress {
                        liveTrackingPanel(for: run)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            UICard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("No assigned runs today")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(UIRunDesignSystem.textPrimary)
                    Text("Assigned runs for this driver will appear here.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(UIRunDesignSystem.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var assignedRunsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Today's Assigned Runs")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(UIRunDesignSystem.textPrimary)

            if todayRuns.isEmpty {
                Text("No assigned runs today")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(UIRunDesignSystem.textSecondary)
                    .padding(.top, 2)
            } else {
                ForEach(todayRuns) { run in
                    runRow(run)
                }
            }
        }
    }

    private func runRow(_ run: SystemDomain.RunInstance) -> some View {
        UICard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(runTitle(run))
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(UIRunDesignSystem.textPrimary)
                        Text(formattedTime(run.date))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(UIRunDesignSystem.textSecondary)
                    }
                    Spacer()
                    AppBadge(text: statusText(run.status), style: badgeStyle(for: run.status))
                }

                Text("Stop: \(stopName(for: run))")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(UIRunDesignSystem.textSecondary)

                NavigationLink(value: Destination.runDetails(runId: run.id.uuidString)) {
                    Text("Open Run")
                }
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func liveTrackingPanel(for run: SystemDomain.RunInstance) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Driver Location Status")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(UIRunDesignSystem.textSecondary)

            if locationService.trackingActive {
                Text("• Location Active")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(UIRunDesignSystem.textPrimary)
            } else {
                Text("Location unavailable")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(UIRunDesignSystem.textSecondary)
            }

            if locationService.authorizationState != .authorizedWhenInUse
                && locationService.authorizationState != .authorizedAlways {
                Text("Location access improves arrival detection")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.orange)
            }

            if let location = locationService.currentLocation,
               let proximity = runDataSource.proximityForRun(run.id, driverLocation: location) {
                Text("Next Stop")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(UIRunDesignSystem.textSecondary)
                Text(proximity.stopName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(UIRunDesignSystem.textPrimary)
                Text("Distance: \(distanceText(proximity.distanceMeters))")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(UIRunDesignSystem.textPrimary)
                Text("Status: \(proximity.withinArrivalRadius ? "Approaching" : "En route")")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(UIRunDesignSystem.textSecondary)
                if proximity.withinArrivalRadius {
                    AppBadge(text: "Within arrival zone", style: .success, uppercased: false)
                }
            } else {
                Text("Location unavailable")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(UIRunDesignSystem.textSecondary)
            }

            if let timestamp = locationService.lastLocationTimestamp {
                Text("Updated \(secondsAgoText(since: timestamp)) ago")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(UIRunDesignSystem.textSecondary)
            }
        }
        .padding(10)
        .background(Color.black.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func summaryPill(title: String, value: Int, style: BadgeStyle) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(value)")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(UIRunDesignSystem.textPrimary)
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(UIRunDesignSystem.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(borderColor(for: style), lineWidth: 1)
        }
    }

    private func statusText(_ status: SystemDomain.RunStatus) -> String {
        switch status {
        case .scheduled, .assigned:
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
        case .scheduled, .assigned:
            return .scheduled
        case .inProgress:
            return .enRoute
        case .completed:
            return .completed
        case .cancelled:
            return .cancelled
        }
    }

    private func stopName(for run: SystemDomain.RunInstance) -> String {
        if run.status == .inProgress,
           let activeIndex = run.activeStopIndex,
           run.stops.indices.contains(activeIndex),
           let snapshot = run.stopSnapshots.first(where: { $0.id == run.stops[activeIndex].stopId }) {
            return snapshot.name
        }
        if let next = run.stops.first(where: { $0.status == .pending || $0.status == .enRoute || $0.status == .arrived }),
           let snapshot = run.stopSnapshots.first(where: { $0.id == next.stopId }) {
            return snapshot.name
        }
        return run.stopSnapshots.first?.name ?? "No stops"
    }

    private func runTitle(_ run: SystemDomain.RunInstance) -> String {
        let trimmed = run.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "Scheduled Run" : trimmed
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, d MMM yyyy"
        return formatter.string(from: date)
    }

    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    private func borderColor(for style: BadgeStyle) -> Color {
        switch style {
        case .scheduled:
            return Color.purple.opacity(0.24)
        case .pending:
            return Color.gray.opacity(0.24)
        case .enRoute:
            return Color.blue.opacity(0.24)
        case .completed:
            return Color.green.opacity(0.24)
        case .cancelled:
            return Color.gray.opacity(0.22)
        case .overdue:
            return Color.red.opacity(0.24)
        case .info:
            return Color.indigo.opacity(0.2)
        case .success:
            return Color.green.opacity(0.2)
        case .warning:
            return Color.orange.opacity(0.2)
        case .neutral:
            return Color.gray.opacity(0.2)
        case .live:
            return Color.red.opacity(0.2)
        }
    }

    private func navigationTarget(for run: SystemDomain.RunInstance) -> NavigationTarget? {
        if run.status == .inProgress,
           let activeIndex = run.activeStopIndex,
           run.stops.indices.contains(activeIndex),
           let snapshot = run.stopSnapshots.first(where: { $0.id == run.stops[activeIndex].stopId }) {
            return NavigationTarget(name: snapshot.name, latitude: snapshot.latitude, longitude: snapshot.longitude)
        }

        if let next = run.stops.first(where: { $0.status == .pending || $0.status == .enRoute || $0.status == .arrived }),
           let snapshot = run.stopSnapshots.first(where: { $0.id == next.stopId }) {
            return NavigationTarget(name: snapshot.name, latitude: snapshot.latitude, longitude: snapshot.longitude)
        }

        if let firstSnapshot = run.stopSnapshots.sorted(by: { $0.order < $1.order }).first {
            return NavigationTarget(name: firstSnapshot.name, latitude: firstSnapshot.latitude, longitude: firstSnapshot.longitude)
        }

        return nil
    }

    private func openNavigation(for run: SystemDomain.RunInstance) {
        guard let target = navigationTarget(for: run) else { return }
        ExternalNavigationService.open(
            app: .appleMaps,
            destinationName: target.name,
            latitude: target.latitude,
            longitude: target.longitude
        )
    }

    private func distanceText(_ meters: Double) -> String {
        if meters < 1000 {
            return "\(Int(meters.rounded())) m"
        }
        return String(format: "%.1f km", meters / 1000)
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

    private func secondsAgoText(since date: Date) -> String {
        let seconds = max(0, Int(Date().timeIntervalSince(date).rounded()))
        return "\(seconds) seconds"
    }
}

#Preview {
    NavigationStack {
        DriverModeView(driverId: UUID())
            .environmentObject(RunDataSource())
            .environmentObject(DriverDataSource())
            .environmentObject(LocationReadinessService())
            .withNavigationRouter()
    }
}
