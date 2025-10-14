import Foundation

/// Data structure containing predefined family information for sample generation
struct SampleFamilyData {
    let name: String
    let members: [SampleMemberData]
}

/// Data structure for sample member information
struct SampleMemberData {
    let displayName: String
    let role: Role
    let appleUserIdHash: String // Generated unique hash for testing
}

/// Information about a generated family for output and reference
struct GeneratedFamilyInfo {
    let family: Family
    let code: String
    let memberCount: Int
}

/// Error types specific to sample data generation
/// Conforms to LocalizedError for proper error reporting and integrates with ErrorHandlingUtilities
enum SampleDataError: LocalizedError {
    case familyAlreadyExists(String)
    case codeGenerationFailed
    case memberCreationFailed(String)
    case partialCreationFailure([String])
    case dataServiceUnavailable
    case validationFailed(String)
    case databaseError(Error)
    case networkError(Error)
    case unknownError(String)
    
    // MARK: - LocalizedError Conformance
    
    var errorDescription: String? {
        switch self {
        case .familyAlreadyExists(let name):
            return "Sample family '\(name)' already exists"
        case .codeGenerationFailed:
            return "Failed to generate unique family code after multiple attempts"
        case .memberCreationFailed(let name):
            return "Failed to create member '\(name)'"
        case .partialCreationFailure(let failures):
            return "Partial creation failure: \(failures.joined(separator: ", "))"
        case .dataServiceUnavailable:
            return "Data service is not available"
        case .validationFailed(let details):
            return "Data validation failed: \(details)"
        case .databaseError(let error):
            return "Database error: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .unknownError(let message):
            return "Unknown error: \(message)"
        }
    }
    
    var failureReason: String? {
        switch self {
        case .familyAlreadyExists:
            return "The sample family data has already been generated in the database"
        case .codeGenerationFailed:
            return "Unable to generate a unique family code due to conflicts with existing families"
        case .memberCreationFailed:
            return "Failed to create one or more family members due to validation or database errors"
        case .partialCreationFailure:
            return "Some families were created successfully, but others failed"
        case .dataServiceUnavailable:
            return "The data service required for family creation is not properly initialized"
        case .validationFailed:
            return "The provided data does not meet the required validation criteria"
        case .databaseError:
            return "An error occurred while accessing the database"
        case .networkError:
            return "A network error prevented the operation from completing"
        case .unknownError:
            return "An unexpected error occurred during sample data generation"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .familyAlreadyExists:
            return "The sample families are already available for testing. Check the console output for family codes."
        case .codeGenerationFailed:
            return "Try again later, or manually clear some existing families to free up code space."
        case .memberCreationFailed:
            return "Check the console logs for specific member creation errors and ensure all required data is valid."
        case .partialCreationFailure:
            return "Some families were created successfully. Check the console for details and try generating again for the failed families."
        case .dataServiceUnavailable:
            return "Ensure the app is properly initialized and try again."
        case .validationFailed:
            return "Check the data format and ensure all required fields are properly filled."
        case .databaseError:
            return "Check your database connection and try again. If the problem persists, restart the app."
        case .networkError:
            return "Check your internet connection and try again."
        case .unknownError:
            return "Try restarting the app. If the problem persists, check the console logs for more details."
        }
    }
    
    // MARK: - Error Classification for ErrorHandlingUtilities Integration
    
    /// Returns the error category for integration with ErrorHandlingUtilities
    var category: ErrorCategory {
        switch self {
        case .familyAlreadyExists, .partialCreationFailure:
            return .data
        case .codeGenerationFailed:
            return .codeGeneration
        case .memberCreationFailed, .validationFailed:
            return .validation
        case .dataServiceUnavailable, .databaseError:
            return .localDatabase
        case .networkError:
            return .network
        case .unknownError:
            return .system
        }
    }
    
    /// Returns the error priority for logging and handling decisions
    var priority: ErrorPriority {
        switch self {
        case .familyAlreadyExists:
            return .low // This is expected behavior (idempotency)
        case .codeGenerationFailed, .memberCreationFailed, .validationFailed:
            return .medium
        case .partialCreationFailure:
            return .medium
        case .dataServiceUnavailable, .databaseError:
            return .high
        case .networkError:
            return .medium
        case .unknownError:
            return .high
        }
    }
    
    /// Returns whether this error is retryable
    var isRetryable: Bool {
        switch self {
        case .familyAlreadyExists:
            return false // No need to retry if families already exist
        case .codeGenerationFailed:
            return true // Can retry with different code generation
        case .memberCreationFailed, .validationFailed:
            return false // Need to fix data first
        case .partialCreationFailure:
            return true // Can retry for failed families
        case .dataServiceUnavailable:
            return true // Service might become available
        case .databaseError, .networkError:
            return true // Transient errors
        case .unknownError:
            return true // Might be transient
        }
    }
    
    /// Returns user-friendly message for display in UI
    var userFriendlyMessage: String {
        switch self {
        case .familyAlreadyExists:
            return "Sample families are already available for testing."
        case .codeGenerationFailed:
            return "Unable to generate unique family codes. Please try again later."
        case .memberCreationFailed:
            return "Failed to create some family members. Please check the data and try again."
        case .partialCreationFailure:
            return "Some families were created successfully. Check the console for details."
        case .dataServiceUnavailable:
            return "Service temporarily unavailable. Please try again."
        case .validationFailed:
            return "Invalid data provided. Please check the input and try again."
        case .databaseError:
            return "Database error occurred. Please try again or restart the app."
        case .networkError:
            return "Network error occurred. Please check your connection and try again."
        case .unknownError:
            return "An unexpected error occurred. Please try again or restart the app."
        }
    }
    
    /// Returns technical description for logging and debugging
    var technicalDescription: String {
        switch self {
        case .familyAlreadyExists(let name):
            return "SampleDataError.familyAlreadyExists: Family '\(name)' exists in database"
        case .codeGenerationFailed:
            return "SampleDataError.codeGenerationFailed: Exhausted retry attempts for unique code generation"
        case .memberCreationFailed(let name):
            return "SampleDataError.memberCreationFailed: Failed to create member '\(name)'"
        case .partialCreationFailure(let failures):
            return "SampleDataError.partialCreationFailure: Failures: [\(failures.joined(separator: ", "))]"
        case .dataServiceUnavailable:
            return "SampleDataError.dataServiceUnavailable: DataService instance not available"
        case .validationFailed(let details):
            return "SampleDataError.validationFailed: \(details)"
        case .databaseError(let error):
            return "SampleDataError.databaseError: \(error)"
        case .networkError(let error):
            return "SampleDataError.networkError: \(error)"
        case .unknownError(let message):
            return "SampleDataError.unknownError: \(message)"
        }
    }
}

// MARK: - Error Conversion Extension

/// Extension to convert SampleDataError to FamilyCreationError where required
/// Maintains error context and information during conversion
extension SampleDataError {
    /// Converts SampleDataError to FamilyCreationError
    /// - Returns: Equivalent FamilyCreationError with preserved context
    func toFamilyCreationError() -> FamilyCreationError {
        switch self {
        case .familyAlreadyExists:
            return .familyAlreadyExists
        case .codeGenerationFailed:
            return .codeGenerationFailed
        case .memberCreationFailed(let message):
            return .validationFailed("Member creation failed: \(message)")
        case .partialCreationFailure(let failures):
            return .validationFailed("Partial creation failure: \(failures.joined(separator: ", "))")
        case .dataServiceUnavailable:
            return .unknownError("Data service unavailable")
        case .validationFailed(let details):
            return .validationFailed(details)
        case .databaseError(let error):
            return .unknownError("Database error: \(error.localizedDescription)")
        case .networkError(let error):
            return .networkUnavailable
        case .unknownError(let message):
            return .unknownError(message)
        }
    }
}

/// Main utility class for generating sample families for testing
class SampleFamilyDataGenerator {
    private let dataService: DataService?
    private let mockDataService: MockDataService?
    
    init(dataService: DataService) {
        self.dataService = dataService
        self.mockDataService = nil
    }
    
    init(mockDataService: MockDataService) {
        self.dataService = nil
        self.mockDataService = mockDataService
    }
    
    // MARK: - Service Abstraction Helpers
    
    private func createFamily(name: String, code: String, createdByUserId: UUID) async throws -> Family {
        if let dataService = dataService {
            return try await dataService.createFamily(name: name, code: code, createdByUserId: createdByUserId)
        } else if let mockDataService = mockDataService {
            return try await mockDataService.createFamily(name: name, code: code, createdByUserId: createdByUserId)
        } else {
            throw SampleDataError.dataServiceUnavailable
        }
    }
    
    private func fetchUserProfile(byAppleUserIdHash hash: String) async throws -> UserProfile? {
        if let dataService = dataService {
            return try await dataService.fetchUserProfile(byAppleUserIdHash: hash)
        } else if let mockDataService = mockDataService {
            return try await mockDataService.fetchUserProfile(byAppleUserIdHash: hash)
        } else {
            throw SampleDataError.dataServiceUnavailable
        }
    }
    
    private func createUserProfile(displayName: String, appleUserIdHash: String) async throws -> UserProfile {
        if let dataService = dataService {
            return try await dataService.createUserProfile(displayName: displayName, appleUserIdHash: appleUserIdHash)
        } else if let mockDataService = mockDataService {
            return try await mockDataService.createUserProfile(displayName: displayName, appleUserIdHash: appleUserIdHash)
        } else {
            throw SampleDataError.dataServiceUnavailable
        }
    }
    
    private func createMembership(family: Family, user: UserProfile, role: Role) async throws -> Membership {
        if let dataService = dataService {
            return try await dataService.createMembership(family: family, user: user, role: role)
        } else if let mockDataService = mockDataService {
            return try await mockDataService.createMembership(family: family, user: user, role: role)
        } else {
            throw SampleDataError.dataServiceUnavailable
        }
    }
    
    private func fetchFamily(byCode code: String) async throws -> Family? {
        if let dataService = dataService {
            return try await dataService.fetchFamily(byCode: code)
        } else if let mockDataService = mockDataService {
            return try await mockDataService.fetchFamily(byCode: code)
        } else {
            throw SampleDataError.dataServiceUnavailable
        }
    }
    
    private func fetchAllFamilies() async throws -> [Family] {
        if let dataService = dataService {
            return try await dataService.fetchAllFamilies()
        } else if let mockDataService = mockDataService {
            return try await mockDataService.fetchAllFamilies()
        } else {
            throw SampleDataError.dataServiceUnavailable
        }
    }
    
    /// Predefined sample family data for consistent testing
    private static let sampleFamilies: [SampleFamilyData] = [
        SampleFamilyData(
            name: "The Johnson Family",
            members: [
                SampleMemberData(displayName: "Sarah Johnson", role: .parentAdmin, appleUserIdHash: "sample_sarah_johnson_001"),
                SampleMemberData(displayName: "Mike Johnson", role: .adult, appleUserIdHash: "sample_mike_johnson_002"),
                SampleMemberData(displayName: "Emma Johnson", role: .kid, appleUserIdHash: "sample_emma_johnson_003"),
                SampleMemberData(displayName: "Jake Johnson", role: .kid, appleUserIdHash: "sample_jake_johnson_004")
            ]
        ),
        SampleFamilyData(
            name: "The Garcia Household",
            members: [
                SampleMemberData(displayName: "Carlos Garcia", role: .parentAdmin, appleUserIdHash: "sample_carlos_garcia_005"),
                SampleMemberData(displayName: "Maria Garcia", role: .adult, appleUserIdHash: "sample_maria_garcia_006"),
                SampleMemberData(displayName: "Sofia Garcia", role: .kid, appleUserIdHash: "sample_sofia_garcia_007")
            ]
        ),
        SampleFamilyData(
            name: "The Chen Family",
            members: [
                SampleMemberData(displayName: "Li Chen", role: .parentAdmin, appleUserIdHash: "sample_li_chen_008"),
                SampleMemberData(displayName: "Wei Chen", role: .adult, appleUserIdHash: "sample_wei_chen_009"),
                SampleMemberData(displayName: "Amy Chen", role: .kid, appleUserIdHash: "sample_amy_chen_010"),
                SampleMemberData(displayName: "David Chen", role: .kid, appleUserIdHash: "sample_david_chen_011"),
                SampleMemberData(displayName: "Grace Chen", role: .kid, appleUserIdHash: "sample_grace_chen_012")
            ]
        ),
        SampleFamilyData(
            name: "The Williams Home",
            members: [
                SampleMemberData(displayName: "Jennifer Williams", role: .parentAdmin, appleUserIdHash: "sample_jennifer_williams_013"),
                SampleMemberData(displayName: "Robert Williams", role: .adult, appleUserIdHash: "sample_robert_williams_014"),
                SampleMemberData(displayName: "Tyler Williams", role: .kid, appleUserIdHash: "sample_tyler_williams_015")
            ]
        ),
        SampleFamilyData(
            name: "The Anderson Family",
            members: [
                SampleMemberData(displayName: "Mark Anderson", role: .parentAdmin, appleUserIdHash: "sample_mark_anderson_016"),
                SampleMemberData(displayName: "Lisa Anderson", role: .adult, appleUserIdHash: "sample_lisa_anderson_017"),
                SampleMemberData(displayName: "Chloe Anderson", role: .kid, appleUserIdHash: "sample_chloe_anderson_018"),
                SampleMemberData(displayName: "Noah Anderson", role: .kid, appleUserIdHash: "sample_noah_anderson_019")
            ]
        )
    ]
    
    /// Main generation method - creates all sample families
    /// - Returns: Array of GeneratedFamilyInfo containing family details and codes
    func generateSampleFamilies() async throws -> [GeneratedFamilyInfo] {
        return try await generateSampleFamiliesInternal()
    }
    
    /// Alternative generation method that throws FamilyCreationError for integration with family creation systems
    /// - Returns: Array of GeneratedFamilyInfo containing family details and codes
    /// - Throws: FamilyCreationError for compatibility with family creation error handling
    func generateSampleFamiliesWithFamilyCreationError() async throws(FamilyCreationError) -> [GeneratedFamilyInfo] {
        do {
            return try await generateSampleFamilies()
        } catch let error as SampleDataError {
            throw error.toFamilyCreationError()
        } catch {
            throw FamilyCreationError.unknownError("Unexpected error during sample family generation: \(error.localizedDescription)")
        }
    }
    
    /// Internal implementation of sample family generation
    /// - Returns: Array of GeneratedFamilyInfo containing family details and codes
    private func generateSampleFamiliesInternal() async throws -> [GeneratedFamilyInfo] {
        let startTime = Date()
        reportOperationStart()
        
        // Log operation start
        let startError = SampleDataError.unknownError("Operation started")
        let startContext = ErrorContext(
            error: startError.toFamilyCreationError(),
            retryCount: 0,
            userContext: ["operation": "generateSampleFamilies", "timestamp": startTime.timeIntervalSince1970]
        )
        let logError = SampleDataError.unknownError("Sample family generation started")
        ErrorHandlingUtilities.logError(
            logError.toFamilyCreationError(),
            context: startContext,
            additionalInfo: ["target_families": Self.sampleFamilies.count]
        )
        
        // Check for existing sample families first
        let existingFamilies = try await checkExistingFamilies()
        if !existingFamilies.isEmpty {
            reportIdempotentBehavior(existingFamilies: existingFamilies)
            outputFamilyCodes(existingFamilies)
            return existingFamilies
        }
        
        var generatedFamilies: [GeneratedFamilyInfo] = []
        var failures: [String] = []
        var skippedFamilies: [String] = []
        
        reportCreationStart(totalFamilies: Self.sampleFamilies.count)
        
        // Generate each sample family
        for (index, familyData) in Self.sampleFamilies.enumerated() {
            let familyNumber = index + 1
            reportFamilyCreationStart(familyNumber: familyNumber, familyName: familyData.name)
            
            do {
                let generatedFamily = try await createSampleFamily(data: familyData)
                generatedFamilies.append(generatedFamily)
                reportFamilyCreationSuccess(
                    familyNumber: familyNumber,
                    familyName: familyData.name,
                    code: generatedFamily.code,
                    memberCount: generatedFamily.memberCount
                )
            } catch {
                let errorMessage = "Failed to create '\(familyData.name)': \(error.localizedDescription)"
                failures.append(errorMessage)
                reportFamilyCreationFailure(
                    familyNumber: familyNumber,
                    familyName: familyData.name,
                    error: error
                )
                
                // Log the error with proper categorization
                let categorizedError = categorizeError(error)
                let errorContext = ErrorContext(
                    error: categorizedError.toFamilyCreationError(),
                    retryCount: 0,
                    userContext: [
                        "family_name": familyData.name,
                        "family_number": familyNumber,
                        "operation": "createSampleFamily"
                    ]
                )
                ErrorHandlingUtilities.logError(categorizedError.toFamilyCreationError(), context: errorContext)
            }
        }
        
        // Report final operation status
        let duration = Date().timeIntervalSince(startTime)
        reportOperationComplete(
            created: generatedFamilies.count,
            failed: failures.count,
            skipped: skippedFamilies.count,
            duration: duration
        )
        
        // Handle partial failures
        if !failures.isEmpty && generatedFamilies.isEmpty {
            reportCompleteFailure(failures: failures)
            throw SampleDataError.partialCreationFailure(failures)
        }
        
        if !failures.isEmpty {
            reportPartialSuccess(failures: failures)
        }
        
        // Output the generated family codes
        if !generatedFamilies.isEmpty {
            outputFamilyCodes(generatedFamilies)
        }
        
        // Log final operation status
        let finalError = SampleDataError.unknownError("Operation completed")
        let finalContext = ErrorContext(
            error: finalError.toFamilyCreationError(),
            retryCount: 0,
            userContext: [
                "operation": "generateSampleFamilies",
                "duration": duration,
                "created_count": generatedFamilies.count,
                "failed_count": failures.count,
                "total_families": Self.sampleFamilies.count
            ]
        )
        
        if failures.isEmpty {
            let successError = SampleDataError.unknownError("Sample family generation completed successfully")
            ErrorHandlingUtilities.logError(
                successError.toFamilyCreationError(),
                context: finalContext
            )
        } else {
            let partialError = SampleDataError.partialCreationFailure(failures)
            ErrorHandlingUtilities.logError(
                partialError.toFamilyCreationError(),
                context: finalContext
            )
        }
        
        return generatedFamilies
    }
    
    // MARK: - Error Handling Integration
    
    /// Categorizes errors for integration with ErrorHandlingUtilities
    /// - Parameter error: The error to categorize
    /// - Returns: A SampleDataError with proper categorization
    private func categorizeError(_ error: Error) -> SampleDataError {
        // If it's already a SampleDataError, return as-is
        if let sampleError = error as? SampleDataError {
            return sampleError
        }
        
        // If it's a FamilyCreationError, map to appropriate SampleDataError
        if let familyError = error as? FamilyCreationError {
            switch familyError {
            case .invalidFamilyName, .emptyFamilyName:
                return .validationFailed(familyError.localizedDescription)
            case .codeGenerationFailed:
                return .codeGenerationFailed
            case .userNotFound:
                return .dataServiceUnavailable
            case .familyAlreadyExists:
                return .familyAlreadyExists(familyError.localizedDescription)
            case .operationCancelled:
                return .unknownError("Operation cancelled: \(familyError.localizedDescription)")
            case .unknownError(let message):
                return .unknownError(message ?? "Unknown error")
            case .networkUnavailable, .connectionTimeout:
                return .networkError(error)
            case .serverError(let code):
                return .networkError(NSError(domain: "ServerError", code: code, userInfo: [NSLocalizedDescriptionKey: "Server error with code \(code)"]))
            case .cloudKitUnavailable, .cloudKitSyncFailed:
                return .databaseError(error)
            case .quotaExceeded:
                return .databaseError(NSError(domain: "CloudKitError", code: -1, userInfo: [NSLocalizedDescriptionKey: "iCloud storage quota exceeded"]))
            case .userNotAuthenticated, .insufficientPermissions, .accountNotAvailable:
                return .dataServiceUnavailable
            case .validationFailed(let message):
                return .validationFailed(message)
            case .constraintViolation(let message):
                return .validationFailed("Constraint violation: \(message)")
            case .dataCorruption(let message):
                return .databaseError(NSError(domain: "DataCorruption", code: -1, userInfo: [NSLocalizedDescriptionKey: message]))
            }
        }
        
        // Check for network-related errors
        if let nsError = error as? NSError {
            if nsError.domain == NSURLErrorDomain {
                return .networkError(error)
            }
        }
        
        // Check error description for common patterns
        let errorDescription = error.localizedDescription.lowercased()
        
        if errorDescription.contains("validation") {
            return .validationFailed(error.localizedDescription)
        } else if errorDescription.contains("network") || errorDescription.contains("connection") {
            return .networkError(error)
        } else if errorDescription.contains("database") || errorDescription.contains("core data") {
            return .databaseError(error)
        } else if errorDescription.contains("code") && errorDescription.contains("generation") {
            return .codeGenerationFailed
        } else {
            return .unknownError(error.localizedDescription)
        }
    }
    
    // MARK: - Private Helper Methods
    
    /// Creates a single sample family with all its members
    /// - Parameter data: The sample family data to create
    /// - Returns: GeneratedFamilyInfo with family details
    private func createSampleFamily(data: SampleFamilyData) async throws -> GeneratedFamilyInfo {
        print("🏠 SampleFamilyDataGenerator: Creating family '\(data.name)'...")
        
        // Validate family data before creation
        guard !data.name.isEmpty else {
            let error = SampleDataError.validationFailed("Family name cannot be empty")
            let context = ErrorContext(error: error.toFamilyCreationError(), userContext: ["family_name": data.name])
            ErrorHandlingUtilities.logError(error.toFamilyCreationError(), context: context)
            throw error
        }
        
        guard data.members.count >= 1 else {
            throw SampleDataError.memberCreationFailed("Family must have at least one member")
        }
        
        // Ensure there's exactly one parent admin
        let adminMembers = data.members.filter { $0.role == .parentAdmin }
        guard adminMembers.count == 1 else {
            throw SampleDataError.memberCreationFailed("Family must have exactly one parent admin")
        }
        
        // Generate unique family code using existing utility
        let familyCode = try await generateUniqueFamilyCode()
        
        // Get the admin member for family creation
        guard let adminMember = data.members.first(where: { $0.role == .parentAdmin }) else {
            throw SampleDataError.memberCreationFailed("No parent admin found in family data")
        }
        
        // Create a temporary admin user ID for family creation (will be replaced with actual user)
        let tempAdminUserId = UUID()
        
        // Create the family using existing DataService patterns
        let family: Family
        do {
            family = try await createFamily(
                name: data.name,
                code: familyCode,
                createdByUserId: tempAdminUserId
            )
        } catch {
            // Convert DataService errors to SampleDataError for consistency
            if let dataServiceError = error as? DataServiceError {
                switch dataServiceError {
                case .validationFailed(let errors):
                    throw SampleDataError.validationFailed("Family creation validation failed: \(errors.joined(separator: ", "))")
                case .invalidData(let message):
                    throw SampleDataError.validationFailed("Invalid family data: \(message)")
                case .notFound(let message):
                    throw SampleDataError.dataServiceUnavailable
                case .constraintViolation(let message):
                    throw SampleDataError.validationFailed("Constraint violation: \(message)")
                case .unknownError:
                    throw SampleDataError.unknownError("DataService unknown error during family creation")
                }
            } else {
                throw SampleDataError.unknownError("Unexpected error during family creation: \(error.localizedDescription)")
            }
        }
        
        // Validate family was created successfully
        guard family.isFullyValid else {
            throw SampleDataError.memberCreationFailed("Created family failed validation")
        }
        
        print("✅ SampleFamilyDataGenerator: Family '\(data.name)' created with code '\(familyCode)'")
        
        // Create all sample users for this family
        let users = try await createSampleUsers(for: data)
        
        // Create memberships linking users to the family
        try await createMemberships(family: family, users: users, familyData: data)
        
        return GeneratedFamilyInfo(
            family: family,
            code: familyCode,
            memberCount: data.members.count
        )
    }
    
    /// Creates sample users for a family
    /// Generates realistic Apple ID hashes and validates user data meets existing model requirements
    /// - Parameter familyData: The family data containing member information
    /// - Returns: Array of created UserProfile instances
    private func createSampleUsers(for familyData: SampleFamilyData) async throws -> [UserProfile] {
        print("👥 SampleFamilyDataGenerator: Creating \(familyData.members.count) users for '\(familyData.name)'...")
        
        var users: [UserProfile] = []
        
        for memberData in familyData.members {
            // Validate member data before creation
            guard !memberData.displayName.isEmpty else {
                throw SampleDataError.memberCreationFailed("Display name cannot be empty for member")
            }
            
            guard !memberData.appleUserIdHash.isEmpty else {
                throw SampleDataError.memberCreationFailed("Apple user ID hash cannot be empty for '\(memberData.displayName)'")
            }
            
            // Generate realistic Apple ID hash if needed (ensure it's unique and realistic)
            let appleUserIdHash = generateRealisticAppleIdHash(for: memberData)
            
            do {
                // Check if user already exists with this Apple ID hash
                let existingUser = try await fetchUserProfile(byAppleUserIdHash: appleUserIdHash)
                if existingUser != nil {
                    throw SampleDataError.memberCreationFailed("User with Apple ID hash already exists: '\(memberData.displayName)'")
                }
                
                // Create user using existing DataService patterns
                let user = try await createUserProfile(
                    displayName: memberData.displayName,
                    appleUserIdHash: appleUserIdHash
                )
                
                // Validate created user meets model requirements
                guard user.isFullyValid else {
                    throw SampleDataError.memberCreationFailed("Created user '\(memberData.displayName)' failed validation")
                }
                
                users.append(user)
                print("✅ SampleFamilyDataGenerator: Created user '\(memberData.displayName)' with hash '\(appleUserIdHash)'")
                
            } catch let error as SampleDataError {
                // Re-throw SampleDataError as-is
                throw error
            } catch {
                // Convert DataService errors to SampleDataError
                if let dataServiceError = error as? DataServiceError {
                    switch dataServiceError {
                    case .validationFailed(let errors):
                        throw SampleDataError.memberCreationFailed("User validation failed for '\(memberData.displayName)': \(errors.joined(separator: ", "))")
                    case .invalidData(let message):
                        throw SampleDataError.memberCreationFailed("Invalid user data for '\(memberData.displayName)': \(message)")
                    case .notFound(let message):
                        throw SampleDataError.memberCreationFailed("User creation failed for '\(memberData.displayName)': \(message)")
                    case .constraintViolation(let message):
                        throw SampleDataError.memberCreationFailed("Constraint violation for '\(memberData.displayName)': \(message)")
                    case .unknownError:
                        throw SampleDataError.memberCreationFailed("Unknown error creating user '\(memberData.displayName)'")
                    }
                } else {
                    let errorMessage = "Failed to create user '\(memberData.displayName)': \(error.localizedDescription)"
                    print("❌ SampleFamilyDataGenerator: \(errorMessage)")
                    throw SampleDataError.memberCreationFailed(errorMessage)
                }
            }
        }
        
        print("✅ SampleFamilyDataGenerator: Successfully created \(users.count) users")
        return users
    }
    
    /// Generates a realistic Apple ID hash for testing purposes
    /// Ensures the hash is unique and meets the expected format requirements
    /// - Parameter memberData: The member data to generate hash for
    /// - Returns: A realistic Apple ID hash string
    private func generateRealisticAppleIdHash(for memberData: SampleMemberData) -> String {
        // Use the provided hash if it's already realistic, otherwise enhance it
        let baseHash = memberData.appleUserIdHash
        
        // Ensure the hash is long enough and realistic for testing
        if baseHash.count >= 20 {
            return baseHash
        }
        
        // Generate a more realistic hash format for testing
        let timestamp = String(Int(Date().timeIntervalSince1970))
        let nameHash = memberData.displayName.replacingOccurrences(of: " ", with: "_").lowercased()
        let randomSuffix = String((0..<8).map { _ in "abcdefghijklmnopqrstuvwxyz0123456789".randomElement()! })
        
        return "sample_\(nameHash)_\(timestamp)_\(randomSuffix)"
    }
    
    /// Creates memberships linking users to the family with proper roles
    /// Ensures proper role assignment including parent_admin constraints using existing DataService patterns
    /// - Parameters:
    ///   - family: The family to create memberships for
    ///   - users: The users to create memberships for
    ///   - familyData: The original family data containing role information
    private func createMemberships(family: Family, users: [UserProfile], familyData: SampleFamilyData) async throws {
        print("🔗 SampleFamilyDataGenerator: Creating memberships for '\(family.name)'...")
        
        // Validate input parameters
        guard users.count == familyData.members.count else {
            throw SampleDataError.memberCreationFailed("User count (\(users.count)) doesn't match member data count (\(familyData.members.count))")
        }
        
        guard !users.isEmpty else {
            throw SampleDataError.memberCreationFailed("Cannot create memberships for empty user list")
        }
        
        // Validate role constraints before creating any memberships
        let adminRoles = familyData.members.filter { $0.role == .parentAdmin }
        guard adminRoles.count == 1 else {
            throw SampleDataError.memberCreationFailed("Family must have exactly one parent admin, found \(adminRoles.count)")
        }
        
        // Create memberships for each user with their corresponding role
        var createdMemberships: [Membership] = []
        
        for (index, user) in users.enumerated() {
            let memberData = familyData.members[index]
            
            // Validate user and role data
            guard user.isFullyValid else {
                throw SampleDataError.memberCreationFailed("User '\(user.displayName)' is not valid")
            }
            
            do {
                // Use existing DataService membership creation patterns
                let membership = try await createMembership(
                    family: family,
                    user: user,
                    role: memberData.role
                )
                
                // Validate created membership
                guard membership.isFullyValid else {
                    throw SampleDataError.memberCreationFailed("Created membership for '\(user.displayName)' failed validation")
                }
                
                // Verify role assignment is correct
                guard membership.role == memberData.role else {
                    throw SampleDataError.memberCreationFailed("Membership role mismatch for '\(user.displayName)': expected \(memberData.role), got \(membership.role)")
                }
                
                createdMemberships.append(membership)
                print("✅ SampleFamilyDataGenerator: Created membership for '\(user.displayName)' as '\(memberData.role.displayName)'")
                
            } catch let error as SampleDataError {
                // Re-throw SampleDataError as-is
                throw error
            } catch {
                // Convert DataService errors to SampleDataError
                if let dataServiceError = error as? DataServiceError {
                    switch dataServiceError {
                    case .validationFailed(let errors):
                        throw SampleDataError.memberCreationFailed("Membership validation failed for '\(user.displayName)': \(errors.joined(separator: ", "))")
                    case .invalidData(let message):
                        throw SampleDataError.memberCreationFailed("Invalid membership data for '\(user.displayName)': \(message)")
                    case .notFound(let message):
                        throw SampleDataError.memberCreationFailed("Membership creation failed for '\(user.displayName)': \(message)")
                    case .constraintViolation(let message):
                        throw SampleDataError.memberCreationFailed("Membership constraint violation for '\(user.displayName)': \(message)")
                    case .unknownError:
                        throw SampleDataError.memberCreationFailed("Unknown error creating membership for '\(user.displayName)'")
                    }
                } else {
                    let errorMessage = "Failed to create membership for '\(user.displayName)' with role '\(memberData.role.displayName)': \(error.localizedDescription)"
                    print("❌ SampleFamilyDataGenerator: \(errorMessage)")
                    throw SampleDataError.memberCreationFailed(errorMessage)
                }
            }
        }
        
        // Verify parent admin constraint is satisfied
        let adminMemberships = createdMemberships.filter { $0.role == .parentAdmin }
        guard adminMemberships.count == 1 else {
            throw SampleDataError.memberCreationFailed("Parent admin constraint violation: expected 1, created \(adminMemberships.count)")
        }
        
        print("✅ SampleFamilyDataGenerator: Successfully created \(createdMemberships.count) memberships with proper role assignments")
    }

    /// Generates a unique family code that doesn't conflict with existing families
    /// Implements code regeneration logic when conflicts occur with retry mechanism
    /// Uses existing FamilyCodeGenerator and DataService patterns for consistency
    /// - Returns: A unique 6-character family code
    private func generateUniqueFamilyCode() async throws -> String {
        let maxAttempts = 20 // Increased attempts for better conflict resolution
        var attemptedCodes: Set<String> = []
        
        print("🔄 SampleFamilyDataGenerator: Starting unique code generation...")
        
        for attempt in 1...maxAttempts {
            // Use existing FamilyCodeGenerator utility
            let code = FamilyCodeGenerator.generateCode()
            
            // Validate code format before checking uniqueness
            guard FamilyCodeGenerator.isValidCodeFormat(code) else {
                print("⚠️ SampleFamilyDataGenerator: Generated invalid code format '\(code)' on attempt \(attempt), retrying...")
                continue
            }
            
            // Check if we've already tried this code in this session
            if attemptedCodes.contains(code) {
                print("⚠️ SampleFamilyDataGenerator: Code '\(code)' already attempted in this session (attempt \(attempt)), retrying...")
                continue
            }
            
            attemptedCodes.insert(code)
            
            do {
                // Use existing DataService method to check for conflicts
                let existingFamily = try await fetchFamily(byCode: code)
                if existingFamily == nil {
                    print("✅ SampleFamilyDataGenerator: Generated unique code '\(code)' on attempt \(attempt)")
                    return code
                } else {
                    print("⚠️ SampleFamilyDataGenerator: Code '\(code)' conflicts with existing family '\(existingFamily?.name ?? "Unknown")' (attempt \(attempt))")
                }
            } catch {
                // Handle DataService errors appropriately
                if let dataServiceError = error as? DataServiceError {
                    switch dataServiceError {
                    case .invalidData(let message):
                        print("⚠️ SampleFamilyDataGenerator: Invalid data error checking code '\(code)': \(message)")
                        continue
                    case .notFound:
                        // Not found is actually good - means the code is unique
                        print("✅ SampleFamilyDataGenerator: Code '\(code)' is unique (not found in database)")
                        return code
                    case .validationFailed, .constraintViolation, .unknownError:
                        print("⚠️ SampleFamilyDataGenerator: Database error checking code '\(code)': \(error.localizedDescription)")
                        continue
                    }
                } else {
                    // If there's an error checking for existing family, log it but be cautious
                    print("⚠️ SampleFamilyDataGenerator: Error checking code '\(code)' on attempt \(attempt): \(error.localizedDescription)")
                    
                    // For database errors, we should be more cautious and not assume uniqueness
                    if error.localizedDescription.contains("database") || error.localizedDescription.contains("context") {
                        print("🚨 SampleFamilyDataGenerator: Database error detected, being cautious about code uniqueness")
                        continue
                    }
                    
                    // For other errors (like network issues), we might still proceed cautiously
                    print("⚠️ SampleFamilyDataGenerator: Non-database error, continuing with caution...")
                }
            }
        }
        
        // If we've exhausted all attempts, provide detailed failure information
        print("❌ SampleFamilyDataGenerator: Failed to generate unique code after \(maxAttempts) attempts")
        print("📊 SampleFamilyDataGenerator: Attempted codes: \(attemptedCodes.sorted())")
        
        // Try to get some statistics about existing codes for debugging
        var debugInfo: [String: Any] = [
            "max_attempts": maxAttempts,
            "attempted_codes": Array(attemptedCodes),
            "operation": "generateUniqueFamilyCode"
        ]
        
        do {
            let allFamilies = try await fetchAllFamilies()
            let existingCodes = allFamilies.map { $0.code }
            print("📊 SampleFamilyDataGenerator: Existing codes in database: \(existingCodes.count) total")
            print("📊 SampleFamilyDataGenerator: Sample existing codes: \(Array(existingCodes.prefix(10)))")
            
            debugInfo["existing_codes_count"] = existingCodes.count
            debugInfo["sample_existing_codes"] = Array(existingCodes.prefix(10))
        } catch {
            // Handle DataService errors for debugging info
            if let dataServiceError = error as? DataServiceError {
                print("⚠️ SampleFamilyDataGenerator: DataService error fetching families for debugging: \(dataServiceError.localizedDescription)")
                debugInfo["debug_fetch_error"] = dataServiceError.localizedDescription
            } else {
                print("⚠️ SampleFamilyDataGenerator: Could not fetch existing codes for debugging: \(error.localizedDescription)")
                debugInfo["debug_fetch_error"] = error.localizedDescription
            }
        }
        
        // Log the code generation failure with detailed context
        let codeGenError = SampleDataError.codeGenerationFailed
        let context = ErrorContext(error: codeGenError.toFamilyCreationError(), userContext: debugInfo)
        ErrorHandlingUtilities.logError(codeGenError.toFamilyCreationError(), context: context, additionalInfo: debugInfo)
        
        throw codeGenError
    }
    
    /// Checks for existing sample families in the database
    /// Queries families by name patterns to identify existing sample data
    /// - Returns: Array of GeneratedFamilyInfo for existing sample families
    private func checkExistingFamilies() async throws -> [GeneratedFamilyInfo] {
        print("🔍 SampleFamilyDataGenerator: Checking for existing sample families...")
        
        var existingFamilies: [GeneratedFamilyInfo] = []
        let sampleFamilyNames = Self.sampleFamilies.map { $0.name }
        
        do {
            // Fetch all families from database
            let allFamilies = try await fetchAllFamilies()
            print("📊 SampleFamilyDataGenerator: Found \(allFamilies.count) total families in database")
            
            // Check each sample family name pattern
            for familyData in Self.sampleFamilies {
                // Look for exact name matches first
                let exactMatch = allFamilies.first { family in
                    family.name == familyData.name
                }
                
                if let family = exactMatch {
                    // Validate the existing family data
                    guard family.isFullyValid else {
                        print("⚠️ SampleFamilyDataGenerator: Found invalid existing family '\(family.name)', skipping...")
                        continue
                    }
                    
                    // Get member count safely
                    let memberCount = family.activeMembers.count
                    
                    let generatedInfo = GeneratedFamilyInfo(
                        family: family,
                        code: family.code,
                        memberCount: memberCount
                    )
                    existingFamilies.append(generatedInfo)
                    print("✅ SampleFamilyDataGenerator: Found existing sample family '\(family.name)' with code '\(family.code)' (\(memberCount) members)")
                }
            }
            
            // Also check for families with similar naming patterns that might be sample data
            let potentialSampleFamilies = allFamilies.filter { family in
                // Check if family name contains common sample family patterns
                let name = family.name.lowercased()
                return name.contains("johnson") || name.contains("garcia") || name.contains("chen") || 
                       name.contains("williams") || name.contains("anderson") ||
                       name.contains("sample") || name.contains("test") || name.contains("demo")
            }
            
            // Report any additional potential sample families found
            for family in potentialSampleFamilies {
                let isAlreadyIncluded = existingFamilies.contains { $0.family.id == family.id }
                if !isAlreadyIncluded && !sampleFamilyNames.contains(family.name) {
                    print("ℹ️ SampleFamilyDataGenerator: Found potential sample family '\(family.name)' with code '\(family.code)' (not in predefined list)")
                }
            }
            
            print("📋 SampleFamilyDataGenerator: Detection complete - found \(existingFamilies.count) existing sample families")
            
        } catch {
            // Handle DataService errors gracefully
            if let dataServiceError = error as? DataServiceError {
                print("❌ SampleFamilyDataGenerator: DataService error during family detection: \(dataServiceError.localizedDescription)")
                switch dataServiceError {
                case .validationFailed(let errors):
                    print("   Validation errors: \(errors.joined(separator: ", "))")
                case .invalidData(let message):
                    print("   Invalid data: \(message)")
                case .notFound(let message):
                    print("   Not found: \(message)")
                case .constraintViolation(let message):
                    print("   Constraint violation: \(message)")
                case .unknownError:
                    print("   Unknown DataService error")
                }
            } else {
                print("❌ SampleFamilyDataGenerator: Error during family detection: \(error.localizedDescription)")
            }
            // Don't throw here - we want to continue with creation if detection fails
            print("⚠️ SampleFamilyDataGenerator: Continuing with creation despite detection error...")
        }
        
        return existingFamilies
    }
    
    /// Outputs family codes to console with clear formatting for testing
    /// Displays family names, codes, member counts and usage instructions
    /// - Parameter families: Array of GeneratedFamilyInfo to output
    private func outputFamilyCodes(_ families: [GeneratedFamilyInfo]) {
        guard !families.isEmpty else {
            print("\n⚠️ No family codes to display")
            return
        }
        
        let separator = String(repeating: "=", count: 70)
        let minorSeparator = String(repeating: "-", count: 70)
        
        print("\n" + separator)
        print("🏠 SAMPLE FAMILY CODES FOR TESTING")
        print(separator)
        print("📊 Total Families Available: \(families.count)")
        print("🎯 Purpose: Test 'Join Family' functionality with realistic data")
        print("")
        
        // Display each family with detailed information
        for (index, family) in families.enumerated() {
            let familyNumber = index + 1
            print("[\(familyNumber)] 📋 \(family.family.name)")
            print("    🔑 Family Code: \(family.code)")
            print("    👥 Member Count: \(family.memberCount)")
            
            // Add member role breakdown if available
            if let memberships = family.family.activeMembers as? [Membership] {
                let roleBreakdown = Dictionary(grouping: memberships, by: { $0.role })
                var roleInfo: [String] = []
                
                if let admins = roleBreakdown[.parentAdmin], !admins.isEmpty {
                    roleInfo.append("\(admins.count) Admin\(admins.count > 1 ? "s" : "")")
                }
                if let adults = roleBreakdown[.adult], !adults.isEmpty {
                    roleInfo.append("\(adults.count) Adult\(adults.count > 1 ? "s" : "")")
                }
                if let kids = roleBreakdown[.kid], !kids.isEmpty {
                    roleInfo.append("\(kids.count) Kid\(kids.count > 1 ? "s" : "")")
                }
                
                if !roleInfo.isEmpty {
                    print("    🎭 Roles: \(roleInfo.joined(separator: ", "))")
                }
            }
            
            print("    📅 Created: \(formatDate(family.family.createdAt))")
            
            if index < families.count - 1 {
                print("")
            }
        }
        
        print("\n" + minorSeparator)
        print("💡 TESTING INSTRUCTIONS")
        print(minorSeparator)
        print("1. 📋 Copy any family code from the list above")
        print("2. 🚀 Navigate to the 'Join Family' screen in the app")
        print("3. 📝 Paste the code into the family code input field")
        print("4. ✅ Test the join family workflow with different families")
        print("5. 🔄 Each family has different member compositions for comprehensive testing")
        print("")
        print("🎯 Test Scenarios:")
        print("   • Join families with different member counts")
        print("   • Test role-based permissions and access")
        print("   • Verify family dashboard displays correctly")
        print("   • Test family member interactions")
        print("")
        print("📱 Quick Copy Format (for easy pasting):")
        for family in families {
            print("   \(family.code) - \(family.family.name)")
        }
        print(separator + "\n")
    }
    
    /// Formats a date for display in console output
    /// - Parameter date: The date to format
    /// - Returns: Formatted date string
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    // MARK: - Operation Status Reporting Methods
    
    /// Reports the start of the sample family generation operation
    private func reportOperationStart() {
        let separator = String(repeating: "=", count: 60)
        print("\n" + separator)
        print("🚀 SAMPLE FAMILY DATA GENERATION STARTED")
        print(separator)
        print("📅 Started at: \(formatDate(Date()))")
        print("🎯 Target: Generate 5 sample families for testing")
        print("🔄 Checking for existing data first...")
        print("")
    }
    
    /// Reports idempotent behavior when existing families are found
    /// - Parameter existingFamilies: Array of existing families found
    private func reportIdempotentBehavior(existingFamilies: [GeneratedFamilyInfo]) {
        let separator = String(repeating: "-", count: 60)
        print(separator)
        print("♻️ IDEMPOTENT BEHAVIOR DETECTED")
        print(separator)
        print("✅ Found \(existingFamilies.count) existing sample families")
        print("🔄 Skipping creation to avoid duplicates")
        print("📋 Outputting existing family codes for reference")
        print("")
        
        // List the existing families
        for (index, family) in existingFamilies.enumerated() {
            print("   \(index + 1). \(family.family.name) (Code: \(family.code))")
        }
        print("")
        print("💡 This is expected behavior - sample data generation is idempotent")
        print("🗑️ To regenerate, delete existing sample families first")
        print(separator)
    }
    
    /// Reports the start of family creation process
    /// - Parameter totalFamilies: Total number of families to create
    private func reportCreationStart(totalFamilies: Int) {
        let separator = String(repeating: "-", count: 60)
        print(separator)
        print("🏗️ CREATING NEW SAMPLE FAMILIES")
        print(separator)
        print("📊 Total families to create: \(totalFamilies)")
        print("⏱️ Starting creation process...")
        print("")
    }
    
    /// Reports the start of individual family creation
    /// - Parameters:
    ///   - familyNumber: The family number being created
    ///   - familyName: The name of the family being created
    private func reportFamilyCreationStart(familyNumber: Int, familyName: String) {
        print("[\(familyNumber)/5] 🏠 Creating '\(familyName)'...")
    }
    
    /// Reports successful family creation
    /// - Parameters:
    ///   - familyNumber: The family number that was created
    ///   - familyName: The name of the family that was created
    ///   - code: The generated family code
    ///   - memberCount: The number of members created
    private func reportFamilyCreationSuccess(familyNumber: Int, familyName: String, code: String, memberCount: Int) {
        print("[\(familyNumber)/5] ✅ '\(familyName)' created successfully")
        print("        🔑 Code: \(code)")
        print("        👥 Members: \(memberCount)")
        print("")
    }
    
    /// Reports family creation failure
    /// - Parameters:
    ///   - familyNumber: The family number that failed
    ///   - familyName: The name of the family that failed
    ///   - error: The error that occurred
    private func reportFamilyCreationFailure(familyNumber: Int, familyName: String, error: Error) {
        print("[\(familyNumber)/5] ❌ '\(familyName)' creation failed")
        print("        🚨 Error: \(error.localizedDescription)")
        
        // Provide specific guidance based on error type
        if let sampleError = error as? SampleDataError {
            switch sampleError {
            case .familyAlreadyExists:
                print("        💡 Suggestion: Check for existing family with same name")
            case .codeGenerationFailed:
                print("        💡 Suggestion: Database may be full of family codes, check capacity")
            case .memberCreationFailed:
                print("        💡 Suggestion: Verify user data and database constraints")
            case .partialCreationFailure:
                print("        💡 Suggestion: Check database connectivity and permissions")
            case .dataServiceUnavailable:
                print("        💡 Suggestion: Ensure DataService is properly initialized and available")
            case .validationFailed:
                print("        💡 Suggestion: Check input data format and validation requirements")
            case .databaseError:
                print("        💡 Suggestion: Check database connection and integrity")
            case .networkError:
                print("        💡 Suggestion: Check network connectivity and try again")
            case .unknownError:
                print("        💡 Suggestion: Check logs for more details or restart the application")
            }
        }
        print("")
    }
    
    /// Reports the completion of the entire operation
    /// - Parameters:
    ///   - created: Number of families successfully created
    ///   - failed: Number of families that failed to create
    ///   - skipped: Number of families that were skipped
    ///   - duration: Time taken for the operation
    private func reportOperationComplete(created: Int, failed: Int, skipped: Int, duration: TimeInterval) {
        let separator = String(repeating: "=", count: 60)
        print(separator)
        print("🏁 SAMPLE FAMILY GENERATION COMPLETE")
        print(separator)
        print("📊 OPERATION SUMMARY:")
        print("   ✅ Successfully Created: \(created) families")
        print("   ❌ Failed: \(failed) families")
        print("   ⏭️ Skipped: \(skipped) families")
        print("   ⏱️ Duration: \(String(format: "%.2f", duration)) seconds")
        print("   📅 Completed at: \(formatDate(Date()))")
        
        // Calculate success rate
        let total = created + failed + skipped
        if total > 0 {
            let successRate = Double(created) / Double(total) * 100
            print("   📈 Success Rate: \(String(format: "%.1f", successRate))%")
        }
        
        print("")
        
        // Provide status-specific messaging
        if created > 0 && failed == 0 {
            print("🎉 All families created successfully!")
            print("🧪 Ready for testing - family codes are displayed below")
        } else if created > 0 && failed > 0 {
            print("⚠️ Partial success - some families created, some failed")
            print("🧪 Available families can still be used for testing")
        } else if created == 0 && failed > 0 {
            print("🚨 Operation failed - no families were created")
            print("🔧 Please check the errors above and retry")
        }
        
        print(separator)
    }
    
    /// Reports complete operation failure
    /// - Parameter failures: Array of failure messages
    private func reportCompleteFailure(failures: [String]) {
        let separator = String(repeating: "!", count: 60)
        print("\n" + separator)
        print("🚨 COMPLETE OPERATION FAILURE")
        print(separator)
        print("❌ No sample families were created")
        print("📋 Failure details:")
        
        for (index, failure) in failures.enumerated() {
            print("   \(index + 1). \(failure)")
        }
        
        print("")
        print("🔧 TROUBLESHOOTING STEPS:")
        print("   1. Check database connectivity")
        print("   2. Verify DataService is properly configured")
        print("   3. Ensure sufficient database permissions")
        print("   4. Check for database capacity issues")
        print("   5. Review error messages above for specific issues")
        print(separator + "\n")
    }
    
    /// Reports partial success with some failures
    /// - Parameter failures: Array of failure messages
    private func reportPartialSuccess(failures: [String]) {
        let separator = String(repeating: "-", count: 60)
        print("\n" + separator)
        print("⚠️ PARTIAL SUCCESS - SOME FAILURES OCCURRED")
        print(separator)
        print("📋 The following families failed to create:")
        
        for (index, failure) in failures.enumerated() {
            print("   \(index + 1). \(failure)")
        }
        
        print("")
        print("💡 Successfully created families are still available for testing")
        print("🔧 Consider investigating failures for complete test coverage")
        print(separator)
    }
}