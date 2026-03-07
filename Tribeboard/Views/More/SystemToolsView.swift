import SwiftUI
import CoreLocation

struct SystemToolsView: View {
    @EnvironmentObject private var runDataSource: RunDataSource
    @EnvironmentObject private var scheduleDataSource: ScheduleDataSource
    @EnvironmentObject private var driverDataSource: DriverDataSource
    @EnvironmentObject private var householdDataSource: HouseholdDataSource
    @EnvironmentObject private var householdContext: ActiveHouseholdContext
    @EnvironmentObject private var locationService: LocationReadinessService
    @EnvironmentObject private var notificationService: NotificationService
    @EnvironmentObject private var syncCoordinator: SyncCoordinator

    @State private var statusMessage: String?
    @State private var isBusy = false
    @State private var pendingNotificationIDs: [String] = []
    @State private var storeHealthReport = StoreHealthReporter().generate()
    @State private var exportedFiles: [URL] = []
    @State private var showResetAllConfirmation = false
    @State private var remoteMirrorCounts: RemoteMirrorCounts?
    @State private var syncDiagnostics: SyncDiagnosticsSnapshot?
    @StateObject private var etaSmoothingService = ETASmoothingService()

    var body: some View {
#if DEBUG
        ScrollView {
            VStack(spacing: 14) {
                storageCard
                countsCard
                storeHealthCard
                repositoryDiagnosticsCard
                performanceDiagnosticsCard
                householdsDebugCard
                exportDebugCard
                appReadyCheckCard
                driversDebugCard
                attentionDebugCard
                routeAdjustmentDebugCard
                etaDebugCard
                syncDebugCard
                syncAuditDebugCard
                navigationDebugCard
                liveTrackingDebugCard
                notificationsDebugCard
                actionsCard
                if let statusMessage {
                    statusCard(message: statusMessage)
                }
            }
            .padding(16)
        }
        .background(Color(red: 0.976, green: 0.980, blue: 0.984).ignoresSafeArea())
        .navigationTitle("System Tools")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await refreshCounts()
            await notificationService.refreshAuthorizationState()
            pendingNotificationIDs = await notificationService.pendingRequestIDs()
            storeHealthReport = StoreHealthReporter().generate()
        }
        .alert("Reset All Demo Data?", isPresented: $showResetAllConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                Task {
                    await runResetAllDemoData()
                }
            }
        } message: {
            Text("This clears runs, schedules, drivers, and pending notifications, then refreshes all data.")
        }
#else
        VStack(spacing: 12) {
            Image(systemName: "lock.fill")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("System Tools are unavailable in release builds.")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.976, green: 0.980, blue: 0.984).ignoresSafeArea())
        .navigationTitle("System Tools")
        .navigationBarTitleDisplayMode(.inline)
#endif
    }

    private var storageCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("JSON Storage")
                .font(.system(size: 16, weight: .bold))
            Text(JSONFileStore.debugStorageDirectory().path)
                .font(.system(size: 12, weight: .regular, design: .monospaced))
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
    }

    private var countsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Store Counts")
                .font(.system(size: 16, weight: .bold))
            countRow(title: "Runs", value: runDataSource.runs.count)
            countRow(title: "Templates", value: scheduleDataSource.templates.count)
            countRow(title: "Drivers", value: driverDataSource.totalDriversCount)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
    }

    private var actionsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Actions")
                .font(.system(size: 16, weight: .bold))

            actionButton("Seed demo schedules") {
                try await SystemBootstrap.seedDemoSchedules()
                await scheduleDataSource.refresh()
                await runDataSource.refresh()
                statusMessage = "Seeded demo schedules."
            }

            actionButton("Generate runs (14d)") {
                let generated = await scheduleDataSource.generateRuns(daysAhead: 14)
                await runDataSource.refresh()
                statusMessage = generated == 0 ? "No new runs generated." : "Generated \(generated) new runs."
            }

            actionButton("Generate 500 Demo Runs") {
                var generatedTotal = 0
                while generatedTotal < 500 {
                    let generated = await scheduleDataSource.generateRuns(daysAhead: 365)
                    await runDataSource.refresh()
                    if generated == 0 {
                        break
                    }
                    generatedTotal += generated
                }
                statusMessage = generatedTotal == 0
                    ? "No additional runs generated."
                    : "Generated \(generatedTotal) runs for stress testing."
            }

            actionButton("Clear runs", role: .destructive) {
                try await SystemBootstrap.clearAllRuns()
                await runDataSource.refresh()
                statusMessage = "Cleared all runs."
            }

            actionButton("Clear schedules", role: .destructive) {
                try await SystemBootstrap.clearAllSchedules()
                await scheduleDataSource.refresh()
                statusMessage = "Cleared all schedules."
            }

            actionButton("Clear drivers", role: .destructive) {
                await driverDataSource.clearDrivers()
                statusMessage = "Cleared all drivers."
            }

            actionButton("Clear pending notifications", role: .destructive) {
                await notificationService.removeAllPending()
                pendingNotificationIDs = await notificationService.pendingRequestIDs()
                statusMessage = "Cleared pending notifications."
            }

            actionButton("Reset All Demo Data", role: .destructive) {
                showResetAllConfirmation = true
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
    }

#if DEBUG
    private var repositoryDiagnosticsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Repository Diagnostics")
                .font(.system(size: 16, weight: .bold))
            countRow(title: "Run repository", value: runDataSource.diagnosticsRepositoryType)
            countRow(title: "Schedule repository", value: scheduleDataSource.diagnosticsRepositoryType)
            countRow(title: "Driver repository", value: driverDataSource.diagnosticsRepositoryType)
            countRow(title: "Run count", value: runDataSource.runs.count)
            countRow(title: "Schedule count", value: scheduleDataSource.templates.count)
            countRow(title: "Driver count", value: driverDataSource.totalDriversCount)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
    }

    private var householdsDebugCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Households")
                .font(.system(size: 16, weight: .bold))
            countRow(title: "Total households", value: householdDataSource.households.count)
            countRow(title: "Active household", value: householdContext.householdName)
            countRow(title: "Household ID", value: householdContext.householdId.uuidString)

            actionButton("Create Demo Household") {
                let demoName = "Demo Household \(householdDataSource.households.count + 1)"
                await householdDataSource.createHousehold(name: demoName)
                if let error = householdDataSource.lastError {
                    statusMessage = error
                } else {
                    statusMessage = "Created and switched to \(demoName)."
                }
            }

            actionButton("Switch to Default Household") {
                await householdDataSource.switchHousehold(id: HouseholdDefaults.defaultHouseholdId)
                if let error = householdDataSource.lastError {
                    statusMessage = error
                } else {
                    statusMessage = "Switched to default household."
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
    }

    private var performanceDiagnosticsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Performance")
                .font(.system(size: 16, weight: .bold))
            countRow(title: "Run count", value: runDataSource.runs.count)
            countRow(title: "Schedule count", value: scheduleDataSource.templates.count)
            countRow(title: "Driver count", value: driverDataSource.totalDriversCount)
            countRow(title: "Active ETA computations", value: runDataSource.diagnosticsActiveETAComputations)
            countRow(title: "Speed sample count", value: locationService.speedSampleCount)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
    }

    private var storeHealthCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Store Health")
                .font(.system(size: 16, weight: .bold))
            ForEach(storeHealthReport.entries) { entry in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(entry.fileName)
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        Spacer()
                        Text(entry.fileExists ? "Present" : "Missing")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(entry.fileExists ? .green : .secondary)
                    }
                    Text("Size: \(entry.sizeBytes) B • Schema: \(entry.schemaVersionSeen.map(String.init) ?? "n/a") • Corrupt backups: \(entry.corruptBackupCount)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    if let modified = entry.lastModified {
                        Text("Modified: \(modified.formatted(date: .abbreviated, time: .shortened))")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
    }

    private var exportDebugCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Data Export")
                .font(.system(size: 16, weight: .bold))

            actionButton("Export Runs JSON") {
                try runExport(options: .init(includeRuns: true, includeSchedules: false, includeDrivers: false))
            }

            actionButton("Export Schedules JSON") {
                try runExport(options: .init(includeRuns: false, includeSchedules: true, includeDrivers: false))
            }

            actionButton("Export Drivers JSON") {
                try runExport(options: .init(includeRuns: false, includeSchedules: false, includeDrivers: true))
            }

            actionButton("Export All JSON") {
                try runExport(options: .init(includeRuns: true, includeSchedules: true, includeDrivers: true))
            }

            if let directory = exportedFiles.first?.deletingLastPathComponent() {
                ShareLink(item: directory) {
                    Label("Share Last Export Folder", systemImage: "square.and.arrow.up")
                        .font(.system(size: 13, weight: .semibold))
                }
            }

            Text("Import not supported yet.")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
    }

    private var appReadyCheckCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("App Ready Check")
                .font(.system(size: 16, weight: .bold))
            countRow(title: "Location auth", value: locationService.authorizationState.rawValue)
            countRow(title: "Notification auth", value: notificationService.authorizationState.rawValue)
            countRow(title: "Run count", value: runDataSource.runs.count)
            countRow(title: "Schedule count", value: scheduleDataSource.templates.count)
            countRow(title: "Driver count", value: driverDataSource.totalDriversCount)
            countRow(title: "Active runs", value: runDataSource.runs.filter { $0.status == .inProgress }.count)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
    }

    private var driversDebugCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Drivers")
                .font(.system(size: 16, weight: .bold))
            countRow(title: "Active drivers", value: driverDataSource.activeDriversCount)
            countRow(title: "Total drivers", value: driverDataSource.totalDriversCount)

            actionButton("Seed Demo Drivers") {
                let beforeTotal = driverDataSource.totalDriversCount
                await driverDataSource.seedDemoDrivers()
                let added = max(0, driverDataSource.totalDriversCount - beforeTotal)
                statusMessage = added == 0
                    ? "Demo drivers already seeded."
                    : "Seeded demo drivers (\(added) added)."
            }

            actionButton("Clear Drivers", role: .destructive) {
                let cleared = driverDataSource.totalDriversCount
                await driverDataSource.clearDrivers()
                statusMessage = "Cleared drivers (\(cleared) removed)."
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
    }

    private var attentionDebugCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Attention Simulations")
                .font(.system(size: 16, weight: .bold))

            actionButton("Simulate Missing Driver Alerts") {
                statusMessage = await runDataSource.simulateMissingDriverAlerts()
            }

            actionButton("Simulate Overdue Alerts") {
                statusMessage = await runDataSource.simulateOverdueAlerts()
            }

            actionButton("Simulate Conflict Alerts") {
                statusMessage = await runDataSource.simulateConflictAlerts()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
    }

    private var routeAdjustmentDebugCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Route Adjustment")
                .font(.system(size: 16, weight: .bold))

            if let activeRun = runDataSource.runs.first(where: { $0.status == .inProgress }) {
                countRow(title: "Active run", value: activeRun.id.uuidString)

                actionButton("Add Demo Stop To Active Run") {
                    await runDataSource.insertStop(
                        runId: activeRun.id,
                        stopName: "Demo Adjustment Stop",
                        latitude: -17.8120,
                        longitude: 31.0460
                    )
                    statusMessage = runDataSource.lastError ?? "Added demo stop to active run."
                }

                actionButton("Defer Next Stop") {
                    guard let index = nextFutureStopIndex(for: activeRun) else {
                        statusMessage = "No future stop available to defer."
                        return
                    }
                    await runDataSource.deferStop(runId: activeRun.id, index: index)
                    statusMessage = runDataSource.lastError ?? "Deferred next stop."
                }

                actionButton("Remove Last Future Stop", role: .destructive) {
                    guard let index = lastRemovableFutureStopIndex(for: activeRun) else {
                        statusMessage = "No removable future stop available."
                        return
                    }
                    await runDataSource.removeStop(runId: activeRun.id, index: index)
                    statusMessage = runDataSource.lastError ?? "Removed last future stop."
                }
            } else {
                Text("Start a run to enable active-run route adjustment tools.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
    }

    private var etaDebugCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ETA Quality")
                .font(.system(size: 16, weight: .bold))
            countRow(
                title: "Estimated speed",
                value: locationService.estimatedSpeedMetersPerSecond.map { String(format: "%.1f m/s", $0) } ?? "n/a"
            )
            countRow(title: "Sample count", value: locationService.speedSampleCount)
            countRow(
                title: "Speed variance",
                value: locationService.speedVariance.map { String(format: "%.2f", $0) } ?? "n/a"
            )
            if let prediction = activeETAPrediction() {
                countRow(title: "Next stop", value: prediction.nextStopName)
                countRow(title: "Next ETA", value: prediction.nextStopETA.formatted(date: .omitted, time: .shortened))
                countRow(title: "Final ETA", value: prediction.finalStopETA.formatted(date: .omitted, time: .shortened))
                countRow(title: "Minutes remaining", value: "\(prediction.estimatedMinutesRemaining)")
                countRow(title: "Confidence", value: prediction.quality.confidence.rawValue.capitalized)
                countRow(title: "Reason", value: prediction.quality.reason)
            } else {
                Text("No active ETA available.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            actionButton("Reset Speed Estimator") {
                locationService.resetSpeedEstimate()
                statusMessage = "Reset speed estimator."
            }

            actionButton("Reset ETA Smoothing") {
                etaSmoothingService.clearAll()
                statusMessage = "Reset ETA smoothing."
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
    }

    private var syncDebugCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Sync")
                .font(.system(size: 16, weight: .bold))
            countRow(title: "State", value: syncCoordinator.status.state.rawValue.capitalized)
            countRow(title: "Pending count", value: syncCoordinator.status.pendingCount)
            countRow(
                title: "Last sync",
                value: syncCoordinator.status.lastSyncAt?.formatted(date: .abbreviated, time: .shortened) ?? "n/a"
            )
            countRow(title: "Remote runs", value: remoteMirrorCounts?.runs ?? 0)
            countRow(title: "Remote schedules", value: remoteMirrorCounts?.schedules ?? 0)
            countRow(title: "Remote drivers", value: remoteMirrorCounts?.drivers ?? 0)
            countRow(title: "Remote households", value: remoteMirrorCounts?.households ?? 0)
            countRow(title: "Remote changes", value: remoteMirrorCounts?.changes ?? 0)
            if let error = syncCoordinator.status.lastError, !error.isEmpty {
                Text(error)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.red)
            }

            actionButton("Refresh Sync Status") {
                await syncCoordinator.refreshStatus()
                statusMessage = "Sync status refreshed."
            }

            actionButton("Push Queue Now") {
                await syncCoordinator.processQueue()
                statusMessage = "Push complete."
            }

            actionButton("Pull Remote Now") {
                await syncCoordinator.pull(householdId: householdContext.householdId)
                await householdDataSource.refresh()
                await runDataSource.reloadForHouseholdChange()
                await scheduleDataSource.reloadForHouseholdChange()
                await driverDataSource.reloadForHouseholdChange()
                statusMessage = "Pulled remote changes."
            }

            actionButton("Clear Sync Queue", role: .destructive) {
                await syncCoordinator.clearQueue()
                statusMessage = "Cleared sync queue."
            }

            actionButton("Seed Remote Mirror Demo Data") {
                await syncCoordinator.seedRemoteMirrorDemoData(for: householdContext.householdId)
                statusMessage = "Seeded remote mirror demo data."
            }

            actionButton("Clear Remote Mirror", role: .destructive) {
                await syncCoordinator.clearRemoteMirror()
                statusMessage = "Cleared remote mirror."
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
    }

    private var syncAuditDebugCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Sync Validation Toolkit")
                .font(.system(size: 16, weight: .bold))
            countRow(title: "Sync state", value: syncCoordinator.status.state.rawValue.capitalized)
            countRow(title: "Pending queue count", value: syncCoordinator.status.pendingCount)
            countRow(title: "Audit records", value: syncDiagnostics?.auditRecordCount ?? 0)
            countRow(title: "Processed changes", value: syncDiagnostics?.processedChangeCount ?? 0)
            countRow(title: "Conflicts", value: syncDiagnostics?.conflictCount ?? 0)

            if let entries = syncDiagnostics?.latestAuditRecords, !entries.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(entries.prefix(5), id: \.id) { entry in
                        Text("\(entry.direction.rawValue.uppercased()) • \(entry.result.rawValue.uppercased()) • \(entry.message)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 4)
            }

            actionButton("Push Queue Now") {
                await syncCoordinator.processQueue()
                statusMessage = "Push complete."
            }

            actionButton("Pull Remote Now") {
                await syncCoordinator.pull(householdId: householdContext.householdId)
                await householdDataSource.refresh()
                await runDataSource.reloadForHouseholdChange()
                await scheduleDataSource.reloadForHouseholdChange()
                await driverDataSource.reloadForHouseholdChange()
                statusMessage = "Pulled remote changes."
            }

            actionButton("Seed Duplicate Remote Change") {
                await syncCoordinator.seedDuplicateRemoteChange(for: householdContext.householdId)
                statusMessage = "Seeded duplicate remote change."
            }

            actionButton("Seed Stale Remote Change") {
                await syncCoordinator.seedStaleRemoteChange(for: householdContext.householdId)
                statusMessage = "Seeded stale remote change."
            }

            actionButton("Seed Newer Remote Change") {
                await syncCoordinator.seedNewerRemoteChange(for: householdContext.householdId)
                statusMessage = "Seeded newer remote change."
            }

            actionButton("Refresh Sync Diagnostics") {
                syncDiagnostics = await syncCoordinator.syncDiagnostics(limit: 5)
                statusMessage = "Sync diagnostics refreshed."
            }

            actionButton("Clear Audit Log", role: .destructive) {
                await syncCoordinator.clearSyncAudit()
                syncDiagnostics = await syncCoordinator.syncDiagnostics(limit: 5)
                statusMessage = "Cleared sync audit log."
            }

            actionButton("Clear Processed Change Log", role: .destructive) {
                await syncCoordinator.clearProcessedChangeLog()
                syncDiagnostics = await syncCoordinator.syncDiagnostics(limit: 5)
                statusMessage = "Cleared processed change log."
            }

            actionButton("Corrupt sync_audit.json", role: .destructive) {
                await syncCoordinator.corruptSyncAuditFile()
                statusMessage = "Corrupted sync_audit.json."
            }

            actionButton("Corrupt processed_sync_changes.json", role: .destructive) {
                await syncCoordinator.corruptProcessedChangeFile()
                statusMessage = "Corrupted processed_sync_changes.json."
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
    }

    private var navigationDebugCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Navigation & Location")
                .font(.system(size: 16, weight: .bold))

            NavigationLink(value: Destination.driverModeSelector) {
                HStack {
                    Text("Open Driver Mode")
                        .font(.system(size: 14, weight: .semibold))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(Color.indigo)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 42)
                .padding(.horizontal, 12)
                .background(Color.indigo.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)

            if let activeRun = runDataSource.runs.first(where: { $0.status == .inProgress }) {
                NavigationLink(value: Destination.runDetails(runId: activeRun.id.uuidString)) {
                    HStack {
                        Text("Open Map Test Run")
                            .font(.system(size: 14, weight: .semibold))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(Color.indigo)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 42)
                    .padding(.horizontal, 12)
                    .background(Color.indigo.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            actionButton("Request Location Permission") {
                locationService.requestWhenInUseAccess()
                statusMessage = "Requested when-in-use location permission."
            }

            actionButton("Open Apple Maps Test Stop") {
                openTestNavigation(.appleMaps)
            }

            if ExternalNavigationService.canOpen(.googleMaps) {
                actionButton("Open Google Maps Test Stop") {
                    openTestNavigation(.googleMaps)
                }
            }

            if ExternalNavigationService.canOpen(.waze) {
                actionButton("Open Waze Test Stop") {
                    openTestNavigation(.waze)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
    }

    private var liveTrackingDebugCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Live Tracking")
                .font(.system(size: 16, weight: .bold))

            actionButton("Simulate Location Near Stop") {
                let coordinate = firstKnownStopCoordinate()
                locationService.simulateLocation(
                    latitude: coordinate.latitude + 0.0002,
                    longitude: coordinate.longitude + 0.0002
                )
                statusMessage = "Simulated location near stop."
            }

            actionButton("Simulate Location Far From Stop") {
                let coordinate = firstKnownStopCoordinate()
                locationService.simulateLocation(
                    latitude: coordinate.latitude + 0.03,
                    longitude: coordinate.longitude + 0.03
                )
                statusMessage = "Simulated location far from stop."
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
    }

    private var notificationsDebugCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Notifications")
                .font(.system(size: 16, weight: .bold))
            countRow(title: "Authorization", value: notificationService.authorizationState.rawValue.capitalized)
            countRow(title: "Pending count", value: "\(pendingNotificationIDs.count)")

            actionButton("Request Notification Permission") {
                let granted = await notificationService.requestAuthorization()
                pendingNotificationIDs = await notificationService.pendingRequestIDs()
                statusMessage = granted ? "Notification permission granted." : "Notification permission not granted."
            }

            actionButton("Show Pending Notification IDs") {
                pendingNotificationIDs = await notificationService.pendingRequestIDs()
                if pendingNotificationIDs.isEmpty {
                    statusMessage = "No pending notification IDs."
                } else {
                    statusMessage = "Pending IDs: \(pendingNotificationIDs.joined(separator: ", "))"
                }
            }

            actionButton("Clear Pending Notifications", role: .destructive) {
                await notificationService.removeAllPending()
                pendingNotificationIDs = await notificationService.pendingRequestIDs()
                statusMessage = "Cleared pending notifications."
            }

            actionButton("Reconcile Notifications Now") {
                await runDataSource.reconcileNotifications(notificationService: notificationService)
                pendingNotificationIDs = await notificationService.pendingRequestIDs()
                statusMessage = "Reconciled notifications."
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
    }
#endif

    private func statusCard(message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(Color.indigo)
            Text(message)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.primary)
            Spacer()
        }
        .padding(12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
    }

    private func countRow(title: String, value: Int) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(value)")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.primary)
        }
    }

    private func countRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.primary)
        }
    }

    private func actionButton(
        _ title: String,
        role: ButtonRole? = nil,
        action: @escaping () async throws -> Void
    ) -> some View {
        Button(role: role) {
            Task {
                guard !isBusy else { return }
                isBusy = true
                defer { isBusy = false }
                do {
                    try await action()
                    await refreshCounts()
                } catch {
                    statusMessage = "Action failed: \(error.localizedDescription)"
                }
            }
        } label: {
            HStack {
                if isBusy {
                    ProgressView()
                        .tint(.white)
                }
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(role == .destructive ? Color.red : Color.indigo)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isBusy)
        .opacity(isBusy ? 0.7 : 1)
    }

    private func refreshCounts() async {
        await householdDataSource.refresh()
        await scheduleDataSource.refresh()
        await runDataSource.refresh()
        await driverDataSource.refresh()
        await notificationService.refreshAuthorizationState()
        pendingNotificationIDs = await notificationService.pendingRequestIDs()
        await syncCoordinator.refreshStatus()
        remoteMirrorCounts = await syncCoordinator.remoteMirrorCounts()
        syncDiagnostics = await syncCoordinator.syncDiagnostics(limit: 5)
        storeHealthReport = StoreHealthReporter().generate()
    }

    private func openTestNavigation(_ app: NavigationApp) {
        let testStopName = "Tribeboard Test Stop"
        let testLatitude = -17.8252
        let testLongitude = 31.0335
        ExternalNavigationService.open(
            app: app,
            destinationName: testStopName,
            latitude: testLatitude,
            longitude: testLongitude
        )
        statusMessage = "Opened \(app.rawValue) test navigation."
    }

    private func firstKnownStopCoordinate() -> CLLocationCoordinate2D {
        if let stop = runDataSource.runs
            .flatMap(\.stopSnapshots)
            .sorted(by: { $0.order < $1.order })
            .first {
            return CLLocationCoordinate2D(latitude: stop.latitude, longitude: stop.longitude)
        }
        return CLLocationCoordinate2D(latitude: -17.8252, longitude: 31.0335)
    }

    private func runResetAllDemoData() async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }

        do {
            try await SystemBootstrap.clearAllRuns()
            try await SystemBootstrap.clearAllSchedules()
            await driverDataSource.clearDrivers()
            await notificationService.removeAllPending()

#if DEBUG
            if AppConfig.isDemoFlowEnabled {
                try await SystemBootstrap.seedDemoSchedules()
                await driverDataSource.seedDemoDrivers()
            }
#endif
            await refreshCounts()
            statusMessage = "Reset complete. Data cleared and refreshed."
        } catch {
            statusMessage = "Reset failed: \(error.localizedDescription)"
        }
    }

    private func runExport(options: JSONExportService.ExportOptions) throws {
        let result = try JSONExportService().export(options: options)
        exportedFiles = result.exportedFiles
        let names = result.exportedFiles.map(\.lastPathComponent).joined(separator: ", ")
        statusMessage = result.exportedFiles.isEmpty
            ? "No JSON files were found to export."
            : "Exported: \(names)"
    }

    private func nextFutureStopIndex(for run: SystemDomain.RunInstance) -> Int? {
        guard let active = run.activeStopIndex else { return nil }
        let start = max(0, active + 1)
        return run.stops.indices.first { index in
            index >= start && run.stops[index].status != .completed
        }
    }

    private func lastRemovableFutureStopIndex(for run: SystemDomain.RunInstance) -> Int? {
        guard let active = run.activeStopIndex else { return nil }
        let start = max(0, active + 1)
        guard run.stops.count > 1 else { return nil }
        return run.stops.indices.reversed().first { index in
            index >= start && run.stops[index].status != .completed
        }
    }

    private func activeETAPrediction() -> ETAPrediction? {
        guard let run = runDataSource.runs.first(where: { $0.status == .inProgress }),
              let location = locationService.currentLocation else {
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
}

#Preview {
    NavigationStack {
        SystemToolsView()
            .environmentObject(RunDataSource())
            .environmentObject(ScheduleDataSource())
            .environmentObject(DriverDataSource())
            .environmentObject(
                HouseholdDataSource(
                    repository: LocalHouseholdRepository(),
                    activeContext: ActiveHouseholdContext()
                )
            )
            .environmentObject(ActiveHouseholdContext())
            .environmentObject(LocationReadinessService())
            .environmentObject(NotificationService())
            .environmentObject(SyncCoordinator(queueRepository: LocalSyncQueueRepository()))
    }
}
