import SwiftUI
import Foundation

/// Mock ViewModel for family dashboard that provides instant responses with comprehensive mock data
@MainActor
class MockFamilyDashboardViewModel: ObservableObject {
    // MARK: - Published Properties
    
    /// List of family members with their memberships
    @Published var members: [Membership] = []
    
    /// Associated user profiles for members
    @Published var userProfiles: [UUID: UserProfile] = [:]
    
    /// Current user's role in the family
    @Published var currentUserRole: Role = .adult
    
    /// Loading state for async operations
    @Published var isLoading = false
    
    /// Error message for display
    @Published var errorMessage: String?
    
    /// Success message for operations
    @Published var successMessage: String?
    
    /// Currently selected member for role change
    @Published var selectedMember: Membership?
    
    /// Show role change sheet
    @Published var showRoleChangeSheet = false
    
    /// Show member removal confirmation
    @Published var showRemovalConfirmation = false
    
    /// Member to be removed
    @Published var memberToRemove: Membership?
    
    /// Show calendar view
    @Published var showCalendarView = false
    
    /// Show tasks view
    @Published var showTasksView = false
    
    /// Show messages view
    @Published var showMessagesView = false
    
    /// Show school run view
    @Published var showSchoolRunView = false
    
    /// Show settings view
    @Published var showSettingsView = false
    
    // MARK: - Dashboard Widget Data
    
    /// Recent calendar events for dashboard widget
    @Published var recentEvents: [CalendarEvent] = []
    
    /// Pending tasks for dashboard widget
    @Published var pendingTasks: [FamilyTask] = []
    
    /// Recent messages for dashboard widget
    @Published var recentMessages: [FamilyMessage] = []
    
    /// Today's school runs for dashboard widget
    @Published var todaysSchoolRuns: [SchoolRun] = []
    
    /// Family activity summary
    @Published var activitySummary: ActivitySummary = ActivitySummary()
    
    // MARK: - Dependencies
    
    private let currentFamily: Family
    private let currentUserId: UUID
    
    // MARK: - Initialization
    
    init(family: Family, currentUserId: UUID, currentUserRole: Role) {
        self.currentFamily = family
        self.currentUserId = currentUserId
        self.currentUserRole = currentUserRole
        
        // Load mock data immediately
        loadMockData()
    }
    
    // MARK: - Public Methods
    
    /// Load family members and dashboard data with mock responses
    func loadMembers() async {
        isLoading = true
        errorMessage = nil
        
        // Simulate brief loading for realism
        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        loadMockData()
        
        isLoading = false
    }
    
    /// Change a member's role with mock validation
    func changeRole(for member: Membership, to newRole: Role) async {
        guard currentUserRole == .parentAdmin else {
            errorMessage = "Only Parent Admin can change member roles"
            return
        }
        
        guard member.userId != currentUserId else {
            errorMessage = "You cannot change your own role"
            return
        }
        
        // Check if trying to assign Parent Admin when one already exists
        if newRole == .parentAdmin && members.contains(where: { $0.role == .parentAdmin && $0.id != member.id }) {
            errorMessage = "Only one Parent Admin is allowed per family"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        // Simulate processing time
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Update role in mock data
        if let index = members.firstIndex(where: { $0.id == member.id }) {
            members[index].role = newRole
            successMessage = "Role updated to \(newRole.displayName)"
            showRoleChangeSheet = false
            selectedMember = nil
        }
        
        isLoading = false
    }
    
    /// Remove a member from the family with mock validation
    func removeMember(_ member: Membership) async {
        guard currentUserRole == .parentAdmin else {
            errorMessage = "Only Parent Admin can remove members"
            return
        }
        
        guard member.userId != currentUserId else {
            errorMessage = "You cannot remove yourself from the family"
            return
        }
        
        guard member.role != .parentAdmin else {
            errorMessage = "Cannot remove Parent Admin"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        // Simulate processing time
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Remove member from mock data
        members.removeAll { $0.id == member.id }
        if let userId = member.userId {
            userProfiles.removeValue(forKey: userId)
        }
        
        successMessage = "Member removed from family"
        showRemovalConfirmation = false
        memberToRemove = nil
        
        // Update activity summary
        updateActivitySummary()
        
        isLoading = false
    }
    
    /// Show role change sheet for a member
    func showRoleChange(for member: Membership) {
        selectedMember = member
        showRoleChangeSheet = true
    }
    
    /// Show removal confirmation for a member
    func showRemovalConfirmation(for member: Membership) {
        memberToRemove = member
        showRemovalConfirmation = true
    }
    
    /// Show calendar view
    func showCalendar() {
        showCalendarView = true
    }
    
    /// Show tasks view
    func showTasks() {
        showTasksView = true
    }
    
    /// Show messages view
    func showMessages() {
        showMessagesView = true
    }
    
    /// Show settings view
    func showSettings() {
        showSettingsView = true
    }
    
    /// Show school run view
    func showSchoolRun() {
        showSchoolRunView = true
    }
    
    /// Clear success message
    func clearSuccessMessage() {
        successMessage = nil
    }
    
    /// Clear error message
    func clearErrorMessage() {
        errorMessage = nil
    }
    
    /// Check if current user can manage members
    var canManageMembers: Bool {
        currentUserRole == .parentAdmin
    }
    
    /// Get user profile for a member
    func userProfile(for membership: Membership) -> UserProfile? {
        guard let userId = membership.userId else { return nil }
        return userProfiles[userId]
    }
    
    /// Refresh dashboard widgets
    func refreshDashboardData() async {
        isLoading = true
        
        // Simulate refresh time
        try? await Task.sleep(nanoseconds: 800_000_000) // 0.8 seconds
        
        loadMockDashboardData()
        updateActivitySummary()
        
        isLoading = false
        successMessage = "Dashboard refreshed"
    }
    
    // MARK: - Private Methods
    
    /// Load comprehensive mock data for the dashboard
    private func loadMockData() {
        let mockData = MockDataGenerator.mockMawereFamily()
        
        // Set family members
        members = mockData.memberships.filter { $0.status == .active }
        
        // Set user profiles
        userProfiles = Dictionary(uniqueKeysWithValues: mockData.users.map { ($0.id, $0) })
        
        // Load dashboard widget data
        loadMockDashboardData()
        updateActivitySummary()
    }
    
    /// Load mock data for dashboard widgets
    private func loadMockDashboardData() {
        let roleSpecificData = MockDataGenerator.mockDataForRole(currentUserRole)
        
        // Get recent events (next 3 upcoming)
        let calendar = Calendar.current
        let today = Date()
        recentEvents = roleSpecificData.calendarEvents
            .filter { $0.date >= today }
            .sorted { $0.date < $1.date }
            .prefix(3)
            .map { $0 }
        
        // Get pending tasks (not completed, limited by role)
        pendingTasks = roleSpecificData.tasks
            .filter { $0.status != .completed }
            .sorted { $0.dueDate ?? Date.distantFuture < $1.dueDate ?? Date.distantFuture }
            .prefix(4)
            .map { $0 }
        
        // Get recent messages (last 3)
        recentMessages = roleSpecificData.messages
            .sorted { $0.timestamp > $1.timestamp }
            .prefix(3)
            .map { $0 }
        
        // Get today's school runs
        todaysSchoolRuns = roleSpecificData.schoolRuns
            .filter { calendar.isDate($0.pickupTime, inSameDayAs: today) }
            .sorted { $0.pickupTime < $1.pickupTime }
    }
    
    /// Update activity summary with current data
    private func updateActivitySummary() {
        let allTasks = MockDataGenerator.mockFamilyTasks()
        let allMessages = MockDataGenerator.mockFamilyMessages()
        
        activitySummary = ActivitySummary(
            totalMembers: members.count,
            pendingTasks: allTasks.filter { $0.status == .pending }.count,
            completedTasksToday: allTasks.filter { 
                $0.status == .completed && 
                Calendar.current.isDateInToday($0.createdAt)
            }.count,
            unreadMessages: allMessages.filter { !$0.isRead }.count,
            upcomingEvents: recentEvents.count,
            totalPoints: allTasks.filter { $0.status == .completed }.reduce(0) { $0 + $1.points }
        )
    }
}

// MARK: - Activity Summary Model

struct ActivitySummary {
    let totalMembers: Int
    let pendingTasks: Int
    let completedTasksToday: Int
    let unreadMessages: Int
    let upcomingEvents: Int
    let totalPoints: Int
    
    init(
        totalMembers: Int = 0,
        pendingTasks: Int = 0,
        completedTasksToday: Int = 0,
        unreadMessages: Int = 0,
        upcomingEvents: Int = 0,
        totalPoints: Int = 0
    ) {
        self.totalMembers = totalMembers
        self.pendingTasks = pendingTasks
        self.completedTasksToday = completedTasksToday
        self.unreadMessages = unreadMessages
        self.upcomingEvents = upcomingEvents
        self.totalPoints = totalPoints
    }
}