import SwiftUI
import Foundation

/// Manages demo data lifecycle, reset functionality, and scenario switching
@MainActor
class DemoDataManager: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Current demo data state
    @Published var currentDemoData: DemoShowcaseData?
    
    /// Available demo scenarios
    @Published var availableScenarios: [DemoScenario] = DemoScenario.allCases
    
    /// Demo reset history for undo functionality
    @Published var resetHistory: [DemoResetPoint] = []
    
    // MARK: - Dependencies
    
    private weak var appState: AppState?
    private weak var demoJourneyManager: DemoJourneyManager?
    
    // MARK: - Initialization
    
    init() {
        loadInitialDemoData()
    }
    
    /// Set dependencies
    func setDependencies(appState: AppState, demoJourneyManager: DemoJourneyManager) {
        self.appState = appState
        self.demoJourneyManager = demoJourneyManager
    }
    
    // MARK: - Demo Data Management
    
    /// Load initial demo data
    private func loadInitialDemoData() {
        currentDemoData = MockDataGenerator.mockDemoShowcaseData()
    }
    
    /// Reset demo data to initial state
    func resetToInitialState() {
        // Create reset point for undo functionality
        createResetPoint(description: "Reset to Initial State")
        
        // Reset app state
        appState?.resetToInitialState()
        
        // Reset demo data
        loadInitialDemoData()
        
        // Stop any active demo
        demoJourneyManager?.stopDemo()
    }
    
    /// Reset demo data for specific scenario
    func resetForScenario(_ scenario: DemoScenario) {
        createResetPoint(description: "Reset for \(scenario.displayName)")
        
        // Generate scenario-specific data
        let scenarioData = MockDataGenerator.mockDataForDemoScenario(scenario)
        
        // Update app state with scenario data
        appState?.configureDemoScenario(convertToUserJourneyScenario(scenario))
        
        // Update current demo data
        currentDemoData = DemoShowcaseData(
            family: scenarioData.family,
            users: scenarioData.users,
            memberships: scenarioData.memberships,
            calendarEvents: scenarioData.calendarEvents,
            tasks: scenarioData.tasks,
            messages: scenarioData.messages,
            noticeboardPosts: MockDataGenerator.mockNoticeboardPosts(),
            schoolRuns: scenarioData.schoolRuns,
            settings: MockDataGenerator.mockFamilySettings(for: scenarioData.family.id)
        )
    }
    
    /// Create a reset point for undo functionality
    private func createResetPoint(description: String) {
        guard let currentData = currentDemoData,
              let appState = appState else { return }
        
        let resetPoint = DemoResetPoint(
            timestamp: Date(),
            description: description,
            demoData: currentData,
            appFlow: appState.currentFlow,
            userScenario: appState.currentScenario,
            isAuthenticated: appState.isAuthenticated,
            currentUser: appState.currentUser,
            currentFamily: appState.currentFamily,
            currentMembership: appState.currentMembership
        )
        
        resetHistory.append(resetPoint)
        
        // Keep only last 10 reset points
        if resetHistory.count > 10 {
            resetHistory.removeFirst()
        }
    }
    
    /// Restore from a reset point
    func restoreFromResetPoint(_ resetPoint: DemoResetPoint) {
        guard let appState = appState else { return }
        
        // Restore demo data
        currentDemoData = resetPoint.demoData
        
        // Restore app state
        appState.currentFlow = resetPoint.appFlow
        appState.currentScenario = resetPoint.userScenario
        appState.isAuthenticated = resetPoint.isAuthenticated
        appState.currentUser = resetPoint.currentUser
        appState.currentFamily = resetPoint.currentFamily
        appState.currentMembership = resetPoint.currentMembership
        
        // Stop any active demo
        demoJourneyManager?.stopDemo()
    }
    
    /// Clear reset history
    func clearResetHistory() {
        resetHistory.removeAll()
    }
    
    // MARK: - Demo Scenario Management
    
    /// Get demo data for specific scenario
    func getDemoDataForScenario(_ scenario: DemoScenario) -> DemoScenarioData {
        return MockDataGenerator.mockDataForDemoScenario(scenario)
    }
    
    /// Switch to different demo scenario
    func switchToScenario(_ scenario: DemoScenario) {
        resetForScenario(scenario)
        
        // Start the demo journey if requested
        demoJourneyManager?.startDemoJourney(scenario)
    }
    
    /// Get available scenarios for current user role
    func getAvailableScenariosForCurrentUser() -> [DemoScenario] {
        guard let appState = appState,
              let currentUser = appState.currentUser,
              let membership = appState.currentMembership else {
            return availableScenarios
        }
        
        // Filter scenarios based on user role
        switch membership.role {
        case .parentAdmin:
            return availableScenarios // Admin can access all scenarios
        case .adult:
            return availableScenarios.filter { $0 != .familyAdminTasks }
        case .kid:
            return [.childUserExperience, .newUserOnboarding]
        case .visitor:
            return [.existingUserLogin, .newUserOnboarding]
        }
    }
    
    // MARK: - Demo Data Validation
    
    /// Validate current demo data integrity
    func validateDemoData() -> DemoDataValidationResult {
        guard let demoData = currentDemoData else {
            return DemoDataValidationResult(
                isValid: false,
                issues: ["No demo data loaded"],
                recommendations: ["Reset to initial state"]
            )
        }
        
        var issues: [String] = []
        var recommendations: [String] = []
        
        // Validate family data
        if demoData.users.isEmpty {
            issues.append("No users in demo data")
            recommendations.append("Reset demo data")
        }
        
        if demoData.memberships.isEmpty {
            issues.append("No memberships in demo data")
            recommendations.append("Reset demo data")
        }
        
        // Validate data consistency
        let userIds = Set(demoData.users.map { $0.id })
        let membershipUserIds = Set(demoData.memberships.compactMap { $0.user?.id })
        
        if !membershipUserIds.isSubset(of: userIds) {
            issues.append("Membership data references non-existent users")
            recommendations.append("Reset demo data")
        }
        
        // Validate task assignments
        let taskAssignees = Set(demoData.tasks.map { $0.assignedTo })
        if !taskAssignees.isSubset(of: userIds) {
            issues.append("Tasks assigned to non-existent users")
            recommendations.append("Regenerate task data")
        }
        
        return DemoDataValidationResult(
            isValid: issues.isEmpty,
            issues: issues,
            recommendations: recommendations
        )
    }
    
    /// Fix demo data issues automatically
    func fixDemoDataIssues() {
        let validation = validateDemoData()
        
        if !validation.isValid {
            // Reset to initial state to fix all issues
            resetToInitialState()
        }
    }
    
    // MARK: - Demo Data Export/Import
    
    /// Export current demo data for sharing
    func exportDemoData() -> DemoDataExport? {
        guard let demoData = currentDemoData,
              let appState = appState else { return nil }
        
        return DemoDataExport(
            timestamp: Date(),
            version: "1.0",
            demoData: demoData,
            appState: DemoAppStateSnapshot(
                currentFlow: appState.currentFlow,
                currentScenario: appState.currentScenario,
                isAuthenticated: appState.isAuthenticated,
                currentUserId: appState.currentUser?.id,
                currentFamilyId: appState.currentFamily?.id
            )
        )
    }
    
    /// Import demo data from export
    func importDemoData(_ export: DemoDataExport) {
        createResetPoint(description: "Import Demo Data")
        
        // Import demo data
        currentDemoData = export.demoData
        
        // Import app state
        guard let appState = appState else { return }
        
        appState.currentFlow = export.appState.currentFlow
        appState.currentScenario = export.appState.currentScenario
        appState.isAuthenticated = export.appState.isAuthenticated
        
        // Find and set current user and family from imported data
        if let userId = export.appState.currentUserId {
            appState.currentUser = export.demoData.users.first { $0.id == userId }
        }
        
        if let familyId = export.appState.currentFamilyId {
            if export.demoData.family.id == familyId {
                appState.currentFamily = export.demoData.family
                
                // Find membership for current user
                if let userId = appState.currentUser?.id {
                    appState.currentMembership = export.demoData.memberships.first { $0.user?.id == userId }
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    /// Convert DemoScenario to UserJourneyScenario
    private func convertToUserJourneyScenario(_ demoScenario: DemoScenario) -> UserJourneyScenario {
        switch demoScenario {
        case .newUserOnboarding:
            return .newUser
        case .existingUserLogin:
            return .existingUser
        case .familyAdminTasks:
            return .familyAdmin
        case .childUserExperience:
            return .childUser
        case .completeFeatureTour:
            return .familyAdmin // Use admin for full access
        }
    }
    
    /// Get demo statistics
    func getDemoStatistics() -> DemoStatistics {
        guard let demoData = currentDemoData else {
            return DemoStatistics(
                totalUsers: 0,
                totalTasks: 0,
                totalMessages: 0,
                totalEvents: 0,
                completedTasks: 0,
                activeMembers: 0
            )
        }
        
        return DemoStatistics(
            totalUsers: demoData.users.count,
            totalTasks: demoData.tasks.count,
            totalMessages: demoData.messages.count,
            totalEvents: demoData.calendarEvents.count,
            completedTasks: demoData.tasks.filter { $0.status == .completed }.count,
            activeMembers: demoData.memberships.filter { $0.status == .active }.count
        )
    }
}

// MARK: - Demo Data Structures

/// Represents a point in time that can be restored
struct DemoResetPoint {
    let id = UUID()
    let timestamp: Date
    let description: String
    let demoData: DemoShowcaseData
    let appFlow: AppFlow
    let userScenario: UserJourneyScenario
    let isAuthenticated: Bool
    let currentUser: UserProfile?
    let currentFamily: Family?
    let currentMembership: Membership?
}

/// Result of demo data validation
struct DemoDataValidationResult {
    let isValid: Bool
    let issues: [String]
    let recommendations: [String]
}

/// Demo data export format
struct DemoDataExport {
    let timestamp: Date
    let version: String
    let demoData: DemoShowcaseData
    let appState: DemoAppStateSnapshot
}

/// Snapshot of app state for export
struct DemoAppStateSnapshot {
    let currentFlow: AppFlow
    let currentScenario: UserJourneyScenario
    let isAuthenticated: Bool
    let currentUserId: UUID?
    let currentFamilyId: UUID?
}

/// Demo statistics
struct DemoStatistics {
    let totalUsers: Int
    let totalTasks: Int
    let totalMessages: Int
    let totalEvents: Int
    let completedTasks: Int
    let activeMembers: Int
    
    var taskCompletionRate: Double {
        guard totalTasks > 0 else { return 0.0 }
        return Double(completedTasks) / Double(totalTasks)
    }
}

// MARK: - Codable Extensions
// Note: For the prototype, we'll disable complex Codable implementations
// In a production app, these types would need proper Codable conformance