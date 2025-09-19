import Foundation
import CloudKit

/// Utility for validating CloudKit schema setup
class CloudKitSchemaValidator {
    
    private let cloudKitService: CloudKitService
    
    init(cloudKitService: CloudKitService) {
        self.cloudKitService = cloudKitService
    }
    
    /// Validates the complete CloudKit schema setup
    func validateSchema() async -> SchemaValidationResult {
        var issues: [SchemaIssue] = []
        
        // Check CloudKit availability
        do {
            let isAvailable = try await cloudKitService.verifyCloudKitAvailability()
            if !isAvailable {
                issues.append(.cloudKitUnavailable)
                return SchemaValidationResult(isValid: false, issues: issues)
            }
        } catch {
            issues.append(.cloudKitError(error))
            return SchemaValidationResult(isValid: false, issues: issues)
        }
        
        // Validate record types
        await validateRecordTypes(&issues)
        
        // Validate subscriptions
        await validateSubscriptions(&issues)
        
        // Validate custom zone
        await validateCustomZone(&issues)
        
        let isValid = issues.isEmpty
        return SchemaValidationResult(isValid: isValid, issues: issues)
    }
    
    // MARK: - Private Validation Methods
    
    private func validateRecordTypes(_ issues: inout [SchemaIssue]) async {
        // Test Family record type
        do {
            _ = try await cloudKitService.fetch(Family.self, predicate: NSPredicate(value: true))
        } catch let error as CKError {
            if error.code == .unknownItem {
                issues.append(SchemaIssue.missingRecordType(CKRecordType.family))
            } else {
                issues.append(SchemaIssue.recordTypeValidationError(CKRecordType.family, error))
            }
        } catch {
            issues.append(SchemaIssue.recordTypeValidationError(CKRecordType.family, error))
        }
        
        // Test UserProfile record type
        do {
            _ = try await cloudKitService.fetch(UserProfile.self, predicate: NSPredicate(value: true))
        } catch let error as CKError {
            if error.code == .unknownItem {
                issues.append(SchemaIssue.missingRecordType(CKRecordType.userProfile))
            } else {
                issues.append(SchemaIssue.recordTypeValidationError(CKRecordType.userProfile, error))
            }
        } catch {
            issues.append(SchemaIssue.recordTypeValidationError(CKRecordType.userProfile, error))
        }
        
        // Test Membership record type
        do {
            _ = try await cloudKitService.fetch(Membership.self, predicate: NSPredicate(value: true))
        } catch let error as CKError {
            if error.code == .unknownItem {
                issues.append(SchemaIssue.missingRecordType(CKRecordType.membership))
            } else {
                issues.append(SchemaIssue.recordTypeValidationError(CKRecordType.membership, error))
            }
        } catch {
            issues.append(SchemaIssue.recordTypeValidationError(CKRecordType.membership, error))
        }
    }
    
    private func validateSubscriptions(_ issues: inout [SchemaIssue]) async {
        let requiredSubscriptions = [
            "family-changes",
            "membership-changes",
            "userprofile-changes"
        ]
        
        do {
            let existingSubscriptions = try await cloudKitService.privateDatabase.allSubscriptions()
            let existingIDs = Set(existingSubscriptions.map { $0.subscriptionID })
            
            for requiredID in requiredSubscriptions {
                if !existingIDs.contains(requiredID) {
                    issues.append(.missingSubscription(requiredID))
                }
            }
        } catch {
            issues.append(.subscriptionValidationError(error))
        }
    }
    
    private func validateCustomZone(_ issues: inout [SchemaIssue]) async {
        do {
            let zones = try await cloudKitService.privateDatabase.allRecordZones()
            let hasCustomZone = zones.contains { $0.zoneID.zoneName == "TribeBoardZone" }
            
            if !hasCustomZone {
                issues.append(.missingCustomZone)
            }
        } catch {
            issues.append(.customZoneValidationError(error))
        }
    }
}

// MARK: - Validation Result Types

struct SchemaValidationResult {
    let isValid: Bool
    let issues: [SchemaIssue]
    
    var summary: String {
        if isValid {
            return "✅ CloudKit schema is properly configured"
        } else {
            let issueDescriptions = issues.map { "• \($0.description)" }.joined(separator: "\n")
            return "❌ CloudKit schema has issues:\n\(issueDescriptions)"
        }
    }
}

enum SchemaIssue {
    case cloudKitUnavailable
    case cloudKitError(Error)
    case missingRecordType(String)
    case recordTypeValidationError(String, Error)
    case missingSubscription(String)
    case subscriptionValidationError(Error)
    case missingCustomZone
    case customZoneValidationError(Error)
    
    var description: String {
        switch self {
        case .cloudKitUnavailable:
            return "CloudKit is not available. Check iCloud account status."
        case .cloudKitError(let error):
            return "CloudKit error: \(error.localizedDescription)"
        case .missingRecordType(let type):
            return "Missing record type: \(type). Create it in CloudKit Console."
        case .recordTypeValidationError(let type, let error):
            return "Error validating record type \(type): \(error.localizedDescription)"
        case .missingSubscription(let id):
            return "Missing subscription: \(id). Run setupSubscriptions() to create it."
        case .subscriptionValidationError(let error):
            return "Error validating subscriptions: \(error.localizedDescription)"
        case .missingCustomZone:
            return "Missing custom zone 'TribeBoardZone'. Run setupCustomZone() to create it."
        case .customZoneValidationError(let error):
            return "Error validating custom zone: \(error.localizedDescription)"
        }
    }
}

// MARK: - CloudKitService Extension for Validation

extension CloudKitService {
    /// Validates the CloudKit schema and returns a detailed report
    func validateSchema() async -> SchemaValidationResult {
        let validator = CloudKitSchemaValidator(cloudKitService: self)
        return await validator.validateSchema()
    }
    
    /// Prints a schema validation report to the console
    func printSchemaValidationReport() async {
        let result = await validateSchema()
        print("CloudKit Schema Validation Report:")
        print(result.summary)
    }
}