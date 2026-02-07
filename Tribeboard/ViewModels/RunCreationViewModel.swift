//
//  RunCreationViewModel.swift
//  Tribeboard
//
//  Created by Kiro on 2026/02/03.
//

import Foundation
import Combine
import CoreLocation

/// Main coordinator for the multi-step run creation workflow
/// Implements Requirements 4.1, 4.2, 4.3, 4.4, 4.5
@MainActor
class RunCreationViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var currentStep: RunCreationStep = .metadata
    @Published var isLoading: Bool = false
    @Published var error: RunCreationError?
    @Published var canProceedToNext: Bool = false
    @Published var isCreatingRun: Bool = false
    @Published var createdRunId: String?
    @Published var createdRun: Run?
    
    // Step ViewModels
    @Published var step1ViewModel: Step1MetadataViewModel
    @Published var step2ViewModel: Step2DriverViewModel
    @Published var step3ViewModel: Step3PassengerViewModel
    @Published var step4ViewModel: Step4StopsViewModel
    
    // MARK: - Private Properties
    
    private let runEventService: RunEventService
    private let firebaseService: MockFirebaseRunService
    private let roleContext: RoleContext
    private var cancellables = Set<AnyCancellable>()
    var onRunCreated: ((Run) -> Void)?
    
    // MARK: - Initialization
    
    init(runEventService: RunEventService, firebaseService: MockFirebaseRunService, roleContext: RoleContext) {
        self.runEventService = runEventService
        self.firebaseService = firebaseService
        self.roleContext = roleContext
        
        // Initialize step ViewModels
        self.step1ViewModel = Step1MetadataViewModel()
        self.step2ViewModel = Step2DriverViewModel()
        self.step3ViewModel = Step3PassengerViewModel()
        self.step4ViewModel = Step4StopsViewModel()
        
        setupStepValidation()
    }
    
    // Convenience initializer for backward compatibility
    convenience init(runEventService: RunEventService, roleContext: RoleContext) {
        let firebaseService = MockFirebaseRunService()
        self.init(runEventService: runEventService, firebaseService: firebaseService, roleContext: roleContext)
    }
    
    // MARK: - Public Interface
    
    /// Move to the next step in the workflow
    func nextStep() {
        guard canProceedToNext else { return }
        
        switch currentStep {
        case .metadata:
            currentStep = .driver
        case .driver:
            currentStep = .passengers
        case .passengers:
            currentStep = .stops
        case .stops:
            // Final step - show confirmation or create the run
            break // Confirmation is handled by confirmAndCreateRun()
        }
    }
    
    /// Confirm run details and create the run
    /// Implements Requirement 4.6 - final run confirmation and backend creation
    func confirmAndCreateRun() {
        guard currentStep == .stops && canProceedToNext else { return }
        
        Task {
            await createRun()
        }
    }
    
    /// Get a summary of the run for confirmation display
    func getRunSummary() -> RunSummary {
        let selectedDriver = step2ViewModel.getSelectedDriver()
        return RunSummary(
            title: step1ViewModel.runTitle,
            scheduledTime: step1ViewModel.runDateTime,
            driverName: selectedDriver?.displayName ?? "Unknown Driver",
            passengerCount: step3ViewModel.selectedPassengers.count,
            passengerNames: step3ViewModel.selectedPassengers.map { $0.displayName },
            stopCount: step4ViewModel.stops.count,
            stopLabels: step4ViewModel.stops.map { $0.label }
        )
    }
    
    /// Move to the previous step
    func previousStep() {
        switch currentStep {
        case .metadata:
            break // Can't go back from first step
        case .driver:
            currentStep = .metadata
        case .passengers:
            currentStep = .driver
        case .stops:
            currentStep = .passengers
        }
    }
    
    /// Reset the entire workflow
    func reset() {
        currentStep = .metadata
        step1ViewModel.reset()
        step2ViewModel.reset()
        step3ViewModel.reset()
        step4ViewModel.reset()
        error = nil
        isCreatingRun = false
        createdRunId = nil
    }
    
    /// Create the final run with all collected data
    /// Implements Requirement 4.6 - run confirmation and backend creation
    private func createRun() async {
        isLoading = true
        isCreatingRun = true
        error = nil
        createdRunId = nil
        
        do {
            // Validate all steps before creation
            try validateAllSteps()
            
            // Create the run object from collected data
            let run = createRunFromSteps()
            
            // Submit run creation request to backend
            let createdRun = try await submitRunToBackend(run)
            
            // Handle creation success - notify all relevant family members
            await handleCreationSuccess(createdRun)
            
            // Store the created run ID for reference
            createdRunId = createdRun.id
            
        } catch {
            // Handle creation error responses
            await handleCreationError(error)
        }
        
        isLoading = false
        isCreatingRun = false
    }
    
    /// Handle successful run creation
    private func handleCreationSuccess(_ run: Run) async {
        print("Run created successfully: \(run.title) (ID: \(run.id))")
        
        // Store the created run
        createdRun = run
        createdRunId = run.id
        
        // Notify observers through the run event service
        let creationEvent = RunEvent(
            runId: run.id,
            type: .runCreated,
            actorId: roleContext.userId,
            stateBefore: nil,
            stateAfter: .scheduled,
            currentStopIndex: 0,
            note: "Run '\(run.title)' created"
        )
        
        runEventService.broadcastEvent(creationEvent)
        
        // Call the callback to show confirmation screen
        onRunCreated?(run)
        
        // Reset the workflow for potential next run creation
        reset()
    }
    
    /// Handle run creation errors with appropriate error responses
    private func handleCreationError(_ error: Error) async {
        print("Run creation failed: \(error.localizedDescription)")
        
        if let runError = error as? RunCreationError {
            self.error = runError
        } else if let firebaseError = error as? FirebaseError {
            switch firebaseError {
            case .networkError:
                self.error = .networkError("Unable to connect to server. Please check your internet connection.")
            case .invalidData:
                self.error = .creationFailed("Invalid run data. Please review your inputs.")
            default:
                self.error = .creationFailed(firebaseError.localizedDescription)
            }
        } else {
            self.error = .creationFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Private Methods
    
    private func setupStepValidation() {
        // Monitor current step changes and update validation accordingly
        $currentStep
            .sink { [weak self] step in
                self?.updateValidationForCurrentStep()
            }
            .store(in: &cancellables)
        
        // Monitor each step's validation
        step1ViewModel.$isValid
            .sink { [weak self] _ in
                self?.updateValidationForCurrentStep()
            }
            .store(in: &cancellables)
        
        step2ViewModel.$isValid
            .sink { [weak self] _ in
                self?.updateValidationForCurrentStep()
            }
            .store(in: &cancellables)
        
        step3ViewModel.$isValid
            .sink { [weak self] _ in
                self?.updateValidationForCurrentStep()
            }
            .store(in: &cancellables)
        
        step4ViewModel.$isValid
            .sink { [weak self] _ in
                self?.updateValidationForCurrentStep()
            }
            .store(in: &cancellables)
    }
    
    private func updateValidationForCurrentStep() {
        switch currentStep {
        case .metadata:
            canProceedToNext = step1ViewModel.isValid
        case .driver:
            canProceedToNext = step2ViewModel.isValid
        case .passengers:
            canProceedToNext = step3ViewModel.isValid
        case .stops:
            canProceedToNext = step4ViewModel.isValid
        }
    }
    
    private func validateAllSteps() throws {
        guard step1ViewModel.isValid else {
            throw RunCreationError.invalidMetadata("Run title and time are required")
        }
        
        guard step2ViewModel.isValid else {
            throw RunCreationError.invalidDriver("Driver selection is required")
        }
        
        guard step3ViewModel.isValid else {
            throw RunCreationError.invalidPassengers("At least one passenger must be selected")
        }
        
        guard step4ViewModel.isValid else {
            throw RunCreationError.invalidStops("At least one stop must be defined")
        }
    }
    
    private func createRunFromSteps() -> Run {
        return Run(
            title: step1ViewModel.runTitle,
            scheduledTime: step1ViewModel.runDateTime,
            driverId: step2ViewModel.selectedDriverId!,
            stops: step4ViewModel.stops,
            passengers: step3ViewModel.selectedPassengers,
            createdBy: roleContext.userId,
            familyId: roleContext.familyId
        )
    }
    
    /// Submit run creation request to backend and handle response
    /// Implements Requirement 4.6 - backend run creation with proper error handling
    private func submitRunToBackend(_ run: Run) async throws -> Run {
        // Validate run data before submission
        try validateRunForSubmission(run)
        
        // Create run through Firebase service
        let createdRun = try await createRunInBackend(run)
        
        // Verify the created run matches our expectations
        try validateCreatedRun(createdRun, against: run)
        
        return createdRun
    }
    
    /// Validate run data before backend submission
    private func validateRunForSubmission(_ run: Run) throws {
        guard !run.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw RunCreationError.invalidMetadata("Run title cannot be empty")
        }
        
        guard run.scheduledTime > Date() else {
            throw RunCreationError.invalidMetadata("Run must be scheduled for a future time")
        }
        
        guard !run.driverId.isEmpty else {
            throw RunCreationError.invalidDriver("Driver must be selected")
        }
        
        guard !run.passengers.isEmpty else {
            throw RunCreationError.invalidPassengers("At least one passenger must be selected")
        }
        
        guard !run.stops.isEmpty else {
            throw RunCreationError.invalidStops("At least one stop must be defined")
        }
        
        // Validate stop sequence timing
        for (index, stop) in run.stops.enumerated() {
            if index > 0 {
                let previousStop = run.stops[index - 1]
                guard stop.scheduledTime > previousStop.scheduledTime else {
                    throw RunCreationError.invalidStops("Stop times must be in chronological order")
                }
            }
        }
    }
    
    /// Create run in backend service
    private func createRunInBackend(_ run: Run) async throws -> Run {
        // Create the run using the Firebase service
        let createdRun = try await firebaseService.createRun(run)
        return createdRun
    }
    
    /// Validate that the created run matches our expectations
    private func validateCreatedRun(_ createdRun: Run, against originalRun: Run) throws {
        guard createdRun.title == originalRun.title else {
            throw RunCreationError.creationFailed("Created run title doesn't match")
        }
        
        guard createdRun.driverId == originalRun.driverId else {
            throw RunCreationError.creationFailed("Created run driver doesn't match")
        }
        
        guard createdRun.passengers.count == originalRun.passengers.count else {
            throw RunCreationError.creationFailed("Created run passenger count doesn't match")
        }
        
        guard createdRun.stops.count == originalRun.stops.count else {
            throw RunCreationError.creationFailed("Created run stop count doesn't match")
        }
        
        guard createdRun.status == .scheduled else {
            throw RunCreationError.creationFailed("Created run should be in scheduled state")
        }
    }
}

// MARK: - Supporting Types

enum RunCreationStep: CaseIterable {
    case metadata
    case driver
    case passengers
    case stops
    
    var title: String {
        switch self {
        case .metadata: return "Run Details"
        case .driver: return "Select Driver"
        case .passengers: return "Select Passengers"
        case .stops: return "Define Stops"
        }
    }
    
    var stepNumber: Int {
        switch self {
        case .metadata: return 1
        case .driver: return 2
        case .passengers: return 3
        case .stops: return 4
        }
    }
}

enum RunCreationError: LocalizedError {
    case invalidMetadata(String)
    case invalidDriver(String)
    case invalidPassengers(String)
    case invalidStops(String)
    case creationFailed(String)
    case networkError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidMetadata(let message):
            return "Invalid run details: \(message)"
        case .invalidDriver(let message):
            return "Invalid driver selection: \(message)"
        case .invalidPassengers(let message):
            return "Invalid passenger selection: \(message)"
        case .invalidStops(let message):
            return "Invalid stops configuration: \(message)"
        case .creationFailed(let message):
            return "Failed to create run: \(message)"
        case .networkError(let message):
            return "Network error: \(message)"
        }
    }
}

/// Summary of run details for confirmation display
struct RunSummary {
    let title: String
    let scheduledTime: Date
    let driverName: String
    let passengerCount: Int
    let passengerNames: [String]
    let stopCount: Int
    let stopLabels: [String]
    
    var formattedScheduledTime: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: scheduledTime)
    }
    
    var passengerSummary: String {
        if passengerNames.count <= 3 {
            return passengerNames.joined(separator: ", ")
        } else {
            let firstThree = Array(passengerNames.prefix(3)).joined(separator: ", ")
            return "\(firstThree) and \(passengerNames.count - 3) more"
        }
    }
    
    var stopSummary: String {
        if stopLabels.count <= 2 {
            return stopLabels.joined(separator: " → ")
        } else {
            return "\(stopLabels.first ?? "") → ... → \(stopLabels.last ?? "")"
        }
    }
}