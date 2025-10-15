import SwiftUI

/// Troubleshooting help view for the sync onboarding process
struct OnboardingTroubleshootingView: View {
    @ObservedObject var viewModel: SyncOnboardingViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Current step troubleshooting
                    currentStepTroubleshooting
                    
                    Divider()
                    
                    // General troubleshooting
                    generalTroubleshooting
                    
                    Divider()
                    
                    // Contact support
                    contactSupport
                }
                .padding()
            }
            .navigationTitle("Troubleshooting")
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
    
    // MARK: - Current Step Troubleshooting
    
    @ViewBuilder
    private var currentStepTroubleshooting: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Current Step: \(viewModel.currentStep.title)")
                .font(.headline)
            
            switch viewModel.currentStep {
            case .welcome:
                welcomeTroubleshooting
            case .permissions:
                permissionsTroubleshooting
            case .calendarSetup:
                calendarSetupTroubleshooting
            case .initialSync:
                syncTroubleshooting
            case .completion:
                completionTroubleshooting
            }
        }
    }
    
    private var welcomeTroubleshooting: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Getting Started")
                .font(.subheadline)
                .fontWeight(.semibold)
            
            Text("If you're having trouble getting started:")
                .font(.subheadline)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("• Make sure you have a stable internet connection")
                Text("• Ensure you're signed into iCloud on this device")
                Text("• Check that you have enough storage space")
                Text("• Try restarting the app if it seems unresponsive")
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
    }
    
    private var permissionsTroubleshooting: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Calendar Permission Issues")
                .font(.subheadline)
                .fontWeight(.semibold)
            
            if viewModel.permissionStatus == .denied {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Permission was denied. To fix this:")
                        .font(.subheadline)
                        .foregroundColor(.red)
                    
                    Text("1. Open the Settings app")
                    Text("2. Scroll down and find 'TribeBoard'")
                    Text("3. Tap on 'Calendars'")
                    Text("4. Enable calendar access")
                    Text("5. Return to TribeBoard and try again")
                    
                    Button("Open Settings") {
                        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(settingsUrl)
                        }
                    }
                    .buttonStyle(.bordered)
                    .padding(.top, 8)
                }
                .font(.caption)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("If the permission request doesn't appear:")
                        .font(.subheadline)
                    
                    Text("• Make sure you haven't previously denied permission")
                    Text("• Try force-closing and reopening TribeBoard")
                    Text("• Check if calendar access is restricted in Screen Time")
                    Text("• Restart your device if the issue persists")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
    }
    
    private var calendarSetupTroubleshooting: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Calendar Setup Issues")
                .font(.subheadline)
                .fontWeight(.semibold)
            
            if viewModel.calendarSetupStatus == .failed {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Calendar creation failed. Try these steps:")
                        .font(.subheadline)
                        .foregroundColor(.red)
                    
                    Text("1. Check your internet connection")
                    Text("2. Make sure you're signed into iCloud")
                    Text("3. Verify iCloud Calendar sync is enabled in Settings")
                    Text("4. Try the setup again")
                    
                    Button("Retry Setup") {
                        Task {
                            await viewModel.setupCalendars()
                        }
                    }
                    .buttonStyle(.bordered)
                    .padding(.top, 8)
                }
                .font(.caption)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("If calendar setup is taking too long:")
                        .font(.subheadline)
                    
                    Text("• Calendar creation requires an internet connection")
                    Text("• iCloud sync must be enabled for Calendars")
                    Text("• The process may take up to 30 seconds")
                    Text("• Try switching to Wi-Fi if on cellular data")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
    }
    
    private var syncTroubleshooting: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sync Issues")
                .font(.subheadline)
                .fontWeight(.semibold)
            
            if viewModel.syncStatus == .failed {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Initial sync failed. Try these solutions:")
                        .font(.subheadline)
                        .foregroundColor(.red)
                    
                    Text("1. Check your internet connection")
                    Text("2. Make sure iCloud is working properly")
                    Text("3. Try syncing again")
                    Text("4. You can skip initial sync and sync manually later")
                    
                    HStack(spacing: 12) {
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
                        .buttonStyle(.bordered)
                    }
                    .padding(.top, 8)
                }
                .font(.caption)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("If sync is taking too long:")
                        .font(.subheadline)
                    
                    Text("• Sync time depends on the number of events")
                    Text("• Large event collections may take several minutes")
                    Text("• Make sure you have a stable internet connection")
                    Text("• You can skip initial sync and sync manually later")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
    }
    
    private var completionTroubleshooting: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Setup Complete")
                .font(.subheadline)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Your sync setup is complete! If you experience issues later:")
                    .font(.subheadline)
                
                Text("• Check sync settings in the TribeBoard settings")
                Text("• Use the sync troubleshooting tools")
                Text("• Try a manual sync from the calendar view")
                Text("• Contact support if problems persist")
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
    }
    
    // MARK: - General Troubleshooting
    
    private var generalTroubleshooting: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("General Troubleshooting")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 16) {
                TroubleshootingSection(
                    title: "iCloud Issues",
                    items: [
                        "Make sure you're signed into iCloud",
                        "Check that Calendar sync is enabled in Settings > [Your Name] > iCloud",
                        "Verify you have available iCloud storage",
                        "Try signing out and back into iCloud if issues persist"
                    ]
                )
                
                TroubleshootingSection(
                    title: "Network Issues",
                    items: [
                        "Ensure you have a stable internet connection",
                        "Try switching between Wi-Fi and cellular data",
                        "Check if other apps can access the internet",
                        "Restart your router if using Wi-Fi"
                    ]
                )
                
                TroubleshootingSection(
                    title: "App Issues",
                    items: [
                        "Force close and reopen TribeBoard",
                        "Restart your device",
                        "Make sure TribeBoard is up to date",
                        "Try the setup process again from the beginning"
                    ]
                )
                
                TroubleshootingSection(
                    title: "Device Issues",
                    items: [
                        "Make sure your device has enough storage space",
                        "Check that your iOS version is supported",
                        "Disable any VPN or proxy connections temporarily",
                        "Check Screen Time restrictions for calendar access"
                    ]
                )
            }
        }
    }
    
    // MARK: - Contact Support
    
    private var contactSupport: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Still Need Help?")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("If you're still experiencing issues after trying these solutions, we're here to help!")
                    .font(.subheadline)
                
                VStack(spacing: 12) {
                    Button(action: {
                        // This would open email or support system
                        if let emailUrl = URL(string: "mailto:support@tribeboard.app?subject=Sync%20Setup%20Issue") {
                            UIApplication.shared.open(emailUrl)
                        }
                    }) {
                        HStack {
                            Image(systemName: "envelope")
                            Text("Email Support")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                        }
                    }
                    .buttonStyle(.bordered)
                    
                    Button(action: {
                        // This would export diagnostic information
                        exportDiagnosticInfo()
                    }) {
                        HStack {
                            Image(systemName: "doc.text")
                            Text("Export Diagnostic Info")
                            Spacer()
                            Image(systemName: "square.and.arrow.up")
                                .font(.caption)
                        }
                    }
                    .buttonStyle(.bordered)
                }
                
                Text("When contacting support, please include:")
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.top, 8)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("• Your device model and iOS version")
                    Text("• Which step you're having trouble with")
                    Text("• Any error messages you see")
                    Text("• Whether you're using Wi-Fi or cellular data")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func exportDiagnosticInfo() {
        // This would collect and export diagnostic information
        let diagnosticInfo = generateDiagnosticInfo()
        
        // Present share sheet with diagnostic info
        let activityVC = UIActivityViewController(
            activityItems: [diagnosticInfo],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityVC, animated: true)
        }
    }
    
    private func generateDiagnosticInfo() -> String {
        var info = "TribeBoard Sync Setup Diagnostic Information\n"
        info += "Generated: \(Date())\n\n"
        
        info += "Current Step: \(viewModel.currentStep.title)\n"
        info += "Permission Status: \(viewModel.permissionStatus.statusText)\n"
        info += "Calendar Setup Status: \(viewModel.calendarSetupStatus)\n"
        info += "Sync Status: \(viewModel.syncStatus.statusText)\n\n"
        
        info += "Device Information:\n"
        info += "iOS Version: \(UIDevice.current.systemVersion)\n"
        info += "Device Model: \(UIDevice.current.model)\n"
        info += "App Version: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")\n\n"
        
        info += "Completed Steps: \(viewModel.completedSteps.map { $0.title }.joined(separator: ", "))\n"
        
        if let syncMessage = viewModel.syncMessage {
            info += "Last Sync Message: \(syncMessage)\n"
        }
        
        return info
    }
}

// MARK: - Supporting Views

struct TroubleshootingSection: View {
    let title: String
    let items: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 4) {
                ForEach(items, id: \.self) { item in
                    Text("• \(item)")
                }
            }
            .font(.caption)
            .foregroundColor(.secondary)
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
    let mockViewModel = SyncOnboardingViewModel(
        userId: UUID(),
        syncService: mockSyncService,
        eventKitManager: mockEventKitManager,
        modelContext: tempContainer.mainContext
    )
    
    return OnboardingTroubleshootingView(viewModel: mockViewModel)
}