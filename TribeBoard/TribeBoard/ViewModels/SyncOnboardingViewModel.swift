import SwiftUI
import SwiftData
import EventKit
import Combine

/// ViewModel for managing the sync onboarding flow
@MainActor
class SyncOnboardingViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var currentStep: OnboardingStep = .welcome
    @Published var completedSteps: Set<OnboardingStep> = []
    @Published var isProcessing = false
    
    // Permission status
    @Published var permissionStatus: PermissionStatus = .notDetermined
    
    // Calendar setup status
    @Published var calendarSetupStatus: CalendarSetupStatus = .notStarted
    @Published var mainCalendarCreated = false
    @Published var familyCalendarCreated = false
    @Published var personalCalendarCreated = false
    
    // Sync status
    @Published var syncStatus: SyncStatus = .pending
    @Published var syncProgress: Double = 0.0
    @Published var syncedEventsCount = 0
    @Published var syncMessage: String?
    
    // MARK: - Properties
    
    let userId: UUID
    let syncService: CalendarSyncService
    let eventKitManager: EventKitManager
    let modelContext: ModelContext
    
    private var syncConfiguration: SyncConfiguration?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(userId: UUID, syncService: CalendarSyncService, eventKitManager: EventKitManager, modelContext: ModelContext) {
        self.userId = userId
        self.syncService = syncService
        self.eventKitManager = eventKitManager
        self.modelContext = modelContext
        
        setupObservers()
        print("🚀 SyncOnboardingViewModel: Initialized for user: \(userId)")
    }
    
    deinit {
        cancellables.removeAll()
    }
    
    // MARK: - Setup
    
    private func setupObservers() {
        // Observe sync service changes
        syncService.$isSyncing
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isSyncing in
                if isSyncing {
                    self?.syncStatus = .inProgress
                } else if self?.syncStatus == .inProgress {
                    self?.syncStatus = .completed
                }
            }
            .store(in: &cancellables)
        
        syncService.$syncProgress
            .receive(on: DispatchQueue.main)
            .assign(to: \.syncProgress, on: self)
            .store(in: &cancellables)
    }
    
    func initialize() async {
        await checkCurrentStatus()
        await determineStartingStep()
    }
    
    private func checkCurrentStatus() async {
        // Check permission status
        await checkPermissionStatus()
        
        // Check if sync configuration exists
        do {
            syncConfiguration = try getSyncConfiguration()
            
            if let config = syncConfiguration {
                // Check calendar setup status
                await checkCalendarSetupStatus()
                
                // If everything is set up, we might be able to skip some steps
                if config.isSyncConfigured {
                    completedSteps.insert(.permissions)
                    completedSteps.insert(.calendarSetup)
                }
            }
        } catch {
            print("❌ SyncOnboardingViewModel: Failed to check sync configuration: \(error)")
        }
    }
    
    private func determineStartingStep() async {
        if permissionStatus == .granted && calendarSetupStatus == .completed {
            // If everything is already set up, go to sync step
            currentStep = .initialSync
        } else if permissionStatus == .granted {
            // If permission is granted but calendars not set up
            currentStep = .calendarSetup
        } else if permissionStatus != .notDetermined {
            // If permission was denied or restricted
            currentStep = .permissions
        } else {
            // Start from the beginning
            currentStep = .welcome
        }
    }
    
    // MARK: - Navigation
    
    var canGoBack: Bool {
        currentStep != .welcome && !isProcessing
    }
    
    var canProceed: Bool {
        switch currentStep {
        case .welcome:
            return true
        case .permissions:
            return permissionStatus == .granted
        case .calendarSetup:
            return calendarSetupStatus == .completed
        case .initialSync:
            return syncStatus == .completed || syncStatus == .cancelled
        case .completion:
            return true
        }
    }
    
    var nextButtonTitle: String {
        switch currentStep {
        case .welcome:
            return "Get Started"
        case .permissions:
            return permissionStatus == .granted ? "Continue" : "Grant Permission"
        case .calendarSetup:
            return calendarSetupStatus == .completed ? "Continue" : "Set Up Calendars"
        case .initialSync:
            return syncStatus == .completed || syncStatus == .cancelled ? "Continue" : "Start Sync"
        case .completion:
            return "Done"
        }
    }
    
    func goToNextStep() async {
        guard canProceed && !isProcessing else { return }
        
        isProcessing = true
        defer { isProcessing = false }
        
        switch currentStep {
        case .welcome:
            completedSteps.insert(.welcome)
            currentStep = .permissions
            
        case .permissions:
            if permissionStatus != .granted {
                await requestCalendarPermission()
            } else {
                completedSteps.insert(.permissions)
                currentStep = .calendarSetup
            }
            
        case .calendarSetup:
            if calendarSetupStatus != .completed {
                await setupCalendars()
            } else {
                completedSteps.insert(.calendarSetup)
                currentStep = .initialSync
            }
            
        case .initialSync:
            if syncStatus == .pending {
                await performInitialSync()
            } else {
                completedSteps.insert(.initialSync)
                currentStep = .completion
            }
            
        case .completion:
            // This should be handled by the parent view
            break
        }
    }
    
    func goToPreviousStep() async {
        guard canGoBack else { return }
        
        switch currentStep {
        case .welcome:
            break // Can't go back from welcome
        case .permissions:
            currentStep = .welcome
        case .calendarSetup:
            currentStep = .permissions
        case .initialSync:
            currentStep = .calendarSetup
        case .completion:
            currentStep = .initialSync
        }
    }
    
    // MARK: - Permission Management
    
    private func checkPermissionStatus() async {
        let authStatus = eventKitManager.authorizationStatus
        
        switch authStatus {
        case .notDetermined:
            permissionStatus = .notDetermined
        case .denied, .restricted:
            permissionStatus = .denied
        case .fullAccess:
            permissionStatus = .granted
        case .writeOnly:
            permissionStatus = .denied // We need full access
        @unknown default:
            permissionStatus = .notDetermined
        }
    }
    
    func requestCalendarPermission() async {
        guard permissionStatus == .notDetermined else { return }
        
        isProcessing = true
        defer { isProcessing = false }
        
        do {
            let granted = try await eventKitManager.requestAccess()
            
            if granted {
                permissionStatus = .granted
                
                // Update or create sync configuration
                let config = try getOrCreateSyncConfiguration()
                config.updateEventKitPermission(granted: true)
                try modelContext.save()
                
                print("✅ SyncOnboardingViewModel: Calendar permission granted")
                
                // Automatically proceed to next step
                completedSteps.insert(.permissions)
                currentStep = .calendarSetup
                
            } else {
                permissionStatus = .denied
                print("❌ SyncOnboardingViewModel: Calendar permission denied")
            }
            
        } catch {
            permissionStatus = .denied
            print("❌ SyncOnboardingViewModel: Failed to request calendar permission: \(error)")
        }
    }
    
    // MARK: - Calendar Setup
    
    private func checkCalendarSetupStatus() async {
        do {
            let calendarsExist = try await eventKitManager.areTribeBoardCalendarsSetUp()
            
            if calendarsExist {
                calendarSetupStatus = .completed
                mainCalendarCreated = true
                familyCalendarCreated = true
                personalCalendarCreated = true
            } else {
                calendarSetupStatus = .notStarted
            }
            
        } catch {
            calendarSetupStatus = .failed
            print("❌ SyncOnboardingViewModel: Failed to check calendar setup: \(error)")
        }
    }
    
    func setupCalendars() async {
        guard permissionStatus == .granted else { return }
        
        isProcessing = true
        calendarSetupStatus = .inProgress
        
        defer {
            isProcessing = false
        }
        
        do {
            // Reset creation status
            mainCalendarCreated = false
            familyCalendarCreated = false
            personalCalendarCreated = false
            
            // Create calendars with progress updates
            syncMessage = "Creating main calendar..."
            let mainCalendar = try await eventKitManager.createTribeBoardCalendar()
            mainCalendarCreated = true
            
            // Small delay for visual feedback
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            syncMessage = "Creating family calendar..."
            let familyCalendar = try await eventKitManager.createTribeBoardFamilyCalendar()
            familyCalendarCreated = true
            
            try await Task.sleep(nanoseconds: 500_000_000)
            
            syncMessage = "Creating personal calendar..."
            let personalCalendar = try await eventKitManager.createTribeBoardPersonalCalendar()
            personalCalendarCreated = true
            
            // Update sync configuration
            let config = try getOrCreateSyncConfiguration()
            config.enableAppleCalendarSync(
                calendarIdentifier: mainCalendar.calendarIdentifier,
                familyCalendarIdentifier: familyCalendar.calendarIdentifier,
                personalCalendarIdentifier: personalCalendar.calendarIdentifier
            )
            
            try modelContext.save()
            
            calendarSetupStatus = .completed
            syncMessage = "Calendars created successfully!"
            
            print("✅ SyncOnboardingViewModel: Calendars set up successfully")
            
            // Automatically proceed to next step after a brief delay
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            completedSteps.insert(.calendarSetup)
            currentStep = .initialSync
            
        } catch {
            calendarSetupStatus = .failed
            syncMessage = "Failed to create calendars: \(error.localizedDescription)"
            print("❌ SyncOnboardingViewModel: Failed to set up calendars: \(error)")
        }
    }
    
    // MARK: - Initial Sync
    
    func performInitialSync() async {
        guard let config = syncConfiguration, config.isSyncConfigured else {
            syncStatus = .failed
            syncMessage = "Sync not properly configured"
            return
        }
        
        isProcessing = true
        syncStatus = .inProgress
        syncProgress = 0.0
        syncedEventsCount = 0
        syncMessage = "Starting initial sync..."
        
        defer {
            isProcessing = false
        }
        
        do {
            // Perform full bidirectional sync
            try await syncService.performFullSync(userId: userId)
            
            // Get count of synced events (mock for now)
            syncedEventsCount = try getEventCount()
            
            syncStatus = .completed
            syncMessage = "Sync completed successfully!"
            
            // Update sync configuration
            config.recordSuccessfulSync()
            try modelContext.save()
            
            print("✅ SyncOnboardingViewModel: Initial sync completed")
            
            // Automatically proceed to completion after a brief delay
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            completedSteps.insert(.initialSync)
            currentStep = .completion
            
        } catch {
            syncStatus = .failed
            syncMessage = "Sync failed: \(error.localizedDescription)"
            
            // Record error in configuration
            config.recordSyncError(error.localizedDescription)
            try? modelContext.save()
            
            print("❌ SyncOnboardingViewModel: Initial sync failed: \(error)")
        }
    }
    
    func skipInitialSync() async {
        syncStatus = .cancelled
        syncMessage = "Sync skipped - you can sync manually later"
        
        completedSteps.insert(.initialSync)
        currentStep = .completion
        
        print("ℹ️ SyncOnboardingViewModel: Initial sync skipped")
    }
    
    // MARK: - Helper Methods
    
    private func getSyncConfiguration() throws -> SyncConfiguration? {
        let descriptor = FetchDescriptor<SyncConfiguration>()
        let allConfigs = try modelContext.fetch(descriptor)
        
        return allConfigs.first { config in
            config.userId == userId
        }
    }
    
    private func getOrCreateSyncConfiguration() throws -> SyncConfiguration {
        if let existing = try getSyncConfiguration() {
            return existing
        }
        
        let newConfig = SyncConfiguration(userId: userId)
        modelContext.insert(newConfig)
        syncConfiguration = newConfig
        return newConfig
    }
    
    private func getEventCount() throws -> Int {
        let descriptor = FetchDescriptor<CalendarEvent>()
        let allEvents = try modelContext.fetch(descriptor)
        
        return allEvents.filter { event in
            !event.isDeleted && (event.createdBy == userId || event.privacyLevel == .familyShared)
        }.count
    }
}

// MARK: - Supporting Enums

enum OnboardingStep: String, CaseIterable {
    case welcome
    case permissions
    case calendarSetup
    case initialSync
    case completion
    
    var stepNumber: Int {
        switch self {
        case .welcome: return 1
        case .permissions: return 2
        case .calendarSetup: return 3
        case .initialSync: return 4
        case .completion: return 5
        }
    }
    
    var title: String {
        switch self {
        case .welcome: return "Welcome"
        case .permissions: return "Permissions"
        case .calendarSetup: return "Calendar Setup"
        case .initialSync: return "Initial Sync"
        case .completion: return "Complete"
        }
    }
}

enum PermissionStatus {
    case notDetermined
    case granted
    case denied
    
    var iconName: String {
        switch self {
        case .notDetermined: return "questionmark.circle"
        case .granted: return "checkmark.circle.fill"
        case .denied: return "xmark.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .notDetermined: return .blue
        case .granted: return .green
        case .denied: return .red
        }
    }
    
    var statusText: String {
        switch self {
        case .notDetermined: return "Not Requested"
        case .granted: return "Granted"
        case .denied: return "Denied"
        }
    }
    
    var description: String {
        switch self {
        case .notDetermined:
            return "TribeBoard needs permission to access your calendar to sync events with Apple Calendar."
        case .granted:
            return "Great! TribeBoard has permission to access your calendar. Now let's set up your calendars."
        case .denied:
            return "Calendar access was denied. Please enable it in Settings to continue with sync setup."
        }
    }
}

enum CalendarSetupStatus {
    case notStarted
    case inProgress
    case completed
    case failed
    
    var iconName: String {
        switch self {
        case .notStarted: return "calendar.badge.plus"
        case .inProgress: return "arrow.triangle.2.circlepath"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .notStarted: return .blue
        case .inProgress: return .orange
        case .completed: return .green
        case .failed: return .red
        }
    }
}

