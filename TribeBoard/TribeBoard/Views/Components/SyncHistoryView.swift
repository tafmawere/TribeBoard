import SwiftUI
import SwiftData

/// View for displaying sync history and error logs
struct SyncHistoryView: View {
    let userId: UUID
    let modelContext: ModelContext
    
    @State private var syncLogs: [SyncLogEntry] = []
    @State private var isLoading = true
    @State private var selectedTimeRange: TimeRange = .lastWeek
    @State private var showingErrorDetails = false
    @State private var selectedError: SyncLogEntry?
    
    enum TimeRange: String, CaseIterable {
        case lastDay = "Last 24 Hours"
        case lastWeek = "Last Week"
        case lastMonth = "Last Month"
        case all = "All Time"
        
        var dateRange: DateInterval {
            let now = Date()
            let calendar = Calendar.current
            
            switch self {
            case .lastDay:
                let start = calendar.date(byAdding: .day, value: -1, to: now) ?? now
                return DateInterval(start: start, end: now)
            case .lastWeek:
                let start = calendar.date(byAdding: .weekOfYear, value: -1, to: now) ?? now
                return DateInterval(start: start, end: now)
            case .lastMonth:
                let start = calendar.date(byAdding: .month, value: -1, to: now) ?? now
                return DateInterval(start: start, end: now)
            case .all:
                return DateInterval(start: Date.distantPast, end: now)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView("Loading sync history...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    content
                }
            }
            .navigationTitle("Sync History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        // Dismiss handled by parent
                    }
                }
            }
            .onAppear {
                Task {
                    await loadSyncHistory()
                }
            }
        }
    }
    
    private var content: some View {
        VStack(spacing: 0) {
            // Time range picker
            Picker("Time Range", selection: $selectedTimeRange) {
                ForEach(TimeRange.allCases, id: \.self) { range in
                    Text(range.rawValue).tag(range)
                }
            }
            .pickerStyle(.segmented)
            .padding()
            .onChange(of: selectedTimeRange) { _, _ in
                Task {
                    await loadSyncHistory()
                }
            }
            
            // Sync statistics
            syncStatisticsView
            
            Divider()
            
            // Sync log list
            if syncLogs.isEmpty {
                emptyStateView
            } else {
                syncLogList
            }
        }
        .sheet(item: $selectedError) { error in
            SyncErrorDetailView(logEntry: error)
        }
    }
    
    private var syncStatisticsView: some View {
        VStack(spacing: 12) {
            HStack(spacing: 20) {
                StatisticView(
                    title: "Total Syncs",
                    value: "\(syncLogs.count)",
                    color: .blue
                )
                
                StatisticView(
                    title: "Successful",
                    value: "\(successfulSyncs)",
                    color: .green
                )
                
                StatisticView(
                    title: "Failed",
                    value: "\(failedSyncs)",
                    color: .red
                )
            }
            
            if !syncLogs.isEmpty {
                HStack {
                    Text("Success Rate:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(successRate, specifier: "%.1f")%")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(successRate >= 90 ? .green : successRate >= 70 ? .orange : .red)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No Sync History")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Sync history will appear here once you start syncing with Apple Calendar.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var syncLogList: some View {
        List {
            ForEach(groupedSyncLogs.keys.sorted(by: >), id: \.self) { date in
                Section(header: Text(formatSectionDate(date))) {
                    ForEach(groupedSyncLogs[date] ?? []) { logEntry in
                        SyncLogRowView(logEntry: logEntry) {
                            if logEntry.isError {
                                selectedError = logEntry
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
    
    // MARK: - Helper Methods
    
    private func loadSyncHistory() async {
        isLoading = true
        
        // Simulate loading sync history from Core Data or UserDefaults
        // In a real implementation, this would fetch from a SyncLog model
        await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        syncLogs = generateMockSyncLogs()
        isLoading = false
    }
    
    private func generateMockSyncLogs() -> [SyncLogEntry] {
        let dateRange = selectedTimeRange.dateRange
        var logs: [SyncLogEntry] = []
        
        let calendar = Calendar.current
        var currentDate = dateRange.end
        
        // Generate mock sync entries
        while currentDate > dateRange.start && logs.count < 50 {
            // Randomly decide if there should be a sync entry for this time
            if Bool.random() {
                let isSuccess = Double.random(in: 0...1) > 0.15 // 85% success rate
                
                let log = SyncLogEntry(
                    id: UUID(),
                    timestamp: currentDate,
                    operation: SyncLogOperation.allCases.randomElement() ?? .fullSync,
                    isSuccess: isSuccess,
                    duration: TimeInterval.random(in: 0.5...5.0),
                    eventsProcessed: isSuccess ? Int.random(in: 0...20) : 0,
                    errorMessage: isSuccess ? nil : generateMockError(),
                    details: isSuccess ? "Sync completed successfully" : nil
                )
                
                logs.append(log)
            }
            
            // Move back in time
            currentDate = calendar.date(byAdding: .hour, value: -Int.random(in: 1...6), to: currentDate) ?? currentDate
        }
        
        return logs.sorted { $0.timestamp > $1.timestamp }
    }
    
    private func generateMockError() -> String {
        let errors = [
            "Network connection lost during sync",
            "EventKit permission denied",
            "Calendar not found in Apple Calendar",
            "Sync conflict detected",
            "Rate limit exceeded",
            "Invalid event data",
            "CloudKit sync failed"
        ]
        return errors.randomElement() ?? "Unknown error"
    }
    
    private var groupedSyncLogs: [Date: [SyncLogEntry]] {
        Dictionary(grouping: syncLogs) { log in
            Calendar.current.startOfDay(for: log.timestamp)
        }
    }
    
    private var successfulSyncs: Int {
        syncLogs.filter { $0.isSuccess }.count
    }
    
    private var failedSyncs: Int {
        syncLogs.filter { !$0.isSuccess }.count
    }
    
    private var successRate: Double {
        guard !syncLogs.isEmpty else { return 0 }
        return Double(successfulSyncs) / Double(syncLogs.count) * 100
    }
    
    private func formatSectionDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        
        if Calendar.current.isDateInToday(date) {
            return "Today"
        } else if Calendar.current.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            formatter.dateStyle = .medium
            return formatter.string(from: date)
        }
    }
}

// MARK: - Supporting Views

struct StatisticView: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct SyncLogRowView: View {
    let logEntry: SyncLogEntry
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                // Status icon
                Image(systemName: logEntry.isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(logEntry.isSuccess ? .green : .red)
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(logEntry.operation.displayName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Text(logEntry.timestamp, style: .time)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if logEntry.isSuccess {
                        HStack {
                            Text("\(logEntry.eventsProcessed) events")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Text("\(logEntry.duration, specifier: "%.1f")s")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text(logEntry.errorMessage ?? "Unknown error")
                            .font(.caption)
                            .foregroundColor(.red)
                            .lineLimit(1)
                    }
                }
                
                if logEntry.isError {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Sync Error Detail View

struct SyncErrorDetailView: View {
    let logEntry: SyncLogEntry
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Error summary
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Error Summary")
                            .font(.headline)
                        
                        Text(logEntry.errorMessage ?? "Unknown error occurred")
                            .font(.body)
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                    }
                    
                    // Sync details
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Sync Details")
                            .font(.headline)
                        
                        DetailRow(label: "Operation", value: logEntry.operation.displayName)
                        DetailRow(label: "Timestamp", value: formatDetailDate(logEntry.timestamp))
                        DetailRow(label: "Duration", value: "\(logEntry.duration, specifier: "%.2f") seconds")
                        DetailRow(label: "Events Processed", value: "\(logEntry.eventsProcessed)")
                    }
                    
                    // Troubleshooting tips
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Troubleshooting Tips")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("• Check your internet connection")
                            Text("• Verify calendar permissions in Settings")
                            Text("• Try syncing again in a few minutes")
                            Text("• Contact support if the issue persists")
                        }
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Sync Error")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func formatDetailDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Supporting Models

struct SyncLogEntry: Identifiable {
    let id: UUID
    let timestamp: Date
    let operation: SyncLogOperation
    let isSuccess: Bool
    let duration: TimeInterval
    let eventsProcessed: Int
    let errorMessage: String?
    let details: String?
    
    var isError: Bool {
        !isSuccess
    }
}

enum SyncLogOperation: String, CaseIterable {
    case fullSync = "full_sync"
    case incrementalSync = "incremental_sync"
    case eventCreate = "event_create"
    case eventUpdate = "event_update"
    case eventDelete = "event_delete"
    case conflictResolution = "conflict_resolution"
    
    var displayName: String {
        switch self {
        case .fullSync:
            return "Full Sync"
        case .incrementalSync:
            return "Incremental Sync"
        case .eventCreate:
            return "Event Created"
        case .eventUpdate:
            return "Event Updated"
        case .eventDelete:
            return "Event Delete"
        case .conflictResolution:
            return "Conflict Resolution"
        }
    }
}

// MARK: - Preview

#Preview {
    SyncHistoryView(
        userId: UUID(),
        modelContext: try! ModelContainerConfiguration.createInMemory().mainContext
    )
}