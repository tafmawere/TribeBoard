import SwiftUI

/// Demo launcher view for accessing guided demo journeys
struct DemoLauncherView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedScenario: DemoScenario?
    @State private var showingDemoInfo = false
    
    private var demoManager: DemoJourneyManager? {
        appState.getDemoManager()
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header Section
                    headerSection
                    
                    // Quick Start Section
                    quickStartSection
                    
                    // HomeLife Features Section
                    homeLifeFeaturesSection
                    
                    // All Scenarios Section
                    allScenariosSection
                    
                    // Demo Controls Section
                    if let demoManager = demoManager, demoManager.isDemoModeActive {
                        activeDemoSection
                    }
                    
                    // Reset Section
                    resetSection
                }
                .padding()
            }
            .navigationTitle("Demo Center")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingDemoInfo = true
                    }) {
                        Image(systemName: "info.circle")
                    }
                }
            }
            .sheet(isPresented: $showingDemoInfo) {
                DemoInfoView()
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "play.rectangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.accentColor)
            
            VStack(spacing: 8) {
                Text("TribeBoard Demo Center")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Experience guided tours showcasing all features of the TribeBoard family management app")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    // MARK: - Quick Start Section
    
    private var quickStartSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Start")
                .font(.title2)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                QuickStartCard(
                    title: "New User",
                    subtitle: "First-time experience",
                    icon: "person.badge.plus",
                    color: .blue
                ) {
                    startDemo(.newUserOnboarding)
                }
                
                QuickStartCard(
                    title: "Existing User",
                    subtitle: "Returning user flow",
                    icon: "person.circle",
                    color: .green
                ) {
                    startDemo(.existingUserLogin)
                }
            }
        }
    }
    
    // MARK: - HomeLife Features Section
    
    private var homeLifeFeaturesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "house.heart.fill")
                    .font(.title2)
                    .foregroundColor(.brandPrimary)
                
                Text("HomeLife Features")
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            
            Text("Discover meal planning, grocery shopping, and task management features")
                .font(.body)
                .foregroundColor(.secondary)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                HomeLifeDemoCard(
                    title: "Meal Planning",
                    subtitle: "Plan & organize meals",
                    icon: "🍽️",
                    color: .brandPrimary
                ) {
                    startDemo(.homeLifeMealPlanning)
                }
                
                HomeLifeDemoCard(
                    title: "Grocery Shopping",
                    subtitle: "Manage shopping lists",
                    icon: "🛒",
                    color: .green
                ) {
                    startDemo(.homeLifeGroceryShopping)
                }
                
                HomeLifeDemoCard(
                    title: "Task Management",
                    subtitle: "Assign shopping tasks",
                    icon: "✅",
                    color: .orange
                ) {
                    startDemo(.homeLifeTaskManagement)
                }
                
                HomeLifeDemoCard(
                    title: "Complete Workflow",
                    subtitle: "Full HomeLife experience",
                    icon: "🏠",
                    color: .purple
                ) {
                    startDemo(.homeLifeCompleteWorkflow)
                }
            }
        }
    }
    
    // MARK: - All Scenarios Section
    
    private var allScenariosSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("All Demo Scenarios")
                .font(.title2)
                .fontWeight(.semibold)
            
            // Group scenarios by category
            ForEach(DemoCategory.allCases, id: \.self) { category in
                let scenariosInCategory = DemoScenario.allCases.filter { $0.category == category }
                
                if !scenariosInCategory.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: category.icon)
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            Text(category.displayName)
                                .font(.headline)
                                .foregroundColor(.secondary)
                        }
                        
                        LazyVStack(spacing: 8) {
                            ForEach(scenariosInCategory, id: \.self) { scenario in
                                DemoScenarioRow(scenario: scenario) {
                                    startDemo(scenario)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Active Demo Section
    
    private var activeDemoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Active Demo")
                .font(.title2)
                .fontWeight(.semibold)
            
            if let demoManager = demoManager {
                DemoControlPanel(demoManager: demoManager)
            }
        }
    }
    
    // MARK: - Reset Section
    
    private var resetSection: some View {
        VStack(spacing: 12) {
            Divider()
            
            VStack(spacing: 8) {
                Text("Reset Options")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Button(action: {
                    appState.resetToInitialState()
                }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Reset App to Initial State")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray5))
                    .cornerRadius(8)
                }
                .foregroundColor(.primary)
                
                Text("This will reset all demo data and return the app to its initial onboarding state")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func startDemo(_ scenario: DemoScenario) {
        appState.startGuidedDemo(scenario)
    }
}

// MARK: - Quick Start Card

struct QuickStartCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title)
                    .foregroundColor(color)
                
                VStack(spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Demo Scenario Row

struct DemoScenarioRow: View {
    let scenario: DemoScenario
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(scenario.displayName)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(scenario.description)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                    
                    HStack {
                        Image(systemName: "clock")
                            .font(.caption)
                        
                        Text(formatDuration(scenario.estimatedDuration))
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "play.circle.fill")
                    .font(.title2)
                    .foregroundColor(.accentColor)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
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

// MARK: - Demo Info View

struct DemoInfoView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("About TribeBoard Demos")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("What are Demo Journeys?")
                            .font(.headline)
                        
                        Text("Demo journeys are guided tours that showcase different aspects of the TribeBoard app. Each journey simulates real user interactions and demonstrates key features in a structured way.")
                            .font(.body)
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("How to Use Demos")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            DemoInfoItem(
                                icon: "1.circle.fill",
                                text: "Select a demo scenario that interests you"
                            )
                            
                            DemoInfoItem(
                                icon: "2.circle.fill",
                                text: "Follow the guided instructions as they appear"
                            )
                            
                            DemoInfoItem(
                                icon: "3.circle.fill",
                                text: "Use demo controls to pause, skip, or restart"
                            )
                            
                            DemoInfoItem(
                                icon: "4.circle.fill",
                                text: "Try different scenarios to see various user experiences"
                            )
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Demo Features")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            DemoInfoItem(
                                icon: "play.circle",
                                text: "Automated step progression with realistic timing"
                            )
                            
                            DemoInfoItem(
                                icon: "pause.circle",
                                text: "Pause and resume functionality"
                            )
                            
                            DemoInfoItem(
                                icon: "arrow.clockwise.circle",
                                text: "Reset to any point in the journey"
                            )
                            
                            DemoInfoItem(
                                icon: "person.3.sequence",
                                text: "Multiple user perspectives (admin, child, visitor)"
                            )
                        }
                    }
                    
                    Spacer(minLength: 20)
                }
                .padding()
            }
            .navigationTitle("Demo Information")
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

// MARK: - Demo Info Item

struct DemoInfoItem: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(.accentColor)
                .frame(width: 20)
            
            Text(text)
                .font(.body)
                .foregroundColor(.primary)
        }
    }
}

// MARK: - HomeLife Demo Card

struct HomeLifeDemoCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Text(icon)
                    .font(.system(size: 32))
                
                VStack(spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 120)
            .padding()
            .background(
                LinearGradient(
                    colors: [color.opacity(0.1), color.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(color.opacity(0.3), lineWidth: 1)
            )
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    DemoLauncherView()
        .environmentObject(AppState())
}

#Preview("HomeLife Demo Cards") {
    LazyVGrid(columns: [
        GridItem(.flexible()),
        GridItem(.flexible())
    ], spacing: 12) {
        HomeLifeDemoCard(
            title: "Meal Planning",
            subtitle: "Plan & organize meals",
            icon: "🍽️",
            color: .brandPrimary
        ) {}
        
        HomeLifeDemoCard(
            title: "Grocery Shopping",
            subtitle: "Manage shopping lists",
            icon: "🛒",
            color: .green
        ) {}
        
        HomeLifeDemoCard(
            title: "Task Management",
            subtitle: "Assign shopping tasks",
            icon: "✅",
            color: .orange
        ) {}
        
        HomeLifeDemoCard(
            title: "Complete Workflow",
            subtitle: "Full HomeLife experience",
            icon: "🏠",
            color: .purple
        ) {}
    }
    .padding()
}