//
//  Step4StopsViewModel.swift
//  Tribeboard
//
//  Created by Kiro on 2026/02/03.
//

import Foundation
import Combine
import CoreLocation
import SwiftUI

/// Step 4 ViewModel for stops definition
/// Implements Requirements 4.5 - stop sequence and timing validation
@MainActor
class Step4StopsViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var stops: [RunStop] = []
    @Published var isValid: Bool = false
    @Published var isLoading: Bool = false
    @Published var validationErrors: [StopValidationError] = []
    
    // Stop creation
    @Published var isAddingStop: Bool = false
    @Published var newStopType: StopType = .pickup
    @Published var newStopLabel: String = ""
    @Published var newStopTime: Date = Date()
    @Published var newStopLocation: LocationData?
    @Published var newStopPassengerIds: Set<String> = []
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    private let selectedPassengers: [MemberSummary]
    private let runStartTime: Date
    
    // MARK: - Initialization
    
    init(selectedPassengers: [MemberSummary] = [], runStartTime: Date = Date()) {
        self.selectedPassengers = selectedPassengers
        self.runStartTime = runStartTime
        setupValidation()
    }
    
    // MARK: - Public Interface
    
    /// Reset all stops
    func reset() {
        stops.removeAll()
        validationErrors = []
        resetNewStopForm()
    }
    
    /// Start adding a new stop
    func startAddingStop() {
        resetNewStopForm()
        isAddingStop = true
    }
    
    /// Cancel adding a new stop
    func cancelAddingStop() {
        isAddingStop = false
        resetNewStopForm()
    }
    
    /// Add the new stop to the list
    func addNewStop() {
        guard validateNewStop() else { return }
        
        let stop = RunStop(
            type: newStopType,
            label: newStopLabel,
            scheduledTime: newStopTime,
            requiredPassengerIds: Array(newStopPassengerIds),
            location: newStopLocation ?? LocationData(latitude: 0, longitude: 0, address: "Unknown")
        )
        
        stops.append(stop)
        sortStopsByTime()
        isAddingStop = false
        resetNewStopForm()
    }
    
    /// Remove a stop from the list
    func removeStop(at index: Int) {
        guard index < stops.count else { return }
        stops.remove(at: index)
    }
    
    /// Move a stop to a different position
    func moveStop(from source: IndexSet, to destination: Int) {
        stops.move(fromOffsets: source, toOffset: destination)
        updateStopTimes()
    }
    
    /// Update stop times to maintain logical sequence
    func updateStopTimes() {
        // Ensure stops are in chronological order
        stops.sort { $0.scheduledTime < $1.scheduledTime }
        
        // Validate time gaps between stops
        for i in 1..<stops.count {
            let previousStop = stops[i-1]
            let currentStop = stops[i]
            
            // Ensure minimum 5-minute gap between stops
            let minimumGap: TimeInterval = 5 * 60 // 5 minutes
            if currentStop.scheduledTime.timeIntervalSince(previousStop.scheduledTime) < minimumGap {
                stops[i] = RunStop(
                    id: currentStop.id,
                    type: currentStop.type,
                    label: currentStop.label,
                    scheduledTime: previousStop.scheduledTime.addingTimeInterval(minimumGap),
                    requiredPassengerIds: currentStop.requiredPassengerIds,
                    location: currentStop.location,
                    notes: currentStop.notes
                )
            }
        }
    }
    
    /// Toggle passenger assignment to new stop
    func togglePassengerForNewStop(_ passengerId: String) {
        if newStopPassengerIds.contains(passengerId) {
            newStopPassengerIds.remove(passengerId)
        } else {
            newStopPassengerIds.insert(passengerId)
        }
    }
    
    /// Set location for new stop
    func setNewStopLocation(_ location: LocationData) {
        newStopLocation = location
    }
    
    /// Get suggested stop labels based on type and time
    func getSuggestedStopLabels() -> [String] {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: newStopTime)
        
        var suggestions: [String] = []
        
        switch newStopType {
        case .pickup:
            if hour < 9 {
                suggestions.append(contentsOf: ["Home", "School", "Daycare"])
            } else if hour < 15 {
                suggestions.append(contentsOf: ["School", "Doctor's Office", "Activity Center"])
            } else {
                suggestions.append(contentsOf: ["School", "After School Program", "Friend's House"])
            }
        case .dropoff:
            if hour < 9 {
                suggestions.append(contentsOf: ["School", "Daycare", "Activity Center"])
            } else if hour < 15 {
                suggestions.append(contentsOf: ["Doctor's Office", "Activity Center", "Mall"])
            } else {
                suggestions.append(contentsOf: ["Home", "After School Program", "Sports Practice"])
            }
        case .waypoint:
            suggestions.append(contentsOf: ["Gas Station", "Grocery Store", "Rest Stop"])
        }
        
        return suggestions
    }
    
    /// Get passengers that need pickup/dropoff
    func getPassengersNeedingPickup() -> [MemberSummary] {
        let alreadyPickedUp = Set(stops.filter { $0.type == .pickup }.flatMap { $0.requiredPassengerIds })
        return selectedPassengers.filter { !alreadyPickedUp.contains($0.id) }
    }
    
    func getPassengersNeedingDropoff() -> [MemberSummary] {
        let pickedUp = Set(stops.filter { $0.type == .pickup }.flatMap { $0.requiredPassengerIds })
        let alreadyDroppedOff = Set(stops.filter { $0.type == .dropoff }.flatMap { $0.requiredPassengerIds })
        return selectedPassengers.filter { pickedUp.contains($0.id) && !alreadyDroppedOff.contains($0.id) }
    }
    
    /// Validate the complete stop sequence
    func validateStopSequence() -> Bool {
        var errors: [StopValidationError] = []
        
        // Must have at least one stop - Requirement 4.5
        if stops.isEmpty {
            errors.append(.noStopsAdded)
            validationErrors = errors
            return false
        }
        
        // Check time sequence
        for i in 1..<stops.count {
            if stops[i].scheduledTime <= stops[i-1].scheduledTime {
                errors.append(.invalidTimeSequence(i))
            }
        }
        
        // Check passenger pickup/dropoff logic
        var pickedUpPassengers: Set<String> = []
        var droppedOffPassengers: Set<String> = []
        
        for (index, stop) in stops.enumerated() {
            switch stop.type {
            case .pickup:
                for passengerId in stop.requiredPassengerIds {
                    if pickedUpPassengers.contains(passengerId) {
                        errors.append(.passengerAlreadyPickedUp(passengerId, index))
                    }
                    pickedUpPassengers.insert(passengerId)
                }
            case .dropoff:
                for passengerId in stop.requiredPassengerIds {
                    if !pickedUpPassengers.contains(passengerId) {
                        errors.append(.passengerNotPickedUp(passengerId, index))
                    }
                    if droppedOffPassengers.contains(passengerId) {
                        errors.append(.passengerAlreadyDroppedOff(passengerId, index))
                    }
                    droppedOffPassengers.insert(passengerId)
                }
            case .waypoint:
                // Waypoints don't affect passenger logic
                break
            }
        }
        
        // Check that all passengers are eventually dropped off
        for passenger in selectedPassengers {
            if pickedUpPassengers.contains(passenger.id) && !droppedOffPassengers.contains(passenger.id) {
                errors.append(.passengerNotDroppedOff(passenger.id))
            }
        }
        
        // Check for reasonable time gaps
        for i in 1..<stops.count {
            let gap = stops[i].scheduledTime.timeIntervalSince(stops[i-1].scheduledTime)
            if gap < 60 { // Less than 1 minute
                errors.append(.timeGapTooShort(i))
            } else if gap > 3600 { // More than 1 hour
                errors.append(.timeGapTooLong(i))
            }
        }
        
        validationErrors = errors
        return errors.isEmpty
    }
    
    // MARK: - Private Methods
    
    private func setupValidation() {
        $stops
            .sink { [weak self] _ in
                self?.isValid = self?.validateStopSequence() ?? false
            }
            .store(in: &cancellables)
    }
    
    private func resetNewStopForm() {
        newStopType = .pickup
        newStopLabel = ""
        newStopTime = stops.isEmpty ? runStartTime : stops.last!.scheduledTime.addingTimeInterval(15 * 60)
        newStopLocation = nil
        newStopPassengerIds.removeAll()
    }
    
    private func validateNewStop() -> Bool {
        // Check required fields
        guard !newStopLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }
        
        guard newStopLocation != nil else {
            return false
        }
        
        // Check passenger requirements for pickup/dropoff
        if newStopType == .pickup || newStopType == .dropoff {
            guard !newStopPassengerIds.isEmpty else {
                return false
            }
        }
        
        // Check time is not in the past
        guard newStopTime > Date() else {
            return false
        }
        
        return true
    }
    
    private func sortStopsByTime() {
        stops.sort { $0.scheduledTime < $1.scheduledTime }
    }
}

// MARK: - Supporting Types

enum StopValidationError: LocalizedError, Equatable {
    case noStopsAdded
    case invalidTimeSequence(Int)
    case passengerAlreadyPickedUp(String, Int)
    case passengerNotPickedUp(String, Int)
    case passengerAlreadyDroppedOff(String, Int)
    case passengerNotDroppedOff(String)
    case timeGapTooShort(Int)
    case timeGapTooLong(Int)
    case invalidLocation(Int)
    case emptyStopLabel(Int)
    
    var errorDescription: String? {
        switch self {
        case .noStopsAdded:
            return "At least one stop must be added"
        case .invalidTimeSequence(let index):
            return "Stop \(index + 1) time must be after the previous stop"
        case .passengerAlreadyPickedUp(_, let index):
            return "Passenger already picked up before stop \(index + 1)"
        case .passengerNotPickedUp(_, let index):
            return "Passenger must be picked up before drop-off at stop \(index + 1)"
        case .passengerAlreadyDroppedOff(_, let index):
            return "Passenger already dropped off before stop \(index + 1)"
        case .passengerNotDroppedOff(let passengerId):
            return "Passenger \(passengerId) must be dropped off"
        case .timeGapTooShort(let index):
            return "Time gap to stop \(index + 1) is too short (minimum 1 minute)"
        case .timeGapTooLong(let index):
            return "Time gap to stop \(index + 1) is too long (maximum 1 hour)"
        case .invalidLocation(let index):
            return "Stop \(index + 1) must have a valid location"
        case .emptyStopLabel(let index):
            return "Stop \(index + 1) must have a label"
        }
    }
}