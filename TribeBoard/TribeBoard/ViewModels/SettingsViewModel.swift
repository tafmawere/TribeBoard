import SwiftUI
import Foundation
import Combine

/// View model for settings with mock data and functionality
@MainActor
class SettingsViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var hasUnsavedChanges = false
    
    // MARK: - Settings Data
    
    @Published var familySettings: MockFamilySettings
    @Published var notificationPreferences: MockNotificationPreferences
    @Published var currentUserProfile: UserProfile?
    
    // MARK: - Sheet States
    
    @Published var showProfileEditor = false
    @Published var showFamilyMemberManagement = false
    @Published var showPrivacySettings = false
    @Published var showSecuritySettings = false
    
    // MARK: - Properties
    
    let currentUserId: UUID
    let currentUserRole: Role
    
    var canManageFamily: Bool {
        currentUserRole == .parentAdmin
    }
    
    // MARK: - Initialization
    
    init(currentUserId: UUID, currentUserRole: Role) {
        self.currentUserId = currentUserId
        self.currentUserRole = currentUserRole
        
        // Initialize with mock data
        self.familySettings = MockFamilySettings()
        self.notificationPreferences = MockNotificationPreferences()
        
        // Set up change tracking
        setupChangeTracking()
    }
    
    // MARK: - Public Methods
    
    func loadSettings() async {
        isLoading = true
        
        // Simulate loading delay
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // Load mock user profile
        let mockData = MockDataGenerator.mockMawereFamily()
        currentUserProfile = mockData.users.first { $0.id == currentUserId } ?? mockData.users[0]
        
        // Load mock family settings
        let mockFamilySettings = MockDataGenerator.mockFamilySettings()
        familySettings.updateFromFamilySettings(mockFamilySettings)
        
        isLoading = false
        successMessage = "Settings loaded successfully"
    }
    
    func saveSettings() async {
        isLoading = true
        
        // Simulate save delay
        try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
        
        // Mock save operation
        hasUnsavedChanges = false
        isLoading = false
        successMessage = "Settings saved successfully!"
    }
    
    func updateProfile(_ profile: UserProfile) {
        currentUserProfile = profile
        hasUnsavedChanges = true
        successMessage = "Profile updated"
    }
    
    func updateFamilySettings(_ settings: MockFamilySettings) {
        familySettings = settings
        hasUnsavedChanges = true
        successMessage = "Family settings updated"
    }
    
    func shareFamilyCode(_ code: String) {
        // Mock share functionality
        successMessage = "Family code \(code) copied to clipboard!"
    }
    
    func inviteNewMember() {
        successMessage = "Invitation link generated! Share with new family member."
    }
    
    func exportFamilyData() {
        successMessage = "Family data export started. You'll receive an email when ready."
    }
    
    func clearAppCache() {
        successMessage = "App cache cleared successfully"
    }
    
    func showAboutApp() {
        successMessage = "TribeBoard v1.0.0 - Family management made simple"
    }
    
    func showLeaveFamilyConfirmation() {
        // This would typically show a confirmation dialog
        successMessage = "Leave family confirmation would appear here"
    }
    
    func showDeleteFamilyDataConfirmation() {
        // This would typically show a confirmation dialog
        errorMessage = "This action cannot be undone. Are you sure?"
    }
    
    func signOut() {
        successMessage = "Signing out..."
        // In a real app, this would trigger sign out
    }
    
    func clearError() {
        errorMessage = nil
    }
    
    // MARK: - Private Methods
    
    private func setupChangeTracking() {
        // Track changes to family settings
        $familySettings
            .dropFirst()
            .sink { [weak self] _ in
                self?.hasUnsavedChanges = true
            }
            .store(in: &cancellables)
        
        // Track changes to notification preferences
        $notificationPreferences
            .dropFirst()
            .sink { [weak self] _ in
                self?.hasUnsavedChanges = true
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
}

// MARK: - Mock Data Structures

/// Mock family settings for prototype
class MockFamilySettings: ObservableObject {
    @Published var notificationsEnabled = true
    @Published var quietHoursStart = Calendar.current.date(bySettingHour: 21, minute: 0, second: 0, of: Date()) ?? Date()
    @Published var quietHoursEnd = Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: Date()) ?? Date()
    @Published var allowChildMessaging = true
    @Published var requireTaskApproval = false
    @Published var pointsSystemEnabled = true
    @Published var maxPointsPerTask = 25
    
    func updateFromFamilySettings(_ settings: FamilySettings) {
        notificationsEnabled = settings.notificationsEnabled
        quietHoursStart = settings.quietHoursStart
        quietHoursEnd = settings.quietHoursEnd
        allowChildMessaging = settings.allowChildMessaging
        requireTaskApproval = settings.requireTaskApproval
        pointsSystemEnabled = settings.pointsSystemEnabled
        maxPointsPerTask = settings.maxPointsPerTask
    }
}

/// Mock notification preferences for prototype
class MockNotificationPreferences: ObservableObject {
    @Published var taskAssignments = true
    @Published var familyMessages = true
    @Published var calendarEvents = true
    @Published var schoolRunUpdates = true
    @Published var systemUpdates = false
    @Published var marketingEmails = false
}