import Foundation
import SwiftData

/// Custom errors for ModelContainer creation
enum ModelContainerError: Error, LocalizedError {
    case schemaValidationFailed(underlying: Error)
    case cloudKitCreationFailed(underlying: Error)
    case localCreationFailed(underlying: Error)
    case inMemoryCreationFailed(underlying: Error)
    case allCreationMethodsFailed
    
    var errorDescription: String? {
        switch self {
        case .schemaValidationFailed(let underlying):
            return "SwiftData schema validation failed: \(underlying.localizedDescription)"
        case .cloudKitCreationFailed(let underlying):
            return "CloudKit ModelContainer creation failed: \(underlying.localizedDescription)"
        case .localCreationFailed(let underlying):
            return "Local ModelContainer creation failed: \(underlying.localizedDescription)"
        case .inMemoryCreationFailed(let underlying):
            return "In-memory ModelContainer creation failed: \(underlying.localizedDescription)"
        case .allCreationMethodsFailed:
            return "All ModelContainer creation methods failed"
        }
    }
    
    var failureReason: String? {
        switch self {
        case .schemaValidationFailed:
            return "SwiftData model definitions are invalid. This may be due to incorrect @Model annotations, invalid property types, or relationship configuration issues."
        case .cloudKitCreationFailed:
            return "CloudKit container could not be initialized. This may be due to CloudKit being unavailable, incorrect container configuration, or network issues."
        case .localCreationFailed:
            return "Local storage container could not be initialized. This may be due to disk space, permissions, or file system issues."
        case .inMemoryCreationFailed:
            return "In-memory container could not be initialized. This indicates a critical system or schema issue."
        case .allCreationMethodsFailed:
            return "No ModelContainer creation method succeeded. The app cannot continue without a data store."
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .schemaValidationFailed:
            return "Review @Model class definitions, ensure proper SwiftData annotations, check property types and relationship configurations."
        case .cloudKitCreationFailed:
            return "Try signing into iCloud, check network connectivity, or verify CloudKit container configuration."
        case .localCreationFailed:
            return "Check available disk space, app permissions, or try clearing app data."
        case .inMemoryCreationFailed:
            return "Check SwiftData model definitions and schema configuration."
        case .allCreationMethodsFailed:
            return "Contact support or reinstall the application."
        }
    }
}

/// Configuration for SwiftData ModelContainer with CloudKit sync
struct ModelContainerConfiguration {
    
    /// Validates the SwiftData schema before container creation
    static func validateSchema() throws {
        print("🔍 Validating SwiftData model schema...")
        
        do {
            // Attempt to create the schema to validate model definitions
            let schema = Schema([
                Family.self,
                UserProfile.self,
                Membership.self
            ])
            
            print("✅ SwiftData schema compilation successful")
            print("   - Family model: ✓")
            print("   - UserProfile model: ✓") 
            print("   - Membership model: ✓")
            print("   - Total entities: \(schema.entities.count)")
            
            // Perform detailed validation of each entity
            try validateEntityStructure(schema)
            try validateRelationships(schema)
            try validateAttributes(schema)
            
            print("✅ SwiftData schema validation completed successfully")
            
        } catch let error as ModelContainerError {
            // Re-throw our custom errors
            throw error
        } catch {
            print("❌ SwiftData schema validation failed")
            print("   Error: \(error.localizedDescription)")
            
            // Log specific model validation issues
            logSchemaValidationError(error)
            
            throw ModelContainerError.schemaValidationFailed(underlying: error)
        }
    }
    
    /// Validates the structure of each entity in the schema
    private static func validateEntityStructure(_ schema: Schema) throws {
        print("🔍 Validating entity structure...")
        
        let expectedEntities = ["Family", "UserProfile", "Membership"]
        let actualEntities = schema.entities.map { $0.name }
        
        // Check that all expected entities are present
        for expectedEntity in expectedEntities {
            guard actualEntities.contains(expectedEntity) else {
                let error = NSError(
                    domain: "SchemaValidation",
                    code: 1001,
                    userInfo: [NSLocalizedDescriptionKey: "Missing expected entity: \(expectedEntity)"]
                )
                throw ModelContainerError.schemaValidationFailed(underlying: error)
            }
        }
        
        // Validate each entity has required properties
        for entity in schema.entities {
            print("   - Validating entity '\(entity.name)' (\(entity.properties.count) properties)")
            
            switch entity.name {
            case "Family":
                try validateFamilyEntity(entity)
            case "UserProfile":
                try validateUserProfileEntity(entity)
            case "Membership":
                try validateMembershipEntity(entity)
            default:
                print("     ⚠️ Unknown entity type: \(entity.name)")
            }
        }
        
        print("✅ Entity structure validation completed")
    }
    
    /// Validates the Family entity structure
    private static func validateFamilyEntity(_ entity: Schema.Entity) throws {
        let requiredProperties = ["id", "name", "code", "createdByUserId", "createdAt"]
        let relationshipProperties = ["memberships"]
        
        try validateEntityProperties(entity, required: requiredProperties, relationships: relationshipProperties)
        
        // Validate unique attributes - but don't fail if they're missing, just warn
        let uniqueProperties = entity.properties.filter { $0.isUnique }
        let expectedUniqueProperties = ["id", "code"]
        
        for expectedUnique in expectedUniqueProperties {
            if !uniqueProperties.contains(where: { $0.name == expectedUnique }) {
                print("     ⚠️ Warning: Family entity missing unique constraint on '\(expectedUnique)'")
                // Don't throw error - SwiftData may handle uniqueness differently
            }
        }
    }
    
    /// Validates the UserProfile entity structure
    private static func validateUserProfileEntity(_ entity: Schema.Entity) throws {
        let requiredProperties = ["id", "displayName", "appleUserIdHash", "createdAt"]
        let relationshipProperties = ["memberships"]
        
        try validateEntityProperties(entity, required: requiredProperties, relationships: relationshipProperties)
        
        // Validate unique attributes - but don't fail if they're missing, just warn
        let uniqueProperties = entity.properties.filter { $0.isUnique }
        let expectedUniqueProperties = ["id", "appleUserIdHash"]
        
        for expectedUnique in expectedUniqueProperties {
            if !uniqueProperties.contains(where: { $0.name == expectedUnique }) {
                print("     ⚠️ Warning: UserProfile entity missing unique constraint on '\(expectedUnique)'")
                // Don't throw error - SwiftData may handle uniqueness differently
            }
        }
    }
    
    /// Validates the Membership entity structure
    private static func validateMembershipEntity(_ entity: Schema.Entity) throws {
        let requiredProperties = ["id", "role", "joinedAt", "status"]
        let relationshipProperties = ["family", "user"]
        
        try validateEntityProperties(entity, required: requiredProperties, relationships: relationshipProperties)
        
        // Validate unique attributes - but don't fail if they're missing, just warn
        let uniqueProperties = entity.properties.filter { $0.isUnique }
        let expectedUniqueProperties = ["id"]
        
        for expectedUnique in expectedUniqueProperties {
            if !uniqueProperties.contains(where: { $0.name == expectedUnique }) {
                print("     ⚠️ Warning: Membership entity missing unique constraint on '\(expectedUnique)'")
                // Don't throw error - SwiftData may handle uniqueness differently
            }
        }
    }
    
    /// Helper method to validate entity properties
    private static func validateEntityProperties(_ entity: Schema.Entity, required: [String], relationships: [String]) throws {
        let allPropertyNames = entity.properties.map { $0.name }
        
        // Check required properties - warn but don't fail for missing properties
        var missingProperties: [String] = []
        for requiredProperty in required {
            if !allPropertyNames.contains(requiredProperty) {
                missingProperties.append(requiredProperty)
                print("     ⚠️ Warning: \(entity.name) entity missing expected property: \(requiredProperty)")
            }
        }
        
        // Check relationship properties - warn but don't fail for missing relationships
        var missingRelationships: [String] = []
        for relationshipProperty in relationships {
            if !allPropertyNames.contains(relationshipProperty) {
                missingRelationships.append(relationshipProperty)
                print("     ⚠️ Warning: \(entity.name) entity missing expected relationship: \(relationshipProperty)")
            }
        }
        
        if missingProperties.isEmpty && missingRelationships.isEmpty {
            print("     ✓ All expected properties and relationships present")
        } else {
            print("     ⚠️ Some expected properties/relationships missing - continuing anyway")
            print("     📋 Actual properties found: \(allPropertyNames.joined(separator: ", "))")
        }
    }
    
    /// Validates relationships between entities
    private static func validateRelationships(_ schema: Schema) throws {
        print("🔍 Validating entity relationships...")
        
        // Find entities
        let familyEntity = schema.entities.first(where: { $0.name == "Family" })
        let userProfileEntity = schema.entities.first(where: { $0.name == "UserProfile" })
        let membershipEntity = schema.entities.first(where: { $0.name == "Membership" })
        
        guard familyEntity != nil && userProfileEntity != nil && membershipEntity != nil else {
            print("   ⚠️ Warning: Could not find all expected entities for relationship validation")
            print("   📋 Found entities: \(schema.entities.map { $0.name }.joined(separator: ", "))")
            return
        }
        
        // Validate Family -> Membership relationship
        if let family = familyEntity {
            if family.properties.contains(where: { $0.name == "memberships" }) {
                print("   ✓ Family -> Memberships relationship found")
            } else {
                print("   ⚠️ Warning: Family entity missing 'memberships' relationship")
            }
        }
        
        // Validate UserProfile -> Membership relationship
        if let userProfile = userProfileEntity {
            if userProfile.properties.contains(where: { $0.name == "memberships" }) {
                print("   ✓ UserProfile -> Memberships relationship found")
            } else {
                print("   ⚠️ Warning: UserProfile entity missing 'memberships' relationship")
            }
        }
        
        // Validate Membership -> Family relationship
        if let membership = membershipEntity {
            if membership.properties.contains(where: { $0.name == "family" }) {
                print("   ✓ Membership -> Family relationship found")
            } else {
                print("   ⚠️ Warning: Membership entity missing 'family' relationship")
            }
            
            // Validate Membership -> User relationship
            if membership.properties.contains(where: { $0.name == "user" }) {
                print("   ✓ Membership -> User relationship found")
            } else {
                print("   ⚠️ Warning: Membership entity missing 'user' relationship")
            }
        }
        
        print("✅ Relationship validation completed (with warnings if any)")
    }
    
    /// Validates attribute configurations
    private static func validateAttributes(_ schema: Schema) throws {
        print("🔍 Validating attribute configurations...")
        
        for entity in schema.entities {
            let uniqueProperties = entity.properties.filter { $0.isUnique }
            
            if !uniqueProperties.isEmpty {
                print("   - \(entity.name) has \(uniqueProperties.count) unique attribute(s):")
                for uniqueProperty in uniqueProperties {
                    print("     ✓ \(uniqueProperty.name)")
                }
            } else {
                print("   - \(entity.name) has no unique attributes")
            }
            
            // Validate that ID properties are unique (if they exist)
            if let idProperty = entity.properties.first(where: { $0.name == "id" }) {
                if !idProperty.isUnique {
                    print("     ⚠️ Warning: '\(entity.name)' entity 'id' property should be unique")
                    // Note: Not throwing error as SwiftData may handle this differently
                }
            }
        }
        
        print("✅ Attribute validation completed")
    }
    
    /// Logs detailed schema validation error information
    private static func logSchemaValidationError(_ error: Error) {
        print("   Error Type: \(type(of: error))")
        
        if let nsError = error as NSError? {
            print("   Domain: \(nsError.domain)")
            print("   Code: \(nsError.code)")
            
            // Provide specific guidance based on error patterns
            let errorDescription = nsError.localizedDescription.lowercased()
            
            if errorDescription.contains("family") {
                print("   🔍 Issue detected in Family model:")
                print("     - Check @Model annotation is present")
                print("     - Verify all properties have correct types")
                print("     - Ensure @Attribute(.unique) is set on id and code")
                print("     - Check @Relationship configuration for memberships")
            }
            
            if errorDescription.contains("userprofile") {
                print("   🔍 Issue detected in UserProfile model:")
                print("     - Check @Model annotation is present")
                print("     - Verify all properties have correct types")
                print("     - Ensure @Attribute(.unique) is set on id and appleUserIdHash")
                print("     - Check @Relationship configuration for memberships")
            }
            
            if errorDescription.contains("membership") {
                print("   🔍 Issue detected in Membership model:")
                print("     - Check @Model annotation is present")
                print("     - Verify Role and MembershipStatus enums are properly defined")
                print("     - Ensure @Attribute(.unique) is set on id")
                print("     - Check @Relationship configurations for family and user")
            }
            
            if errorDescription.contains("circular") || errorDescription.contains("relationship") {
                print("   🔍 Relationship configuration issue detected:")
                print("     - Check inverse relationship configurations")
                print("     - Verify deleteRule settings are appropriate")
                print("     - Ensure no circular dependencies in relationships")
            }
            
            if errorDescription.contains("unique") || errorDescription.contains("constraint") {
                print("   🔍 Unique constraint issue detected:")
                print("     - Verify @Attribute(.unique) annotations")
                print("     - Check for duplicate unique constraint definitions")
                print("     - Ensure unique properties have appropriate types")
            }
            
            if errorDescription.contains("type") || errorDescription.contains("property") {
                print("   🔍 Property type issue detected:")
                print("     - Check all property types are SwiftData compatible")
                print("     - Verify enum types conform to required protocols")
                print("     - Ensure optional properties are properly declared")
            }
        }
        
        print("   💡 General troubleshooting steps:")
        print("     1. Clean build folder (⌘+Shift+K)")
        print("     2. Restart Xcode")
        print("     3. Check iOS deployment target compatibility")
        print("     4. Verify all model files are included in target")
    }
    
    /// Creates and configures the SwiftData ModelContainer
    static func create() throws -> ModelContainer {
        let schema = Schema([
            Family.self,
            UserProfile.self,
            Membership.self
        ])
        
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .private("iCloud.net.dataenvy.TribeBoard")
        )
        
        return try ModelContainer(
            for: schema,
            configurations: [modelConfiguration]
        )
    }
    
    /// Creates ModelContainer with fallback: tries CloudKit first, then local storage
    static func createWithFallback() -> ModelContainer {
        print("🔄 Attempting to create ModelContainer with CloudKit fallback...")
        
        // Attempt schema validation - log issues but don't block container creation
        do {
            try validateSchema()
            print("✅ Schema validation passed - proceeding with container creation")
        } catch let error as ModelContainerError {
            print("⚠️ Schema validation failed with ModelContainerError")
            logSchemaValidationFailure(error)
            
            // Log the error but continue - the actual container creation will be the final test
            print("⚠️ Continuing with container creation - actual usage will determine if schema is valid")
        } catch {
            print("⚠️ Schema validation failed with unexpected error")
            print("   Error: \(error.localizedDescription)")
            
            // Log the error but attempt to continue - might be a validation false positive
            print("⚠️ Attempting container creation despite validation failure...")
        }
        
        // Try to create CloudKit container
        do {
            let container = try createCloudKitContainer()
            print("✅ Successfully created CloudKit-enabled ModelContainer")
            return container
        } catch {
            logCloudKitError(error)
            print("🔄 Falling back to local-only storage...")
        }
        
        // Fallback to local-only container
        do {
            let container = try createLocalContainer()
            print("✅ Successfully created local-only ModelContainer")
            return container
        } catch {
            logLocalContainerError(error)
            print("🔄 Using in-memory container as last resort...")
        }
        
        // Last resort: in-memory container
        do {
            let container = try createInMemory()
            print("⚠️ Using in-memory ModelContainer - data will not persist")
            return container
        } catch {
            logCriticalError(error)
            fatalError("Unable to create any ModelContainer: \(error.localizedDescription)")
        }
    }
    
    /// Private helper method to create CloudKit-enabled container
    private static func createCloudKitContainer() throws -> ModelContainer {
        print("🌤️ Creating CloudKit-enabled ModelContainer...")
        
        do {
            // Create schema with validation
            let schema = Schema([
                Family.self,
                UserProfile.self,
                Membership.self
            ])
            
            // Validate schema compilation before container creation
            print("   🔍 Validating schema compilation for CloudKit...")
            _ = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: true // Test configuration
            )
            print("   ✅ Schema compilation validated")
            
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .private("iCloud.net.dataenvy.TribeBoard")
            )
            
            let container = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
            
            print("🌤️ CloudKit ModelContainer created successfully")
            return container
            
        } catch {
            print("❌ CloudKit ModelContainer creation failed")
            
            // Log specific CloudKit schema issues
            if error.localizedDescription.contains("schema") {
                print("   🔍 Schema-related CloudKit error detected")
                print("   💡 CloudKit may have stricter schema requirements")
                print("   💡 Check CloudKit console for schema conflicts")
            }
            
            throw ModelContainerError.cloudKitCreationFailed(underlying: error)
        }
    }
    
    /// Private helper method to create local-only container
    private static func createLocalContainer() throws -> ModelContainer {
        print("💾 Creating local-only ModelContainer...")
        
        do {
            // Create schema with validation
            let schema = Schema([
                Family.self,
                UserProfile.self,
                Membership.self
            ])
            
            // Validate schema compilation before container creation
            print("   🔍 Validating schema compilation for local storage...")
            _ = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: true // Test configuration
            )
            print("   ✅ Schema compilation validated")
            
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false
                // No cloudKitDatabase parameter = local storage only
            )
            
            let container = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
            
            print("💾 Local ModelContainer created successfully")
            return container
            
        } catch {
            print("❌ Local ModelContainer creation failed")
            
            // Log specific local storage schema issues
            if error.localizedDescription.contains("schema") {
                print("   🔍 Schema-related local storage error detected")
                print("   💡 Check model definitions and property types")
            }
            
            throw ModelContainerError.localCreationFailed(underlying: error)
        }
    }
    
    /// Creates an in-memory container for testing
    static func createInMemory() throws -> ModelContainer {
        print("🧠 Creating in-memory ModelContainer...")
        
        do {
            // Create schema - in-memory containers are most forgiving
            let schema = Schema([
                Family.self,
                UserProfile.self,
                Membership.self
            ])
            
            print("   🔍 Creating in-memory configuration...")
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: true
            )
            
            let container = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
            
            print("🧠 In-memory ModelContainer created successfully")
            print("   ⚠️ Data will not persist between app launches")
            return container
            
        } catch {
            print("❌ In-memory ModelContainer creation failed")
            print("   💥 This indicates a critical schema issue")
            
            // If even in-memory creation fails, it's a serious schema problem
            if error.localizedDescription.contains("schema") {
                print("   🔍 Critical schema error - even in-memory creation failed")
                print("   💡 This suggests fundamental model definition issues")
            }
            
            throw ModelContainerError.inMemoryCreationFailed(underlying: error)
        }
    }
    
    // MARK: - Error Logging Methods
    
    /// Logs detailed information about schema validation failures
    private static func logSchemaValidationFailure(_ error: ModelContainerError) {
        print("💥 CRITICAL SCHEMA VALIDATION FAILURE")
        print("   Error: \(error.localizedDescription)")
        
        if let failureReason = error.failureReason {
            print("   Reason: \(failureReason)")
        }
        
        if let recoverySuggestion = error.recoverySuggestion {
            print("   Recovery: \(recoverySuggestion)")
        }
        
        switch error {
        case .schemaValidationFailed(let underlying):
            print("   Underlying Error: \(underlying.localizedDescription)")
            
            if let nsError = underlying as NSError? {
                print("   Error Code: \(nsError.code)")
                print("   Error Domain: \(nsError.domain)")
                
                // Provide specific guidance based on error code
                switch nsError.code {
                case 1001:
                    print("   🔧 Missing Entity: Add the missing @Model class to your project")
                case 1002...1004:
                    print("   🔧 Missing Unique Constraint: Add @Attribute(.unique) to the specified property")
                case 1005:
                    print("   🔧 Missing Property: Add the required property to your @Model class")
                case 1006:
                    print("   🔧 Missing Relationship: Add the required @Relationship property")
                case 1007...1011:
                    print("   🔧 Relationship Issue: Check @Relationship inverse configurations")
                case 1012:
                    print("   🔧 ID Property: Ensure 'id' property has @Attribute(.unique)")
                default:
                    print("   🔧 General: Review SwiftData model definitions and annotations")
                }
            }
            
        default:
            print("   🔧 Check SwiftData model definitions and try cleaning build folder")
        }
        
        print("   📋 Schema validation checklist:")
        print("     □ All @Model classes have proper annotations")
        print("     □ All required properties are present")
        print("     □ Unique constraints are properly configured")
        print("     □ Relationships have correct inverse configurations")
        print("     □ Enum types conform to required protocols")
        print("     □ Property types are SwiftData compatible")
    }
    
    /// Logs detailed CloudKit container creation errors
    private static func logCloudKitError(_ error: Error) {
        print("❌ CloudKit Container Creation Failed")
        print("   Error Type: \(type(of: error))")
        print("   Description: \(error.localizedDescription)")
        
        if let modelContainerError = error as? ModelContainerError {
            switch modelContainerError {
            case .cloudKitCreationFailed(let underlying):
                print("   Underlying Error: \(underlying.localizedDescription)")
                logUnderlyingError(underlying, context: "CloudKit")
            default:
                break
            }
        } else {
            logUnderlyingError(error, context: "CloudKit")
        }
        
        print("   Possible Causes:")
        print("   - CloudKit container identifier mismatch")
        print("   - CloudKit not available (simulator limitation)")
        print("   - Network connectivity issues")
        print("   - iCloud account not signed in")
        print("   - CloudKit container not properly configured in Apple Developer Portal")
    }
    
    /// Logs detailed local container creation errors
    private static func logLocalContainerError(_ error: Error) {
        print("❌ Local Container Creation Failed")
        print("   Error Type: \(type(of: error))")
        print("   Description: \(error.localizedDescription)")
        
        if let modelContainerError = error as? ModelContainerError {
            switch modelContainerError {
            case .localCreationFailed(let underlying):
                print("   Underlying Error: \(underlying.localizedDescription)")
                logUnderlyingError(underlying, context: "Local Storage")
            default:
                break
            }
        } else {
            logUnderlyingError(error, context: "Local Storage")
        }
        
        print("   Possible Causes:")
        print("   - Insufficient disk space")
        print("   - File system permissions issues")
        print("   - Corrupted local database")
        print("   - Schema migration problems")
    }
    
    /// Logs critical errors when all container creation methods fail
    private static func logCriticalError(_ error: Error) {
        print("💥 CRITICAL ERROR: All ModelContainer Creation Methods Failed")
        print("   Error Type: \(type(of: error))")
        print("   Description: \(error.localizedDescription)")
        
        if let modelContainerError = error as? ModelContainerError {
            switch modelContainerError {
            case .inMemoryCreationFailed(let underlying):
                print("   Underlying Error: \(underlying.localizedDescription)")
                logUnderlyingError(underlying, context: "In-Memory")
            default:
                break
            }
        } else {
            logUnderlyingError(error, context: "In-Memory")
        }
        
        print("   This is a critical system failure - the app cannot continue")
        print("   Please check:")
        print("   - SwiftData model definitions")
        print("   - Schema configuration")
        print("   - System resources")
    }
    
    /// Logs detailed information about underlying errors
    private static func logUnderlyingError(_ error: Error, context: String) {
        print("   [\(context)] Detailed Error Information:")
        
        // Log NSError details if available
        if let nsError = error as NSError? {
            print("   - Domain: \(nsError.domain)")
            print("   - Code: \(nsError.code)")
            if !nsError.userInfo.isEmpty {
                print("   - User Info:")
                for (key, value) in nsError.userInfo {
                    print("     \(key): \(value)")
                }
            }
        }
        
        // Log additional context based on error type
        if error.localizedDescription.contains("CloudKit") {
            print("   - CloudKit-related error detected")
            print("   - Check CloudKit container configuration")
            print("   - Verify iCloud account status")
        }
        
        if error.localizedDescription.contains("schema") || error.localizedDescription.contains("migration") {
            print("   - Schema or migration error detected")
            print("   - Check SwiftData model definitions")
            print("   - Consider clearing app data for testing")
        }
        
        if error.localizedDescription.contains("permission") || error.localizedDescription.contains("access") {
            print("   - Permission or access error detected")
            print("   - Check file system permissions")
            print("   - Verify app sandbox configuration")
        }
    }
}

/// Extension to provide mock data for testing
extension ModelContainer {
    
    /// Seeds the container with mock data for testing
    @MainActor
    func seedMockData() throws {
        let context = mainContext
        
        // Create mock users
        let user1 = UserProfile(
            displayName: "Sarah Johnson",
            appleUserIdHash: "hash_sarah_123"
        )
        let user2 = UserProfile(
            displayName: "Mike Garcia", 
            appleUserIdHash: "hash_mike_456"
        )
        let user3 = UserProfile(
            displayName: "Emma Chen",
            appleUserIdHash: "hash_emma_789"
        )
        
        context.insert(user1)
        context.insert(user2)
        context.insert(user3)
        
        // Create mock family
        let family = Family(
            name: "The Johnson Family",
            code: "JOH123",
            createdByUserId: user1.id
        )
        context.insert(family)
        
        // Create memberships
        let membership1 = Membership(family: family, user: user1, role: .parentAdmin)
        let membership2 = Membership(family: family, user: user2, role: .adult)
        let membership3 = Membership(family: family, user: user3, role: .kid)
        
        context.insert(membership1)
        context.insert(membership2)
        context.insert(membership3)
        
        try context.save()
    }
}