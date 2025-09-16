import Foundation
import SwiftData

/// Errors that can occur in DataService operations
enum DataServiceError: LocalizedError {
    case validationFailed([String])
    case invalidData(String)
    case notFound(String)
    case constraintViolation(String)
    
    var errorDescription: String? {
        switch self {
        case .validationFailed(let errors):
            return "Validation failed: \(errors.joined(separator: ", "))"
        case .invalidData(let message):
            return "Invalid data: \(message)"
        case .notFound(let message):
            return "Not found: \(message)"
        case .constraintViolation(let message):
            return "Constraint violation: \(message)"
        }
    }
}

/// Service for managing SwiftData operations
@MainActor
class DataService: ObservableObject {
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - Family Operations
    
    /// Creates a new family with validation
    func createFamily(name: String, code: String, createdByUserId: UUID) throws -> Family {
        // Validate before creation
        let validationResult = try validateFamily(name: name, code: code)
        if !validationResult.isValid {
            throw DataServiceError.validationFailed(validationResult.errors)
        }
        
        let family = Family(name: name, code: code, createdByUserId: createdByUserId)
        
        // Ensure the family is valid
        guard family.isFullyValid else {
            throw DataServiceError.invalidData("Family data is invalid")
        }
        
        modelContext.insert(family)
        try modelContext.save()
        return family
    }
    
    /// Fetches a family by code
    func fetchFamily(byCode code: String) throws -> Family? {
        let descriptor = FetchDescriptor<Family>(
            predicate: #Predicate { $0.code == code }
        )
        return try modelContext.fetch(descriptor).first
    }
    
    /// Fetches all families
    func fetchAllFamilies() throws -> [Family] {
        let descriptor = FetchDescriptor<Family>()
        return try modelContext.fetch(descriptor)
    }
    
    /// Checks if a family code exists
    func familyCodeExists(_ code: String) throws -> Bool {
        return try fetchFamily(byCode: code) != nil
    }
    
    // MARK: - UserProfile Operations
    
    /// Creates a new user profile with validation
    func createUserProfile(displayName: String, appleUserIdHash: String, avatarUrl: URL? = nil) throws -> UserProfile {
        // Validate before creation
        let validationResult = validateUserProfile(displayName: displayName, appleUserIdHash: appleUserIdHash)
        if !validationResult.isValid {
            throw DataServiceError.validationFailed(validationResult.errors)
        }
        
        let userProfile = UserProfile(displayName: displayName, appleUserIdHash: appleUserIdHash, avatarUrl: avatarUrl)
        
        // Ensure the user profile is valid
        guard userProfile.isFullyValid else {
            throw DataServiceError.invalidData("User profile data is invalid")
        }
        
        modelContext.insert(userProfile)
        try modelContext.save()
        return userProfile
    }
    
    /// Fetches a user profile by Apple ID hash
    func fetchUserProfile(byAppleUserIdHash hash: String) throws -> UserProfile? {
        let descriptor = FetchDescriptor<UserProfile>(
            predicate: #Predicate { $0.appleUserIdHash == hash }
        )
        return try modelContext.fetch(descriptor).first
    }
    
    /// Fetches a user profile by ID
    func fetchUserProfile(byId id: UUID) throws -> UserProfile? {
        let descriptor = FetchDescriptor<UserProfile>(
            predicate: #Predicate { $0.id == id }
        )
        return try modelContext.fetch(descriptor).first
    }
    
    // MARK: - Membership Operations
    
    /// Creates a new membership with validation
    func createMembership(family: Family, user: UserProfile, role: Role) throws -> Membership {
        // Check if user is already a member of this family
        let existingMembership = try fetchMemberships(forUser: user)
            .first { $0.family?.id == family.id && $0.status == .active }
        
        if existingMembership != nil {
            throw DataServiceError.constraintViolation("User is already a member of this family")
        }
        
        // Check parent admin constraint
        if role == .parentAdmin && try familyHasParentAdmin(family) {
            throw DataServiceError.constraintViolation("A Parent Admin already exists for this family")
        }
        
        let membership = Membership(family: family, user: user, role: role)
        
        // Ensure the membership is valid
        guard membership.isFullyValid else {
            throw DataServiceError.invalidData("Membership data is invalid")
        }
        
        modelContext.insert(membership)
        try modelContext.save()
        return membership
    }
    
    /// Fetches memberships for a family
    func fetchMemberships(forFamily family: Family) throws -> [Membership] {
        let descriptor = FetchDescriptor<Membership>(
            predicate: #Predicate { $0.family?.id == family.id }
        )
        return try modelContext.fetch(descriptor)
    }
    
    /// Fetches memberships for a user
    func fetchMemberships(forUser user: UserProfile) throws -> [Membership] {
        let descriptor = FetchDescriptor<Membership>(
            predicate: #Predicate { $0.user?.id == user.id }
        )
        return try modelContext.fetch(descriptor)
    }
    
    /// Fetches active memberships for a family
    func fetchActiveMemberships(forFamily family: Family) throws -> [Membership] {
        let descriptor = FetchDescriptor<Membership>(
            predicate: #Predicate { 
                $0.family?.id == family.id && $0.status == MembershipStatus.active 
            }
        )
        return try modelContext.fetch(descriptor)
    }
    
    /// Checks if a family has a parent admin
    func familyHasParentAdmin(_ family: Family) throws -> Bool {
        let descriptor = FetchDescriptor<Membership>(
            predicate: #Predicate { 
                $0.family?.id == family.id && 
                $0.role == Role.parentAdmin && 
                $0.status == MembershipStatus.active 
            }
        )
        return !(try modelContext.fetch(descriptor).isEmpty)
    }
    
    /// Updates a membership role with validation
    func updateMembershipRole(_ membership: Membership, to role: Role) throws {
        // Validate the role change
        let validationResult = try validateRoleChange(membership: membership, newRole: role)
        if !validationResult.isValid {
            throw DataServiceError.validationFailed(validationResult.errors)
        }
        
        membership.updateRole(to: role)
        try modelContext.save()
    }
    
    /// Removes a membership (soft delete)
    func removeMembership(_ membership: Membership) throws {
        membership.remove()
        try modelContext.save()
    }
    
    // MARK: - General Operations
    
    /// Saves the current context
    func save() throws {
        try modelContext.save()
    }
    
    /// Deletes an object
    func delete<T: PersistentModel>(_ object: T) throws {
        modelContext.delete(object)
        try modelContext.save()
    }
    
    /// Fetches records that need CloudKit sync
    func fetchRecordsNeedingSync<T: PersistentModel & CloudKitSyncable>(_ type: T.Type) throws -> [T] {
        let descriptor = FetchDescriptor<T>(
            predicate: #Predicate { $0.needsSync == true }
        )
        return try modelContext.fetch(descriptor)
    }
    
    // MARK: - Validation Operations
    
    /// Validates a family before creation
    func validateFamily(name: String, code: String) throws -> ValidationResult {
        var errors: [String] = []
        
        // Validate name
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty {
            errors.append("Family name cannot be empty")
        } else if trimmedName.count < 2 {
            errors.append("Family name must be at least 2 characters")
        } else if trimmedName.count > 50 {
            errors.append("Family name cannot exceed 50 characters")
        }
        
        // Validate code format
        if code.count < 6 || code.count > 8 {
            errors.append("Family code must be 6-8 characters")
        } else if !code.allSatisfy({ $0.isLetter || $0.isNumber }) {
            errors.append("Family code must be alphanumeric")
        }
        
        // Check code uniqueness
        if try familyCodeExists(code) {
            errors.append("Family code already exists")
        }
        
        return ValidationResult(isValid: errors.isEmpty, errors: errors)
    }
    
    /// Validates a user profile before creation
    func validateUserProfile(displayName: String, appleUserIdHash: String) -> ValidationResult {
        var errors: [String] = []
        
        // Validate display name
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty {
            errors.append("Display name cannot be empty")
        } else if trimmedName.count > 50 {
            errors.append("Display name cannot exceed 50 characters")
        }
        
        // Validate Apple ID hash
        if appleUserIdHash.isEmpty {
            errors.append("Apple ID hash cannot be empty")
        } else if appleUserIdHash.count < 10 {
            errors.append("Invalid Apple ID hash format")
        }
        
        return ValidationResult(isValid: errors.isEmpty, errors: errors)
    }
    
    /// Validates a role change
    func validateRoleChange(membership: Membership, newRole: Role) throws -> ValidationResult {
        var errors: [String] = []
        
        guard let family = membership.family else {
            errors.append("Invalid membership: no family associated")
            return ValidationResult(isValid: false, errors: errors)
        }
        
        // Check if role change is valid
        if !membership.canChangeRole(to: newRole, in: family) {
            if newRole == .parentAdmin && family.hasParentAdmin {
                errors.append("A Parent Admin already exists for this family")
            } else if membership.role == newRole {
                errors.append("Member already has this role")
            }
        }
        
        return ValidationResult(isValid: errors.isEmpty, errors: errors)
    }
    
    // MARK: - Constraint Checking
    
    /// Checks if a user can join a specific family
    func canUserJoinFamily(user: UserProfile, family: Family) throws -> Bool {
        // Check if user is already a member
        let existingMembership = try fetchMemberships(forUser: user)
            .first { $0.family?.id == family.id && $0.status == .active }
        
        return existingMembership == nil
    }
    
    /// Gets the count of active members in a family
    func getActiveMemberCount(for family: Family) throws -> Int {
        return try fetchActiveMemberships(forFamily: family).count
    }
    
    /// Checks if a family code is properly formatted
    func isValidFamilyCodeFormat(_ code: String) -> Bool {
        return code.count >= 6 && 
               code.count <= 8 && 
               code.allSatisfy { $0.isLetter || $0.isNumber } &&
               !code.isEmpty
    }
    
    /// Generates a unique family code (collision-safe)
    func generateUniqueFamilyCode() throws -> String {
        let maxAttempts = 10
        var attempts = 0
        
        while attempts < maxAttempts {
            let code = generateRandomCode()
            if !(try familyCodeExists(code)) {
                return code
            }
            attempts += 1
        }
        
        throw DataServiceError.constraintViolation("Unable to generate unique family code after \(maxAttempts) attempts")
    }
    
    /// Generates a random 6-8 character alphanumeric code
    private func generateRandomCode() -> String {
        let characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        let length = Int.random(in: 6...8)
        return String((0..<length).map { _ in characters.randomElement()! })
    }
}



/// Extension for creating DataService from environment
extension DataService {
    /// Creates a DataService from the current model context
    static func from(modelContext: ModelContext) -> DataService {
        return DataService(modelContext: modelContext)
    }
}