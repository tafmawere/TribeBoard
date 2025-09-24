import SwiftUI

/// Mock family dashboard view with comprehensive widgets and mock data
struct MockFamilyDashboardView: View {
    @StateObject private var viewModel: MockFamilyDashboardViewModel
    @EnvironmentObject var appState: AppState
    
    // MARK: - Initialization
    
    init(family: Family, currentUserId: UUID, currentUserRole: Role) {
        self._viewModel = StateObject(wrappedValue: MockFamilyDashboardViewModel(
            family: family,
            currentUserId: currentUserId,
            currentUserRole: currentUserRole
        ))
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                LinearGradient(
                    colors: [Color(.systemGroupedBackground), Color(.systemBackground)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                if viewModel.isLoading && viewModel.members.isEmpty {
                    // Initial loading state
                    LoadingStateView(
                        message: "Loading family dashboard...",
                        style: .card
                    )
                    .padding()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 20) {
                            // Family header with enhanced info
                            familyHeaderView
                            
                            // Activity summary cards
                            activitySummaryView
                            
                            // Quick actions section
                            quickActionsView
                            
                            // Dashboard widgets
                            dashboardWidgetsView
                            
                            // Members section
                            membersSection
                            
                            // Admin controls section
                            if viewModel.canManageMembers {
                                adminControlsSection
                            }
                        }
                        .padding()
                    }
                    .refreshable {
                        await viewModel.refreshDashboardData()
                    }
                }
            }
            .navigationTitle("Family Dashboard")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Refresh Dashboard") {
                            Task {
                                await viewModel.refreshDashboardData()
                            }
                        }
                        
                        Button("View All Modules") {
                            // Navigate to module overview
                        }
                        
                        Divider()
                        
                        Button("Family Settings") {
                            viewModel.showSettings()
                        }
                        
                        Button("Leave Family", role: .destructive) {
                            appState.leaveFamily()
                        }
                        
                        Button("Sign Out", role: .destructive) {
                            Task {
                                await appState.signOut()
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .task {
            await viewModel.loadMembers()
        }
        .withToast()
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.clearErrorMessage()
            }
        } message: {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
            }
        }
        .sheet(isPresented: $viewModel.showRoleChangeSheet) {
            if let member = viewModel.selectedMember {
                RoleChangeSheet(
                    member: member,
                    userProfile: viewModel.userProfile(for: member),
                    onRoleChange: { newRole in
                        Task {
                            await viewModel.changeRole(for: member, to: newRole)
                        }
                    }
                )
            }
        }
        .sheet(isPresented: $viewModel.showCalendarView) {
            CalendarView()
        }
        .sheet(isPresented: $viewModel.showTasksView) {
            if let currentUser = appState.currentUser {
                TasksView(
                    currentUserId: currentUser.id,
                    currentUserRole: viewModel.currentUserRole
                )
            }
        }
        .sheet(isPresented: $viewModel.showMessagesView) {
            if let currentUser = appState.currentUser {
                MessagingView(
                    currentUserId: currentUser.id,
                    currentUserRole: viewModel.currentUserRole
                )
            }
        }
        .sheet(isPresented: $viewModel.showSchoolRunView) {
            SchoolRunView()
        }
        .sheet(isPresented: $viewModel.showSettingsView) {
            if let currentUser = appState.currentUser {
                SettingsView(
                    currentUserId: currentUser.id,
                    currentUserRole: viewModel.currentUserRole
                )
            }
        }
        .confirmationDialog(
            "Remove Member",
            isPresented: $viewModel.showRemovalConfirmation,
            titleVisibility: .visible
        ) {
            if let member = viewModel.memberToRemove,
               let profile = viewModel.userProfile(for: member) {
                Button("Remove \(profile.displayName)", role: .destructive) {
                    Task {
                        await viewModel.removeMember(member)
                    }
                }
                Button("Cancel", role: .cancel) {
                    viewModel.memberToRemove = nil
                }
            }
        } message: {
            if let member = viewModel.memberToRemove,
               let profile = viewModel.userProfile(for: member) {
                Text("Are you sure you want to remove \(profile.displayName) from the family? This action cannot be undone.")
            }
        }
    }
    
    // MARK: - View Components
    
    private var familyHeaderView: some View {
        VStack(spacing: 16) {
            // Family name with icon
            HStack {
                Image(systemName: "house.fill")
                    .foregroundColor(.brandPrimary)
                    .font(.title2)
                
                if let family = appState.currentFamily {
                    Text(family.name)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                // Family code badge
                if let family = appState.currentFamily {
                    Text(family.code)
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.brandPrimary.opacity(0.1))
                        .foregroundColor(.brandPrimary)
                        .cornerRadius(8)
                }
            }
            
            // Current user info
            HStack {
                MemberAvatarView(userProfile: appState.currentUser)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(appState.currentUser?.displayName ?? "Current User")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    RoleBadge(role: viewModel.currentUserRole)
                }
                
                Spacer()
                
                // Member count
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(viewModel.members.count)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.brandPrimary)
                    
                    Text("Members")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    private var activitySummaryView: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            ActivitySummaryCard(
                title: "Pending Tasks",
                value: "\(viewModel.activitySummary.pendingTasks)",
                icon: "checklist",
                color: .orange
            )
            
            ActivitySummaryCard(
                title: "Completed Today",
                value: "\(viewModel.activitySummary.completedTasksToday)",
                icon: "checkmark.circle.fill",
                color: .green
            )
            
            ActivitySummaryCard(
                title: "Unread Messages",
                value: "\(viewModel.activitySummary.unreadMessages)",
                icon: "message.fill",
                color: .blue
            )
            
            ActivitySummaryCard(
                title: "Total Points",
                value: "\(viewModel.activitySummary.totalPoints)",
                icon: "star.fill",
                color: .yellow
            )
        }
    }
    
    private var quickActionsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)
                .fontWeight(.semibold)
                .padding(.horizontal, 4)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                QuickActionButton(
                    title: "Calendar",
                    icon: "calendar",
                    color: .blue,
                    action: {
                        viewModel.showCalendar()
                    }
                )
                
                QuickActionButton(
                    title: "Tasks",
                    icon: "checklist",
                    color: .orange,
                    action: {
                        viewModel.showTasks()
                    }
                )
                
                QuickActionButton(
                    title: "Messages",
                    icon: "message",
                    color: .green,
                    action: {
                        viewModel.showMessages()
                    }
                )
                
                QuickActionButton(
                    title: "School Run",
                    icon: "car",
                    color: .purple,
                    action: {
                        viewModel.showSchoolRun()
                    }
                )
                
                QuickActionButton(
                    title: "Settings",
                    icon: "gearshape",
                    color: .gray,
                    action: {
                        viewModel.showSettings()
                    }
                )
                
                QuickActionButton(
                    title: "Add Member",
                    icon: "person.badge.plus",
                    color: .brandPrimary,
                    action: {
                        // Navigate to add member
                        viewModel.successMessage = "Add Member feature coming soon!"
                    }
                )
            }
        }
    }
    
    private var dashboardWidgetsView: some View {
        VStack(spacing: 16) {
            // Upcoming events widget
            if !viewModel.recentEvents.isEmpty {
                DashboardWidget(title: "Upcoming Events", icon: "calendar") {
                    ForEach(viewModel.recentEvents, id: \.id) { event in
                        EventRowView(event: event)
                    }
                }
            }
            
            // Pending tasks widget
            if !viewModel.pendingTasks.isEmpty {
                DashboardWidget(title: "Pending Tasks", icon: "checklist") {
                    ForEach(viewModel.pendingTasks, id: \.id) { task in
                        TaskRowView(task: task, userProfiles: viewModel.userProfiles)
                    }
                }
            }
            
            // Recent messages widget
            if !viewModel.recentMessages.isEmpty {
                DashboardWidget(title: "Recent Messages", icon: "message") {
                    ForEach(viewModel.recentMessages, id: \.id) { message in
                        MessageRowView(message: message, userProfiles: viewModel.userProfiles)
                    }
                }
            }
            
            // Today's school runs widget
            if !viewModel.todaysSchoolRuns.isEmpty {
                SchoolRunDashboardWidget(
                    title: "Today's School Runs",
                    icon: "car",
                    onViewAll: { viewModel.showSchoolRunView = true }
                ) {
                    ForEach(viewModel.todaysSchoolRuns, id: \.id) { schoolRun in
                        SchoolRunRowView(schoolRun: schoolRun, userProfiles: viewModel.userProfiles)
                    }
                }
            }
        }
    }
    
    private var membersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Family Members")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("View All") {
                    // Navigate to full member list
                }
                .font(.subheadline)
                .foregroundColor(.brandPrimary)
            }
            .padding(.horizontal, 4)
            
            LazyVStack(spacing: 8) {
                ForEach(viewModel.members.prefix(3)) { member in
                    MemberRowView(
                        member: member,
                        userProfile: viewModel.userProfile(for: member),
                        canManage: viewModel.canManageMembers && member.userId != appState.currentUser?.id,
                        onRoleChange: {
                            viewModel.showRoleChange(for: member)
                        },
                        onRemove: {
                            viewModel.showRemovalConfirmation(for: member)
                        }
                    )
                }
                
                if viewModel.members.count > 3 {
                    Button("View All \(viewModel.members.count) Members") {
                        // Navigate to full member list
                    }
                    .font(.subheadline)
                    .foregroundColor(.brandPrimary)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                }
            }
        }
    }
    
    private var adminControlsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Admin Controls")
                .font(.headline)
                .fontWeight(.semibold)
                .padding(.horizontal, 4)
            
            VStack(spacing: 8) {
                AdminControlButton(
                    title: "Invite New Member",
                    icon: "person.badge.plus",
                    action: {
                        viewModel.successMessage = "Invite functionality coming soon!"
                    }
                )
                
                AdminControlButton(
                    title: "Manage Roles",
                    icon: "person.2.badge.gearshape",
                    action: {
                        viewModel.successMessage = "Role management coming soon!"
                    }
                )
                
                AdminControlButton(
                    title: "Family Settings",
                    icon: "gearshape",
                    action: {
                        viewModel.showSettings()
                    }
                )
                
                AdminControlButton(
                    title: "View Reports",
                    icon: "chart.bar",
                    action: {
                        viewModel.successMessage = "Reports functionality coming soon!"
                    }
                )
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
    }
}

// MARK: - Activity Summary Card

struct ActivitySummaryCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title3)
                
                Spacer()
                
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Quick Action Button

struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
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
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Dashboard Widget

struct DashboardWidget<Content: View>: View {
    let title: String
    let icon: String
    let content: Content
    
    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.brandPrimary)
                
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("View All") {
                    // Navigate to full view
                }
                .font(.caption)
                .foregroundColor(.brandPrimary)
            }
            
            content
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Widget Row Views

struct EventRowView: View {
    let event: CalendarEvent
    @State private var showingEventDetail = false
    
    var body: some View {
        Button(action: {
            showingEventDetail = true
        }) {
            HStack(spacing: 12) {
                Text(event.type.icon)
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(event.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(event.date, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showingEventDetail) {
            EventDetailView(
                event: event,
                userProfiles: Dictionary(uniqueKeysWithValues: MockDataGenerator.mockMawereFamily().users.map { ($0.id, $0) })
            )
        }
    }
}

struct TaskRowView: View {
    let task: FamilyTask
    let userProfiles: [UUID: UserProfile]
    
    var body: some View {
        HStack(spacing: 12) {
            Text(task.category.icon)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if let assignedUser = userProfiles[task.assignedTo] {
                    Text("Assigned to \(assignedUser.displayName)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Text("\(task.points)pts")
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.brandPrimary.opacity(0.1))
                .foregroundColor(.brandPrimary)
                .cornerRadius(4)
        }
        .padding(.vertical, 4)
    }
}

struct MessageRowView: View {
    let message: FamilyMessage
    let userProfiles: [UUID: UserProfile]
    
    var body: some View {
        HStack(spacing: 12) {
            MemberAvatarView(userProfile: userProfiles[message.sender])
                .frame(width: 32, height: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(message.content)
                    .font(.subheadline)
                    .lineLimit(2)
                
                if let sender = userProfiles[message.sender] {
                    Text(sender.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if !message.isRead {
                Circle()
                    .fill(Color.brandPrimary)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.vertical, 4)
    }
}

struct SchoolRunRowView: View {
    let schoolRun: SchoolRun
    let userProfiles: [UUID: UserProfile]
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "car.fill")
                .foregroundColor(.blue)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(schoolRun.route)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(schoolRun.pickupTime, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(schoolRun.status.displayName)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.blue.opacity(0.1))
                .foregroundColor(.blue)
                .cornerRadius(4)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#Preview {
    let mockData = MockDataGenerator.mockMawereFamily()
    let mockUserId = mockData.users[0].id
    
    MockFamilyDashboardView(
        family: mockData.family,
        currentUserId: mockUserId,
        currentUserRole: .parentAdmin
    )
    .environmentObject(AppState())
}

// MARK: - School Run Dashboard Widget

struct SchoolRunDashboardWidget<Content: View>: View {
    let title: String
    let icon: String
    let onViewAll: () -> Void
    let content: Content
    
    init(title: String, icon: String, onViewAll: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.onViewAll = onViewAll
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.brandPrimary)
                
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("View All") {
                    onViewAll()
                }
                .font(.caption)
                .foregroundColor(.brandPrimary)
            }
            
            content
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}