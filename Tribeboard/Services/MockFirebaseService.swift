//
//  MockFirebaseService.swift
//  Tribeboard
//
//  Created by Kiro on 2026/02/03.
//

import Foundation
import CoreLocation
import Combine

// Mock GeoPoint for development without Firebase
struct GeoPoint: Codable {
    let latitude: Double
    let longitude: Double
    
    init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}

// Mock Firestore Encoder/Decoder
struct Firestore {
    struct Encoder {
        func encode<T: Codable>(_ value: T) throws -> [String: Any] {
            let data = try JSONEncoder().encode(value)
            let json = try JSONSerialization.jsonObject(with: data, options: [])
            return json as? [String: Any] ?? [:]
        }
    }
    
    struct Decoder {
        func decode<T: Codable>(_ type: T.Type, from data: [String: Any]) throws -> T {
            let jsonData = try JSONSerialization.data(withJSONObject: data, options: [])
            return try JSONDecoder().decode(type, from: jsonData)
        }
    }
}

@MainActor
class MockFirebaseRunService: ObservableObject {
    @Published var currentRun: Run?
    @Published var runEvents: [RunEvent] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    private var mockRuns: [String: Run] = [:]
    private var mockEvents: [String: [RunEvent]] = [:]
    
    // MARK: - Run Management
    
    func createRun(_ run: Run) async throws -> Run {
        isLoading = true
        defer { isLoading = false }
        
        // Simulate network delay
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // Validate run data
        guard !run.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw FirebaseError.invalidData
        }
        
        guard !run.driverId.isEmpty else {
            throw FirebaseError.invalidData
        }
        
        guard !run.passengers.isEmpty else {
            throw FirebaseError.invalidData
        }
        
        guard !run.stops.isEmpty else {
            throw FirebaseError.invalidData
        }
        
        // Create run with backend-assigned ID
        let createdRun = Run(
            id: UUID().uuidString,
            title: run.title,
            scheduledTime: run.scheduledTime,
            driverId: run.driverId,
            status: .scheduled,
            stops: run.stops,
            passengers: run.passengers,
            createdBy: run.createdBy,
            familyId: run.familyId
        )
        
        // Store in mock database
        mockRuns[createdRun.id] = createdRun
        
        // Log creation event
        await logRunEvent(
            runId: createdRun.id,
            type: .runCreated,
            stateBefore: nil,
            stateAfter: .scheduled,
            currentStopIndex: 0,
            note: "Run '\(createdRun.title)' created"
        )
        
        return createdRun
    }
    
    func fetchRun(runId: String) async throws -> Run {
        isLoading = true
        defer { isLoading = false }
        
        // Simulate network delay
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        guard let run = mockRuns[runId] else {
            throw FirebaseError.documentNotFound
        }
        
        self.currentRun = run
        return run
    }
    
    func listenToRun(runId: String) {
        // Simulate real-time updates by checking for changes every 2 seconds
        Task {
            while true {
                if let run = mockRuns[runId] {
                    await MainActor.run {
                        self.currentRun = run
                    }
                }
                try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            }
        }
    }
    
    func updateRunStatus(runId: String, newStatus: RunStatus, location: CLLocationCoordinate2D? = nil) async throws {
        guard var run = mockRuns[runId] else {
            throw FirebaseError.documentNotFound
        }
        
        let oldStatus = run.status
        
        // Validate state transition using state machine
        let dummyAction: DriverAction = .startRun // This will be replaced by proper action handling
        guard RunStateMachine.canTransition(from: oldStatus, to: newStatus, with: dummyAction) else {
            throw FirebaseError.invalidTransition
        }
        
        run.status = newStatus
        
        if let location = location {
            run.lastLocation = GeoPoint(latitude: location.latitude, longitude: location.longitude)
            run.lastLocationUpdatedAt = Date()
        }
        
        // Add startTime when run starts
        if newStatus == .activeEnroute && run.startTime == nil {
            run.startTime = Date()
        }
        
        mockRuns[runId] = run
        self.currentRun = run
        
        // Log the event
        await logRunEvent(
            runId: runId,
            type: eventTypeForStatus(newStatus),
            stateBefore: oldStatus,
            stateAfter: newStatus,
            currentStopIndex: run.currentStopIndex,
            location: location.map { GeoPoint(latitude: $0.latitude, longitude: $0.longitude) }
        )
    }
    
    func updateDriverLocation(runId: String, location: CLLocationCoordinate2D) async throws {
        guard var run = mockRuns[runId] else {
            throw FirebaseError.documentNotFound
        }
        
        run.lastLocation = GeoPoint(latitude: location.latitude, longitude: location.longitude)
        run.lastLocationUpdatedAt = Date()
        
        mockRuns[runId] = run
        self.currentRun = run
    }
    
    func updatePassengerStatus(runId: String, passengerId: String, status: PassengerStatus) async throws {
        guard var run = mockRuns[runId] else { return }
        
        // Update passenger status in the run
        if let index = run.passengers.firstIndex(where: { $0.id == passengerId }) {
            run.passengers[index].status = status
            mockRuns[runId] = run
            self.currentRun = run
            
            // Log the event
            let eventType: RunEventType = status == .onboard ? .passengerPickedUp : .passengerDroppedOff
            await logRunEvent(
                runId: runId,
                type: eventType,
                stateBefore: run.status,
                stateAfter: run.status,
                currentStopIndex: run.currentStopIndex,
                note: "\(run.passengers[index].displayName) was \(status.displayName.lowercased())"
            )
        }
    }
    
    // MARK: - State Machine Integration
    
    func processDriverAction(_ action: DriverAction, runId: String, location: CLLocationCoordinate2D? = nil) async throws {
        guard var run = mockRuns[runId] else {
            throw FirebaseError.documentNotFound
        }
        
        let result = RunStateMachine.processDriverAction(action, for: &run)
        
        switch result {
        case .success(let eventType):
            // Update location if provided
            if let location = location {
                run.lastLocation = GeoPoint(latitude: location.latitude, longitude: location.longitude)
                run.lastLocationUpdatedAt = Date()
            }
            
            mockRuns[runId] = run
            self.currentRun = run
            
            // Log the event
            await logRunEvent(
                runId: runId,
                type: eventType,
                stateBefore: nil, // Will be set by the state machine
                stateAfter: run.status,
                currentStopIndex: run.currentStopIndex,
                location: location.map { GeoPoint(latitude: $0.latitude, longitude: $0.longitude) }
            )
            
        case .failure(let error):
            throw FirebaseError.stateTransitionFailed(error.localizedDescription)
        }
    }
    
    func processAdminAction(_ action: AdminAction, runId: String) async throws {
        guard var run = mockRuns[runId] else {
            throw FirebaseError.documentNotFound
        }
        
        let result = RunStateMachine.processAdminAction(action, for: &run)
        
        switch result {
        case .success(let eventType):
            mockRuns[runId] = run
            self.currentRun = run
            
            // Log the event
            await logRunEvent(
                runId: runId,
                type: eventType,
                stateBefore: nil,
                stateAfter: run.status,
                currentStopIndex: run.currentStopIndex
            )
            
        case .failure(let error):
            throw FirebaseError.stateTransitionFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Event Logging
    
    func listenToRunEvents(runId: String) {
        // Simulate real-time event updates
        Task {
            while true {
                if let events = mockEvents[runId] {
                    await MainActor.run {
                        self.runEvents = events.sorted { $0.timestamp < $1.timestamp }
                    }
                }
                try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            }
        }
    }
    
    private func logRunEvent(
        runId: String,
        type: RunEventType,
        stateBefore: RunStatus?,
        stateAfter: RunStatus,
        currentStopIndex: Int,
        location: GeoPoint? = nil,
        note: String? = nil
    ) async {
        let event = RunEvent(
            runId: runId,
            type: type,
            actorId: "current_user",
            stateBefore: stateBefore,
            stateAfter: stateAfter,
            currentStopIndex: currentStopIndex,
            location: location,
            note: note
        )
        
        if mockEvents[runId] == nil {
            mockEvents[runId] = []
        }
        mockEvents[runId]?.append(event)
        
        // Update published events
        self.runEvents = mockEvents[runId]?.sorted { $0.timestamp < $1.timestamp } ?? []
    }
    
    private func eventTypeForStatus(_ status: RunStatus) -> RunEventType {
        switch status {
        case .activeEnroute: return .runStarted
        case .arrivedAtStop: return .runArrivedStop
        case .completed: return .runCompleted
        case .cancelled: return .runCancelled
        case .paused: return .runPaused
        default: return .locationUpdated
        }
    }
    
    // MARK: - Active Run Management
    
    /// Get current active run for a family
    func getCurrentActiveRun(for familyId: String) async throws -> Run? {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Find active runs for the family
        let activeRuns = mockRuns.values.filter { run in
            run.familyId == familyId && run.status.isActive
        }
        
        // Return the most recent active run
        return activeRuns.sorted { $0.scheduledTime > $1.scheduledTime }.first
    }
    
    /// Get all active runs for a family
    func getActiveRuns(for familyId: String) async throws -> [Run] {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        return mockRuns.values.filter { run in
            run.familyId == familyId && run.status.isActive
        }.sorted { $0.scheduledTime < $1.scheduledTime }
    }
    
    // MARK: - Demo Data
    
    func createDemoRun() async throws -> Run {
        let demoRun = Run(
            title: "School Pickup",
            scheduledTime: Date().addingTimeInterval(300), // 5 minutes from now
            driverId: "demo_driver",
            stops: [
                RunStop(
                    type: .pickup,
                    label: "St Davids School",
                    scheduledTime: Date().addingTimeInterval(600),
                    requiredPassengerIds: ["demo_child1", "demo_child2"],
                    location: LocationData(latitude: -17.8252, longitude: 31.0335, address: "St Davids School, Harare")
                ),
                RunStop(
                    type: .dropoff,
                    label: "Home",
                    scheduledTime: Date().addingTimeInterval(1200),
                    requiredPassengerIds: ["demo_child1", "demo_child2"],
                    location: LocationData(latitude: -17.8145, longitude: 31.0493, address: "123 Main Street, Harare")
                )
            ],
            passengers: [
                MemberSummary(id: "demo_child1", displayName: "Emma", role: .passenger),
                MemberSummary(id: "demo_child2", displayName: "Liam", role: .passenger)
            ],
            createdBy: "demo_parent",
            familyId: "demo_family"
        )
        
        mockRuns[demoRun.id] = demoRun
        
        // Log creation event
        await logRunEvent(
            runId: demoRun.id,
            type: .runCreated,
            stateBefore: nil,
            stateAfter: .scheduled,
            currentStopIndex: 0
        )
        
        return demoRun
    }
    
    // MARK: - Cleanup
    
    func stopListening() {
        // Mock implementation - no actual listeners to stop
    }
}

enum FirebaseError: LocalizedError {
    case documentNotFound
    case invalidData
    case networkError
    case invalidTransition
    case stateTransitionFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .documentNotFound:
            return "Document not found"
        case .invalidData:
            return "Invalid data format"
        case .networkError:
            return "Network connection error"
        case .invalidTransition:
            return "Invalid state transition"
        case .stateTransitionFailed(let message):
            return "State transition failed: \(message)"
        }
    }
}