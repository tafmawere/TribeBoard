import SwiftUI
import Foundation

/// Manages guided demo journeys and user scenarios for the prototype
@MainActor
class DemoJourneyManager: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = DemoJourneyManager()
    
    // MARK: - Published Properties
    
    /// Current demo mode state
    @Published var isDemoModeActive: Bool = false
    
    /// Current demo scenario being executed
    @Published var currentDemoScenario: DemoScenario?
    
    /// Current step in the demo journey
    @Published var currentStep: Int = 0
    
    /// Demo progress (0.0 to 1.0)
    @Published var demoProgress: Double = 0.0
    
    /// Demo instructions for current step
    @Published var currentInstructions: String = ""
    
    /// Whether demo is paused
    @Published var isDemoPaused: Bool = false
    
    /// Demo completion status
    @Published var isDemoCompleted: Bool = false
    
    // MARK: - Dependencies
    
    weak var appState: AppState?
    private var demoTimer: Timer?
    
    // MARK: - Initialization
    
    init() {
        setupDemoEnvironment()
    }
    
    /// Set the app state dependency
    func setAppState(_ appState: AppState) {
        self.appState = appState
    }
    
    // MARK: - Demo Control Methods
    
    /// Start a guided demo journey
    func startDemoJourney(_ scenario: DemoScenario) {
        guard let appState = appState else { return }
        
        // Reset demo state
        resetDemoState()
        
        // Configure demo
        currentDemoScenario = scenario
        isDemoModeActive = true
        currentStep = 0
        demoProgress = 0.0
        isDemoCompleted = false
        
        // Reset app to initial state for demo
        appState.resetToInitialState()
        
        // Configure app for specific scenario
        configureDemoScenario(scenario, appState: appState)
        
        // Start the demo journey
        executeCurrentDemoStep()
    }
    
    /// Pause the current demo
    func pauseDemo() {
        isDemoPaused = true
        demoTimer?.invalidate()
        demoTimer = nil
    }
    
    /// Resume the paused demo
    func resumeDemo() {
        isDemoPaused = false
        executeCurrentDemoStep()
    }
    
    /// Stop the current demo
    func stopDemo() {
        isDemoModeActive = false
        isDemoPaused = false
        isDemoCompleted = false
        currentDemoScenario = nil
        currentStep = 0
        demoProgress = 0.0
        currentInstructions = ""
        
        demoTimer?.invalidate()
        demoTimer = nil
        
        // Reset app state
        appState?.resetToInitialState()
    }
    
    /// Move to next demo step
    func nextDemoStep() {
        guard let scenario = currentDemoScenario else { return }
        
        let totalSteps = getDemoSteps(for: scenario).count
        
        if currentStep < totalSteps - 1 {
            currentStep += 1
            demoProgress = Double(currentStep) / Double(totalSteps - 1)
            executeCurrentDemoStep()
        } else {
            completeDemoJourney()
        }
    }
    
    /// Move to previous demo step
    func previousDemoStep() {
        guard currentStep > 0 else { return }
        
        currentStep -= 1
        
        if let scenario = currentDemoScenario {
            let totalSteps = getDemoSteps(for: scenario).count
            demoProgress = Double(currentStep) / Double(totalSteps - 1)
        }
        
        executeCurrentDemoStep()
    }
    
    /// Skip to specific demo step
    func skipToStep(_ stepIndex: Int) {
        guard let scenario = currentDemoScenario else { return }
        
        let totalSteps = getDemoSteps(for: scenario).count
        guard stepIndex >= 0 && stepIndex < totalSteps else { return }
        
        currentStep = stepIndex
        demoProgress = Double(currentStep) / Double(totalSteps - 1)
        executeCurrentDemoStep()
    }
    
    /// Reset demo to initial state
    func resetDemoToStart() {
        guard let scenario = currentDemoScenario else { return }
        
        currentStep = 0
        demoProgress = 0.0
        isDemoCompleted = false
        isDemoPaused = false
        
        // Reset app state
        appState?.resetToInitialState()
        configureDemoScenario(scenario, appState: appState!)
        
        executeCurrentDemoStep()
    }
    
    // MARK: - Private Demo Execution Methods
    
    /// Setup demo environment
    private func setupDemoEnvironment() {
        // Configure any global demo settings
    }
    
    /// Reset demo state
    private func resetDemoState() {
        isDemoModeActive = false
        isDemoPaused = false
        isDemoCompleted = false
        currentDemoScenario = nil
        currentStep = 0
        demoProgress = 0.0
        currentInstructions = ""
        
        demoTimer?.invalidate()
        demoTimer = nil
    }
    
    /// Configure app for specific demo scenario
    private func configureDemoScenario(_ scenario: DemoScenario, appState: AppState) {
        switch scenario {
        case .newUserOnboarding:
            appState.configureDemoScenario(.newUser)
        case .existingUserLogin:
            appState.configureDemoScenario(.existingUser)
        case .familyAdminTasks:
            appState.configureDemoScenario(.familyAdmin)
        case .childUserExperience:
            appState.configureDemoScenario(.childUser)
        case .completeFeatureTour:
            appState.configureDemoScenario(.familyAdmin) // Use admin for full access
        }
    }
    
    /// Execute the current demo step
    private func executeCurrentDemoStep() {
        guard let scenario = currentDemoScenario,
              let appState = appState else { return }
        
        let steps = getDemoSteps(for: scenario)
        guard currentStep < steps.count else { return }
        
        let step = steps[currentStep]
        currentInstructions = step.instructions
        
        // Execute step action
        Task {
            await step.action(appState, self)
        }
    }
    
    /// Complete the demo journey
    private func completeDemoJourney() {
        isDemoCompleted = true
        demoProgress = 1.0
        currentInstructions = "Demo completed! You can restart or try a different scenario."
        
        demoTimer?.invalidate()
        demoTimer = nil
    }
    
    /// Get demo steps for a scenario
    private func getDemoSteps(for scenario: DemoScenario) -> [DemoStep] {
        switch scenario {
        case .newUserOnboarding:
            return newUserOnboardingSteps
        case .existingUserLogin:
            return existingUserLoginSteps
        case .familyAdminTasks:
            return familyAdminTasksSteps
        case .childUserExperience:
            return childUserExperienceSteps
        case .completeFeatureTour:
            return completeFeatureTourSteps
        }
    }
    
    // MARK: - Demo Step Definitions
    
    /// New user onboarding demo steps
    private var newUserOnboardingSteps: [DemoStep] {
        return [
            DemoStep(
                title: "Welcome Screen",
                instructions: "Welcome to TribeBoard! This demo shows how a new user would first experience the app.",
                action: { appState, demoManager in
                    appState.currentFlow = .onboarding
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    demoManager.nextDemoStep()
                }
            ),
            DemoStep(
                title: "Sign In",
                instructions: "New users can sign in with Apple ID or Google. We'll simulate a successful sign-in.",
                action: { appState, demoManager in
                    await appState.signInWithMockAuth()
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                    demoManager.nextDemoStep()
                }
            ),
            DemoStep(
                title: "Family Selection",
                instructions: "After signing in, users choose to create a new family or join an existing one.",
                action: { appState, demoManager in
                    appState.currentFlow = .familySelection
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    demoManager.nextDemoStep()
                }
            ),
            DemoStep(
                title: "Create Family",
                instructions: "Let's create a new family. Users enter a family name and get a unique family code.",
                action: { appState, demoManager in
                    appState.currentFlow = .createFamily
                    try? await Task.sleep(nanoseconds: 2_500_000_000)
                    
                    // Simulate family creation
                    let success = await appState.createFamilyMock(name: "Demo Family", code: "DEMO24")
                    if success {
                        try? await Task.sleep(nanoseconds: 1_000_000_000)
                        demoManager.nextDemoStep()
                    }
                }
            ),
            DemoStep(
                title: "Role Selection",
                instructions: "Family creators automatically get admin role, but let's see the role selection interface.",
                action: { appState, demoManager in
                    appState.currentFlow = .roleSelection
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    demoManager.nextDemoStep()
                }
            ),
            DemoStep(
                title: "Family Dashboard",
                instructions: "Welcome to your family dashboard! This is where you'll manage your family's activities.",
                action: { appState, demoManager in
                    appState.currentFlow = .familyDashboard
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                    demoManager.nextDemoStep()
                }
            )
        ]
    }
    
    /// Existing user login demo steps
    private var existingUserLoginSteps: [DemoStep] {
        return [
            DemoStep(
                title: "Returning User",
                instructions: "This demo shows how existing users quickly access their family dashboard.",
                action: { appState, demoManager in
                    appState.currentFlow = .onboarding
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                    demoManager.nextDemoStep()
                }
            ),
            DemoStep(
                title: "Quick Sign In",
                instructions: "Existing users sign in and are automatically taken to their family dashboard.",
                action: { appState, demoManager in
                    await appState.signInWithMockAuth()
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    demoManager.nextDemoStep()
                }
            ),
            DemoStep(
                title: "Family Dashboard",
                instructions: "Existing users land directly on their family dashboard with all their family data.",
                action: { appState, demoManager in
                    appState.currentFlow = .familyDashboard
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    demoManager.nextDemoStep()
                }
            )
        ]
    }
    
    /// Family admin tasks demo steps
    private var familyAdminTasksSteps: [DemoStep] {
        return [
            DemoStep(
                title: "Admin Dashboard",
                instructions: "Family admins have full access to manage family members, settings, and activities.",
                action: { appState, demoManager in
                    appState.currentFlow = .familyDashboard
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    demoManager.nextDemoStep()
                }
            ),
            DemoStep(
                title: "Member Management",
                instructions: "Admins can invite new members, assign roles, and manage family membership.",
                action: { appState, demoManager in
                    // Navigate to member management (simulated)
                    try? await Task.sleep(nanoseconds: 2_500_000_000)
                    demoManager.nextDemoStep()
                }
            ),
            DemoStep(
                title: "Task Assignment",
                instructions: "Admins can create and assign tasks to family members with point values.",
                action: { appState, demoManager in
                    // Navigate to task management (simulated)
                    try? await Task.sleep(nanoseconds: 2_500_000_000)
                    demoManager.nextDemoStep()
                }
            ),
            DemoStep(
                title: "Family Settings",
                instructions: "Admins control family-wide settings like notifications, privacy, and permissions.",
                action: { appState, demoManager in
                    // Navigate to settings (simulated)
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    demoManager.nextDemoStep()
                }
            )
        ]
    }
    
    /// Child user experience demo steps
    private var childUserExperienceSteps: [DemoStep] {
        return [
            DemoStep(
                title: "Child Dashboard",
                instructions: "Children see a simplified, age-appropriate interface focused on their tasks and activities.",
                action: { appState, demoManager in
                    appState.currentFlow = .familyDashboard
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    demoManager.nextDemoStep()
                }
            ),
            DemoStep(
                title: "My Tasks",
                instructions: "Children can view their assigned tasks and mark them as complete to earn points.",
                action: { appState, demoManager in
                    // Navigate to child's tasks view (simulated)
                    try? await Task.sleep(nanoseconds: 2_500_000_000)
                    demoManager.nextDemoStep()
                }
            ),
            DemoStep(
                title: "Family Calendar",
                instructions: "Children can see family events and their own schedule in a kid-friendly format.",
                action: { appState, demoManager in
                    // Navigate to calendar (simulated)
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    demoManager.nextDemoStep()
                }
            ),
            DemoStep(
                title: "Messages",
                instructions: "Children can send messages to family members with appropriate supervision.",
                action: { appState, demoManager in
                    // Navigate to messaging (simulated)
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    demoManager.nextDemoStep()
                }
            )
        ]
    }
    
    /// Complete feature tour demo steps
    private var completeFeatureTourSteps: [DemoStep] {
        return [
            DemoStep(
                title: "Dashboard Overview",
                instructions: "The family dashboard is your central hub for all family activities and information.",
                action: { appState, demoManager in
                    appState.currentFlow = .familyDashboard
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    demoManager.nextDemoStep()
                }
            ),
            DemoStep(
                title: "Calendar Module",
                instructions: "View and manage family events, birthdays, appointments, and school activities.",
                action: { appState, demoManager in
                    // Navigate to calendar (simulated)
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                    demoManager.nextDemoStep()
                }
            ),
            DemoStep(
                title: "Tasks & Chores",
                instructions: "Assign tasks, track completion, and manage the family point system.",
                action: { appState, demoManager in
                    // Navigate to tasks (simulated)
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                    demoManager.nextDemoStep()
                }
            ),
            DemoStep(
                title: "Family Messaging",
                instructions: "Stay connected with family chat and the family noticeboard.",
                action: { appState, demoManager in
                    // Navigate to messaging (simulated)
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                    demoManager.nextDemoStep()
                }
            ),
            DemoStep(
                title: "School Run Tracker",
                instructions: "Coordinate school pickups and drop-offs with GPS tracking and notifications.",
                action: { appState, demoManager in
                    // Navigate to school run (simulated)
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                    demoManager.nextDemoStep()
                }
            ),
            DemoStep(
                title: "Settings & Privacy",
                instructions: "Manage family settings, privacy controls, and member permissions.",
                action: { appState, demoManager in
                    // Navigate to settings (simulated)
                    try? await Task.sleep(nanoseconds: 2_500_000_000)
                    demoManager.nextDemoStep()
                }
            )
        ]
    }
}

// MARK: - Demo Data Structures
// DemoScenario is defined in TribeBoard/Models/MockDataGenerator.swift

/// Represents a single step in a demo journey
struct DemoStep {
    let title: String
    let instructions: String
    let action: (AppState, DemoJourneyManager) async -> Void
}

// MockErrorScenario is defined in TribeBoard/Models/MockErrorTypes.swift