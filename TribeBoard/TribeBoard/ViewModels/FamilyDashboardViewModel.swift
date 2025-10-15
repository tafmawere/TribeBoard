import SwiftUI
import Foundation

/// ViewModel for managing family dashboard state and member operations with SwiftUI-compatible in-memory storage
@MainActor
class FamilyDashboardViewModel: ObservableObject {
    // MARK: - Published Properties for SwiftUI List binding
    
    /// List of family members with their user details for SwiftUI List display
    @Published var members: [(member: InMemoryMember, user: InMemoryUser?)] = []
    
    /// Current family being displayed
    @Published var currentFamily: InMemoryFamily?
    
    /// Current user's role in the family
    @Published var currentUserRole: InMemoryRole = .parent
    
    /// Loading state for SwiftUI progress views
    @Published var isLoading = false
    
    /// Current error, if any
    @Published var currentError: FamilyJoinError?
    
    /// Success message for SwiftUI toast notifications
    @Published var successMessage: String?
    
    /// Show error alert
    @Published var showErrorAlert: Bool = false
    
    /// Show success alert
    @Published var showSuccessAlert: Bool = false
    
    /// Currently selected member for role change
    @Published var selectedMember: InMemoryMember?
    
    /// Show role change sheet
    @Published var showRoleChangeSheet = false
    
    /// Show member removal confirmation
    @Published var showRemovalConfirmation = false
    
    /// Member to be removed
    @Published var memberToRemove: InMemoryMember?
    
    // MARK: - Calendar Integration Properties
    
    /// Calendar dashboard data
    @Published var calendarDashboardData: FamilyCalendarDashboardData?
    
    /// Calendar activity feed
    @Published var calendarActivityFeed: [FamilyCalendarActivity] = []
    
    /// Show calendar section in dashboard
    @Published var showCalendarSection = true
    
    /// Calendar loading state
    @Published var isLoadingCalendar = false
    
    /// Calendar error
    @Published var calendarError: Error?
    
    // MARK: - Dependencies
    
    private let dataManager: InMemoryFamilyDataManager
    private let currentFamilyId: UUID
    private let currentUserId: UUID
    private let familyCalendarService: FamilyCalendarIntegrationService?
    
    // MARK: - Initialization
    
    init(
        familyId: UUID, 
        currentUserId: UUID, 
        dataManager: InMemoryFamilyDataManager? = nil,
        familyCalendarService: FamilyCalendarIntegrationService? = nil
    ) {
        self.currentFamilyId = familyId
        self.currentUserId = currentUserId
        self.dataManager = dataManager ?? InMemoryFamilyDataManager.shared
        self.familyCalendarService = familyCalendarService
        
        // Set current family from data manager
        self.currentFamily = dataManager?.families.first { $0.id == familyId }
        
        // Determine current user's role
        if let family = currentFamily,
           let member = family.member(withUserId: currentUserId) {
            self.currentUserRole = member.role
        }
        
        // Load initial member data
        loadMembers()
        
        // Load calendar data if service is available
        if familyCalendarService != nil {
            Task {
                await loadCalendarDashboardData()
            }
        }
    }
    
    // MARK: - Public Methods
    
    /// Update the context with actual family and user IDs
    func updateContext(familyId: UUID, currentUserId: UUID) async {
        // Update the internal IDs if they're different from placeholders
        // This is a workaround for the initialization issue
        // In a real implementation, we'd restructure this differently
    }
    
    /// Load family members with @Published members array for SwiftUI List binding
    func loadMembers() {
        isLoading = true
        currentError = nil
        
        // Get current family from data manager
        guard let family = dataManager.families.first(where: { $0.id == currentFamilyId }) else {
            showError(.familyNotFound)
            isLoading = false
            return
        }
        
        // Update current family reference
        currentFamily = family
        
        // Get members with user details for SwiftUI List display
        let membersWithUsers = dataManager.getFamilyMembersWithUserDetails(familyId: currentFamilyId)
        
        // Update @Published property to trigger SwiftUI view updates
        members = membersWithUsers
        
        // Update current user's role if needed
        if let currentMember = family.member(withUserId: currentUserId) {
            currentUserRole = currentMember.role
        }
        
        isLoading = false
    }
    
    /// Change a member's role (Parent only) with SwiftUI-compatible in-memory storage
    func changeRole(for member: InMemoryMember, to newRole: InMemoryRole) {
        guard currentUserRole == .parent else {
            showError(.userNotFound) // Using closest available error
            return
        }
        
        guard member.userId != currentUserId else {
            showError(.alreadyMember) // Using closest available error
            return
        }
        
        // Check if trying to assign Parent when one already exists (if business rule applies)
        if newRole == .parent && members.contains(where: { $0.member.role == .parent && $0.member.id != member.id }) {
            showError(.alreadyMember)
            return
        }
        
        isLoading = true
        clearError()
        
        // Update role using data manager
        let success = dataManager.updateUserRole(userId: member.userId, familyId: currentFamilyId, newRole: newRole)
        
        if success {
            // Reload members to reflect changes in SwiftUI List
            loadMembers()
            showSuccess("Role updated to \(newRole.displayName)")
            showRoleChangeSheet = false
            selectedMember = nil
        } else {
            showError(.unknownError)
        }
        
        isLoading = false
    }
    
    /// Remove a member from the family (Parent only) with SwiftUI-compatible in-memory storage
    func removeMember(_ member: InMemoryMember) {
        guard currentUserRole == .parent else {
            showError(.userNotFound) // Using closest available error
            return
        }
        
        guard member.userId != currentUserId else {
            showError(.alreadyMember) // Using closest available error
            return
        }
        
        guard member.role != .parent else {
            showError(.alreadyMember) // Using closest available error
            return
        }
        
        isLoading = true
        clearError()
        
        // Remove member from family using data manager
        guard let family = dataManager.families.first(where: { $0.id == currentFamilyId }) else {
            showError(.familyNotFound)
            isLoading = false
            return
        }
        
        // Remove member from family
        family.removeMember(withUserId: member.userId)
        
        // Reload members to reflect changes in SwiftUI List
        loadMembers()
        showSuccess("Member removed from family")
        showRemovalConfirmation = false
        memberToRemove = nil
        
        isLoading = false
    }
    
    /// Show role change sheet for a member
    func showRoleChange(for member: InMemoryMember) {
        selectedMember = member
        showRoleChangeSheet = true
    }
    
    /// Show removal confirmation for a member
    func showRemovalConfirmation(for member: InMemoryMember) {
        memberToRemove = member
        showRemovalConfirmation = true
    }
    
    /// Clear success message
    func clearSuccessMessage() {
        successMessage = nil
        showSuccessAlert = false
    }
    
    /// Clear error message and alert state
    func clearError() {
        currentError = nil
        showErrorAlert = false
    }
    
    /// Show error alert with the specified error
    private func showError(_ error: FamilyJoinError) {
        currentError = error
        showErrorAlert = true
        HapticManager.shared.error()
        ToastManager.shared.error(error.localizedDescription)
    }
    
    /// Show success message and alert
    private func showSuccess(_ message: String) {
        successMessage = message
        showSuccessAlert = true
        HapticManager.shared.success()
        ToastManager.shared.success(message)
    }
    
    /// Get current error message for display
    var errorMessage: String? {
        return currentError?.localizedDescription
    }
    
    /// Check if current user can manage members
    var canManageMembers: Bool {
        currentUserRole == .parent
    }
    
    /// Get user for a member (convenience method for SwiftUI views)
    func user(for member: InMemoryMember) -> InMemoryUser? {
        return dataManager.getUser(byId: member.userId)
    }
    
    /// Navigate to "Add Member" flow using SwiftUI @EnvironmentObject AppState
    /// This method should be called from the view with access to AppState
    func navigateToAddMember(appState: AppState) {
        // Navigation will be handled by the view layer
        // The view can use this as a trigger to navigate to join family flow
    }
    
    /// Get family name for display
    var familyName: String {
        return currentFamily?.name ?? "Unknown Family"
    }
    
    /// Get family code for display
    var familyCode: String {
        return currentFamily?.code ?? ""
    }
    
    /// Get member count for display
    var memberCount: Int {
        return members.count
    }
    
    // MARK: - Calendar Integration Methods
    
    /// Load calendar dashboard data
    func loadCalendarDashboardData() async {
        guard let familyCalendarService = familyCalendarService else {
            print("📋 FamilyDashboardViewModel: No calendar service available")
            return
        }
        
        isLoadingCalendar = true
        calendarError = nil
        
        do {
            let dashboardData = try await familyCalendarService.getFamilyCalendarDashboardData(
                familyId: currentFamilyId,
                userId: currentUserId
            )
            
            calendarDashboardData = dashboardData
            showCalendarSection = dashboardData.hasCalendarAccess
            
            // Also load activity feed
            let activityFeed = try await familyCalendarService.getFamilyCalendarActivityFeed(
                familyId: currentFamilyId,
                userId: currentUserId,
                limit: 5
            )
            
            calendarActivityFeed = activityFeed
            
            print("✅ FamilyDashboardViewModel: Loaded calendar dashboard data")
            
        } catch {
            calendarError = error
            showCalendarSection = false
            print("❌ FamilyDashboardViewModel: Failed to load calendar data: \(error)")
        }
        
        isLoadingCalendar = false
    }
    
    /// Refresh calendar data
    func refreshCalendarData() async {
        await loadCalendarDashboardData()
    }
    
    /// Get calendar info for a specific member
    func getCalendarInfoForMember(_ member: InMemoryMember) async -> MemberCalendarInfo? {
        guard let familyCalendarService = familyCalendarService else { return nil }
        
        do {
            return try await familyCalendarService.getCalendarInfoForMemberProfile(
                userId: member.userId,
                familyId: currentFamilyId,
                viewingUserId: currentUserId
            )
        } catch {
            print("❌ FamilyDashboardViewModel: Failed to get calendar info for member: \(error)")
            return nil
        }
    }
    
    /// Update calendar permissions for a member (admin only)
    func updateMemberCalendarPermissions(
        for member: InMemoryMember,
        newPermissionLevel: CalendarPermissionLevel
    ) async {
        guard let familyCalendarService = familyCalendarService else { return }
        guard currentUserRole == .parent else {
            showError(.userNotFound) // Using closest available error
            return
        }
        
        isLoading = true
        clearError()
        
        do {
            try await familyCalendarService.updateMemberCalendarPermissions(
                targetUserId: member.userId,
                familyId: currentFamilyId,
                newPermissionLevel: newPermissionLevel,
                adminUserId: currentUserId
            )
            
            showSuccess("Calendar permissions updated for \(user(for: member)?.name ?? "member")")
            
            // Refresh calendar data to reflect changes
            await loadCalendarDashboardData()
            
        } catch {
            showError(.unknownError)
            print("❌ FamilyDashboardViewModel: Failed to update calendar permissions: \(error)")
        }
        
        isLoading = false
    }
    
    /// Handle role change with calendar permission updates
    func changeRoleWithCalendarUpdate(for member: InMemoryMember, to newRole: InMemoryRole) async {
        let oldRole = member.role
        
        // First update the role using existing logic
        changeRole(for: member, to: newRole)
        
        // Then update calendar permissions if service is available
        if let familyCalendarService = familyCalendarService {
            do {
                // Convert InMemoryRole to Role for calendar service
                let calendarOldRole = Role.fromInMemoryRole(oldRole)
                let calendarNewRole = Role.fromInMemoryRole(newRole)
                
                // Create a temporary membership for the calendar service
                let tempMembership = createTempMembership(for: member, with: calendarNewRole)
                
                try await familyCalendarService.updateCalendarPermissionsForRoleChange(
                    membership: tempMembership,
                    oldRole: calendarOldRole,
                    newRole: calendarNewRole,
                    changedBy: currentUserId
                )
                
                // Refresh calendar data
                await loadCalendarDashboardData()
                
                print("✅ FamilyDashboardViewModel: Updated calendar permissions for role change")
                
            } catch {
                print("❌ FamilyDashboardViewModel: Failed to update calendar permissions for role change: \(error)")
                // Don't show error to user as the role change itself succeeded
            }
        }
    }
    
    /// Handle member removal with calendar cleanup
    func removeMemberWithCalendarCleanup(_ member: InMemoryMember) async {
        // First remove using existing logic
        removeMember(member)
        
        // Then clean up calendar permissions if service is available
        if let familyCalendarService = familyCalendarService {
            do {
                try await familyCalendarService.removeCalendarPermissionsForMember(
                    userId: member.userId,
                    familyId: currentFamilyId,
                    removedBy: currentUserId
                )
                
                // Refresh calendar data
                await loadCalendarDashboardData()
                
                print("✅ FamilyDashboardViewModel: Cleaned up calendar permissions for removed member")
                
            } catch {
                print("❌ FamilyDashboardViewModel: Failed to clean up calendar permissions: \(error)")
                // Don't show error to user as the removal itself succeeded
            }
        }
    }
    
    /// Navigate to family calendar view
    func navigateToFamilyCalendar(appState: AppState) {
        // This would be handled by the view layer to navigate to calendar
        print("📅 FamilyDashboardViewModel: Navigate to family calendar requested")
    }
    
    /// Check if user has calendar access
    var hasCalendarAccess: Bool {
        return calendarDashboardData?.hasCalendarAccess ?? false
    }
    
    /// Check if user can manage calendar permissions
    var canManageCalendarPermissions: Bool {
        return calendarDashboardData?.permissions.isAdmin ?? false
    }
    
    /// Get calendar statistics summary
    var calendarStatsSummary: String? {
        guard let stats = calendarDashboardData?.stats else { return nil }
        return "📅 \(stats.totalEvents) events • \(stats.upcomingEvents) upcoming"
    }
    
    // MARK: - Private Methods
    
    /// Refresh member data from data manager (for SwiftUI reactive updates)
    private func refreshMemberData() {
        // Since we're using @Published properties and ObservableObject,
        // calling loadMembers() will automatically trigger SwiftUI view updates
        loadMembers()
    }
    
    /// Validate member permissions for role changes
    private func canChangeRole(for member: InMemoryMember, to newRole: InMemoryRole) -> (canChange: Bool, reason: String?) {
        // Only parents can change roles
        guard currentUserRole == .parent else {
            return (false, "Only Parents can change member roles")
        }
        
        // Cannot change own role
        guard member.userId != currentUserId else {
            return (false, "You cannot change your own role")
        }
        
        // Business rule: Only one parent allowed (if applicable)
        if newRole == .parent && members.contains(where: { $0.member.role == .parent && $0.member.id != member.id }) {
            return (false, "Only one Parent is allowed per family")
        }
        
        return (true, nil)
    }
    
    /// Validate member permissions for removal
    private func canRemoveMember(_ member: InMemoryMember) -> (canRemove: Bool, reason: String?) {
        // Only parents can remove members
        guard currentUserRole == .parent else {
            return (false, "Only Parents can remove members")
        }
        
        // Cannot remove self
        guard member.userId != currentUserId else {
            return (false, "You cannot remove yourself from the family")
        }
        
        // Cannot remove other parents
        guard member.role != .parent else {
            return (false, "Cannot remove Parent")
        }
        
        return (true, nil)
    }
    
    /// Creates a temporary membership object for calendar service integration
    private func createTempMembership(for member: InMemoryMember, with role: Role) -> Membership {
        // This is a temporary solution - in a real implementation, we'd have proper data model integration
        let tempFamily = Family(name: familyName, code: familyCode, createdByUserId: currentUserId)
        tempFamily.id = currentFamilyId
        
        let tempUser = UserProfile(
            displayName: user(for: member)?.name ?? "Unknown",
            appleUserIdHash: "temp_hash_\(member.userId)"
        )
        tempUser.id = member.userId
        
        let tempMembership = Membership(family: tempFamily, user: tempUser, role: role)
        return tempMembership
    }
}

// MARK: - Role Conversion Extensions

extension Role {
    /// Converts from InMemoryRole to Role
    static func fromInMemoryRole(_ inMemoryRole: InMemoryRole) -> Role {
        switch inMemoryRole {
        case .parent:
            return .parentAdmin
        case .child:
            return .kid
        case .guardian:
            return .adult
        case .helper:
            return .adult
        }
    }
}

extension InMemoryRole {
    /// Converts to Role
    var asRole: Role {
        return Role.fromInMemoryRole(self)
    }
}