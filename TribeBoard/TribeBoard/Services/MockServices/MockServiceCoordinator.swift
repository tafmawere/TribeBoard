import Foundation
import SwiftUI

/// Mock service coordinator for UI/UX prototype that provides all mock services
@MainActor
class MockServiceCoordinator: ObservableObject {
    
    // MARK: - Mock Services
    
    /// Mock authentication service
    let authService: MockAuthService
    
    /// Convenience accessor for mock auth service
    var mockAuthService: MockAuthService {
        return authService
    }
    
    /// Mock data service
    let dataService: MockDataService
    
    /// Mock CloudKit service
    let cloudKitService: MockCloudKitService
    
    /// Mock sync manager
    let syncManager: MockSyncManager
    
    // MARK: - Published Properties
    
    /// Overall service initialization status
    @Published var isInitialized: Bool = false
    
    /// Loading state during initialization
    @Published var isInitializing: Bool = false
    
    /// Initialization error if any
    @Published var initializationError: String?
    
    // MARK: - Initialization
    
    init() {
        // Initialize all mock services
        self.authService = MockAuthService()
        self.dataService = MockDataService()
        self.cloudKitService = MockCloudKitService()
        self.syncManager = MockSyncManager(
            dataService: dataService,
            cloudKitService: cloudKitService
        )
        
        // Setup service relationships
        setupServiceRelationships()
    }
    
    // MARK: - Service Setup
    
    /// Setup relationships between mock services
    private func setupServiceRelationships() {
        // In a real app, services would have dependencies
        // For the mock, we just ensure they're all available
    }
    
    /// Initialize all mock services
    func initializeServices() async {
        guard !isInitialized && !isInitializing else { return }
        
        isInitializing = true
        initializationError = nil
        
        do {
            // Simulate initialization time for realistic feel
            try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
            
            // Initialize CloudKit service
            try await cloudKitService.performInitialSetup()
            
            // Check existing authentication
            await authService.checkExistingAuthentication()
            
            // Start periodic sync simulation
            cloudKitService.startPeriodicSyncSimulation()
            
            // Mark as initialized
            isInitialized = true
            isInitializing = false
            
        } catch {
            initializationError = error.localizedDescription
            isInitializing = false
        }
    }
    
    /// Reset all services to initial state (useful for demo)
    func resetServices() {
        // Reset authentication
        authService.setMockAuthenticationState(authenticated: false)
        
        // Reset data
        dataService.resetMockData()
        
        // Reset sync status
        cloudKitService.syncStatus = .idle
        
        // Reset initialization state
        isInitialized = false
        initializationError = nil
    }
    
    // MARK: - Demo Helper Methods
    
    /// Configure services for specific demo scenario
    func configureDemoScenario(_ scenario: DemoScenario) {
        switch scenario {
        case .newUserOnboarding:
            // Start with unauthenticated state
            authService.setMockAuthenticationState(authenticated: false)
            
        case .existingUserLogin:
            // Start with authenticated state and existing family
            if let mockUser = dataService.getMockUsers().first {
                authService.setMockAuthenticationState(authenticated: true, user: mockUser)
            }
            
        case .familyAdminTasks:
            // Start as authenticated parent admin
            let adminUser = UserProfile(
                displayName: "Admin User",
                appleUserIdHash: "mock_admin_hash"
            )
            authService.setMockAuthenticationState(authenticated: true, user: adminUser)
            
        case .childUserExperience:
            // Start as authenticated child
            if let childUser = dataService.getMockUsers().first(where: { $0.displayName.contains("Alex") }) {
                authService.setMockAuthenticationState(authenticated: true, user: childUser)
            }
            
        case .completeFeatureTour:
            // Start as authenticated admin for full access
            let adminUser = UserProfile(
                displayName: "Tour User",
                appleUserIdHash: "mock_tour_hash"
            )
            authService.setMockAuthenticationState(authenticated: true, user: adminUser)
            
        case .homeLifeMealPlanning, .homeLifeGroceryShopping, .homeLifeTaskManagement, .homeLifeCompleteWorkflow:
            // Start as authenticated admin for HomeLife features
            let adminUser = UserProfile(
                displayName: "HomeLife User",
                appleUserIdHash: "mock_homelife_hash"
            )
            authService.setMockAuthenticationState(authenticated: true, user: adminUser)
        }
    }
    
    /// Simulate various error scenarios for demo
    func simulateErrorScenario(_ errorType: MockErrorScenario) {
        switch errorType {
        case .networkOutage:
            cloudKitService.simulateNetworkError()
            
        case .networkError:
            cloudKitService.simulateNetworkError()
            
        case .syncConflicts:
            cloudKitService.simulateSyncConflict()
            
        case .syncConflict:
            cloudKitService.simulateSyncConflict()
            
        case .authenticationIssues:
            Task {
                try? await authService.signOut()
            }
            
        case .authenticationError:
            Task {
                try? await authService.signOut()
            }
            
        case .validationProblems:
            // Simulate validation errors
            print("Simulating validation problems")
            
        case .permissionDenials:
            // Simulate permission errors
            print("Simulating permission denials")
            
        case .mixedErrors:
            // Simulate a mix of different errors
            print("Simulating mixed error scenarios")
            
        case .prototypeDemo:
            // Simulate prototype-specific demo errors
            print("Simulating prototype demo errors")
        }
    }
    
    // MARK: - Service Access
    
    /// Get the mock authentication service
    func getAuthService() -> MockAuthService {
        return authService
    }
    
    /// Get the mock data service
    func getDataService() -> MockDataService {
        return dataService
    }
    
    /// Get the mock CloudKit service
    func getCloudKitService() -> MockCloudKitService {
        return cloudKitService
    }
    
    /// Get the mock sync manager
    func getSyncManager() -> MockSyncManager {
        return syncManager
    }
}

// MARK: - Demo Scenarios
// DemoScenario is defined in TribeBoard/Models/MockDataGenerator.swift

// MARK: - Mock Error Scenarios
// MockErrorScenario is defined in TribeBoard/Models/MockErrorTypes.swift

// MARK: - Mock Sync Manager

@MainActor
class MockSyncManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isSyncing: Bool = false
    @Published var lastSyncDate: Date?
    @Published var syncError: String?
    
    // MARK: - Dependencies
    
    private let dataService: MockDataService
    private let cloudKitService: MockCloudKitService
    
    // MARK: - Initialization
    
    init(dataService: MockDataService, cloudKitService: MockCloudKitService) {
        self.dataService = dataService
        self.cloudKitService = cloudKitService
    }
    
    // MARK: - Sync Operations
    
    /// Mock sync all data
    func syncAll() async {
        isSyncing = true
        syncError = nil
        
        // Simulate sync time
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        // Always succeed for prototype
        lastSyncDate = Date()
        isSyncing = false
    }
    
    /// Mock sync specific family
    func syncFamily(_ family: Family) async {
        isSyncing = true
        
        let result = await cloudKitService.syncFamily(family)
        
        switch result {
        case .success:
            lastSyncDate = Date()
            syncError = nil
        case .failure(let error):
            syncError = error.localizedDescription
        }
        
        isSyncing = false
    }
    
    /// Mock check sync status
    func checkSyncStatus() -> Bool {
        return !isSyncing && syncError == nil
    }
}