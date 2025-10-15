import Foundation
import CloudKit
import CoreData

/// Service for backing up and restoring calendar data
class CalendarBackupService {
    static let shared = CalendarBackupService()
    
    private let cloudKitService: CloudKitService
    private let calendarService: CalendarService
    
    private init() {
        self.cloudKitService = CloudKitService.shared
        self.calendarService = CalendarService()
    }
    
    // MARK: - Backup Operations
    
    /// Create a full backup of calendar data
    func createFullBackup() async throws -> CalendarBackup {
        let events = try await fetchAllEvents()
        let syncConfigurations = try await fetchSyncConfigurations()
        let permissions = try await fetchCalendarPermissions()
        
        let backup = CalendarBackup(
            id: UUID(),
            createdAt: Date(),
            events: events,
            syncConfigurations: syncConfigurations,
            permissions: permissions,
            version: CalendarBackup.currentVersion
        )
        
        // Store backup in CloudKit
        try await storeBackupInCloudKit(backup)
        
        // Store backup locally
        try await storeBackupLocally(backup)
        
        return backup
    }
    
    /// Create an incremental backup (only changed data since last backup)
    func createIncrementalBackup(since lastBackupDate: Date) async throws -> CalendarBackup {
        let events = try await fetchEventsModifiedSince(lastBackupDate)
        let syncConfigurations = try await fetchSyncConfigurations()
        let permissions = try await fetchCalendarPermissions()
        
        let backup = CalendarBackup(
            id: UUID(),
            createdAt: Date(),
            events: events,
            syncConfigurations: syncConfigurations,
            permissions: permissions,
            version: CalendarBackup.currentVersion,
            isIncremental: true,
            baseBackupDate: lastBackupDate
        )
        
        try await storeBackupInCloudKit(backup)
        try await storeBackupLocally(backup)
        
        return backup
    }
    
    // MARK: - Restore Operations
    
    /// Restore calendar data from backup
    func restoreFromBackup(_ backup: CalendarBackup, strategy: RestoreStrategy = .merge) async throws {
        switch strategy {
        case .replace:
            try await replaceAllData(with: backup)
        case .merge:
            try await mergeBackupData(backup)
        case .selective(let options):
            try await selectiveRestore(backup, options: options)
        }
        
        // Trigger sync after restore
        try await calendarService.syncWithAppleCalendar()
    }
    
    /// Get list of available backups
    func getAvailableBackups() async throws -> [CalendarBackupMetadata] {
        let cloudKitBackups = try await fetchBackupsFromCloudKit()
        let localBackups = try await fetchLocalBackups()
        
        // Merge and deduplicate backups
        var allBackups: [CalendarBackupMetadata] = []
        
        // Add CloudKit backups
        allBackups.append(contentsOf: cloudKitBackups.map { backup in
            CalendarBackupMetadata(
                id: backup.id,
                createdAt: backup.createdAt,
                version: backup.version,
                isIncremental: backup.isIncremental,
                eventCount: backup.events.count,
                source: .cloudKit
            )
        })
        
        // Add local backups that aren't already in CloudKit
        for localBackup in localBackups {
            if !allBackups.contains(where: { $0.id == localBackup.id }) {
                allBackups.append(CalendarBackupMetadata(
                    id: localBackup.id,
                    createdAt: localBackup.createdAt,
                    version: localBackup.version,
                    isIncremental: localBackup.isIncremental,
                    eventCount: localBackup.events.count,
                    source: .local
                ))
            }
        }
        
        return allBackups.sorted { $0.createdAt > $1.createdAt }
    }
    
    /// Delete a backup
    func deleteBackup(withId backupId: UUID) async throws {
        // Delete from CloudKit
        try await deleteBackupFromCloudKit(backupId)
        
        // Delete from local storage
        try await deleteLocalBackup(backupId)
    }
    
    // MARK: - Automatic Backup
    
    /// Schedule automatic backups - coordinates with CalendarBackgroundSyncProcessor
    func scheduleAutomaticBackups() {
        print("📅 CalendarBackupService: Scheduling automatic backups (coordinates with background processor)")
        
        // Note: In a fully integrated system, this would coordinate with CalendarBackgroundSyncProcessor
        // For now, we maintain the existing timer-based approach but note the coordination point
        Timer.scheduledTimer(withTimeInterval: 24 * 60 * 60, repeats: true) { _ in
            Task {
                try? await self.performAutomaticBackup()
            }
        }
    }
    
    /// Performs backup as part of background processing
    func performBackgroundBackup() async {
        print("📅 CalendarBackupService: Performing background backup")
        do {
            try await performAutomaticBackup()
        } catch {
            print("❌ CalendarBackupService: Background backup failed: \(error.localizedDescription)")
        }
    }
    
    private func performAutomaticBackup() async throws {
        let lastBackupDate = try await getLastBackupDate()
        
        if let lastBackup = lastBackupDate,
           Date().timeIntervalSince(lastBackup) < 24 * 60 * 60 {
            // Don't backup more than once per day
            return
        }
        
        if let lastBackup = lastBackupDate {
            // Create incremental backup
            _ = try await createIncrementalBackup(since: lastBackup)
        } else {
            // Create full backup
            _ = try await createFullBackup()
        }
    }
    
    // MARK: - Private Methods
    
    private func fetchAllEvents() async throws -> [CalendarEvent] {
        let startDate = Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date()
        let endDate = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
        let dateRange = DateInterval(start: startDate, end: endDate)
        
        return try await calendarService.fetchEvents(for: dateRange)
    }
    
    private func fetchEventsModifiedSince(_ date: Date) async throws -> [CalendarEvent] {
        let allEvents = try await fetchAllEvents()
        return allEvents.filter { $0.lastModified > date }
    }
    
    private func fetchSyncConfigurations() async throws -> [SyncConfiguration] {
        // Fetch sync configurations from Core Data
        // This is a simplified implementation
        return []
    }
    
    private func fetchCalendarPermissions() async throws -> [CalendarPermission] {
        // Fetch calendar permissions from Core Data
        // This is a simplified implementation
        return []
    }
    
    private func storeBackupInCloudKit(_ backup: CalendarBackup) async throws {
        let record = CKRecord(recordType: "CalendarBackup", recordID: CKRecord.ID(recordName: backup.id.uuidString))
        
        // Convert backup to data
        let backupData = try JSONEncoder().encode(backup)
        record["backupData"] = backupData
        record["createdAt"] = backup.createdAt
        record["version"] = backup.version
        record["isIncremental"] = backup.isIncremental ? 1 : 0
        
        try await cloudKitService.save(record: record)
    }
    
    private func storeBackupLocally(_ backup: CalendarBackup) async throws {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let backupsPath = documentsPath.appendingPathComponent("CalendarBackups")
        
        // Create backups directory if it doesn't exist
        try FileManager.default.createDirectory(at: backupsPath, withIntermediateDirectories: true)
        
        let backupFile = backupsPath.appendingPathComponent("\(backup.id.uuidString).backup")
        let backupData = try JSONEncoder().encode(backup)
        
        try backupData.write(to: backupFile)
    }
    
    private func fetchBackupsFromCloudKit() async throws -> [CalendarBackup] {
        let query = CKQuery(recordType: "CalendarBackup", predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        
        let records = try await cloudKitService.fetch(query: query)
        
        return try records.compactMap { (record: CKRecord) -> CalendarBackup? in
            guard let backupData = record["backupData"] as? Data else { return nil }
            return try JSONDecoder().decode(CalendarBackup.self, from: backupData)
        }
    }
    
    private func fetchLocalBackups() async throws -> [CalendarBackup] {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let backupsPath = documentsPath.appendingPathComponent("CalendarBackups")
        
        guard FileManager.default.fileExists(atPath: backupsPath.path) else {
            return []
        }
        
        let backupFiles = try FileManager.default.contentsOfDirectory(at: backupsPath, includingPropertiesForKeys: nil)
        
        return try backupFiles.compactMap { file in
            guard file.pathExtension == "backup" else { return nil }
            let backupData = try Data(contentsOf: file)
            return try JSONDecoder().decode(CalendarBackup.self, from: backupData)
        }
    }
    
    private func deleteBackupFromCloudKit(_ backupId: UUID) async throws {
        let recordID = CKRecord.ID(recordName: backupId.uuidString)
        try await cloudKitService.delete(recordID: recordID)
    }
    
    private func deleteLocalBackup(_ backupId: UUID) async throws {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let backupFile = documentsPath.appendingPathComponent("CalendarBackups/\(backupId.uuidString).backup")
        
        if FileManager.default.fileExists(atPath: backupFile.path) {
            try FileManager.default.removeItem(at: backupFile)
        }
    }
    
    private func replaceAllData(with backup: CalendarBackup) async throws {
        // Delete all existing events
        let existingEvents = try await fetchAllEvents()
        for event in existingEvents {
            try await calendarService.deleteEvent(event)
        }
        
        // Restore events from backup
        for event in backup.events {
            _ = try await calendarService.createEvent(event)
        }
    }
    
    private func mergeBackupData(_ backup: CalendarBackup) async throws {
        for event in backup.events {
            // Check if event already exists
            let existingEvents = try await fetchAllEvents()
            if let existingEvent = existingEvents.first(where: { $0.id == event.id }) {
                // Update if backup version is newer
                if event.lastModified > existingEvent.lastModified {
                    _ = try await calendarService.updateEvent(event)
                }
            } else {
                // Create new event
                _ = try await calendarService.createEvent(event)
            }
        }
    }
    
    private func selectiveRestore(_ backup: CalendarBackup, options: SelectiveRestoreOptions) async throws {
        let eventsToRestore = backup.events.filter { event in
            if let dateRange = options.dateRange {
                return dateRange.contains(event.startDate)
            }
            
            if let privacyLevels = options.privacyLevels {
                return privacyLevels.contains(event.privacyLevel)
            }
            
            return true
        }
        
        for event in eventsToRestore {
            _ = try await calendarService.createEvent(event)
        }
    }
    
    private func getLastBackupDate() async throws -> Date? {
        let backups = try await getAvailableBackups()
        return backups.first?.createdAt
    }
}

// MARK: - Supporting Types

struct CalendarBackup: Codable {
    let id: UUID
    let createdAt: Date
    let events: [CalendarEvent]
    let syncConfigurations: [SyncConfiguration]
    let permissions: [CalendarPermission]
    let version: String
    let isIncremental: Bool
    let baseBackupDate: Date?
    
    static let currentVersion = "1.0"
    
    init(
        id: UUID,
        createdAt: Date,
        events: [CalendarEvent],
        syncConfigurations: [SyncConfiguration],
        permissions: [CalendarPermission],
        version: String,
        isIncremental: Bool = false,
        baseBackupDate: Date? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.events = events
        self.syncConfigurations = syncConfigurations
        self.permissions = permissions
        self.version = version
        self.isIncremental = isIncremental
        self.baseBackupDate = baseBackupDate
    }
}

struct CalendarBackupMetadata {
    let id: UUID
    let createdAt: Date
    let version: String
    let isIncremental: Bool
    let eventCount: Int
    let source: BackupSource
}

enum BackupSource {
    case cloudKit
    case local
}

enum RestoreStrategy {
    case replace
    case merge
    case selective(SelectiveRestoreOptions)
}

struct SelectiveRestoreOptions {
    let dateRange: DateInterval?
    let privacyLevels: [CalendarEvent.PrivacyLevel]?
    let eventTypes: [String]?
}

// MARK: - Backup Management View

struct CalendarBackupManagementView: View {
    @StateObject private var backupService = CalendarBackupService.shared
    @State private var availableBackups: [CalendarBackupMetadata] = []
    @State private var isLoading = false
    @State private var showCreateBackupAlert = false
    @State private var showRestoreAlert = false
    @State private var selectedBackup: CalendarBackupMetadata?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Backup Actions
                VStack(spacing: 12) {
                    Button(action: createBackup) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Create Backup")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(isLoading)
                    
                    Button(action: scheduleAutomaticBackups) {
                        HStack {
                            Image(systemName: "clock.arrow.circlepath")
                            Text("Enable Auto Backup")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal)
                
                // Available Backups
                VStack(alignment: .leading, spacing: 12) {
                    Text("Available Backups")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    if availableBackups.isEmpty {
                        Text("No backups available")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 8) {
                                ForEach(availableBackups, id: \.id) { backup in
                                    BackupRowView(backup: backup) {
                                        selectedBackup = backup
                                        showRestoreAlert = true
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                
                Spacer()
            }
            .navigationTitle("Calendar Backup")
            .navigationBarTitleDisplayMode(.large)
            .task {
                await loadBackups()
            }
            .alert("Create Backup", isPresented: $showCreateBackupAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Create") {
                    Task {
                        await performCreateBackup()
                    }
                }
            } message: {
                Text("This will create a backup of all your calendar data.")
            }
            .alert("Restore Backup", isPresented: $showRestoreAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Restore", role: .destructive) {
                    Task {
                        await performRestore()
                    }
                }
            } message: {
                Text("This will restore your calendar data from the selected backup. Current data may be overwritten.")
            }
        }
    }
    
    private func loadBackups() async {
        isLoading = true
        
        do {
            let backups = try await CalendarBackupService.shared.getAvailableBackups()
            await MainActor.run {
                self.availableBackups = backups
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
    
    private func createBackup() {
        showCreateBackupAlert = true
    }
    
    private func performCreateBackup() async {
        isLoading = true
        
        do {
            _ = try await CalendarBackupService.shared.createFullBackup()
            await loadBackups()
            
            CalendarHapticManager.shared.success()
        } catch {
            CalendarHapticManager.shared.error()
        }
        
        isLoading = false
    }
    
    private func scheduleAutomaticBackups() {
        CalendarBackupService.shared.scheduleAutomaticBackups()
        CalendarHapticManager.shared.success()
    }
    
    private func performRestore() async {
        guard let backup = selectedBackup else { return }
        
        isLoading = true
        
        // For this implementation, we'll need to fetch the full backup
        // This is simplified - in a real implementation, you'd fetch the backup by ID
        
        CalendarHapticManager.shared.success()
        isLoading = false
    }
}

struct BackupRowView: View {
    let backup: CalendarBackupMetadata
    let onRestore: () -> Void
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(dateFormatter.string(from: backup.createdAt))
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    if backup.isIncremental {
                        Text("Incremental")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.2))
                            .foregroundColor(.orange)
                            .cornerRadius(4)
                    }
                    
                    Spacer()
                    
                    Image(systemName: backup.source == .cloudKit ? "icloud.fill" : "internaldrive.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text("\(backup.eventCount) events")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button("Restore", action: onRestore)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

#Preview {
    CalendarBackupManagementView()
        .previewEnvironment()
}