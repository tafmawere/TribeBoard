import SwiftUI
import Foundation

/// Global app state management for navigation and authentication
@MainActor
class AppState: ObservableObject {
    // MARK: - Published Properties
    
    /// Current authentication state
    @Published var isAuthenticated: Bool = false
    
    /// Current user profile (nil if not authenticated)
    @Published var currentUser: UserProfile?
    
    /// Current family membership (nil if not in a family)
    @Published var currentMembership: Membership?
    
    /// Current family (nil if not in a family)
    @Published var currentFamily: Family?
    
    /// Loading state for async operations
    @Published var isLoading: Bool = false
    
    /// Global error message
    @Published var errorMessage: String?
    
    // MARK: - Navigation State
    
    /// Current app flow state
    @Published var currentFlow: AppFlow = .onboarding
    
    /// Navigation path for deep linking and programmatic navigation
    @Published var navigationPath = NavigationPath()
    
    // MARK: - Mock Service Integration
    
    /// Current user journey scenario for prototype
    @Published var currentScenario: UserJourneyScenario = .newUser
    
    /// Mock service coordinator for prototype
    private var mockServiceCoordinator: MockServiceCoordinator?
    
    /// Demo journey manager for guided demos
    @Published var demoJourneyManager: DemoJourneyManager?
    
    /// Demo data manager for data lifecycle management
    @Published var demoDataManager: DemoDataManager?
    
    /// Flag to indicate if using mock services (always true for prototype)
    private let useMockServices: Bool = true
    
    // MARK: - Initialization
    
    init() {
        // Initialize with mock services for prototype
        setupMockServices()
        setupDemoManager()
        checkAuthenticationState()
    }
    
    // MARK: - Mock Service Setup
    
    /// Setup mock services for prototype
    private func setupMockServices() {
        mockServiceCoordinator = MockServiceCoordinator()
        
        // Configure initial demo scenario
        configureDemoScenario(.newUser)
    }
    
    /// Setup demo journey manager
    private func setupDemoManager() {
        demoJourneyManager = DemoJourneyManager()
        demoJourneyManager?.setAppState(self)
        
        demoDataManager = DemoDataManager()
        if let demoJourneyManager = demoJourneyManager {
            demoDataManager?.setDependencies(appState: self, demoJourneyManager: demoJourneyManager)
        }
    }
    
    /// Configure app for specific demo scenario
    func configureDemoScenario(_ scenario: UserJourneyScenario) {
        currentScenario = scenario
        
        guard let mockServices = mockServiceCoordinator else { return }
        
        // Get mock data for scenario
        let mockData = MockDataGenerator.mockDataForScenario(scenario)
        
        switch scenario {
        case .newUser:
            // Start with unauthenticated state for onboarding flow
            mockServices.authService.setMockAuthenticationState(authenticated: false)
            isAuthenticated = false
            currentUser = nil
            currentFamily = nil
            currentMembership = nil
            currentFlow = .onboarding
            
        case .existingUser:
            // Start authenticated with existing family membership
            mockServices.authService.setMockAuthenticationState(authenticated: true, user: mockData.currentUser)
            isAuthenticated = true
            currentUser = mockData.currentUser
            currentFamily = mockData.family
            currentMembership = mockData.memberships.first { $0.user?.id == mockData.currentUser.id }
            currentFlow = .familyDashboard
            
        case .familyAdmin:
            // Start as authenticated family admin
            mockServices.authService.setMockAuthenticationState(authenticated: true, user: mockData.currentUser)
            isAuthenticated = true
            currentUser = mockData.currentUser
            currentFamily = mockData.family
            currentMembership = mockData.memberships.first { $0.user?.id == mockData.currentUser.id }
            currentFlow = .familyDashboard
            
        case .childUser:
            // Start as authenticated child user
            mockServices.authService.setMockAuthenticationState(authenticated: true, user: mockData.currentUser)
            isAuthenticated = true
            currentUser = mockData.currentUser
            currentFamily = mockData.family
            currentMembership = mockData.memberships.first { $0.user?.id == mockData.currentUser.id }
            currentFlow = .familyDashboard
            
        case .visitorUser:
            // Start as authenticated visitor
            mockServices.authService.setMockAuthenticationState(authenticated: true, user: mockData.currentUser)
            isAuthenticated = true
            currentUser = mockData.currentUser
            currentFamily = mockData.family
            currentMembership = mockData.memberships.first { $0.user?.id == mockData.currentUser.id }
            currentFlow = .familyDashboard
        }
    }
    
    // MARK: - Dependencies
    
    private var serviceCoordinator: ServiceCoordinator?
    
    /// Set the service coordinator (called during app initialization)
    func setServiceCoordinator(_ serviceCoordinator: ServiceCoordinator) {
        if !useMockServices {
            self.serviceCoordinator = serviceCoordinator
            checkAuthenticationState()
        }
    }
    
    /// Set the mock service coordinator for prototype (called during prototype initialization)
    func setMockServiceCoordinator(_ mockServiceCoordinator: MockServiceCoordinator) {
        self.mockServiceCoordinator = mockServiceCoordinator
        checkAuthenticationState()
    }
    
    /// Get the service coordinator (returns mock services for prototype)
    var services: ServiceCoordinator? {
        return useMockServices ? nil : serviceCoordinator
    }
    
    /// Get mock services for prototype
    var mockServices: MockServiceCoordinator? {
        return mockServiceCoordinator
    }
    
    // MARK: - Authentication Methods
    
    /// Check if user is already authenticated
    private func checkAuthenticationState() {
        if useMockServices {
            // Use mock authentication state
            guard let mockServices = mockServiceCoordinator else {
                isAuthenticated = false
                currentFlow = .onboarding
                return
            }
            
            isAuthenticated = mockServices.authService.checkAuthenticationStatus()
            currentUser = mockServices.authService.getCurrentUser()
            
            if isAuthenticated, let user = currentUser {
                checkUserFamilyStatusMock(user)
            } else {
                currentFlow = .onboarding
            }
        } else {
            // Use real services (legacy path)
            guard let serviceCoordinator = serviceCoordinator else {
                isAuthenticated = false
                currentFlow = .onboarding
                return
            }
            
            isAuthenticated = serviceCoordinator.authService.checkAuthenticationStatus()
            currentUser = serviceCoordinator.authService.getCurrentUser()
            
            if isAuthenticated, let user = currentUser {
                checkUserFamilyStatus(user)
            } else {
                currentFlow = .onboarding
            }
        }
    }
    
    /// Sign in user with mock authentication
    func signInWithMockAuth() async {
        guard let mockServices = mockServiceCoordinator else { return }
        
        isLoading = true
        
        do {
            // Use mock authentication
            try await mockServices.authService.signInWithApple()
            
            // Update state from mock service
            isAuthenticated = mockServices.authService.isAuthenticated
            currentUser = mockServices.authService.currentUser
            
            if let user = currentUser {
                checkUserFamilyStatusMock(user)
            }
        } catch {
            showError("Mock authentication failed: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    /// Sign in user (legacy method for real services)
    func signIn(user: UserProfile) {
        currentUser = user
        isAuthenticated = true
        
        if useMockServices {
            checkUserFamilyStatusMock(user)
        } else {
            checkUserFamilyStatus(user)
        }
    }
    
    /// Sign out user
    func signOut() async {
        isLoading = true
        
        if useMockServices {
            guard let mockServices = mockServiceCoordinator else { return }
            
            do {
                try await mockServices.authService.signOut()
            } catch {
                showError("Failed to sign out: \(error.localizedDescription)")
            }
        } else {
            guard let serviceCoordinator = serviceCoordinator else { return }
            
            do {
                try await serviceCoordinator.authService.signOut()
            } catch {
                showError("Failed to sign out: \(error.localizedDescription)")
            }
        }
        
        // Reset state
        currentUser = nil
        currentMembership = nil
        currentFamily = nil
        isAuthenticated = false
        currentFlow = .onboarding
        navigationPath = NavigationPath()
        isLoading = false
    }
    
    /// Check user's family status using mock services
    private func checkUserFamilyStatusMock(_ user: UserProfile) {
        guard let mockServices = mockServiceCoordinator else {
            currentFlow = .familySelection
            return
        }
        
        Task {
            do {
                // Get user's active memberships from mock service
                let memberships = try await mockServices.dataService.fetchMemberships(forUser: user)
                let activeMembership = memberships.first { $0.status == .active }
                
                await MainActor.run {
                    if let membership = activeMembership,
                       let family = membership.family {
                        
                        currentMembership = membership
                        currentFamily = family
                        currentFlow = .familyDashboard
                    } else {
                        currentFlow = .familySelection
                    }
                }
            } catch {
                await MainActor.run {
                    currentFlow = .familySelection
                }
            }
        }
    }
    
    /// Check user's family status and set appropriate flow (legacy method for real services)
    private func checkUserFamilyStatus(_ user: UserProfile) {
        guard let serviceCoordinator = serviceCoordinator else {
            currentFlow = .familySelection
            return
        }
        
        do {
            // Get user's active memberships
            let memberships = try serviceCoordinator.dataService.fetchMemberships(forUser: user)
            let activeMembership = memberships.first { $0.status == .active }
            
            if let membership = activeMembership,
               let familyId = membership.family?.id,
               let family = try serviceCoordinator.dataService.fetchFamily(byId: familyId) {
                
                currentMembership = membership
                currentFamily = family
                currentFlow = .familyDashboard
            } else {
                currentFlow = .familySelection
            }
        } catch {
            // If there's an error checking family status, go to family selection
            currentFlow = .familySelection
        }
    }
    
    // MARK: - Family Management
    
    /// Join or create a family with mock services
    func setFamily(_ family: Family, membership: Membership) {
        currentFamily = family
        currentMembership = membership
        currentFlow = .familyDashboard
    }
    
    /// Create family using mock services
    func createFamilyMock(name: String, code: String) async -> Bool {
        guard let mockServices = mockServiceCoordinator,
              let user = currentUser else { return false }
        
        isLoading = true
        
        do {
            // Create family using mock service
            let family = try await mockServices.dataService.createFamily(
                name: name,
                code: code,
                createdByUserId: user.id
            )
            
            // Create membership for creator
            let membership = try await mockServices.dataService.createMembership(
                family: family,
                user: user,
                role: .parentAdmin
            )
            
            await MainActor.run {
                setFamily(family, membership: membership)
                isLoading = false
            }
            
            return true
        } catch {
            await MainActor.run {
                showError("Failed to create family: \(error.localizedDescription)")
                isLoading = false
            }
            return false
        }
    }
    
    /// Join family using mock services
    func joinFamilyMock(code: String, role: Role) async -> Bool {
        guard let mockServices = mockServiceCoordinator,
              let user = currentUser else { return false }
        
        isLoading = true
        
        do {
            // Find family by code
            guard let family = try await mockServices.dataService.fetchFamily(byCode: code) else {
                await MainActor.run {
                    showError("Family not found with code: \(code)")
                    isLoading = false
                }
                return false
            }
            
            // Create membership
            let membership = try await mockServices.dataService.createMembership(
                family: family,
                user: user,
                role: role
            )
            
            await MainActor.run {
                setFamily(family, membership: membership)
                isLoading = false
            }
            
            return true
        } catch {
            await MainActor.run {
                showError("Failed to join family: \(error.localizedDescription)")
                isLoading = false
            }
            return false
        }
    }
    
    /// Leave current family
    func leaveFamily() {
        currentFamily = nil
        currentMembership = nil
        currentFlow = .familySelection
    }
    
    // MARK: - Navigation Methods
    
    /// Navigate to a specific flow
    func navigateTo(_ flow: AppFlow) {
        currentFlow = flow
    }
    
    /// Reset navigation to root
    func resetNavigation() {
        navigationPath = NavigationPath()
    }
    
    /// Navigate through predefined user journey for demo
    func executeUserJourney(_ scenario: UserJourneyScenario) async {
        switch scenario {
        case .newUser:
            await executeNewUserJourney()
        case .existingUser:
            await executeExistingUserJourney()
        case .familyAdmin:
            await executeFamilyAdminJourney()
        case .childUser:
            await executeChildUserJourney()
        case .visitorUser:
            await executeVisitorUserJourney()
        }
    }
    
    /// Execute new user onboarding journey
    private func executeNewUserJourney() async {
        // Start at onboarding
        await MainActor.run { currentFlow = .onboarding }
        
        // Simulate user interaction delays for demo
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        // Sign in
        await signInWithMockAuth()
        
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // Navigate to family selection
        await MainActor.run { currentFlow = .familySelection }
    }
    
    /// Execute existing user journey
    private func executeExistingUserJourney() async {
        // Start at onboarding
        await MainActor.run { currentFlow = .onboarding }
        
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // Sign in and go directly to dashboard
        await signInWithMockAuth()
        
        // Should automatically navigate to dashboard via checkUserFamilyStatusMock
    }
    
    /// Execute family admin journey
    private func executeFamilyAdminJourney() async {
        configureDemoScenario(.familyAdmin)
        
        // Admin starts at dashboard with full access
        await MainActor.run { currentFlow = .familyDashboard }
    }
    
    /// Execute child user journey
    private func executeChildUserJourney() async {
        configureDemoScenario(.childUser)
        
        // Child starts at dashboard with limited access
        await MainActor.run { currentFlow = .familyDashboard }
    }
    
    /// Execute visitor user journey
    private func executeVisitorUserJourney() async {
        configureDemoScenario(.visitorUser)
        
        // Visitor starts at dashboard with restricted access
        await MainActor.run { currentFlow = .familyDashboard }
    }
    
    // MARK: - Error Handling
    
    /// Show error message
    func showError(_ message: String) {
        errorMessage = message
    }
    
    /// Clear error message
    func clearError() {
        errorMessage = nil
    }
    
    // MARK: - Demo Helper Methods
    
    /// Reset app to initial demo state
    func resetToInitialState() {
        guard let mockServices = mockServiceCoordinator else { return }
        
        // Reset all services
        mockServices.resetServices()
        
        // Reset app state
        isAuthenticated = false
        currentUser = nil
        currentFamily = nil
        currentMembership = nil
        currentFlow = .onboarding
        navigationPath = NavigationPath()
        errorMessage = nil
        isLoading = false
        
        // Reset demo manager if active
        if let demoManager = demoJourneyManager, demoManager.isDemoModeActive {
            demoManager.stopDemo()
        }
        
        // Reset to new user scenario
        configureDemoScenario(.newUser)
    }
    
    /// Start a guided demo journey
    func startGuidedDemo(_ scenario: DemoScenario) {
        guard let demoManager = demoJourneyManager else { return }
        demoManager.startDemoJourney(scenario)
    }
    
    /// Get demo manager for UI access
    func getDemoManager() -> DemoJourneyManager? {
        return demoJourneyManager
    }
    
    /// Get demo data manager for UI access
    func getDemoDataManager() -> DemoDataManager? {
        return demoDataManager
    }
    
    /// Simulate error scenario for demo
    func simulateErrorScenario(_ errorType: MockErrorScenario) {
        guard let mockServices = mockServiceCoordinator else { return }
        
        mockServices.simulateErrorScenario(errorType)
        
        // Show appropriate error message
        switch errorType {
        case .networkOutage:
            showError("Network outage detected. Please try again later.")
        case .networkError:
            showError("Network connection lost. Please check your internet connection.")
        case .authenticationIssues:
            showError("Authentication issues detected. Please sign in again.")
        case .authenticationError:
            showError("Authentication session expired. Please sign in again.")
        case .validationProblems:
            showError("Validation problems detected. Please check your input.")
        case .permissionDenials:
            showError("Permission denied. You don't have access to this feature.")
        case .syncConflicts:
            showError("Sync conflicts detected. Some changes may not be saved.")
        case .syncConflict:
            showError("Sync conflict detected. Some changes may not be saved.")
        case .mixedErrors:
            showError("Multiple errors detected. Please try again.")
        case .prototypeDemo:
            showError("This is a prototype demo error for testing purposes.")
        }
    }
    
    /// Get current user's role for UI customization
    func getCurrentUserRole() -> Role? {
        return currentMembership?.role
    }
    
    /// Check if current user has admin privileges
    func isCurrentUserAdmin() -> Bool {
        return currentMembership?.role == .parentAdmin
    }
    
    /// Get mock data appropriate for current user's role
    func getMockDataForCurrentUser() -> (
        calendarEvents: [CalendarEvent],
        tasks: [FamilyTask],
        messages: [FamilyMessage],
        schoolRuns: [SchoolRun]
    ) {
        let role = getCurrentUserRole() ?? .visitor
        return MockDataGenerator.mockDataForRole(role)
    }
    
    /// Validate family code format for mock validation
    func validateFamilyCode(_ code: String) -> Bool {
        // Mock validation - code should be 6-8 characters, alphanumeric
        let trimmedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedCode.count >= 6 && trimmedCode.count <= 8 && trimmedCode.allSatisfy { $0.isLetter || $0.isNumber }
    }
    
    /// Generate mock QR code for family
    func generateMockQRCode(for family: Family) -> String {
        // Return mock QR code data
        return "TRIBEBOARD://join/\(family.code)"
    }
    
    // MARK: - Mock Data Helpers (Legacy - kept for compatibility)
    
    private func getMockMembership(for userId: UUID) -> Membership? {
        guard let mockServices = mockServiceCoordinator else { return nil }
        
        // Get mock memberships and find one for the user
        let mockMemberships = mockServices.dataService.getMockMemberships()
        return mockMemberships.first { $0.user?.id == userId && $0.status == .active }
    }
    
    private func getMockFamily(for familyId: UUID) -> Family? {
        guard let mockServices = mockServiceCoordinator else { return nil }
        
        // Return the default mock family
        return mockServices.dataService.getDefaultMockFamily()
    }
}

// MARK: - App Flow Enum

/// Represents the main navigation flows in the app
enum AppFlow: String, CaseIterable, Codable {
    case onboarding = "onboarding"
    case familySelection = "family_selection"
    case createFamily = "create_family"
    case joinFamily = "join_family"
    case roleSelection = "role_selection"
    case familyDashboard = "family_dashboard"
    
    var displayName: String {
        switch self {
        case .onboarding:
            return "Onboarding"
        case .familySelection:
            return "Family Selection"
        case .createFamily:
            return "Create Family"
        case .joinFamily:
            return "Join Family"
        case .roleSelection:
            return "Role Selection"
        case .familyDashboard:
            return "Family Dashboard"
        }
    }
}