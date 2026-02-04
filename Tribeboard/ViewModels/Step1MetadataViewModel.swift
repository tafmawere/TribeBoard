//
//  Step1MetadataViewModel.swift
//  Tribeboard
//
//  Created by Kiro on 2026/02/03.
//

import Foundation
import Combine

/// Step 1 ViewModel for run metadata collection
/// Implements Requirements 4.1, 4.2 - run title and datetime validation
@MainActor
class Step1MetadataViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var runTitle: String = ""
    @Published var runDateTime: Date = Date().addingTimeInterval(3600) // Default to 1 hour from now
    @Published var runDescription: String = ""
    @Published var isValid: Bool = false
    @Published var validationErrors: [ValidationError] = []
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init() {
        setupValidation()
    }
    
    // MARK: - Public Interface
    
    /// Reset all fields to default values
    func reset() {
        runTitle = ""
        runDateTime = Date().addingTimeInterval(3600)
        runDescription = ""
        validationErrors = []
    }
    
    /// Validate the current input and update validation state
    func validateInput() {
        var errors: [ValidationError] = []
        
        // Validate run title - Requirement 4.2
        if runTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append(.emptyTitle)
        } else if runTitle.count < 3 {
            errors.append(.titleTooShort)
        } else if runTitle.count > 100 {
            errors.append(.titleTooLong)
        }
        
        // Validate run date time - Requirement 4.2
        let now = Date()
        if runDateTime < now {
            errors.append(.pastDateTime)
        } else if runDateTime.timeIntervalSince(now) > 86400 * 30 { // 30 days
            errors.append(.dateTimeTooFar)
        }
        
        // Validate description (optional but has limits)
        if runDescription.count > 500 {
            errors.append(.descriptionTooLong)
        }
        
        validationErrors = errors
        isValid = errors.isEmpty
    }
    
    /// Get suggested run titles based on common patterns
    func getSuggestedTitles() -> [String] {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: runDateTime)
        let dayOfWeek = calendar.component(.weekday, from: runDateTime)
        
        var suggestions: [String] = []
        
        // Time-based suggestions
        if hour < 9 {
            suggestions.append("Morning School Run")
            suggestions.append("Early Pickup")
        } else if hour < 12 {
            suggestions.append("Morning Activities")
            suggestions.append("Doctor Appointment")
        } else if hour < 15 {
            suggestions.append("Lunch Pickup")
            suggestions.append("Afternoon Activities")
        } else if hour < 18 {
            suggestions.append("School Pickup")
            suggestions.append("After School Activities")
        } else {
            suggestions.append("Evening Activities")
            suggestions.append("Dinner Pickup")
        }
        
        // Day-based suggestions
        if dayOfWeek == 1 || dayOfWeek == 7 { // Weekend
            suggestions.append("Weekend Activities")
            suggestions.append("Family Outing")
        } else {
            suggestions.append("Weekday Pickup")
            suggestions.append("School Transport")
        }
        
        return Array(Set(suggestions)).sorted()
    }
    
    /// Set run title from suggestion
    func setTitleFromSuggestion(_ title: String) {
        runTitle = title
        validateInput()
    }
    
    /// Get formatted date string for display
    func getFormattedDateTime() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: runDateTime)
    }
    
    /// Check if the selected time is during typical school hours
    func isSchoolHours() -> Bool {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: runDateTime)
        let weekday = calendar.component(.weekday, from: runDateTime)
        
        // Monday to Friday, 7 AM to 4 PM
        return weekday >= 2 && weekday <= 6 && hour >= 7 && hour <= 16
    }
    
    /// Get time slot description
    func getTimeSlotDescription() -> String {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: runDateTime)
        
        switch hour {
        case 6..<9:
            return "Early Morning"
        case 9..<12:
            return "Morning"
        case 12..<15:
            return "Afternoon"
        case 15..<18:
            return "Late Afternoon"
        case 18..<21:
            return "Evening"
        default:
            return "Late Hours"
        }
    }
    
    // MARK: - Private Methods
    
    private func setupValidation() {
        // Validate whenever title or date changes
        Publishers.CombineLatest3($runTitle, $runDateTime, $runDescription)
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _, _, _ in
                self?.validateInput()
            }
            .store(in: &cancellables)
    }
}

// MARK: - Supporting Types

enum ValidationError: LocalizedError, Equatable {
    case emptyTitle
    case titleTooShort
    case titleTooLong
    case pastDateTime
    case dateTimeTooFar
    case descriptionTooLong
    
    var errorDescription: String? {
        switch self {
        case .emptyTitle:
            return "Run title is required"
        case .titleTooShort:
            return "Run title must be at least 3 characters"
        case .titleTooLong:
            return "Run title cannot exceed 100 characters"
        case .pastDateTime:
            return "Run time cannot be in the past"
        case .dateTimeTooFar:
            return "Run time cannot be more than 30 days in the future"
        case .descriptionTooLong:
            return "Description cannot exceed 500 characters"
        }
    }
    
    var fieldName: String {
        switch self {
        case .emptyTitle, .titleTooShort, .titleTooLong:
            return "title"
        case .pastDateTime, .dateTimeTooFar:
            return "dateTime"
        case .descriptionTooLong:
            return "description"
        }
    }
}