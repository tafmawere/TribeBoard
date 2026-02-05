//
//  Step2DriverViewModel.swift
//  Tribeboard
//
//  Created by Kiro on 2026/02/03.
//

import Foundation
import Combine

/// Step 2 ViewModel for driver selection
/// Implements Requirements 4.3 - driver availability validation
@MainActor
class Step2DriverViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var eligibleDrivers: [FamilyMember] = []
    @Published var selectedDriverId: String?
    @Published var isValid: Bool = false
    @Published var isLoading: Bool = false
    @Published var validationErrors: [DriverValidationError] = []
    
    // Driver availability checking
    @Published var driverAvailability: [String: DriverAvailabilityStatus] = [:]
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    private let familyId: String
    
    // MARK: - Initialization
    
    init(familyId: String = "default_family") {
        self.familyId = familyId
        setupValidation()
        loadEligibleDrivers()
    }
    
    // MARK: - Public Interface
    
    /// Reset all selections
    func reset() {
        selectedDriverId = nil
        validationErrors = []
        driverAvailability = [:]
    }
    
    /// Select a driver and validate availability
    func selectDriver(_ driverId: String) {
        selectedDriverId = driverId
        Task {
            await checkDriverAvailability(driverId)
        }
    }
    
    /// Check availability for a specific driver at the scheduled time
    func checkDriverAvailability(_ driverId: String, scheduledTime: Date = Date()) async {
        isLoading = true
        
        // Simulate availability check
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
        
        let availability = await performAvailabilityCheck(driverId: driverId, scheduledTime: scheduledTime)
        driverAvailability[driverId] = availability
        
        validateSelection()
        isLoading = false
    }
    
    /// Get the selected driver object
    func getSelectedDriver() -> FamilyMember? {
        guard let selectedDriverId = selectedDriverId else { return nil }
        return eligibleDrivers.first { $0.id == selectedDriverId }
    }
    
    /// Get driver availability status
    func getDriverAvailability(_ driverId: String) -> DriverAvailabilityStatus {
        return driverAvailability[driverId] ?? .unknown
    }
    
    /// Check if driver has required permissions
    func hasDriverPermissions(_ member: FamilyMember) -> Bool {
        return member.role == .driver || member.role == .admin
    }
    
    /// Get driver experience level description
    func getDriverExperienceDescription(_ member: FamilyMember) -> String {
        // In a real app, this would come from user profile data
        switch member.role {
        case .admin:
            return "Experienced family driver"
        case .driver:
            return "Authorized family driver"
        default:
            return "Not authorized to drive"
        }
    }
    
    /// Refresh the list of eligible drivers
    func refreshDrivers() {
        loadEligibleDrivers()
    }
    
    // MARK: - Private Methods
    
    private func setupValidation() {
        $selectedDriverId
            .combineLatest($driverAvailability)
            .sink { [weak self] selectedId, availability in
                self?.validateSelection()
            }
            .store(in: &cancellables)
    }
    
    private func validateSelection() {
        var errors: [DriverValidationError] = []
        
        // Check if driver is selected - Requirement 4.3
        guard let selectedDriverId = selectedDriverId else {
            errors.append(.noDriverSelected)
            validationErrors = errors
            isValid = false
            return
        }
        
        // Check if selected driver exists in eligible list
        guard let selectedDriver = eligibleDrivers.first(where: { $0.id == selectedDriverId }) else {
            errors.append(.invalidDriverSelection)
            validationErrors = errors
            isValid = false
            return
        }
        
        // Check driver permissions
        if !hasDriverPermissions(selectedDriver) {
            errors.append(.insufficientPermissions)
        }
        
        // Check driver availability
        let availability = driverAvailability[selectedDriverId] ?? .unknown
        switch availability {
        case .unavailable(let reason):
            errors.append(.driverUnavailable(reason))
        case .conflicted(let conflictingRun):
            errors.append(.driverConflicted(conflictingRun))
        case .unknown:
            // Don't treat unknown as an error, but it's not ideal
            break
        case .available:
            // All good
            break
        }
        
        validationErrors = errors
        isValid = errors.isEmpty
    }
    
    private func loadEligibleDrivers() {
        #if DEBUG
        // Load demo family members in DEBUG mode
        if AppConfig.isFullAppMode {
            eligibleDrivers = [
                FamilyMember(
                    id: DemoSeedDataService.rueId,
                    displayName: "Rue",
                    role: .admin,
                    avatarURL: nil,
                    isActive: true,
                    lastSeen: Date()
                ),
                FamilyMember(
                    id: DemoSeedDataService.tafadzwaId,
                    displayName: "Tafadzwa",
                    role: .admin,
                    avatarURL: nil,
                    isActive: true,
                    lastSeen: Date()
                )
            ]
            return
        }
        #endif
        
        // Simulate loading family members who can drive
        // In a real app, this would fetch from the backend
        eligibleDrivers = [
            FamilyMember(
                id: "driver1",
                displayName: "Sarah Johnson",
                role: .driver,
                avatarURL: nil,
                isActive: true,
                lastSeen: Date()
            ),
            FamilyMember(
                id: "admin1",
                displayName: "Mike Johnson",
                role: .admin,
                avatarURL: nil,
                isActive: true,
                lastSeen: Date()
            ),
            FamilyMember(
                id: "driver2",
                displayName: "Emma Wilson",
                role: .driver,
                avatarURL: nil,
                isActive: false,
                lastSeen: Date().addingTimeInterval(-3600)
            )
        ]
    }
    
    private func performAvailabilityCheck(driverId: String, scheduledTime: Date) async -> DriverAvailabilityStatus {
        // Simulate availability checking logic
        // In a real app, this would check against:
        // - Existing runs assigned to the driver
        // - Driver's calendar/schedule
        // - Driver's availability preferences
        
        let driver = eligibleDrivers.first { $0.id == driverId }
        
        // Check if driver is active
        if let driver = driver, !driver.isActive {
            return .unavailable("Driver is currently offline")
        }
        
        // Simulate some drivers having conflicts
        if driverId == "driver2" {
            return .conflicted("Soccer Practice Run")
        }
        
        // Check for time-based availability
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: scheduledTime)
        
        if hour < 6 || hour > 22 {
            return .unavailable("Outside normal driving hours")
        }
        
        // Most drivers are available
        return .available
    }
}

// MARK: - Supporting Types

struct FamilyMember: Identifiable, Codable {
    let id: String
    let displayName: String
    let role: FamilyRole
    let avatarURL: String?
    let isActive: Bool
    let lastSeen: Date
    
    init(id: String, displayName: String, role: FamilyRole, avatarURL: String? = nil, isActive: Bool = true, lastSeen: Date = Date()) {
        self.id = id
        self.displayName = displayName
        self.role = role
        self.avatarURL = avatarURL
        self.isActive = isActive
        self.lastSeen = lastSeen
    }
}

enum DriverAvailabilityStatus: Equatable {
    case available
    case unavailable(String)
    case conflicted(String) // Conflicting run title
    case unknown
    
    var isAvailable: Bool {
        if case .available = self {
            return true
        }
        return false
    }
    
    var displayMessage: String {
        switch self {
        case .available:
            return "Available"
        case .unavailable(let reason):
            return "Unavailable: \(reason)"
        case .conflicted(let runTitle):
            return "Conflict with: \(runTitle)"
        case .unknown:
            return "Checking availability..."
        }
    }
}

enum DriverValidationError: LocalizedError, Equatable {
    case noDriverSelected
    case invalidDriverSelection
    case insufficientPermissions
    case driverUnavailable(String)
    case driverConflicted(String)
    
    var errorDescription: String? {
        switch self {
        case .noDriverSelected:
            return "Please select a driver for this run"
        case .invalidDriverSelection:
            return "Selected driver is not valid"
        case .insufficientPermissions:
            return "Selected person does not have driver permissions"
        case .driverUnavailable(let reason):
            return "Driver is unavailable: \(reason)"
        case .driverConflicted(let runTitle):
            return "Driver has a conflict with: \(runTitle)"
        }
    }
}