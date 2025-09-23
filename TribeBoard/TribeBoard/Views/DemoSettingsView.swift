import SwiftUI

/// Demo settings view for configuring demo behavior and accessing demo features
struct DemoSettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingDemoLauncher = false
    @State private var showingResetConfirmation = false
    @State private var selectedErrorScenario: MockErrorScenario?
    
    private var demoManager: DemoJourneyManager? {
        appState.getDemoManager()
    }
    
    var body: some View {
        NavigationView {
            List {
                // Demo Status Section
                demoStatusSection
                
                // Demo Controls Section
                demoControlsSection
                
                // Demo Scenarios Section
                demoScenariosSection
                
                // Error Testing Section
                errorTestingSection
                
                // Reset Options Section
                resetOptionsSection
                
                // Demo Information Section
                demoInfoSection
            }
            .navigationTitle("Demo Settings")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingDemoLauncher) {
                DemoLauncherView()
                    .environmentObject(appState)
            }
            .confirmationDialog(
                "Reset Demo Data",
                isPresented: $showingResetConfirmation,
                titleVisibility: .visible
            ) {
                Button("Reset to Initial State", role: .destructive) {
                    appState.resetToInitialState()
                }
                
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will reset all demo data and return the app to its initial onboarding state. This action cannot be undone.")
            }
        }
    }
    
    // MARK: - Demo Status Section
    
    private var demoStatusSection: some View {
        Section("Demo Status") {
            if let demoManager = demoManager {
                HStack {
                    Image(systemName: demoManager.isDemoModeActive ? "play.circle.fill" : "pause.circle.fill")
                        .foregroundColor(demoManager.isDemoModeActive ? .green : .gray)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Demo Mode")
                            .font(.headline)
                        
                        Text(demoManager.isDemoModeActive ? "Active" : "Inactive")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if demoManager.isDemoModeActive {
                        VStack(alignment: .trailing, spacing: 2) {
                            if let scenario = demoManager.currentDemoScenario {
                                Text(scenario.displayName)
                                    .font(.caption)
                                    .foregroundColor(.primary)
                            }
                            
                            Text("\(Int(demoManager.demoProgress * 100))% Complete")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                if demoManager.isDemoModeActive {
                    HStack {
                        Button("Pause Demo") {
                            demoManager.pauseDemo()
                        }
                        .buttonStyle(.bordered)
                        .disabled(demoManager.isDemoPaused)
                        
                        Button("Resume Demo") {
                            demoManager.resumeDemo()
                        }
                        .buttonStyle(.bordered)
                        .disabled(!demoManager.isDemoPaused)
                        
                        Spacer()
                        
                        Button("Stop Demo") {
                            demoManager.stopDemo()
                        }
                        .buttonStyle(.bordered)
                        .foregroundColor(.red)
                    }
                }
            } else {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                    
                    Text("Demo Manager Not Available")
                        .font(.headline)
                }
            }
        }
    }
    
    // MARK: - Demo Controls Section
    
    private var demoControlsSection: some View {
        Section("Demo Controls") {
            Button(action: {
                showingDemoLauncher = true
            }) {
                HStack {
                    Image(systemName: "play.rectangle")
                        .foregroundColor(.accentColor)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Launch Demo Center")
                            .font(.headline)
                        
                        Text("Access all demo scenarios and guided tours")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .foregroundColor(.primary)
            
            if let currentUser = appState.currentUser {
                Button(action: {
                    switchUserScenario()
                }) {
                    HStack {
                        Image(systemName: "person.2.circle")
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Switch User Scenario")
                                .font(.headline)
                            
                            Text("Currently: \(currentUser.displayName)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .foregroundColor(.primary)
            }
        }
    }
    
    // MARK: - Demo Scenarios Section
    
    private var demoScenariosSection: some View {
        Section("Quick Start Scenarios") {
            ForEach(DemoScenario.allCases.prefix(3), id: \.self) { scenario in
                Button(action: {
                    appState.startGuidedDemo(scenario)
                }) {
                    HStack {
                        Image(systemName: iconForScenario(scenario))
                            .foregroundColor(colorForScenario(scenario))
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(scenario.displayName)
                                .font(.headline)
                            
                            Text(formatDuration(scenario.estimatedDuration))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "play.circle")
                            .font(.caption)
                            .foregroundColor(.accentColor)
                    }
                }
                .foregroundColor(.primary)
            }
        }
    }
    
    // MARK: - Error Testing Section
    
    private var errorTestingSection: some View {
        Section("Error Testing") {
            ForEach(MockErrorScenario.allCases, id: \.self) { errorScenario in
                Button(action: {
                    simulateError(errorScenario)
                }) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(errorScenario.displayName)
                                .font(.headline)
                            
                            Text(errorScenario.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "play.circle")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                .foregroundColor(.primary)
            }
        }
    }
    
    // MARK: - Reset Options Section
    
    private var resetOptionsSection: some View {
        Section("Reset Options") {
            Button(action: {
                showingResetConfirmation = true
            }) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.red)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Reset to Initial State")
                            .font(.headline)
                        
                        Text("Clear all demo data and return to onboarding")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .foregroundColor(.red)
            
            if let demoManager = demoManager, demoManager.isDemoModeActive {
                Button(action: {
                    demoManager.resetDemoToStart()
                }) {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Restart Current Demo")
                                .font(.headline)
                            
                            Text("Reset current demo to the beginning")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .foregroundColor(.blue)
            }
        }
    }
    
    // MARK: - Demo Information Section
    
    private var demoInfoSection: some View {
        Section("Information") {
            VStack(alignment: .leading, spacing: 8) {
                Text("About Demo Mode")
                    .font(.headline)
                
                Text("Demo mode provides guided tours of the TribeBoard app using mock data. All interactions are simulated and no real data is stored or transmitted.")
                    .font(.body)
                    .foregroundColor(.secondary)
                
                Text("Features:")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .padding(.top, 4)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("• Guided step-by-step tours")
                    Text("• Multiple user perspectives")
                    Text("• Realistic mock data")
                    Text("• Error scenario testing")
                    Text("• Offline functionality")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
    }
    
    // MARK: - Helper Methods
    
    private func switchUserScenario() {
        let scenarios: [UserJourneyScenario] = [.newUser, .existingUser, .familyAdmin, .childUser, .visitorUser]
        let currentIndex = scenarios.firstIndex(of: appState.currentScenario) ?? 0
        let nextIndex = (currentIndex + 1) % scenarios.count
        let nextScenario = scenarios[nextIndex]
        
        appState.configureDemoScenario(nextScenario)
    }
    
    private func simulateError(_ errorScenario: MockErrorScenario) {
        appState.simulateErrorScenario(errorScenario)
    }
    
    private func iconForScenario(_ scenario: DemoScenario) -> String {
        switch scenario {
        case .newUserOnboarding:
            return "person.badge.plus"
        case .existingUserLogin:
            return "person.circle"
        case .familyAdminTasks:
            return "person.3.sequence"
        case .childUserExperience:
            return "figure.child.circle"
        case .completeFeatureTour:
            return "map"
        }
    }
    
    private func colorForScenario(_ scenario: DemoScenario) -> Color {
        switch scenario {
        case .newUserOnboarding:
            return .blue
        case .existingUserLogin:
            return .green
        case .familyAdminTasks:
            return .purple
        case .childUserExperience:
            return .orange
        case .completeFeatureTour:
            return .red
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration / 60)
        let seconds = Int(duration.truncatingRemainder(dividingBy: 60))
        
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }
}

#Preview {
    DemoSettingsView()
        .environmentObject(AppState())
}