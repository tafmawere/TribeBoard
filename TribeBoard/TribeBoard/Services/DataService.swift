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
        print("🔧 DataService: Initialized with ModelContext")
        
        // Validate ModelContext on initialization
        validateModelContext()
    }
    
    /// Validates that the ModelContext is in a usable state
    private func validateModelContext() {
        print("🔍 DataService: Validating ModelContext state...")
        
        do {
            // Try a simple operation to test if the context is working
            let testDescriptor = FetchDescriptor<Family>()
            _ = try modelContext.fetch(testDescriptor)
            print("✅ DataService: ModelContext validation successful")
        } catch {
            print("❌ DataService: ModelContext validation failed")
            print("   Error: \(error.localizedDescription)")
            print("   ⚠️ This may cause issues with data operations")
        }
    }
    
    // MARK: - Family Operations
    
    /// Creates a new family with validation
    func createFamily(name: String, code: String, createdByUserId: UUID) throws -> Family {
        print("🏠 DataService: Creating new family - Name: '\(name)', Code: '\(code)'")
        
        // Validate before creation
        let validationResult = try validateFamily(name: name, code: code)
        if !validationResult.isValid {
            print("❌ DataService: Family validation failed: \(validationResult.message)")
            throw DataServiceError.validationFailed([validationResult.message])
        }
        
        print("✅ DataService: Family validation passed")
        
        do {
            let family = Family(name: name, code: code, createdByUserId: createdByUserId)
            
            // Ensure the family is valid
            guard family.isFullyValid else {
                print("❌ DataService: Created family is not fully valid")
                throw DataServiceError.invalidData("Family data is invalid")
            }
            
            print("📝 DataService: Inserting family into ModelContext...")
            modelContext.insert(family)
            
            print("💾 DataService: Saving family to persistent store...")
            try save()
            
            print("✅ DataService: Family created successfully - ID: \(family.id)")
            return family
            
        } catch {
            print("❌ DataService: Failed to create family")
            print("   Error: \(error.localizedDescription)")
            
            // Re-throw with more context
            if error is DataServiceError {
                throw error
            } else {
                throw DataServiceError.invalidData("Failed to create family '\(name)': \(error.localizedDescription)")
            }
        }
    }
    
    /// Fetches a family by code
    func fetchFamily(byCode code: String) throws -> Family? {
        print("🔍 DataService: Fetching family by code: '\(code)'")
        
        // Validate input
        guard !code.isEmpty else {
            print("❌ DataService: Empty code provided")
            throw DataServiceError.invalidData("Family code cannot be empty")
        }
        
        do {
            // Create descriptor with safer predicate handling
            let descriptor = FetchDescriptor<Family>()
            let allFamilies = try modelContext.fetch(descriptor)
            
            print("📊 DataService: Found \(allFamilies.count) total families")
            
            // Filter manually to avoid predicate issues
            let matchingFamily = allFamilies.first { family in
                family.code == code
            }
            
            if let family = matchingFamily {
                print("✅ DataService: Found matching family: '\(family.name)' (ID: \(family.id))")
            } else {
                print("❌ DataService: No family found with code: '\(code)'")
            }
            
            return matchingFamily
            
        } catch {
            print("❌ DataService: Fetch operation failed")
            print("   Error: \(error.localizedDescription)")
            
            // Re-throw with more context
            throw DataServiceError.invalidData("Failed to fetch family by code '\(code)': \(error.localizedDescription)")
        }
    }
    
    /// Fetches a family by ID
    func fetchFamily(byId id: UUID) throws -> Family? {
        print("🔍 DataService: Fetching family by ID: \(id)")
        
        do {
            // Create descriptor with safer predicate handling
            let descriptor = FetchDescriptor<Family>()
            let allFamilies = try modelContext.fetch(descriptor)
            
            print("📊 DataService: Found \(allFamilies.count) total families")
            
            // Filter manually to avoid predicate issues
            let matchingFamily = allFamilies.first { family in
                family.id == id
            }
            
            if let family = matchingFamily {
                print("✅ DataService: Found matching family: '\(family.name)' (Code: \(family.code))")
            } else {
                print("❌ DataService: No family found with ID: \(id)")
            }
            
            return matchingFamily
            
        } catch {
            print("❌ DataService: Fetch operation failed")
            print("   Error: \(error.localizedDescription)")
            
            // Re-throw with more context
            throw DataServiceError.invalidData("Failed to fetch family by ID '\(id)': \(error.localizedDescription)")
        }
    }
    
    /// Fetches all families
    func fetchAllFamilies() throws -> [Family] {
        print("🔍 DataService: Fetching all families")
        
        do {
            let descriptor = FetchDescriptor<Family>()
            let families = try modelContext.fetch(descriptor)
            
            print("📊 DataService: Successfully fetched \(families.count) families")
            
            return families
            
        } catch {
            print("❌ DataService: Failed to fetch all families")
            print("   Error: \(error.localizedDescription)")
            
            // Re-throw with more context
            throw DataServiceError.invalidData("Failed to fetch all families: \(error.localizedDescription)")
        }
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
            throw DataServiceError.validationFailed([validationResult.message])
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
        print("🔍 DataService: Fetching user profile by Apple ID hash")
        
        // Validate input
        guard !hash.isEmpty else {
            print("❌ DataService: Empty Apple ID hash provided")
            throw DataServiceError.invalidData("Apple ID hash cannot be empty")
        }
        
        do {
            // Create descriptor with safer predicate handling
            let descriptor = FetchDescriptor<UserProfile>()
            let allProfiles = try modelContext.fetch(descriptor)
            
            print("📊 DataService: Found \(allProfiles.count) total user profiles")
            
            // Filter manually to avoid predicate issues
            let matchingProfile = allProfiles.first { profile in
                profile.appleUserIdHash == hash
            }
            
            if let profile = matchingProfile {
                print("✅ DataService: Found matching user profile: '\(profile.displayName)' (ID: \(profile.id))")
            } else {
                print("❌ DataService: No user profile found with Apple ID hash")
            }
            
            return matchingProfile
            
        } catch {
            print("❌ DataService: Fetch operation failed")
            print("   Error: \(error.localizedDescription)")
            
            // Re-throw with more context
            throw DataServiceError.invalidData("Failed to fetch user profile by Apple ID hash: \(error.localizedDescription)")
        }
    }
    
    /// Fetches a user profile by ID
    func fetchUserProfile(byId id: UUID) throws -> UserProfile? {
        print("🔍 DataService: Fetching user profile by ID: \(id)")
        
        do {
            // Create descriptor with safer predicate handling
            let descriptor = FetchDescriptor<UserProfile>()
            let allProfiles = try modelContext.fetch(descriptor)
            
            print("📊 DataService: Found \(allProfiles.count) total user profiles")
            
            // Filter manually to avoid predicate issues
            let matchingProfile = allProfiles.first { profile in
                profile.id == id
            }
            
            if let profile = matchingProfile {
                print("✅ DataService: Found matching user profile: '\(profile.displayName)'")
            } else {
                print("❌ DataService: No user profile found with ID: \(id)")
            }
            
            return matchingProfile
            
        } catch {
            print("❌ DataService: Fetch operation failed")
            print("   Error: \(error.localizedDescription)")
            
            // Re-throw with more context
            throw DataServiceError.invalidData("Failed to fetch user profile by ID '\(id)': \(error.localizedDescription)")
        }
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
        if role == .parentAdmin {
            let hasParentAdmin = try familyHasParentAdmin(family)
            if hasParentAdmin {
                throw DataServiceError.constraintViolation("A Parent Admin already exists for this family")
            }
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
        print("🔍 DataService: Fetching memberships for family: '\(family.name)' (ID: \(family.id))")
        
        do {
            let descriptor = FetchDescriptor<Membership>()
            let allMemberships = try modelContext.fetch(descriptor)
            
            print("📊 DataService: Found \(allMemberships.count) total memberships")
            
            let familyMemberships = allMemberships.filter { membership in
                membership.family?.id == family.id
            }
            
            print("✅ DataService: Found \(familyMemberships.count) memberships for family '\(family.name)'")
            
            return familyMemberships
            
        } catch {
            print("❌ DataService: Failed to fetch memberships for family")
            print("   Error: \(error.localizedDescription)")
            
            // Re-throw with more context
            throw DataServiceError.invalidData("Failed to fetch memberships for family '\(family.name)': \(error.localizedDescription)")
        }
    }
    
    /// Fetches memberships for a user
    func fetchMemberships(forUser user: UserProfile) throws -> [Membership] {
        print("🔍 DataService: Fetching memberships for user: '\(user.displayName)' (ID: \(user.id))")
        
        do {
            let descriptor = FetchDescriptor<Membership>()
            let allMemberships = try modelContext.fetch(descriptor)
            
            print("📊 DataService: Found \(allMemberships.count) total memberships")
            
            let userMemberships = allMemberships.filter { membership in
                membership.user?.id == user.id
            }
            
            print("✅ DataService: Found \(userMemberships.count) memberships for user '\(user.displayName)'")
            
            return userMemberships
            
        } catch {
            print("❌ DataService: Failed to fetch memberships for user")
            print("   Error: \(error.localizedDescription)")
            
            // Re-throw with more context
            throw DataServiceError.invalidData("Failed to fetch memberships for user '\(user.displayName)': \(error.localizedDescription)")
        }
    }
    
    /// Fetches active memberships for a family
    func fetchActiveMemberships(forFamily family: Family) throws -> [Membership] {
        let allMemberships = try fetchMemberships(forFamily: family)
        return allMemberships.filter { $0.status == .active }
    }
    
    /// Checks if a family has a parent admin
    func familyHasParentAdmin(_ family: Family) throws -> Bool {
        let activeMemberships = try fetchActiveMemberships(forFamily: family)
        return activeMemberships.contains { $0.role == .parentAdmin }
    }
    
    /// Updates a membership role with validation
    func updateMembershipRole(_ membership: Membership, to role: Role) throws {
        // Validate the role change
        let validationResult = try validateRoleChange(membership: membership, newRole: role)
        if !validationResult.isValid {
            throw DataServiceError.validationFailed([validationResult.message])
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
        print("💾 DataService: Attempting to save ModelContext...")
        
        do {
            // Check if there are changes to save
            if modelContext.hasChanges {
                print("📝 DataService: ModelContext has changes, saving...")
                try modelContext.save()
                print("✅ DataService: ModelContext saved successfully")
            } else {
                print("ℹ️ DataService: No changes to save")
            }
        } catch {
            print("❌ DataService: Failed to save ModelContext")
            print("   Error: \(error.localizedDescription)")
            
            // Re-throw with more context
            throw DataServiceError.invalidData("Failed to save context: \(error.localizedDescription)")
        }
    }
    
    /// Deletes an object
    func delete<T: PersistentModel>(_ object: T) throws {
        modelContext.delete(object)
        try modelContext.save()
    }
    
    /// Fetches records that need CloudKit sync
    func fetchRecordsNeedingSync<T: PersistentModel & CloudKitSyncable>(_ type: T.Type) throws -> [T] {
        print("🔍 DataService: Fetching records needing sync for type: \(T.self)")
        
        do {
            // Use safer approach without predicates for now
            let descriptor = FetchDescriptor<T>()
            let allRecords = try modelContext.fetch(descriptor)
            
            print("📊 DataService: Found \(allRecords.count) total records of type \(T.self)")
            
            // Filter manually to avoid predicate issues
            let recordsNeedingSync = allRecords.filter { record in
                record.needsSync == true
            }
            
            print("✅ DataService: Found \(recordsNeedingSync.count) records needing sync")
            
            return recordsNeedingSync
            
        } catch {
            print("❌ DataService: Failed to fetch records needing sync")
            print("   Error: \(error.localizedDescription)")
            
            // Re-throw with more context
            throw DataServiceError.invalidData("Failed to fetch records needing sync for type \(T.self): \(error.localizedDescription)")
        }
    }
    
    // MARK: - Validation Operations
    
    /// Validates a family before creation
    func validateFamily(name: String, code: String) throws -> ValidationResult {
        // Validate name
        let nameValidation = Validation.validateFamilyName(name)
        if !nameValidation.isValid {
            return nameValidation
        }
        
        // Validate code
        let codeValidation = Validation.validateFamilyCode(code)
        if !codeValidation.isValid {
            return codeValidation
        }
        
        // Check code uniqueness
        if try familyCodeExists(code) {
            return ValidationResult(isValid: false, message: "Family code already exists")
        }
        
        return ValidationResult(isValid: true, message: "Valid family data")
    }
    
    /// Validates a user profile before creation
    func validateUserProfile(displayName: String, appleUserIdHash: String) -> ValidationResult {
        // Validate display name
        let displayNameValidation = Validation.validateDisplayName(displayName)
        if !displayNameValidation.isValid {
            return displayNameValidation
        }
        
        // Validate Apple ID hash
        if appleUserIdHash.isEmpty {
            return ValidationResult(isValid: false, message: "Apple ID hash cannot be empty")
        } else if appleUserIdHash.count < 10 {
            return ValidationResult(isValid: false, message: "Invalid Apple ID hash format")
        }
        
        return ValidationResult(isValid: true, message: "Valid user profile")
    }
    
    /// Validates a role change
    func validateRoleChange(membership: Membership, newRole: Role) throws -> ValidationResult {
        guard let family = membership.family else {
            return ValidationResult(isValid: false, message: "Invalid membership: no family associated")
        }
        
        // Check if role change is valid
        if !membership.canChangeRole(to: newRole, in: family) {
            if newRole == .parentAdmin && family.hasParentAdmin {
                return ValidationResult(isValid: false, message: "A Parent Admin already exists for this family")
            } else if membership.role == newRole {
                return ValidationResult(isValid: false, message: "Member already has this role")
            }
        }
        
        return ValidationResult(isValid: true, message: "Valid role change")
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