import Foundation
import SwiftUI

/// Mock CloudKit service for UI/UX prototype with simulated sync operations
@MainActor
class MockCloudKitService: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Current sync status
    @Published var syncStatus: MockSyncStatus = .idle
    
    /// Network connectivity status (always true for prototype)
    @Published private(set) var isNetworkAvailable = true
    
    /// CloudKit availability status (always true for prototype)
    @Published private(set) var isCloudKitAvailable = true
    
    /// Offline mode flag (always false for prototype)
    @Published private(set) var isOfflineMode = false
    
    // MARK: - Mock Sync Timer
    
    private var syncTimer: Timer?
    
    // MARK: - Initialization
    
    init() {
        // Start with idle status
        syncStatus = .idle
    }
    
    deinit {
        syncTimer?.invalidate()
    }
    
    // MARK: - Setup and Configuration
    
    /// Mock initial CloudKit setup - always succeeds
    func performInitialSetup() async throws {
        syncStatus = .syncing
        
        // Simulate setup time
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        syncStatus = .synced
    }
    
    /// Mock custom zone setup - always succeeds
    func setupCustomZone() async throws {
        // Simulate zone creation
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
    }
    
    /// Mock subscription setup - always succeeds
    func setupSubscriptions() async throws {
        // Simulate subscription setup
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
    }
    
    // MARK: - Connectivity Methods
    
    /// Mock network connectivity check - always returns true
    func checkNetworkConnectivity() -> Bool {
        return true
    }
    
    /// Mock CloudKit availability check - always returns true
    func checkCloudKitAvailability() async -> Bool {
        // Simulate brief check
        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        return true
    }
    
    // MARK: - Sync Operations
    
    /// Mock sync family to CloudKit
    func syncFamily(_ family: Family) async -> Result<Void, MockCloudKitError> {
        syncStatus = .syncing
        
        // Simulate sync time
        try? await Task.sleep(nanoseconds: 800_000_000) // 0.8 seconds
        
        // Always succeed for prototype
        syncStatus = .synced
        return .success(())
    }
    
    /// Mock sync user profile to CloudKit
    func syncUserProfile(_ userProfile: UserProfile) async -> Result<Void, MockCloudKitError> {
        syncStatus = .syncing
        
        // Simulate sync time
        try? await Task.sleep(nanoseconds: 600_000_000) // 0.6 seconds
        
        // Always succeed for prototype
        syncStatus = .synced
        return .success(())
    }
    
    /// Mock sync membership to CloudKit
    func syncMembership(_ membership: Membership) async -> Result<Void, MockCloudKitError> {
        syncStatus = .syncing
        
        // Simulate sync time
        try? await Task.sleep(nanoseconds: 700_000_000) // 0.7 seconds
        
        // Always succeed for prototype
        syncStatus = .synced
        return .success(())
    }
    
    /// Mock full sync operation
    func performFullSync() async -> Result<Void, MockCloudKitError> {
        syncStatus = .syncing
        
        // Simulate comprehensive sync
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        // Always succeed for prototype
        syncStatus = .synced
        return .success(())
    }
    
    // MARK: - QR Code Generation
    
    /// Mock QR code generation for family
    func generateQRCode(for family: Family) -> String {
        // Return a realistic-looking mock QR code data
        return "TRIBEBOARD://join/\(family.code)?family=\(family.id.uuidString.prefix(8))"
    }
    
    /// Mock QR code validation
    func validateQRCode(_ qrCodeData: String) -> Bool {
        // Simple validation for demo purposes
        return qrCodeData.hasPrefix("TRIBEBOARD://join/")
    }
    
    /// Mock extract family code from QR data
    func extractFamilyCode(from qrCodeData: String) -> String? {
        // Extract code from mock QR format
        if let range = qrCodeData.range(of: "TRIBEBOARD://join/") {
            let afterPrefix = String(qrCodeData[range.upperBound...])
            if let questionMarkIndex = afterPrefix.firstIndex(of: "?") {
                return String(afterPrefix[..<questionMarkIndex])
            } else {
                return afterPrefix
            }
        }
        return nil
    }
    
    // MARK: - Save Operations
    
    /// Mock save CloudKit syncable record - always succeeds
    func save<T: CloudKitSyncable>(_ record: T) async throws {
        syncStatus = .syncing
        
        // Simulate save time
        try await Task.sleep(nanoseconds: 600_000_000) // 0.6 seconds
        
        // Always succeed for prototype
        syncStatus = .synced
    }
    
    /// Mock save multiple records
    func saveRecords<T: CloudKitSyncable>(_ records: [T]) async throws {
        syncStatus = .syncing
        
        // Simulate batch save time
        try await Task.sleep(nanoseconds: 800_000_000) // 0.8 seconds
        
        // Always succeed for prototype
        syncStatus = .synced
    }
    
    // MARK: - Fetch Operations
    
    /// Mock fetch family by code from CloudKit
    func fetchFamily(byCode code: String) async throws -> MockCloudKitRecord? {
        // Simulate network fetch
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Return mock record for demo family code
        if code == "TRIBE123" {
            return MockCloudKitRecord(
                id: "mock_family_record_id",
                recordType: "Family",
                fields: [
                    "name": "Mawere Family",
                    "code": "TRIBE123",
                    "createdByUserId": "mock_user_id"
                ]
            )
        }
        
        return nil
    }
    
    /// Mock fetch user profile by Apple ID hash
    func fetchUserProfile(byAppleUserIdHash hash: String) async throws -> MockCloudKitRecord? {
        // Simulate network fetch
        try await Task.sleep(nanoseconds: 400_000_000) // 0.4 seconds
        
        // Return mock record for known hashes
        let knownHashes = [
            "mock_parent_hash_001": ("Sarah Mawere", "mock_parent_record_id"),
            "mock_child_hash_002": ("Alex Mawere", "mock_child_record_id"),
            "mock_guardian_hash_003": ("John Mawere", "mock_guardian_record_id")
        ]
        
        if let (displayName, recordId) = knownHashes[hash] {
            return MockCloudKitRecord(
                id: recordId,
                recordType: "UserProfile",
                fields: [
                    "displayName": displayName,
                    "appleUserIdHash": hash
                ]
            )
        }
        
        return nil
    }
    
    /// Mock fetch memberships for family
    func fetchMemberships(forFamilyId familyId: String) async throws -> [MockCloudKitRecord] {
        // Simulate network fetch
        try await Task.sleep(nanoseconds: 600_000_000) // 0.6 seconds
        
        // Return mock membership records
        return [
            MockCloudKitRecord(
                id: "mock_membership_1",
                recordType: "Membership",
                fields: [
                    "familyId": familyId,
                    "userId": "mock_parent_record_id",
                    "role": "parentAdmin",
                    "status": "active"
                ]
            ),
            MockCloudKitRecord(
                id: "mock_membership_2",
                recordType: "Membership",
                fields: [
                    "familyId": familyId,
                    "userId": "mock_child_record_id",
                    "role": "child",
                    "status": "active"
                ]
            )
        ]
    }
    
    /// Mock fetch active memberships for family
    func fetchActiveMemberships(forFamilyId familyId: String) async throws -> [MockCloudKitRecord] {
        let allMemberships = try await fetchMemberships(forFamilyId: familyId)
        return allMemberships.filter { record in
            if let status = record.fields["status"] as? String {
                return status == "active"
            }
            return false
        }
    }
    
    // MARK: - Periodic Sync Simulation
    
    /// Start periodic sync simulation for demo purposes
    func startPeriodicSyncSimulation() {
        syncTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.simulateBackgroundSync()
            }
        }
    }
    
    /// Stop periodic sync simulation
    func stopPeriodicSyncSimulation() {
        syncTimer?.invalidate()
        syncTimer = nil
    }
    
    /// Simulate background sync activity
    private func simulateBackgroundSync() async {
        let _ = syncStatus
        syncStatus = .syncing
        
        // Simulate brief sync
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        syncStatus = .synced
        
        // Occasionally simulate sync conflicts or errors for demo
        if Int.random(in: 1...20) == 1 { // 5% chance
            syncStatus = .error("Mock sync conflict resolved")
            
            // Auto-resolve after a moment
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.syncStatus = .synced
            }
        }
    }
    
    // MARK: - Error Simulation
    
    /// Simulate network error for demo purposes
    func simulateNetworkError() {
        syncStatus = .error("Network connection lost")
        
        // Auto-recover after a moment
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            self.syncStatus = .synced
        }
    }
    
    /// Simulate sync conflict for demo purposes
    func simulateSyncConflict() {
        syncStatus = .error("Sync conflict detected - resolving...")
        
        // Auto-resolve after a moment
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.syncStatus = .synced
        }
    }
}

// MARK: - Mock Data Structures

/// Mock sync status for prototype
enum MockSyncStatus: Equatable {
    case idle
    case syncing
    case synced
    case error(String)
    
    var displayText: String {
        switch self {
        case .idle:
            return "Ready"
        case .syncing:
            return "Syncing..."
        case .synced:
            return "Synced"
        case .error(let message):
            return "Error: \(message)"
        }
    }
    
    var isError: Bool {
        if case .error = self {
            return true
        }
        return false
    }
}

/// Mock CloudKit error for prototype
enum MockCloudKitError: LocalizedError {
    case networkUnavailable
    case quotaExceeded
    case recordNotFound
    case conflictResolution
    case invalidRecord
    case syncFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .networkUnavailable:
            return "Network unavailable"
        case .quotaExceeded:
            return "CloudKit quota exceeded"
        case .recordNotFound:
            return "Record not found"
        case .conflictResolution:
            return "Conflict resolution failed"
        case .invalidRecord:
            return "Invalid record format"
        case .syncFailed(let message):
            return "Sync failed: \(message)"
        }
    }
}

/// Mock CloudKit record for prototype
struct MockCloudKitRecord {
    let id: String
    let recordType: String
    let fields: [String: Any]
    let creationDate: Date
    let modificationDate: Date
    
    init(id: String, recordType: String, fields: [String: Any]) {
        self.id = id
        self.recordType = recordType
        self.fields = fields
        self.creationDate = Date()
        self.modificationDate = Date()
    }
}