import SwiftUI
import Foundation

/// Bug tracking and resolution system for calendar features
class CalendarBugTracker {
    static let shared = CalendarBugTracker()
    
    @Published var knownIssues: [CalendarBug] = []
    @Published var resolvedIssues: [CalendarBug] = []
    
    private init() {
        loadKnownIssues()
    }
    
    // MARK: - Known Issues Management
    
    private func loadKnownIssues() {
        knownIssues = [
            CalendarBug(
                id: "CAL-001",
                title: "Event sync delay with Apple Calendar",
                description: "Events may take up to 30 seconds to sync with Apple Calendar",
                severity: .medium,
                category: .sync,
                status: .known,
                workaround: "Use manual sync button for immediate synchronization",
                affectedVersions: ["1.0.0"],
                reportedDate: Date().addingTimeInterval(-86400 * 7) // 7 days ago
            ),
            
            CalendarBug(
                id: "CAL-002",
                title: "VoiceOver navigation in calendar grid",
                description: "VoiceOver users may experience difficulty navigating the calendar grid",
                severity: .high,
                category: .accessibility,
                status: .inProgress,
                workaround: "Use list view for better accessibility",
                affectedVersions: ["1.0.0"],
                reportedDate: Date().addingTimeInterval(-86400 * 5) // 5 days ago
            ),
            
            CalendarBug(
                id: "CAL-003",
                title: "All-day events display incorrectly in different time zones",
                description: "All-day events may show incorrect dates when user changes time zones",
                severity: .medium,
                category: .dateTime,
                status: .investigating,
                workaround: "Refresh calendar after changing time zones",
                affectedVersions: ["1.0.0"],
                reportedDate: Date().addingTimeInterval(-86400 * 3) // 3 days ago
            ),
            
            CalendarBug(
                id: "CAL-004",
                title: "Family event permissions not updating immediately",
                description: "Changes to family event permissions may not reflect immediately for all users",
                severity: .low,
                category: .permissions,
                status: .known,
                workaround: "Sign out and sign back in to refresh permissions",
                affectedVersions: ["1.0.0"],
                reportedDate: Date().addingTimeInterval(-86400 * 2) // 2 days ago
            ),
            
            CalendarBug(
                id: "CAL-005",
                title: "Calendar widget not updating in background",
                description: "Calendar widget may show stale data when app is backgrounded",
                severity: .low,
                category: .widget,
                status: .resolved,
                workaround: "Open app to refresh widget data",
                affectedVersions: ["1.0.0"],
                reportedDate: Date().addingTimeInterval(-86400 * 10), // 10 days ago
                resolvedDate: Date().addingTimeInterval(-86400 * 1) // 1 day ago
            )
        ]
        
        // Separate resolved issues
        resolvedIssues = knownIssues.filter { $0.status == .resolved }
        knownIssues = knownIssues.filter { $0.status != .resolved }
    }
    
    // MARK: - Bug Reporting
    
    func reportBug(_ bug: CalendarBug) {
        knownIssues.append(bug)
        
        // In a real app, this would send to a bug tracking system
        print("🐛 New bug reported: \(bug.title)")
    }
    
    func updateBugStatus(_ bugId: String, status: CalendarBugStatus) {
        if let index = knownIssues.firstIndex(where: { $0.id == bugId }) {
            knownIssues[index].status = status
            
            if status == .resolved {
                knownIssues[index].resolvedDate = Date()
                let resolvedBug = knownIssues.remove(at: index)
                resolvedIssues.append(resolvedBug)
            }
        }
    }
    
    // MARK: - Bug Analysis
    
    func getBugsByCategory(_ category: CalendarBugCategory) -> [CalendarBug] {
        return knownIssues.filter { $0.category == category }
    }
    
    func getBugsBySeverity(_ severity: CalendarBugSeverity) -> [CalendarBug] {
        return knownIssues.filter { $0.severity == severity }
    }
    
    func getCriticalBugs() -> [CalendarBug] {
        return knownIssues.filter { $0.severity == .critical }
    }
    
    func getHighPriorityBugs() -> [CalendarBug] {
        return knownIssues.filter { $0.severity == .high || $0.severity == .critical }
    }
    
    // MARK: - Automated Bug Detection
    
    func runAutomatedBugDetection() async -> [CalendarBug] {
        var detectedBugs: [CalendarBug] = []
        
        // Check for common issues
        detectedBugs.append(contentsOf: await checkSyncIssues())
        detectedBugs.append(contentsOf: await checkPerformanceIssues())
        detectedBugs.append(contentsOf: await checkDataIntegrityIssues())
        
        return detectedBugs
    }
    
    private func checkSyncIssues() async -> [CalendarBug] {
        var issues: [CalendarBug] = []
        
        // Check if sync is taking too long
        let startTime = Date()
        do {
            try await CalendarService().syncWithAppleCalendar()
            let syncDuration = Date().timeIntervalSince(startTime)
            
            if syncDuration > 10.0 {
                issues.append(CalendarBug(
                    id: "AUTO-SYNC-\(UUID().uuidString.prefix(8))",
                    title: "Slow sync performance detected",
                    description: "Calendar sync took \(String(format: "%.1f", syncDuration)) seconds",
                    severity: .medium,
                    category: .sync,
                    status: .new,
                    workaround: "Check network connection and try again",
                    affectedVersions: ["Current"],
                    reportedDate: Date()
                ))
            }
        } catch {
            issues.append(CalendarBug(
                id: "AUTO-SYNC-ERROR-\(UUID().uuidString.prefix(8))",
                title: "Sync failure detected",
                description: "Calendar sync failed: \(error.localizedDescription)",
                severity: .high,
                category: .sync,
                status: .new,
                workaround: "Check calendar permissions and network connection",
                affectedVersions: ["Current"],
                reportedDate: Date()
            ))
        }
        
        return issues
    }
    
    private func checkPerformanceIssues() async -> [CalendarBug] {
        var issues: [CalendarBug] = []
        
        // Check event loading performance
        let startTime = Date()
        do {
            let dateRange = DateInterval(start: Date(), end: Date().addingTimeInterval(86400 * 30))
            _ = try await CalendarService().fetchEvents(for: dateRange)
            let loadDuration = Date().timeIntervalSince(startTime)
            
            if loadDuration > 3.0 {
                issues.append(CalendarBug(
                    id: "AUTO-PERF-\(UUID().uuidString.prefix(8))",
                    title: "Slow event loading detected",
                    description: "Event loading took \(String(format: "%.1f", loadDuration)) seconds",
                    severity: .medium,
                    category: .performance,
                    status: .new,
                    workaround: "Reduce date range or clear calendar cache",
                    affectedVersions: ["Current"],
                    reportedDate: Date()
                ))
            }
        } catch {
            // Loading error already handled elsewhere
        }
        
        return issues
    }
    
    private func checkDataIntegrityIssues() async -> [CalendarBug] {
        var issues: [CalendarBug] = []
        
        // Check for events with invalid date ranges
        do {
            let dateRange = DateInterval(start: Date().addingTimeInterval(-86400 * 365), end: Date().addingTimeInterval(86400 * 365))
            let events = try await CalendarService().fetchEvents(for: dateRange)
            
            let invalidEvents = events.filter { $0.startDate >= $0.endDate && !$0.isAllDay }
            
            if !invalidEvents.isEmpty {
                issues.append(CalendarBug(
                    id: "AUTO-DATA-\(UUID().uuidString.prefix(8))",
                    title: "Invalid event date ranges detected",
                    description: "Found \(invalidEvents.count) events with invalid date ranges",
                    severity: .high,
                    category: .dataIntegrity,
                    status: .new,
                    workaround: "Edit affected events to fix date ranges",
                    affectedVersions: ["Current"],
                    reportedDate: Date()
                ))
            }
        } catch {
            // Data loading error
        }
        
        return issues
    }
}

// MARK: - Bug Models

struct CalendarBug: Identifiable {
    let id: String
    let title: String
    let description: String
    let severity: CalendarBugSeverity
    let category: CalendarBugCategory
    var status: CalendarBugStatus
    let workaround: String?
    let affectedVersions: [String]
    let reportedDate: Date
    var resolvedDate: Date?
    
    var ageInDays: Int {
        Calendar.current.dateComponents([.day], from: reportedDate, to: Date()).day ?? 0
    }
}

enum CalendarBugSeverity: String, CaseIterable {
    case critical = "Critical"
    case high = "High"
    case medium = "Medium"
    case low = "Low"
    
    var color: Color {
        switch self {
        case .critical: return .red
        case .high: return .orange
        case .medium: return .yellow
        case .low: return .blue
        }
    }
    
    var icon: String {
        switch self {
        case .critical: return "exclamationmark.triangle.fill"
        case .high: return "exclamationmark.circle.fill"
        case .medium: return "info.circle.fill"
        case .low: return "info.circle"
        }
    }
}

enum CalendarBugCategory: String, CaseIterable {
    case sync = "Sync"
    case accessibility = "Accessibility"
    case dateTime = "Date & Time"
    case permissions = "Permissions"
    case widget = "Widget"
    case performance = "Performance"
    case dataIntegrity = "Data Integrity"
    case ui = "User Interface"
    case notifications = "Notifications"
    
    var icon: String {
        switch self {
        case .sync: return "arrow.clockwise"
        case .accessibility: return "accessibility"
        case .dateTime: return "calendar"
        case .permissions: return "lock"
        case .widget: return "rectangle.3.group"
        case .performance: return "speedometer"
        case .dataIntegrity: return "checkmark.shield"
        case .ui: return "paintbrush"
        case .notifications: return "bell"
        }
    }
}

enum CalendarBugStatus: String, CaseIterable {
    case new = "New"
    case known = "Known"
    case investigating = "Investigating"
    case inProgress = "In Progress"
    case resolved = "Resolved"
    case wontFix = "Won't Fix"
    
    var color: Color {
        switch self {
        case .new: return .red
        case .known: return .orange
        case .investigating: return .yellow
        case .inProgress: return .blue
        case .resolved: return .green
        case .wontFix: return .gray
        }
    }
}

// MARK: - Bug Tracker View

struct CalendarBugTrackerView: View {
    @StateObject private var bugTracker = CalendarBugTracker.shared
    @State private var selectedCategory: CalendarBugCategory?
    @State private var selectedSeverity: CalendarBugSeverity?
    @State private var showResolvedBugs = false
    @State private var isRunningDetection = false
    
    var filteredBugs: [CalendarBug] {
        var bugs = showResolvedBugs ? bugTracker.resolvedIssues : bugTracker.knownIssues
        
        if let category = selectedCategory {
            bugs = bugs.filter { $0.category == category }
        }
        
        if let severity = selectedSeverity {
            bugs = bugs.filter { $0.severity == severity }
        }
        
        return bugs.sorted { $0.reportedDate > $1.reportedDate }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Filters
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        // Category filter
                        Menu("Category: \(selectedCategory?.rawValue ?? "All")") {
                            Button("All Categories") {
                                selectedCategory = nil
                            }
                            
                            ForEach(CalendarBugCategory.allCases, id: \.self) { category in
                                Button(category.rawValue) {
                                    selectedCategory = category
                                }
                            }
                        }
                        .buttonStyle(.bordered)
                        
                        // Severity filter
                        Menu("Severity: \(selectedSeverity?.rawValue ?? "All")") {
                            Button("All Severities") {
                                selectedSeverity = nil
                            }
                            
                            ForEach(CalendarBugSeverity.allCases, id: \.self) { severity in
                                Button(severity.rawValue) {
                                    selectedSeverity = severity
                                }
                            }
                        }
                        .buttonStyle(.bordered)
                        
                        // Show resolved toggle
                        Button(showResolvedBugs ? "Show Active" : "Show Resolved") {
                            showResolvedBugs.toggle()
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 8)
                
                // Bug list
                List {
                    if filteredBugs.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: showResolvedBugs ? "checkmark.circle" : "ladybug")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)
                            
                            Text(showResolvedBugs ? "No resolved bugs" : "No active bugs")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            if !showResolvedBugs {
                                Text("Great! No known issues at the moment.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    } else {
                        ForEach(filteredBugs) { bug in
                            CalendarBugRowView(bug: bug) { updatedBug in
                                bugTracker.updateBugStatus(updatedBug.id, status: updatedBug.status)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Calendar Issues")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Run Bug Detection") {
                            runBugDetection()
                        }
                        .disabled(isRunningDetection)
                        
                        Button("Report New Bug") {
                            // Show bug reporting form
                        }
                        
                        Divider()
                        
                        Button("Export Bug Report") {
                            exportBugReport()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
    }
    
    private func runBugDetection() {
        isRunningDetection = true
        
        Task {
            let detectedBugs = await bugTracker.runAutomatedBugDetection()
            
            await MainActor.run {
                for bug in detectedBugs {
                    bugTracker.reportBug(bug)
                }
                
                isRunningDetection = false
                
                if !detectedBugs.isEmpty {
                    // Show alert about detected bugs
                }
            }
        }
    }
    
    private func exportBugReport() {
        // Export bug report functionality
        CalendarHapticManager.shared.lightImpact()
    }
}

struct CalendarBugRowView: View {
    let bug: CalendarBug
    let onStatusUpdate: (CalendarBug) -> Void
    
    @State private var showDetails = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Severity indicator
                Image(systemName: bug.severity.icon)
                    .foregroundColor(bug.severity.color)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(bug.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(2)
                    
                    HStack {
                        Text(bug.category.rawValue)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .foregroundColor(.blue)
                            .cornerRadius(4)
                        
                        Text(bug.status.rawValue)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(bug.status.color.opacity(0.2))
                            .foregroundColor(bug.status.color)
                            .cornerRadius(4)
                        
                        Spacer()
                        
                        Text("\(bug.ageInDays)d ago")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Button(action: { showDetails.toggle() }) {
                    Image(systemName: showDetails ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if showDetails {
                VStack(alignment: .leading, spacing: 8) {
                    Text(bug.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let workaround = bug.workaround {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Workaround:")
                                .font(.caption)
                                .fontWeight(.medium)
                            
                            Text(workaround)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(8)
                        .background(Color.yellow.opacity(0.1))
                        .cornerRadius(6)
                    }
                    
                    if bug.status != .resolved {
                        Menu("Update Status") {
                            ForEach(CalendarBugStatus.allCases, id: \.self) { status in
                                if status != bug.status {
                                    Button(status.rawValue) {
                                        var updatedBug = bug
                                        updatedBug.status = status
                                        onStatusUpdate(updatedBug)
                                    }
                                }
                            }
                        }
                        .buttonStyle(.bordered)
                        .font(.caption)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    CalendarBugTrackerView()
        .previewEnvironment()
}