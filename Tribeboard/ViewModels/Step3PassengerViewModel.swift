//
//  Step3PassengerViewModel.swift
//  Tribeboard
//
//  Created by Kiro on 2026/02/03.
//

import Foundation
import Combine

/// Step 3 ViewModel for passenger selection
/// Implements Requirements 4.4 - passenger availability validation
@MainActor
class Step3PassengerViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var availablePassengers: [PassengerProfile] = []
    @Published var selectedPassengerIds: Set<String> = []
    @Published var selectedPassengers: [MemberSummary] = []
    @Published var isValid: Bool = false
    @Published var isLoading: Bool = false
    @Published var validationErrors: [PassengerValidationError] = []
    
    // Passenger availability checking
    @Published var passengerAvailability: [String: PassengerAvailabilityStatus] = [:]
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    private let familyId: String
    private let maxPassengers: Int = 8 // Typical family vehicle capacity
    
    // MARK: - Initialization
    
    init(familyId: String = "default_family") {
        self.familyId = familyId
        setupValidation()
        loadAvailablePassengers()
    }
    
    // MARK: - Public Interface
    
    /// Reset all selections
    func reset() {
        selectedPassengerIds.removeAll()
        selectedPassengers.removeAll()
        validationErrors = []
        passengerAvailability = [:]
    }
    
    /// Toggle passenger selection
    func togglePassenger(_ passengerId: String) {
        if selectedPassengerIds.contains(passengerId) {
            removePassenger(passengerId)
        } else {
            addPassenger(passengerId)
        }
    }
    
    /// Add a passenger to the selection
    func addPassenger(_ passengerId: String) {
        guard !selectedPassengerIds.contains(passengerId) else { return }
        guard selectedPassengerIds.count < maxPassengers else { return }
        
        selectedPassengerIds.insert(passengerId)
        updateSelectedPassengers()
        
        Task {
            await checkPassengerAvailability(passengerId)
        }
    }
    
    /// Remove a passenger from the selection
    func removePassenger(_ passengerId: String) {
        selectedPassengerIds.remove(passengerId)
        passengerAvailability.removeValue(forKey: passengerId)
        updateSelectedPassengers()
    }
    
    /// Check availability for a specific passenger at the scheduled time
    func checkPassengerAvailability(_ passengerId: String, scheduledTime: Date = Date()) async {
        isLoading = true
        
        // Simulate availability check
        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 second delay
        
        let availability = await performAvailabilityCheck(passengerId: passengerId, scheduledTime: scheduledTime)
        passengerAvailability[passengerId] = availability
        
        validateSelection()
        isLoading = false
    }
    
    /// Check availability for all selected passengers
    func checkAllPassengerAvailability(scheduledTime: Date = Date()) async {
        isLoading = true
        
        await withTaskGroup(of: Void.self) { group in
            for passengerId in selectedPassengerIds {
                group.addTask {
                    await self.checkPassengerAvailability(passengerId, scheduledTime: scheduledTime)
                }
            }
        }
        
        isLoading = false
    }
    
    /// Get passenger availability status
    func getPassengerAvailability(_ passengerId: String) -> PassengerAvailabilityStatus {
        return passengerAvailability[passengerId] ?? .unknown
    }
    
    /// Check if passenger is selected
    func isPassengerSelected(_ passengerId: String) -> Bool {
        return selectedPassengerIds.contains(passengerId)
    }
    
    /// Get passenger profile by ID
    func getPassengerProfile(_ passengerId: String) -> PassengerProfile? {
        return availablePassengers.first { $0.id == passengerId }
    }
    
    /// Get selected passenger count
    var selectedCount: Int {
        return selectedPassengerIds.count
    }
    
    /// Check if at capacity
    var isAtCapacity: Bool {
        return selectedPassengerIds.count >= maxPassengers
    }
    
    /// Get passengers grouped by age category
    func getPassengersByAgeGroup() -> [AgeGroup: [PassengerProfile]] {
        return Dictionary(grouping: availablePassengers) { passenger in
            passenger.ageGroup
        }
    }
    
    /// Refresh the list of available passengers
    func refreshPassengers() {
        loadAvailablePassengers()
    }
    
    // MARK: - Private Methods
    
    private func setupValidation() {
        $selectedPassengerIds
            .combineLatest($passengerAvailability)
            .sink { [weak self] _, _ in
                self?.validateSelection()
            }
            .store(in: &cancellables)
    }
    
    private func validateSelection() {
        var errors: [PassengerValidationError] = []
        
        // Check if at least one passenger is selected - Requirement 4.4
        if selectedPassengerIds.isEmpty {
            errors.append(.noPassengersSelected)
            validationErrors = errors
            isValid = false
            return
        }
        
        // Check capacity limits
        if selectedPassengerIds.count > maxPassengers {
            errors.append(.tooManyPassengers(maxPassengers))
        }
        
        // Check individual passenger availability
        for passengerId in selectedPassengerIds {
            let availability = passengerAvailability[passengerId] ?? .unknown
            
            switch availability {
            case .unavailable(let reason):
                if let passenger = getPassengerProfile(passengerId) {
                    errors.append(.passengerUnavailable(passenger.displayName, reason))
                }
            case .conflicted(let conflictingActivity):
                if let passenger = getPassengerProfile(passengerId) {
                    errors.append(.passengerConflicted(passenger.displayName, conflictingActivity))
                }
            case .requiresPermission(let guardian):
                if let passenger = getPassengerProfile(passengerId) {
                    errors.append(.requiresGuardianPermission(passenger.displayName, guardian))
                }
            case .available, .unknown:
                // No error
                break
            }
        }
        
        // Check for age-appropriate supervision
        let selectedProfiles = selectedPassengerIds.compactMap { getPassengerProfile($0) }
        let hasYoungChildren = selectedProfiles.contains { $0.ageGroup == .child }
        
        if hasYoungChildren && selectedProfiles.count > 4 {
            errors.append(.supervisionRequired("Young children require additional supervision for groups larger than 4"))
        }
        
        validationErrors = errors
        isValid = errors.isEmpty
    }
    
    private func updateSelectedPassengers() {
        selectedPassengers = selectedPassengerIds.compactMap { passengerId in
            guard let profile = getPassengerProfile(passengerId) else { return nil }
            
            return MemberSummary(
                id: profile.id,
                displayName: profile.displayName,
                role: .passenger,
                avatarURL: profile.avatarURL
            )
        }
    }
    
    private func loadAvailablePassengers() {
        #if DEBUG
        // Load demo family members in DEBUG mode
        if AppConfig.isFullAppMode {
            availablePassengers = [
                PassengerProfile(
                    id: DemoSeedDataService.tjId,
                    displayName: "TJ",
                    ageGroup: .child,
                    age: 10,
                    avatarURL: nil,
                    specialNeeds: [],
                    guardianIds: [DemoSeedDataService.rueId, DemoSeedDataService.tafadzwaId]
                ),
                PassengerProfile(
                    id: DemoSeedDataService.tawanaId,
                    displayName: "Tawana",
                    ageGroup: .child,
                    age: 8,
                    avatarURL: nil,
                    specialNeeds: [],
                    guardianIds: [DemoSeedDataService.rueId, DemoSeedDataService.tafadzwaId]
                )
            ]
            return
        }
        #endif
        
        // Simulate loading family members who can be passengers
        // In a real app, this would fetch from the backend
        availablePassengers = [
            PassengerProfile(
                id: "child1",
                displayName: "Emma Johnson",
                ageGroup: .child,
                age: 8,
                avatarURL: nil,
                specialNeeds: [],
                guardianIds: ["admin1", "driver1"]
            ),
            PassengerProfile(
                id: "child2",
                displayName: "Liam Johnson",
                ageGroup: .child,
                age: 6,
                avatarURL: nil,
                specialNeeds: [.carSeat],
                guardianIds: ["admin1", "driver1"]
            ),
            PassengerProfile(
                id: "teen1",
                displayName: "Sophia Wilson",
                ageGroup: .teen,
                age: 15,
                avatarURL: nil,
                specialNeeds: [],
                guardianIds: ["driver2"]
            ),
            PassengerProfile(
                id: "adult1",
                displayName: "Grandma Rose",
                ageGroup: .adult,
                age: 72,
                avatarURL: nil,
                specialNeeds: [.mobilityAssistance],
                guardianIds: []
            )
        ]
    }
    
    private func performAvailabilityCheck(passengerId: String, scheduledTime: Date) async -> PassengerAvailabilityStatus {
        // Simulate availability checking logic
        // In a real app, this would check against:
        // - Passenger's schedule/calendar
        // - School hours for children
        // - Other family commitments
        // - Guardian permissions
        
        guard let passenger = getPassengerProfile(passengerId) else {
            return .unavailable("Passenger not found")
        }
        
        // Check school hours for children
        if passenger.ageGroup == .child {
            let calendar = Calendar.current
            let hour = calendar.component(.hour, from: scheduledTime)
            let weekday = calendar.component(.weekday, from: scheduledTime)
            
            // Monday to Friday, 8 AM to 3 PM is school time
            if weekday >= 2 && weekday <= 6 && hour >= 8 && hour <= 15 {
                return .conflicted("School hours")
            }
        }
        
        // Simulate some passengers having conflicts
        if passengerId == "teen1" {
            let calendar = Calendar.current
            let hour = calendar.component(.hour, from: scheduledTime)
            if hour >= 15 && hour <= 17 {
                return .conflicted("Soccer practice")
            }
        }
        
        // Check guardian permission for minors
        if passenger.ageGroup == .child && !passenger.guardianIds.isEmpty {
            // In a real app, this would check if guardians have approved
            // For simulation, require permission for evening runs
            let calendar = Calendar.current
            let hour = calendar.component(.hour, from: scheduledTime)
            if hour >= 19 {
                return .requiresPermission(passenger.guardianIds.first ?? "Guardian")
            }
        }
        
        // Most passengers are available
        return .available
    }
}

// MARK: - Supporting Types

struct PassengerProfile: Identifiable, Codable {
    let id: String
    let displayName: String
    let ageGroup: AgeGroup
    let age: Int
    let avatarURL: String?
    let specialNeeds: [SpecialNeed]
    let guardianIds: [String]
    
    var requiresCarSeat: Bool {
        return specialNeeds.contains(.carSeat) || age < 8
    }
    
    var requiresSupervision: Bool {
        return ageGroup == .child || specialNeeds.contains(.supervision)
    }
}

enum AgeGroup: String, CaseIterable, Codable {
    case child = "child"
    case teen = "teen"
    case adult = "adult"
    
    var displayName: String {
        switch self {
        case .child: return "Child"
        case .teen: return "Teen"
        case .adult: return "Adult"
        }
    }
    
    var ageRange: String {
        switch self {
        case .child: return "0-12"
        case .teen: return "13-17"
        case .adult: return "18+"
        }
    }
}

enum SpecialNeed: String, CaseIterable, Codable {
    case carSeat = "carSeat"
    case boosterSeat = "boosterSeat"
    case wheelchair = "wheelchair"
    case mobilityAssistance = "mobilityAssistance"
    case supervision = "supervision"
    case medication = "medication"
    
    var displayName: String {
        switch self {
        case .carSeat: return "Car Seat"
        case .boosterSeat: return "Booster Seat"
        case .wheelchair: return "Wheelchair Access"
        case .mobilityAssistance: return "Mobility Assistance"
        case .supervision: return "Extra Supervision"
        case .medication: return "Medication Management"
        }
    }
}

enum PassengerAvailabilityStatus: Equatable {
    case available
    case unavailable(String)
    case conflicted(String) // Conflicting activity
    case requiresPermission(String) // Guardian ID
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
        case .conflicted(let activity):
            return "Conflict: \(activity)"
        case .requiresPermission(let guardian):
            return "Needs permission from \(guardian)"
        case .unknown:
            return "Checking availability..."
        }
    }
}

enum PassengerValidationError: LocalizedError, Equatable {
    case noPassengersSelected
    case tooManyPassengers(Int)
    case passengerUnavailable(String, String)
    case passengerConflicted(String, String)
    case requiresGuardianPermission(String, String)
    case supervisionRequired(String)
    
    var errorDescription: String? {
        switch self {
        case .noPassengersSelected:
            return "Please select at least one passenger"
        case .tooManyPassengers(let max):
            return "Cannot select more than \(max) passengers"
        case .passengerUnavailable(let name, let reason):
            return "\(name) is unavailable: \(reason)"
        case .passengerConflicted(let name, let activity):
            return "\(name) has a conflict with: \(activity)"
        case .requiresGuardianPermission(let name, let guardian):
            return "\(name) requires permission from \(guardian)"
        case .supervisionRequired(let reason):
            return "Supervision required: \(reason)"
        }
    }
}