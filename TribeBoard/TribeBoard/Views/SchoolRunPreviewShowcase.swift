import SwiftUI

/// Comprehensive preview showcase for all School Run Scheduler components and screens
struct SchoolRunPreviewShowcase: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Screen Previews
            ScreenPreviewsTab()
                .tabItem {
                    Image(systemName: "iphone")
                    Text("Screens")
                }
                .tag(0)
            
            // Component Previews
            ComponentPreviewsTab()
                .tabItem {
                    Image(systemName: "square.grid.2x2")
                    Text("Components")
                }
                .tag(1)
            
            // Accessibility Previews
            AccessibilityPreviewsTab()
                .tabItem {
                    Image(systemName: "accessibility")
                    Text("Accessibility")
                }
                .tag(2)
            
            // Interactive Demos
            InteractiveDemosTab()
                .tabItem {
                    Image(systemName: "hand.tap")
                    Text("Interactive")
                }
                .tag(3)
        }
        .navigationTitle("School Run Showcase")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Screen Previews Tab

struct ScreenPreviewsTab: View {
    var body: some View {
        NavigationView {
            List {
                Section("Main Screens") {
                    NavigationLink("Dashboard") {
                        SchoolRunPreviewProvider.previewWithSampleData {
                            SchoolRunDashboardView()
                        }
                    }
                    
                    NavigationLink("Schedule New Run") {
                        SchoolRunPreviewProvider.previewWithSampleData {
                            ScheduleNewRunView()
                        }
                    }
                    
                    NavigationLink("Scheduled Runs List") {
                        SchoolRunPreviewProvider.previewWithSampleData {
                            ScheduledRunsListView()
                        }
                    }
                    
                    NavigationLink("Run Detail") {
                        SchoolRunPreviewProvider.previewWithSampleData {
                            RunDetailView(run: SchoolRunPreviewProvider.upcomingRun)
                        }
                    }
                    
                    NavigationLink("Run Execution") {
                        SchoolRunPreviewProvider.previewWithSampleData {
                            RunExecutionView(run: SchoolRunPreviewProvider.executionRunStart)
                        }
                    }
                }
                
                Section("Screen States") {
                    NavigationLink("Dashboard - Empty State") {
                        SchoolRunPreviewProvider.previewWithSampleData {
                            SchoolRunDashboardView()
                                .onAppear {
                                    // Would show empty state
                                }
                        }
                    }
                    
                    NavigationLink("Run Detail - Completed") {
                        SchoolRunPreviewProvider.previewWithSampleData {
                            RunDetailView(run: SchoolRunPreviewProvider.completedRun)
                        }
                    }
                    
                    NavigationLink("Run Execution - Mid Progress") {
                        SchoolRunPreviewProvider.previewWithSampleData {
                            RunExecutionView(run: SchoolRunPreviewProvider.executionRunMidway)
                        }
                    }
                }
            }
            .navigationTitle("Screen Previews")
        }
    }
}

// MARK: - Component Previews Tab

struct ComponentPreviewsTab: View {
    var body: some View {
        NavigationView {
            List {
                Section("Card Components") {
                    NavigationLink("Run Summary Card") {
                        ComponentPreviewView {
                            VStack(spacing: DesignSystem.Spacing.lg) {
                                RunSummaryCard(run: SchoolRunPreviewProvider.upcomingRun)
                                RunSummaryCard(run: SchoolRunPreviewProvider.completedRun)
                                RunSummaryCard(run: SchoolRunPreviewProvider.longRun)
                            }
                        }
                    }
                    
                    NavigationLink("Run Overview Card") {
                        ComponentPreviewView {
                            VStack(spacing: DesignSystem.Spacing.lg) {
                                RunOverviewCard(run: SchoolRunPreviewProvider.upcomingRun)
                                RunOverviewCard(run: SchoolRunPreviewProvider.completedRun)
                            }
                        }
                    }
                    
                    NavigationLink("Current Stop Card") {
                        ComponentPreviewView {
                            VStack(spacing: DesignSystem.Spacing.lg) {
                                CurrentStopCard(
                                    stopNumber: 3,
                                    totalStops: 6,
                                    stop: SchoolRunPreviewProvider.sampleStops[1],
                                    isActive: true
                                )
                                
                                CurrentStopCard(
                                    stopNumber: 2,
                                    totalStops: 6,
                                    stop: SchoolRunPreviewProvider.sampleStops[0],
                                    isActive: false
                                )
                            }
                        }
                    }
                }
                
                Section("Form Components") {
                    NavigationLink("Stop Configuration Row") {
                        ComponentPreviewView {
                            VStack(spacing: DesignSystem.Spacing.lg) {
                                StopConfigurationRow(
                                    stop: .constant(SchoolRunPreviewProvider.sampleStops[1]),
                                    children: SchoolRunPreviewProvider.sampleChildren,
                                    stopNumber: 1,
                                    onDelete: {}
                                )
                                
                                StopConfigurationRow(
                                    stop: .constant(RunStop(
                                        name: "Custom Location",
                                        type: .custom,
                                        task: "Quick errand",
                                        estimatedMinutes: 15
                                    )),
                                    children: SchoolRunPreviewProvider.sampleChildren,
                                    stopNumber: 2,
                                    onDelete: {}
                                )
                            }
                        }
                    }
                    
                    NavigationLink("Stop Detail Row") {
                        ComponentPreviewView {
                            VStack(spacing: DesignSystem.Spacing.lg) {
                                StopDetailRow(
                                    stopNumber: 1,
                                    totalStops: 4,
                                    stop: SchoolRunPreviewProvider.sampleStops[0]
                                )
                                
                                StopDetailRow(
                                    stopNumber: 2,
                                    totalStops: 4,
                                    stop: SchoolRunPreviewProvider.sampleStops[1]
                                )
                                
                                StopDetailRow(
                                    stopNumber: 3,
                                    totalStops: 4,
                                    stop: RunStop(
                                        name: "Music Academy",
                                        type: .music,
                                        assignedChild: SchoolRunPreviewProvider.sampleChildren[1],
                                        task: "Drop off for lesson",
                                        estimatedMinutes: 15,
                                        isCompleted: true
                                    )
                                )
                            }
                        }
                    }
                }
                
                Section("UI Components") {
                    NavigationLink("Progress Indicators") {
                        ComponentPreviewView {
                            VStack(spacing: DesignSystem.Spacing.xl) {
                                ProgressIndicator(current: 3, total: 6)
                                
                                HStack {
                                    ProgressIndicator.circular(current: 2, total: 5, size: 80)
                                    ProgressIndicator.circular(current: 4, total: 5, size: 80)
                                }
                                
                                ProgressIndicator.mini(current: 3, total: 5)
                            }
                        }
                    }
                    
                    NavigationLink("Map Placeholders") {
                        ComponentPreviewView {
                            VStack(spacing: DesignSystem.Spacing.xl) {
                                SchoolRunMapPlaceholder(
                                    currentStop: SchoolRunPreviewProvider.sampleStops[1],
                                    showCurrentLocation: true,
                                    mapStyle: .overview
                                )
                                .frame(height: 200)
                                
                                SchoolRunMapPlaceholder(
                                    currentStop: SchoolRunPreviewProvider.sampleStops[0],
                                    showCurrentLocation: true,
                                    mapStyle: .execution
                                )
                                .frame(height: 200)
                                
                                HStack(spacing: DesignSystem.Spacing.md) {
                                    MapPlaceholderThumbnail(for: .home)
                                    MapPlaceholderThumbnail(for: .school)
                                    MapPlaceholderThumbnail(for: .music)
                                    MapPlaceholderThumbnail(for: .ot)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Component Previews")
        }
    }
}

// MARK: - Accessibility Previews Tab

struct AccessibilityPreviewsTab: View {
    var body: some View {
        NavigationView {
            List {
                Section("Dynamic Type") {
                    NavigationLink("Large Text - Dashboard") {
                        SchoolRunPreviewProvider.previewWithSampleData {
                            SchoolRunDashboardView()
                        }
                        .environment(\.dynamicTypeSize, .accessibility2)
                    }
                    
                    NavigationLink("Large Text - Form") {
                        SchoolRunPreviewProvider.previewWithSampleData {
                            ScheduleNewRunView()
                        }
                        .environment(\.dynamicTypeSize, .accessibility1)
                    }
                    
                    NavigationLink("Large Text - Components") {
                        ComponentPreviewView {
                            VStack(spacing: DesignSystem.Spacing.lg) {
                                RunSummaryCard(run: SchoolRunPreviewProvider.accessibilityTestRun)
                                
                                CurrentStopCard(
                                    stopNumber: 1,
                                    totalStops: 2,
                                    stop: RunStop(
                                        name: "Riverside Elementary School",
                                        type: .school,
                                        assignedChild: ChildProfile(name: "Emma-Louise", avatar: "person.circle.fill", age: 8),
                                        task: "Pick up Emma-Louise from her classroom and collect her art project",
                                        estimatedMinutes: 15
                                    ),
                                    isActive: true
                                )
                            }
                        }
                        .environment(\.dynamicTypeSize, .accessibility1)
                    }
                }
                
                Section("High Contrast") {
                    NavigationLink("High Contrast - Dashboard") {
                        SchoolRunPreviewProvider.previewWithSampleData {
                            SchoolRunDashboardView()
                        }
                    }
                    
                    NavigationLink("High Contrast - Components") {
                        ComponentPreviewView {
                            VStack(spacing: DesignSystem.Spacing.lg) {
                                RunSummaryCard(run: SchoolRunPreviewProvider.upcomingRun)
                                ProgressIndicator(current: 3, total: 6)
                                
                                CurrentStopCard(
                                    stopNumber: 2,
                                    totalStops: 4,
                                    stop: SchoolRunPreviewProvider.sampleStops[1],
                                    isActive: true
                                )
                            }
                        }
                    }
                }
                
                Section("Reduced Motion") {
                    NavigationLink("Reduced Motion - Execution") {
                        SchoolRunPreviewProvider.previewWithSampleData {
                            RunExecutionView(run: SchoolRunPreviewProvider.executionRunStart)
                        }
                    }
                    
                    NavigationLink("Reduced Motion - Components") {
                        ComponentPreviewView {
                            VStack(spacing: DesignSystem.Spacing.lg) {
                                SchoolRunMapPlaceholder(
                                    currentStop: SchoolRunPreviewProvider.sampleStops[1],
                                    showCurrentLocation: true,
                                    mapStyle: .execution
                                )
                                .frame(height: 200)
                                
                                ProgressIndicator(current: 3, total: 6)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Accessibility Previews")
        }
    }
}

// MARK: - Interactive Demos Tab

struct InteractiveDemosTab: View {
    var body: some View {
        NavigationView {
            List {
                Section("Interactive Flows") {
                    NavigationLink("Complete User Journey") {
                        InteractiveUserJourneyDemo()
                    }
                    
                    NavigationLink("Form Interaction Demo") {
                        InteractiveFormDemo()
                    }
                    
                    NavigationLink("Execution Flow Demo") {
                        InteractiveExecutionDemo()
                    }
                }
                
                Section("Component Interactions") {
                    NavigationLink("Button State Changes") {
                        InteractiveButtonDemo()
                    }
                    
                    NavigationLink("Progress Animation") {
                        InteractiveProgressDemo()
                    }
                    
                    NavigationLink("Card Interactions") {
                        InteractiveCardDemo()
                    }
                }
            }
            .navigationTitle("Interactive Demos")
        }
    }
}

// MARK: - Helper Views

struct ComponentPreviewView<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        ScrollView {
            content
                .screenPadding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Interactive Demo Views

struct InteractiveUserJourneyDemo: View {
    @State private var currentStep = 0
    private let steps = ["Dashboard", "Schedule", "List", "Detail", "Execution"]
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Text("User Journey Demo")
                .headlineLarge()
            
            Text("Step \(currentStep + 1) of \(steps.count): \(steps[currentStep])")
                .titleMedium()
                .foregroundColor(.brandPrimary)
            
            ProgressIndicator(current: currentStep + 1, total: steps.count)
            
            // Demo content based on current step
            Group {
                switch currentStep {
                case 0:
                    RunSummaryCard(run: SchoolRunPreviewProvider.upcomingRun)
                case 1:
                    StopConfigurationRow(
                        stop: .constant(SchoolRunPreviewProvider.sampleStops[1]),
                        children: SchoolRunPreviewProvider.sampleChildren,
                        stopNumber: 1,
                        onDelete: {}
                    )
                case 2:
                    RunListRowView(run: SchoolRunPreviewProvider.upcomingRun)
                case 3:
                    RunOverviewCard(run: SchoolRunPreviewProvider.upcomingRun)
                case 4:
                    CurrentStopCard(
                        stopNumber: 1,
                        totalStops: 4,
                        stop: SchoolRunPreviewProvider.sampleStops[0],
                        isActive: true
                    )
                default:
                    EmptyView()
                }
            }
            
            HStack {
                Button("Previous") {
                    if currentStep > 0 {
                        currentStep -= 1
                    }
                }
                .disabled(currentStep == 0)
                
                Spacer()
                
                Button("Next") {
                    if currentStep < steps.count - 1 {
                        currentStep += 1
                    }
                }
                .disabled(currentStep == steps.count - 1)
            }
            .buttonStyle(SecondaryButtonStyle())
            
            Spacer()
        }
        .screenPadding()
        .background(Color(.systemGroupedBackground))
        .navigationTitle("User Journey")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct InteractiveFormDemo: View {
    @State private var stops: [RunStop] = [
        RunStop(name: "", type: .home, task: "", estimatedMinutes: 5)
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spacing.lg) {
                Text("Interactive Form Demo")
                    .headlineLarge()
                
                ForEach(Array(stops.enumerated()), id: \.offset) { index, stop in
                    StopConfigurationRow(
                        stop: $stops[index],
                        children: SchoolRunPreviewProvider.sampleChildren,
                        stopNumber: index + 1,
                        onDelete: {
                            stops.remove(at: index)
                        }
                    )
                }
                
                Button("Add Stop") {
                    stops.append(RunStop(name: "", type: .home, task: "", estimatedMinutes: 5))
                }
                .buttonStyle(SecondaryButtonStyle())
                
                if !stops.isEmpty {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        Text("Form Summary")
                            .titleMedium()
                        
                        Text("Total stops: \(stops.count)")
                            .bodyMedium()
                        
                        Text("Total duration: \(stops.reduce(0) { $0 + $1.estimatedMinutes }) minutes")
                            .bodyMedium()
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                            .fill(Color(.systemGray6))
                    )
                }
            }
            .screenPadding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Form Demo")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct InteractiveExecutionDemo: View {
    @State private var currentStop = 0
    private let totalStops = 4
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Text("Execution Demo")
                .headlineLarge()
            
            SchoolRunMapPlaceholder(
                currentStop: SchoolRunPreviewProvider.sampleStops[min(currentStop, SchoolRunPreviewProvider.sampleStops.count - 1)],
                showCurrentLocation: true,
                mapStyle: .execution
            )
            .frame(height: 200)
            
            CurrentStopCard(
                stopNumber: currentStop + 1,
                totalStops: totalStops,
                stop: SchoolRunPreviewProvider.sampleStops[min(currentStop, SchoolRunPreviewProvider.sampleStops.count - 1)],
                isActive: true
            )
            
            ProgressIndicator(current: currentStop + 1, total: totalStops)
            
            HStack {
                Button("Previous Stop") {
                    if currentStop > 0 {
                        currentStop -= 1
                    }
                }
                .disabled(currentStop == 0)
                
                Spacer()
                
                Button("Complete Stop") {
                    if currentStop < totalStops - 1 {
                        currentStop += 1
                    }
                }
                .disabled(currentStop == totalStops - 1)
            }
            .buttonStyle(SecondaryButtonStyle())
            
            Spacer()
        }
        .screenPadding()
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Execution Demo")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct InteractiveButtonDemo: View {
    @State private var isPressed = false
    @State private var isLoading = false
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            Text("Button State Demo")
                .headlineLarge()
            
            VStack(spacing: DesignSystem.Spacing.lg) {
                Button("Primary Button") {
                    isPressed.toggle()
                }
                .buttonStyle(PrimaryButtonStyle())
                .scaleEffect(isPressed ? 0.95 : 1.0)
                .animation(.spring(response: 0.2), value: isPressed)
                
                Button(isLoading ? "Loading..." : "Secondary Button") {
                    isLoading = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        isLoading = false
                    }
                }
                .buttonStyle(SecondaryButtonStyle())
                .disabled(isLoading)
                
                Button("Destructive Button") {
                    // Demo action
                }
                .buttonStyle(DestructiveButtonStyle())
            }
            
            Spacer()
        }
        .screenPadding()
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Button Demo")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct InteractiveProgressDemo: View {
    @State private var progress = 1
    @State private var timer: Timer?
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            Text("Progress Animation Demo")
                .headlineLarge()
            
            VStack(spacing: DesignSystem.Spacing.lg) {
                ProgressIndicator(current: progress, total: 6)
                
                ProgressIndicator.circular(current: progress, total: 6, size: 120)
                
                ProgressIndicator.mini(current: progress, total: 6)
            }
            
            HStack {
                Button("Start Animation") {
                    startAnimation()
                }
                .buttonStyle(PrimaryButtonStyle())
                
                Button("Reset") {
                    stopAnimation()
                    progress = 1
                }
                .buttonStyle(SecondaryButtonStyle())
            }
            
            Spacer()
        }
        .screenPadding()
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Progress Demo")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            stopAnimation()
        }
    }
    
    private func startAnimation() {
        stopAnimation()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if progress < 6 {
                progress += 1
            } else {
                progress = 1
            }
        }
    }
    
    private func stopAnimation() {
        timer?.invalidate()
        timer = nil
    }
}

struct InteractiveCardDemo: View {
    @State private var selectedCard: Int? = nil
    
    var body: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spacing.lg) {
                Text("Card Interaction Demo")
                    .headlineLarge()
                
                ForEach(Array(SchoolRunPreviewProvider.allSampleRuns.enumerated()), id: \.offset) { index, run in
                    Button(action: {
                        selectedCard = selectedCard == index ? nil : index
                    }) {
                        RunSummaryCard(run: run)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .scaleEffect(selectedCard == index ? 1.05 : 1.0)
                    .animation(.spring(response: 0.3), value: selectedCard)
                }
            }
            .screenPadding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Card Demo")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Preview

#Preview("School Run Showcase") {
    NavigationStack {
        SchoolRunPreviewShowcase()
    }
}