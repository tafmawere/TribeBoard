import Foundation
import SwiftData
import CloudKit

/// SwiftData model for Family with CloudKit sync capabilities
@Model
final class Family {
    // Primary identifier
    var id: UUID = UUID()
    
    // Core properties - with default values for CloudKit compatibility
    var name: String = ""
    var code: String = ""
    var createdByUserId: UUID = UUID()
    var createdAt: Date = Date()
    
    // CloudKit sync properties
    var ckRecordID: String?
    var lastSyncDate: Date?
    var needsSync: Bool = true
    
    // Relationships - optional for CloudKit compatibility
    @Relationship(deleteRule: .cascade, inverse: \Membership.family)
    var memberships: [Membership]?
    
    init(name: String, code: String, createdByUserId: UUID) {
        self.id = UUID()
        self.name = name
        self.code = code
        self.createdByUserId = createdByUserId
        self.createdAt = Date()
        self.needsSync = true
        self.memberships = []
    }
    
    // MARK: - Validation
    
    /// Validates the family name
    var isNameValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        name.count >= 2 &&
        name.count <= 50
    }
    
    /// Validates the family code format (6-8 character alphanumeric)
    var isCodeValid: Bool {
        code.count >= 6 &&
        code.count <= 8 &&
        code.allSatisfy { $0.isLetter || $0.isNumber } &&
        !code.isEmpty
    }
    
    /// Validates all family properties
    var isFullyValid: Bool {
        isNameValid && isCodeValid && !createdByUserId.uuidString.isEmpty
    }
    
    /// Returns active memberships only
    var activeMembers: [Membership] {
        memberships?.filter { $0.status == .active } ?? []
    }
    
    /// Returns the parent admin membership if exists
    var parentAdmin: Membership? {
        memberships?.first { $0.role == .parentAdmin && $0.status == .active }
    }
    
    /// Checks if a parent admin exists
    var hasParentAdmin: Bool {
        parentAdmin != nil
    }
    
    /// Marks the record as synced
    func markAsSynced(recordID: String) {
        ckRecordID = recordID
        lastSyncDate = Date()
        needsSync = false
    }
}

// MARK: - CloudKit Synchronization
extension Family: CloudKitSyncable {
    static var recordType: String { CKRecordType.family }
    
    func toCKRecord() throws -> CKRecord {
        let recordID = CKRecord.ID(recordName: id.uuidString)
        let record = CKRecord(recordType: Self.recordType, recordID: recordID)
        
        record[CKFieldName.familyName] = name
        record[CKFieldName.familyCode] = code
        record[CKFieldName.familyCreatedByUserId] = createdByUserId.uuidString
        record[CKFieldName.familyCreatedAt] = createdAt
        
        return record
    }
    
    func updateFromCKRecord(_ record: CKRecord) throws {
        guard let name = record[CKFieldName.familyName] as? String,
              let code = record[CKFieldName.familyCode] as? String,
              let createdByUserIdString = record[CKFieldName.familyCreatedByUserId] as? String,
              let createdByUserId = UUID(uuidString: createdByUserIdString),
              let createdAt = record[CKFieldName.familyCreatedAt] as? Date else {
            throw CloudKitSyncError.invalidRecord
        }
        
        self.name = name
        self.code = code
        self.createdByUserId = createdByUserId
        self.createdAt = createdAt
        self.ckRecordID = record.recordID.recordName
        self.lastSyncDate = Date()
        self.needsSync = false
    }
}

/// CloudKit synchronization errors
enum CloudKitSyncError: LocalizedError {
    case invalidRecord
    case missingRequiredField(String)
    case conversionFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidRecord:
            return "Invalid CloudKit record format"
        case .missingRequiredField(let field):
            return "Missing required field: \(field)"
        case .conversionFailed:
            return "Failed to convert data types"
        }
    }
}