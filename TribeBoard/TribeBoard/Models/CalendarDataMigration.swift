import Foundation
import SwiftData

/// Handles migration of existing calendar data to the new enhanced CalendarEvent model
struct CalendarDataMigration {
    
    // MARK: - Migration Types
    
    /// Migration result information
    struct MigrationResult {
        let migratedEventsCount: Int
        let skippedEventsCount: Int
        let errorCount: Int
        let errors: [MigrationError]
        let duration: TimeInterval
        
        var isSuccessful: Bool {
            errorCount == 0
        }
        
        var summary: String {
            if isSuccessful {
                return "Successfully migrated \(migratedEventsCount) events in \(String(format: "%.2f", duration))s"
            } else {
                return "Migration completed with \(errorCount) errors. Migrated: \(migratedEventsCount), Skipped: \(skippedEventsCount)"
            }
        }
    }
    
    /// Migration error types
    enum MigrationError: LocalizedError {
        case invalidEventData(String)
        case missingRequiredField(String, String)
        case conversionFailed(String, Error)
        case duplicateEvent(String)
        case validationFailed(String, [String])
        
        var errorDescription: String? {
            switch self {
            case .invalidEventData(let eventId):
                return "Invalid event data for event: \(eventId)"
            case .missingRequiredField(let field, let eventId):
                return "Missing required field '\(field)' for event: \(eventId)"
            case .conversionFailed(let eventId, let error):
                return "Failed to convert event \(eventId): \(error.localizedDescription)"
            case .duplicateEvent(let eventId):
                return "Duplicate event found: \(eventId)"
            case .validationFailed(let eventId, let errors):
                return "Validation failed for event \(eventId): \(errors.joined(separator: ", "))"
            }
        }
    }
    
    /// Legacy calendar event structure for migration
    struct LegacyCalendarEvent {
        let id: UUID
        let title: String
        let date: Date
        let type: String
        let participants: [UUID]
        let description: String?
        let location: String?
        
        // Convert legacy event type to privacy level
        var inferredPrivacyLevel: CalendarEvent.PrivacyLevel {
            switch type.lowercased() {
            case "family_activity", "birthday", "school_event":
                return .familyShared
            default:
                return .personal
            }
        }
        
        // Infer end date from start date (default 1 hour for appointments, all day for others)
        var inferredEndDate: Date {
            switch type.lowercased() {
            case "appointment", "reminder":
                return Calendar.current.date(byAdding: .hour, value: 1, to: date) ?? date
            case "birthday", "school_event", "family_activity":
                return Calendar.current.date(byAdding: .day, value: 1, to: date) ?? date
            default:
                return Calendar.current.date(byAdding: .hour, value: 1, to: date) ?? date
            }
        }
        
        // Determine if event should be all-day
        var isAllDay: Bool {
            switch type.lowercased() {
            case "birthday", "school_event", "family_activity":
                return true
            default:
                return false
            }
        }
    }
    
    // MARK: - Migration Methods
    
    /// Performs migration of legacy calendar events to new CalendarEvent model
    static func migrateLegacyEvents(
        legacyEvents: [LegacyCalendarEvent],
        defaultUserId: UUID,
        defaultFamilyId: UUID?,
        modelContext: ModelContext
    ) async throws -> MigrationResult {
        let startTime = Date()
        var migratedCount = 0
        var skippedCount = 0
        var errors: [MigrationError] = []
        
        print("🔄 Starting calendar data migration...")
        print("   - Legacy events to migrate: \(legacyEvents.count)")
        print("   - Default user ID: \(defaultUserId)")
        print("   - Default family ID: \(defaultFamilyId?.uuidString ?? "None")")
        
        // Check for existing CalendarEvents to avoid duplicates
        let existingEvents = try await fetchExistingCalendarEvents(modelContext: modelContext)
        let existingEventIds = Set(existingEvents.map { $0.id })
        
        print("   - Existing CalendarEvents found: \(existingEvents.count)")
        
        for legacyEvent in legacyEvents {
            do {
                // Skip if event already exists
                if existingEventIds.contains(legacyEvent.id) {
                    print("   ⏭️ Skipping existing event: \(legacyEvent.title)")
                    skippedCount += 1
                    continue
                }
                
                // Convert legacy event to new CalendarEvent
                let calendarEvent = try convertLegacyEvent(
                    legacyEvent,
                    defaultUserId: defaultUserId,
                    defaultFamilyId: defaultFamilyId
                )
                
                // Validate the converted event
                let validationErrors = validateConvertedEvent(calendarEvent)
                if !validationErrors.isEmpty {
                    errors.append(.validationFailed(legacyEvent.id.uuidString, validationErrors))
                    skippedCount += 1
                    continue
                }
                
                // Insert into model context
                modelContext.insert(calendarEvent)
                migratedCount += 1
                
                print("   ✅ Migrated: \(legacyEvent.title) (\(calendarEvent.privacyLevel.displayName))")
                
            } catch {
                errors.append(.conversionFailed(legacyEvent.id.uuidString, error))
                skippedCount += 1
                print("   ❌ Failed to migrate: \(legacyEvent.title) - \(error.localizedDescription)")
            }
        }
        
        // Save changes
        do {
            try modelContext.save()
            print("✅ Migration completed successfully")
        } catch {
            print("❌ Failed to save migrated events: \(error.localizedDescription)")
            throw error
        }
        
        let duration = Date().timeIntervalSince(startTime)
        let result = MigrationResult(
            migratedEventsCount: migratedCount,
            skippedEventsCount: skippedCount,
            errorCount: errors.count,
            errors: errors,
            duration: duration
        )
        
        print("📊 Migration Summary:")
        print("   - Migrated: \(migratedCount)")
        print("   - Skipped: \(skippedCount)")
        print("   - Errors: \(errors.count)")
        print("   - Duration: \(String(format: "%.2f", duration))s")
        
        return result
    }
    
    /// Converts a legacy calendar event to the new CalendarEvent model
    private static func convertLegacyEvent(
        _ legacyEvent: LegacyCalendarEvent,
        defaultUserId: UUID,
        defaultFamilyId: UUID?
    ) throws -> CalendarEvent {
        
        // Determine family ID based on privacy level
        let familyId = legacyEvent.inferredPrivacyLevel == .familyShared ? defaultFamilyId : nil
        
        // Create new CalendarEvent
        let calendarEvent = CalendarEvent(
            title: legacyEvent.title,
            startDate: legacyEvent.date,
            endDate: legacyEvent.inferredEndDate,
            isAllDay: legacyEvent.isAllDay,
            location: legacyEvent.location,
            notes: legacyEvent.description,
            privacyLevel: legacyEvent.inferredPrivacyLevel,
            createdBy: defaultUserId,
            familyId: familyId
        )
        
        // Preserve the original ID if possible
        calendarEvent.id = legacyEvent.id
        
        // Set creation date to past to indicate this is migrated data
        calendarEvent.createdAt = legacyEvent.date
        
        return calendarEvent
    }
    
    /// Validates a converted CalendarEvent
    private static func validateConvertedEvent(_ event: CalendarEvent) -> [String] {
        var errors: [String] = []
        
        if !event.isTitleValid {
            errors.append("Invalid title")
        }
        
        if !event.isDateRangeValid {
            errors.append("Invalid date range")
        }
        
        if !event.isDurationValid {
            errors.append("Invalid duration")
        }
        
        if !event.isFamilySharingValid {
            errors.append("Invalid family sharing configuration")
        }
        
        return errors
    }
    
    /// Fetches existing CalendarEvents from the model context
    private static func fetchExistingCalendarEvents(modelContext: ModelContext) async throws -> [CalendarEvent] {
        let descriptor = FetchDescriptor<CalendarEvent>()
        return try modelContext.fetch(descriptor)
    }
    
    // MARK: - Mock Data Migration
    
    /// Migrates mock calendar events from MockDataGenerator
    static func migrateMockCalendarEvents(
        defaultUserId: UUID,
        defaultFamilyId: UUID?,
        modelContext: ModelContext
    ) async throws -> MigrationResult {
        
        // Convert MockDataGenerator events to legacy format for migration
        let mockEvents = MockDataGenerator.mockCalendarEvents()
        let legacyEvents = mockEvents.map { mockEvent in
            LegacyCalendarEvent(
                id: mockEvent.id,
                title: mockEvent.title,
                date: mockEvent.date,
                type: mockEvent.type.rawValue,
                participants: mockEvent.participants,
                description: mockEvent.description,
                location: mockEvent.location
            )
        }
        
        return try await migrateLegacyEvents(
            legacyEvents: legacyEvents,
            defaultUserId: defaultUserId,
            defaultFamilyId: defaultFamilyId,
            modelContext: modelContext
        )
    }
    
    // MARK: - Migration Utilities
    
    /// Checks if migration is needed
    static func isMigrationNeeded(modelContext: ModelContext) throws -> Bool {
        // Check if there are any CalendarEvents in the database
        let descriptor = FetchDescriptor<CalendarEvent>()
        let existingEvents = try modelContext.fetch(descriptor)
        
        // If no CalendarEvents exist, migration might be needed
        // This is a simple check - in a real app, you might want to check for legacy data structures
        return existingEvents.isEmpty
    }
    
    /// Creates default SyncConfiguration for a user
    static func createDefaultSyncConfiguration(
        for userId: UUID,
        modelContext: ModelContext
    ) throws {
        // Check if SyncConfiguration already exists for this user
        var descriptor = FetchDescriptor<SyncConfiguration>()
        descriptor.predicate = #Predicate<SyncConfiguration> { config in
            config.userId == userId
        }
        
        let existingConfigs = try modelContext.fetch(descriptor)
        
        if existingConfigs.isEmpty {
            let syncConfig = SyncConfiguration(userId: userId)
            modelContext.insert(syncConfig)
            print("✅ Created default SyncConfiguration for user: \(userId)")
        } else {
            print("ℹ️ SyncConfiguration already exists for user: \(userId)")
        }
    }
    
    /// Performs cleanup of legacy calendar data structures
    static func cleanupLegacyData() {
        // This method would handle cleanup of any legacy data structures
        // For now, it's a placeholder since we're working with mock data
        print("🧹 Legacy data cleanup completed")
    }
    
    // MARK: - Migration Validation
    
    /// Validates the migration results
    static func validateMigration(
        originalCount: Int,
        result: MigrationResult,
        modelContext: ModelContext
    ) throws -> Bool {
        
        // Fetch all CalendarEvents after migration
        let descriptor = FetchDescriptor<CalendarEvent>()
        let migratedEvents = try modelContext.fetch(descriptor)
        
        print("🔍 Validating migration results...")
        print("   - Original events: \(originalCount)")
        print("   - Migrated events: \(result.migratedEventsCount)")
        print("   - Skipped events: \(result.skippedEventsCount)")
        print("   - Total events in database: \(migratedEvents.count)")
        
        // Basic validation
        let expectedTotal = result.migratedEventsCount + result.skippedEventsCount
        let isValid = expectedTotal == originalCount && result.errorCount == 0
        
        if isValid {
            print("✅ Migration validation passed")
        } else {
            print("❌ Migration validation failed")
            print("   - Expected total: \(expectedTotal)")
            print("   - Actual original: \(originalCount)")
            print("   - Error count: \(result.errorCount)")
        }
        
        return isValid
    }
}

// MARK: - Migration Extensions

extension CalendarEvent {
    /// Creates a CalendarEvent from legacy mock data
    static func fromLegacyMockEvent(
        _ mockEvent: MockCalendarEvent,
        createdBy: UUID,
        familyId: UUID?
    ) -> CalendarEvent {
        
        let privacyLevel: CalendarEvent.PrivacyLevel = {
            switch mockEvent.type {
            case MockCalendarEvent.EventType.familyActivity, MockCalendarEvent.EventType.birthday, MockCalendarEvent.EventType.schoolEvent:
                return CalendarEvent.PrivacyLevel.familyShared
            default:
                return CalendarEvent.PrivacyLevel.personal
            }
        }()
        
        let endDate: Date = {
            switch mockEvent.type {
            case .appointment, .reminder:
                return Calendar.current.date(byAdding: .hour, value: 1, to: mockEvent.date) ?? mockEvent.date
            default:
                return Calendar.current.date(byAdding: .day, value: 1, to: mockEvent.date) ?? mockEvent.date
            }
        }()
        
        let isAllDay = [MockCalendarEvent.EventType.birthday, MockCalendarEvent.EventType.schoolEvent, MockCalendarEvent.EventType.familyActivity].contains(mockEvent.type)
        
        let event = CalendarEvent(
            title: mockEvent.title,
            startDate: mockEvent.date,
            endDate: endDate,
            isAllDay: isAllDay,
            location: mockEvent.location,
            notes: mockEvent.description,
            privacyLevel: privacyLevel,
            createdBy: createdBy,
            familyId: privacyLevel == CalendarEvent.PrivacyLevel.familyShared ? familyId : nil
        )
        
        // Preserve original ID and creation date
        event.id = mockEvent.id
        event.createdAt = mockEvent.date
        
        return event
    }
}