import SwiftUI

/// Demo control panel for managing guided demo journeys
struct DemoControlPanel: View {
    @ObservedObject var demoManager: DemoJourneyManager
    @State private var showingScenarioSelection = false
    @State private var selectedScenario: DemoScenario?
    
    var body: some View {
        VStack(spacing: 16) {
            if demoManager.isDemoModeActive {
                activeDemoControls
            } else {
                demoSelectionControls
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 4)
        .sheet(isPresented: $showingScenarioSelection) {
            DemoScenarioSelectionView(
                demoManager: demoManager,
                selectedScenario: $selectedScenario,
                isPresented: $showingScenarioSelection
            )
        }
    }
    
    // MARK: - Active Demo Controls
    
    private var activeDemoControls: some View {
        VStack(spacing: 12) {
            // Demo Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Demo Mode Active")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if let scenario = demoManager.currentDemoScenario {
                        Text(scenario.displayName)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Button("Stop Demo") {
                    demoManager.stopDemo()
                }
                .buttonStyle(.bordered)
                .foregroundColor(.red)
            }
            
            // Progress Bar
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Progress")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(Int(demoManager.demoProgress * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                ProgressView(value: demoManager.demoProgress)
                    .progressViewStyle(LinearProgressViewStyle())
            }
            
            // Current Instructions
            if !demoManager.currentInstructions.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Current Step")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(demoManager.currentInstructions)
                        .font(.body)
                        .foregroundColor(.primary)
                        .padding(12)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
            }
            
            // Demo Controls
            HStack(spacing: 12) {
                Button(action: {
                    demoManager.previousDemoStep()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                }
                .buttonStyle(.bordered)
                .disabled(demoManager.currentStep == 0)
                
                if demoManager.isDemoPaused {
                    Button(action: {
                        demoManager.resumeDemo()
                    }) {
                        Image(systemName: "play.fill")
                            .font(.title2)
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button(action: {
                        demoManager.pauseDemo()
                    }) {
                        Image(systemName: "pause.fill")
                            .font(.title2)
                    }
                    .buttonStyle(.bordered)
                }
                
                Button(action: {
                    demoManager.nextDemoStep()
                }) {
                    Image(systemName: "chevron.right")
                        .font(.title2)
                }
                .buttonStyle(.bordered)
                .disabled(demoManager.isDemoCompleted)
                
                Spacer()
                
                Button(action: {
                    demoManager.resetDemoToStart()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.title2)
                }
                .buttonStyle(.bordered)
            }
            
            // Demo Completion
            if demoManager.isDemoCompleted {
                VStack(spacing: 8) {
                    Text("Demo Completed! 🎉")
                        .font(.headline)
                        .foregroundColor(.green)
                    
                    Button("Try Another Scenario") {
                        showingScenarioSelection = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }
    
    // MARK: - Demo Selection Controls
    
    private var demoSelectionControls: some View {
        VStack(spacing: 16) {
            // Header
            VStack(spacing: 8) {
                Text("TribeBoard Demo")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Experience guided tours of the app's features")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Quick Start Buttons
            VStack(spacing: 12) {
                Text("Quick Start")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    ForEach([DemoScenario.newUserOnboarding, .existingUserLogin], id: \.self) { scenario in
                        DemoScenarioCard(
                            scenario: scenario,
                            isCompact: true
                        ) {
                            demoManager.startDemoJourney(scenario)
                        }
                    }
                }
            }
            
            // All Scenarios Button
            Button(action: {
                showingScenarioSelection = true
            }) {
                HStack {
                    Text("View All Demo Scenarios")
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
            .foregroundColor(.primary)
            
            // Reset Button
            Button("Reset App to Initial State") {
                // This will reset the app without starting a demo
                demoManager.appState?.resetToInitialState()
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
    }
}

// MARK: - Demo Scenario Selection View

struct DemoScenarioSelectionView: View {
    @ObservedObject var demoManager: DemoJourneyManager
    @Binding var selectedScenario: DemoScenario?
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(DemoScenario.allCases, id: \.self) { scenario in
                        DemoScenarioCard(scenario: scenario) {
                            demoManager.startDemoJourney(scenario)
                            isPresented = false
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Demo Scenarios")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

// MARK: - Demo Scenario Card

struct DemoScenarioCard: View {
    let scenario: DemoScenario
    let isCompact: Bool
    let action: () -> Void
    
    init(scenario: DemoScenario, isCompact: Bool = false, action: @escaping () -> Void) {
        self.scenario = scenario
        self.isCompact = isCompact
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: isCompact ? 8 : 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(scenario.displayName)
                            .font(isCompact ? .subheadline : .headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        if !isCompact {
                            Text(formatDuration(scenario.estimatedDuration))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: "play.circle.fill")
                        .font(isCompact ? .title2 : .title)
                        .foregroundColor(.accentColor)
                }
                
                if !isCompact {
                    Text(scenario.description)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
            }
            .padding(isCompact ? 12 : 16)
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

// MARK: - Demo Control Overlay

/// Floating demo control overlay that can be shown over any view
struct DemoControlOverlay: View {
    @ObservedObject var demoManager: DemoJourneyManager
    @State private var isExpanded = false
    @State private var dragOffset = CGSize.zero
    
    var body: some View {
        VStack {
            Spacer()
            
            HStack {
                Spacer()
                
                VStack(spacing: 0) {
                    if isExpanded {
                        DemoControlPanel(demoManager: demoManager)
                            .transition(.scale.combined(with: .opacity))
                    }
                    
                    // Floating Action Button
                    Button(action: {
                        withAnimation(.spring()) {
                            isExpanded.toggle()
                        }
                    }) {
                        Image(systemName: demoManager.isDemoModeActive ? "stop.circle.fill" : "play.circle.fill")
                            .font(.title)
                            .foregroundColor(.white)
                            .frame(width: 56, height: 56)
                            .background(demoManager.isDemoModeActive ? Color.red : Color.accentColor)
                            .clipShape(Circle())
                            .shadow(radius: 4)
                    }
                }
                .offset(dragOffset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            dragOffset = value.translation
                        }
                        .onEnded { _ in
                            withAnimation(.spring()) {
                                dragOffset = .zero
                            }
                        }
                )
            }
        }
        .padding()
    }
}

#Preview {
    DemoControlPanel(demoManager: DemoJourneyManager())
}