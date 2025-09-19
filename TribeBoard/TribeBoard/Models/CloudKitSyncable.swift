import Foundation
import CloudKit

/// Protocol for models that can be synchronized with CloudKit
protocol CloudKitSyncable {
    /// The CloudKit record ID
    var ckRecordID: String? { get set }
    
    /// The last sync date with CloudKit
    var lastSyncDate: Date? { get set }
    
    /// Flag indicating if the record needs to be synced
    var needsSync: Bool { get set }
    
    /// The unique identifier for the record
    var id: UUID { get }
    
    /// Converts the model to a CloudKit record
    func toCKRecord() throws -> CKRecord
    
    /// Updates the model from a CloudKit record
    func updateFromCKRecord(_ record: CKRecord) throws
    
    /// The CloudKit record type name
    static var recordType: String { get }
}

/// Default implementations for CloudKit synchronization
extension CloudKitSyncable {
    
    /// Marks the record as needing sync
    mutating func markForSync() {
        needsSync = true
    }
    
    /// Marks the record as synced
    mutating func markAsSynced(recordID: String) {
        ckRecordID = recordID
        lastSyncDate = Date()
        needsSync = false
    }
    
    /// Checks if the record needs to be synced
    var requiresSync: Bool {
        needsSync || ckRecordID == nil
    }
}

