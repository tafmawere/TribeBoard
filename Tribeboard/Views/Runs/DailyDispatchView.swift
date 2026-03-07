import SwiftUI

struct DailyDispatchView: View {
    private struct SelectedRun: Identifiable {
        let id: UUID
    }

    @EnvironmentObject private var runDataSource: RunDataSource
    @EnvironmentObject private var driverDataSource: DriverDataSource
    @EnvironmentObject private var locationService: LocationReadinessService
    @EnvironmentObject private var notificationService: NotificationService
    @StateObject private var etaSmoothingService = ETASmoothingService()

    @State private var selectedDate: Date = Date()
    @State private var selectedRunForDriverPicker: SelectedRun?

    let onOpenRunDetails: (UIRun) -> Void

    private var buckets: DispatchBuckets {
        runDataSource.dispatchBuckets(for: selectedDate)
    }

    private var conflicts: [RunConflict] {
        runDataSource.conflictsForDay(selectedDate)
    }

    private var conflictRunIDs: Set<UUID> {
        Set(conflicts.flatMap(\.runIds))
    }

    private var summary: DispatchSummary {
        runDataSource.dispatchSummary(for: selectedDate)
    }

    private var attentionItems: [AttentionItem] {
        runDataSource.attentionItems(for: selectedDate)
    }

    private var runAttentionByRunID: [UUID: [AttentionItem]] {
        Dictionary(grouping: attentionItems.compactMap { item -> (UUID, AttentionItem)? in
            guard let runId = item.runId else { return nil }
            return (runId, item)
        }) { $0.0 }.mapValues { $0.map(\.1) }
    }

    private var showNotificationHint: Bool {
        notificationService.authorizationState == .notDetermined
            || notificationService.authorizationState == .denied
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                notificationHint
                attentionStrip
                sectionHeader("Summary Metrics")
                summaryStrip

                if summary.total == 0 {
                    emptyState
                } else {
                    section(title: "Unassigned Runs", runs: buckets.unassigned)
                    section(title: "Assigned Runs", runs: buckets.assigned)
                    section(title: "In Progress", runs: buckets.inProgress)
                    section(title: "Completed", runs: buckets.completed)
                    section(title: "Cancelled", runs: buckets.cancelled)
                }
            }
            .padding(16)
        }
        .background(UIRunDesignSystem.background.ignoresSafeArea())
        .task {
            await runDataSource.refresh()
            await driverDataSource.bootstrapIfNeeded()
            await notificationService.refreshAuthorizationState()
        }
        .sheet(item: $selectedRunForDriverPicker) { runId in
            NavigationStack {
                DriverPickerView(runId: runId.id)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Dispatch")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(UIRunDesignSystem.textPrimary)
            Text(formattedDate(selectedDate))
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(UIRunDesignSystem.textSecondary)
        }
    }

    private var summaryStrip: some View {
        HStack(spacing: 8) {
            summaryPill(title: "Total", value: summary.total, style: .neutral)
            summaryPill(title: "Unassigned", value: summary.unassigned, style: .warning)
            summaryPill(title: "In Progress", value: summary.inProgress, style: .enRoute)
            summaryPill(title: "Completed", value: summary.completed, style: .completed)
        }
    }

    @ViewBuilder
    private var notificationHint: some View {
        if showNotificationHint {
            UICard {
                HStack(spacing: 8) {
                    Text("Enable notifications for run reminders")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(UIRunDesignSystem.textSecondary)
                    Spacer()
                    Button("Enable") {
                        Task {
                            let granted = await notificationService.requestAuthorization()
                            if granted {
                                await runDataSource.reconcileNotifications(notificationService: notificationService)
                            }
                        }
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(UIRunDesignSystem.primary)
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private var attentionStrip: some View {
        let visible = Array(attentionItems.prefix(3))
        let remaining = max(0, attentionItems.count - visible.count)
        if !visible.isEmpty {
            UICard {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Attention")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(UIRunDesignSystem.textPrimary)
                        Spacer()
                        let summary = runDataSource.attentionSummary(for: selectedDate)
                        if summary.critical > 0 {
                            AppBadge(text: "\(summary.critical) Critical", style: .live)
                        } else if summary.warning > 0 {
                            AppBadge(text: "\(summary.warning) Warning", style: .warning)
                        }
                    }

                    ForEach(visible) { item in
                        Button {
                            guard let runId = item.runId,
                                  let run = runDataSource.runs.first(where: { $0.id == runId }) else { return }
                            onOpenRunDetails(RunUIAdapter.mapToUIRun(run))
                        } label: {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: icon(for: item.severity))
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(color(for: item.severity))
                                    .frame(width: 16, height: 16)
                                Text(item.message)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(UIRunDesignSystem.textPrimary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(item.runId == nil)
                    }

                    if remaining > 0 {
                        Text("+\(remaining) more issues")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(UIRunDesignSystem.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
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

    private var emptyState: some View {
        UICard {
            VStack(alignment: .leading, spacing: 8) {
                Text("No runs for this day")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(UIRunDesignSystem.textPrimary)
                Text("Generate runs from schedules or choose another date.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(UIRunDesignSystem.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
        }
    }

    @ViewBuilder
    private func section(title: String, runs: [SystemDomain.RunInstance]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(title)
            if runs.isEmpty {
                Text("No runs")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(UIRunDesignSystem.textSecondary)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(runs) { run in
                        runCard(run)
                    }
                }
            }
        }
    }

    private func runCard(_ run: SystemDomain.RunInstance) -> some View {
        let isTerminal = run.status == .completed || run.status == .cancelled
        let hasConflict = conflictRunIDs.contains(run.id)
        let runAttention = runAttentionByRunID[run.id] ?? []
        let inlineFlags = inlineFlagBadges(for: run, runAttention: runAttention, hasConflict: hasConflict)
        let proximity = currentProximity(for: run)
        return UICard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(runTitle(run))
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(UIRunDesignSystem.textPrimary)
                        Text(formattedTime(run.date))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(UIRunDesignSystem.textSecondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        AppBadge(text: statusText(run.status), style: badgeStyle(for: run.status))
                        if let conflictFlag = inlineFlags.first(where: { $0.text == "Conflict" }) {
                            AppBadge(text: conflictFlag.text, style: conflictFlag.style)
                        }
                    }
                }

                Text("Driver: \(driverName(for: run))")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(UIRunDesignSystem.textPrimary)

                Text("Next stop: \(nextStopName(for: run))")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(UIRunDesignSystem.textSecondary)

                if run.status == .inProgress {
                    VStack(alignment: .leading, spacing: 4) {
                        if locationService.currentLocation != nil {
                            Text("Driver Location")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(UIRunDesignSystem.textSecondary)
                            Text("• Tracking active")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(UIRunDesignSystem.textPrimary)
                        } else {
                            Text("Location unavailable")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(UIRunDesignSystem.textSecondary)
                        }

                        if let proximity {
                            Text("Next Stop")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(UIRunDesignSystem.textSecondary)
                            Text("\(proximity.stopName)")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(UIRunDesignSystem.textPrimary)
                            Text("\(distanceText(proximity.distanceMeters)) away")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(UIRunDesignSystem.textPrimary)
                            if proximity.withinArrivalRadius {
                                AppBadge(text: "Near Stop", style: .success)
                            }
                        }

                        if let prediction = etaPrediction(for: run) {
                            Text("ETA")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(UIRunDesignSystem.textSecondary)
                            Text("\(prediction.nextStopName)")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(UIRunDesignSystem.textPrimary)
                            Text("ETA \(formattedTime(prediction.nextStopETA))")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(UIRunDesignSystem.textPrimary)
                            Text("ETA • \(confidenceHint(prediction.quality.confidence))")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(UIRunDesignSystem.textSecondary)
                        }
                    }
                    .padding(8)
                    .background(Color.black.opacity(0.03))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }

                HStack(spacing: 8) {
                    if !isTerminal {
                        Button(run.assignedDriverId == nil ? "Assign Driver" : "Change Driver") {
                            selectedRunForDriverPicker = SelectedRun(id: run.id)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(UIRunDesignSystem.primary)
                    }

                    Button("Open Run") {
                        onOpenRunDetails(RunUIAdapter.mapToUIRun(run))
                    }
                    .buttonStyle(.bordered)

                    if run.status == .inProgress {
                        Button("View Live") {
                            onOpenRunDetails(RunUIAdapter.mapToUIRun(run))
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(UIRunDesignSystem.primary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func runTitle(_ run: SystemDomain.RunInstance) -> String {
        let trimmed = run.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "Scheduled Run" : trimmed
    }

    private func driverName(for run: SystemDomain.RunInstance) -> String {
        let explicit = run.assignedDriverName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !explicit.isEmpty { return explicit }
        if let id = run.assignedDriverId,
           let driver = driverDataSource.drivers.first(where: { $0.id == id }) {
            return driver.name
        }
        return "Unassigned"
    }

    private func nextStopName(for run: SystemDomain.RunInstance) -> String {
        if let activeIndex = run.activeStopIndex, run.stops.indices.contains(activeIndex) {
            let activeStopId = run.stops[activeIndex].stopId
            if let snapshot = run.stopSnapshots.first(where: { $0.id == activeStopId }) {
                return snapshot.name
            }
        }
        if let nextPending = run.stops.first(where: { $0.status == .pending || $0.status == .enRoute }),
           let snapshot = run.stopSnapshots.first(where: { $0.id == nextPending.stopId }) {
            return snapshot.name
        }
        return run.stopSnapshots.last?.name ?? "No stops"
    }

    private func statusText(_ status: SystemDomain.RunStatus) -> String {
        switch status {
        case .scheduled: return "Scheduled"
        case .inProgress: return "In Progress"
        case .completed: return "Completed"
        case .cancelled: return "Cancelled"
        }
    }

    private func badgeStyle(for status: SystemDomain.RunStatus) -> BadgeStyle {
        switch status {
        case .scheduled: return .scheduled
        case .inProgress: return .enRoute
        case .completed: return .completed
        case .cancelled: return .cancelled
        }
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

    private func icon(for severity: AttentionSeverity) -> String {
        switch severity {
        case .critical:
            return "exclamationmark.triangle.fill"
        case .warning:
            return "exclamationmark.circle.fill"
        case .info:
            return "info.circle.fill"
        }
    }

    private func color(for severity: AttentionSeverity) -> Color {
        switch severity {
        case .critical:
            return Color.red
        case .warning:
            return Color.orange
        case .info:
            return Color.indigo
        }
    }

    private func inlineFlagBadges(
        for run: SystemDomain.RunInstance,
        runAttention: [AttentionItem],
        hasConflict: Bool
    ) -> [(text: String, style: BadgeStyle)] {
        var flags: [(String, BadgeStyle)] = []
        if runAttention.contains(where: { $0.type == .runOverdue }) {
            flags.append(("Overdue", .overdue))
        }
        if runAttention.contains(where: { $0.type == .driverMissing }) {
            flags.append(("Driver Required", .warning))
        }
        if hasConflict || runAttention.contains(where: { $0.type == .driverConflict }) {
            flags.append(("Conflict", .warning))
        }
        if runAttention.contains(where: { $0.type == .runStuck }) {
            flags.append(("Stuck", .warning))
        }
        return Array(flags.prefix(2))
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 20, weight: .bold))
            .foregroundStyle(UIRunDesignSystem.textPrimary)
    }

    private func currentProximity(for run: SystemDomain.RunInstance) -> RunProximity? {
        guard let location = locationService.currentLocation else { return nil }
        return runDataSource.proximityForRun(run.id, driverLocation: location)
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

    private func confidenceHint(_ confidence: ETAConfidenceLevel) -> String {
        switch confidence {
        case .high:
            return "High confidence"
        case .medium:
            return "Estimated"
        case .low:
            return "Low confidence"
        }
    }
}

#Preview {
    NavigationStack {
        DailyDispatchView { _ in }
            .environmentObject(RunDataSource())
            .environmentObject(DriverDataSource())
            .environmentObject(NotificationService())
    }
}
