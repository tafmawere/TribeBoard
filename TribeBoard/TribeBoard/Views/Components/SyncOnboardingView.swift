import SwiftUI
import SwiftData
import EventKit

/// Onboarding flow for setting up Apple Calendar sync
struct SyncOnboardingView: View {
    @StateObject private var viewModel: SyncOnboardingViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingPermissionHelp = false
    @State private var showingTroubleshooting = false
    
    init(userId: UUID, syncService: CalendarSyncService, eventKitManager: EventKitManager, modelContext: ModelContext) {
        self._viewModel = StateObject(wrappedValue: SyncOnboardingViewModel(
            userId: userId,
            syncService: syncService,
            eventKitManager: eventKitManager,
            modelContext: modelContext
        ))
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [Color.blue.opacity(0.1), Color.green.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 0) {
                        // Progress indicator
                        progressIndicator
                        
                        // Current step content
                        currentStepView
                            .padding(.horizontal, 24)
                            .padding(.bottom, 32)
                        
                        // Navigation buttons
                        navigationButtons
                            .padding(.horizontal, 24)
                    }
                }
            }
            .navigationTitle("Calendar Sync Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                if viewModel.currentStep != .welcome {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Help") {
                            showingTroubleshooting = true
                        }
                    }
                }
            }
            .sheet(isPresented: $showingPermissionHelp) {
                PermissionHelpView()
            }
            .sheet(isPresented: $showingTroubleshooting) {
                OnboardingTroubleshootingView(viewModel: viewModel)
            }
            .onAppear {
                Task {
                    await viewModel.initialize()
                }
            }
        }
    }
    
    // MARK: - Progress Indicator
    
    private var progressIndicator: some View {
        VStack(spacing: 16) {
            HStack {
                ForEach(OnboardingStep.allCases.indices, id: \.self) { index in
                    let step = OnboardingStep.allCases[index]
                    let isActive = step == viewModel.currentStep
                    let isCompleted = viewModel.completedSteps.contains(step)
                    
                    HStack {
                        Circle()
                            .fill(isCompleted ? Color.green : (isActive ? Color.blue : Color.gray.opacity(0.3)))
                            .frame(width: 12, height: 12)
                            .overlay(
                                Group {
                                    if isCompleted {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 8, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                }
                            )
                        
                        if index < OnboardingStep.allCases.count - 1 {
                            Rectangle()
                                .fill(isCompleted ? Color.green : Color.gray.opacity(0.3))
                                .frame(height: 2)
                        }
                    }
                }
            }
            .padding(.horizontal, 32)
            
            Text("Step \(viewModel.currentStep.stepNumber) of \(OnboardingStep.allCases.count)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.top, 24)
        .padding(.bottom, 32)
    }
    
    // MARK: - Current Step View
    
    @ViewBuilder
    private var currentStepView: some View {
        switch viewModel.currentStep {
        case .welcome:
            WelcomeStepView(viewModel: viewModel)
        case .permissions:
            PermissionsStepView(viewModel: viewModel, showingHelp: $showingPermissionHelp)
        case .calendarSetup:
            CalendarSetupStepView(viewModel: viewModel)
        case .initialSync:
            InitialSyncStepView(viewModel: viewModel)
        case .completion:
            CompletionStepView(viewModel: viewModel)
        }
    }
    
    // MARK: - Navigation Buttons
    
    private var navigationButtons: some View {
        HStack(spacing: 16) {
            if viewModel.canGoBack {
                Button("Back") {
                    Task {
                        await viewModel.goToPreviousStep()
                    }
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isProcessing)
            }
            
            Spacer()
            
            if viewModel.currentStep == .completion {
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button(viewModel.nextButtonTitle) {
                    Task {
                        await viewModel.goToNextStep()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.canProceed || viewModel.isProcessing)
            }
        }
    }
}

// MARK: - Welcome Step

struct WelcomeStepView: View {
    @ObservedObject var viewModel: SyncOnboardingViewModel
    
    var body: some View {
        VStack(spacing: 24) {
            // Icon
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 64))
                .foregroundColor(.blue)
                .padding(.bottom, 8)
            
            // Title
            Text("Welcome to Calendar Sync")
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            // Description
            VStack(spacing: 16) {
                Text("Keep your TribeBoard events synchronized with Apple Calendar across all your devices.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                
                // Benefits list
                VStack(alignment: .leading, spacing: 12) {
                    BenefitRow(
                        icon: "icloud",
                        title: "Automatic Sync",
                        description: "Events sync automatically across all your Apple devices"
                    )
                    
                    BenefitRow(
                        icon: "lock.shield",
                        title: "Privacy Protected",
                        description: "Personal events stay private, family events are shared appropriately"
                    )
                    
                    BenefitRow(
                        icon: "arrow.triangle.2.circlepath",
                        title: "Two-Way Sync",
                        description: "Changes in either app are reflected in both places"
                    )
                    
                    BenefitRow(
                        icon: "wifi.slash",
                        title: "Offline Support",
                        description: "Create events offline, they'll sync when connection returns"
                    )
                }
                .padding(.top, 8)
            }
        }
    }
}

struct BenefitRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

// MARK: - Permissions Step

struct PermissionsStepView: View {
    @ObservedObject var viewModel: SyncOnboardingViewModel
    @Binding var showingHelp: Bool
    
    var body: some View {
        VStack(spacing: 24) {
            // Icon
            Image(systemName: viewModel.permissionStatus.iconName)
                .font(.system(size: 64))
                .foregroundColor(viewModel.permissionStatus.color)
                .padding(.bottom, 8)
            
            // Title
            Text("Calendar Permission")
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            // Status and description
            VStack(spacing: 16) {
                Text(viewModel.permissionStatus.description)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                
                // Permission status card
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: viewModel.permissionStatus.iconName)
                            .foregroundColor(viewModel.permissionStatus.color)
                        
                        Text("Calendar Access")
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Text(viewModel.permissionStatus.statusText)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(viewModel.permissionStatus.color.opacity(0.2))
                            .foregroundColor(viewModel.permissionStatus.color)
                            .clipShape(Capsule())
                    }
                    
                    if viewModel.permissionStatus == .denied {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("To enable calendar access:")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Text("1. Open Settings app")
                            Text("2. Find TribeBoard in the app list")
                            Text("3. Tap Calendars and enable access")
                            
                            Button("Open Settings") {
                                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(settingsUrl)
                                }
                            }
                            .buttonStyle(.bordered)
                            .padding(.top, 8)
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                if viewModel.permissionStatus == .notDetermined {
                    Button("Grant Calendar Access") {
                        Task {
                            await viewModel.requestCalendarPermission()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isProcessing)
                }
                
                Button("Need Help?") {
                    showingHelp = true
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
        }
    }
}

// MARK: - Calendar Setup Step

struct CalendarSetupStepView: View {
    @ObservedObject var viewModel: SyncOnboardingViewModel
    
    var body: some View {
        VStack(spacing: 24) {
            // Icon
            Image(systemName: viewModel.calendarSetupStatus.iconName)
                .font(.system(size: 64))
                .foregroundColor(viewModel.calendarSetupStatus.color)
                .padding(.bottom, 8)
            
            // Title
            Text("Calendar Setup")
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            // Description
            VStack(spacing: 16) {
                Text("TribeBoard will create dedicated calendars in your Apple Calendar app for organizing your events.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                
                // Calendar preview
                VStack(spacing: 12) {
                    CalendarPreviewRow(
                        name: "TribeBoard",
                        description: "Main calendar for all events",
                        color: .blue,
                        isCreated: viewModel.mainCalendarCreated
                    )
                    
                    CalendarPreviewRow(
                        name: "TribeBoard Family",
                        description: "Shared family events",
                        color: .green,
                        isCreated: viewModel.familyCalendarCreated
                    )
                    
                    CalendarPreviewRow(
                        name: "TribeBoard Personal",
                        description: "Your private events",
                        color: .orange,
                        isCreated: viewModel.personalCalendarCreated
                    )
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                if viewModel.calendarSetupStatus == .notStarted {
                    Button("Create Calendars") {
                        Task {
                            await viewModel.setupCalendars()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isProcessing)
                } else if viewModel.calendarSetupStatus == .inProgress {
                    VStack(spacing: 8) {
                        ProgressView("Creating calendars...")
                        Text("This may take a moment")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else if viewModel.calendarSetupStatus == .failed {
                    VStack(spacing: 12) {
                        Text("Calendar setup failed")
                            .foregroundColor(.red)
                        
                        Button("Retry") {
                            Task {
                                await viewModel.setupCalendars()
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
    }
}

struct CalendarPreviewRow: View {
    let name: String
    let description: String
    let color: Color
    let isCreated: Bool
    
    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if isCreated {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else {
                Image(systemName: "circle")
                    .foregroundColor(.gray)
            }
        }
    }
}

// MARK: - Initial Sync Step

struct InitialSyncStepView: View {
    @ObservedObject var viewModel: SyncOnboardingViewModel
    
    var body: some View {
        VStack(spacing: 24) {
            // Icon
            Image(systemName: viewModel.syncStatus.iconName)
                .font(.system(size: 64))
                .foregroundColor(viewModel.syncStatus.color)
                .padding(.bottom, 8)
            
            // Title
            Text("Initial Sync")
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            // Description and progress
            VStack(spacing: 16) {
                Text("Synchronizing your existing events with Apple Calendar. This ensures everything is up to date.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                
                // Sync progress card
                VStack(spacing: 16) {
                    HStack {
                        Image(systemName: viewModel.syncStatus.iconName)
                            .foregroundColor(viewModel.syncStatus.color)
                        
                        Text("Sync Status")
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Text(viewModel.syncStatus.statusText)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(viewModel.syncStatus.color.opacity(0.2))
                            .foregroundColor(viewModel.syncStatus.color)
                            .clipShape(Capsule())
                    }
                    
                    if viewModel.syncStatus == .inProgress {
                        VStack(spacing: 8) {
                            ProgressView(value: viewModel.syncProgress)
                                .progressViewStyle(LinearProgressViewStyle())
                            
                            HStack {
                                Text("\(Int(viewModel.syncProgress * 100))% complete")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                if viewModel.syncedEventsCount > 0 {
                                    Text("\(viewModel.syncedEventsCount) events synced")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    
                    if let syncMessage = viewModel.syncMessage {
                        Text(syncMessage)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                if viewModel.syncStatus == .notStarted {
                    Button("Start Sync") {
                        Task {
                            await viewModel.performInitialSync()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isProcessing)
                } else if viewModel.syncStatus == .failed {
                    VStack(spacing: 12) {
                        Text("Sync failed")
                            .foregroundColor(.red)
                        
                        Button("Retry Sync") {
                            Task {
                                await viewModel.performInitialSync()
                            }
                        }
                        .buttonStyle(.bordered)
                        
                        Button("Skip for Now") {
                            Task {
                                await viewModel.skipInitialSync()
                            }
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                }
            }
        }
    }
}

// MARK: - Completion Step

struct CompletionStepView: View {
    @ObservedObject var viewModel: SyncOnboardingViewModel
    
    var body: some View {
        VStack(spacing: 24) {
            // Success animation or icon
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)
                .padding(.bottom, 8)
            
            // Title
            Text("Setup Complete!")
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            // Summary
            VStack(spacing: 16) {
                Text("Your TribeBoard calendar is now synchronized with Apple Calendar. Your events will stay in sync across all your devices.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                
                // Setup summary
                VStack(spacing: 12) {
                    SummaryRow(
                        icon: "checkmark.circle.fill",
                        title: "Calendar Access",
                        subtitle: "Granted",
                        color: .green
                    )
                    
                    SummaryRow(
                        icon: "checkmark.circle.fill",
                        title: "Calendars Created",
                        subtitle: "3 calendars in Apple Calendar",
                        color: .green
                    )
                    
                    SummaryRow(
                        icon: "checkmark.circle.fill",
                        title: "Initial Sync",
                        subtitle: viewModel.syncedEventsCount > 0 ? "\(viewModel.syncedEventsCount) events synced" : "Ready to sync",
                        color: .green
                    )
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Next steps
                VStack(alignment: .leading, spacing: 8) {
                    Text("What's Next:")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text("• Create events in TribeBoard or Apple Calendar")
                    Text("• Changes will sync automatically")
                    Text("• Manage sync settings anytime in Settings")
                    Text("• Family events are shared, personal events stay private")
                }
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }
}

struct SummaryRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

// MARK: - Permission Help View

struct PermissionHelpView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Why we need permission
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Why Calendar Access?")
                            .font(.headline)
                        
                        Text("TribeBoard needs calendar access to sync your events with Apple Calendar. This allows you to see your TribeBoard events in the built-in Calendar app and across all your Apple devices.")
                            .font(.body)
                    }
                    
                    // What we do with permission
                    VStack(alignment: .leading, spacing: 8) {
                        Text("What We Do")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("✓ Create dedicated TribeBoard calendars")
                            Text("✓ Sync your events between apps")
                            Text("✓ Keep family and personal events organized")
                            Text("✓ Maintain privacy for personal events")
                        }
                        .font(.subheadline)
                    }
                    
                    // What we don't do
                    VStack(alignment: .leading, spacing: 8) {
                        Text("What We Don't Do")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("✗ Access other calendar apps' events")
                            Text("✗ Modify existing non-TribeBoard events")
                            Text("✗ Share your calendar data with third parties")
                            Text("✗ Access calendars without your permission")
                        }
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    }
                    
                    // Troubleshooting
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Troubleshooting")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("If permission was denied:")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Text("1. Go to Settings > TribeBoard")
                            Text("2. Tap 'Calendars'")
                            Text("3. Enable calendar access")
                            Text("4. Return to TribeBoard")
                            
                            Button("Open Settings") {
                                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(settingsUrl)
                                }
                            }
                            .buttonStyle(.bordered)
                            .padding(.top, 8)
                        }
                        .font(.caption)
                    }
                }
                .padding()
            }
            .navigationTitle("Calendar Permission")
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
}

// MARK: - Preview

#Preview {
    let tempContainer = try! ModelContainerConfiguration.createInMemory()
    let mockEventKitManager = EventKitManager()
    let mockSyncService = CalendarSyncService(
        eventKitManager: mockEventKitManager,
        modelContext: tempContainer.mainContext
    )
    
    return SyncOnboardingView(
        userId: UUID(),
        syncService: mockSyncService,
        eventKitManager: mockEventKitManager,
        modelContext: tempContainer.mainContext
    )
}