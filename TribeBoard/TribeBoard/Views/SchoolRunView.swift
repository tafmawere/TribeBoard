import SwiftUI
import Foundation

/// School Run Tracker View with mock pickup and drop-off schedules
struct SchoolRunView: View {
    @StateObject private var viewModel = SchoolRunViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 16) {
                    if viewModel.isLoading {
                        LoadingStateView(message: "Loading school runs...")
                    } else if viewModel.schoolRuns.isEmpty {
                        EmptyStateView(
                            icon: "car",
                            title: "No School Runs",
                            message: "No school runs scheduled for today."
                        )
                    } else {
                        // Today's School Runs Section
                        todaysRunsSection
                        
                        // Upcoming School Runs Section
                        upcomingRunsSection
                        
                        // Route Map Section
                        routeMapSection
                    }
                }
                .padding()
            }
            .navigationTitle("School Runs")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            viewModel.loadSchoolRuns()
        }
    }
    
    // MARK: - Today's Runs Section
    
    private var todaysRunsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "calendar.badge.clock")
                    .foregroundColor(.blue)
                Text("Today's Runs")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            ForEach(viewModel.todaysRuns, id: \.id) { schoolRun in
                PickupCard(
                    schoolRun: schoolRun,
                    userProfiles: viewModel.userProfiles,
                    onTrackRoute: {
                        viewModel.startTracking(schoolRun)
                    }
                )
            }
        }
    }
    
    // MARK: - Upcoming Runs Section
    
    private var upcomingRunsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundColor(.orange)
                Text("Upcoming Runs")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            ForEach(viewModel.upcomingRuns, id: \.id) { schoolRun in
                PickupCard(
                    schoolRun: schoolRun,
                    userProfiles: viewModel.userProfiles,
                    onTrackRoute: {
                        viewModel.startTracking(schoolRun)
                    }
                )
            }
        }
    }
    
    // MARK: - Route Map Section
    
    private var routeMapSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "map")
                    .foregroundColor(.green)
                Text("Route Navigation")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            if let activeRun = viewModel.activeTrackingRun,
               let trackingData = viewModel.trackingData {
                RouteMapView(
                    schoolRun: activeRun,
                    trackingData: trackingData,
                    onStopTracking: {
                        viewModel.stopTracking()
                    }
                )
            } else {
                RouteMapPlaceholder()
            }
        }
    }
}

// MARK: - Route Map Placeholder

private struct RouteMapPlaceholder: View {
    var body: some View {
        VStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1))
                .frame(height: 200)
                .overlay(
                    VStack(spacing: 8) {
                        Image(systemName: "map.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                        Text("Start a school run to see navigation")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                )
            
            Text("Tap 'Track Route' on any school run to see live navigation with mock GPS tracking.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}

// MARK: - Preview

#Preview {
    SchoolRunView()
}