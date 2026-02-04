//
//  CoreDataService.swift
//  Tribeboard
//
//  Created by Kiro on 2026/02/03.
//

import Foundation
import CoreData

class CoreDataService {
    static let shared = CoreDataService()
    
    private let persistenceController = PersistenceController.shared
    
    private var context: NSManagedObjectContext {
        persistenceController.container.viewContext
    }
    
    // MARK: - Run Management
    
    func saveRun(_ run: Run) async throws {
        try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    // Check if run already exists
                    let fetchRequest: NSFetchRequest<RunEntity> = RunEntity.fetchRequest()
                    fetchRequest.predicate = NSPredicate(format: "id == %@", run.id)
                    
                    let existingRuns = try self.context.fetch(fetchRequest)
                    let runEntity = existingRuns.first ?? RunEntity(context: self.context)
                    
                    // Update entity properties
                    runEntity.id = run.id
                    runEntity.title = run.title
                    runEntity.scheduledTime = run.scheduledTime
                    runEntity.driverId = run.driverId
                    runEntity.status = run.status.rawValue
                    runEntity.createdBy = run.createdBy
                    runEntity.familyId = run.familyId
                    runEntity.isDelayed = run.isDelayed
                    runEntity.delayReason = run.delayReason
                    runEntity.currentStopIndex = Int32(run.currentStopIndex)
                    runEntity.startTime = run.startTime
                    runEntity.lastSyncedAt = Date()
                    
                    // Handle location
                    if let location = run.lastLocation {
                        runEntity.lastLocationLatitude = location.latitude
                        runEntity.lastLocationLongitude = location.longitude
                    }
                    runEntity.lastLocationUpdatedAt = run.lastLocationUpdatedAt
                    
                    // Encode complex data as JSON
                    runEntity.stopsData = try JSONEncoder().encode(run.stops)
                    runEntity.passengersData = try JSONEncoder().encode(run.passengers)
                    
                    try self.context.save()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func fetchRun(runId: String) async throws -> Run? {
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    let fetchRequest: NSFetchRequest<RunEntity> = RunEntity.fetchRequest()
                    fetchRequest.predicate = NSPredicate(format: "id == %@", runId)
                    
                    guard let runEntity = try self.context.fetch(fetchRequest).first else {
                        continuation.resume(returning: nil)
                        return
                    }
                    
                    let run = try self.convertToRun(runEntity)
                    continuation.resume(returning: run)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func fetchAllRuns() async throws -> [Run] {
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    let fetchRequest: NSFetchRequest<RunEntity> = RunEntity.fetchRequest()
                    fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \RunEntity.scheduledTime, ascending: false)]
                    
                    let runEntities = try self.context.fetch(fetchRequest)
                    let runs = try runEntities.compactMap { try self.convertToRun($0) }
                    continuation.resume(returning: runs)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func deleteRun(id: String) throws {
        let fetchRequest: NSFetchRequest<RunEntity> = RunEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", id)
        
        let runEntities = try context.fetch(fetchRequest)
        runEntities.forEach { context.delete($0) }
        
        try context.save()
    }
    
    // MARK: - Run Events Management
    
    func saveRunEvent(_ event: RunEvent) throws {
        // Check if event already exists
        let fetchRequest: NSFetchRequest<RunEventEntity> = RunEventEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", event.id)
        
        let existingEvents = try context.fetch(fetchRequest)
        let eventEntity = existingEvents.first ?? RunEventEntity(context: context)
        
        // Update entity properties
        eventEntity.id = event.id
        eventEntity.runId = event.runId
        eventEntity.type = event.type.rawValue
        eventEntity.timestamp = event.timestamp
        eventEntity.actorId = event.actorId
        eventEntity.stateBefore = event.stateBefore?.rawValue
        eventEntity.stateAfter = event.stateAfter.rawValue
        eventEntity.currentStopIndex = Int32(event.currentStopIndex)
        eventEntity.note = event.note
        eventEntity.lastSyncedAt = Date()
        
        // Handle location
        if let location = event.location {
            eventEntity.locationLatitude = location.latitude
            eventEntity.locationLongitude = location.longitude
        }
        
        try context.save()
    }
    
    func fetchRunEvents(runId: String) throws -> [RunEvent] {
        let fetchRequest: NSFetchRequest<RunEventEntity> = RunEventEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "runId == %@", runId)
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \RunEventEntity.timestamp, ascending: true)]
        
        let eventEntities = try context.fetch(fetchRequest)
        return try eventEntities.compactMap { try convertToRunEvent($0) }
    }
    
    // MARK: - Cache Management
    
    func clearOldCompletedRuns(olderThan days: Int = 7) throws {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        
        let fetchRequest: NSFetchRequest<RunEntity> = RunEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(
            format: "status IN %@ AND scheduledTime < %@",
            [RunStatus.completed.rawValue, RunStatus.cancelled.rawValue],
            cutoffDate as NSDate
        )
        
        let oldRuns = try context.fetch(fetchRequest)
        oldRuns.forEach { context.delete($0) }
        
        try context.save()
    }
    
    // MARK: - Conversion Helpers
    
    private func convertToRun(_ entity: RunEntity) throws -> Run {
        guard let id = entity.id,
              let title = entity.title,
              let scheduledTime = entity.scheduledTime,
              let driverId = entity.driverId,
              let statusString = entity.status,
              let status = RunStatus(rawValue: statusString),
              let createdBy = entity.createdBy,
              let familyId = entity.familyId,
              let stopsData = entity.stopsData,
              let passengersData = entity.passengersData else {
            throw CoreDataError.invalidData
        }
        
        let stops = try JSONDecoder().decode([RunStop].self, from: stopsData)
        let passengers = try JSONDecoder().decode([MemberSummary].self, from: passengersData)
        
        var lastLocation: GeoPoint?
        if entity.lastLocationLatitude != 0 || entity.lastLocationLongitude != 0 {
            lastLocation = GeoPoint(latitude: entity.lastLocationLatitude, longitude: entity.lastLocationLongitude)
        }
        
        return Run(
            id: id,
            title: title,
            scheduledTime: scheduledTime,
            driverId: driverId,
            status: status,
            stops: stops,
            passengers: passengers,
            createdBy: createdBy,
            familyId: familyId,
            isDelayed: entity.isDelayed,
            delayReason: entity.delayReason,
            currentStopIndex: Int(entity.currentStopIndex),
            lastLocation: lastLocation,
            lastLocationUpdatedAt: entity.lastLocationUpdatedAt,
            startTime: entity.startTime
        )
    }
    
    private func convertToRunEvent(_ entity: RunEventEntity) throws -> RunEvent {
        guard let id = entity.id,
              let runId = entity.runId,
              let typeString = entity.type,
              let type = RunEventType(rawValue: typeString),
              let timestamp = entity.timestamp,
              let actorId = entity.actorId,
              let stateAfterString = entity.stateAfter,
              let stateAfter = RunStatus(rawValue: stateAfterString) else {
            throw CoreDataError.invalidData
        }
        
        let stateBefore = entity.stateBefore.flatMap { RunStatus(rawValue: $0) }
        
        var location: GeoPoint?
        if entity.locationLatitude != 0 || entity.locationLongitude != 0 {
            location = GeoPoint(latitude: entity.locationLatitude, longitude: entity.locationLongitude)
        }
        
        return RunEvent(
            id: id,
            runId: runId,
            type: type,
            timestamp: timestamp,
            actorId: actorId,
            stateBefore: stateBefore,
            stateAfter: stateAfter,
            currentStopIndex: Int(entity.currentStopIndex),
            location: location,
            note: entity.note
        )
    }
}

enum CoreDataError: LocalizedError {
    case invalidData
    case saveFailed
    case fetchFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidData:
            return "Invalid data format"
        case .saveFailed:
            return "Failed to save data"
        case .fetchFailed:
            return "Failed to fetch data"
        }
    }
}