import SwiftUI

/// Showcase view demonstrating all school run UI components
struct SchoolRunComponentsShowcase: View {
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationView {
            TabView(selection: $selectedTab) {
                // Run Cards Tab
                runCardsShowcase
                    .tabItem {
                        Image(systemName: "rectangle.stack")
                        Text("Run Cards")
                    }
                    .tag(0)
                
                // Stop Rows Tab
                stopRowsShowcase
                    .tabItem {
                        Image(systemName: "list.bullet")
                        Text("Stop Rows")
                    }
                    .tag(1)
                
                // Status Badges Tab
                statusBadgesShowcase
                    .tabItem {
                        Image(systemName: "tag")
                        Text("Status Badges")
                    }
                    .tag(2)
                
                // Quick Actions Tab
                quickActionsShowcase
                    .tabItem {
                        Image(systemName: "bolt")
                        Text("Quick Actions")
                    }
                    .tag(3)
            }
            .navigationTitle("School Run Components")
            .navigationBarTitleDisplayMode(.large)
        }
    }
    
    // MARK: - Run Cards Showcase
    
    private var runCardsShowcase: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spacing.lg) {
                Text("Run Card Components")
                    .headlineMedium()
                    .padding(.top)
                
                // Sample runs with different states
                ForEach(sampleRuns) { run in
                    RunCard(
                        run: run,
                        onTap: { 
                            print("Tapped run: \(run.title)")
                        },
                        onStart: run.status.canStart ? {
                            print("Start run: \(run.title)")
                        } : nil,
                        onEdit: run.status.canEdit ? {
                            print("Edit run: \(run.title)")
                        } : nil,
                        onDelete: run.status.canDelete ? {
                            print("Delete run: \(run.title)")
                        } : nil
                    )
                }
            }
            .screenPadding()
        }
    }
    
    // MARK: - Stop Rows Showcase
    
    private var stopRowsShowcase: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spacing.xl) {
                Text("Stop Row Components")
                    .headlineMedium()
                    .padding(.top)
                
                // Full stop rows
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                    Text("Full Stop Rows")
                        .titleMedium()
                    
                    VStack(spacing: DesignSystem.Spacing.sm) {
                        ForEach(sampleStops) { stop in
                            StopRow(
                                stop: stop,
                                onTap: {
                                    print("Tapped stop: \(stop.name)")
                                },
                                onToggleComplete: {
                                    print("Toggle complete: \(stop.name)")
                                }
                            )
                        }
                    }
                }
                
                // Compact stop rows
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                    Text("Compact Stop Rows")
                        .titleMedium()
                    
                    VStack(spacing: DesignSystem.Spacing.xs) {
                        ForEach(sampleStops) { stop in
                            CompactStopRow(
                                stop: stop,
                                onTap: {
                                    print("Tapped compact stop: \(stop.name)")
                                }
                            )
                        }
                    }
                }
                
                // Stop rows without status
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                    Text("Stop Rows (Planning Mode)")
                        .titleMedium()
                    
                    VStack(spacing: DesignSystem.Spacing.sm) {
                        ForEach(sampleStops.prefix(2)) { stop in
                            StopRow(
                                stop: stop,
                                showStatus: false,
                                onTap: {
                                    print("Tapped planning stop: \(stop.name)")
                                }
                            )
                        }
                    }
                }
            }
            .screenPadding()
        }
    }
    
    // MARK: - Status Badges Showcase
    
    private var statusBadgesShowcase: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spacing.xl) {
                Text("Status Badge Components")
                    .headlineMedium()
                    .padding(.top)
                
                // Standard badges
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                    Text("Standard Badges")
                        .titleMedium()
                    
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        ForEach(RunStatus.allCases, id: \.self) { status in
                            HStack {
                                RunStatusBadge(status: status, style: .standard)
                                Spacer()
                                Text(status.displayText)
                                    .bodySmall()
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                // Style variants
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                    Text("Style Variants")
                        .titleMedium()
                    
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        HStack {
                            Text("Large:")
                                .bodySmall()
                                .frame(width: 80, alignment: .leading)
                            RunStatusBadge(status: .inProgress, style: .large)
                            Spacer()
                        }
                        
                        HStack {
                            Text("Standard:")
                                .bodySmall()
                                .frame(width: 80, alignment: .leading)
                            RunStatusBadge(status: .inProgress, style: .standard)
                            Spacer()
                        }
                        
                        HStack {
                            Text("Compact:")
                                .bodySmall()
                                .frame(width: 80, alignment: .leading)
                            RunStatusBadge(status: .inProgress, style: .compact)
                            Spacer()
                        }
                        
                        HStack {
                            Text("Minimal:")
                                .bodySmall()
                                .frame(width: 80, alignment: .leading)
                            RunStatusBadge(status: .inProgress, style: .minimal)
                            Spacer()
                        }
                    }
                }
                
                // Animated badges
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                    Text("Animated Badges")
                        .titleMedium()
                    
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        HStack {
                            Text("In Progress:")
                                .bodySmall()
                                .frame(width: 100, alignment: .leading)
                            AnimatedRunStatusBadge(status: .inProgress, style: .standard)
                            Spacer()
                        }
                        
                        HStack {
                            Text("Completed:")
                                .bodySmall()
                                .frame(width: 100, alignment: .leading)
                            AnimatedRunStatusBadge(status: .completed, style: .standard)
                            Spacer()
                        }
                    }
                }
                
                // Progress badges
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                    Text("Progress Badges")
                        .titleMedium()
                    
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        StatusProgressBadge(status: .inProgress, progress: 0.3, style: .standard)
                        StatusProgressBadge(status: .inProgress, progress: 0.7, style: .compact)
                        StatusProgressBadge(status: .completed, progress: 1.0, style: .standard)
                    }
                }
            }
            .screenPadding()
        }
    }
    
    // MARK: - Quick Actions Showcase
    
    private var quickActionsShowcase: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spacing.xl) {
                Text("Quick Action Components")
                    .headlineMedium()
                    .padding(.top)
                
                // School run actions
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                    Text("School Run Actions")
                        .titleMedium()
                    
                    QuickActionButtons.schoolRunActions(
                        onNewRun: { print("New Run") },
                        onHistory: { print("History") },
                        onSettings: { print("Settings") }
                    )
                }
                
                // Active run actions
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                    Text("Active Run Actions")
                        .titleMedium()
                    
                    QuickActionButtons.activeRunActions(
                        onNextStop: { print("Next Stop") },
                        onPause: { print("Pause") },
                        onEndRun: { print("End Run") }
                    )
                }
                
                // Run management actions
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                    Text("Run Management Actions")
                        .titleMedium()
                    
                    QuickActionButtons.runManagementActions(
                        onEdit: { print("Edit") },
                        onDuplicate: { print("Duplicate") },
                        onDelete: { print("Delete") }
                    )
                }
                
                // Grid layout
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                    Text("Grid Layout (2 Columns)")
                        .titleMedium()
                    
                    let gridActions = [
                        QuickActionButtons.QuickAction(title: "Start", icon: "play.fill", color: .green) { print("Start") },
                        QuickActionButtons.QuickAction(title: "Edit", icon: "pencil", color: .blue) { print("Edit") },
                        QuickActionButtons.QuickAction(title: "Share", icon: "square.and.arrow.up", color: .purple) { print("Share") },
                        QuickActionButtons.QuickAction(title: "Delete", icon: "trash", color: .red) { print("Delete") }
                    ]
                    
                    QuickActionButtons(actions: gridActions, layout: .grid(columns: 2))
                }
                
                // Button style variants
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                    Text("Button Style Variants")
                        .titleMedium()
                    
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        HStack {
                            Text("Sample Button:")
                                .bodySmall()
                                .frame(width: 80, alignment: .leading)
                            QuickActionButton(
                                title: "Sample Action",
                                icon: "star.fill",
                                color: .yellow,
                                action: { print("Sample") }
                            )
                            Spacer()
                        }
                        
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                            Text("Another Button:")
                                .bodySmall()
                            QuickActionButton(
                                title: "Another Action",
                                icon: "heart.fill",
                                color: .red,
                                action: { print("Another") }
                            )
                            .frame(width: 120)
                        }
                    }
                }
            }
            .screenPadding()
        }
    }
    
    // MARK: - Sample Data
    
    private var sampleRuns: [SchoolRun] {
        [
            SchoolRun(
                title: "Morning School Run",
                date: Date(),
                route: [
                    RunStop(name: "Home", time: Date(), note: "Pick up Emma", type: .pickup),
                    RunStop(name: "Emma's House", time: Date().addingTimeInterval(300), note: "Pick up Sarah", type: .pickup),
                    RunStop(name: "Greenwood Elementary", time: Date().addingTimeInterval(900), type: .dropoff)
                ],
                status: .scheduled,
                estimatedDuration: 1800
            ),
            SchoolRun(
                title: "Afternoon Pickup",
                date: Date(),
                route: [
                    RunStop(name: "Greenwood Elementary", time: Date(), type: .pickup, isCompleted: true),
                    RunStop(name: "Emma's House", time: Date().addingTimeInterval(600), type: .dropoff),
                    RunStop(name: "Home", time: Date().addingTimeInterval(1200), type: .dropoff)
                ],
                status: .inProgress,
                estimatedDuration: 1500
            ),
            SchoolRun(
                title: "Soccer Practice Run",
                date: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date(),
                route: [
                    RunStop(name: "Home", time: Date(), type: .pickup, isCompleted: true),
                    RunStop(name: "Soccer Field", time: Date().addingTimeInterval(900), type: .dropoff, isCompleted: true)
                ],
                status: .completed,
                estimatedDuration: 1200
            ),
            SchoolRun(
                title: "Cancelled Piano Lesson",
                date: Date(),
                route: [
                    RunStop(name: "Home", time: Date(), type: .pickup),
                    RunStop(name: "Music School", time: Date().addingTimeInterval(1200), type: .dropoff)
                ],
                status: .cancelled,
                estimatedDuration: 1800
            )
        ]
    }
    
    private var sampleStops: [RunStop] {
        [
            RunStop(
                name: "Home",
                time: Date(),
                note: "Pick up Emma and backpack",
                type: .pickup,
                isCompleted: false
            ),
            RunStop(
                name: "Emma's House",
                time: Date().addingTimeInterval(300),
                note: "Pick up Emma's friend Sarah",
                type: .pickup,
                isCompleted: true
            ),
            RunStop(
                name: "Greenwood Elementary School",
                time: Date().addingTimeInterval(900),
                note: "Drop off at main entrance",
                type: .dropoff,
                isCompleted: false
            ),
            RunStop(
                name: "Soccer Field",
                time: Date().addingTimeInterval(1800),
                note: "",
                type: .dropoff,
                isCompleted: false
            )
        ]
    }
}

// MARK: - Preview

#Preview("School Run Components Showcase") {
    SchoolRunComponentsShowcase()
}