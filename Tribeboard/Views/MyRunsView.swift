//
//  MyRunsView.swift
//  Tribeboard
//
//  Created by Kiro on 2026/02/05.
//

import SwiftUI
import MapKit

/// My Runs screen with Today/Upcoming/History tabs
/// Requirement 3: My Runs Screen
@MainActor
struct MyRunsView: View {
    @StateObject private var viewModel: HomeDashboardViewModel
    @EnvironmentObject private var appCoordinator: AppCoordinator
    @State private var selectedTab: RunTab = .today
    
    // Schedule preview support
    private let scheduleRunGenerator: ScheduleRunGenerator
    @State private var schedulePreviews: [ScheduledRunPreview] = []
    
    enum RunTab: String, CaseIterable {
        case today = "Today"
        case upcoming = "Upcoming"
        case history = "History"
    }
    
    init(viewModel: HomeDashboardViewModel, scheduleRunGenerator: ScheduleRunGenerator) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.scheduleRunGenerator = scheduleRunGenerator
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Tab Selector
                Picker("", selection: $selectedTab) {
                    ForEach(RunTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                
                // Content
                if viewModel.isLoading {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            // Active Now Card (only on Today tab)
                            if selectedTab == .today, let activeRun = viewModel.activeRun {
                                activeNowCard(run: activeRun)
                            }
                            
                            // Run List
                            let filteredRuns = getFilteredRuns()
                            let filteredPreviews = getFilteredPreviews()
                            
                            if filteredRuns.isEmpty && filteredPreviews.isEmpty {
                                emptyStateView()
                            } else {
                                // Schedule previews section (if any)
                                if !filteredPreviews.isEmpty {
                                    schedulePreviewsSection(previews: filteredPreviews)
                                }
                                
                                // Regular runs section (if any)
                                if !filteredRuns.isEmpty {
                                    runListSection(runs: filteredRuns)
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("My Runs")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        Button(action: {
                            appCoordinator.presentSheet(.calendar)
                        }) {
                            Image(systemName: "calendar")
                        }
                        
                        Button(action: {
                            appCoordinator.presentSheet(.runCreation)
                        }) {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .refreshable {
                await viewModel.refreshData()
                loadSchedulePreviews()
            }
            .task {
                loadSchedulePreviews()
            }
            .onChange(of: selectedTab) {
                loadSchedulePreviews()
            }
            .sheet(item: $appCoordinator.presentedSheet) { sheet in
                appCoordinator.createSheetView(for: sheet)
            }
        }
    }
    
    // MARK: - Active Now Card
    
    @ViewBuilder
    private func activeNowCard(run: Run) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Active Now")
                .font(.headline)
                .foregroundColor(.orange)
            
            // Compact Map
            Map {
                if let location = run.lastLocation {
                    Marker("Driver", coordinate: CLLocationCoordinate2D(
                        latitude: location.latitude,
                        longitude: location.longitude
                    ))
                    .tint(.blue)
                }
                
                // Show stops
                ForEach(run.stops) { stop in
                    Marker(stop.label, coordinate: stop.location.coordinate)
                        .tint(stop.type == .pickup ? .green : .red)
                }
            }
            .frame(height: 200)
            .cornerRadius(12)
            
            // Run Info
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(run.title)
                        .font(.headline)
                    Text(run.status.displayName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: {
                    appCoordinator.presentSheet(.runDetail(runId: run.id))
                }) {
                    Text("View Details")
                        .font(.subheadline)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
    
    // MARK: - Run List Section
    
    @ViewBuilder
    private func runListSection(runs: [Run]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if selectedTab == .today {
                Text("Next Up")
                    .font(.headline)
                    .padding(.horizontal, 4)
            }
            
            ForEach(runs) { run in
                RunCardView(
                    run: run,
                    showActions: true,
                    onTap: {
                        appCoordinator.presentSheet(.runDetail(runId: run.id))
                    },
                    onStartRun: canStartRun(run) ? {
                        startRun(run)
                    } : nil
                )
            }
        }
    }
    
    // MARK: - Schedule Previews Section
    
    @ViewBuilder
    private func schedulePreviewsSection(previews: [ScheduledRunPreview]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Scheduled (from Calendar)")
                .font(.headline)
                .padding(.horizontal, 4)
            
            ForEach(previews) { preview in
                Button(action: {
                    // Navigate to DayScheduleListView for the preview's date
                    let calendar = Calendar.current
                    let date = calendar.startOfDay(for: preview.occurrenceDateTime)
                    appCoordinator.presentSheet(.dayScheduleList(date: date))
                }) {
                    SchedulePreviewCard(preview: preview)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
    
    // MARK: - Actions
    
    /// Start a run and navigate to driver focus mode
    private func startRun(_ run: Run) {
        Task {
            do {
                // Start the run using the ViewModel method
                try await viewModel.startRun(runId: run.id)
                
                // Navigate to driver focus mode
                appCoordinator.navigate(to: .driverFocusMode(runId: run.id))
            } catch {
                print("❌ Failed to start run: \(error.localizedDescription)")
                // Show error to user
                appCoordinator.showAlert(message: "Failed to start run: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Empty State
    
    @ViewBuilder
    private func emptyStateView() -> some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "car.fill")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No runs \(selectedTab.rawValue.lowercased())")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Create a run to get started")
                .font(.body)
                .foregroundColor(.secondary)
            
            Button(action: {
                appCoordinator.presentSheet(.runCreation)
            }) {
                Text("Create a Run")
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Helper Methods
    
    /// Load schedule previews based on selected tab
    private func loadSchedulePreviews() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        switch selectedTab {
        case .today:
            // Load previews for today
            schedulePreviews = scheduleRunGenerator.occurrences(on: today)
                .sorted { $0.occurrenceDateTime < $1.occurrenceDateTime }
            
        case .upcoming:
            // Load previews for next 7-14 days
            guard let startDate = calendar.date(byAdding: .day, value: 1, to: today),
                  let endDate = calendar.date(byAdding: .day, value: 14, to: today) else {
                schedulePreviews = []
                return
            }
            
            schedulePreviews = scheduleRunGenerator.occurrences(in: startDate...endDate)
                .sorted { $0.occurrenceDateTime < $1.occurrenceDateTime }
            
        case .history:
            // No schedule previews in history
            schedulePreviews = []
        }
    }
    
    /// Get filtered schedule previews based on selected tab
    private func getFilteredPreviews() -> [ScheduledRunPreview] {
        return schedulePreviews
    }
    
    private func getFilteredRuns() -> [Run] {
        let allRuns = viewModel.getDisplayRuns()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        
        switch selectedTab {
        case .today:
            // Today: scheduled runs for today (excluding active run shown in card)
            return allRuns.filter { run in
                run.scheduledTime >= today &&
                run.scheduledTime < tomorrow &&
                run.status == .scheduled
            }
            .sorted { $0.scheduledTime < $1.scheduledTime }
            
        case .upcoming:
            // Upcoming: future scheduled runs
            return allRuns.filter { run in
                run.scheduledTime >= tomorrow &&
                run.status == .scheduled
            }
            .sorted { $0.scheduledTime < $1.scheduledTime }
            
        case .history:
            // History: completed or cancelled runs
            return allRuns.filter { run in
                run.status == .completed || run.status == .cancelled
            }
            .sorted { $0.scheduledTime > $1.scheduledTime }
        }
    }
    
    private func canStartRun(_ run: Run) -> Bool {
        // Check if user is driver and run is scheduled
        return run.status == .scheduled &&
               run.driverId == viewModel.currentUser.id
    }
}
