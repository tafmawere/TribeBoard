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
    
    /// Validates database state before critical operations
    private func validateDatabaseState() throws {
        print("🔍 DataService: Validating database state...")
        
        // Test basic read operation
        do {
            var testDescriptor = FetchDescriptor<Family>()
            testDescriptor.fetchLimit = 1
            _ = try modelContext.fetch(testDescriptor)
        } catch {
            throw DataServiceError.invalidData("Database read test failed: \(error.localizedDescription)")
        }
        
        print("✅ DataService: Database state validation passed")
    }
    
    /// Performs a database operation within a safe transaction context
    private func performTransactionSafely<T>(_ operation: (ModelContext) throws -> T) throws -> T {
        print("🔄 DataService: Starting safe transaction...")
        
        // Validate state before transaction
        try validateDatabaseState()
        
        do {
            // Perform the operation
            let result = try operation(modelContext)
            
            // Only save if there are changes and operation succeeded
            if modelContext.hasChanges {
                print("💾 DataService: Transaction has changes, saving...")
                try modelContext.save()
                print("✅ DataService: Transaction saved successfully")
            } else {
                print("ℹ️ DataService: Transaction completed with no changes")
            }
            
            return result
            
        } catch {
            print("❌ DataService: Transaction failed, attempting rollback...")
            
            // Attempt to rollback changes
            if modelContext.hasChanges {
                do {
                    modelContext.rollback()
                    print("✅ DataService: Transaction rolled back successfully")
                } catch let rollbackError {
                    print("❌ DataService: Rollback failed: \(rollbackError.localizedDescription)")
                    ErrorHandlingUtilities.logError(
                        .localCreationFailed(.invalidData("Transaction rollback failed")),
                        context: ErrorContext(error: .localCreationFailed(.invalidData("Rollback failed"))),
                        additionalInfo: ["rollback_error": rollbackError.localizedDescription, "original_error": error.localizedDescription]
                    )
                }
            }
            
            // Re-throw the original error
            throw error
        }
    }
    
    // MARK: - Family Operations
    
    /// Creates a new family with enhanced validation and transaction safety
    func createFamily(name: String, code: String, createdByUserId: UUID) throws -> Family {
        print("🏠 DataService: Creating new family - Name: '\(name)', Code: '\(code)'")
        
        // Comprehensive input validation
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            let error = DataServiceError.validationFailed(["Family name cannot be empty"])
            ErrorHandlingUtilities.logError(
                .validationFailed("Empty family name provided"),
                context: ErrorContext(error: .validationFailed("Empty name")),
                additionalInfo: ["operation": "createFamily", "name": name, "code": code]
            )
            throw error
        }
        
        // Validate before creation
        let validationResult = try validateFamily(name: name, code: code)
        if !validationResult.isValid {
            print("❌ DataService: Family validation failed: \(validationResult.message)")
            ErrorHandlingUtilities.logError(
                .validationFailed(validationResult.message),
                context: ErrorContext(error: .validationFailed("Family validation failed")),
                additionalInfo: ["operation": "createFamily", "name": name, "code": code, "validation_message": validationResult.message]
            )
            throw DataServiceError.validationFailed([validationResult.message])
        }
        
        print("✅ DataService: Family validation passed")
        
        // Validate database state before creation
        do {
            try validateDatabaseState()
        } catch {
            ErrorHandlingUtilities.logError(
                .localCreationFailed(.invalidData("Database validation failed")),
                context: ErrorContext(error: .localCreationFailed(.invalidData("Database invalid"))),
                additionalInfo: ["operation": "createFamily", "validation_error": error.localizedDescription]
            )
            throw DataServiceError.invalidData("Database is in invalid state: \(error.localizedDescription)")
        }
        
        return try performTransactionSafely { context in
            // Double-check code uniqueness within transaction
            let existingFamily = try fetchFamily(byCode: code)
            if existingFamily != nil {
                let error = DataServiceError.constraintViolation("Family code '\(code)' already exists")
                ErrorHandlingUtilities.logError(
                    .constraintViolation("Duplicate family code during creation"),
                    context: ErrorContext(error: .constraintViolation("Duplicate code")),
                    additionalInfo: ["operation": "createFamily", "name": name, "code": code]
                )
                throw error
            }
            
            // Create family instance
            let family = Family(name: name, code: code, createdByUserId: createdByUserId)
            
            // Ensure the family is valid
            guard family.isFullyValid else {
                let error = DataServiceError.invalidData("Created family data is invalid")
                ErrorHandlingUtilities.logError(
                    .validationFailed("Created family failed validation"),
                    context: ErrorContext(error: .validationFailed("Invalid family data")),
                    additionalInfo: ["operation": "createFamily", "name": name, "code": code, "family_id": family.id.uuidString]
                )
                throw error
            }
            
            print("📝 DataService: Inserting family into ModelContext...")
            context.insert(family)
            
            // Validate insertion was successful
            guard context.hasChanges else {
                let error = DataServiceError.invalidData("Family insertion did not register changes")
                ErrorHandlingUtilities.logError(
                    .localCreationFailed(.invalidData("Insertion failed")),
                    context: ErrorContext(error: .localCreationFailed(.invalidData("No changes"))),
                    additionalInfo: ["operation": "createFamily", "name": name, "code": code]
                )
                throw error
            }
            
            print("✅ DataService: Family created successfully - ID: \(family.id)")
            
            // Log successful creation
            ErrorHandlingUtilities.logError(
                .operationSucceeded,
                context: ErrorContext(error: .operationSucceeded),
                additionalInfo: ["operation": "createFamily", "name": name, "code": code, "family_id": family.id.uuidString]
            )
            
            return family
        }
    }
    
    /// Fetches a family by code with enhanced safety and error handling
    func fetchFamily(byCode code: String) throws -> Family? {
        print("🔍 DataService: Fetching family by code: '\(code)'")
        
        // Comprehensive input validation
        guard !code.isEmpty else {
            let error = DataServiceError.invalidData("Family code cannot be empty")
            ErrorHandlingUtilities.logError(
                .validationFailed("Empty family code provided"),
                context: ErrorContext(error: .validationFailed("Empty family code")),
                additionalInfo: ["operation": "fetchFamily", "code": "empty"]
            )
            throw error
        }
        
        guard code.count >= 6 && code.count <= 8 else {
            let error = DataServiceError.invalidData("Family code must be 6-8 characters long")
            ErrorHandlingUtilities.logError(
                .validationFailed("Invalid family code length: \(code.count)"),
                context: ErrorContext(error: .validationFailed("Invalid code length")),
                additionalInfo: ["operation": "fetchFamily", "code": code, "length": code.count]
            )
            throw error
        }
        
        // Validate database state before operation
        do {
            try validateDatabaseState()
        } catch {
            ErrorHandlingUtilities.logError(
                .localCreationFailed(.invalidData("Database validation failed")),
                context: ErrorContext(error: .localCreationFailed(.invalidData("Database invalid"))),
                additionalInfo: ["operation": "fetchFamily", "validation_error": error.localizedDescription]
            )
            throw DataServiceError.invalidData("Database is in invalid state: \(error.localizedDescription)")
        }
        
        return try performTransactionSafely { context in
            do {
                // Use safer predicate-based query with proper error handling
                let predicate = #Predicate<Family> { family in
                    family.code == code
                }
                
                let descriptor = FetchDescriptor<Family>(predicate: predicate)
                let matchingFamilies = try context.fetch(descriptor)
                
                print("📊 DataService: Found \(matchingFamilies.count) families matching code '\(code)'")
                
                // Validate results
                if matchingFamilies.count > 1 {
                    let error = DataServiceError.constraintViolation("Multiple families found with same code: '\(code)'")
                    ErrorHandlingUtilities.logError(
                        .constraintViolation("Duplicate family codes detected"),
                        context: ErrorContext(error: .constraintViolation("Duplicate codes")),
                        additionalInfo: ["operation": "fetchFamily", "code": code, "count": matchingFamilies.count]
                    )
                    throw error
                }
                
                let matchingFamily = matchingFamilies.first
                
                if let family = matchingFamily {
                    // Validate family data integrity
                    guard family.isFullyValid else {
                        let error = DataServiceError.invalidData("Found family has invalid data")
                        ErrorHandlingUtilities.logError(
                            .dataCorruption("Invalid family data detected"),
                            context: ErrorContext(error: .dataCorruption("Invalid family")),
                            additionalInfo: ["operation": "fetchFamily", "family_id": family.id.uuidString, "code": code]
                        )
                        throw error
                    }
                    
                    print("✅ DataService: Found valid family: '\(family.name)' (ID: \(family.id))")
                } else {
                    print("ℹ️ DataService: No family found with code: '\(code)'")
                }
                
                return matchingFamily
                
            } catch {
                // Handle predicate-related errors with fallback
                print("⚠️ DataService: Predicate query failed, falling back to manual filtering")
                print("   Predicate Error: \(error.localizedDescription)")
                
                // Fallback to safer manual filtering
                return try fetchFamilyWithManualFiltering(code: code, context: context)
            }
        }
    }
    
    /// Fallback method using manual filtering when predicate queries fail
    private func fetchFamilyWithManualFiltering(code: String, context: ModelContext) throws -> Family? {
        print("🔄 DataService: Using manual filtering fallback for code: '\(code)'")
        
        do {
            // Fetch all families without predicates
            let descriptor = FetchDescriptor<Family>()
            let allFamilies = try context.fetch(descriptor)
            
            print("📊 DataService: Loaded \(allFamilies.count) families for manual filtering")
            
            // Safely filter families manually
            var matchingFamilies: [Family] = []
            
            for family in allFamilies {
                // Safely check each family
                guard family.isFullyValid else {
                    print("⚠️ DataService: Skipping invalid family (ID: \(family.id))")
                    continue
                }
                
                if family.code == code {
                    matchingFamilies.append(family)
                }
            }
            
            // Validate uniqueness
            if matchingFamilies.count > 1 {
                let error = DataServiceError.constraintViolation("Multiple families found with same code: '\(code)'")
                ErrorHandlingUtilities.logError(
                    .constraintViolation("Duplicate family codes in manual filter"),
                    context: ErrorContext(error: .constraintViolation("Duplicate codes")),
                    additionalInfo: ["operation": "fetchFamilyManual", "code": code, "count": matchingFamilies.count]
                )
                throw error
            }
            
            let matchingFamily = matchingFamilies.first
            
            if let family = matchingFamily {
                print("✅ DataService: Manual filtering found family: '\(family.name)' (ID: \(family.id))")
            } else {
                print("ℹ️ DataService: Manual filtering found no family with code: '\(code)'")
            }
            
            return matchingFamily
            
        } catch {
            ErrorHandlingUtilities.logError(
                .localCreationFailed(.invalidData("Manual filtering failed")),
                context: ErrorContext(error: .localCreationFailed(.invalidData("Manual filter failed"))),
                additionalInfo: ["operation": "fetchFamilyManual", "code": code, "error": error.localizedDescription]
            )
            throw DataServiceError.invalidData("Failed to fetch family by code '\(code)' using manual filtering: \(error.localizedDescription)")
        }
    }
    
    /// Fetches a family by ID with enhanced safety and error handling
    func fetchFamily(byId id: UUID) throws -> Family? {
        print("🔍 DataService: Fetching family by ID: \(id)")
        
        // Validate database state before operation
        do {
            try validateDatabaseState()
        } catch {
            ErrorHandlingUtilities.logError(
                .localCreationFailed(.invalidData("Database validation failed")),
                context: ErrorContext(error: .localCreationFailed(.invalidData("Database invalid"))),
                additionalInfo: ["operation": "fetchFamilyById", "validation_error": error.localizedDescription]
            )
            throw DataServiceError.invalidData("Database is in invalid state: \(error.localizedDescription)")
        }
        
        return try performTransactionSafely { context in
            do {
                // Use safer predicate-based query with proper error handling
                let predicate = #Predicate<Family> { family in
                    family.id == id
                }
                
                let descriptor = FetchDescriptor<Family>(predicate: predicate)
                let matchingFamilies = try context.fetch(descriptor)
                
                print("📊 DataService: Found \(matchingFamilies.count) families matching ID")
                
                // Validate results
                if matchingFamilies.count > 1 {
                    let error = DataServiceError.constraintViolation("Multiple families found with same ID: \(id)")
                    ErrorHandlingUtilities.logError(
                        .constraintViolation("Duplicate family IDs detected"),
                        context: ErrorContext(error: .constraintViolation("Duplicate IDs")),
                        additionalInfo: ["operation": "fetchFamilyById", "id": id.uuidString, "count": matchingFamilies.count]
                    )
                    throw error
                }
                
                let matchingFamily = matchingFamilies.first
                
                if let family = matchingFamily {
                    // Validate family data integrity
                    guard family.isFullyValid else {
                        let error = DataServiceError.invalidData("Found family has invalid data")
                        ErrorHandlingUtilities.logError(
                            .dataCorruption("Invalid family data detected"),
                            context: ErrorContext(error: .dataCorruption("Invalid family")),
                            additionalInfo: ["operation": "fetchFamilyById", "family_id": family.id.uuidString]
                        )
                        throw error
                    }
                    
                    print("✅ DataService: Found valid family: '\(family.name)' (Code: \(family.code))")
                } else {
                    print("ℹ️ DataService: No family found with ID: \(id)")
                }
                
                return matchingFamily
                
            } catch {
                // Handle predicate-related errors with fallback
                print("⚠️ DataService: Predicate query failed, falling back to manual filtering")
                print("   Predicate Error: \(error.localizedDescription)")
                
                // Fallback to safer manual filtering
                return try fetchFamilyByIdWithManualFiltering(id: id, context: context)
            }
        }
    }
    
    /// Fallback method using manual filtering when predicate queries fail for ID lookup
    private func fetchFamilyByIdWithManualFiltering(id: UUID, context: ModelContext) throws -> Family? {
        print("🔄 DataService: Using manual filtering fallback for ID: \(id)")
        
        do {
            // Fetch all families without predicates
            let descriptor = FetchDescriptor<Family>()
            let allFamilies = try context.fetch(descriptor)
            
            print("📊 DataService: Loaded \(allFamilies.count) families for manual ID filtering")
            
            // Safely filter families manually
            var matchingFamilies: [Family] = []
            
            for family in allFamilies {
                // Safely check each family
                guard family.isFullyValid else {
                    print("⚠️ DataService: Skipping invalid family (ID: \(family.id))")
                    continue
                }
                
                if family.id == id {
                    matchingFamilies.append(family)
                }
            }
            
            // Validate uniqueness
            if matchingFamilies.count > 1 {
                let error = DataServiceError.constraintViolation("Multiple families found with same ID: \(id)")
                ErrorHandlingUtilities.logError(
                    .constraintViolation("Duplicate family IDs in manual filter"),
                    context: ErrorContext(error: .constraintViolation("Duplicate IDs")),
                    additionalInfo: ["operation": "fetchFamilyByIdManual", "id": id.uuidString, "count": matchingFamilies.count]
                )
                throw error
            }
            
            let matchingFamily = matchingFamilies.first
            
            if let family = matchingFamily {
                print("✅ DataService: Manual filtering found family: '\(family.name)' (Code: \(family.code))")
            } else {
                print("ℹ️ DataService: Manual filtering found no family with ID: \(id)")
            }
            
            return matchingFamily
            
        } catch {
            ErrorHandlingUtilities.logError(
                .localCreationFailed(.invalidData("Manual ID filtering failed")),
                context: ErrorContext(error: .localCreationFailed(.invalidData("Manual ID filter failed"))),
                additionalInfo: ["operation": "fetchFamilyByIdManual", "id": id.uuidString, "error": error.localizedDescription]
            )
            throw DataServiceError.invalidData("Failed to fetch family by ID '\(id)' using manual filtering: \(error.localizedDescription)")
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
    
    /// Fetches families that need to be synced to CloudKit
    func fetchPendingSyncFamilies() throws -> [Family] {
        print("🔍 DataService: Fetching families pending sync")
        
        do {
            let descriptor = FetchDescriptor<Family>()
            let allFamilies = try modelContext.fetch(descriptor)
            
            let pendingFamilies = allFamilies.filter { family in
                family.needsSync && family.isFullyValid
            }
            
            print("📊 DataService: Found \(pendingFamilies.count) families pending sync")
            return pendingFamilies
            
        } catch {
            print("❌ DataService: Failed to fetch pending sync families: \(error.localizedDescription)")
            throw DataServiceError.invalidData("Failed to fetch pending sync families: \(error.localizedDescription)")
        }
    }
    
    /// Counts families that need to be synced to CloudKit
    func countPendingSyncFamilies() throws -> Int {
        return try fetchPendingSyncFamilies().count
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
    
    /// Saves the current context with enhanced error handling and validation
    func save() throws {
        print("💾 DataService: Attempting to save ModelContext...")
        
        // Validate database state before saving
        do {
            try validateDatabaseState()
        } catch {
            ErrorHandlingUtilities.logError(
                .localCreationFailed(.invalidData("Database validation failed before save")),
                context: ErrorContext(error: .localCreationFailed(.invalidData("Database invalid"))),
                additionalInfo: ["operation": "save", "validation_error": error.localizedDescription]
            )
            throw DataServiceError.invalidData("Database is in invalid state before save: \(error.localizedDescription)")
        }
        
        do {
            // Check if there are changes to save
            if modelContext.hasChanges {
                print("📝 DataService: ModelContext has changes, saving...")
                
                // Attempt to save with retry logic for transient failures
                var saveAttempts = 0
                let maxSaveAttempts = 3
                var lastError: Error?
                
                while saveAttempts < maxSaveAttempts {
                    do {
                        try modelContext.save()
                        print("✅ DataService: ModelContext saved successfully on attempt \(saveAttempts + 1)")
                        
                        // Log successful save
                        ErrorHandlingUtilities.logError(
                            .operationSucceeded,
                            context: ErrorContext(error: .operationSucceeded),
                            additionalInfo: ["operation": "save", "attempts": saveAttempts + 1]
                        )
                        
                        return
                        
                    } catch {
                        saveAttempts += 1
                        lastError = error
                        
                        print("⚠️ DataService: Save attempt \(saveAttempts) failed: \(error.localizedDescription)")
                        
                        if saveAttempts < maxSaveAttempts {
                            print("🔄 DataService: Retrying save in 0.1 seconds...")
                            Thread.sleep(forTimeInterval: 0.1)
                        }
                    }
                }
                
                // All save attempts failed
                if let error = lastError {
                    ErrorHandlingUtilities.logError(
                        .localCreationFailed(.invalidData("Save failed after retries")),
                        context: ErrorContext(error: .localCreationFailed(.invalidData("Save failed"))),
                        additionalInfo: ["operation": "save", "attempts": saveAttempts, "error": error.localizedDescription]
                    )
                    throw DataServiceError.invalidData("Failed to save context after \(maxSaveAttempts) attempts: \(error.localizedDescription)")
                }
                
            } else {
                print("ℹ️ DataService: No changes to save")
            }
        } catch {
            print("❌ DataService: Failed to save ModelContext")
            print("   Error: \(error.localizedDescription)")
            
            // Log the error
            let familyCreationError = ErrorHandlingUtilities.categorizeError(error)
            ErrorHandlingUtilities.logError(
                familyCreationError,
                context: ErrorContext(error: familyCreationError),
                additionalInfo: ["operation": "save", "error": error.localizedDescription]
            )
            
            // Re-throw with more context
            if error is DataServiceError {
                throw error
            } else {
                throw DataServiceError.invalidData("Failed to save context: \(error.localizedDescription)")
            }
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
    
    /// Fetches memberships that need to be synced to CloudKit
    func fetchPendingSyncMemberships() throws -> [Membership] {
        print("🔍 DataService: Fetching memberships pending sync")
        
        do {
            let descriptor = FetchDescriptor<Membership>()
            let allMemberships = try modelContext.fetch(descriptor)
            
            let pendingMemberships = allMemberships.filter { membership in
                membership.needsSync && membership.isFullyValid
            }
            
            print("📊 DataService: Found \(pendingMemberships.count) memberships pending sync")
            return pendingMemberships
            
        } catch {
            print("❌ DataService: Failed to fetch pending sync memberships: \(error.localizedDescription)")
            throw DataServiceError.invalidData("Failed to fetch pending sync memberships: \(error.localizedDescription)")
        }
    }
    
    /// Counts memberships that need to be synced to CloudKit
    func countPendingSyncMemberships() throws -> Int {
        return try fetchPendingSyncMemberships().count
    }
    
    /// Fetches user profiles that need to be synced to CloudKit
    func fetchPendingSyncUserProfiles() throws -> [UserProfile] {
        print("🔍 DataService: Fetching user profiles pending sync")
        
        do {
            let descriptor = FetchDescriptor<UserProfile>()
            let allProfiles = try modelContext.fetch(descriptor)
            
            let pendingProfiles = allProfiles.filter { profile in
                profile.needsSync && profile.isFullyValid
            }
            
            print("📊 DataService: Found \(pendingProfiles.count) user profiles pending sync")
            return pendingProfiles
            
        } catch {
            print("❌ DataService: Failed to fetch pending sync user profiles: \(error.localizedDescription)")
            throw DataServiceError.invalidData("Failed to fetch pending sync user profiles: \(error.localizedDescription)")
        }
    }
    
    /// Counts user profiles that need to be synced to CloudKit
    func countPendingSyncUserProfiles() throws -> Int {
        return try fetchPendingSyncUserProfiles().count
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
    
    /// Generates a random 6-8 character alphanumeric code safely
    private func generateRandomCode() -> String {
        let characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        let charactersArray = Array(characters)
        let length = Int.random(in: 6...8)
        
        return String((0..<length).compactMap { _ in
            guard !charactersArray.isEmpty else { return nil }
            let randomIndex = Int.random(in: 0..<charactersArray.count)
            return charactersArray[randomIndex]
        })
    }
}



/// Extension for creating DataService from environment
extension DataService {
    /// Creates a DataService from the current model context
    static func from(modelContext: ModelContext) -> DataService {
        return DataService(modelContext: modelContext)
    }
}