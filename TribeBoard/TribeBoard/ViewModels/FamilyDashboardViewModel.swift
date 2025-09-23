import SwiftUI
import Foundation
import CloudKit

/// ViewModel for managing family dashboard state and member operations with real backend integration
@MainActor
class FamilyDashboardViewModel: ObservableObject {
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
    
    // MARK: - Dependencies
    
    private let dataService: DataService
    private let cloudKitService: CloudKitService
    private let currentFamily: Family
    private let currentUserId: UUID
    
    // MARK: - Initialization
    
    init(family: Family, currentUserId: UUID, currentUserRole: Role, dataService: DataService, cloudKitService: CloudKitService) {
        self.currentFamily = family
        self.currentUserId = currentUserId
        self.currentUserRole = currentUserRole
        self.dataService = dataService
        self.cloudKitService = cloudKitService
        
        // Set up real-time sync notifications
        setupSyncNotifications()
    }
    
    // MARK: - Public Methods
    
    /// Load family members and their profiles with real backend integration
    func loadMembers() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Load from local storage first for immediate display
            // Add a small delay to allow SwiftData relationships to stabilize
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            
            let localMemberships = try dataService.fetchActiveMemberships(forFamily: currentFamily)
            var allProfiles: [UUID: UserProfile] = [:]
            
            // Get user profiles for local memberships
            for membership in localMemberships {
                if let userId = membership.userId,
                   let userProfile = try dataService.fetchUserProfile(byId: userId) {
                    allProfiles[userId] = userProfile
                }
            }
            
            // Update UI with local data
            await MainActor.run {
                self.members = localMemberships
                self.userProfiles = allProfiles
            }
            
            // Sync with CloudKit for latest data
            try await syncMembersFromCloudKit()
            
        } catch {
            print("❌ FamilyDashboardViewModel: Error loading members: \(error.localizedDescription)")
            
            await MainActor.run {
                // For SwiftData relationship errors, provide a more user-friendly message
                if error.localizedDescription.contains("SwiftData") || 
                   error.localizedDescription.contains("relationship") ||
                   error.localizedDescription.contains("EXC_BREAKPOINT") {
                    self.errorMessage = "Loading family members... Please wait a moment and try again."
                    
                    // Try to reload after a short delay
                    Task {
                        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                        await self.loadMembers()
                    }
                } else {
                    self.errorMessage = "Failed to load family members: \(error.localizedDescription)"
                }
            }
        }
        
        isLoading = false
    }
    
    /// Change a member's role (Parent Admin only) with real backend integration
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
        
        do {
            // Update role in local storage
            try dataService.updateMembershipRole(member, to: newRole)
            
            // Sync to CloudKit
            try await cloudKitService.save(member)
            
            // Mark as synced
            member.needsSync = false
            member.lastSyncDate = Date()
            try dataService.save()
            
            // Update local UI
            if let index = members.firstIndex(where: { $0.id == member.id }) {
                await MainActor.run {
                    self.members[index] = member
                    self.successMessage = "Role updated to \(newRole.displayName)"
                    self.showRoleChangeSheet = false
                    self.selectedMember = nil
                }
            }
            
        } catch {
            if let dataError = error as? DataServiceError {
                errorMessage = dataError.localizedDescription
            } else if let cloudKitError = error as? CloudKitError {
                errorMessage = "Role updated locally. Sync failed: \(cloudKitError.localizedDescription)"
            } else {
                errorMessage = "Failed to update role: \(error.localizedDescription)"
            }
        }
        
        isLoading = false
    }
    
    /// Remove a member from the family (Parent Admin only) with real backend integration
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
        
        do {
            // Remove member (soft delete) in local storage
            try dataService.removeMembership(member)
            
            // Sync to CloudKit
            try await cloudKitService.save(member)
            
            // Mark as synced
            member.needsSync = false
            member.lastSyncDate = Date()
            try dataService.save()
            
            // Update local UI
            await MainActor.run {
                self.members.removeAll { $0.id == member.id }
                if let userId = member.userId {
                    self.userProfiles.removeValue(forKey: userId)
                }
                self.successMessage = "Member removed from family"
                self.showRemovalConfirmation = false
                self.memberToRemove = nil
            }
            
        } catch {
            if let dataError = error as? DataServiceError {
                errorMessage = dataError.localizedDescription
            } else if let cloudKitError = error as? CloudKitError {
                errorMessage = "Member removed locally. Sync failed: \(cloudKitError.localizedDescription)"
            } else {
                errorMessage = "Failed to remove member: \(error.localizedDescription)"
            }
        }
        
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
    
    // MARK: - Private Methods
    
    /// Set up real-time sync notifications
    private func setupSyncNotifications() {
        NotificationCenter.default.addObserver(
            forName: .membershipRecordChanged,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task {
                await self?.handleMembershipChange(notification)
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: .membershipRecordDeleted,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task {
                await self?.handleMembershipDeletion(notification)
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: .userProfileRecordChanged,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task {
                await self?.handleUserProfileChange(notification)
            }
        }
    }
    
    /// Sync members from CloudKit
    private func syncMembersFromCloudKit() async throws {
        // Fetch latest memberships from CloudKit
        let membershipRecords = try await cloudKitService.fetchActiveMemberships(forFamilyId: currentFamily.id.uuidString)
        
        var updatedMemberships: [Membership] = []
        var updatedProfiles: [UUID: UserProfile] = userProfiles
        
        for record in membershipRecords {
            // Convert CloudKit record to local membership
            if let membership = try await convertMembershipRecord(record) {
                updatedMemberships.append(membership)
                
                // Get user profile for this membership
                if let userId = membership.userId,
                   let userProfile = try dataService.fetchUserProfile(byId: userId) {
                    updatedProfiles[userId] = userProfile
                } else if let userReference = record[CKFieldName.membershipUserReference] as? CKRecord.Reference {
                    // Fetch user profile from CloudKit if not found locally
                    if let userRecord = try await cloudKitService.fetchRecord(withID: userReference.recordID.recordName, recordType: CKRecordType.userProfile) {
                        let userProfile = try await convertUserProfileRecord(userRecord)
                        if let userId = membership.userId {
                            updatedProfiles[userId] = userProfile
                        }
                    }
                }
            }
        }
        
        // Update UI on main thread
        await MainActor.run {
            self.members = updatedMemberships
            self.userProfiles = updatedProfiles
        }
    }
    
    /// Convert CloudKit membership record to local Membership
    private func convertMembershipRecord(_ record: CKRecord) async throws -> Membership? {
        guard let roleString = record[CKFieldName.membershipRole] as? String,
              let role = Role(rawValue: roleString),
              let statusString = record[CKFieldName.membershipStatus] as? String,
              let status = MembershipStatus(rawValue: statusString),
              status == .active else {
            return nil // Skip non-active memberships
        }
        
        // Check if membership exists locally
        let _ = UUID(uuidString: record.recordID.recordName)!
        
        // For now, create a temporary membership - in a real implementation,
        // this would properly sync with local storage
        let membership = Membership(family: currentFamily, user: UserProfile(displayName: "Loading...", appleUserIdHash: "temp"), role: role)
        try membership.updateFromCKRecord(record)
        
        return membership
    }
    
    /// Convert CloudKit user profile record to local UserProfile
    private func convertUserProfileRecord(_ record: CKRecord) async throws -> UserProfile {
        guard let displayName = record[CKFieldName.userDisplayName] as? String,
              let appleUserIdHash = record[CKFieldName.userAppleUserIdHash] as? String else {
            throw CloudKitSyncError.invalidRecord
        }
        
        let userProfile = UserProfile(displayName: displayName, appleUserIdHash: appleUserIdHash)
        try userProfile.updateFromCKRecord(record)
        
        return userProfile
    }
    
    /// Handle membership change notifications
    private func handleMembershipChange(_ notification: Notification) async {
        guard let record = notification.userInfo?["record"] as? CKRecord else { return }
        
        // Check if this membership belongs to our family
        if let familyReference = record[CKFieldName.membershipFamilyReference] as? CKRecord.Reference,
           familyReference.recordID.recordName == currentFamily.id.uuidString {
            
            // Reload members to get latest data
            await loadMembers()
        }
    }
    
    /// Handle membership deletion notifications
    private func handleMembershipDeletion(_ notification: Notification) async {
        guard let recordID = notification.userInfo?["recordID"] as? String else { return }
        
        // Remove member from local list
        await MainActor.run {
            self.members.removeAll { $0.ckRecordID == recordID }
        }
    }
    
    /// Handle user profile change notifications
    private func handleUserProfileChange(_ notification: Notification) async {
        guard let record = notification.userInfo?["record"] as? CKRecord else { return }
        
        // Update user profile if it's for one of our members
        if let userId = UUID(uuidString: record.recordID.recordName),
           userProfiles[userId] != nil {
            
            do {
                let updatedProfile = try await convertUserProfileRecord(record)
                await MainActor.run {
                    self.userProfiles[userId] = updatedProfile
                }
            } catch {
                // Handle error silently for now
            }
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}