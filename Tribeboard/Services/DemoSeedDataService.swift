//
//  DemoSeedDataService.swift
//  Tribeboard
//
//  Created by Kiro on 2026/02/05.
//

#if DEBUG
import Foundation
import CoreLocation

/// Service for seeding demo data in DEBUG builds
/// Creates a demo family with users and scheduled runs for testing
@MainActor
class DemoSeedDataService {
    
    // MARK: - Constants
    
    static let demoFamilyId = "demo-family-tribeboard"
    
    // Demo user IDs
    static let rueId = "demo-rue"
    static let tafadzwaId = "demo-tafadzwa"
    static let tjId = "demo-tj"
    static let tawanaId = "demo-tawana"
    
    // MARK: - Properties
    
    private let firebaseService: MockFirebaseRunService
    private var hasSeeded = false
    
    // MARK: - Initialization
    
    init(firebaseService: MockFirebaseRunService) {
        self.firebaseService = firebaseService
    }
    
    // MARK: - Public Methods
    
    /// Seed demo data if not already seeded
    func seedIfNeeded() async {
        guard !hasSeeded else { return }
        
        print("🌱 Seeding demo data...")
        
        do {
            // Create demo users
            let users = createDemoUsers()
            try await persistDemoUsers(users)
            
            // Create demo runs
            let runs = createDemoRuns()
            try await persistDemoRuns(runs)
            
            hasSeeded = true
            print("✅ Demo data seeded successfully")
            print("   - Family ID: \(DemoSeedDataService.demoFamilyId)")
            print("   - Users: Rue (parent), Tafadzwa (parent), TJ (child), Tawana (child)")
            print("   - Runs: 2 scheduled runs created")
        } catch {
            print("❌ Failed to seed demo data: \(error.localizedDescription)")
        }
    }
    
    /// Seed demo family with Mawere family members
    /// Idempotent - checks if family exists before creating
    /// Requirements: 2.1, 2.2, 2.3
    func seedDemoFamily() async {
        print("🌱 Seeding demo family...")
        
        do {
            // Check if demo family already exists (idempotency)
            if let existingFamily = try await firebaseService.getFamily(familyId: DemoSeedDataService.demoFamilyId) {
                print("ℹ️ Demo family already exists, skipping seed")
                print("   - Family ID: \(DemoSeedDataService.demoFamilyId)")
                print("   - Members: \(existingFamily.count)")
                return
            }
            
            // Create demo family members
            let users = createDemoFamilyUsers()
            try await persistDemoUsers(users)
            
            // Create ONE scheduled demo run if no runs exist
            let existingRuns = try await firebaseService.listRuns(forFamilyId: DemoSeedDataService.demoFamilyId)
            if existingRuns.isEmpty {
                let demoRun = createInitialDemoRun()
                try await persistDemoRuns([demoRun])
                print("   - Created 1 scheduled demo run")
            } else {
                print("   - Runs already exist, skipping run creation")
            }
            
            print("✅ Demo family seeded successfully")
            print("   - Family ID: \(DemoSeedDataService.demoFamilyId)")
            print("   - Rue Mawere: Parent/Admin/Observer (+1-555-0101)")
            print("   - Tafadzwa Mawere: Parent/Admin/Driver (+1-555-0102)")
            print("   - TJ: Child/Passenger")
            print("   - Tawana: Child/Passenger")
        } catch {
            print("❌ Failed to seed demo family: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Private Methods - User Creation
    
    private func createDemoUsers() -> [User] {
        return [
            User(
                id: DemoSeedDataService.rueId,
                displayName: "Rue",
                role: .admin,
                familyId: DemoSeedDataService.demoFamilyId
            ),
            User(
                id: DemoSeedDataService.tafadzwaId,
                displayName: "Tafadzwa",
                role: .admin,
                familyId: DemoSeedDataService.demoFamilyId
            ),
            User(
                id: DemoSeedDataService.tjId,
                displayName: "TJ",
                role: .observer,
                familyId: DemoSeedDataService.demoFamilyId
            ),
            User(
                id: DemoSeedDataService.tawanaId,
                displayName: "Tawana",
                role: .observer,
                familyId: DemoSeedDataService.demoFamilyId
            )
        ]
    }
    
    /// Create demo family users with proper roles
    /// Requirements: 2.1, 2.2, 2.3
    private func createDemoFamilyUsers() -> [User] {
        return [
            // Rue Mawere: Parent/Admin/Observer with phone
            User(
                id: DemoSeedDataService.rueId,
                displayName: "Rue Mawere",
                role: .observer, // Primary role: Observer
                familyId: DemoSeedDataService.demoFamilyId
            ),
            // Tafadzwa Mawere: Parent/Admin/Driver with phone
            User(
                id: DemoSeedDataService.tafadzwaId,
                displayName: "Tafadzwa Mawere",
                role: .driver, // Primary role: Driver
                familyId: DemoSeedDataService.demoFamilyId
            ),
            // TJ: Child/Passenger
            User(
                id: DemoSeedDataService.tjId,
                displayName: "TJ",
                role: .observer, // Children use observer role for passenger functionality
                familyId: DemoSeedDataService.demoFamilyId
            ),
            // Tawana: Child/Passenger
            User(
                id: DemoSeedDataService.tawanaId,
                displayName: "Tawana",
                role: .observer, // Children use observer role for passenger functionality
                familyId: DemoSeedDataService.demoFamilyId
            )
        ]
    }
    
    private func persistDemoUsers(_ users: [User]) async throws {
        // Store users in MockFirebaseService
        for user in users {
            try await firebaseService.upsertUser(user)
        }
        
        // Create family with members
        let memberIds = users.map { $0.id }
        try await firebaseService.upsertFamily(
            id: DemoSeedDataService.demoFamilyId,
            members: memberIds
        )
    }
    
    // MARK: - Private Methods - Run Creation
    
    /// Create initial demo run for first launch
    /// Requirements: 2.7
    private func createInitialDemoRun() -> Run {
        let now = Date()
        
        // Create ONE scheduled run: Rue creates, Tafadzwa drives, TJ+Tawana passengers, 3 stops
        return Run(
            title: "School Pickup",
            scheduledTime: now.addingTimeInterval(30 * 60), // 30 minutes from now
            driverId: DemoSeedDataService.tafadzwaId, // Tafadzwa is the driver
            status: .scheduled,
            stops: [
                // Stop 1: Pickup at school
                RunStop(
                    type: .pickup,
                    label: "St Davids School",
                    scheduledTime: now.addingTimeInterval(35 * 60),
                    requiredPassengerIds: [DemoSeedDataService.tjId, DemoSeedDataService.tawanaId],
                    location: LocationData(
                        latitude: -17.8252,
                        longitude: 31.0335,
                        address: "St Davids School, Harare"
                    )
                ),
                // Stop 2: Waypoint at grocery store
                RunStop(
                    type: .waypoint,
                    label: "Grocery Store",
                    scheduledTime: now.addingTimeInterval(45 * 60),
                    requiredPassengerIds: [],
                    location: LocationData(
                        latitude: -17.8200,
                        longitude: 31.0400,
                        address: "Pick n Pay, Harare"
                    )
                ),
                // Stop 3: Dropoff at home
                RunStop(
                    type: .dropoff,
                    label: "Home",
                    scheduledTime: now.addingTimeInterval(55 * 60),
                    requiredPassengerIds: [DemoSeedDataService.tjId, DemoSeedDataService.tawanaId],
                    location: LocationData(
                        latitude: -17.8145,
                        longitude: 31.0493,
                        address: "123 Main Street, Harare"
                    )
                )
            ],
            passengers: [
                MemberSummary(
                    id: DemoSeedDataService.tjId,
                    displayName: "TJ",
                    role: .passenger,
                    status: .waiting
                ),
                MemberSummary(
                    id: DemoSeedDataService.tawanaId,
                    displayName: "Tawana",
                    role: .passenger,
                    status: .waiting
                )
            ],
            createdBy: DemoSeedDataService.rueId, // Rue creates the run
            familyId: DemoSeedDataService.demoFamilyId,
            currentStopIndex: 0
        )
    }
    
    private func createDemoRuns() -> [Run] {
        let now = Date()
        
        // Run A: School Pickup - TJ (Driver: Tafadzwa)
        let runA = Run(
            title: "School Pickup - TJ",
            scheduledTime: now.addingTimeInterval(30 * 60), // 30 minutes from now
            driverId: DemoSeedDataService.tafadzwaId,
            status: .scheduled,
            stops: [
                RunStop(
                    type: .pickup,
                    label: "St Davids School",
                    scheduledTime: now.addingTimeInterval(35 * 60),
                    requiredPassengerIds: [DemoSeedDataService.tjId],
                    location: LocationData(
                        latitude: -17.8252,
                        longitude: 31.0335,
                        address: "St Davids School, Harare"
                    )
                ),
                RunStop(
                    type: .waypoint,
                    label: "Grocery Store",
                    scheduledTime: now.addingTimeInterval(45 * 60),
                    requiredPassengerIds: [],
                    location: LocationData(
                        latitude: -17.8200,
                        longitude: 31.0400,
                        address: "Pick n Pay, Harare"
                    )
                ),
                RunStop(
                    type: .dropoff,
                    label: "Home",
                    scheduledTime: now.addingTimeInterval(55 * 60),
                    requiredPassengerIds: [DemoSeedDataService.tjId],
                    location: LocationData(
                        latitude: -17.8145,
                        longitude: 31.0493,
                        address: "123 Main Street, Harare"
                    )
                )
            ],
            passengers: [
                MemberSummary(
                    id: DemoSeedDataService.tjId,
                    displayName: "TJ",
                    role: .passenger,
                    status: .waiting
                )
            ],
            createdBy: DemoSeedDataService.tafadzwaId,
            familyId: DemoSeedDataService.demoFamilyId,
            currentStopIndex: 0
        )
        
        // Run B: Aftercare - Tawana (Driver: Rue)
        let runB = Run(
            title: "Aftercare - Tawana",
            scheduledTime: now.addingTimeInterval(2 * 60 * 60), // 2 hours from now
            driverId: DemoSeedDataService.rueId,
            status: .scheduled,
            stops: [
                RunStop(
                    type: .pickup,
                    label: "Aftercare Center",
                    scheduledTime: now.addingTimeInterval(2 * 60 * 60 + 10 * 60),
                    requiredPassengerIds: [DemoSeedDataService.tawanaId],
                    location: LocationData(
                        latitude: -17.8100,
                        longitude: 31.0450,
                        address: "Sunshine Aftercare, Harare"
                    )
                ),
                RunStop(
                    type: .waypoint,
                    label: "Park",
                    scheduledTime: now.addingTimeInterval(2 * 60 * 60 + 20 * 60),
                    requiredPassengerIds: [],
                    location: LocationData(
                        latitude: -17.8050,
                        longitude: 31.0500,
                        address: "Central Park, Harare"
                    )
                ),
                RunStop(
                    type: .dropoff,
                    label: "Home",
                    scheduledTime: now.addingTimeInterval(2 * 60 * 60 + 30 * 60),
                    requiredPassengerIds: [DemoSeedDataService.tawanaId],
                    location: LocationData(
                        latitude: -17.8145,
                        longitude: 31.0493,
                        address: "123 Main Street, Harare"
                    )
                )
            ],
            passengers: [
                MemberSummary(
                    id: DemoSeedDataService.tawanaId,
                    displayName: "Tawana",
                    role: .passenger,
                    status: .waiting
                )
            ],
            createdBy: DemoSeedDataService.rueId,
            familyId: DemoSeedDataService.demoFamilyId,
            currentStopIndex: 0
        )
        
        return [runA, runB]
    }
    
    private func persistDemoRuns(_ runs: [Run]) async throws {
        for run in runs {
            _ = try await firebaseService.upsertRun(run)
        }
    }
}
#endif
