//
//  ScheduleStore.swift
//  Tribeboard
//
//  Created by Kiro on 2026/02/03.
//

import Foundation
import Combine

/// Manages persistence of RunSchedule objects to local JSON file
@MainActor
class ScheduleStore: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published private(set) var schedules: [RunSchedule] = []
    
    // MARK: - Private Properties
    
    private let fileManager: FileManager
    private let fileURL: URL
    
    // MARK: - Initialization
    
    init(fileManager: FileManager = .default) throws {
        self.fileManager = fileManager
        self.fileURL = try Self.getFileURL(fileManager: fileManager)
        
        // Load schedules on initialization
        Task {
            do {
                self.schedules = try await loadSchedules()
            } catch {
                // If file doesn't exist or is corrupted, start with empty array
                print("ScheduleStore: Failed to load schedules: \(error)")
                self.schedules = []
            }
        }
    }
    
    // MARK: - File URL Helper
    
    /// Get the file URL for schedule_store.json in Application Support directory
    private static func getFileURL(fileManager: FileManager) throws -> URL {
        let appSupportDir = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return appSupportDir.appendingPathComponent("schedule_store.json")
    }
    
    // MARK: - CRUD Operations
    
    /// Load schedules from JSON file
    func loadSchedules() async throws -> [RunSchedule] {
        // Check if file exists
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return []
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let wrapper = try JSONDecoder().decode(ScheduleStoreWrapper.self, from: data)
            return wrapper.schedules
        } catch {
            // If JSON is corrupted, backup the file and start fresh
            try await backupCorruptedFile()
            throw ScheduleStoreError.corruptedData(underlyingError: error)
        }
    }
    
    /// Save schedules to JSON file with version wrapper
    func saveSchedules(_ schedules: [RunSchedule]) async throws {
        let wrapper = ScheduleStoreWrapper(version: 1, schedules: schedules)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        
        do {
            let data = try encoder.encode(wrapper)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            throw ScheduleStoreError.saveFailed(underlyingError: error)
        }
    }
    
    /// Add or update a schedule and persist immediately
    func upsert(_ schedule: RunSchedule) async throws {
        // Check if schedule with this ID already exists
        if let index = schedules.firstIndex(where: { $0.id == schedule.id }) {
            // Update existing schedule
            schedules[index] = schedule
        } else {
            // Add new schedule
            schedules.append(schedule)
        }
        
        // Persist immediately
        try await saveSchedules(schedules)
    }
    
    /// Remove schedule by ID and persist immediately
    func delete(scheduleId: String) async throws {
        schedules.removeAll { $0.id == scheduleId }
        
        // Persist immediately
        try await saveSchedules(schedules)
    }
    
    // MARK: - Error Handling
    
    /// Backup corrupted JSON file with timestamp
    private func backupCorruptedFile() async throws {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return
        }
        
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let backupURL = fileURL.deletingLastPathComponent()
            .appendingPathComponent("schedule_store_corrupted_\(timestamp).json")
        
        do {
            try fileManager.moveItem(at: fileURL, to: backupURL)
            print("ScheduleStore: Backed up corrupted file to \(backupURL.lastPathComponent)")
        } catch {
            print("ScheduleStore: Failed to backup corrupted file: \(error)")
        }
    }
    
    // MARK: - Demo Seeding
    
    /// Seed demo schedules if they don't already exist
    /// Creates "School Dropoff" and "School Pickup" schedules for weekdays
    /// Idempotent - safe to call multiple times
    func seedIfNeeded() async throws {
        // Check if demo schedules already exist
        let hasDropoff = scheduleExists(withTitle: "School Dropoff")
        let hasPickup = scheduleExists(withTitle: "School Pickup")
        
        // If both exist, nothing to do
        if hasDropoff && hasPickup {
            return
        }
        
        // Demo user IDs (from DemoSeedDataService)
        let tafadzwaId = "demo-tafadzwa"
        let tjId = "demo-tj"
        let tawanaId = "demo-tawana"
        
        // Demo coordinates in San Francisco area
        let homeLocation = LocationData(
            latitude: 37.7749,
            longitude: -122.4194,
            address: "123 Main St, San Francisco, CA"
        )
        
        let friendLocation = LocationData(
            latitude: 37.7849,
            longitude: -122.4094,
            address: "456 Oak Ave, San Francisco, CA"
        )
        
        let schoolLocation = LocationData(
            latitude: 37.7949,
            longitude: -122.3994,
            address: "789 School Rd, San Francisco, CA"
        )
        
        // Create School Dropoff schedule if it doesn't exist
        if !hasDropoff {
            let dropoffStops = [
                ScheduleStop(
                    type: .pickup,
                    label: "Home",
                    location: homeLocation
                ),
                ScheduleStop(
                    type: .pickup,
                    label: "TJ's Friend's House",
                    location: friendLocation
                ),
                ScheduleStop(
                    type: .dropoff,
                    label: "School",
                    location: schoolLocation
                )
            ]
            
            let dropoffSchedule = RunSchedule(
                title: "School Dropoff",
                timeOfDay: TimeOfDay(hour: 6, minute: 45),
                recurrence: .weekly(weekdays: [.monday, .tuesday, .wednesday, .thursday, .friday]),
                startDate: Date(),
                endDate: nil,
                driverUserId: tafadzwaId,
                passengerUserIds: [tjId, tawanaId],
                stops: dropoffStops,
                isEnabled: true
            )
            
            try await upsert(dropoffSchedule)
        }
        
        // Create School Pickup schedule if it doesn't exist
        if !hasPickup {
            let pickupStops = [
                ScheduleStop(
                    type: .pickup,
                    label: "School",
                    location: schoolLocation
                ),
                ScheduleStop(
                    type: .dropoff,
                    label: "TJ's Friend's House",
                    location: friendLocation
                ),
                ScheduleStop(
                    type: .dropoff,
                    label: "Home",
                    location: homeLocation
                )
            ]
            
            let pickupSchedule = RunSchedule(
                title: "School Pickup",
                timeOfDay: TimeOfDay(hour: 14, minute: 30),
                recurrence: .weekly(weekdays: [.monday, .tuesday, .wednesday, .thursday, .friday]),
                startDate: Date(),
                endDate: nil,
                driverUserId: tafadzwaId,
                passengerUserIds: [tjId, tawanaId],
                stops: pickupStops,
                isEnabled: true
            )
            
            try await upsert(pickupSchedule)
        }
    }
    
    // MARK: - Helper Methods
    
    /// Check if a schedule with the given title already exists
    func scheduleExists(withTitle title: String) -> Bool {
        return schedules.contains { $0.title == title }
    }
}

// MARK: - Storage Wrapper

/// Wrapper for JSON storage with version field
private struct ScheduleStoreWrapper: Codable {
    let version: Int
    let schedules: [RunSchedule]
}

// MARK: - Errors

enum ScheduleStoreError: LocalizedError {
    case corruptedData(underlyingError: Error)
    case saveFailed(underlyingError: Error)
    
    var errorDescription: String? {
        switch self {
        case .corruptedData(let error):
            return "Schedule data is corrupted: \(error.localizedDescription)"
        case .saveFailed(let error):
            return "Failed to save schedules: \(error.localizedDescription)"
        }
    }
}
