import SwiftUI
import SwiftData

/// Dashboard view for family calendar administrators
struct FamilyCalendarDashboardView: View {
    let familyId: UUID
    let currentUserId: UUID
    
    @StateObject private var coordinationService: FamilyEventCoordinationService
    @State private var dashboard: FamilyCalendarDashboard?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedDateRange = DateInterval(start: Date(), duration: 30 * 24 * 60 * 60) // 30 days
    @State private var showingBulkActions = false
    @State private var showingNotifications = false
    @State private var showingInvitations = false
    
    private var isAdmin: Bool {
        // This would be determined by checking permissions
        true // Placeholder
    }
    
    init(familyId: UUID, currentUserId: UUID, modelContext: ModelContext) {
        self.familyId = familyId
        self.currentUserId = currentUserId
        let permissionManager = CalendarPermissionManager(modelContext: modelContext)
        self._coordinationService = StateObject(wrappedValue: FamilyEventCoordinationService(
            modelContext: modelContext,
            permissionManager: permissionManager
        ))
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                headerSection
                
                if isLoading {
                    loadingSection
                } else if let errorMessage = errorMessage {
                    errorSection(errorMessage)
                } else if let dashboard = dashboard {
                    // Statistics overview
                    statisticsSection(dashboard)
                    
                    // Quick actions (admin only)
                    if isAdmin {
                        quickActionsSection
                    }
                    
                    // Recent activity
                    recentActivitySection(dashboard)
                    
                    // Notifications and invitations
                    notificationsSection(dashboard)
                }
            }
            .padding()
        }
        .navigationTitle("Family Calendar")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            loadDashboard()
        }
        .refreshable {
            loadDashboard()
        }
        .sheet(isPresented: $showingBulkActions) {
            BulkEventActionsView(
                familyId: familyId,
                currentUserId: currentUserId,
                coordinationService: coordinationService
            )
        }
        .sheet(isPresented: $showingNotifications) {
            FamilyNotificationsView(
                familyId: familyId,
                currentUserId: currentUserId,
                coordinationService: coordinationService
            )
        }
        .sheet(isPresented: $showingInvitations) {
            EventInvitationsView(
                currentUserId: currentUserId,
                coordinationService: coordinationService
            )
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "calendar.badge.clock")
                    .font(.title)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading) {
                    Text("Family Calendar Dashboard")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Manage family events and coordination")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isAdmin {
                    Button("Bulk Actions") {
                        showingBulkActions = true
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }
        }
    }
    
    private var loadingSection: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Loading dashboard...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    private func errorSection(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title)
                .foregroundColor(.orange)
            
            Text("Dashboard Error")
                .font(.headline)
                .fontWeight(.medium)
            
            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Retry") {
                loadDashboard()
            }
            .font(.caption)
            .foregroundColor(.blue)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    private func statisticsSection(_ dashboard: FamilyCalendarDashboard) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Overview")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                statisticCard(
                    title: "Total Events",
                    value: "\(dashboard.totalEvents)",
                    icon: "calendar.circle.fill",
                    color: .blue
                )
                
                statisticCard(
                    title: "Upcoming",
                    value: "\(dashboard.upcomingEvents)",
                    icon: "clock.circle.fill",
                    color: .green
                )
                
                statisticCard(
                    title: "Today",
                    value: "\(dashboard.todayEvents)",
                    icon: "calendar.badge.clock",
                    color: .orange
                )
                
                statisticCard(
                    title: "Notifications",
                    value: "\(dashboard.unreadNotifications)",
                    icon: "bell.circle.fill",
                    color: dashboard.unreadNotifications > 0 ? .red : .gray
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func statisticCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
    
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                quickActionButton(
                    title: "Bulk Operations",
                    icon: "square.stack.3d.up.fill",
                    color: .purple
                ) {
                    showingBulkActions = true
                }
                
                quickActionButton(
                    title: "Send Reminders",
                    icon: "bell.badge.fill",
                    color: .orange
                ) {
                    sendBulkReminders()
                }
                
                quickActionButton(
                    title: "Event Analytics",
                    icon: "chart.bar.fill",
                    color: .blue
                ) {
                    // Navigate to analytics
                }
                
                quickActionButton(
                    title: "Export Calendar",
                    icon: "square.and.arrow.up.fill",
                    color: .green
                ) {
                    exportCalendar()
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func quickActionButton(
        title: String,
        icon: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color(.systemBackground))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func recentActivitySection(_ dashboard: FamilyCalendarDashboard) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Events")
                .font(.headline)
                .fontWeight(.semibold)
            
            if dashboard.recentEvents.isEmpty {
                EmptyStateView(
                    icon: "calendar.badge.plus",
                    title: "No Recent Events",
                    message: "No family events in the selected time period."
                )
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(dashboard.recentEvents, id: \.id) { event in
                        RecentEventRowView(event: event)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func notificationsSection(_ dashboard: FamilyCalendarDashboard) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Notifications & Invitations")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if dashboard.unreadNotifications > 0 || dashboard.pendingInvitations > 0 {
                    Button("View All") {
                        showingNotifications = true
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }
            
            HStack(spacing: 16) {
                notificationSummaryCard(
                    title: "Unread",
                    count: dashboard.unreadNotifications,
                    icon: "bell.fill",
                    color: .red
                ) {
                    showingNotifications = true
                }
                
                notificationSummaryCard(
                    title: "Invitations",
                    count: dashboard.pendingInvitations,
                    icon: "envelope.fill",
                    color: .purple
                ) {
                    showingInvitations = true
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func notificationSummaryCard(
        title: String,
        count: Int,
        icon: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(count > 0 ? color : .gray)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(count)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text(title)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if count > 0 {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func loadDashboard() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let dashboardData = try await coordinationService.getFamilyCalendarDashboard(
                    familyId: familyId,
                    userId: currentUserId,
                    dateRange: selectedDateRange
                )
                
                await MainActor.run {
                    self.dashboard = dashboardData
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
    
    private func sendBulkReminders() {
        // Implementation for sending bulk reminders
        Task {
            // Get upcoming events and send reminders
        }
    }
    
    private func exportCalendar() {
        // Implementation for exporting calendar
    }
}

/// View for displaying recent event information
struct RecentEventRowView: View {
    let event: CalendarEvent
    
    var body: some View {
        HStack(spacing: 12) {
            // Event type indicator
            VStack {
                Image(systemName: event.privacyLevel.icon)
                    .font(.title3)
                    .foregroundColor(event.privacyLevel == .familyShared ? .blue : .green)
            }
            
            // Event details
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Text(event.dateRangeString)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let location = event.location {
                    HStack {
                        Image(systemName: "location.fill")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Text(location)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            
            Spacer()
            
            // Status indicator
            VStack {
                if event.isToday {
                    Text("Today")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange)
                        .cornerRadius(4)
                } else if event.isUpcoming {
                    Text("Upcoming")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: CalendarEvent.self, CalendarEventNotification.self, configurations: config)
    
    return NavigationView {
        FamilyCalendarDashboardView(
            familyId: UUID(),
            currentUserId: UUID(),
            modelContext: container.mainContext
        )
    }
}