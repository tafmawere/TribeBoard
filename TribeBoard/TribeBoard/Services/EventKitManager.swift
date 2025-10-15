import Foundation
import EventKit
import SwiftData

/// Errors that can occur in EventKit operations
enum EventKitError: LocalizedError {
    case accessDenied
    case accessNotDetermined
    case calendarCreationFailed(String)
    case eventCreationFailed(String)
    case eventUpdateFailed(String)
    case eventDeletionFailed(String)
    case calendarNotFound(String)
    case eventNotFound(String)
    case invalidEvent(String)
    case storeNotAvailable
    case unknownError(String)
    
    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Calendar access is denied. Please enable calendar access in Settings."
        case .accessNotDetermined:
            return "Calendar access permission has not been determined."
        case .calendarCreationFailed(let message):
            return "Failed to create calendar: \(message)"
        case .eventCreationFailed(let message):
            return "Failed to create event: \(message)"
        case .eventUpdateFailed(let message):
            return "Failed to update event: \(message)"
        case .eventDeletionFailed(let message):
            return "Failed to delete event: \(message)"
        case .calendarNotFound(let name):
            return "Calendar '\(name)' not found"
        case .eventNotFound(let identifier):
            return "Event with identifier '\(identifier)' not found"
        case .invalidEvent(let message):
            return "Invalid event: \(message)"
        case .storeNotAvailable:
            return "EventKit store is not available"
        case .unknownError(let message):
            return "Unknown EventKit error: \(message)"
        }
    }
}

/// Protocol for EventKit operations to enable testing
protocol EventKitManagerProtocol {
    func requestAccess() async throws -> Bool
    func createTribeBoardCalendar() async throws -> EKCalendar
    func createTribeBoardFamilyCalendar() async throws -> EKCalendar
    func createTribeBoardPersonalCalendar() async throws -> EKCalendar
    func syncEventToAppleCalendar(_ event: CalendarEvent) async throws -> String
    func updateEventInAppleCalendar(_ event: CalendarEvent) async throws
    func deleteEventFromAppleCalendar(_ eventIdentifier: String) async throws
    func fetchEventsFromAppleCalendar(for dateRange: DateInterval) async throws -> [EKEvent]
    func findTribeBoardCalendars() async throws -> (main: EKCalendar?, family: EKCalendar?, personal: EKCalendar?)
    func areTribeBoardCalendarsSetUp() async throws -> Bool
    func setupAllTribeBoardCalendars() async throws -> (main: EKCalendar, family: EKCalendar, personal: EKCalendar)
}

/// Service for managing EventKit integration with Apple Calendar
@MainActor
class EventKitManager: ObservableObject, EventKitManagerProtocol {
    
    // MARK: - Properties
    
    private let eventStore: EKEventStore
    private var tribeBoardCalendar: EKCalendar?
    private var tribeBoardFamilyCalendar: EKCalendar?
    private var tribeBoardPersonalCalendar: EKCalendar?
    
    // MARK: - Constants
    
    private enum CalendarNames {
        static let main = "TribeBoard"
        static let family = "TribeBoard Family"
        static let personal = "TribeBoard Personal"
    }
    
    // MARK: - Initialization
    
    init() {
        self.eventStore = EKEventStore()
        print("🗓️ EventKitManager: Initialized with new EventStore")
    }
    
    // MARK: - Permission Management
    
    /// Requests access to EventKit and returns whether permission was granted
    func requestAccess() async throws -> Bool {
        print("🔐 EventKitManager: Requesting EventKit access...")
        
        return try await withCheckedThrowingContinuation { continuation in
            eventStore.requestFullAccessToEvents { granted, error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("❌ EventKitManager: Access request failed with error: \(error.localizedDescription)")
                        continuation.resume(throwing: EventKitError.unknownError(error.localizedDescription))
                        return
                    }
                    
                    if granted {
                        print("✅ EventKitManager: EventKit access granted")
                        continuation.resume(returning: true)
                    } else {
                        print("❌ EventKitManager: EventKit access denied")
                        continuation.resume(returning: false)
                    }
                }
            }
        }
    }
    
    /// Checks current authorization status
    var authorizationStatus: EKAuthorizationStatus {
        return EKEventStore.authorizationStatus(for: .event)
    }
    
    /// Checks if EventKit access is available
    var hasAccess: Bool {
        return authorizationStatus == .fullAccess
    }
    
    // MARK: - Calendar Management
    
    /// Creates the main TribeBoard calendar
    func createTribeBoardCalendar() async throws -> EKCalendar {
        print("📅 EventKitManager: Creating main TribeBoard calendar...")
        
        guard hasAccess else {
            throw EventKitError.accessDenied
        }
        
        // Check if calendar already exists
        if let existingCalendar = findCalendar(withTitle: CalendarNames.main) {
            print("✅ EventKitManager: Found existing TribeBoard calendar")
            self.tribeBoardCalendar = existingCalendar
            return existingCalendar
        }
        
        // Create new calendar
        let calendar = EKCalendar(for: .event, eventStore: eventStore)
        calendar.title = CalendarNames.main
        calendar.cgColor = UIColor.systemBlue.cgColor
        
        // Find the default source (usually iCloud or Local)
        guard let source = eventStore.defaultCalendarForNewEvents?.source ?? eventStore.sources.first(where: { $0.sourceType == .calDAV }) ?? eventStore.sources.first else {
            throw EventKitError.calendarCreationFailed("No suitable calendar source found")
        }
        
        calendar.source = source
        
        do {
            try eventStore.saveCalendar(calendar, commit: true)
            print("✅ EventKitManager: Successfully created TribeBoard calendar")
            self.tribeBoardCalendar = calendar
            return calendar
        } catch {
            print("❌ EventKitManager: Failed to create TribeBoard calendar: \(error.localizedDescription)")
            throw EventKitError.calendarCreationFailed(error.localizedDescription)
        }
    }
    
    /// Creates the TribeBoard Family calendar for shared events
    func createTribeBoardFamilyCalendar() async throws -> EKCalendar {
        print("👨‍👩‍👧‍👦 EventKitManager: Creating TribeBoard Family calendar...")
        
        guard hasAccess else {
            throw EventKitError.accessDenied
        }
        
        // Check if calendar already exists
        if let existingCalendar = findCalendar(withTitle: CalendarNames.family) {
            print("✅ EventKitManager: Found existing TribeBoard Family calendar")
            self.tribeBoardFamilyCalendar = existingCalendar
            return existingCalendar
        }
        
        // Create new calendar
        let calendar = EKCalendar(for: .event, eventStore: eventStore)
        calendar.title = CalendarNames.family
        calendar.cgColor = UIColor.systemGreen.cgColor
        
        // Find the default source
        guard let source = eventStore.defaultCalendarForNewEvents?.source ?? eventStore.sources.first(where: { $0.sourceType == .calDAV }) ?? eventStore.sources.first else {
            throw EventKitError.calendarCreationFailed("No suitable calendar source found")
        }
        
        calendar.source = source
        
        do {
            try eventStore.saveCalendar(calendar, commit: true)
            print("✅ EventKitManager: Successfully created TribeBoard Family calendar")
            self.tribeBoardFamilyCalendar = calendar
            return calendar
        } catch {
            print("❌ EventKitManager: Failed to create TribeBoard Family calendar: \(error.localizedDescription)")
            throw EventKitError.calendarCreationFailed(error.localizedDescription)
        }
    }
    
    /// Creates the TribeBoard Personal calendar for private events
    func createTribeBoardPersonalCalendar() async throws -> EKCalendar {
        print("👤 EventKitManager: Creating TribeBoard Personal calendar...")
        
        guard hasAccess else {
            throw EventKitError.accessDenied
        }
        
        // Check if calendar already exists
        if let existingCalendar = findCalendar(withTitle: CalendarNames.personal) {
            print("✅ EventKitManager: Found existing TribeBoard Personal calendar")
            self.tribeBoardPersonalCalendar = existingCalendar
            return existingCalendar
        }
        
        // Create new calendar
        let calendar = EKCalendar(for: .event, eventStore: eventStore)
        calendar.title = CalendarNames.personal
        calendar.cgColor = UIColor.systemOrange.cgColor
        
        // Find the default source
        guard let source = eventStore.defaultCalendarForNewEvents?.source ?? eventStore.sources.first(where: { $0.sourceType == .calDAV }) ?? eventStore.sources.first else {
            throw EventKitError.calendarCreationFailed("No suitable calendar source found")
        }
        
        calendar.source = source
        
        do {
            try eventStore.saveCalendar(calendar, commit: true)
            print("✅ EventKitManager: Successfully created TribeBoard Personal calendar")
            self.tribeBoardPersonalCalendar = calendar
            return calendar
        } catch {
            print("❌ EventKitManager: Failed to create TribeBoard Personal calendar: \(error.localizedDescription)")
            throw EventKitError.calendarCreationFailed(error.localizedDescription)
        }
    }
    
    /// Finds existing TribeBoard calendars
    func findTribeBoardCalendars() async throws -> (main: EKCalendar?, family: EKCalendar?, personal: EKCalendar?) {
        print("🔍 EventKitManager: Finding existing TribeBoard calendars...")
        
        guard hasAccess else {
            throw EventKitError.accessDenied
        }
        
        let mainCalendar = findCalendar(withTitle: CalendarNames.main)
        let familyCalendar = findCalendar(withTitle: CalendarNames.family)
        let personalCalendar = findCalendar(withTitle: CalendarNames.personal)
        
        // Cache found calendars
        self.tribeBoardCalendar = mainCalendar
        self.tribeBoardFamilyCalendar = familyCalendar
        self.tribeBoardPersonalCalendar = personalCalendar
        
        print("📊 EventKitManager: Found calendars - Main: \(mainCalendar != nil), Family: \(familyCalendar != nil), Personal: \(personalCalendar != nil)")
        
        return (main: mainCalendar, family: familyCalendar, personal: personalCalendar)
    }
    
    /// Finds a calendar by title
    private func findCalendar(withTitle title: String) -> EKCalendar? {
        return eventStore.calendars(for: .event).first { calendar in
            calendar.title == title
        }
    }
    
    /// Gets the appropriate calendar for an event based on its privacy level
    private func getTargetCalendar(for event: CalendarEvent) throws -> EKCalendar {
        switch event.privacyLevel {
        case .familyShared:
            if let familyCalendar = tribeBoardFamilyCalendar {
                return familyCalendar
            } else if let mainCalendar = tribeBoardCalendar {
                return mainCalendar
            } else {
                throw EventKitError.calendarNotFound("No suitable calendar found for family event")
            }
        case .personal:
            if let personalCalendar = tribeBoardPersonalCalendar {
                return personalCalendar
            } else if let mainCalendar = tribeBoardCalendar {
                return mainCalendar
            } else {
                throw EventKitError.calendarNotFound("No suitable calendar found for personal event")
            }
        }
    }
}    
  
  // MARK: - Event Conversion Utilities
    
    /// Converts a CalendarEvent to an EKEvent
    private func convertToEKEvent(_ calendarEvent: CalendarEvent, in calendar: EKCalendar) throws -> EKEvent {
        print("🔄 EventKitManager: Converting CalendarEvent to EKEvent - '\(calendarEvent.title)'")
        
        // Validate the event can be synced
        guard calendarEvent.canSyncToEventKit else {
            let errors = calendarEvent.eventKitSyncValidationErrors
            throw EventKitError.invalidEvent("Event validation failed: \(errors.joined(separator: ", "))")
        }
        
        let ekEvent = calendarEvent.toEKEvent(in: eventStore, calendar: calendar)
        
        print("✅ EventKitManager: Successfully converted CalendarEvent to EKEvent")
        return ekEvent
    }
    
    /// Converts an EKEvent to a CalendarEvent
    private func convertFromEKEvent(_ ekEvent: EKEvent, createdBy: UUID, familyId: UUID? = nil) -> CalendarEvent {
        print("🔄 EventKitManager: Converting EKEvent to CalendarEvent - '\(ekEvent.title ?? "Untitled")'")
        
        // Extract privacy level from metadata or use default
        let privacyLevel = CalendarEvent.extractPrivacyLevel(from: ekEvent) ?? .personal
        let extractedFamilyId = CalendarEvent.extractFamilyId(from: ekEvent) ?? familyId
        
        let calendarEvent = CalendarEvent.fromEKEvent(
            ekEvent,
            createdBy: createdBy,
            familyId: extractedFamilyId,
            defaultPrivacyLevel: privacyLevel
        )
        
        print("✅ EventKitManager: Successfully converted EKEvent to CalendarEvent")
        return calendarEvent
    }
    
    // MARK: - Event Sync Operations
    
    /// Syncs a CalendarEvent to Apple Calendar and returns the EventKit identifier
    func syncEventToAppleCalendar(_ event: CalendarEvent) async throws -> String {
        print("📤 EventKitManager: Syncing event to Apple Calendar - '\(event.title)'")
        
        guard hasAccess else {
            throw EventKitError.accessDenied
        }
        
        // Validate event
        guard event.canSyncToEventKit else {
            let errors = event.eventKitSyncValidationErrors
            throw EventKitError.invalidEvent("Cannot sync event: \(errors.joined(separator: ", "))")
        }
        
        // Get the appropriate calendar
        let targetCalendar = try getTargetCalendar(for: event)
        
        // Convert to EKEvent
        let ekEvent = try convertToEKEvent(event, in: targetCalendar)
        
        // Save to EventKit
        do {
            try eventStore.save(ekEvent, span: .thisEvent)
            print("✅ EventKitManager: Successfully synced event to Apple Calendar")
            print("   EventKit ID: \(ekEvent.eventIdentifier)")
            return ekEvent.eventIdentifier
        } catch {
            print("❌ EventKitManager: Failed to sync event to Apple Calendar: \(error.localizedDescription)")
            throw EventKitError.eventCreationFailed(error.localizedDescription)
        }
    }
    
    /// Updates an existing event in Apple Calendar
    func updateEventInAppleCalendar(_ event: CalendarEvent) async throws {
        print("📝 EventKitManager: Updating event in Apple Calendar - '\(event.title)'")
        
        guard hasAccess else {
            throw EventKitError.accessDenied
        }
        
        // Validate event
        guard event.canSyncToEventKit else {
            let errors = event.eventKitSyncValidationErrors
            throw EventKitError.invalidEvent("Cannot update event: \(errors.joined(separator: ", "))")
        }
        
        // Find the existing event
        guard let eventKitIdentifier = event.eventKitIdentifier,
              let existingEKEvent = eventStore.event(withIdentifier: eventKitIdentifier) else {
            throw EventKitError.eventNotFound(event.eventKitIdentifier ?? "unknown")
        }
        
        // Update the existing EKEvent with new data
        existingEKEvent.title = event.title
        existingEKEvent.startDate = event.startDate
        existingEKEvent.endDate = event.endDate
        existingEKEvent.isAllDay = event.isAllDay
        existingEKEvent.location = event.location
        
        // Update notes with metadata
        var combinedNotes = event.notes ?? ""
        let metadata = createEventKitMetadata(for: event)
        
        if !combinedNotes.isEmpty {
            combinedNotes += "\n\n"
        }
        combinedNotes += metadata
        
        existingEKEvent.notes = combinedNotes
        
        // Check if calendar needs to change based on privacy level
        let targetCalendar = try getTargetCalendar(for: event)
        if existingEKEvent.calendar.calendarIdentifier != targetCalendar.calendarIdentifier {
            existingEKEvent.calendar = targetCalendar
        }
        
        // Save changes
        do {
            try eventStore.save(existingEKEvent, span: .thisEvent)
            print("✅ EventKitManager: Successfully updated event in Apple Calendar")
        } catch {
            print("❌ EventKitManager: Failed to update event in Apple Calendar: \(error.localizedDescription)")
            throw EventKitError.eventUpdateFailed(error.localizedDescription)
        }
    }
    
    /// Deletes an event from Apple Calendar
    func deleteEventFromAppleCalendar(_ eventIdentifier: String) async throws {
        print("🗑️ EventKitManager: Deleting event from Apple Calendar - ID: \(eventIdentifier)")
        
        guard hasAccess else {
            throw EventKitError.accessDenied
        }
        
        // Find the event
        guard let ekEvent = eventStore.event(withIdentifier: eventIdentifier) else {
            throw EventKitError.eventNotFound(eventIdentifier)
        }
        
        // Delete the event
        do {
            try eventStore.remove(ekEvent, span: .thisEvent)
            print("✅ EventKitManager: Successfully deleted event from Apple Calendar")
        } catch {
            print("❌ EventKitManager: Failed to delete event from Apple Calendar: \(error.localizedDescription)")
            throw EventKitError.eventDeletionFailed(error.localizedDescription)
        }
    }
    
    /// Fetches events from Apple Calendar within a date range
    func fetchEventsFromAppleCalendar(for dateRange: DateInterval) async throws -> [EKEvent] {
        print("📥 EventKitManager: Fetching events from Apple Calendar")
        print("   Date range: \(dateRange.start) to \(dateRange.end)")
        
        guard hasAccess else {
            throw EventKitError.accessDenied
        }
        
        // Get all TribeBoard calendars
        var calendarsToSearch: [EKCalendar] = []
        
        if let mainCalendar = tribeBoardCalendar {
            calendarsToSearch.append(mainCalendar)
        }
        if let familyCalendar = tribeBoardFamilyCalendar {
            calendarsToSearch.append(familyCalendar)
        }
        if let personalCalendar = tribeBoardPersonalCalendar {
            calendarsToSearch.append(personalCalendar)
        }
        
        // If no TribeBoard calendars found, search all calendars for TribeBoard events
        if calendarsToSearch.isEmpty {
            calendarsToSearch = eventStore.calendars(for: .event)
        }
        
        // Create predicate for the date range
        let predicate = eventStore.predicateForEvents(
            withStart: dateRange.start,
            end: dateRange.end,
            calendars: calendarsToSearch
        )
        
        // Fetch events
        let events = eventStore.events(matching: predicate)
        
        // Filter to only TribeBoard events if searching all calendars
        let tribeBoardEvents = events.filter { event in
            CalendarEvent.isEKEventFromTribeBoard(event) ||
            calendarsToSearch.contains { calendar in
                calendar.calendarIdentifier == event.calendar.calendarIdentifier &&
                (calendar.title == CalendarNames.main ||
                 calendar.title == CalendarNames.family ||
                 calendar.title == CalendarNames.personal)
            }
        }
        
        print("📊 EventKitManager: Found \(tribeBoardEvents.count) TribeBoard events in Apple Calendar")
        return tribeBoardEvents
    }
    
    // MARK: - Metadata Utilities
    
    /// Creates metadata string for EventKit notes
    private func createEventKitMetadata(for event: CalendarEvent) -> String {
        var metadata: [String] = []
        
        // Add privacy level
        metadata.append("\(CalendarEvent.EventKitConstants.privacyLevelKey): \(event.privacyLevel.rawValue)")
        
        // Add event ID
        metadata.append("\(CalendarEvent.EventKitConstants.eventIdKey): \(event.id.uuidString)")
        
        // Add family ID if present
        if let familyId = event.familyId {
            metadata.append("\(CalendarEvent.EventKitConstants.familyIdKey): \(familyId.uuidString)")
        }
        
        return "\(CalendarEvent.EventKitConstants.metadataPrefix) \(metadata.joined(separator: ", ")) \(CalendarEvent.EventKitConstants.metadataSuffix)"
    }
    
    // MARK: - Batch Operations
    
    /// Syncs multiple events to Apple Calendar
    func syncEventsToAppleCalendar(_ events: [CalendarEvent]) async throws -> [String: String] {
        print("📤 EventKitManager: Syncing \(events.count) events to Apple Calendar")
        
        var results: [String: String] = [:]
        var errors: [String] = []
        
        for event in events {
            do {
                let eventKitId = try await syncEventToAppleCalendar(event)
                results[event.id.uuidString] = eventKitId
            } catch {
                errors.append("Event '\(event.title)': \(error.localizedDescription)")
            }
        }
        
        if !errors.isEmpty {
            print("⚠️ EventKitManager: Some events failed to sync: \(errors.joined(separator: "; "))")
        }
        
        print("✅ EventKitManager: Batch sync completed - \(results.count) successful, \(errors.count) failed")
        return results
    }
    
    /// Updates multiple events in Apple Calendar
    func updateEventsInAppleCalendar(_ events: [CalendarEvent]) async throws {
        print("📝 EventKitManager: Updating \(events.count) events in Apple Calendar")
        
        var errors: [String] = []
        
        for event in events {
            do {
                try await updateEventInAppleCalendar(event)
            } catch {
                errors.append("Event '\(event.title)': \(error.localizedDescription)")
            }
        }
        
        if !errors.isEmpty {
            print("⚠️ EventKitManager: Some events failed to update: \(errors.joined(separator: "; "))")
            throw EventKitError.unknownError("Batch update partially failed: \(errors.joined(separator: "; "))")
        }
        
        print("✅ EventKitManager: Batch update completed successfully")
    }
    
    /// Deletes multiple events from Apple Calendar
    func deleteEventsFromAppleCalendar(_ eventIdentifiers: [String]) async throws {
        print("🗑️ EventKitManager: Deleting \(eventIdentifiers.count) events from Apple Calendar")
        
        var errors: [String] = []
        
        for identifier in eventIdentifiers {
            do {
                try await deleteEventFromAppleCalendar(identifier)
            } catch {
                errors.append("Event ID '\(identifier)': \(error.localizedDescription)")
            }
        }
        
        if !errors.isEmpty {
            print("⚠️ EventKitManager: Some events failed to delete: \(errors.joined(separator: "; "))")
            throw EventKitError.unknownError("Batch deletion partially failed: \(errors.joined(separator: "; "))")
        }
        
        print("✅ EventKitManager: Batch deletion completed successfully")
    }
    
    // MARK: - Calendar Information
    
    /// Gets information about TribeBoard calendars
    func getTribeBoardCalendarInfo() async throws -> (main: String?, family: String?, personal: String?) {
        let calendars = try await findTribeBoardCalendars()
        
        return (
            main: calendars.main?.calendarIdentifier,
            family: calendars.family?.calendarIdentifier,
            personal: calendars.personal?.calendarIdentifier
        )
    }
    
    /// Checks if TribeBoard calendars are properly set up
    func areTribeBoardCalendarsSetUp() async throws -> Bool {
        let calendars = try await findTribeBoardCalendars()
        return calendars.main != nil || calendars.family != nil || calendars.personal != nil
    }
    
    /// Sets up all TribeBoard calendars
    func setupAllTribeBoardCalendars() async throws -> (main: EKCalendar, family: EKCalendar, personal: EKCalendar) {
        print("🏗️ EventKitManager: Setting up all TribeBoard calendars...")
        
        let mainCalendar = try await createTribeBoardCalendar()
        let familyCalendar = try await createTribeBoardFamilyCalendar()
        let personalCalendar = try await createTribeBoardPersonalCalendar()
        
        print("✅ EventKitManager: All TribeBoard calendars set up successfully")
        return (main: mainCalendar, family: familyCalendar, personal: personalCalendar)
    }

// MARK: - EventKit Manager Extensions

extension EventKitManager {
    
    /// Convenience method to check if an event exists in Apple Calendar
    func eventExists(withIdentifier identifier: String) -> Bool {
        return eventStore.event(withIdentifier: identifier) != nil
    }
    
    /// Gets the calendar identifier for a specific privacy level
    func getCalendarIdentifier(for privacyLevel: CalendarEvent.PrivacyLevel) -> String? {
        switch privacyLevel {
        case .familyShared:
            return tribeBoardFamilyCalendar?.calendarIdentifier ?? tribeBoardCalendar?.calendarIdentifier
        case .personal:
            return tribeBoardPersonalCalendar?.calendarIdentifier ?? tribeBoardCalendar?.calendarIdentifier
        }
    }
    
    /// Validates that EventKit is available and accessible
    func validateEventKitAvailability() throws {
        guard hasAccess else {
            switch authorizationStatus {
            case .notDetermined:
                throw EventKitError.accessNotDetermined
            case .denied, .restricted:
                throw EventKitError.accessDenied
            case .fullAccess:
                break // This shouldn't happen if hasAccess is false
            case .writeOnly:
                throw EventKitError.accessDenied
            @unknown default:
                throw EventKitError.unknownError("Unknown authorization status")
            }
        }
    }
}