import Foundation
import SwiftData
import Combine

/// Service for managing calendar events in offline scenarios
@MainActor
class OfflineEventManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isOffline: Bool = false
    @Published var pendingOperationsCount: Int = 0
    @Published var offlineCapabilities: OfflineCapabilities = .full
    
    // MARK: - Types
    
    enum OfflineCapabilities {
        case full        // All operations available offline
        case readOnly    // Only viewing available offline
        case limited     // Basic operations only
        case none        // No offline capabilities
        
        var displayName: String {
            switch self {
            case .full:
                return "Full offline support"
            case .readOnly:
                return "View-only offline"
            case .limited:
                return "Limited offline support"
            case .none:
                return "Online only"
            }
        }
    }
    
    // MARK: - Private Properties
    
    private let modelContext: ModelContext
    private let networkMonitor: NetworkMonitor
    private let syncManager: CalendarSyncManager
    
    private var offlineOperations: [OfflineOperation] = []
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(
        modelContext: ModelContext,
        networkMonitor: NetworkMonitor = NetworkMonitor.shared,
        syncManager: CalendarSyncManager
    ) {
        self.modelContext = modelContext
        self.networkMonitor = networkMonitor
        self.syncManager = syncManager
        
        setupNetworkMonitoring()
        loadPersistedOperations()
        
        print("📱 OfflineEventManager: Initialized with \(offlineOperations.count) pending operations")
    }
    
    // MARK: - Offline Event Operations
    
    /// Creates an event offline with queuing for later sync
    func createEventOffline(
        title: String,
        startDate: Date,
        endDate: Date,
        isAllDay: Bool = false,
        location: String? = nil,
        notes: String? = nil,
        privacyLevel: CalendarEvent.PrivacyLevel = .personal,
        createdBy: UUID,
        familyId: UUID? = nil
    ) throws -> CalendarEvent {
        
        print("📝 OfflineEventManager: Creating event offline - '\(title)'")
        
        // Validate offline capabilities
        guard offlineCapabilities != .none && offlineCapabilities != .readOnly else {
            throw OfflineEventError.operationNotAllowed("Event creation not available offline")
        }
        
        // Create the event
        let event = CalendarEvent(
            title: title,
            startDate: startDate,
            endDate: endDate,
            isAllDay: isAllDay,
            location: location,
            notes: notes,
            privacyLevel: privacyLevel,
            createdBy: createdBy,
            familyId: familyId
        )
        
        // Validate the event
        guard event.isFullyValid else {
            throw OfflineEventError.validationFailed("Event validation failed")
        }
        
        // Set offline metadata
        event.needsSync = true
        event.needsEventKitSync = true
        event.createdAt = Date()
        event.lastModified = Date()
        
        // Save to local database
        modelContext.insert(event)
        try modelContext.save()
        
        // Queue for sync when online
        let operation = OfflineOperation(
            id: UUID(),
            eventId: event.id,
            operationType: .create,
            userId: createdBy,
            createdAt: Date(),
            eventData: try event.toOfflineData()
        )
        
        offlineOperations.append(operation)
        pendingOperationsCount = offlineOperations.count
        
        try persistOfflineOperations()
        
        print("✅ OfflineEventManager: Event created offline and queued for sync")
        
        return event
    }
    
    /// Updates an event offline with queuing for later sync
    func updateEventOffline(
        _ event: CalendarEvent,
        title: String? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil,
        isAllDay: Bool? = nil,
        location: String? = nil,
        notes: String? = nil,
        privacyLevel: CalendarEvent.PrivacyLevel? = nil,
        modifiedBy: UUID
    ) throws -> CalendarEvent {
        
        print("📝 OfflineEventManager: Updating event offline - '\(event.title)'")
        
        // Validate offline capabilities
        guard offlineCapabilities == .full else {
            throw OfflineEventError.operationNotAllowed("Event updates not available offline")
        }
        
        // Validate permissions
        guard canModifyEvent(event, userId: modifiedBy) else {
            throw OfflineEventError.permissionDenied("User cannot modify this event")
        }
        
        // Store original data for rollback if needed
        let originalData = try event.toOfflineData()
        
        // Update the event
        event.updateEvent(
            title: title,
            startDate: startDate,
            endDate: endDate,
            isAllDay: isAllDay,
            location: location,
            notes: notes,
            privacyLevel: privacyLevel,
            modifiedBy: modifiedBy
        )
        
        // Validate updated event
        guard event.isFullyValid else {
            // Rollback changes
            try event.fromOfflineData(originalData)
            throw OfflineEventError.validationFailed("Updated event validation failed")
        }
        
        // Save to local database
        try modelContext.save()
        
        // Queue for sync when online
        let operation = OfflineOperation(
            id: UUID(),
            eventId: event.id,
            operationType: .update,
            userId: modifiedBy,
            createdAt: Date(),
            eventData: try event.toOfflineData()
        )
        
        offlineOperations.append(operation)
        pendingOperationsCount = offlineOperations.count
        
        try persistOfflineOperations()
        
        print("✅ OfflineEventManager: Event updated offline and queued for sync")
        
        return event
    }
    
    /// Deletes an event offline with queuing for later sync
    func deleteEventOffline(_ event: CalendarEvent, deletedBy: UUID) throws {
        print("🗑️ OfflineEventManager: Deleting event offline - '\(event.title)'")
        
        // Validate offline capabilities
        guard offlineCapabilities == .full else {
            throw OfflineEventError.operationNotAllowed("Event deletion not available offline")
        }
        
        // Validate permissions
        guard canDeleteEvent(event, userId: deletedBy) else {
            throw OfflineEventError.permissionDenied("User cannot delete this event")
        }
        
        // Mark as deleted (soft delete for sync purposes)
        event.markAsDeleted(by: deletedBy)
        
        // Save to local database
        try modelContext.save()
        
        // Queue for sync when online
        let operation = OfflineOperation(
            id: UUID(),
            eventId: event.id,
            operationType: .delete,
            userId: deletedBy,
            createdAt: Date(),
            eventData: try event.toOfflineData()
        )
        
        offlineOperations.append(operation)
        pendingOperationsCount = offlineOperations.count
        
        try persistOfflineOperations()
        
        print("✅ OfflineEventManager: Event deleted offline and queued for sync")
    }
    
    // MARK: - Offline Data Access
    
    /// Fetches events for offline viewing
    func fetchEventsOffline(
        for userId: UUID,
        dateRange: DateInterval,
        includeFamily: Bool = true
    ) throws -> [CalendarEvent] {
        
        print("🔍 OfflineEventManager: Fetching events offline for user: \(userId)")
        
        let descriptor = FetchDescriptor<CalendarEvent>()
        let allEvents = try modelContext.fetch(descriptor)
        
        let filteredEvents = allEvents.filter { event in
            !event.isDeleted &&
            event.startDate >= dateRange.start &&
            event.startDate <= dateRange.end &&
            (event.createdBy == userId || (includeFamily && event.privacyLevel == .familyShared))
        }.sorted { $0.startDate < $1.startDate }
        
        print("📊 OfflineEventManager: Found \(filteredEvents.count) events offline")
        
        return filteredEvents
    }
    
    /// Gets offline statistics for a user
    func getOfflineStatistics(for userId: UUID) throws -> OfflineStatistics {
        let descriptor = FetchDescriptor<CalendarEvent>()
        let allEvents = try modelContext.fetch(descriptor)
        
        let userEvents = allEvents.filter { event in
            event.createdBy == userId || event.privacyLevel == .familyShared
        }
        
        let pendingSync = userEvents.filter { $0.needsSync || $0.needsEventKitSync }
        let offlineCreated = userEvents.filter { $0.eventKitIdentifier == nil }
        
        return OfflineStatistics(
            totalEvents: userEvents.count,
            pendingSyncEvents: pendingSync.count,
            offlineCreatedEvents: offlineCreated.count,
            pendingOperations: offlineOperations.filter { $0.userId == userId }.count,
            lastOfflineActivity: getLastOfflineActivity(for: userId)
        )
    }
    
    // MARK: - Sync Integration
    
    /// Processes offline operations when connection is restored
    func processOfflineOperationsWhenOnline() async {
        guard networkMonitor.isConnected && !offlineOperations.isEmpty else {
            return
        }
        
        print("🔄 OfflineEventManager: Processing \(offlineOperations.count) offline operations")
        
        // Wait for network to stabilize
        let isStableConnection = await networkMonitor.waitForConnection(timeout: 5.0)
        guard isStableConnection else {
            print("⚠️ OfflineEventManager: Network connection not stable, deferring operation processing")
            return
        }
        
        var processedOperations: [UUID] = []
        var failedOperations: [OfflineOperation] = []
        
        // Process operations in batches to avoid overwhelming the sync system
        let batchSize = 10
        let batches = offlineOperations.chunked(into: batchSize)
        
        for (batchIndex, batch) in batches.enumerated() {
            print("📦 OfflineEventManager: Processing batch \(batchIndex + 1)/\(batches.count)")
            
            for operation in batch {
                do {
                    // Verify event still exists and is valid
                    guard let event = try getEvent(by: operation.eventId) else {
                        print("⚠️ OfflineEventManager: Event not found for operation: \(operation.id)")
                        processedOperations.append(operation.id) // Remove invalid operation
                        continue
                    }
                    
                    // Validate operation is still relevant
                    if !isOperationStillRelevant(operation, event: event) {
                        print("ℹ️ OfflineEventManager: Operation \(operation.id) is no longer relevant")
                        processedOperations.append(operation.id)
                        continue
                    }
                    
                    // Queue operation with sync manager
                    syncManager.queueEventForSync(
                        event,
                        operation: operation.operationType.toSyncOperationType(),
                        userId: operation.userId
                    )
                    processedOperations.append(operation.id)
                    
                } catch {
                    print("❌ OfflineEventManager: Failed to process operation \(operation.id): \(error)")
                    failedOperations.append(operation)
                }
            }
            
            // Small delay between batches to avoid overwhelming the system
            if batchIndex < batches.count - 1 {
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            }
        }
        
        // Remove processed operations
        offlineOperations.removeAll { processedOperations.contains($0.id) }
        pendingOperationsCount = offlineOperations.count
        
        try? persistOfflineOperations()
        
        print("✅ OfflineEventManager: Processed \(processedOperations.count) operations, \(failedOperations.count) failed")
        
        // If there are failed operations, they'll be retried on next connection
        if !failedOperations.isEmpty {
            print("⏰ OfflineEventManager: \(failedOperations.count) operations will be retried later")
        }
    }
    
    /// Checks if an offline operation is still relevant
    private func isOperationStillRelevant(_ operation: OfflineOperation, event: CalendarEvent) -> Bool {
        switch operation.operationType {
        case .create:
            // Create operation is relevant if event hasn't been synced yet
            return event.eventKitIdentifier == nil
            
        case .update:
            // Update operation is relevant if event needs sync
            return event.needsEventKitSync || event.needsSync
            
        case .delete:
            // Delete operation is relevant if event is marked as deleted but still has EventKit ID
            return event.isDeleted && event.eventKitIdentifier != nil
        }
    }
    
    /// Retries failed offline operations with exponential backoff
    func retryFailedOperations() async {
        guard networkMonitor.isConnected else {
            print("📱 OfflineEventManager: Cannot retry operations while offline")
            return
        }
        
        // Filter operations that might have failed in previous attempts
        let oldOperations = offlineOperations.filter { operation in
            // Consider operations older than 5 minutes as potentially failed
            Date().timeIntervalSince(operation.createdAt) > 300
        }
        
        guard !oldOperations.isEmpty else {
            return
        }
        
        print("🔄 OfflineEventManager: Retrying \(oldOperations.count) potentially failed operations")
        
        // Process with exponential backoff
        for (index, operation) in oldOperations.enumerated() {
            // Exponential backoff: 1s, 2s, 4s, 8s, etc.
            let delay = min(pow(2.0, Double(index)), 30.0) // Max 30 seconds
            
            if index > 0 {
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
            
            // Check if still connected
            guard networkMonitor.isConnected else {
                print("📱 OfflineEventManager: Connection lost during retry, stopping")
                break
            }
            
            // Try to process the operation
            do {
                if let event = try getEvent(by: operation.eventId) {
                    syncManager.queueEventForSync(
                        event,
                        operation: operation.operationType.toSyncOperationType(),
                        userId: operation.userId
                    )
                    
                    // Remove from offline operations if successfully queued
                    if let operationIndex = offlineOperations.firstIndex(where: { $0.id == operation.id }) {
                        offlineOperations.remove(at: operationIndex)
                        pendingOperationsCount = offlineOperations.count
                    }
                }
            } catch {
                print("❌ OfflineEventManager: Retry failed for operation \(operation.id): \(error)")
            }
        }
        
        try? persistOfflineOperations()
    }
    
    /// Clears all offline operations (use with caution)
    func clearOfflineOperations() throws {
        offlineOperations.removeAll()
        pendingOperationsCount = 0
        try persistOfflineOperations()
        
        print("🧹 OfflineEventManager: Cleared all offline operations")
    }
    
    // MARK: - Private Methods
    
    private func setupNetworkMonitoring() {
        networkMonitor.$isConnected
            .sink { [weak self] isConnected in
                Task { @MainActor in
                    self?.isOffline = !isConnected
                    
                    if isConnected {
                        // Process offline operations when connection is restored
                        await self?.processOfflineOperationsWhenOnline()
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    private func canModifyEvent(_ event: CalendarEvent, userId: UUID) -> Bool {
        // User can modify their own events
        if event.createdBy == userId {
            return true
        }
        
        // For family events, check if user has family admin permissions
        // This would integrate with the family service in a full implementation
        if event.privacyLevel == .familyShared {
            // Placeholder - would check actual family permissions
            return false
        }
        
        return false
    }
    
    private func canDeleteEvent(_ event: CalendarEvent, userId: UUID) -> Bool {
        // Same logic as modify for now
        return canModifyEvent(event, userId: userId)
    }
    
    private func getEvent(by id: UUID) throws -> CalendarEvent? {
        let descriptor = FetchDescriptor<CalendarEvent>()
        let events = try modelContext.fetch(descriptor)
        return events.first { $0.id == id }
    }
    
    private func getLastOfflineActivity(for userId: UUID) -> Date? {
        return offlineOperations
            .filter { $0.userId == userId }
            .map { $0.createdAt }
            .max()
    }
    
    // MARK: - Persistence
    
    private func persistOfflineOperations() throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(offlineOperations)
        UserDefaults.standard.set(data, forKey: "OfflineEventOperations")
    }
    
    private func loadPersistedOperations() {
        guard let data = UserDefaults.standard.data(forKey: "OfflineEventOperations") else {
            return
        }
        
        do {
            let decoder = JSONDecoder()
            offlineOperations = try decoder.decode([OfflineOperation].self, from: data)
            pendingOperationsCount = offlineOperations.count
        } catch {
            print("❌ OfflineEventManager: Failed to load persisted operations: \(error)")
            offlineOperations = []
            pendingOperationsCount = 0
        }
    }
}

// MARK: - Supporting Types

/// Represents an offline operation
struct OfflineOperation: Codable, Identifiable {
    let id: UUID
    let eventId: UUID
    let operationType: OfflineOperationType
    let userId: UUID
    let createdAt: Date
    let eventData: [String: Any]
    
    enum CodingKeys: String, CodingKey {
        case id, eventId, operationType, userId, createdAt, eventData
    }
    
    init(id: UUID, eventId: UUID, operationType: OfflineOperationType, userId: UUID, createdAt: Date, eventData: [String: Any]) {
        self.id = id
        self.eventId = eventId
        self.operationType = operationType
        self.userId = userId
        self.createdAt = createdAt
        self.eventData = eventData
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        eventId = try container.decode(UUID.self, forKey: .eventId)
        operationType = try container.decode(OfflineOperationType.self, forKey: .operationType)
        userId = try container.decode(UUID.self, forKey: .userId)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        
        // Decode eventData as JSON
        let eventDataString = try container.decode(String.self, forKey: .eventData)
        if let data = eventDataString.data(using: .utf8),
           let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
            eventData = json
        } else {
            eventData = [:]
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(eventId, forKey: .eventId)
        try container.encode(operationType, forKey: .operationType)
        try container.encode(userId, forKey: .userId)
        try container.encode(createdAt, forKey: .createdAt)
        
        // Encode eventData as JSON string
        let data = try JSONSerialization.data(withJSONObject: eventData)
        let eventDataString = String(data: data, encoding: .utf8) ?? "{}"
        try container.encode(eventDataString, forKey: .eventData)
    }
}

/// Types of offline operations
enum OfflineOperationType: String, Codable, CaseIterable {
    case create
    case update
    case delete
    
    var displayName: String {
        switch self {
        case .create:
            return "Create"
        case .update:
            return "Update"
        case .delete:
            return "Delete"
        }
    }
    
    func toSyncOperationType() -> SyncOperationType {
        switch self {
        case .create:
            return .create
        case .update:
            return .update
        case .delete:
            return .delete
        }
    }
}

/// Statistics about offline operations
struct OfflineStatistics: Codable {
    let totalEvents: Int
    let pendingSyncEvents: Int
    let offlineCreatedEvents: Int
    let pendingOperations: Int
    let lastOfflineActivity: Date?
    
    var description: String {
        return """
        Offline Statistics:
        - Total Events: \(totalEvents)
        - Pending Sync: \(pendingSyncEvents)
        - Created Offline: \(offlineCreatedEvents)
        - Pending Operations: \(pendingOperations)
        - Last Activity: \(lastOfflineActivity?.formatted() ?? "None")
        """
    }
}

/// Errors that can occur during offline operations
enum OfflineEventError: LocalizedError {
    case operationNotAllowed(String)
    case validationFailed(String)
    case permissionDenied(String)
    case dataCorruption(String)
    
    var errorDescription: String? {
        switch self {
        case .operationNotAllowed(let message):
            return "Operation not allowed: \(message)"
        case .validationFailed(let message):
            return "Validation failed: \(message)"
        case .permissionDenied(let message):
            return "Permission denied: \(message)"
        case .dataCorruption(let message):
            return "Data corruption: \(message)"
        }
    }
}

// MARK: - CalendarEvent Extensions for Offline Support

extension CalendarEvent {
    /// Converts event to offline data dictionary
    func toOfflineData() throws -> [String: Any] {
        return [
            "id": id.uuidString,
            "title": title,
            "startDate": startDate.timeIntervalSince1970,
            "endDate": endDate.timeIntervalSince1970,
            "isAllDay": isAllDay,
            "location": location as Any,
            "notes": notes as Any,
            "privacyLevel": privacyLevel.rawValue,
            "createdBy": createdBy.uuidString,
            "familyId": familyId?.uuidString as Any,
            "lastModified": lastModified.timeIntervalSince1970,
            "version": version
        ]
    }
    
    /// Updates event from offline data dictionary
    func fromOfflineData(_ data: [String: Any]) throws {
        guard let title = data["title"] as? String,
              let startDateInterval = data["startDate"] as? TimeInterval,
              let endDateInterval = data["endDate"] as? TimeInterval,
              let isAllDay = data["isAllDay"] as? Bool,
              let privacyLevelString = data["privacyLevel"] as? String,
              let privacyLevel = PrivacyLevel(rawValue: privacyLevelString),
              let createdByString = data["createdBy"] as? String,
              let createdBy = UUID(uuidString: createdByString),
              let lastModifiedInterval = data["lastModified"] as? TimeInterval,
              let version = data["version"] as? Int else {
            throw OfflineEventError.dataCorruption("Invalid offline data format")
        }
        
        self.title = title
        self.startDate = Date(timeIntervalSince1970: startDateInterval)
        self.endDate = Date(timeIntervalSince1970: endDateInterval)
        self.isAllDay = isAllDay
        self.location = data["location"] as? String
        self.notes = data["notes"] as? String
        self.privacyLevel = privacyLevel
        self.createdBy = createdBy
        self.lastModified = Date(timeIntervalSince1970: lastModifiedInterval)
        self.version = version
        
        if let familyIdString = data["familyId"] as? String {
            self.familyId = UUID(uuidString: familyIdString)
        }
    }
}

// MARK: - Array Extension for Batching

