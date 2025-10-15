import Foundation
import SwiftData

/// Service for managing calendar business rules and validation configuration
@MainActor
class CalendarBusinessRulesService: ObservableObject {
    
    // MARK: - Properties
    
    private let modelContext: ModelContext
    
    @Published var businessRules: CalendarBusinessRules
    @Published var isLoading = false
    
    // MARK: - Initialization
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.businessRules = CalendarBusinessRules.default
        loadBusinessRules()
    }
    
    // MARK: - Business Rules Management
    
    /// Loads business rules from storage or creates defaults
    func loadBusinessRules() {
        isLoading = true
        
        // In a real implementation, this would load from persistent storage
        // For now, we'll use default rules
        businessRules = CalendarBusinessRules.default
        
        isLoading = false
        print("📋 CalendarBusinessRulesService: Loaded business rules")
    }
    
    /// Updates business rules configuration
    func updateBusinessRules(_ newRules: CalendarBusinessRules) async throws {
        isLoading = true
        
        defer {
            isLoading = false
        }
        
        // Validate the new rules
        try validateBusinessRulesConfiguration(newRules)
        
        // Update the rules
        businessRules = newRules
        
        // Save to persistent storage
        try await saveBusinessRules(newRules)
        
        print("✅ CalendarBusinessRulesService: Updated business rules")
    }
    
    /// Validates a business rules configuration
    func validateBusinessRulesConfiguration(_ rules: CalendarBusinessRules) throws {
        // Validate limits are reasonable
        if rules.maxEventTitleLength < 10 || rules.maxEventTitleLength > 500 {
            throw CalendarError.invalidConfiguration(
                parameter: "maxEventTitleLength",
                value: String(rules.maxEventTitleLength)
            )
        }
        
        if rules.minEventDuration < 60 || rules.minEventDuration > 3600 {
            throw CalendarError.invalidConfiguration(
                parameter: "minEventDuration",
                value: String(rules.minEventDuration)
            )
        }
        
        if rules.maxTimedEventDuration < 3600 || rules.maxTimedEventDuration > 604800 {
            throw CalendarError.invalidConfiguration(
                parameter: "maxTimedEventDuration",
                value: String(rules.maxTimedEventDuration)
            )
        }
        
        if rules.maxEventsPerDay < 1 || rules.maxEventsPerDay > 100 {
            throw CalendarError.invalidConfiguration(
                parameter: "maxEventsPerDay",
                value: String(rules.maxEventsPerDay)
            )
        }
        
        if rules.maxFamilyEventsPerMonth < 10 || rules.maxFamilyEventsPerMonth > 1000 {
            throw CalendarError.invalidConfiguration(
                parameter: "maxFamilyEventsPerMonth",
                value: String(rules.maxFamilyEventsPerMonth)
            )
        }
    }
    
    /// Gets business rules for a specific context
    func getBusinessRulesForContext(
        userId: UUID,
        familyId: UUID?,
        eventType: CalendarEvent.PrivacyLevel
    ) -> CalendarBusinessRules {
        var contextRules = businessRules
        
        // Adjust rules based on context
        if eventType == .familyShared {
            // Family events might have stricter rules
            contextRules.enableContentFiltering = true
            contextRules.requireEventApproval = familyId != nil
        }
        
        // Could adjust rules based on user role, subscription level, etc.
        
        return contextRules
    }
    
    /// Checks if a specific business rule is enabled
    func isRuleEnabled(_ rule: BusinessRuleType) -> Bool {
        switch rule {
        case .titleValidation:
            return businessRules.enableTitleValidation
        case .contentFiltering:
            return businessRules.enableContentFiltering
        case .schedulingConflictDetection:
            return businessRules.enableSchedulingConflictDetection
        case .dailyEventLimits:
            return businessRules.enableDailyEventLimits
        case .familyEventLimits:
            return businessRules.enableFamilyEventLimits
        case .duplicateEventPrevention:
            return businessRules.enableDuplicateEventPrevention
        case .pastEventModification:
            return businessRules.allowPastEventModification
        case .eventApproval:
            return businessRules.requireEventApproval
        case .privacyLevelValidation:
            return businessRules.enablePrivacyLevelValidation
        case .dataIntegrityChecks:
            return businessRules.enableDataIntegrityChecks
        }
    }
    
    /// Gets validation severity for a rule
    func getValidationSeverity(_ rule: BusinessRuleType) -> ValidationSeverity {
        switch rule {
        case .titleValidation, .privacyLevelValidation, .dataIntegrityChecks:
            return .error
        case .contentFiltering, .duplicateEventPrevention:
            return .error
        case .schedulingConflictDetection, .pastEventModification:
            return .warning
        case .dailyEventLimits, .familyEventLimits:
            return businessRules.enableStrictLimits ? .error : .warning
        case .eventApproval:
            return .info
        }
    }
    
    // MARK: - Rule-Specific Validation
    
    /// Validates event against title rules
    func validateTitleRules(_ title: String) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        
        if !isRuleEnabled(.titleValidation) {
            return issues
        }
        
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Length validation
        if trimmedTitle.isEmpty {
            issues.append(ValidationIssue(
                rule: .titleValidation,
                severity: .error,
                message: "Event title is required",
                suggestion: "Please enter a title for your event"
            ))
        } else if trimmedTitle.count > businessRules.maxEventTitleLength {
            issues.append(ValidationIssue(
                rule: .titleValidation,
                severity: .error,
                message: "Title exceeds maximum length of \(businessRules.maxEventTitleLength) characters",
                suggestion: "Please shorten the event title"
            ))
        }
        
        // Content validation
        if isRuleEnabled(.contentFiltering) && containsInappropriateContent(trimmedTitle) {
            issues.append(ValidationIssue(
                rule: .contentFiltering,
                severity: .error,
                message: "Title contains inappropriate content",
                suggestion: "Please use appropriate language in event titles"
            ))
        }
        
        // Format validation
        if trimmedTitle.contains(where: { $0.isNewline }) {
            issues.append(ValidationIssue(
                rule: .titleValidation,
                severity: .error,
                message: "Title cannot contain line breaks",
                suggestion: "Please use a single line for the event title"
            ))
        }
        
        return issues
    }
    
    /// Validates event against duration rules
    func validateDurationRules(startDate: Date, endDate: Date, isAllDay: Bool) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        
        let duration = endDate.timeIntervalSince(startDate)
        
        if isAllDay {
            // All-day event duration validation
            if duration > businessRules.maxAllDayEventDuration {
                issues.append(ValidationIssue(
                    rule: .titleValidation, // Using titleValidation as a general rule
                    severity: .error,
                    message: "All-day event duration exceeds maximum of \(formatDuration(businessRules.maxAllDayEventDuration))",
                    suggestion: "Please reduce the event duration or split into multiple events"
                ))
            }
        } else {
            // Timed event duration validation
            if duration < businessRules.minEventDuration {
                issues.append(ValidationIssue(
                    rule: .titleValidation,
                    severity: .error,
                    message: "Event duration is below minimum of \(formatDuration(businessRules.minEventDuration))",
                    suggestion: "Please increase the event duration"
                ))
            }
            
            if duration > businessRules.maxTimedEventDuration {
                issues.append(ValidationIssue(
                    rule: .titleValidation,
                    severity: .error,
                    message: "Timed event duration exceeds maximum of \(formatDuration(businessRules.maxTimedEventDuration))",
                    suggestion: "Please reduce the event duration or make it an all-day event"
                ))
            }
        }
        
        return issues
    }
    
    /// Validates event against scheduling conflict rules
    func validateSchedulingConflictRules(
        _ event: CalendarEvent,
        conflictingEvents: [CalendarEvent]
    ) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        
        if !isRuleEnabled(.schedulingConflictDetection) || conflictingEvents.isEmpty {
            return issues
        }
        
        let severity = getValidationSeverity(.schedulingConflictDetection)
        let conflictTitles = conflictingEvents.map { $0.title }.joined(separator: ", ")
        
        issues.append(ValidationIssue(
            rule: .schedulingConflictDetection,
            severity: severity,
            message: "Event conflicts with existing events: \(conflictTitles)",
            suggestion: "Please choose a different time or resolve the conflicting events"
        ))
        
        return issues
    }
    
    /// Validates event against daily limit rules
    func validateDailyLimitRules(currentCount: Int, userId: UUID) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        
        if !isRuleEnabled(.dailyEventLimits) {
            return issues
        }
        
        let severity = getValidationSeverity(.dailyEventLimits)
        
        if currentCount >= businessRules.maxEventsPerDay {
            issues.append(ValidationIssue(
                rule: .dailyEventLimits,
                severity: severity,
                message: "Daily event limit of \(businessRules.maxEventsPerDay) reached",
                suggestion: "Please delete some events or try again tomorrow"
            ))
        } else if currentCount >= businessRules.maxEventsPerDay - 5 {
            issues.append(ValidationIssue(
                rule: .dailyEventLimits,
                severity: .warning,
                message: "Approaching daily event limit (\(currentCount)/\(businessRules.maxEventsPerDay))",
                suggestion: "Consider consolidating events or planning ahead"
            ))
        }
        
        return issues
    }
    
    /// Validates event against family limit rules
    func validateFamilyLimitRules(currentCount: Int, familyId: UUID) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        
        if !isRuleEnabled(.familyEventLimits) {
            return issues
        }
        
        let severity = getValidationSeverity(.familyEventLimits)
        
        if currentCount >= businessRules.maxFamilyEventsPerMonth {
            issues.append(ValidationIssue(
                rule: .familyEventLimits,
                severity: severity,
                message: "Monthly family event limit of \(businessRules.maxFamilyEventsPerMonth) reached",
                suggestion: "Please delete some events or wait until next month"
            ))
        } else if currentCount >= businessRules.maxFamilyEventsPerMonth - 10 {
            issues.append(ValidationIssue(
                rule: .familyEventLimits,
                severity: .warning,
                message: "Approaching monthly family event limit (\(currentCount)/\(businessRules.maxFamilyEventsPerMonth))",
                suggestion: "Consider planning family events more efficiently"
            ))
        }
        
        return issues
    }
    
    // MARK: - Private Methods
    
    private func saveBusinessRules(_ rules: CalendarBusinessRules) async throws {
        // In a real implementation, this would save to persistent storage
        // For now, just simulate the save operation
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        print("💾 CalendarBusinessRulesService: Saved business rules to storage")
    }
    
    private func containsInappropriateContent(_ text: String) -> Bool {
        // Basic inappropriate content detection
        let inappropriateWords = ["spam", "test123", "inappropriate", "badword"]
        let lowercaseText = text.lowercased()
        
        return inappropriateWords.contains { lowercaseText.contains($0) }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Supporting Types

struct CalendarBusinessRules: Codable {
    // Field validation limits
    var maxEventTitleLength: Int = 200
    var maxLocationLength: Int = 200
    var maxNotesLength: Int = 1000
    
    // Duration limits
    var minEventDuration: TimeInterval = 900 // 15 minutes
    var maxTimedEventDuration: TimeInterval = 86400 // 24 hours
    var maxAllDayEventDuration: TimeInterval = 2592000 // 30 days
    
    // Event limits
    var maxEventsPerDay: Int = 50
    var maxFamilyEventsPerMonth: Int = 200
    var maxConcurrentFamilyEvents: Int = 10
    
    // Time constraints
    var maxFutureYears: Int = 2
    var pastEventModificationHours: Int = 24
    
    // Feature toggles
    var enableTitleValidation: Bool = true
    var enableContentFiltering: Bool = true
    var enableSchedulingConflictDetection: Bool = true
    var enableDailyEventLimits: Bool = true
    var enableFamilyEventLimits: Bool = true
    var enableDuplicateEventPrevention: Bool = true
    var allowPastEventModification: Bool = true
    var requireEventApproval: Bool = false
    var enablePrivacyLevelValidation: Bool = true
    var enableDataIntegrityChecks: Bool = true
    var enableStrictLimits: Bool = false
    
    static let `default` = CalendarBusinessRules()
    
    static let strict = CalendarBusinessRules(
        maxEventsPerDay: 20,
        maxFamilyEventsPerMonth: 100,
        enableStrictLimits: true,
        requireEventApproval: true
    )
    
    static let relaxed = CalendarBusinessRules(
        maxEventsPerDay: 100,
        maxFamilyEventsPerMonth: 500,
        enableSchedulingConflictDetection: false,
        enableDailyEventLimits: false,
        enableFamilyEventLimits: false
    )
}

enum BusinessRuleType: String, CaseIterable {
    case titleValidation = "title_validation"
    case contentFiltering = "content_filtering"
    case schedulingConflictDetection = "scheduling_conflict_detection"
    case dailyEventLimits = "daily_event_limits"
    case familyEventLimits = "family_event_limits"
    case duplicateEventPrevention = "duplicate_event_prevention"
    case pastEventModification = "past_event_modification"
    case eventApproval = "event_approval"
    case privacyLevelValidation = "privacy_level_validation"
    case dataIntegrityChecks = "data_integrity_checks"
    
    var displayName: String {
        switch self {
        case .titleValidation:
            return "Title Validation"
        case .contentFiltering:
            return "Content Filtering"
        case .schedulingConflictDetection:
            return "Scheduling Conflict Detection"
        case .dailyEventLimits:
            return "Daily Event Limits"
        case .familyEventLimits:
            return "Family Event Limits"
        case .duplicateEventPrevention:
            return "Duplicate Event Prevention"
        case .pastEventModification:
            return "Past Event Modification"
        case .eventApproval:
            return "Event Approval"
        case .privacyLevelValidation:
            return "Privacy Level Validation"
        case .dataIntegrityChecks:
            return "Data Integrity Checks"
        }
    }
}

enum ValidationSeverity: String, CaseIterable {
    case info = "info"
    case warning = "warning"
    case error = "error"
    
    var displayName: String {
        return rawValue.capitalized
    }
    
    var color: String {
        switch self {
        case .info:
            return "blue"
        case .warning:
            return "orange"
        case .error:
            return "red"
        }
    }
}

// Note: ValidationIssue is now defined in CalendarService.swift